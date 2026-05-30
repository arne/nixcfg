# Hardware baseline for oink (HP ProLiant, SATA/AHCI, Intel CPU).
# Generated with `nixos-generate-config --no-filesystems` (disko owns the
# fileSystems), then ZFS support + a fixed hostId were added by hand.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # ZFS — root + data pools are imported by stable /dev/disk/by-id paths.
  # hostId must be fixed (and must match the id the pool was created under) or
  # ZFS won't auto-import root. The pool is created under this same id (see the
  # install runbook: `zgenhostid -f 3711cc5f` before disko).
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/disk/by-id";
  networking.hostId = "3711cc5f";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
