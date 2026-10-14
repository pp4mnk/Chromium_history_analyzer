#!/bin/sh
# pp4mnk Slimjet History Analyzer v3.1 - EasyOS / GTKdialog
# Copyright (c) 2026 pp4mnk
# Local, read-only browsing-history report. No Python required.
set -eu
BASE=${SLIMJET_PORTABLE:-/files/portable/Slimjet-portable64}
OUTPUT=${SLIMJET_REPORT:-/root/slimjet-top50-pp4mnk.txt}
error() {
  printf 'ERROR: %s\n' "$1" >&2
  if command -v gtkdialog >/dev/null 2>&1; then
    export ERROR_GUI='<window title="Slimjet History Analyzer - Error"><vbox><text><label>"Error: check the terminal for details."</label></text><button ok></button></vbox></window>'
    gtkdialog --center --program=ERROR_GUI 2>/dev/null || :
  fi
  exit 1
}
command -v sqlite3 >/dev/null 2>&1 || error 'Install the sqlite3 command-line package (libsqlite3 alone is not enough).'
command -v gtkdialog >/dev/null 2>&1 || error 'gtkdialog is missing.'

# Optional override: SLIMJET_HISTORY=/full/path/to/History ./script.sh
if [ -n "${SLIMJET_HISTORY:-}" ]; then
  HISTORY=$SLIMJET_HISTORY
else
  # Portable Slimjet may keep its active profile in /dev/shm.
  # Prefer the most recently modified History database among known locations.
  HISTORY=$(find -L "$BASE" /dev/shm/pp4mnk-browsers /dev/shm/slimjet /root/.config/slimjet /root/.config/chromium /home/spot/.config/slimjet \
    -type f -name History -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2- || :)
fi
[ -n "$HISTORY" ] && [ -r "$HISTORY" ] || error "Cannot find a readable Slimjet History database. Set SLIMJET_HISTORY=/full/path/to/History."
WORK=$(mktemp -d /tmp/pp4mnk-slimjet-v3.XXXXXX) || exit 1
trap 'rm -rf "$WORK"' EXIT
trap 'exit 1' HUP INT TERM
DB=$WORK/History
ROWS=$WORK/rows.txt

# First try SQLite's consistent online backup, allowing time for locks.
if ! sqlite3 -readonly -cmd '.timeout 2500' "$HISTORY" ".backup '$DB'" 2>"$WORK/backup-error"; then
  rm -f "$DB"
  # Best-effort fallback for a database held open by Slimjet.
  # Copy WAL and SHM alongside the DB; never modify the source files.
  cp "$HISTORY" "$DB" || error 'Could not copy the Slimjet History database.'
  for suffix in -wal -shm; do
    if [ -f "$HISTORY$suffix" ]; then
      cp "$HISTORY$suffix" "$DB$suffix" || error "Could not copy History$suffix."
    fi
  done
fi
CHECK=$(sqlite3 -readonly -cmd '.timeout 2500' "$DB" 'PRAGMA quick_check;' 2>/dev/null) || error 'History snapshot unreadable. Close Slimjet and retry.'
[ "$CHECK" = ok ] || error 'History snapshot failed integrity check. Close Slimjet and retry.'

if ! sqlite3 -noheader -separator '|' "$DB" > "$ROWS" <<'SQL'
WITH urls_parsed AS (
 SELECT lower(substr(rest, 1, CASE WHEN instr(rest, '/') > 0 THEN instr(rest, '/') - 1 ELSE length(rest) END)) AS authority, visit_count
 FROM (
  SELECT substr(url, instr(url, '://') + 3) AS rest, visit_count
  FROM urls WHERE url LIKE 'http://%' OR url LIKE 'https://%'
 )
), hosts AS (
 SELECT CASE WHEN authority LIKE 'www.%' THEN substr(authority, 5) ELSE authority END AS domain, visit_count
 FROM urls_parsed
), clean AS (
 SELECT replace(replace(replace(domain, '|', ''), char(10), ''), char(13), '') AS website, visit_count FROM hosts
)
SELECT website, sum(visit_count) AS visits
FROM clean WHERE website <> ''
GROUP BY website ORDER BY visits DESC, website ASC LIMIT 50;
SQL
then error 'Could not query Slimjet history.'; fi

{
 printf 'pp4mnk Slimjet History Analyzer v3.1 - EasyOS\n'
 printf 'TOP 50 MOST VISITED DOMAINS\nSource: %s\n' "$HISTORY"
 printf 'Counts reflect recorded visits retained in this Slimjet profile.\n\n'
 printf '%-48s %s\n' WEBSITE VISITS
 printf '%s\n' '---------------------------------------------------------------'
 awk -F '|' '{printf "%-48s %s\n", $1, $2}' "$ROWS"
} > "$OUTPUT"

export ROWS OUTPUT
GUI='<window title="pp4mnk Slimjet History Analyzer v3.1 - EasyOS" default-width="720" default-height="560" window-position="1">
<vbox spacing="8">
 <frame Slimjet - Top 50 Most Visited Websites>
  <text><label>"Ranking by domain | Visits stored in Slimjet history"</label></text>
  <tree rules-hint="true" headers-visible="true">
   <label>Website|Visits</label>
   <input>cat "$ROWS"</input>
   <variable>SLIMJET_HISTORY_TREE</variable>
  </tree>
 </frame>
 <text><label>"Report saved in /root/slimjet-top50-pp4mnk.txt (or SLIMJET_REPORT)"</label></text>
 <hbox>
  <button>
   <label>Open text report</label>
   <action>sh -c '\''if command -v defaulttexteditor >/dev/null 2>&amp;1; then defaulttexteditor "$OUTPUT"; elif command -v geany >/dev/null 2>&amp;1; then geany "$OUTPUT"; else xdg-open "$OUTPUT"; fi'\'' &amp;</action>
  </button>
  <button cancel><label>Close</label></button>
 </hbox>
</vbox>
</window>'
export GUI
printf 'Slimjet history: %s\nReport: %s\n' "$HISTORY" "$OUTPUT"
gtkdialog --center --program=GUI
