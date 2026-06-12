# Declarative disk layout for fismen (disko).
#
# BOOT MODE: the box boots BIOS/legacy today (verified 2026-06-12; the AMI
# firmware *supports* UEFI but flipping the mode remotely risks a dead box +
# Hetzner KVM session). So: GRUB in BIOS mode via a 1M EF02 bios_boot
# partition on EACH disk, with grub.mirroredBoots writing both /boot trees
# (see configuration.nix). The 1G vfat partitions stay typed EF00, so a later
# switch to UEFI/systemd-boot is config-only — no repartitioning.
#
# Two NVMe devices (by-id, so nvmeXnY enumeration can shuffle):
#   rpool-a — 960 GB Toshiba KXD51RUE960G: bios_boot + vfat /boot + half of
#             mirrored rpool.
#   rpool-b — 960 GB Toshiba KXD51RUE960G: bios_boot + vfat /boot-fallback +
#             other half of the mirror. GRUB is installed to both disks'
#             MBR/EF02, so the box still boots if rpool-a dies.
#
# Unlike oink there is no dedicated Incus SSD — only two disks — so container
# storage is a child dataset (rpool/incus) on the mirrored root pool. See
# hosts/fismen/incus.nix (storage_pools[].config.source = "rpool/incus").
{
  disko.devices = {
    disk = {
      rpool-a = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-KXD51RUE960G_TOSHIBA_406S10D6T7PM";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              type = "EF02"; # BIOS boot partition — GRUB core.img lands here
              size = "1M";
              priority = 1;
            };
            ESP = {
              type = "EF00";
              size = "1G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };

      rpool-b = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-KXD51RUE960G_TOSHIBA_406S10AYT7PM";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              type = "EF02";
              size = "1M";
              priority = 1;
            };
            ESP = {
              type = "EF00";
              size = "1G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot-fallback";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };

    zpool = {
      # Root pool — mirrored across both NVMe.
      rpool = {
        type = "zpool";
        mode = "mirror";
        options.ashift = "12";
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          mountpoint = "none";
          "com.sun:auto-snapshot" = "false";
        };
        datasets = {
          root = { type = "zfs_fs"; mountpoint = "/";     options.mountpoint = "legacy"; };
          nix  = { type = "zfs_fs"; mountpoint = "/nix";  options.mountpoint = "legacy"; };
          var  = { type = "zfs_fs"; mountpoint = "/var";  options.mountpoint = "legacy"; };
          home = { type = "zfs_fs"; mountpoint = "/home"; options.mountpoint = "legacy"; };

          # Incus container storage. Incus owns this dataset and creates its own
          # children (containers/, images/, virtual-machines/, …); we just carve
          # it out and hand it over (mountpoint none). Referenced as the
          # `default` pool's source in hosts/fismen/incus.nix.
          incus = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              "com.sun:auto-snapshot" = "false";
            };
          };
        };
      };
    };
  };
}
