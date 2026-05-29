{ config, pkgs, lib, ... }:

{
  imports = [
    ../../modules/base.nix
    ./ollama.nix
    ./openwebui.nix
  ];

  ###########################################################################
  ## Boot / kernel
  ###########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;   # keep /boot from filling
  boot.loader.efi.canTouchEfiVariables = true;

  # Newest kernel — what makes the Apple 5K tiled panel modeset correctly on
  # the amdgpu stack (see nixos-display-fix.md on the Kingston).
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Apple Studio Display (5K over USB4) — see also services.hardware.bolt below
  # (TB authorization was the root cause of the black screen) and the niri output
  # config. The phantom right-tile is handled in niri, NOT via `video=<conn>:d`
  # (that broke it on CachyOS: connector index drifts over DP-tunneling).
  boot.kernelParams = [
    # USB4 v2 host-router reset tears down the already-connected DP tunnel to the
    # Studio Display; disabling it lets the display enumerate cleanly at boot.
    "thunderbolt.host_reset=false"
  ];
  # Bring the Thunderbolt subsystem up in the initramfs so the USB4 DP tunnel
  # (and early console output) is available at boot, not only on later hotplug.
  boot.initrd.kernelModules = [ "thunderbolt" ];

  ###########################################################################
  ## Firmware / microcode (Strix Halo needs current amdgpu blobs)
  ###########################################################################
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  ###########################################################################
  ## Graphics — amdgpu / Mesa RADV, 32-bit enabled for Steam/Proton later
  ###########################################################################
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  ###########################################################################
  ## Networking — hostname `ram`, NetworkManager (Wi-Fi profile "Boksen"
  ## is dropped into /etc/NetworkManager/system-connections during install)
  ###########################################################################
  networking.hostName = "fox";
  networking.networkmanager.enable = true;
  # NM manages the firewall; keep the default firewall on, SSH open.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  # Drop new inbound IPv6 to global-unicast destinations (2000::/3) on the WAN
  # iface so the public ISP prefix is invisible from the internet. ULA
  # (fd00::/8), link-local, multicast, and tailscale0 are unaffected. The
  # ctstate NEW filter means outbound v6 still works — response packets are
  # ESTABLISHED and fall through to the state-accept rule in nixos-fw.
  networking.firewall.extraCommands = ''
    ip6tables -I INPUT 1 -i enp191s0 -d 2000::/3 -m conntrack --ctstate NEW -j DROP
  '';

  ###########################################################################
  ## Locale / time
  ###########################################################################
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  ###########################################################################
  ## Power — desktop, stays on, never sleeps
  ###########################################################################
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  ###########################################################################
  ## zram — OOM cushion only, no disk swap (per base.md)
  ###########################################################################
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
    memoryMax = 16 * 1024 * 1024 * 1024;   # cap ~16 GiB
  };

  ###########################################################################
  ## Users
  ###########################################################################
  users.users.arne = {
    isNormalUser = true;
    uid = 1000;
    description = "Arne Skaar Fismen";
    extraGroups = [ "wheel" "networkmanager" "video" "render" "media" ];
    shell = pkgs.fish;
    # TEMPORARY login password for tuigreet — CHANGE on first login: `passwd`.
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN8r647rf/5m/GEXN1kIccmJItzT1sdI0k4FGYSq5AKi arne@mac"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEoX8GswCzYqOs94smClAJBxAO0ZX2U2WaKgriZO2Z7R servo"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHb1GcfjCCMlzVsZw5Zku7UvbF3QrFPbP+kxFDU4a+H/9p2HalYD43ZkaJQphQMYqC1MIQd4Cjmg1RTbUTneC+M= aPad"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkHOi39HCigHCOneTKIiY+C809n6d3sNHd3hoy2Uq21 aMini"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8iwTusmiXgGpx7VxMXJ/3U6LbTbkEPw+dv4538dThs orbit"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhF6a+vyLLQl74q6BHVbqeVxstHUMwVyDM4649b81Bg fismen"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAkjfCCcwrYPMff8OA6l5cJKaWBQ2RkbjcamyLib9uRM rootShell"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBoj+n9iDeEVkDm9Yms0KNjqChlhGFrP6Aokh/DFByX air"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPmGloBn0yDmkJtsNEPQWYJdYBP1G0NNXeOw30r5801u ram"
    ];
  };
  # Passwordless sudo for wheel (per README §6).
  security.sudo.wheelNeedsPassword = false;

  # Shared media group + library root. setgid (2775) so files dropped in by
  # any member inherit the `media` group, keeping the tree readable to all.
  users.groups.media = {};
  systemd.tmpfiles.rules = [
    "d /srv/music 2775 root media -"
  ];

  programs.fish.enable = true;

  ###########################################################################
  ## Desktop — niri (via niri-flake module) behind greetd + tuigreet
  ###########################################################################
  programs.niri.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      # Autologin into niri. A console greeter (tuigreet) can't render on the
      # tiled+DSC Studio Display (fbcon limitation) — only a Wayland compositor
      # drives it. So we autologin niri directly; revisit a Wayland greeter
      # (ReGreet/cage) later if a login gate is wanted.
      default_session = {
        command = "niri-session";
        user = "arne";
      };
    };
  };

  # Portals for screenshots/screencast/file pickers under niri.
  # Without xdg.portal.config, xdg-desktop-portal doesn't know which backend
  # handles each interface — GTK FileChooser requests then fall through to
  # xdg-open, which on niri ends up launching whatever handles inode/directory
  # (Firefox by default; yazi after the override). Force gtk for everything.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.niri.default = [ "gtk" ];
  };

  # PipeWire audio.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Polkit (needed by greetd/niri session bits).
  security.polkit.enable = true;

  # dconf daemon — needed for home-manager's dconf.settings (color-scheme
  # preference for cross-toolkit dark mode).
  programs.dconf.enable = true;

  ###########################################################################
  ## SSH — key-only, no root, no passwords (this is our remote lifeline)
  ###########################################################################
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  ###########################################################################
  ## Bluetooth (for the wireless mouse, etc.)
  ###########################################################################
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  ###########################################################################
  ## Thunderbolt / USB4 — the Apple Studio Display connects over USB4, and
  ## TB security is SL1 ("user"), so devices need authorization or the DP
  ## tunnel is torn down (~16s disconnect + DPIA AUX failures seen in dmesg).
  ## boltd manages authorization; provides `boltctl` to enroll the display.
  ###########################################################################
  services.hardware.bolt.enable = true;

  ###########################################################################
  ## Tailscale — system service, always on (auth/state restored post-install)
  ###########################################################################
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  ###########################################################################
  ## Fonts
  ###########################################################################
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  ###########################################################################
  ## System packages — desktop deps referenced by the niri config + basics
  ###########################################################################
  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    claude-code        # run the agent locally on fox
    xdg-utils          # xdg-open, so `claude` can launch the browser for auth
    # niri config spawns / binds these:
    hyprpaper
    hypridle
    hyprlock
    dunst
    brightnessctl
    wl-clipboard
    cliphist
    xwayland-satellite
    # diagnostics
    vulkan-tools
    pciutils
    usbutils
    btrfs-progs
  ];

  nixpkgs.config.allowUnfree = true;

  # Default browser so CLI tools (e.g. `claude` auth) open Firefox via xdg-open.
  environment.sessionVariables.BROWSER = "firefox";

  # Default terminal so apps that consult $TERMINAL (and xdg-terminal-exec
  # via the per-user xdg-terminals.list in home/ghostty.nix) launch ghostty.
  environment.sessionVariables.TERMINAL = "ghostty";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Let wheel users run nix without sudo prompts during setup.
  nix.settings.trusted-users = [ "root" "arne" ];
  # Binary caches:
  #   niri.cachix.org — prebuilt niri (its check-phase EGL test aborts in the
  #     build sandbox, so compiling locally fails).
  #   cache.numtide.com — prebuilt llm-agents.nix (pi, claude-code, codex, …).
  nix.settings.extra-substituters = [
    "https://niri.cachix.org"
    "https://cache.numtide.com"
  ];
  nix.settings.extra-trusted-public-keys = [
    "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];

  # First release installed against. Do NOT bump casually.
  system.stateVersion = "25.11";
}
