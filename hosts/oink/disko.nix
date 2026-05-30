# Declarative disk layout for oink (disko).
#
# Three SATA devices are managed (by-id, so Linux sdX letters can shuffle):
#   rpool-a — 1 TB Crucial MX500 SSD, ESP + half of mirrored rpool.
#   rpool-b — 1 TB Crucial MX500 SSD, ESP (fallback) + half of mirrored rpool.
#             The fallback ESP is kept in sync by systemd-boot's mirroredBoots
#             (see hosts/oink/configuration.nix) so the box still boots if
#             rpool-a dies.
#   tank    — 8 TB Seagate HDD, single-disk data pool.
{
  disko.devices = {
    disk = {
      rpool-a = {
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

      rpool-b = {
        type = "disk";
        device = "/dev/disk/by-id/ata-CT1000MX500SSD1_1927E210DE32";
        content = {
          type = "gpt";
          partitions = {
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

      tank = {
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
      # Root pool — mirrored across rpool-a and rpool-b.
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
