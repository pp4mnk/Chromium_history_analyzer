#!/bin/sh
# pp4mnk Firefox History Analyzer v3.1 - EasyOS / GTKdialog
# Copyright (c) 2026 pp4mnk
# Local read-only report; works with portable Firefox and RAM profiles.
set -eu
BASE=${FIREFOX_PORTABLE:-/files/portable/Firefox-portable64}
OUTPUT=${FIREFOX_REPORT:-/root/firefox-top50-pp4mnk.txt}
error() { printf 'ERROR: %s\n' "$1" >&2; if command -v gtkdialog >/dev/null 2>&1; then export ERROR_GUI='<window title="Firefox History Analyzer - Error"><vbox><text><label>"Error: check the terminal for details."</label></text><button ok></button></vbox></window>'; gtkdialog --center --program=ERROR_GUI 2>/dev/null || :; fi; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || error 'sqlite3 is missing. Install the sqlite3 command-line package.'
command -v gtkdialog >/dev/null 2>&1 || error 'gtkdialog is missing.'
# Optional override for profiles in unusual locations.
if [ -n "${FIREFOX_PLACES:-}" ]; then
  HISTORY=$FIREFOX_PLACES
else
  # Locate profile databases, prioritising the most recently updated copy.
  # Avoid arbitrary system-wide scans and don't follow symlink loops.
  HISTORY=$(find -L "$BASE" /dev/shm/pp4mnk-browsers /dev/shm/firefox /root/.mozilla/firefox /home/spot/.mozilla/firefox \
    -type f -name places.sqlite -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2- || :)
fi
[ -n "$HISTORY" ] && [ -r "$HISTORY" ] || error "Cannot find places.sqlite in $BASE or common RAM/profile directories. Set FIREFOX_PLACES=/full/path/places.sqlite to select it."
WORK=$(mktemp -d /tmp/pp4mnk-firefox-v3.XXXXXX) || exit 1
trap 'rm -rf "$WORK"' EXIT
trap 'exit 1' HUP INT TERM
DB=$WORK/places.sqlite
ROWS=$WORK/rows.txt
# Try a consistent SQLite online backup first, allowing time for Firefox locks.
# Some portable Firefox builds hold a lock that prevents this operation.
if ! sqlite3 -readonly -cmd '.timeout 2500' "$HISTORY" ".backup '$DB'" 2>"$WORK/backup-error"; then
  rm -f "$DB"
  # Fallback: take a best-effort snapshot of the database and its WAL files.
  # Copy all three into a private directory, without touching the originals.
  # This can fail if Firefox writes during copying; closing Firefox is the
  # safest fallback if the snapshot does not pass integrity checking.
  cp "$HISTORY" "$DB" || error 'Could not copy places.sqlite.'
  for suffix in -wal -shm; do
    if [ -f "$HISTORY$suffix" ]; then
      cp "$HISTORY$suffix" "$DB$suffix" || error "Could not copy places.sqlite$suffix."
    fi
  done
fi
# Validate the snapshot before generating the report.
CHECK=$(sqlite3 -readonly -cmd '.timeout 2500' "$DB" 'PRAGMA quick_check;' 2>/dev/null) || error 'Snapshot cannot be read. Close Firefox and retry.'
[ "$CHECK" = ok ] || error 'Snapshot failed integrity check. Close Firefox and retry.'
if ! sqlite3 -noheader -separator '|' "$DB" > "$ROWS" <<'SQL'
WITH hosts AS (
 SELECT lower(substr(rest, 1, CASE WHEN instr(rest, '/') > 0 THEN instr(rest, '/')-1 ELSE length(rest) END)) AS authority, visit_count
 FROM (
   SELECT substr(url, instr(url, '://') + 3) AS rest, visit_count
   FROM moz_places WHERE url LIKE 'http://%' OR url LIKE 'https://%'
 )
), domains AS (
 SELECT CASE WHEN authority LIKE 'www.%' THEN substr(authority, 5) ELSE authority END AS domain, visit_count FROM hosts
)
SELECT replace(replace(replace(domain, '|', ''), char(10), ''), char(13), '') AS Website,
       sum(visit_count) AS Visits
FROM domains WHERE domain <> ''
GROUP BY Website ORDER BY Visits DESC, Website ASC LIMIT 50;
SQL
then error 'Could not query Firefox history.'; fi
{
 printf 'pp4mnk Firefox History Analyzer v3.1 - EasyOS\n'
 printf 'TOP 50 MOST VISITED DOMAINS\nSource: %s\n' "$HISTORY"
 printf 'Counts reflect visits retained in this Firefox profile.\n\n'
 printf '%-48s %s\n' WEBSITE VISITS
 printf '%s\n' '---------------------------------------------------------------'
 awk -F '|' '{printf "%-48s %s\n", $1, $2}' "$ROWS"
} > "$OUTPUT"
# GTKdialog can read the pipe-delimited data directly.
# Paths are passed via environment variables, not interpolated into shell actions.
export ROWS OUTPUT
GUI='<window title="pp4mnk Firefox History Analyzer v3.1 - EasyOS" default-width="720" default-height="560" window-position="1">
<vbox spacing="8">
 <frame Firefox - Top 50 Most Visited Websites>
  <text><label>"Ranking by domain | Visits stored in Firefox history"</label></text>
  <tree rules-hint="true" headers-visible="true">
   <label>Website|Visits</label>
   <input>cat "$ROWS"</input>
   <variable>FIREFOX_HISTORY_TREE</variable>
  </tree>
 </frame>
 <text><label>"Report saved in /root/firefox-top50-pp4mnk.txt (or FIREFOX_REPORT)"</label></text>
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
printf 'Firefox profile: %s\nReport: %s\n' "$HISTORY" "$OUTPUT"
gtkdialog --center --program=GUI
