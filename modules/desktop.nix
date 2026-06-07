{ config, pkgs, lib, inputs, ... }:

# Shared Wayland/niri desktop surface for the interactive workstation hosts
# (air, fox). Imported from each of their configuration.nix; oink (headless
# server) deliberately does NOT import this — it has no GUI.
#
# Everything here is identical across air and fox. Genuinely host-specific
# desktop bits stay in the per-host configuration.nix:
#   - greetd login policy (air: tuigreet prompt; fox: autologin, because the
#     tiled+DSC Studio Display can't render a console greeter)
#   - graphics/hardware (fox amdgpu + 32-bit ALSA; air gets Mesa from the
#     apple-silicon module)
#   - keyd (air); VIA udev + bolt + hyprlock PAM (fox)

{
  # niri compositor — module + session come from sodiboo's flake, reached via
  # specialArgs.inputs. Pin to niri-unstable: the backup config.kdl uses
  # 2026-era features (background-effect, maximize-window-to-edges) absent from
  # the 25.08-stable output.
  imports = [ inputs.niri.nixosModules.niri ];

  programs.niri.enable = true;
  programs.niri.package =
    inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;

  # Portals — without xdg.portal.config, niri doesn't know which backend handles
  # each interface, so GTK FileChooser requests fall through to xdg-open (which
  # launches whatever handles inode/directory). Force gtk for everything.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.niri.default = [ "gtk" ];
  };

  # PipeWire audio. fox additionally sets services.pipewire.alsa.support32Bit in
  # its own config (32-bit ALSA plugin for Steam/Proton — only meaningful with
  # x86 enable32Bit graphics, and it can't evaluate on aarch64, so it must NOT
  # live in this shared module that air also imports).
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Polkit + dconf — needed by the greetd/niri session and home-manager's
  # dconf.settings (cross-toolkit dark mode).
  security.polkit.enable = true;
  programs.dconf.enable = true;

  # Bluetooth (wireless mouse / peripherals).
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    ibm-plex            # IBM Plex Sans — dunst notification font (home/dunst.nix)
    noto-fonts
    noto-fonts-color-emoji
  ];

  # Desktop deps referenced by the niri config + Wayland clipboard/diagnostics.
  # (hyprpaper/hypridle/hyprlock/dunst are per-user — they live in home-manager.)
  environment.systemPackages = with pkgs; [
    xdg-utils          # xdg-open, so `claude` etc. can launch the browser
    brightnessctl
    wl-clipboard       # also backs the `clip` fish function (home/fish.nix)
    cliphist
    xwayland-satellite
    vulkan-tools
    pciutils
    usbutils
    btrfs-progs
  ];

  environment.sessionVariables.BROWSER = "firefox";
  environment.sessionVariables.TERMINAL = "ghostty";

  # Prebuilt niri from its cachix (its check-phase EGL test aborts in the build
  # sandbox, so compiling locally fails). air layers the apple-silicon cache on
  # top in its own config; the lists merge.
  nix.settings.extra-substituters = [ "https://niri.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
  ];
}
