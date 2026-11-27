#!/usr/bin/env bash
# SessionStart hook for the `webme` skill (https://github.com/TerminatedProcess/webme-ai-conversation-assistant).
# Pages belong to a PROJECT (the directory Claude Code started in), not to one conversation.
# Open list: ~/webme/.open/<project-key>.txt, one absolute page path per line; key = the directory with
# every character outside [A-Za-z0-9._-] turned into "_".
# Retire = move the line to the retired list; the file stays. Nothing is ever deleted or expired by this hook.
# Retired list: <key>.retired.txt next to it. Index page (Active + Retired): ~/webme/.index/<key>.html,
# rebuilt on every event by scripts/make-index.sh.
# startup / resume → reopen: one active page → that page; two or more → the index, which opens the
#                    pages itself as tabs (so its links switch to them). Then remind Claude.
# clear / compact  → remind only (the pages are still open in the browser).
command -v jq >/dev/null || exit 0          # needs jq; without it, do nothing
[[ "$CLAUDE_CODE_REMOTE" == "true" ]] && exit 0   # cloud session: no local browser
input=$(cat)
source=$(jq -r '.source // empty' <<<"$input")
sid=$(jq -r '.session_id // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input"); cwd=${cwd:-${CLAUDE_PROJECT_DIR:-$PWD}}
command -v cygpath >/dev/null && cwd=$(cygpath -u "$cwd")   # Windows: same form as Git Bash's pwd
case "$source" in startup|resume|clear|compact) ;; *) exit 0 ;; esac

key=$(printf %s "$cwd" | tr -c 'A-Za-z0-9._-' _)
openlist="$HOME/webme/.open/$key.txt"

# Migrate a pre-1.3.0 per-conversation list into the project list.
old="$HOME/webme/.open/$sid.txt"
if [[ -n "$sid" && -f "$old" && "$old" != "$openlist" ]]; then
  mkdir -p "${openlist%/*}"; cat "$old" >>"$openlist"; rm -f "$old"
fi
[[ -f "$openlist" ]] || exit 0

# Drop lines whose files are gone and duplicates, then rewrite the list.
pages=()
while IFS= read -r f; do
  [[ -n "$f" && -f "$f" ]] && pages+=("$f")
done < <(awk '!seen[$0]++' "$openlist")
tmp=$(mktemp "$openlist.XXXXXX") && { (( ${#pages[@]} )) && printf '%s\n' "${pages[@]}" >"$tmp" || : >"$tmp"; } && mv "$tmp" "$openlist"
(( ${#pages[@]} )) || exit 0

list=""
for p in "${pages[@]}"; do
  kind=$(grep -o 'name="webme-kind" content="[a-z]*"' "$p" | sed 's/.*content="//; s/"//'); kind=${kind:-living}
  purpose=$(grep -o 'name="webme-purpose" content="[^"]*"' "$p" | sed 's/.*content="//; s/"$//')
  list+="- $p [$kind]${purpose:+ — $purpose}"$'\n'
done
scripts="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/skills/webme/scripts"
index=$(bash "$scripts/make-index.sh" "$openlist")
if [[ "$source" == startup || "$source" == resume ]]; then
  if (( ${#pages[@]} > 1 )); then bash "$scripts/open-page.sh" "$index"; else bash "$scripts/open-page.sh" "${pages[0]}"; fi
fi

jq -n --arg l "$list" --arg f "$openlist" --arg i "$index" --arg s "$scripts" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("webme is ACTIVE for this project. Pages (already open in the browser; do not reopen):\n" + $l + "Open list: " + $f + " (new page = append its path; retire = move the line to the .retired.txt list next to it, never delete the file). After any list change run: bash " + $s + "/make-index.sh " + $f + " (rebuilds the index page " + $i + ").\nThese pages carry over across /clear and new conversations: continue them. Keep living pages updated every turn per the webme skill (clear old chg markers, mark new changes with class chg); keep all pages on the list in sync: when data changes, update every page that shows it, snapshots included. For a new webme request, decide per the skill whether it adds to one of these or starts a new page.")
  }
}'
