{ config, pkgs, lib, ... }:

{
  programs.firefox = {
    enable = true;

    profiles.default = {
      id = 0;
      isDefault = true;

      settings = {
        "browser.link.open_newwindow" = 2;
        "browser.link.open_newwindow.restriction" = 0;
        "browser.tabs.opentabfor.middleclick" = false;
        "browser.tabs.loadBookmarksInTabs" = false;
        "browser.tabs.loadInBackground" = false;

        "browser.aboutwelcome.enabled" = false;
        "browser.shell.checkDefaultBrowser" = false;

        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
        "ui.systemUsesDarkTheme" = 1;
        "layout.css.prefers-color-scheme.content-override" = 0;
      };

      userChrome = ''
        #TabsToolbar { visibility: collapse !important; }
      '';

      search = {
        default = "Google";
        force = true;
      };
    };
  };
}
