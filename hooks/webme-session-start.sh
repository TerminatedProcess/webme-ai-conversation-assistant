#!/usr/bin/env bash
# SessionStart hook for the `webme` skill (https://github.com/TerminatedProcess/webme-ai-conversation-assistant).
# resume  → reopen the conversation's living webme pages and remind Claude to keep them updated.
# compact → remind only (pages are already open).
# startup / clear → new conversation; webme is off. Only prunes pages in ~/webme older than 14 days.
command -v jq >/dev/null || exit 0          # needs jq; without it, do nothing
[[ "$CLAUDE_CODE_REMOTE" == "true" ]] && exit 0   # cloud session: no local browser
input=$(cat)
source=$(jq -r '.source // empty' <<<"$input")
transcript=$(jq -r '.transcript_path // empty' <<<"$input")

case "$source" in
  startup|clear) find "$HOME/webme" -maxdepth 1 -name 'webme-*.html' -mtime +14 -delete 2>/dev/null; exit 0 ;;
  resume|compact) ;;
  *) exit 0 ;;
esac
browser=$(head -1 "$HOME/webme/.browser" 2>/dev/null); browser=${browser:-default}
open_page() {  # $1 = page path. Works on Linux, macOS, Windows (Git Bash).
  case "$(uname -s)" in
    Darwin) if [[ $browser == default ]]; then open "$1"; else open -a "$browser" "$1"; fi ;;
    MINGW*|MSYS*|CYGWIN*) if [[ $browser == default ]]; then cmd.exe //c start "" "$1"; else "$browser" "$1" & fi ;;
    *) if [[ $browser == default ]]; then setsid xdg-open "file://$1" >/dev/null 2>&1 & else setsid $browser "file://$1" >/dev/null 2>&1 & fi ;;
  esac
}
[[ -f "$transcript" ]] || exit 0

# Every .html file this conversation wrote/edited that still carries the webme marker, newest first.
pages=()
while IFS= read -r f; do
  [[ -f "$f" ]] && grep -q '<meta name="webme"' "$f" && pages+=("$f")
done < <(grep -o '"file_path":"[^"]*\.html"' "$transcript" | sed 's/^"file_path":"//; s/"$//' | tac | awk '!seen[$0]++')

(( ${#pages[@]} )) || exit 0

list=""
for p in "${pages[@]}"; do
  kind=$(grep -o 'name="webme-kind" content="[a-z]*"' "$p" | sed 's/.*content="//; s/"//'); kind=${kind:-living}
  purpose=$(grep -o 'name="webme-purpose" content="[^"]*"' "$p" | sed 's/.*content="//; s/"$//')
  list+="- $p [$kind]${purpose:+ — $purpose}"$'\n'
  if [[ "$source" == resume && "$kind" == living ]]; then
    open_page "$p"
  fi
done

jq -n --arg l "$list" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("webme is ACTIVE for this conversation. Pages (already open in the browser; do not reopen):\n" + $l + "Keep living pages updated every turn per the webme skill (clear old chg markers, mark new changes with class chg); keep all pages in sync: when data changes, update every page that shows it, snapshots included. For a new webme request, decide per the skill whether it adds to one of these or starts a new page.")
  }
}'
