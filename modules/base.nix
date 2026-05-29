{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python3
    go
    nh                                # nicer nixos-rebuild wrapper (diffs, gc helpers)
    (callPackage ../pkgs/forge.nix { })
    (callPackage ../pkgs/motd.nix { })
  ];
}
