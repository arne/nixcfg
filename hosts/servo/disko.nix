# Declarative disk layout for servo (disko).
#
# Single 256 GB Samsung NVMe, UEFI boot (systemd-boot on the ESP). Home box —
# no mirror, no ZFS: a plain GPT layout with an ESP, a swap partition, and an
# ext4 root, matching what the box ran under Debian.
#
# The external USB Seagate BUP (labelled "form", ~3.6 TB, our media/photo
# archive) is DELIBERATELY not listed here. Disko only touches the devices it
# owns, so omission is the safeguard — the drive stays untouched during install
# and is mounted read-write at /mnt/form by configuration.nix with `nofail`
# (boot must not block if the USB cable is out).
{
  disko.devices = {
    disk = {
      nvme = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZVLB256HAHQ-00000_S444NB0K553476";
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
            swap = {
              size = "16G";
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = false;
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
