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
  ## Caddy — public reverse proxy / TLS terminator.
  ##
  ## goltenstories.no — Golten Stories podcast platform. The kokosbananas Go
  ## binary runs inside the kokosbananas container (10.100.0.122); the container's
  ## `web` proxy device forwards host:8080 → container:8080. Public paths
  ## (/feed/**, /audio/**, /images/**) are ungated; the admin/lab is protected
  ## by Pocket ID passkey auth enforced at the edge (forward_auth to
  ## oauth2-proxy — separate nix module, not yet wired).
  ##
  ## tilgang.goltenstories.no — Pocket ID passkey auth provider for the above.
  ## Runs in the services container (10.100.0.141) on port 1412, exposed via
  ## the container's `pocket-id-goltenstories` proxy device.
  ##
  ## kokosbananas.tjue.net — internal dev/test alias for the same backend.
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
      reverse_proxy localhost:8080
    '';
    virtualHosts."tilgang.goltenstories.no".extraConfig = ''
      reverse_proxy localhost:1412
    '';
    virtualHosts."kokosbananas.tjue.net".extraConfig = ''
      reverse_proxy localhost:8080
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
