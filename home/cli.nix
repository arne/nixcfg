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
  programs.bat.enable = true;

  # zoxide — the "smart cd". `--cmd cd` replaces `cd` itself, so plain `cd foo`
  # jumps to a frecent match; `cdi` is the interactive picker. Fish integration
  # is automatic.
  programs.zoxide = {
    enable = true;
    options = [ "--cmd cd" ];
  };

  # nix-index + comma — `, foo` runs `foo` from nixpkgs in a throwaway shell
  # without installing it. The prebuilt index (nix-index-database flake) means
  # it works immediately; no `nix-index` build needed. nix-index also provides
  # a command-not-found handler that suggests the right package/`,` invocation.
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
}
