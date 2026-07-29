# ollama + open-webui — the local LLM stack, restored from the Debian `cube`
# install.
#
# Both ran differently there: ollama was a host service, open-webui lived in an
# Incus container. Here they are plain NixOS services.
#
# NOTE ON DATA: ollama's models were stored on the OS NVMe under Debian and were
# NOT part of the pre-migration backup, so they are gone. They are re-pullable
# (`ollama pull <model>`); add them to `loadModels` below to make that
# declarative once the wanted set is known. open-webui's state (chats, users,
# settings) WAS captured, inside /storage/migration/openwebui.tar.gz, and is
# restored into stateDir.
{ config, pkgs, lib, ... }:

{
  services.ollama = {
    enable = true;

    # RTX 2000 Ada — the driver comes from ./nvidia.nix. This is the whole
    # reason the GPU is in this box.
    acceleration = "cuda";

    # Localhost only: its consumer is open-webui on the same host. Flip to
    # "0.0.0.0" + open port 11434 if other machines need the API directly.
    host = "127.0.0.1";
    port = 11434;

    # Models are re-pulled, not restored — see the note above.
    loadModels = [ ];
  };

  services.open-webui = {
    enable = true;

    # Exposed on the LAN and tailnet, as it was on Debian.
    host = "0.0.0.0";
    port = 8080;
    openFirewall = true;

    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      # No outbound calls: keep the instance local-only, as it was.
      ENABLE_OPENAI_API = "False";
      WEBUI_AUTH = "True";
      # Telemetry/model-download chatter off.
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
    };
  };
}
