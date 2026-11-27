#!/usr/bin/env bash
# Build the project's webme index page: Active and Retired lists, one link per page.
# The index opens the active pages itself (window.open with a name per page), so its
# links switch to a page's tab when it is open and reopen it when it was closed.
# On later auto-refreshes it opens only pages added since (e.g. a new page).
#
# Usage: make-index.sh <open-list.txt>     → prints the index path
# Retired list: <open-list>.retired.txt next to it (same name, ".retired.txt").
set -u
list=$1
retired=${list%.txt}.retired.txt
key=$(basename "${list%.txt}")
out="$HOME/webme/.index/$key.html"
mkdir -p "${out%/*}"

esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g' <<<"$1"; }
meta() { grep -o "name=\"$2\" content=\"[^\"]*\"" "$1" 2>/dev/null | head -1 | sed 's/.*content="//; s/"$//'; }
url() { local p=$1; p=${p//%/%25}; p=${p// /%20}; p=${p//#/%23}; printf 'file://%s' "$p"; }

rows() {   # $1 = list file; prints <li> rows
  n=0; local f
  [[ -f $1 ]] || return 0
  while IFS= read -r f; do
    [[ -n $f && -f $f ]] || continue
    n=$((n+1))
    local title; title=$(grep -o '<title>[^<]*</title>' "$f" | head -1 | sed 's/<[^>]*>//g')
    local kind; kind=$(meta "$f" webme-kind); kind=${kind:-living}
    local when; when=$(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null)
    local ts; ts=$(date -r "$f" +%s 2>/dev/null)
    local name; name="webme-$(basename "$f" .html)"
    printf '<li><a class="row %s" href="%s" target="%s" data-name="%s" data-ts="%s"><span class="main"><span class="title">%s<span class="fresh">updated</span></span><span class="purpose">%s</span><span class="file">%s</span></span><span class="side"><span class="kind">%s</span><span class="ago">%s</span></span></a></li>\n' \
      "$kind" "$(url "$f")" "$name" "$name" "$ts" "$(esc "${title:-$(basename "$f")}")" "$(esc "$(meta "$f" webme-purpose)")" "$(esc "$(basename "$f")")" "$kind" "$when"
  done < <(awk '!seen[$0]++' "$1")
}

active=$(rows "$list"); na=$(grep -c "<li>" <<<"$active")
old=$(rows "$retired"); nr=$(grep -c "<li>" <<<"$old")

proj=$(esc "$key"); proj=${proj#_}; proj=/${proj//_//}   # best-effort readable project path
cat >"$out" <<EOF
<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="refresh" content="15">
<title>webme · $na active</title>
<style>
:root{color-scheme:light dark;
  --ground:#f7f5f0;--surface:#fff;--line:#e4dfd3;--ink:#1d1b16;--mut:#5f5a4f;
  --acc:#c25e00;--acc-tint:#fdeedd;--acc-line:#f3cfa6;
  --liv:#2b7a3d;--liv-tint:#e3f3e6;--snap:#1c62b0;--snap-tint:#e2edf9;--hover:#fbf6ee}
@media (prefers-color-scheme:dark){:root{
  --ground:#16150f;--surface:#1f1e18;--line:#34312a;--ink:#ece8df;--mut:#a59f92;
  --acc:#ff9f45;--acc-tint:#33230f;--acc-line:#5a3b17;
  --liv:#7fd18f;--liv-tint:#1b2e1f;--snap:#8cbcf2;--snap-tint:#172535;--hover:#26241d}}
*{box-sizing:border-box}
html{background:var(--ground);scrollbar-color:var(--line) var(--ground)}
body{margin:0;font:15px/1.5 system-ui,sans-serif;color:var(--ink)}
::selection{background:var(--acc-line);color:var(--ink)}
.shell{background:var(--acc-tint);border-bottom:1px solid var(--acc-line)}
.bar{max-width:880px;margin:0 auto;padding:1.4rem 1.25rem 1.2rem;display:flex;align-items:center;justify-content:space-between;gap:1rem;flex-wrap:wrap}
h1{margin:0;font-size:1.35rem;font-weight:700;letter-spacing:-.015em}
h1 span{color:var(--acc)}
.proj{margin-top:.15rem;color:var(--mut);font:.82rem/1.4 ui-monospace,monospace;overflow-wrap:anywhere}
.counts{display:flex;gap:1.2rem;font-variant-numeric:tabular-nums}
.counts div{text-align:right;color:var(--mut);font-size:.78rem}
.counts b{display:block;color:var(--ink);font-size:1.3rem;line-height:1.1}
main{max-width:880px;margin:0 auto;padding:.6rem 1.25rem 3rem}
h2{margin:2rem 0 .6rem;font-size:1rem;font-weight:650}
h2 small{color:var(--mut);font-weight:400;margin-left:.35rem;font-variant-numeric:tabular-nums}
ul{list-style:none;margin:0;padding:0;background:var(--surface);border:1px solid var(--line);border-radius:10px;overflow:hidden;box-shadow:0 1px 2px rgba(40,30,10,.05),0 4px 14px rgba(40,30,10,.04)}
li+li{border-top:1px solid var(--line)}
.row{display:flex;justify-content:space-between;align-items:flex-start;gap:1.2rem;padding:.85rem 1.1rem;color:inherit;text-decoration:none;transition:background .15s cubic-bezier(.16,1,.3,1)}
.row:hover{background:var(--hover)}
.row:focus-visible{outline:2px solid var(--acc);outline-offset:-2px;border-radius:9px}
.main{display:flex;flex-direction:column;gap:.15rem;min-width:0}
.title{font-weight:650;font-size:1rem;color:var(--ink);text-wrap:balance}
.row:hover .title{text-decoration:underline;text-decoration-color:var(--acc);text-underline-offset:3px}
.purpose{color:var(--mut);font-size:.9rem;max-width:65ch}
.file{color:var(--mut);font:.75rem/1.4 ui-monospace,monospace;opacity:.85}
.side{display:flex;flex-direction:column;align-items:flex-end;gap:.35rem;flex:none}
.kind{font-size:.72rem;font-weight:650;padding:.1rem .5rem;border-radius:999px;color:var(--liv);background:var(--liv-tint)}
.snapshot .kind{color:var(--snap);background:var(--snap-tint)}
.ago{color:var(--mut);font-size:.78rem;font-variant-numeric:tabular-nums;white-space:nowrap}
.fresh{display:none;margin-left:.55rem;vertical-align:.1em;font-size:.68rem;font-weight:700;color:var(--acc);background:var(--acc-tint);border:1px solid var(--acc-line);border-radius:999px;padding:0 .45rem}
.is-fresh .fresh{display:inline-block}
.retired .row{color:var(--mut)}.retired .title{color:var(--mut);font-weight:600}
.retired .kind{color:var(--mut);background:transparent;border:1px solid var(--line)}
.empty{padding:1rem 1.1rem;color:var(--mut);font-size:.9rem}
footer{margin-top:1.6rem;color:var(--mut);font-size:.78rem}
@media (max-width:560px){.row{flex-direction:column;gap:.4rem}.side{flex-direction:row;align-items:center}}
</style></head><body>
<div class="shell"><div class="bar">
  <div><h1><span>webme</span> pages</h1><div class="proj">$proj</div></div>
  <div class="counts"><div><b>$na</b>active</div><div><b>$nr</b>retired</div></div>
</div></div>
<main>
<h2>Active <small>$na</small></h2>
<ul id="active">
${active:-<li class="empty">No active pages.</li>}
</ul>
<h2>Retired <small>$nr</small></h2>
<ul class="retired">
${old:-<li class="empty">Nothing retired. Ask Claude to retire a page to stop it reopening; the file stays.</li>}
</ul>
<footer>Click a page to switch to its tab, or reopen it if you closed it. This list refreshes every 15 seconds.</footer>
</main>
<script>
// Open each active page once per index tab (remembered across auto-refreshes).
const seen = new Set(JSON.parse(sessionStorage.getItem('webme-opened') || '[]'));
let opened = 0;
for (const a of document.querySelectorAll('#active a.row')) {
  if (seen.has(a.dataset.name)) continue;
  if (window.open(a.href, a.dataset.name)) { seen.add(a.dataset.name); opened++; }
}
sessionStorage.setItem('webme-opened', JSON.stringify([...seen]));
// Relative times.
const now = Date.now() / 1000;
for (const r of document.querySelectorAll('a.row')) {
  const d = now - r.dataset.ts, m = Math.round(d / 60), h = Math.round(d / 3600), dd = Math.round(d / 86400);
  const e = r.querySelector('.ago');
  e.title = new Date(r.dataset.ts * 1000).toLocaleString();
  e.textContent = d < 60 ? 'just now' : m < 60 ? m + ' min ago' : h < 48 ? h + ' h ago' : dd + ' days ago';
  if (d < 900) r.classList.add('is-fresh');
}
if (opened) setTimeout(() => window.focus(), 300);
</script>
</body></html>
EOF
printf '%s\n' "$out"
