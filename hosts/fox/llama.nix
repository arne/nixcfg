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
      # MTP (multi-token prediction) speculative decoding: the MTP head is baked
      # into these *-MTP-* GGUFs (the plain unsloth quants drop the nextn
      # tensors), so no separate draft model is needed — just --spec-type
      # draft-mtp. ~1.8-2x decode throughput on Strix Halo at n-max 3 (~75%
      # accept). Tradeoff: prompt prefill is slightly slower. Requires
      # llama-cpp >= b9190 (MTP merged upstream 2026-05-16, PR #22673) — our
      # nixpkgs-unstable pin already includes it.
      "qwen3.6:35b" = {
        cmd = mkCmd {
          gguf = "Qwen3.6-35B-A3B-MTP-UD-Q6_K.gguf";
          port = 18001;
          extra = [ "--spec-type draft-mtp" "--spec-draft-n-max 3" ];
        };
        proxy = "http://127.0.0.1:18001";
      };
      # 27B is the agentic daily-driver, so it gets the full native 256k context
      # (the others stay at 32k). At f16 that KV would be ~+14.6 GiB and blow the
      # all-4 GTT budget; q8_0 KV + flash-attn halves it to ~+10 GiB (measured:
      # 38.3 GiB standalone @256k) with no measurable quality loss (Qwen's card
      # reports no NIAH degradation under KV quant). q8_0 V-cache requires -fa.
      "qwen3.6:27b" = {
        cmd = mkCmd {
          gguf = "Qwen3.6-27B-MTP-UD-Q6_K.gguf";
          port = 18002;
          ctx = 262144;
          extra = [
            "--spec-type draft-mtp" "--spec-draft-n-max 3"
            "-fa on" "-ctk q8_0" "-ctv q8_0"
          ];
        };
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

    # Co-residency: by default llama-swap runs one model and swaps (a ~35s
    # reload on every switch). We use the legacy groups mechanism (the newer
    # "matrix" DSL is NOT in our llama-swap 165 — it parses the YAML but
    # silently ignores it and falls back to swapping).
    #
    # Only the two Qwen3.6 models stay resident (swap=false → co-resident, no
    # eviction between them). The coder and gemma share an on-demand group; both
    # groups are exclusive, so calling coder or gemma swaps the Qwen pair out,
    # and calling a Qwen model swaps them back in.
    #
    # Budget: 27B at 256k (q8_0 KV) ~38 GiB + 35B at 32k ~30 GiB ≈ 68 GiB of the
    # 96 GiB GTT — generous headroom for the 27B's context checkpoints to grow
    # as it fills 256k, plus niri. (For reference, pinning all four pushed GTT
    # to a measured 95.1 GiB — too tight, hence pair-only.)
    settings.groups = {
      qwen = {
        swap = false;      # 27B + 35B co-resident, no eviction between them
        exclusive = true;  # loading either unloads the on-demand group
        members = [ "qwen3.6:27b" "qwen3.6:35b" ];
      };
      ondemand = {
        swap = true;       # coder / gemma load one at a time when called
        exclusive = true;  # loading either swaps the Qwen pair out
        members = [ "qwen2.5-coder:3b" "gemma4:26b" ];
      };
    };

    # Warm the resident Qwen pair at boot; coder and gemma load on demand.
    settings.hooks.on_startup.preload = [
      "qwen3.6:27b"
      "qwen3.6:35b"
    ];
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
