# Hardware baseline for roar (bare-metal, Intel i5-1235U, UEFI, ZFS root).
# Same shape as oink: `nixos-generate-config --no-filesystems` (disko owns
# fileSystems), then ZFS support + a fixed hostId added by hand.
#
# hostId is REUSED from the Debian install (42c68340) so the pre-existing data
# pools `fast` and `storage` import without -f. The root pool is force-imported
# by the initrd regardless (boot.zfs.forceImportRoot, default true).
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # ZFS — root imported by the initrd; the two data pools imported at boot by
  # extraPools. Their datasets carry native mountpoints (fast/photos →
  # /storage/photos, etc.), so `zfs mount -a` places them; nothing to declare
  # in fileSystems.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/disk/by-id";
  boot.zfs.extraPools = [ "fast" "storage" ];
  networking.hostId = "42c68340";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
