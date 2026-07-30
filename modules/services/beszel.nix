{ config, pkgs, lib, ... }:

let
  ###########################################################################
  ## The hub's PUBLIC SSH key — the only thing an agent needs in order to
  ## trust the hub. It is a public key, so it belongs in git, not in sops.
  ##
  ## The hub mints this keypair itself the first time it starts
  ## (internal/hub/hub.go: GetSSHKey writes <dataDir>/id_ed25519 if absent),
  ## so it could not be known until meow had run the hub once. The value below
  ## was read off the live hub after that first start:
  ##
  ##   sudo ssh-keygen -y -f /var/lib/private/beszel-hub/beszel_data/id_ed25519
  ##
  ## Note BOTH path oddities: the hub runs under DynamicUser, so its state dir
  ## is the /var/lib/private one (/var/lib/beszel-hub is a symlink into it),
  ## and the key sits in the PocketBase data subdir `beszel_data/`, not at the
  ## top of it. The same key is shown in the UI's "Add System" dialog.
  ##
  ## `enable` is tied to this being non-empty: an agent started with an empty
  ## KEY would only crash-loop, so a fleet that does not yet have a hub gets a
  ## no-op instead of five broken units.
  ##
  ## Rotating it: delete the hub's id_ed25519, restart beszel-hub, re-read the
  ## key, paste here, rebuild the fleet. Nothing else depends on this key.
  ###########################################################################
  hubPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDzDAdsfp92ST1ERjjRUlRQCsBwmOqPYkXTmkzcZjoh3";
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
