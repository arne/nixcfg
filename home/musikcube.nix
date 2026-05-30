{ config, pkgs, lib, ... }:

{
  # musikcube — terminal music player. The package was previously a bare
  # entry in fox's home.packages; it lives here now so the app and its
  # config travel together.
  home.packages = [ pkgs.musikcube ];

  # Config ported verbatim from the backup. `settings.json` selects the
  # custom "bases" colour theme (plus the ★/· rating chars and a few
  # appearance flags); `themes/bases.json` is the theme itself.
  #
  # Note: musikcube rewrites settings.json when you change a setting in the
  # TUI, but home-manager owns it as a read-only store symlink — so adjust
  # settings by editing this file, not in-app. The live regenerated copy is
  # backed up to settings.json.hm-bak on first switch (backupFileExtension).
  xdg.configFile."musikcube/settings.json".source =
    ../files/musikcube/settings.json;
  xdg.configFile."musikcube/themes/bases.json".source =
    ../files/musikcube/themes/bases.json;
}
