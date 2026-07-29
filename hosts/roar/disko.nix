# Declarative disk layout for roar (disko).
#
# disko owns EXACTLY ONE device — the Kingston OS NVMe (nvme2n1), addressed
# by-id so a Linux nvmeXnY renumber can't retarget it. The data pools live on
# OTHER disks and are deliberately NOT declared here (disko would try to
# create/wipe them); they are imported via boot.zfs.extraPools instead:
#   fast    — nvme0n1 + nvme1n1 mirror  (/storage/media, /storage/photos)
#   storage — sda/sdb/sdc raidz1        (bulk data)
#
# Root is ZFS (pool `rpool`, single disk, no redundancy — the OS is rebuildable
# from this flake; data redundancy lives on fast/storage).
{
  disko.devices = {
    disk = {
      os = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP41024Q-A0_50026B7382FAA119";
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
    };

    zpool = {
      rpool = {
        type = "zpool";
        mode = "";                    # single disk — no mirror/raidz
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
    };
  };
}
