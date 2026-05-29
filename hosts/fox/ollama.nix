{ pkgs, ... }:

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
  };

  environment.systemPackages = [ pkgs.ollama-vulkan ];
}
