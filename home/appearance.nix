{ config, pkgs, lib, ... }:

{
  # Cross-toolkit dark preference. Read by xdg-desktop-portal and surfaced to
  # GTK4 / Qt6 apps and webpages (via prefers-color-scheme).
  dconf.settings = {
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  # GTK3 doesn't read the portal preference; it needs an explicit hint, and
  # the dark Adwaita variant must be installed for it to resolve.
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  # Qt apps follow GTK via the adwaita platform theme.
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };
}
