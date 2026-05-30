# Phase 6 — `firsthouse`: self-service sandbox portal

Status: **design only** (no code yet). Supersedes the manual Phase 5 flow
(`sandbox-new-client` / `sandbox-remove-client`), which stays as the validated
scripted baseline and reference recipe.

## Why

Phase 5 worked but the access-control story scales badly: every employee needs
a per-user tag + `ssh` rule + `tagOwners` line, hand-edited into the tailnet-B
policy. The fix is to stop encoding users in the policy at all. A small portal,
authenticated by Tailscale identity, becomes the authority; the tailnet policy
collapses to a couple of static rules and never changes as people come and go.

## One-paragraph picture

`firsthouse` is the only thing on tailnet B that trainees touch. They
`ssh firsthouse`; the portal learns who they are from their **verified Tailscale
identity** (`tsnet` + `LocalClient.WhoIs`), and gives them a tiny TUI to
provision / enter / destroy their **one** sandbox. Sandboxes are Incus
containers that join tailnet B (so trainees can reach each other's web apps on
any port) but run **no SSH** — the only way to a shell is back through
`firsthouse`, which bridges the session into the box via `incus exec`. So
trainees see each other's *services* but can only get a *shell* on their own
box, and the policy stays trivial.

## Components

- **`firsthouse` service** (Go, on oink):
  - [`tailscale.com/tsnet`](https://pkg.go.dev/tailscale.com/tsnet) — embedded
    node on tailnet B, tagged `tag:firsthouse`, listening on `:22`.
  - [`charmbracelet/wish`](https://github.com/charmbracelet/wish) — SSH server
    presenting the TUI; identity comes from `WhoIs(remoteAddr)`, **not** SSH
    keys/passwords.
  - [`charmbracelet/bubbletea`](https://github.com/charmbracelet/bubbletea) —
    the menu (list / provision / enter / destroy). Optional; the same core
    could be a couple of non-interactive subcommands.
  - **Incus client** ([`github.com/lxc/incus/client`](https://github.com/lxc/incus))
    over the local socket — launch, `exec` (PTY bridge), file push (later),
    delete.
  - **Ownership store** — small persistent map `identity -> box` (+ created-at,
    last-used) for one-box-per-user, lookup-on-reconnect, quotas, idle reaping.
    A single JSON/SQLite file on oink is enough.
  - Holds the **tailnet-B OAuth client secret** (to mint `tag:sandbox` keys for
    the boxes it launches). Same credential the Phase 5 scripts use.
- **Sandbox image** (evolves `images/sandbox.nix`):
  - Joins tailnet B with **one shared tag `tag:sandbox`** (no per-user tags).
  - **No `sshd`, no Tailscale SSH** — `:22` simply isn't listening, so nobody
    can shell in over the tailnet.
  - Runs the trainee's own services on whatever ports they choose.
  - `claude-code` + the existing dev tooling, plus a local user named after the
    trainee (see below).

## Identity, ownership, naming

- **Owner key = the verified Tailscale identity** (`alice@github`). This is what
  enforces one-box-per-user, isolation, lookup-on-reconnect, and (later) the
  file-manager gate. **Never key ownership on anything the user types** — else
  typing someone else's name could claim their box.
- **Hostname = a name the user enters**, defaulted from their identity and
  editable (e.g. `alice`). It's the tailnet device name / MagicDNS label, so
  peers reach `http://alice:<port>`. Cosmetic, not a credential.
- The only checks that survive from Phase 5's hostname logic: **charset**
  (`^[a-z][a-z0-9-]*$`) and **uniqueness** (reject if a live instance or a
  tailnet-B device already uses the name). No pool, no random assignment.
- **One container per user**, enforced by the owner key: if your identity
  already owns a box, you enter it; you don't get a second.

## Access paths

| Need | Path |
|---|---|
| Provision / enter shell / destroy | `ssh firsthouse` → `WhoIs` → TUI → `incus exec <box> -- su - <user>` (PTY bridged from the wish session) |
| See each other's web apps (any port) | direct over tailnet B: `http://<name>:<port>`, allowed by the `tcp:*` grant |
| Files into a box | **deferred** (see below) |

## The entire tailnet-B policy (frozen, headcount-independent)

```hujson
{
  "tagOwners": {
    "tag:sandbox-provisioner": ["autogroup:admin"],          // OAuth client firsthouse mints with
    "tag:firsthouse":          ["autogroup:admin"],           // the portal node
    "tag:sandbox":             ["tag:sandbox-provisioner"],   // the boxes
  },
  "grants": [
    // everyone reaches the portal to provision / get a shell
    { "src": ["autogroup:member"], "dst": ["tag:firsthouse"], "ip": ["tcp:22"] },
    // everyone sees everyone's web services, any port (the training requirement)
    { "src": ["autogroup:member"], "dst": ["tag:sandbox"],    "ip": ["tcp:*"] },
  ],
  // No ssh{} block, no per-user anything. Shells come via firsthouse -> incus exec.
}
```

Tag notes: the portal node needs a `tag:firsthouse` identity (a stable auth key,
minted manually once or by letting `tag:sandbox-provisioner` own `tag:firsthouse`
too). The OAuth client is `tag:sandbox-provisioner` and owns `tag:sandbox`, so it
can mint the boxes' keys (validated in Phase 5 — owning via `autogroup:admin`
alone is rejected).

## Provisioning flow

```
ssh firsthouse
  └─ WhoIs → alice@github
       ├─ owns a box?  → enter it (incus exec)
       └─ no box yet?  → "Name your box: [alice]" (prefilled, editable)
                          → validate charset + uniqueness
                          → mint tag:sandbox key (OAuth client)
                          → incus launch <name> (sandbox image, profile)
                          → wait for lease; create local user <user>; join tailnet B
                          → record owner = alice@github
                          → drop into shell
destroy → incus delete --force + delete tailnet device + free the name
```

The launch/user/join/teardown steps are exactly the Phase 5 recipe, minus the
`--ssh` flag and per-user tags; `firsthouse` automates them behind identity.

## Reused vs new vs dropped (relative to Phase 5)

- **Reused:** the provisioning recipe (mint → launch → create user → join →
  teardown), the egress hardening, the OAuth + `tag:sandbox-provisioner` model.
- **New:** the Go portal (tsnet/wish/bubbletea + Incus client + ownership
  store); the `incus exec` shell broker; name-your-box-from-identity flow.
- **Dropped:** the Ghibli hostname pool + random assignment; per-user tags and
  per-user `ssh`/`tagOwners` rules; Tailscale SSH on the boxes; `--cohort/--user`
  CLI args.

## Deferred sub-phases

- **File transfer / web file manager.** Not built until we can do it the
  identity-gated way: a web file manager (e.g. Filebrowser) on each box behind
  **Tailscale Serve**, authorized to the box's **owner only** via the injected
  tailnet-identity header (so it's reachable on the cohort-open box but only the
  owner can use it). The simpler per-box-password variant is explicitly *not*
  the plan. Until then, trainees edit in-box.
- Heavy SSH-native tooling (`rsync`, VS Code Remote-SSH, port-forwarding) is out
  of scope by construction — boxes run no SSH. Revisit only if a trainee need
  forces it (it would reopen the isolation model).

## `firsthouse` as a control plane — threat model notes

`firsthouse` is now the security boundary. It holds the Incus socket and the
OAuth secret, and its `WhoIs`→owner check is the *only* thing keeping tenants
apart (there are no per-user Tailscale rules anymore). Therefore:

- It must run as a hardened systemd service on oink (least privilege it can get
  while still reaching Incus; restart-on-failure; logs/audit of provision/enter/
  destroy keyed by identity).
- The `WhoIs` lookup must be on the **connection's** source, and the result
  trusted only from `tailscaled` (never a client-supplied value).
- Bound the blast radius: per-identity quota (1 box), resource caps (already in
  the `client-sandbox` profile), idle reaping, and a hard cap on total boxes.
- A bug in the owner check = cross-tenant access, so that check deserves tests
  and review before first real use.

## Naming caveat (acknowledged)

`firsthouse` is a *client* name on a structurally multi-client portal. If a
second client is ever onboarded they'd all `ssh firsthouse`. Accepted for now as
a deliberate choice; revisit if multi-client becomes real.

## Open questions for when we build

1. Portal node identity: mint `tag:firsthouse` key manually, or let
   `tag:sandbox-provisioner` own `tag:firsthouse` and have the service mint its
   own on first boot?
2. Ownership store: flat JSON vs SQLite (lean JSON unless quotas/audit grow).
3. Bubble Tea TUI vs plain menu — UX nicety, decide when prototyping.
4. Idle-reaping policy (destroy after N days unused?) and whether to warn first.
