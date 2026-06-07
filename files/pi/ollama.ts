import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Registers the local llama-swap server as a pi provider via its
// OpenAI-compatible endpoint at /v1. The API key is a placeholder — llama-swap
// doesn't check it but pi's openai-completions transport requires the field.
//
// IMPORTANT: contextWindow must match the `-c` (ctx) that hosts/fox/llama.nix
// passes to llama-server for each model — NOT a larger value. llama-swap serves
// 32768 for the big models and 16384 for the coder; advertising more here lets
// pi overflow the server's real KV window mid-session. To raise it, bump `ctx`
// in llama.nix first (costs KV memory — watch the all-4 co-residency budget).
//
// THINKING TOGGLE: the Qwen3.6 models are reasoning models whose thinking is
// gated by the chat template's `enable_thinking` kwarg. Marking them
// `reasoning: true` + `compat.thinkingFormat: "qwen-chat-template"` makes pi
// inject `chat_template_kwargs.enable_thinking` per request, driven by the
// thinking level you pick in pi's UI: level "off" → enable_thinking=false
// (straight to the answer, no ~50s reasoning preamble), any other level → on.
// Same loaded model serves both — it's a request flag, not a second model.
// maxTokens is raised to 8192 so the answer still fits after a thinking pass.
export default function (pi: ExtensionAPI) {
  pi.registerProvider("ollama", {
    name: "llama.cpp (local)",
    baseUrl: "http://127.0.0.1:11434/v1",
    apiKey: "ollama",
    api: "openai-completions",
    models: [
      {
        id: "qwen3.6:35b",
        name: "Qwen 3.6 35B-A3B (MTP)",
        reasoning: true,
        compat: { thinkingFormat: "qwen-chat-template" },
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 32768,
        maxTokens: 8192,
      },
      {
        id: "qwen3.6:27b",
        name: "Qwen 3.6 27B (MTP, 256k)",
        reasoning: true,
        compat: { thinkingFormat: "qwen-chat-template" },
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 262144,
        maxTokens: 8192,
      },
      {
        id: "qwen2.5-coder:3b",
        name: "Qwen 2.5 Coder 3B",
        reasoning: false,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 16384,
        maxTokens: 2048,
      },
      {
        id: "gemma4:26b",
        name: "Gemma 4 26B-A4B",
        reasoning: false,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 32768,
        maxTokens: 4096,
      },
    ],
  });
}
