{ ... }:

{
  # Claude Code statusline. The script reads the JSON Claude pipes on stdin and
  # prints "folder | branch | context% | 5h-usage | 7d-usage" with ANSI colours.
  # Needs jq (installed system-wide in modules/base.nix).
  #
  # settings.json is NOT managed here — Claude rewrites it at runtime (plugins,
  # auth, …). Point it at this script once per machine with:
  #   "statusLine": { "type": "command", "command": "~/.claude/statusline-command.sh" }
  home.file.".claude/statusline-command.sh" = {
    source = ../files/claude/statusline-command.sh;
    executable = true;
  };
}
