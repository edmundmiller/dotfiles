# Claude Code status line: model · effort │ branch │ context │ prompt cache │ 5h limit.
# Reads the session JSON Claude Code sends on stdin; see
# https://code.claude.com/docs/en/statusline#available-data
input=$(cat)
now=$(date +%s)

# Unit separator, not tab: read collapses runs of whitespace IFS, dropping empty fields.
IFS=$'\x1f' read -r model effort dir ctx warm expires five <<<"$(jq -r '[
  .model.display_name // "?",
  .effort.level // "",
  .workspace.current_dir // .cwd // "",
  (.context_window.used_percentage // 0 | floor),
  (.prompt_cache.warm | if . == null then "" else tostring end),
  (.prompt_cache.expires_at // ""),
  (.rate_limits.five_hour.used_percentage // "" | if . == "" then . else floor end)
] | map(tostring) | join("\u001f")' <<<"$input")"

dim=$'\033[2m' red=$'\033[31m' yellow=$'\033[33m' green=$'\033[32m' reset=$'\033[0m'
sep=" ${dim}│${reset} "

# Green under 50%, yellow under 80%, red beyond.
level() {
  if [ "$1" -ge 80 ]; then printf %s "$red"
  elif [ "$1" -ge 50 ]; then printf %s "$yellow"
  else printf %s "$green"; fi
}

out="$model"
[ -n "$effort" ] && out+=" ${dim}${effort}${reset}"

if [ -n "$dir" ] && branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null) && [ -n "$branch" ]; then
  dirty=
  [ -n "$(git -C "$dir" --no-optional-locks status --porcelain --untracked-files=no 2>/dev/null)" ] && dirty="${yellow}*${reset}"
  out+="${sep}${branch}${dirty}"
fi

out+="${sep}ctx $(level "$ctx")${ctx}%${reset}"

# Minutes until the prompt cache goes cold; idle compaction fires shortly before.
if [ "$warm" = true ] && [ -n "$expires" ] && [ "$expires" -gt "$now" ]; then
  mins=$(((expires - now) / 60))
  color=$green
  [ "$mins" -lt 10 ] && color=$yellow
  out+="${sep}cache ${color}${mins}m${reset}"
elif [ "$warm" = false ]; then
  out+="${sep}cache ${dim}cold${reset}"
fi

[ -n "$five" ] && out+="${sep}5h $(level "$five")${five}%${reset}"

printf '%s\n' "$out"
