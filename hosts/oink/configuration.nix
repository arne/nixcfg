{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/base.nix
    ./caddy.nix
    ./incus.nix
    ./oauth2-proxy.nix
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
    description = "Øystein";
    extraGroups = [ "wheel" "incus" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvxD8FA3gl4XFGhMSwO5885bxLNT0UT/Rj/v+vncRhY oystein@carbon-x1"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDmI5e3HluXuSbQWzUsbIew8SCwQg4QLnSTyA+BTtOxbB54yEV7EM6n4eYry5CMAj4+8I1VoWR9Me7hZn35U3o3hRlTn42ArE8OC4Mfe9qsAl+sLFY6pJ8fLK9Qn9pbrm0rk8fdBn4sfU/cLwiGeLvrTr1pbDL5jEPv1RcssW9I+jCStC3xCtiG7zjv0jDWwGrA3zytuK0wm686FLTeDPhiiqUTgqhUnXNe+Vf3uWzGFLO9HXFGwaLIqr9ELzidYOhm2+QtcF+C7U4mDZP+VIUW6+c3rl1J4esv4eeJ3OV7elmZfber8/4Evh58U/vuO9EybWE5SAN0d3mQ+Y94Dt6+r7Hnlto0mtUKvb+SAddT2HBa5kGVNfrxp3ZNIYVya+vqXuPCfGgXZjYTFdy496/yhbdJMUJYYjBdq6JOO4h6OhMdBET5bg4YW8KUFwpx0UxOpqZYwOrviml/zNElUA8oF7Saaj8jcVx4eZ4KsdLyEcfS15eTHu9WhFx9sRCjy/U= oystein@ryzen7"
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

  # Caddy lives in ./caddy.nix.

  # It's a pig, not a fox.
  motd.animal = "piggy";

  # First release installed against. Do NOT bump casually.
  system.stateVersion = "25.11";
}
