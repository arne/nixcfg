{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/base.nix
    ../../modules/desktop.nix
    ./llama.nix
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
  ## Networking — hostname `fox`, NetworkManager (Wi-Fi profile "Boksen"
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
    # SSH keys come from the shared list in modules/ssh-keys.nix (config.mine.sshKeys).
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
  ## Desktop — niri (enabled in modules/desktop.nix) behind greetd
  ###########################################################################
  services.greetd = {
    enable = true;
    settings = {
      # tuigreet on the console, gating niri behind a real login. The previous
      # autologin worked around "fbcon can't render on the tiled+DSC display" —
      # no longer true: on kernel 7.0+ the panel negotiates single-stream 5K
      # via DSC and fbcon binds to amdgpudrmfb at 5120x2880 (verified
      # 2026-06-13), so a console greeter renders fine. Sessions started
      # through the greeter are real user sessions, so logind lock (hypridle's
      # idle/sleep locking) works without the old initial_session contortion.
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # fbcon runs at native 5K — the default console font is unreadably small
  # there. Terminus at 32px keeps the VTs (and tuigreet) legible.
  console = {
    packages = [ pkgs.terminus_font ];
    font = "ter-132n";
    earlySetup = true;
  };

  # The shared Wayland desktop surface (niri, xdg.portal, PipeWire base, polkit,
  # dconf, fonts, GUI packages) lives in modules/desktop.nix. fox only adds the
  # 32-bit ALSA plugin on top — Steam/Proton need it, and it's x86-only (needs
  # enable32Bit graphics), so it can't live in the module that air also imports.
  services.pipewire.alsa.support32Bit = true;

  # PAM service for hyprlock. nixpkgs ships a default security.pam.services
  # entry for swaylock but NOT for hyprlock, and home-manager's
  # programs.hyprlock only writes the config — it can't create system PAM.
  # Without /etc/pam.d/hyprlock, PAM auth always fails: you can lock the
  # screen but never unlock it (the typed password is rejected). This gives
  # hyprlock the standard pam_unix stack, same as swaylock.
  security.pam.services.hyprlock = {};

  ###########################################################################
  ## Input peripherals — VIA/QMK keyboard access
  ###########################################################################
  # wilba.tech WT65-H3 (6582:0036): VIA reconfigures the board over its raw-HID
  # interface (/dev/hidrawN). Those nodes are root-only by default, so Chromium's
  # WebHID fails with "NotAllowedError: Failed to open the device" (and then reads
  # garbage → "invalid protocol version"). uaccess grants the active-seat user an
  # ACL on the device — the same mechanism that already opens the YubiKey.
  #
  # NOTE: this MUST be a < 73-numbered rules file. `services.udev.extraRules`
  # lands in 99-local.rules, which runs AFTER systemd's 73-seat-late.rules where
  # the `uaccess` builtin fires — so a TAG+="uaccess" set at 99 is applied too
  # late and no ACL appears. Shipping it as a package at 60- fixes the ordering.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "via-wt65h3-udev-rules";
      destination = "/lib/udev/rules.d/60-via.rules";
      text = ''
        KERNEL=="hidraw*", ATTRS{idVendor}=="6582", ATTRS{idProduct}=="0036", TAG+="uaccess"
      '';
    })
  ];

  # programs.dconf.enable is set in modules/desktop.nix.

  ###########################################################################
  ## SSH — key-only, no root, no passwords (this is our remote lifeline)
  ###########################################################################
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  # hardware.bluetooth (wireless mouse, etc.) is enabled in modules/desktop.nix.

  ###########################################################################
  ## Thunderbolt / USB4 — the Apple Studio Display connects over USB4, and
  ## TB security is SL1 ("user"), so devices need authorization or the DP
  ## tunnel is torn down (~16s disconnect + DPIA AUX failures seen in dmesg).
  ## boltd manages authorization; provides `boltctl` to enroll the display.
  ###########################################################################
  services.hardware.bolt.enable = true;

  # Tailscale lives in modules/tailscale.nix (shared via base.nix).

  # Fonts, the Wayland/desktop system packages, and the BROWSER/TERMINAL
  # defaults are shared via modules/desktop.nix. nix experimental-features /
  # trusted-users / the numtide cache are shared via modules/base.nix.

  # Garbage-collect generations older than 14 days, weekly. `persistent` makes
  # the timer catch up if the box is off when it would normally fire.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
    persistent = true;
  };
  # Hardlink identical store paths after each build to save disk.
  nix.optimise.automatic = true;

  # Binary caches: niri.cachix.org is added by modules/desktop.nix; the numtide
  # cache is shared via modules/base.nix.

  # First release installed against. Do NOT bump casually.
  system.stateVersion = "25.11";
}
