# Placeholder. Replaced on the target during install — `nixos-generate-config`
# produces filesystem entries from the real disk. The labels below match what
# the install runbook formats with:
#   mkfs.ext4 -L nixos /dev/nvme0n1pX     (new root, fills freed space)
#   fatlabel /dev/nvme0n1p4 EFI            (relabelled from "EFI - FEDOR")
{ ... }: {
  imports = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  nixpkgs.hostPlatform = "aarch64-linux";
}
