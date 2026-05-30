# Declarative disk layout for oink (disko).
#
# IMPORTANT: only sdb (root SSD) and sdc (data HDD) are referenced here. The
# fourth disk, sdd (ata-CT1000MX500SSD1_1927E210DE32), holds the original
# Debian install and is DELIBERATELY ABSENT so disko never touches it — it
# stays bootable as the remote-recovery fallback. sda (the 250 GB SSD) is also
# left untouched/spare for now (future tank L2ARC / special vdev).
#
# Root starts as a single-disk rpool on sdb. Once NixOS is trusted and Debian
# is no longer needed, sdd can be wiped and `zpool attach`ed to mirror rpool.
{
  disko.devices = {
    disk = {
      # sdb — 1 TB Crucial MX500: ESP + rpool (system root)
      sdb = {
        type = "disk";
        device = "/dev/disk/by-id/ata-CT1000MX500SSD1_2022E2A66015";
        content = {
          type = "gpt";
          partitions = {
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

      # sdc — 8 TB Seagate HDD: tank (data)
      sdc = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST8000DM004-2CX188_ZCT02K74";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "tank";
              };
            };
          };
        };
      };
    };

    zpool = {
      # Root pool — single vdev (no redundancy until sdd is attached later).
      rpool = {
        type = "zpool";
        mode = "";
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
        };
      };

      # Data pool — single 8 TB HDD.
      tank = {
        type = "zpool";
        mode = "";
        options.ashift = "12";
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          mountpoint = "none";
        };
        datasets = {
          data = { type = "zfs_fs"; mountpoint = "/tank"; options.mountpoint = "legacy"; };
        };
      };
    };
  };
}
