{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    python3
    go
    jq                                # used by ~/.claude/statusline-command.sh (and generally useful)
    nh                                # nicer nixos-rebuild wrapper (diffs, gc helpers)
    (callPackage ../pkgs/forge.nix { })
    (callPackage ../pkgs/motd.nix { })
  ];

  # nix-ld — provide a stock dynamic loader at /lib64/ld-linux-x86-64.so.2 so
  # vendor-distributed Linux binaries (pip wheels, prebuilt CLIs, install
  # scripts) run without patchelf/buildFHSUserEnv. The library set below is
  # the usual suspects scripts dlopen at runtime.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
      curl
      glib
      libxml2
    ];
  };
}
