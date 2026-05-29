{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python3
    go
    (callPackage ../pkgs/forge.nix { })
    (callPackage ../pkgs/motd.nix { })
  ];
}
