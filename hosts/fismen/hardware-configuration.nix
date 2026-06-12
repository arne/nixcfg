# Hardware baseline for fismen (Hetzner dedicated, ASUS board, Intel Xeon
# E-2276G, 2× NVMe). Generated with `nixos-generate-config --no-filesystems`
# (disko owns the fileSystems), then ZFS support + a fixed hostId added by hand.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "ahci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # ZFS — root pool is imported by stable /dev/disk/by-id paths. hostId must be
  # fixed AND match the id the pool was created under, or ZFS won't auto-import
  # root. Run `zgenhostid -f f15e0a01` before disko at install time.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/disk/by-id";
  networking.hostId = "f15e0a01";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
