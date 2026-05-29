{ ... }:

# Open WebUI — web frontend pointed at the local llama-swap (OpenAI-compatible
# API on :11434). LAN-reachable on http://fox:8080. State (sqlite, uploaded
# files, RAG vectors) lives under /var/lib/open-webui, managed by the upstream
# module.
{
  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 8080;
    openFirewall = true;
    environment = {
      # llama-swap speaks the OpenAI /v1 API, not Ollama's /api. Disable the
      # Ollama probe and point the OpenAI connection at llama-swap. The key is
      # a required-but-unchecked placeholder.
      ENABLE_OLLAMA_API = "False";
      OPENAI_API_BASE_URL = "http://127.0.0.1:11434/v1";
      OPENAI_API_KEY = "llama-swap";
    };
  };
}
