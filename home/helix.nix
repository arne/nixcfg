{ config, pkgs, lib, ... }:

{
  programs.helix = {
    enable = true;

    settings = {
      theme = "bases";

      editor = {
        line-number = "relative";
        mouse = true;
        bufferline = "multiple";
        color-modes = true;
        cursorline = true;
        true-color = true;
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        statusline = {
          left = [ "mode" "spinner" "file-name" "file-modification-indicator" ];
          center = [];
          right = [ "diagnostics" "selections" "register" "position" "file-encoding" ];
        };
        lsp = {
          display-messages = true;
          display-inlay-hints = true;
        };
        indent-guides = {
          render = true;
          character = "▏";
        };
        soft-wrap.enable = true;
      };

      keys.normal = {
        C-s = ":w";
        y = "yank_to_clipboard";
        p = "paste_clipboard_after";
        P = "paste_clipboard_before";
        R = "replace_selections_with_clipboard";
      };

      keys.select = {
        y = "yank_to_clipboard";
        p = "paste_clipboard_after";
        P = "paste_clipboard_before";
        R = "replace_selections_with_clipboard";
      };
    };
  };

  xdg.configFile."helix/themes/bases.toml".source = ../files/helix/themes/bases.toml;
  xdg.configFile."helix/themes/bases-light.toml".source = ../files/helix/themes/bases-light.toml;
}
