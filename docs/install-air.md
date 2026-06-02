# Installing NixOS on `air` (Path B: reuse Fedora's stub/ESP)

This runbook covers installing NixOS on the Apple Silicon MacBook Air via
GRUB-loopback of the upstream installer ISO, reusing the Asahi UEFI
environment that Fedora's Asahi installer set up. End state:
**macOS + NixOS bootable, Fedora unbootable** (its filesystem data is
gone — partitions p5 and p6 are wiped).

## Read this whole document once before starting.

There is one mandatory stop point partway through (step 3) where you should
verify the partition layout before doing anything destructive. After that
point Fedora is gone.

---

## Pre-install (already done if you're following along)

- `/boot/nixos-installer.iso` exists (542 MiB, downloaded from the
  nix-community/nixos-apple-silicon release).
- `/etc/grub.d/40_custom` has the `NixOS Apple Silicon installer (ISO loopback)`
  entry with `set iso_path=$isofile`.
- `/var/lib/nixos-install-backup/` has a tar of the ESP and a copy of
  `grubenv`, in case we need to roll back.
- The `air-scaffold` branch of `arne/nixcfg` has the air host scaffold,
  the `nix-community` apple-silicon URL, and the ext4
  hardware-configuration.nix placeholder. Peripheral firmware is read
  impurely from `/boot/asahi` at build time — no firmware blobs in git.

## macOS safety check

Power off cleanly, hold the power button to enter the Apple boot picker,
pick macOS, log in, confirm it works, shut down. Last chance to verify the
parachute before we wipe Fedora.

---

## Step 1 — boot the installer

Reboot into Fedora's GRUB → pick **NixOS Apple Silicon installer (ISO loopback)**.
You'll land at a `nixos@nixos$` prompt.

```sh
sudo -i                     # root
setfont ter-v32n            # bigger console font (optional)
```

## Step 2 — Wi-Fi + time

```sh
iwctl
# inside iwctl:
station wlan0 scan
station wlan0 get-networks
station wlan0 connect <YOUR-SSID>
# passphrase prompt
station wlan0 show          # confirm "connected"
exit

systemctl restart systemd-timesyncd
ping -c2 github.com         # sanity check
```

## Step 3 — verify partitions (STOP — confirm before continuing)

```sh
sgdisk /dev/nvme0n1 -p
```

Expected layout:

| # | Code | Name                    | Notes                              |
|---|------|-------------------------|------------------------------------|
| 1 | FFFF | iBootSystemContainer    | Apple boot stub. **Never touch.**  |
| 2 | AF0A | Container               | macOS APFS. Untouched.             |
| 3 | AF0A | (empty)                 | macOS recovery. Untouched.         |
| 4 | EF00 | (empty)                 | ESP. Shared with NixOS.            |
| 5 | (8300) | (empty)               | Fedora `/boot`. **Will be deleted.** |
| 6 | (8300) | (empty)               | Fedora btrfs root. **Will be deleted.** |
| 7 (or last) | FFFF | RecoveryOSContainer | Apple recovery. **Never touch.** |

Confirm numbers match before proceeding. If they don't, pause and reconsider —
do not run the next commands until the layout matches.

## Step 4 — partition (DESTRUCTIVE)

```sh
sgdisk /dev/nvme0n1 -d 6 -d 5                       # delete Fedora btrfs + /boot
sgdisk /dev/nvme0n1 -n 0:0:0 -t 0:8300 -c 0:nixos   # one new partition filling freed space
sgdisk /dev/nvme0n1 -p                              # verify: new p5 is ~110 GiB, type 8300
partprobe /dev/nvme0n1
```

## Step 5 — format + relabel

```sh
mkfs.ext4 -L nixos /dev/nvme0n1p5
fatlabel /dev/nvme0n1p4 EFI                         # was "EFI - FEDOR"
```

## Step 6 — mount

```sh
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/EFI /mnt/boot
ls /mnt/boot/                                       # expect: asahi/ EFI/ m1n1/ vendorfw/ ubootefi.var
```

## Step 7 — clean Fedora's GRUB out of the ESP

Keep `asahi/`, `m1n1/`, `vendorfw/`, `ubootefi.var` — that's the boot chain
m1n1 → U-Boot → UEFI. Only nuke Fedora's GRUB binaries:

```sh
rm -rf /mnt/boot/EFI/fedora /mnt/boot/EFI/BOOT
rm -rf /mnt/boot/grub2 /mnt/boot/loader            # only if present
ls /mnt/boot/                                       # asahi/ m1n1/ vendorfw/ ubootefi.var must still be there
```

systemd-boot will install itself into `EFI/BOOT/` and `loader/` during
`nixos-install`.

## Step 8 — clone the flake

```sh
nix-shell -p git
# you are now in a sub-shell with git available
git clone https://github.com/arne/nixcfg /mnt/etc/nixos
```

No firmware copying needed: the config doesn't pin
`hardware.asahi.peripheralFirmwareDirectory`, so the apple-silicon module
reads its default location — here `/mnt/boot/asahi` (the mounted ESP) — at
build time. That's an absolute path outside the flake, so the build runs
impure (`--impure` below). The firmware never enters the repo.

## Step 9 — install

```sh
nixos-install --flake /mnt/etc/nixos#air --no-channel-copy --impure
```

Expect a long wait. The flake doesn't have the apple-silicon binary cache
configured (TODO comment in `hosts/air/configuration.nix`), so it'll compile
the Asahi kernel locally — likely 30–60 min on M2 Air. If you want the
cache added first, exit the shell, ping for the substituter URL+key, and
re-run.

You'll be prompted for a **root password** near the end. Pick something
memorable; you'll need it for first login if niri/greetd doesn't come up
cleanly.

## Step 10 — reboot

```sh
exit          # leave the nix-shell
reboot
```

m1n1 → U-Boot → UEFI → systemd-boot → NixOS. To pick between macOS and
NixOS, hold the power button at boot for the Apple boot picker.

---

## First boot

- Log in as `arne` with `changeme` (from `users.users.arne.initialPassword`
  in `hosts/air/configuration.nix`). Run `passwd` immediately.
- niri should start via greetd → niri-session.
- sshd is enabled and keyed (your `id_ed25519` from `modules/ssh-keys.nix`),
  so if the GUI doesn't come up you can ssh in from another device.

## If something goes wrong

- **First boot lands at a TTY, not niri:** `journalctl -b -u greetd`,
  `journalctl -b | grep -i niri`. ssh in from another device is often
  easier than typing at the console.
- **Wi-Fi doesn't connect on first boot:** the apple-silicon firmware
  copy may have failed. Compare `/lib/firmware/vendor/asahi/` against the
  ESP's `/boot/asahi/`.
- **Kernel won't build:** add the apple-silicon binary cache substituter
  and rebuild. See `docs/binary-cache.md` in the nix-community/nixos-apple-silicon
  repo.
- **NixOS won't boot at all (m1n1 hands off to nothing):** boot macOS,
  re-run the Asahi installer's "UEFI environment only" option to rebuild
  the chain. Your data on the new p5 ext4 partition survives.
