# `firsthouse` (Phase 6) — moved out of nixcfg

The firsthouse self-service sandbox portal is its own system now, not part of
this config. The Go portal app, the Incus/LXC sandbox guest image (formerly
`images/sandbox.nix`), the design doc, and the NixOS service module all live in:

  **`code.bas.es/arne/firsthouse`** (private; fetched as the `firsthouse` flake input)

nixcfg's job is reduced to **host instantiation**: import
`firsthouse.nixosModules.firsthouse`, enable it on oink, and hand it oink's
secrets (the `tag:firsthouse` tailnet auth key, the tailnet-B OAuth secret) and
the group that grants Incus socket access. That wiring will land alongside this
file in `hosts/oink/`.

The Phase 5 scripted baseline (`sandbox-new-client` / `sandbox-remove-client`,
the egress hardening, the tailnet-B OAuth model) stays in `hosts/oink/incus/` as
the validated reference recipe firsthouse automates.
