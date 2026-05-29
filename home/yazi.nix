{ ... }:

{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
  };

  # Override upstream yazi.desktop. The packaged entry has Terminal=true,
  # which GTK apps (e.g. Nicotine+) can't resolve without a configured default
  # terminal emulator and so fall back to Firefox for inode/directory. Embed
  # ghostty directly via -e so xdg-open / GIO can launch it without that step.
  xdg.desktopEntries.yazi = {
    name = "Yazi";
    comment = "Blazing fast terminal file manager";
    icon = "yazi";
    exec = "ghostty -e yazi %f";
    terminal = false;
    type = "Application";
    mimeType = [ "inode/directory" ];
    categories = [ "Utility" "FileTools" "FileManager" ];
  };
}
