{ pkgs, llm-agents, ... }:

# Crush — Charmbracelet's terminal AI coding agent — pointed at our own
# LiteLLM gateway (https://llm.azf.no), which fronts fox's llama-swap. Imported
# only by hosts that pass the `llm-agents` specialArg (fox, air, meow); the
# package comes from numtide's llm-agents flake (crush 0.74.x, daily-fresh)
# rather than nixpkgs (0.18.x, far behind).
#
# CONFIG lives at ~/.config/crush/crush.json (confirmed from the 0.74.1 binary:
# it reads `crush.json` under $XDG_CONFIG_HOME/crush, NOT `crushrc`). The field
# names below are the canonical schema at https://charm.land/crush.json — note
# models REQUIRE the cost_per_1m_* fields (0 here, it's local) and can_reason /
# supports_attachments.
#
# API KEY is NOT baked into the Nix store. crush embeds mvdan.cc/sh and expands
# `$(...)` in string config values, so api_key runs `cat` on a 600-mode file
# you drop outside the store:
#
#   umask 077; echo 'sk-...your-litellm-key...' > ~/.config/crush/litellm-key
#
# Use a LiteLLM *virtual* key (make one in the llm.azf.no admin UI, or via
# /key/generate), not the master key. Same file path on every host.

let
  system = pkgs.stdenv.hostPlatform.system;

  # Local models served by fox's llama-swap (see hosts/fox/llama.nix). context_window
  # mirrors each model's `-c` there; cost is zero (self-hosted). can_reason is left
  # false for a predictable first cut — crush won't inject reasoning params the
  # llama.cpp backend doesn't map; flip per-model later if desired.
  mkModel = { id, ctx, maxTok }: {
    inherit id;
    name = id;
    cost_per_1m_in = 0;
    cost_per_1m_out = 0;
    cost_per_1m_in_cached = 0;
    cost_per_1m_out_cached = 0;
    context_window = ctx;
    default_max_tokens = maxTok;
    can_reason = false;
    supports_attachments = false;
  };

  models = [
    (mkModel { id = "qwen3.6:27b";      ctx = 262144; maxTok = 8192; })
    (mkModel { id = "qwen3.6:35b";      ctx = 32768;  maxTok = 8192; })
    (mkModel { id = "gemma4:26b";       ctx = 32768;  maxTok = 8192; })
    (mkModel { id = "qwen2.5-coder:3b"; ctx = 16384;  maxTok = 4096; })
  ];
in
{
  home.packages = [ llm-agents.packages.${system}.crush ];

  xdg.configFile."crush/crush.json".text = builtins.toJSON {
    "$schema" = "https://charm.land/crush.json";

    providers.litellm = {
      id = "litellm";
      name = "llm.azf.no";
      type = "openai-compat";
      base_url = "https://llm.azf.no/v1";
      api_key = "$(cat $HOME/.config/crush/litellm-key)";
      inherit models;
    };

    # Default the agent to our gateway so it never falls back to a cloud
    # provider that would need a separate key. 27b is fox's agentic daily
    # driver (256k ctx); the 3b coder is the cheap "small" model.
    models = {
      large = { model = "qwen3.6:27b";      provider = "litellm"; };
      small = { model = "qwen2.5-coder:3b"; provider = "litellm"; };
    };
  };
}
