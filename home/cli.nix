{ ... }:

{
  # Shared CLI tooling for every host (imported by both fox and oink home.nix).
  # fish/helix/yazi live in their own modules; this is the smaller stuff that
  # mostly just wants `enable = true` plus shell integration. Fish is HM-managed
  # (see ./fish.nix), so each program's fish hooks wire themselves in.

  # tmux is a full module (prefix, themes, keybinds); pull it in here so every
  # host gets it, not just fox.
  imports = [ ./tmux.nix ];

  # GitHub CLI.
  programs.gh.enable = true;

  # bat — `cat` with syntax highlighting (command is `bat`, not Debian's
  # `batcat`). Also backs helix/yazi previews if they reach for it.
  #
  # theme = "ansi": highlight with the terminal's 16 ANSI colors, which ghostty
  # maps to the bases palette (0–15). bat tracks bases for free this way — dark
  # and light both — with no separate tmTheme file to maintain.
  programs.bat = {
    enable = true;
    config.theme = "ansi";
  };

  # `cat` → bat. bat auto-detects a non-terminal stdout and falls back to plain,
  # un-paged output, so `cat f | grep x` and redirects still behave like real cat.
  programs.fish.shellAliases.cat = "bat";

  # Use bat as the pager. For man pages, col strips the overstrike backspaces and
  # MANROFFOPT=-c keeps groff output plain so bat renders them cleanly. (bat
  # guards against PAGER=bat recursion by falling back to less for its own paging.)
  home.sessionVariables = {
    PAGER = "bat";
    MANPAGER = "sh -c 'col -bx | bat --language man --plain'";
    MANROFFOPT = "-c";
  };

  # zoxide — the "smart cd". `--cmd cd` replaces `cd` itself, so plain `cd foo`
  # jumps to a frecent match; `cdi` is the interactive picker. Fish integration
  # is automatic.
  programs.zoxide = {
    enable = true;
    options = [ "--cmd cd" ];
  };

  # fzf — fuzzy finder. The fish integration installs three key bindings:
  #   Ctrl-R  fuzzy-search shell history
  #   Ctrl-T  fuzzy-pick file(s)/dir(s) into the command line (with a bat preview)
  #   Alt-C   fuzzy-pick a directory and cd into it
  # It also backs zoxide's interactive `cdi` picker. Colors come from the
  # terminal's ANSI palette (= bases), same trick as bat's ansi theme.
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultOptions = [ "--height=40%" "--layout=reverse" "--border" ];
    fileWidgetOptions = [ "--preview 'bat --color=always --style=numbers --line-range=:500 {}'" ];
  };

  # nix-index + comma — `, foo` runs `foo` from nixpkgs in a throwaway shell
  # without installing it. The prebuilt index (nix-index-database flake) means
  # it works immediately; no `nix-index` build needed. nix-index also provides
  # a command-not-found handler that suggests the right package/`,` invocation.
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
}
