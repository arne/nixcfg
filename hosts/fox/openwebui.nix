{ ... }:

# Open WebUI — web frontend pointed at the local Ollama. LAN-reachable on
# http://fox:8080. State (sqlite, uploaded files, RAG vectors) lives under
# /var/lib/open-webui, managed by the upstream module.
{
  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 8080;
    openFirewall = true;
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
    };
  };
}
