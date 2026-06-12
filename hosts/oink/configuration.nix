{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/base.nix
    ./incus.nix
    ./secrets.nix
    # FISMEN-INTERIM: temporary home for the fismen estate during its NixOS
    # reinstall — remove this import (plus the marked blocks in ./incus.nix)
    # after the move-back. See hosts/fismen/MIGRATION.md.
    ./fismen-interim.nix
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
  networking.firewall.allowedTCPPorts = [ 22 ];

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

  # It's a pig, not a fox.
  motd.animal = "piggy";

  # First release installed against. Do NOT bump casually.
  system.stateVersion = "25.11";
}
