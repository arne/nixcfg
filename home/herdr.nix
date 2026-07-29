{ ... }:

{
  # herdr — terminal workspace manager / agent multiplexer. The binary is
  # installed system-wide in modules/base.nix (so it's there for root and for
  # `ssh host herdr` too); this module only ships arne's config.
  #
  # The config deliberately tracks home/tmux.nix: same C-a prefix, same split
  # keys, same bases palette. Divergences and the things herdr has no
  # equivalent for are documented inline in the toml.
  #
  # Kept as a plain .toml rather than generated from Nix attrs so it lines up
  # 1:1 with `herdr --default-config` and the upstream docs. Validate edits
  # with `herdr config check`; apply them to a running server with
  # `herdr server reload-config`.
  xdg.configFile."herdr/config.toml".source = ../files/herdr/config.toml;
}
