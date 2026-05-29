{ pkgs, lib, ... }:

# Ollama on Strix Halo (gfx1151) — Vulkan/RADV backend.
#
# Why Vulkan and not ROCm: as of May 2026 Ollama ≥0.18 has two open bugs on
# gfx1151 — GPU detection silently falls back to CPU (ollama #15336), and the
# vendored llama.cpp lags upstream by enough to cost ~56% tg throughput on AMD
# (ollama #15601). Vulkan RADV sidesteps both and tops the strix-halo-llm-perf
# scoreboard for token generation; ROCm only wins on prompt-processing batches.
# Models live under /var/lib/ollama, which is already a nodatacow btrfs subvol.
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    # Static user (not DynamicUser): /var/lib/ollama is its own btrfs subvol
    # mountpoint, so systemd's DynamicUser StateDirectory= migration to
    # /var/lib/private/ollama fails with EBUSY. A real user uses the subvol
    # directly.
    user = "ollama";
    group = "ollama";
  };

  # The upstream module hardcodes DynamicUser=true even when user/group are
  # set, which the systemd manual flags as conflicting. Force it off so the
  # subvol at /var/lib/ollama is used in place, not bind-mounted from
  # /var/lib/private/ollama.
  systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;

  # The subvol mount is root-owned and empty; the unit's ReadWritePaths=
  # includes both home and models, so the models subdir must pre-exist.
  systemd.tmpfiles.rules = [
    "d /var/lib/ollama        0750 ollama ollama -"
    "d /var/lib/ollama/models 0750 ollama ollama -"
  ];

  # Bump GTT (the dynamic shared-memory pool the iGPU draws from) from the
  # 50%-of-RAM default to 96 GiB on this 128 GB box. Pages are 4 KiB:
  # 96 × 1024 × 1024 / 4 = 25165824. Leaves 32 GiB for the OS.
  boot.kernelParams = [ "ttm.pages_limit=25165824" ];

  environment.systemPackages = [ pkgs.ollama-vulkan ];
}
