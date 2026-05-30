{ ... }:

{
  # Shared git identity + defaults (imported by every host's home.nix).
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
}
