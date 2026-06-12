# fismen → NixOS migration — inventory + runbook log

Phase 0 pre-flight inventory, captured 2026-06-12 on the live host.
Plan: move everything to oink in the interim, reinstall fismen with
nixos-anywhere + disko, move back. See the repo commits tagged
FISMEN-INTERIM for the temporary oink config.

## Live host (Debian 13 trixie, kernel 6.12.74+deb13)

- Hetzner dedicated, ASUS WS C246 DC, Xeon E-2276G (12 threads), 62 GiB RAM.
- 2× NVMe `nvme-KXD51RUE960G_TOSHIBA_406S10D6T7PM` / `..._406S10AYT7PM`
  (matches disko.nix). Current layout: mdraid1 ×3 (32G swap, 1G /boot,
  861G ext4 root). **Boots BIOS/legacy today; firmware reports "UEFI is
  supported"** (AMI 0803, 05/2021).
- WAN eno1: MAC `d4:5d:64:41:5b:d6`, `135.181.130.98/26` gw `135.181.130.65`,
  `2a01:4f9:4b:2141::2/64` (Hetzner v6 gw `fe80::1` — verify at install).
- Tailnet IP `100.86.115.86` (will change on reinstall).
- Listeners on public/tailnet IPs: sshd :22, caddy :80/:443 (+ :443/udp),
  tailscaled, dnsmasq on incusbr0, caddy admin `10.228.107.1:2019`,
  bbs :2222 (when healthy — see below). **No SMTP/IMAP — no mail hosted here.**
- No custom cron, no DNAT rules, nothing drives the caddy admin API
  (the WARNING in the stock unit says API changes aren't persisted anyway).

## Host-level services

| service | detail |
|---|---|
| caddy | v2.11.2 + caddy-dns/cloudflare **v0.2.3**; config /etc/caddy/Caddyfile; env file /etc/caddy/secrets/cloudflare-token (`CLOUDFLARE_API_TOKEN=...`, root:root 600); storage `/var/lib/caddy/.local/share/caddy` (1.2 MB; certificates/ + acme/ + locks/) |
| nyheter | /opt/nyheter/nyheter-server (Go binary, arne-built); sqlite db ~950 MB (+wal/shm) in /opt/nyheter; User=nobody; env: `DATABASE_PATH`, `LISTEN_ADDR=127.0.0.1:8083`, `OLLAMA_URL=http://100.121.19.125:11434` (host `cube`), OIDC client id/secret in override `oidc.conf` → **goes to sops** |
| bbs | /usr/local/bin/bbs; env `BBS_ADDR=:2222`, `BBS_DB=/var/lib/bbs/bbs.db`, `BBS_HOST_KEY=/var/lib/bbs/host_key`, `BBS_NAME=THE BBS`; **crash-looping since Mar 12** — /var/lib/bbs is root:root 700 but unit runs User=bbs (fix: chown -R bbs:bbs). Host key must migrate (known_hosts continuity). Firewall needs :2222 |
| beszel-agent | /opt/beszel-agent/beszel-agent; PORT=45876, KEY+TOKEN in unit (→ sops), HUB_URL=https://monitor.fismen.no (the beszel instance) |
| news | /opt/news (news-server + news.db) — unit **disabled**, not migrated |

## Incus (zabbly stable 1:6.23, server+client)

Pool `default`: **dir** driver on the ext4 root, 83.17 GiB used.
Bridge incusbr0 `10.228.107.1/24` + ULA `fd42:4920:83b2:cb09::1/64`.
Single profile `default`. **No instance pins its IP — all DHCP leases.**
Pin every instance on copy with the addresses below.

32 instances (30 containers, 2 VMs):

| instance | IP (pin this) | notes |
|---|---|---|
| a | 10.228.107.204 | |
| abase | 10.228.107.104 | **VM**; nested incus + tailscale (100.110.176.128); serves a.bas.es |
| auth | 10.228.107.231 | |
| b | 10.228.107.137 | |
| bases-dev | 10.228.107.167 | dev.bas.es |
| beszel | 10.228.107.118 | monitor hub |
| blog | 10.228.107.175 | disk: /var/www/arne → /var/www/arne |
| bookmarks | 10.228.107.77 | |
| burball | 10.228.107.59 | disk: /var/lib/burball → /opt/burball/data; proxy device tcp:127.0.0.1:8080 ↔ container :8080 |
| cal | 10.228.107.79 | |
| chat-posta | 10.228.107.208 | |
| clips | 10.228.107.49 | |
| coffee | 10.228.107.111 | |
| comet | 10.228.107.218 | tun device (tailscale inside, 100.78.135.48) |
| filebrowser | 10.228.107.67 | disk: /srv/media → /media (4 KB — near-empty) |
| gatus | 10.228.107.102 | |
| glance | 10.228.107.196 | fismen.no frontpage |
| keys | 10.228.107.29 | |
| marki | 10.228.107.122 | disk: /srv/docs → /srv/docs (632 KB) |
| martin | 10.228.107.200 | **VM**, root size 20GiB; nested incus |
| msg-web | 10.228.107.173 | vhost msg.fismen.no REMOVED from live Caddyfile — confirm before migrating |
| orbit | 10.228.107.78 | tun device (tailscale inside, 100.75.77.28) |
| outline | 10.228.107.254 | |
| posta | 10.228.107.168 | arne/marcus/tarald/oystein.posta.no |
| posta-web | 10.228.107.240 | posta.no |
| themes | 10.228.107.116 | disk: /var/www/themebases → /srv/site |
| tinyauth | 10.228.107.250 | forward_auth backend — move in wave 1 |
| tjue | 10.228.107.2 | |
| tjue-preview | 10.228.107.74 | |
| tp | 10.228.107.103 | trappeprodusenten.no |
| tv | 10.228.107.136 | |
| vaultwarden | 10.228.107.31 | vault.fismen.no (tailnet-bind) |

Host paths mounted into instances (all tiny; rsync with the instance):
/var/www/arne (484K), /var/lib/burball (392K), /srv/media (4K),
/srv/docs (632K), /var/www/themebases (816K).

Custom storage volume: `poxy-data` on pool default — ORPHANED (used_by: []);
RETIRED per arne 2026-06-12 (deleted on oink; the fismen original dies with
the reinstall — do not recreate).

Config deltas applied to the OINK COPIES during cutover (carry these to the
new fismen on move-back — both hosts use the NixOS subuid layout
root:1000000:1000000000, so the originals' settings can't come back):
* burball: `raw.idmap: uid 100000 0` REMOVED (fismen-Debian-specific subuid
  base; newuidmap refuses it) → replaced with `shift=true` on the `data`
  disk device + host dir /var/lib/burball chowned to 0:0.
* burball: vestigial `http` proxy device (host 127.0.0.1:8080 → :8080)
  REMOVED — nothing used it, and it collided with kokosbananas' 0.0.0.0:8080
  proxy on oink. Don't restore unless something on the host needs loopback
  access to burball.

/var/www: arne 484K, bases 300K, chess 28K, lageriet 788K, nytta 1.8M,
themebases 816K, tjue 48K (unused by live Caddyfile?), totalfrihet 165M.

## Caddyfile drift

The repo copy (hosts/fismen/Caddyfile) is STALE vs live /etc/caddy/Caddyfile
(live changed ~June): live removed books/calibre/bases/msg vhosts, merged
posta.no subdomains + `bas.es basehp.fismen.no`, added a `(cf)` snippet for
the DNS-01 blocks. → repo copy refreshed from live in Phase 1.

## DNS (public audit 2026-06-12; all zones in Cloudflare, TTL 300)

- **No MX points at this host** (Cloudflare Email Routing / Protonmail).
- Grey-cloud A → 135.181.130.98: everything except the below.
- A → 100.86.115.86 (tailnet): vault.fismen.no, ai.azf.no — flip these to the
  interim/new host's TAILNET IP, not the public one.
- Cloudflare-proxied (origin swap invisible, no TTL wait): lageriet.org,
  www.lageriet.org, tjue.net, preview.tjue.net, theme.bas.es,
  trappeprodusenten.no.
- TTL lowering + flips need the CF token (on this host at
  /etc/caddy/secrets/cloudflare-token) — operator-run steps.

## Version constraints

- fismen incus 6.23 (zabbly) → oink must run incus ≥ 6.23 to receive copies.
  oink currently runs **incus-lts 6.0.6** → set
  `virtualisation.incus.package = pkgs.incus` (7.0.0 in nixpkgs 25.11).
  **One-way DB upgrade** for oink (sandbox machinery unaffected, but no
  downgrade path). New fismen must then also run `pkgs.incus` (7.0.0)
  so the move-back (oink 7.0 → fismen 7.0) works.
- oink capacity: 8 cores / 62 GiB (52 GiB is evictable ZFS ARC), incus pool
  default = 232 GiB SSD zpool with 228 GiB free → 83 GiB fleet fits;
  **no tank pool needed**.

## Boot strategy decision

Current install is BIOS/legacy; firmware supports UEFI but switching boot
mode remotely is risky (may need Hetzner KVM console if it doesn't come up).
→ decision recorded in plan discussion.

## Vhost baseline (2026-06-12, ./check-vhosts.sh)

40/44 healthy. Pre-existing breakage — do NOT chase these during migration
verification: ai.azf.no + ai.fismen.no 502 (fox upstream :8080 down),
keys.fismen.no 502 (app down inside the instance), video.fismen.no 502
(targets 10.228.107.38 — no such instance exists; dead vhost),
dev.bas.es 404 (app-level).

## Phase 2 runbook — copy instances to oink

One-time setup (DONE 2026-06-12): API bound to the PUBLIC IP for transfer
speed (tailscale's userspace WireGuard bottlenecks):
```bash
# on fismen:
incus config set core.https_address 135.181.130.98:8443
# + nft table inet incus-migration: 8443 allowed ONLY from 185.181.63.4.
incus config trust add oink            # prints a token
# on oink:
incus remote add fismen https://135.181.130.98:8443 --accept-certificate
```
DECOMMISSION (after move-back): `incus config unset core.https_address` +
`nft delete table inet incus-migration` on whichever host still has them
(fismen's copies die with the reinstall; the NixOS fismen gets its own pair
for Phase 5 — remember the same cleanup there), `incus remote remove` both.

Pre-sync (instances keep running; repeat near cutover — --refresh is
incremental). NOTE: `-d eth0,ipv4.address=...` does NOT work on copy (the
NIC is profile-inherited; -d creates a typeless new device and the copy
fails). Copy first, then `incus config device override`:
```bash
# on oink — /tmp/presync.sh does all 32 from the inventory table:
incus copy fismen:$n $n --refresh -p fismen
incus config device override $n eth0 ipv4.address=10.228.107.X \
  || incus config device set $n eth0 ipv4.address=10.228.107.X
```
After any later `--refresh`, re-check the pin before starting the instance
(refresh may resync config from source, where nothing is pinned).
Notes: instances with host-mounted disk devices (blog, burball, filebrowser,
marki, themes) need their host paths rsynced to oink at the SAME paths first,
or the copy's device source dangles. burball also has a host proxy device
(127.0.0.1:8080) — works as-is. The two VMs (abase, martin) copy as VMs;
oink must have KVM (it does).

Cutover, per wave: stop on fismen → final `incus copy --refresh` → start on
oink → flip the wave's DNS records → `./check-vhosts.sh`.
- Wave 0 (canary): chess.fismen.no (static, /var/www only — no instance).
  (Original canary nytta.fismen.no was retired 2026-06-12 — vhost removed
  from the Caddyfile; delete its DNS record + /var/www/nytta at leisure.)
- Wave 1: tinyauth (forward_auth backend for fismen.no/status.fismen.no),
  then low-risk singles (cal, clips, coffee, bookmarks, …).
- Wave 2: the posta group together (posta, posta-web, chat-posta).
- Wave 3: remainder incl. VMs; nyheter (stop on fismen, rsync /opt/nyheter →
  oink:/opt/nyheter, chown -R nyheter:nyheter, start) and bbs (rsync
  /var/lib/bbs → oink:/var/lib/bbs, binary /usr/local/bin/bbs →
  oink:/opt/bbs/bbs, chown -R bbs:bbs /var/lib/bbs).
- vault.fismen.no + ai.azf.no flip to OINK'S TAILNET IP (100.78.72.66).

Caddy storage seed (before ANY flip — do this right after oink deploys):
```bash
# on oink:
sudo rsync -a arne@100.86.115.86:/var/lib/caddy/.local/ /var/lib/caddy/.local/
sudo chown -R caddy:caddy /var/lib/caddy
sudo touch /var/lib/caddy/.storage-seeded
sudo systemctl restart caddy
# smoke test (DNS still on fismen):
./check-vhosts.sh 185.181.63.4
```
Also rsync /var/www/* → oink:/var/www/ (same paths; caddy must read them).

## Phase 4 runbook — reinstall fismen

Drive from OINK (this box will be in rescue). Repo + pre-generated host key
already staged there (/tmp/nixcfg-mig is scratch — clone properly first).
```bash
# 1. Belt-and-braces: incus export the stateful instances to /tank;
#    tarball old fismen /etc, /var/lib/caddy, /var/www, /opt to /tank.
# 2. Hetzner Robot → activate rescue → reboot fismen.
# 3. From oink:
nixos-anywhere --flake .#fismen \
  --phases kexec root@135.181.130.98
ssh root@135.181.130.98 zgenhostid -f f15e0a01   # BEFORE disko (ZFS hostId)
nixos-anywhere --flake .#fismen \
  --phases disko,install,reboot \
  --extra-files ~/fismen-install \
  root@135.181.130.98
# 4. First boot: tailscale up --advertise-exit-node; note NEW tailnet IP;
#    update the two `bind` lines in Caddyfile + the vault/ai.azf DNS records.
# 5. rsync /var/www + caddy storage oink→fismen, touch .storage-seeded.
```

## Operational notes

- The Claude session driving this ran ON fismen — Phase 4 (rescue/reinstall)
  must be driven from oink or fox, and flake builds happen on oink
  (no nix on fismen).
