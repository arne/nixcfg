#!/usr/bin/env bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
folder=$(basename "$cwd")
branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null)
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

now=$(date +%s)

# 5h window: minutes when <2h remain, else "X.Yh" with one decimal.
five_h_remaining() {
  local reset_epoch="$1"
  [ -z "$reset_epoch" ] && return
  local diff=$(( reset_epoch - now ))
  [ "$diff" -lt 0 ] && diff=0
  if [ "$diff" -lt 7200 ]; then
    echo "$(( diff / 60 ))m"
  else
    awk -v d="$diff" 'BEGIN { printf "%.1fh", d/3600 }'
  fi
}

# 7d window: "Xd Xh" (or "Xh" when under a day).
seven_d_remaining() {
  local reset_epoch="$1"
  [ -z "$reset_epoch" ] && return
  local diff=$(( reset_epoch - now ))
  [ "$diff" -lt 0 ] && diff=0
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  if [ "$days" -gt 0 ]; then
    echo "${days}d ${hours}h"
  else
    echo "${hours}h"
  fi
}

# ANSI colors
dim='\033[2m'
green='\033[32m'
yellow='\033[33m'
red='\033[31m'
cyan='\033[36m'
reset='\033[0m'

# Color context percentage by usage
ctx_color="$green"
if [ -n "$ctx" ]; then
  [ "$ctx" -ge 20 ] 2>/dev/null && ctx_color="$yellow"
  [ "$ctx" -ge 50 ] 2>/dev/null && ctx_color="$red"
fi

# Color 5h usage
fh_color="$green"
if [ -n "$five_h" ]; then
  five_h_int=$(printf '%.0f' "$five_h")
  [ "$five_h_int" -ge 50 ] 2>/dev/null && fh_color="$yellow"
  [ "$five_h_int" -ge 80 ] 2>/dev/null && fh_color="$red"
fi

# Color 7d usage
sd_color="$green"
if [ -n "$seven_d" ]; then
  seven_d_int=$(printf '%.0f' "$seven_d")
  [ "$seven_d_int" -ge 50 ] 2>/dev/null && sd_color="$yellow"
  [ "$seven_d_int" -ge 80 ] 2>/dev/null && sd_color="$red"
fi

parts=()
[ -n "$folder" ] && parts+=("$folder")
[ -n "$branch" ] && parts+=("${cyan}${branch}${reset}")
[ -n "$ctx" ] && parts+=("${dim}◔${reset} ${ctx_color}${ctx}%${reset}")

if [ -n "$five_h" ]; then
  fh_label=$(five_h_remaining "$five_h_reset")
  [ -z "$fh_label" ] && fh_label="5h"
  parts+=("${fh_color}${five_h_int}%${reset} ${dim}(${fh_label})${reset}")
fi

if [ -n "$seven_d" ]; then
  sd_label=$(seven_d_remaining "$seven_d_reset")
  [ -z "$sd_label" ] && sd_label="7d"
  parts+=("${sd_color}${seven_d_int}%${reset} ${dim}(${sd_label})${reset}")
fi

result=""
for i in "${!parts[@]}"; do
  [ $i -gt 0 ] && result+=" ${dim}|${reset} "
  result+="${parts[$i]}"
done
echo -e "$result"
