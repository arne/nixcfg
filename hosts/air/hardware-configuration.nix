# Placeholder. Generate on the target with:
#   nixos-generate-config --root /mnt --show-hardware-config > hardware-configuration.nix
# after the Asahi installer has partitioned (typically a 500 MiB EFI vfat + a
# btrfs root). Commit the generated file in its place.
{ ... }: {
  imports = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "btrfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };

  nixpkgs.hostPlatform = "aarch64-linux";
}
