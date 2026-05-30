# Phase 5 — per-employee cohort sandboxes

Builds on the Phase 4 host (Incus + egress hardening + tailnet-B OAuth
provisioning). Phase 4 shipped a one-box-per-`<client-name>` flow; Phase 5
turns that into a **per-employee cohort** model.

## Goal

A client (e.g. *First House*) runs a test with N employees. Each employee gets
their own sandbox, and:

1. they log in as **`<theirname>@<hostname>`** over tailnet B (Tailscale SSH,
   no SSH keys);
2. **only that employee** can log into their box;
3. **every** employee in the cohort can reach a shared service on any cohort
   box — e.g. `http://<hostname>:8080`.

## Model

| Concern | Mechanism |
|---|---|
| Hostname | Random free name from the lower-case Studio-Ghibli pool in `new-client.sh`. "Taken" = a live Incus instance **or** any tailnet-B device, so no two boxes ever collide (no MagicDNS suffixing). |
| Per-box SSH isolation | Each box carries a **unique tag** `tag:<cohort>-<login>`. The tailnet-B `ssh` rule maps one employee → that one tag → local user `<login>`. (Tailscale `ssh.dst` keys on tags, and admin-provisioned nodes can't use `autogroup:self`, so a per-box tag is the only lever.) |
| Shared :8080 | Each box also carries the **cohort tag** `tag:<cohort>`. One `acls` rule lets `tag:<cohort>` (and the employees' own devices) reach `tag:<cohort>:8080`. |
| Login identity | Tailscale identity (tailnet-B membership / SSO). No keys, no `authorized_keys`, no `openssh`. |
| Local account | `new-client.sh` creates `<login>` (wheel + passwordless sudo) in the box at provision time. |

Inter-box `:8080` traffic is WireGuard-encapsulated tailnet-B and is **not**
affected by the host bridge-egress drops added in Phase 4.

## Provisioner

```
sudo sandbox-new-client --cohort <client> --user <login>
# e.g.
sudo sandbox-new-client --cohort firsthouse --user alice
```

Per run: pick a free hostname → mint a single-use key stamped with
`tag:<cohort>` + `tag:<cohort>-<login>` → launch → wait for DHCP → create local
user `<login>` → join tailnet B → print `ssh <login>@<hostname>`.

Implemented in `hosts/oink/incus/new-client.sh` (this PR).

### Teardown

```
sudo sandbox-remove-client <hostname> [-y]
```

Deletes the Incus instance **and** its tailnet-B device, freeing the hostname
for reuse. Either may be absent (an orphaned device is still cleaned up).
Prompts before deleting unless `-y`. Requires the OAuth client to have devices
write scope. Implemented in `hosts/oink/incus/remove-client.sh` (this PR).

## One-time setup per cohort (external, Tailscale admin console)

These cannot be done from the host and must precede provisioning:

1. Add the employees to tailnet B (users, or node-sharing) — it's the only
   ingress to the boxes.
2. Grant the tailnet-B **OAuth client** ownership of `tag:<cohort>` and each
   `tag:<cohort>-<login>` (the client can only mint keys for tags it owns).
3. Apply the policy: `tagOwners` + `groups` + `acls` (shared :8080) + `ssh`
   (per-employee). See `tailnet-b-acl.example.hujson`.

## Decisions / trade-offs

- **Per-employee tags ⇒ per-employee console setup** (OAuth-client tag list +
  `tagOwners` + one `ssh` line). Fine for a fixed roster; doesn't scale to
  churn. The alternative (real `sshd` + injected `authorized_keys`, one cohort
  tag) was rejected: it drops SSO/MFA and reintroduces key handling, and the
  employees must be on tailnet B for ingress either way.
- **`useradd` is imperative** (relies on the image default `mutableUsers =
  true`). Persists on the box's writable rootfs; not declarative, so an
  in-container `nixos-rebuild` won't know about it. Acceptable for disposable
  test boxes.

## Out of scope / follow-ups

- Optional: make the shared service port configurable (hard-coded `8080` in
  docs/ACL today).
- Optional: automate the tailnet-B policy via the ACL API instead of manual
  edits.
