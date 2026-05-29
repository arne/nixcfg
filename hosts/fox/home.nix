{ config, pkgs, lib, ... }:

{
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user.name = "Arne Skaar Fismen";
      user.email = "arnefismen@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "hx";
    };
  };

  home.packages = with pkgs; [
    gh
  ];
}
