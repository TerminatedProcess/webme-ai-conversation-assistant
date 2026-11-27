#!/usr/bin/env bash
# SessionStart hook for the `webme` skill (https://github.com/TerminatedProcess/webme-ai-conversation-assistant).
# Pages of a conversation are listed in ~/webme/.open/<session-id>.txt (one absolute path per line).
# Retiring a page = removing its line; the file stays and expires with the 14-day retention.
# resume  → reopen every page on the list (living and snapshot) and remind Claude to keep them updated.
# compact → remind only (pages are already open).
# startup / clear → new conversation; webme is off. Only prunes pages and open lists in ~/webme older than 14 days.
# No list yet (conversation from before 1.1.0) → fall back to scanning the transcript.
command -v jq >/dev/null || exit 0          # needs jq; without it, do nothing
[[ "$CLAUDE_CODE_REMOTE" == "true" ]] && exit 0   # cloud session: no local browser
input=$(cat)
source=$(jq -r '.source // empty' <<<"$input")
transcript=$(jq -r '.transcript_path // empty' <<<"$input")
sid=$(jq -r '.session_id // empty' <<<"$input")

case "$source" in
  startup|clear)
    find "$HOME/webme" -maxdepth 1 -name 'webme-*.html' -mtime +14 -delete 2>/dev/null
    find "$HOME/webme/.open" -maxdepth 1 -name '*.txt' -mtime +14 -delete 2>/dev/null
    exit 0 ;;
  resume|compact) ;;
  *) exit 0 ;;
esac
openlist="$HOME/webme/.open/$sid.txt"
pages=()
if [[ -n "$sid" && -f "$openlist" ]]; then
  # The conversation's open list; drop lines whose files are gone, then rewrite it.
  while IFS= read -r f; do
    [[ -n "$f" && -f "$f" ]] && pages+=("$f")
  done < <(awk '!seen[$0]++' "$openlist")
  tmp=$(mktemp "$openlist.XXXXXX") && { (( ${#pages[@]} )) && printf '%s\n' "${pages[@]}" >"$tmp" || : >"$tmp"; } && mv "$tmp" "$openlist"
  note="Open list: ~/webme/.open/$sid.txt (retire = remove the line; don't delete the file)."
else
  # Fallback (no list yet): every .html file this conversation wrote/edited that still carries the webme marker, newest first.
  [[ -f "$transcript" ]] || exit 0
  while IFS= read -r f; do
    [[ -f "$f" ]] && grep -q '<meta name="webme"' "$f" && pages+=("$f")
  done < <(grep -o '"file_path":"[^"]*\.html"' "$transcript" | sed 's/^"file_path":"//; s/"$//' | tac | awk '!seen[$0]++')
  note="No open list yet for this conversation: create ~/webme/.open/${sid:-<session-id>}.txt with these paths (one per line); retire = remove the line; don't delete the file."
fi

(( ${#pages[@]} )) || exit 0

list=""
for p in "${pages[@]}"; do
  kind=$(grep -o 'name="webme-kind" content="[a-z]*"' "$p" | sed 's/.*content="//; s/"//'); kind=${kind:-living}
  purpose=$(grep -o 'name="webme-purpose" content="[^"]*"' "$p" | sed 's/.*content="//; s/"$//')
  list+="- $p [$kind]${purpose:+ — $purpose}"$'\n'
done
# All pages in one new window, one tab each.
[[ "$source" == resume ]] && bash "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/skills/webme/scripts/open-page.sh" "${pages[@]}"

jq -n --arg l "$list" --arg n "$note" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("webme is ACTIVE for this conversation. Pages (already open in the browser; do not reopen):\n" + $l + $n + "\nKeep living pages updated every turn per the webme skill (clear old chg markers, mark new changes with class chg); keep all pages on the list in sync: when data changes, update every page that shows it, snapshots included. For a new webme request, decide per the skill whether it adds to one of these or starts a new page.")
  }
}'
