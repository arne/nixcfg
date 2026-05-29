{ config, pkgs, lib, ... }:

let
  basesDark = {
    background = "#141210";
    foreground = "#ede8de";
    cursor-color = "#ede8de";
    cursor-text = "#141210";
    selection-background = "#3a3630";
    selection-foreground = "#ede8de";
    palette = [
      "0=#201e1a"
      "1=#d95050"
      "2=#48a068"
      "3=#e07800"
      "4=#5a8fcc"
      "5=#4a9f82"
      "6=#57b090"
      "7=#ede8de"
      "8=#4a4640"
      "9=#d95050"
      "10=#48a068"
      "11=#e07800"
      "12=#5a8fcc"
      "13=#4a9f82"
      "14=#57b090"
      "15=#ede8de"
    ];
  };
in
{
  programs.ghostty = {
    enable = true;

    settings = {
      theme = "bases";
      font-size = 10;
      font-family = "JetBrainsMono Nerd Font Mono";
      copy-on-select = "clipboard";
      shell-integration = "fish";
      window-padding-x = 12;
      window-padding-y = 12;
      background-opacity = 0.95;
    };

    themes = {
      bases = basesDark;
      bases-light = {
        background = "#f7f4ee";
        foreground = "#1a1814";
        cursor-color = "#1a1814";
        cursor-text = "#f7f4ee";
        selection-background = "#c4bfb3";
        selection-foreground = "#1a1814";
        palette = [
          "0=#fdfcf8"
          "1=#c12b2b"
          "2=#276947"
          "3=#b35800"
          "4=#1e5799"
          "5=#2a5f4f"
          "6=#3d7a66"
          "7=#1a1814"
          "8=#bab5aa"
          "9=#c12b2b"
          "10=#276947"
          "11=#c86800"
          "12=#1e5799"
          "13=#2a5f4f"
          "14=#3d7a66"
          "15=#1a1814"
        ];
      };
    };
  };
}
