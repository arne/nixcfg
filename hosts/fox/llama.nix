{ pkgs, lib, inputs, ... }:

# llama.cpp + llama-swap on Strix Halo. Replaces ollama: serves an
# OpenAI-compatible API on :11434, spawning a per-model llama-server on demand.
#
# GGUFs are fetched from unsloth's upstream HuggingFace repos (Q6_K quants) and
# stored at /var/lib/llama/models/. Ollama's own GGUFs aren't reusable here:
# their qwen3.6 / gemma4 files carry ollama-specific architecture metadata
# (e.g. qwen35moe with a 3-element rope.dimension_sections) that mainline
# llama.cpp rejects.
#
# llama-cpp pinned to nixpkgs-unstable: 25.11 ships build 6981 which predates
# Gemma 4 (added upstream April 2026). Unstable is build 9190+.

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
  llamaCpp = unstable.llama-cpp.override { vulkanSupport = true; };
  modelsDir = "/var/lib/llama/models";

  mkCmd = { gguf, port, ctx ? 32768, ngl ? 999, extra ? [ ] }:
    lib.concatStringsSep " " ([
      "${llamaCpp}/bin/llama-server"
      "--host 127.0.0.1"
      "--port ${toString port}"
      "-m ${modelsDir}/${gguf}"
      "-ngl ${toString ngl}"
      "-c ${toString ctx}"
    ] ++ extra);
in
{
  services.llama-swap = {
    enable = true;
    port = 11434;          # ollama's old port — Open WebUI / pi reach it here
    openFirewall = false;
    settings.models = {
      "qwen3.6:35b" = {
        cmd = mkCmd { gguf = "Qwen3.6-35B-A3B-UD-Q6_K.gguf"; port = 18001; };
        proxy = "http://127.0.0.1:18001";
      };
      "qwen3.6:27b" = {
        cmd = mkCmd { gguf = "Qwen3.6-27B-Q6_K.gguf"; port = 18002; };
        proxy = "http://127.0.0.1:18002";
      };
      "qwen2.5-coder:3b" = {
        cmd = mkCmd { gguf = "Qwen2.5-Coder-3B-Instruct-Q6_K.gguf"; port = 18003; ctx = 16384; };
        proxy = "http://127.0.0.1:18003";
      };
      "gemma4:26b" = {
        cmd = mkCmd { gguf = "gemma-4-26B-A4B-it-UD-Q6_K.gguf"; port = 18004; };
        proxy = "http://127.0.0.1:18004";
      };
    };
  };

  # The upstream module hardens with DynamicUser=true + MemoryDenyWriteExecute
  # but doesn't add the render/video groups needed for /dev/dri + /dev/kfd
  # access, and MDWE breaks RADV's shader-compile path. Relax both.
  systemd.services.llama-swap.serviceConfig = {
    SupplementaryGroups = [ "render" "video" ];
    MemoryDenyWriteExecute = lib.mkForce false;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/llama         0755 root root - -"
    "d /var/lib/llama/models  0755 root root - -"
  ];

  # Bump GTT (the dynamic shared-memory pool the iGPU draws from) from the
  # 50%-of-RAM default to 96 GiB on this 128 GB box. Pages are 4 KiB:
  # 96 × 1024 × 1024 / 4 = 25165824. Leaves 32 GiB for the OS. (Carried over
  # from the old ollama config — the iGPU needs this regardless of runtime.)
  boot.kernelParams = [ "ttm.pages_limit=25165824" ];
}
