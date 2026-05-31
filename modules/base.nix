{ pkgs, inputs, ... }:

{
  imports = [ ./motd.nix ./tailscale.nix ./ssh-keys.nix ];

  nixpkgs.config.allowUnfree = true;

  # Editor: helix everywhere, never nano.
  #   - EDITOR/VISUAL point at helix so $EDITOR-respecting tools (sops edit,
  #     systemctl edit, crontab -e, git commit, visudo, …) open hx. Absolute
  #     store path, not bare "hx", so it resolves in root/sudo/sops contexts
  #     where the home-manager profile isn't on PATH. (helix itself stays an
  #     HM app — this only references the store path, it doesn't add hx to PATH.)
  #   - nano comes solely from programs.nano.enable (default true) in 25.11;
  #     disabling it removes the binary entirely, so nano can't be a fallback.
  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
    VISUAL = "${pkgs.helix}/bin/hx";
  };
  programs.nano.enable = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Let wheel users run nix without sudo prompts during setup.
  nix.settings.trusted-users = [ "root" "arne" ];

  # cache.numtide.com — prebuilt llm-agents.nix (pi, claude-code, codex, …),
  # rebuilt daily. Shared by every host (extra-substituters merges, so hosts
  # can add their own caches on top).
  nix.settings.extra-substituters = [ "https://cache.numtide.com" ];
  nix.settings.extra-trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];

  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    htop
    btop
    python3
    go
    jq                                # used by ~/.claude/statusline-command.sh (and generally useful)
    nh                                # nicer nixos-rebuild wrapper (diffs, gc helpers)
    (callPackage ../pkgs/forge.nix { })
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code  # numtide, rebuilt daily; cached at cache.numtide.com (see substituters above)
    # motd binary + global config/greeting live in ./motd.nix.
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
