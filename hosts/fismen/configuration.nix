{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/base.nix
    ./incus.nix
    ./caddy.nix
    ./services.nix
    ./secrets.nix
  ];

  ###########################################################################
  ## Boot — GRUB in BIOS/legacy mode (the box boots legacy today and flipping
  ## a remote Hetzner machine to UEFI risks a KVM-console rescue — see
  ## disko.nix). mirroredBoots installs GRUB to BOTH disks' EF02 partitions
  ## and writes both /boot trees, so either disk failing leaves a bootable
  ## system. The vfat partitions stay EF00-typed for a later UEFI switch.
  ###########################################################################
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
    configurationLimit = 10;
    # disko auto-fills boot.loader.grub.devices from the EF02 partitions,
    # which the grub module would merge into mirroredBoots as a duplicate
    # entry — mirroredBoots below is the complete intent, so squash it.
    devices = lib.mkForce [ ];
    mirroredBoots = [
      {
        devices = [ "/dev/disk/by-id/nvme-KXD51RUE960G_TOSHIBA_406S10D6T7PM" ];
        path = "/boot";
      }
      {
        devices = [ "/dev/disk/by-id/nvme-KXD51RUE960G_TOSHIBA_406S10AYT7PM" ];
        path = "/boot-fallback";
      }
    ];
  };

  ###########################################################################
  ## Networking — static, headless. Matched on MAC (not iface name) via
  ## systemd-networkd so a NIC rename can never strand the box. Reproduces
  ## the live Hetzner assignment exactly (captured 2026-06-12, MIGRATION.md).
  ## Hetzner routes IPv6 via the link-local gateway fe80::1.
  ###########################################################################
  networking.hostName = "fismen";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "d4:5d:64:41:5b:d6";
    address = [
      "135.181.130.98/26"
      "2a01:4f9:4b:2141::2/64"
    ];
    routes = [
      { Gateway = "135.181.130.65"; }
      { Gateway = "fe80::1"; }
    ];
    networkConfig.DNS = [ "1.1.1.1" "1.0.0.1" ];
    linkConfig.RequiredForOnline = "routable";
  };

  # 22 only here — caddy.nix opens 80/443(+udp), modules/services/bbs.nix
  # opens 2222.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  ###########################################################################
  ## Tailscale — base.nix enables the service; fismen offers an exit node
  ## (like the old install), so bump routing features to "both". Advertising
  ## happens at auth time (manual auth): on first bring-up run
  ##   sudo tailscale up --advertise-exit-node
  ## then approve in the admin console, note the NEW tailnet IP, and update
  ## the two `bind` lines in ./Caddyfile (vault.fismen.no, ai.azf.no).
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
    extraGroups = [ "wheel" "incus-admin" ];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = false;

  programs.fish.enable = true;

  ###########################################################################
  ## Swap — zram OOM cushion only; no disk swap (ZFS-on-zvol swap can
  ## deadlock). The old install's 32G md-swap partition is gone with disko.
  ###########################################################################
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  ###########################################################################
  ## ZFS maintenance — monthly scrub, periodic TRIM (NVMe rpool).
  ###########################################################################
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  ###########################################################################
  ## Locale / time
  ###########################################################################
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # The estate-bearing dragon.
  motd.animal = "dragon";

  # First release installed against. Do NOT bump casually.
  system.stateVersion = "25.11";
}
