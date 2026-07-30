{ config, pkgs, lib, ... }:

let
  ###########################################################################
  ## The hub's PUBLIC SSH key — the only thing an agent needs in order to
  ## trust the hub. It is a public key, so it belongs in git, not in sops.
  ##
  ## IT IS EMPTY ON PURPOSE. The hub mints its own Ed25519 keypair the first
  ## time it starts (internal/hub/hub.go: GetSSHKey writes
  ## <dataDir>/id_ed25519 if absent), so the key does not exist until meow has
  ## run the hub once. An agent started with an empty KEY would only
  ## crash-loop, so `enable` below is tied to this string being non-empty:
  ## importing this module before the key is known is a deliberate no-op.
  ##
  ## BRING-UP (one time, in this order):
  ##   1. Deploy meow (hub + Caddy vhost). Agents stay off everywhere.
  ##   2. Read the hub's public key, either from the UI's "Add System" dialog
  ##      at https://status.azf.no, or on meow:
  ##        sudo ssh-keygen -y -f /var/lib/private/beszel-hub/id_ed25519
  ##      (/var/lib/beszel-hub is a symlink into /var/lib/private — the hub
  ##      runs under DynamicUser, so the real state dir is the private one.)
  ##   3. Paste it below, rebuild the whole fleet. Every agent comes up and
  ##      accepts exactly that one key.
  ##   4. In the UI, add one system per host (see the table in
  ##      hosts/meow/beszel.nix).
  ##
  ## Rotating it: delete the hub's id_ed25519, restart beszel-hub, repeat from
  ## step 2. Nothing else in the estate depends on this key.
  ###########################################################################
  hubPublicKey = "";
in
{
  ###########################################################################
  ## Beszel agent — the per-host metrics collector (CPU / memory / disk /
  ## network / temperatures, and container stats where there is a Docker or
  ## Podman socket). Imported by fox, fismen, oink, roar and meow; NOT by air,
  ## which is a laptop that is asleep more often than not and would just sit
  ## in the hub's UI showing as down.
  ##
  ## CONNECTION DIRECTION: SSH, i.e. the HUB dials the AGENT on :45876 and
  ## authenticates with the key above. The alternative (agents dialling the
  ## hub over a WebSocket) is what upstream now recommends, but it needs a
  ## per-host registration token — five more secrets in sops, for no gain
  ## here: every host is on the tailnet and meow can reach all of them.
  ## Nothing about the agent is secret this way, so the whole monitoring
  ## surface is readable in this repo.
  ##
  ## The agent listens on 0.0.0.0:45876 but the port is opened ONLY on
  ## tailscale0, so it is unreachable from the LAN and from the public WAN
  ## (this matters for fismen and oink, which have public addresses). Note
  ## the module's own `openFirewall` is deliberately left off: it would open
  ## the port on every interface.
  ###########################################################################
  services.beszel.agent = {
    enable = hubPublicKey != "";

    environment = {
      KEY = hubPublicKey;
      LISTEN = "45876";
    };

    # SMART data (disk health, per-drive temperatures) — the main reason to
    # run this at all on the ZFS hosts. The cost is a looser sandbox: the
    # upstream module drops NoNewPrivileges/PrivateDevices/PrivateUsers and
    # grants CAP_SYS_RAWIO + CAP_SYS_ADMIN so smartctl can talk to the
    # controllers, plus a udev rule putting NVMe devices in the disk group.
    # Acceptable for a read-only collector that is only reachable over the
    # tailnet.
    smartmon.enable = true;
  };

  # nvidia-smi is added to the agent's PATH automatically on roar: the
  # upstream module keys off services.xserver.videoDrivers, which
  # hosts/roar/nvidia.nix sets to [ "nvidia" ]. Nothing to do per-host.

  networking.firewall.interfaces."tailscale0".allowedTCPPorts =
    lib.mkIf config.services.beszel.agent.enable [ 45876 ];
}
