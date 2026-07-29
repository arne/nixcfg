{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/base.nix
    ./nvidia.nix
    ./immich.nix
  ];

  ###########################################################################
  ## Boot — UEFI, systemd-boot on the ESP (/boot). Single OS disk, so no
  ## fismen/oink /boot-fallback dance.
  ###########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  ###########################################################################
  ## Networking — home LAN, DHCP on the wired NIC, matched by MAC (not iface
  ## name) via systemd-networkd so a NIC rename can't strand the box. roar has
  ## no remote console: this deliberately mirrors meow's proven config on the
  ## same subnet.
  ###########################################################################
  networking.hostName = "roar";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.MACAddress = "00:e0:4c:0f:32:0a";
    networkConfig.DHCP = "yes";
    linkConfig.RequiredForOnline = "routable";
    # A transient hostname from DHCP would override the static one above.
    dhcpV4Config.UseHostname = false;
  };

  # LAN + tailnet SSH only in Phase 1. Service ports are opened in a later phase.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # NOTE: roar does NOT advertise subnet routes — meow already advertises
  # 10.69.68.0/24 to the tailnet; a second advertiser would conflict. So the
  # tailscale useRoutingFeatures/extraSetFlags block from meow is intentionally
  # absent here (base.nix's tailscale defaults to "client").

  ###########################################################################
  ## SSH — key-only, no root, no passwords. arne's keys come from
  ## modules/ssh-keys.nix (via base.nix).
  ###########################################################################
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  ###########################################################################
  ## Users — base.nix does NOT create the account; every host defines it.
  ###########################################################################
  users.users.arne = {
    isNormalUser = true;
    uid = 1000;
    description = "Arne Skaar Fismen";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = false;

  programs.fish.enable = true;

  ###########################################################################
  ## Swap — zram only (62 GiB RAM; no on-disk swap partition).
  ###########################################################################
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  ###########################################################################
  ## Locale / time
  ###########################################################################
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Cosmetic motd mark — any name from the marks dir (see modules/motd.nix).
  motd.animal = "lion";

  # First release installed against. Do NOT bump casually.
  system.stateVersion = "25.11";
}
