{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/base.nix
  ];

  ###########################################################################
  ## Boot / kernel — handled by apple-silicon.nixosModules.apple-silicon-support
  ## (wired in flake.nix). It pulls in the Asahi kernel, Mesa, peripheral
  ## firmware, and asahi-audio. The bootloader is u-boot → systemd-boot.
  ###########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = false;   # m1n1 owns NVRAM, not EFI

  # Asahi peripheral firmware (Wi-Fi, BT, …). The Asahi installer extracts
  # this from macOS at install time; drop the resulting bundle into
  # hosts/air/firmware/ and uncomment. Until then we rely on the prebuilt
  # firmware shipped by the apple-silicon flake's installer image.
  # hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  # GPU. The conservative driver is the default; flip to the experimental
  # one for noticeably better perf once it's stable on this kernel.
  # hardware.asahi.useExperimentalGPUDriver = true;

  ###########################################################################
  ## Networking — hostname `air`, NetworkManager (Wi-Fi).
  ###########################################################################
  networking.hostName = "air";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  ###########################################################################
  ## Locale / time
  ###########################################################################
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  ###########################################################################
  ## Power — laptop. Sleep on lid close, suspend on idle.
  ###########################################################################
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "suspend";
    lidSwitchDocked = "ignore";
  };
  # Suspend support on Asahi is still shallow (s2idle only) but works.
  # Don't disable the sleep targets here the way fox does.

  ###########################################################################
  ## zram — OOM cushion only, no disk swap.
  ###########################################################################
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  ###########################################################################
  ## Users
  ###########################################################################
  users.users.arne = {
    isNormalUser = true;
    uid = 1000;
    description = "Arne Skaar Fismen";
    extraGroups = [ "wheel" "networkmanager" "video" "render" ];
    shell = pkgs.fish;
    initialPassword = "changeme";
  };
  security.sudo.wheelNeedsPassword = false;

  programs.fish.enable = true;

  ###########################################################################
  ## Desktop — niri behind greetd + tuigreet (real login prompt).
  ###########################################################################
  programs.niri.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # Portals — see hosts/fox/configuration.nix for the rationale (gtk handles
  # FileChooser so xdg-open doesn't fall through to the default mime handler).
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.niri.default = [ "gtk" ];
  };

  # PipeWire audio. asahi-audio (speaker DSP + calibration) is pulled in by
  # the apple-silicon module; PipeWire is the consumer.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  security.polkit.enable = true;

  programs.dconf.enable = true;

  ###########################################################################
  ## SSH — key-only, no root, no passwords.
  ###########################################################################
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  ###########################################################################
  ## Fonts
  ###########################################################################
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    ibm-plex
    noto-fonts
    noto-fonts-color-emoji
  ];

  environment.systemPackages = with pkgs; [
    xdg-utils
    brightnessctl
    wl-clipboard
    cliphist
    xwayland-satellite
    vulkan-tools
    pciutils
    usbutils
    btrfs-progs
  ];

  environment.sessionVariables.BROWSER = "firefox";
  environment.sessionVariables.TERMINAL = "ghostty";

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
    persistent = true;
  };
  nix.optimise.automatic = true;

  # Binary caches.
  #   niri.cachix.org — prebuilt niri (same as fox).
  #   TODO: add the apple-silicon flake's binary cache before the first
  #   rebuild, or building will compile the Asahi kernel + Mesa locally.
  #   Pull the substituter URL and public key from the upstream README:
  #     https://github.com/tpwrules/nixos-apple-silicon#binary-cache
  nix.settings.extra-substituters = [
    "https://niri.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
  ];

  system.stateVersion = "25.11";
}
