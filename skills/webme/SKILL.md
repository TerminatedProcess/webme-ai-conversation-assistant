---
name: webme
description: Maintain live, auto-refreshing local web pages for the conversation: a running summary (state, recommendations, numbers, deadlines, open questions, decisions) updated every turn with orange arrows on what changed, plus one-off pages such as charts or document lists. Several pages per conversation; Claude decides whether a request adds to an existing page or starts a new one. Not for cloud (web) sessions. Use ONLY when the user explicitly asks — "webme", "/webme", "make a web page of this conversation", "keep a running summary page". Never start one unprompted.
---

# webme — living pages for the conversation

Long chats scroll away. A webme page is the user's **stable reference**: what
is true *now*, not a transcript. Keep chat replies short and let pages carry
the detail. A conversation can have **several pages**, one per purpose.

## Where it runs

Global skill for Claude Code on any machine: Linux, macOS, Windows (desktop
app or CLI; its shell is Git Bash, so `~` and bash work there too).

**Cloud sessions (Claude Code on the web) can't use it.** The page would be
written on the remote machine, where the user's browser can't open it, and
publishing it somewhere breaks the "stays local" rule. In a cloud session
(no local desktop, e.g. `CLAUDE_CODE_REMOTE` is set), say so in one line and
keep the summary in chat instead.

## Where pages live

All pages go in **`~/webme/`** (Windows: `%USERPROFILE%\webme`), one folder for
every project, named `webme-<topic>-<purpose>.html`, a short kebab slug (e.g.
`webme-hostlore-ui.html`, `webme-taxes-allocation-pie.html`). It's outside
every repo, so pages never get committed. **Retention: 14 days.** The
SessionStart hook deletes pages not modified for 14 days, on every startup
and `/clear` (Claude Code; without the hook, delete old pages yourself).

## Each request: add to a page, or start a new one?

**`/clear` ends the topic.** Pages from before a `/clear` or from an earlier
conversation are finished: never edit them. If the user wants one back, build
a new page from it.

Within this conversation, decide yourself; don't ask. Match the request
against the **purpose** of each page this conversation made, not just its topic:
- **Same purpose → add to that page.** More facts for a running summary, one
  more slice on an existing chart, more years on an existing document list.
- **Different purpose → new page**, even if the topic is the same. "Summarize
  our conversation", "pie chart of the allocation" and "pull up my tax
  documents for 2022–2024" are three pages, even if they're all about taxes.
- **A different topic → always a new page.**
- **Say what you chose in one line** ("new page: `webme-tax-docs.html`" or
  "added to `webme-hostlore-ui.html`"). The user redirects if it's wrong.

## First run of the skill: default browser or a specific one?

The choice is saved per machine in **`~/webme/.browser`** (one line: `default`,
or the command for a specific browser). If that file is missing, this is the
first run: before opening anything, ask with AskUserQuestion:
- **Default browser**: whatever the OS opens HTML files with.
- **A specific browser**: then ask which one, find its command or path, and
  save that.

If you know a browser on this machine has the Claude extension, say so in
that option's description: only that browser lets Claude screenshot and
check the page. After the first run, never ask again; read the file. The
user changes it by saying so, and then you rewrite the file. The resume hook
reads the same file.

Open each page **once** (it refreshes itself; never re-open it) with the
script that ships next to this file:

```bash
bash <this skill's folder>/scripts/open-page.sh <file> [<file> ...]
```

It reads `~/webme/.browser` and opens the pages in **one new window**, so the
page appears on the workspace / virtual desktop the user is on (a new tab
would join the browser's existing window, wherever that is). It handles
Linux, macOS and Windows (Git Bash), and finds the executable of the default
browser so that one gets a new window too. **Several pages at once (e.g. a
request that creates more than one): pass them all in one call**, so they
become tabs of the same new window instead of one window each.

Never kill a running browser to open a page. A tab the user opened is outside
Claude's tab group, so Claude can't see or switch to it.

## Start a page

1. **File:** `~/webme/webme-<slug>.html` (above), unless the user names a
   path. Never reuse a name that exists for a different purpose.
2. **`<head>` must have:**
   - `<meta name="webme" content="active">`: the hooks find pages by it.
   - `<meta name="webme-purpose" content="<one line: what this page is for>">`.
   - `<meta name="webme-kind" content="living">` or `"snapshot"`:
     - **living:** a running summary, updated every turn (below).
     - **snapshot:** a one-off view (a chart, a document list, a report).
       Update it when the user asks, or when the data it shows changes
       anywhere in the conversation (see "Keep every page in sync").
   - `<meta http-equiv="refresh" content="15">`.
3. **Build it from the whole conversation so far** (living), or from the
   data the request names (snapshot).
4. **Open it once** in the saved browser (table above).
5. **Add it to the open list** (next section).

## The open list: which pages are live

Each conversation has an **open list**, `~/webme/.open/$CLAUDE_CODE_SESSION_ID.txt`:
one absolute page path per line. It decides which pages the resume hook
reopens and which pages you keep in sync. (`$CLAUDE_CODE_SESSION_ID` is set in
Claude's Bash tool.)

- **Creating a page:** append its absolute path (no duplicates; create the
  dir/file if missing):
  ```bash
  f=~/webme/.open/$CLAUDE_CODE_SESSION_ID.txt; p=/abs/path/webme-x.html; mkdir -p "${f%/*}"; grep -qxF "$p" "$f" 2>/dev/null || echo "$p" >> "$f"
  ```
- **Renaming a page:** after `mv`, replace its line:
  ```bash
  f=~/webme/.open/$CLAUDE_CODE_SESSION_ID.txt; sed -i.bak "s|^$old\$|$new|" "$f" && rm -f "$f.bak"   # $old, $new = absolute paths
  ```
- **Retire** ("retire / close / drop / stop showing that page", "I read it"):
  remove its line only. The file stays on disk and still expires with the
  14-day retention. **Never delete a page unless the user explicitly says
  delete.**
  ```bash
  f=~/webme/.open/$CLAUDE_CODE_SESSION_ID.txt; p=/abs/path/webme-x.html; grep -vxF "$p" "$f" > "$f.tmp"; mv "$f.tmp" "$f"
  ```
- Conversations from before 1.1.0 have no list; the hook then scans the
  transcript. Create the list the first time you touch a page.

## Checking a page yourself (screenshot)

Only possible in a browser with the Claude in Chrome extension. Its
`navigate` refuses `file://` URLs, even with "Allow access to file URLs" on.
To look at a page, serve its folder on localhost only for the check, then
stop the server:

```bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory ~/webme >/dev/null 2>&1 &
# navigate a new Claude tab to http://127.0.0.1:8765/<file> → screenshot → close that tab
kill %1    # stop the server (or kill its PID)
```

Do this after big layout changes (new charts or diagrams), not every turn.

## Lifetime

webme stays on for the **whole conversation**. `/clear` or a fresh
conversation ends it: off until the user asks again, and old pages are not
continued (they expire after 14 days).

The session-start hook (`hooks/webme-session-start.sh`, installed with the
Claude Code plugin; other agents can run it from their own session-start
hook, or go without it):
- **startup / clear:** deletes `~/webme/webme-*.html` and `~/webme/.open/*.txt` older than 14 days. Nothing else.
- **resume:** reopens every page on this conversation's open list (living and snapshot) in the saved
  browser and injects "webme is ACTIVE, pages: …" plus the open-list path.
  Lines whose files no longer exist are dropped from the list.
- **compact:** injects the same reminder only; the pages are already open.

So when you see that reminder, keep updating those pages and don't reopen
them. No memory file is needed.

## Every turn while active

**Keep every page on the open list in sync.** Each turn, check all of
them, not just the one the request was about. If a fact, number or decision
changes and another page shows it or is built from it, update that page in
the same turn too. Example: the summary page records a new allocation figure,
so the allocation pie chart is redrawn with it. A snapshot page is exempt
only from the "every turn" summary updates; it still changes whenever its
own data changes.

- **Update the page in the same turn** as any new fact, decision, number or
  question. Bump "Last updated" (date, and time if it helps).
- **Change markers:** first remove every `chg` class left from the previous
  update, then add `class="chg"` to each heading, row, list item or box you
  changed. An orange ➜ arrow appears beside each one. **No legend**; the
  user knows what the arrows mean.
- **Replace stale content in place.** The page shows what's true *now*.
  Only the decision log grows; old entries stay.
- Answered questions leave "Open questions". Their answers go into the
  body and the decision log.
- In chat, say which pages were updated and name the sections that changed. Don't
  repeat the content.
- If a turn adds nothing new, leave the page alone.

## Page shape

Self-contained HTML in a single file: inline CSS and SVG, no CDNs, no
external scripts. That keeps it private and working offline.

A snapshot page is just its one view (chart, list, report), a header with
its purpose, and Sources. For a living page, use the sections that fit the
topic, roughly in this order:

| Section | Purpose |
|---|---|
| Header | One line of context (who/what/where) + Last updated |
| **Alert box** (orange) | Deadlines, risks, the one thing not to get wrong |
| **Current recommendation / state** (green) | The answer as of now, with the one-line *why* for each point |
| Numbers | Tables of costs, comparisons, scenarios (typical vs worst case), totals row |
| Steps / flow | Ordered actions with dates, or a diagram |
| Things to know | Key concepts the user needed explained |
| Open questions | Highlighted TBDs; the most important first |
| Decision log | Dated, append-only |
| Sources | Links + date checked |

## Pick the right visual

Use whichever communicates fastest:
- **Table:** options compared side by side; costs.
- **Inline SVG bar chart:** comparing magnitudes (premiums, totals). If a
  `dataviz` skill is installed, load it first for colors and marks.
- **Flow chart / timeline (inline SVG, or styled HTML boxes with arrows):**
  sequences, deadlines, "if X then Y" logic.
- **Highlighting:** `<mark>` or colored spans for the critical numbers or
  words. Never use color alone; pair it with a symbol or text (✔ ✖ ⚠).
- **Image:** embed a local image by relative path when the user provided one
  or it really helps.
- Plain short bullets when nothing else fits. Text the user can skim, not essays.

## Style

- Readable: ~18px body, max-width ~960px, high contrast, light background.
- Fixed classes: `.alert` (orange), `.rec` (green), `.tbd` (orange bold for
  unknowns), `.muted`, `.num` (right-aligned numbers), `tr.total`, and
  `.chg:not(tr)::before, tr.chg > :first-child::before { content: "➜ "; color: #e67700; font-weight: bold; font-size: 1.3em; }`
  (a pseudo-element on the `tr` itself would add a cell and shift the row).
- No sound, autoplay or animation.

## Guardrails

- The page stays **local**. Never upload, publish or share it. It often holds
  personal health, financial or legal details.
- Uncertain or stale figures carry a `.tbd` marker and say where they came
  from. Facts verified online carry the check date in Sources.
- The page mirrors the conversation. Don't put recommendations on it that
  weren't made in chat.
