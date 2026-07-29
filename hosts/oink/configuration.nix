{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/base.nix
    ./incus.nix
    ./secrets.nix
  ];

  ###########################################################################
  ## Boot — systemd-boot on rpool-a's ESP (/boot). After each install, the
  ## entire ESP is mirrored to rpool-b's ESP (/boot-fallback) so it stays
  ## bit-identical. UEFI's built-in /EFI/BOOT/BOOTX64.EFI fallback on each
  ## disk's ESP handles the failover if rpool-a dies — no separate Boot####
  ## entry is required (systemd-boot copies BOOTX64.EFI alongside its own
  ## loader).
  ###########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.extraInstallCommands = ''
    ${pkgs.rsync}/bin/rsync -a --delete /boot/ /boot-fallback/
  '';

  ###########################################################################
  ## Networking — static, headless. Matched on MAC (not iface name) via
  ## systemd-networkd so a NIC rename can never strand the box. Reproduces the
  ## gigahost.no assignment (v4 + v6) exactly.
  ###########################################################################
  networking.hostName = "oink";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "8c:dc:d4:ae:14:25";
    address = [
      "185.181.63.4/24"
      "2a03:94e0:ffff:185:181:63::4/118"
    ];
    routes = [
      { Gateway = "185.181.63.1"; }
      { Gateway = "2a03:94e0:ffff:185:181:63::1"; }
    ];
    networkConfig.DNS = [ "1.1.1.1" "1.0.0.1" ];
    linkConfig.RequiredForOnline = "routable";
  };

  networking.firewall.enable = true;
  # 22: WAN SSH. 80/443: Caddy (HTTP→HTTPS redirect + ACME challenge, and HTTPS).
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  ###########################################################################
  ## Tailscale — base.nix enables the service ("client"); oink is also an exit
  ## node, so bump routing features to "both" (turns on the IPv4/IPv6 forwarding
  ## sysctls needed to route other nodes' traffic out the gigahost.no uplink).
  ## Advertising is set at auth time, not declaratively (we use manual auth, so
  ## extraUpFlags would be ignored). On first bring-up, SSH in and run:
  ##   sudo tailscale up --advertise-exit-node
  ## then approve the exit node in the Tailscale admin console.
  ###########################################################################
  services.tailscale.useRoutingFeatures = "both";

  ###########################################################################
  ## SSH — key-only, no root, no passwords (this is our remote lifeline).
  ###########################################################################
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  ###########################################################################
  ## Users — SSH keys for arne come from the shared list in
  ## modules/ssh-keys.nix; root SSH is disabled (PermitRootLogin = "no").
  ###########################################################################
  users.users.arne = {
    isNormalUser = true;
    uid = 1000;
    description = "Arne Skaar Fismen";
    extraGroups = [ "wheel" "incus-admin" ];  # incus-admin: drive Incus without sudo
    shell = pkgs.fish;
    # SSH keys come from the shared list in modules/ssh-keys.nix (config.mine.sshKeys).
  };

  # oystein — oink-only account with passwordless sudo (wheel). Key inline
  # rather than the shared list since this account does not exist elsewhere.
  users.users.oystein = {
    isNormalUser = true;
    description = "Oystein";
    extraGroups = [ "wheel" "incus" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvxD8FA3gl4XFGhMSwO5885bxLNT0UT/Rj/v+vncRhY oystein@carbon-x1"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  programs.fish.enable = true;

  ###########################################################################
  ## Swap — zram OOM cushion only; no disk swap (ZFS-on-zvol swap can deadlock).
  ###########################################################################
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  ###########################################################################
  ## ZFS maintenance — monthly scrub, periodic TRIM (helps the SSD rpool).
  ###########################################################################
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  ###########################################################################
  ## Locale / time
  ###########################################################################
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  ###########################################################################
  ## Nix / packages — nix experimental-features / trusted-users, the numtide
  ## cache, and the shared CLI tooling (git/htop/claude-code/…) all live in
  ## modules/base.nix; oink adds nothing host-specific here.
  ###########################################################################

  ###########################################################################
  ## Navidrome — self-hosted music streaming (Subsonic-compatible). Binds
  ## 0.0.0.0 but the port is opened ONLY on tailscale0, so it's reachable from
  ## the tailnet (http://oink:4533) and never from the public WAN. Music lives
  ## in /srv/music, pre-created arne:users 0755 so arne manages the files while
  ## the navidrome service user only reads them (the module's tmpfiles rule is
  ## ":700" = create-only, so it leaves the existing dir's owner/mode alone).
  ###########################################################################
  services.navidrome = {
    enable = true;
    settings = {
      Address = "0.0.0.0";
      Port = 4533;
      MusicFolder = "/srv/music";
    };
  };
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 4533 ];

  ###########################################################################
  ## oauth2-proxy — session gateway in front of the Golten Stories backend.
  ##
  ## Two instances share the same Pocket ID at tilgang.goltenstories.no but
  ## use separate OIDC client registrations so their sessions are independent:
  ##
  ##   4180  goltenstories.no   client-id kokosbananas
  ##   4181  kokosbananas.tjue.net   client-id kokosbananas-dev
  ##
  ## Both read their OAUTH2_PROXY_CLIENT_SECRET and OAUTH2_PROXY_COOKIE_SECRET
  ## from sops-decrypted env files. The client secrets start as "CHANGEME" —
  ## replace them in sops after registering the OIDC clients in Pocket ID:
  ##   1. Log into https://tilgang.goltenstories.no as admin.
  ##   2. Register two clients:
  ##        kokosbananas      redirect https://goltenstories.no/oauth2/callback
  ##        kokosbananas-dev  redirect https://kokosbananas.tjue.net/oauth2/callback
  ##   3. sops secrets/oink.yaml  ← set the two CLIENT_SECRET values.
  ##   4. nixos-rebuild switch (or comin picks it up on next push).
  ##
  ## Caddy wires these up with forward_auth (see below).
  ###########################################################################
  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    oidcIssuerUrl = "https://tilgang.goltenstories.no";
    clientID = "a03eaba7-7beb-4738-abbb-150d76de31a6";  # Pocket ID auto-generated client ID.
    # OAUTH2_PROXY_CLIENT_SECRET + OAUTH2_PROXY_COOKIE_SECRET via env file.
    keyFile = config.sops.secrets."goltenstories/oauth2-proxy-env".path;
    cookie = {
      secure = true;
      domain = ".goltenstories.no";
      name = "_oauth2_proxy";
    };
    extraConfig.cookie-samesite = "lax";
    httpAddress = "http://127.0.0.1:4180";
    email.domains = [ "*" ];  # Any Pocket ID user may access.
    redirectURL = "https://goltenstories.no/oauth2/callback";
    upstream = "static://200";  # Validation only — Caddy does the proxying.
  };

  # Second instance for kokosbananas.tjue.net (different domain → different cookie).
  # Uses the NixOS oauth2-proxy module's user/group but runs as a separate unit.
  systemd.services.oauth2-proxy-tjue = {
    description = "oauth2-proxy — kokosbananas.tjue.net";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      User = "oauth2-proxy";
      Group = "oauth2-proxy";
      Restart = "always";
      EnvironmentFile = config.sops.secrets."goltenstories/oauth2-proxy-tjue-env".path;
      ExecStart = let
        args = [
          "--provider=oidc"
          "--oidc-issuer-url=https://tilgang.goltenstories.no"
          "--client-id=kokosbananas-dev"
          "--redirect-url=https://kokosbananas.tjue.net/oauth2/callback"
          "--upstream=static://200"
          "--http-address=127.0.0.1:4181"
          "--email-domain=*"
          "--cookie-secure=true"
          "--cookie-name=_oauth2_proxy_tjue"
          "--cookie-domain=kokosbananas.tjue.net"
          "--cookie-samesite=lax"
        ];
      in "${pkgs.oauth2-proxy}/bin/oauth2-proxy ${builtins.concatStringsSep " " (map (a: "'${a}'") args)}";
    };
  };

  ###########################################################################
  ## Caddy — public reverse proxy / TLS terminator.
  ##
  ## goltenstories.no and kokosbananas.tjue.net — Golten Stories backend.
  ## The kokosbananas Go binary runs in its Incus container (10.100.0.122);
  ## the container's `web` proxy device forwards host:8080 → container:8080.
  ##
  ## Auth pattern (both vhosts):
  ##   @public  /feed/*, /audio/*, /images/*  → direct proxy (no auth)
  ##   /oauth2/*                              → oauth2-proxy (handles OIDC flow)
  ##   everything else                        → forward_auth → proxy
  ##
  ## tilgang.goltenstories.no — Pocket ID (OIDC provider). Runs in the
  ## services container (10.100.0.141) on port 1412.
  ##
  ## Ports 80/443 are opened in the firewall block above.
  ###########################################################################
  services.caddy = {
    enable = true;
    email = "arnefismen@gmail.com";  # ACME account — Let's Encrypt expiry notices.
    virtualHosts."goltenstories.no".extraConfig = ''
      log {
        output file /var/log/caddy/access-goltenstories.no.log
      }
      @public path /feed/* /audio/* /images/*
      handle @public {
        reverse_proxy localhost:8080
      }
      handle /oauth2/* {
        reverse_proxy localhost:4180
      }
      handle {
        forward_auth localhost:4180 {
          uri /oauth2/auth
          copy_headers X-Auth-Request-User X-Auth-Request-Email

          # Unauthenticated → bounce to the Pocket ID sign-in flow instead of a
          # bare 401, preserving the originally requested URL for post-login.
          @needs-login status 401
          handle_response @needs-login {
            redir * /oauth2/sign_in?rd={uri}
          }
        }
        reverse_proxy localhost:8080
      }
    '';
    virtualHosts."tilgang.goltenstories.no".extraConfig = ''
      reverse_proxy localhost:1412
    '';
    virtualHosts."kokosbananas.tjue.net".extraConfig = ''
      handle /oauth2/* {
        reverse_proxy localhost:4181
      }
      handle {
        forward_auth localhost:4181 {
          uri /oauth2/auth
          copy_headers X-Auth-Request-User X-Auth-Request-Email

          # Unauthenticated → bounce to the Pocket ID sign-in flow.
          @needs-login status 401
          handle_response @needs-login {
            redir * /oauth2/sign_in?rd={uri}
          }
        }
        reverse_proxy localhost:8080
      }
    '';
  };

  ###########################################################################
  ## goltenstories.no health check — curl the main page every 5 min and fail
  ## the unit (journald alert) if it returns a non-2xx or times out. Extend
  ## with an OnFailure= notification unit if email/push alerting is wanted.
  ###########################################################################
  systemd.services.goltenstories-health = {
    description = "goltenstories.no HTTP health check";
    after = [ "network-online.target" "caddy.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.curl}/bin/curl --fail --max-time 15 --silent --output /dev/null https://goltenstories.no";
    };
  };
  systemd.timers.goltenstories-health = {
    wantedBy = [ "timers.target" ];
    description = "goltenstories.no health check every 5 minutes";
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
  };

  # It's a pig, not a fox.
  motd.animal = "piggy";

  # First release installed against. Do NOT bump casually.
  system.stateVersion = "25.11";
}
