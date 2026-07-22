{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/base.nix
  ];

  ###########################################################################
  ## Boot — UEFI, systemd-boot on the ESP (/boot). No mirror (single NVMe),
  ## so none of the fismen/oink /boot-fallback dance is needed.
  ###########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  ###########################################################################
  ## Networking — home LAN, DHCP on the wired NIC. Matched on MAC (not iface
  ## name) via systemd-networkd so a NIC rename can never strand the box.
  ## Wi-Fi (wlp0s20f3) is intentionally left unconfigured — same network as
  ## the wired NIC, so there's no point running two supplicants.
  ###########################################################################
  networking.hostName = "servo";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.MACAddress = "1c:69:7a:01:07:bd";
    networkConfig.DHCP = "yes";
    linkConfig.RequiredForOnline = "routable";
  };

  # LAN + tailnet SSH only. Nothing else exposed from the home box.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  ###########################################################################
  ## SSH — key-only, no root, no passwords. The `servo` key is already in
  ## modules/ssh-keys.nix, so this box's own key trusts the rest of the fleet
  ## as soon as it comes up.
  ###########################################################################
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  ###########################################################################
  ## Users — SSH keys for arne come from the shared list in
  ## modules/ssh-keys.nix; root SSH is disabled.
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
  ## External data disk — the 3.6 TB Seagate BUP over USB (Films / Music /
  ## TV / Children / …). `nofail` so boot doesn't hang if the cable is out;
  ## `x-systemd.device-timeout=5s` bounds how long systemd waits before
  ## giving up. Mount point is /mnt/form (the ext4 label is "form").
  ###########################################################################
  fileSystems."/mnt/form" = {
    device = "/dev/disk/by-label/form";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.device-timeout=5s" ];
  };

  ###########################################################################
  ## Swap — disko already carved a 16 G swap partition on nvme. zram on top
  ## as an OOM cushion (compressed anon pages before we page to disk).
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

  # Home box, keeps the media archive.
  motd.animal = "owl";

  # First release installed against. Do NOT bump casually.
  system.stateVersion = "25.11";
}
