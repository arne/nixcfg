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

Custom storage volume: `poxy-data` on pool default — check owner/use before
migrating (`incus storage volume show default poxy-data`).

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

## Operational notes

- The Claude session driving this ran ON fismen — Phase 4 (rescue/reinstall)
  must be driven from oink or fox, and flake builds happen on oink
  (no nix on fismen).
