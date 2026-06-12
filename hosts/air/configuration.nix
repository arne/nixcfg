{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/base.nix
    ../../modules/desktop.nix
  ];

  ###########################################################################
  ## Boot / kernel — handled by apple-silicon.nixosModules.apple-silicon-support
  ## (wired in flake.nix). It pulls in the Asahi kernel, Mesa, peripheral
  ## firmware, and asahi-audio. The bootloader is u-boot → systemd-boot.
  ###########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = false;   # m1n1 owns NVRAM, not EFI

  # Asahi peripheral firmware (Wi-Fi, BT, …) lives on the ESP at /boot/asahi/
  # (placed there by the Asahi installer; see docs/install-air.md). It's a
  # ~52 MB, host-specific, non-redistributable blob, so we keep it OUT of the
  # flake entirely and let the apple-silicon module read its default location
  # directly. Reading an absolute path needs impure eval, so `air` rebuilds
  # pass --impure (handled by the `rebuild` shell function).
  # hardware.asahi.peripheralFirmwareDirectory defaults to /boot/asahi — unset.

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

  # It's a cat, not a fox.
  motd.animal = "cat";

  ###########################################################################
  ## Locale / time
  ###########################################################################
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  ###########################################################################
  ## Power — laptop. Sleep on lid close, suspend on idle.
  ###########################################################################
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
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
  ## Desktop — niri (enabled in modules/desktop.nix) behind greetd + tuigreet.
  ###########################################################################
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # asahi-audio (speaker DSP + calibration) is pulled in by the apple-silicon
  # module; PipeWire is the consumer. The shared PipeWire/portal/polkit/dconf
  # desktop config lives in modules/desktop.nix.

  ###########################################################################
  ## SSH — key-only, no root, no passwords.
  ###########################################################################
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  # hardware.bluetooth is enabled in modules/desktop.nix.

  ###########################################################################
  ## Keyboard — Caps Lock acts as Control when held, Escape when tapped.
  ## keyd remaps at the evdev level (below the compositor), so this works in
  ## niri, the TTYs, and the greeter alike — unlike an xkb `ctrl:nocaps`
  ## option, which can only do the plain Caps→Control half.
  ###########################################################################
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main.capslock = "overload(control, esc)";
    };
  };

  # Fonts, the Wayland/desktop system packages, and the BROWSER/TERMINAL
  # defaults are shared via modules/desktop.nix.

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
    persistent = true;
  };
  nix.optimise.automatic = true;

  # Binary caches. niri.cachix.org is added by modules/desktop.nix; here we add
  # the apple-silicon cache (kernel still compiles if the cache lacks this exact
  # nixpkgs build). Substituter URL + key from the upstream README:
  #   https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/binary-cache.md
  nix.settings.extra-substituters = [
    "https://nixos-apple-silicon.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
  ];

  system.stateVersion = "25.11";
}
