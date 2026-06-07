{ config, pkgs, lib, ... }:

{
  # Ollama provider extension — pi auto-discovers TS files under
  # ~/.pi/agent/extensions/ and registers `ollama` at the local server.
  home.file.".pi/agent/extensions/ollama.ts".source =
    ../files/pi/ollama.ts;

  # Pi global settings. Symlink is read-only, so the in-app /settings command
  # can't mutate it — change defaults by editing this file instead.
  home.file.".pi/agent/settings.json".text = builtins.toJSON {
    defaultProvider = "ollama";
    defaultModel = "qwen3.6:27b";
  };
}
