import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Registers a local Ollama server as a pi provider via the OpenAI-compatible
// endpoint at /v1. The API key is a placeholder — Ollama doesn't check it but
// pi's openai-completions transport requires the field to be present.
//
// contextWindow values match Ollama's *runtime* num_ctx, set globally to 131072
// via OLLAMA_CONTEXT_LENGTH in hosts/fox/ollama.nix. To diverge per-model, add
// `PARAMETER num_ctx N` to a Modelfile, recreate, and update the value here.
export default function (pi: ExtensionAPI) {
  pi.registerProvider("ollama", {
    name: "Ollama (local)",
    baseUrl: "http://127.0.0.1:11434/v1",
    apiKey: "ollama",
    api: "openai-completions",
    models: [
      {
        id: "qwen3.6:35b",
        name: "Qwen 3.6 35B",
        reasoning: false,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 131072,
        maxTokens: 4096,
      },
      {
        id: "qwen3.6:27b",
        name: "Qwen 3.6 27B",
        reasoning: false,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 131072,
        maxTokens: 4096,
      },
      {
        id: "qwen2.5-coder:3b",
        name: "Qwen 2.5 Coder 3B",
        reasoning: false,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 131072,
        maxTokens: 2048,
      },
    ],
  });
}
