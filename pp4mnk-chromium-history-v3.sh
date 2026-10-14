#!/bin/sh
# pp4mnk Chromium History Analyzer v3 - EasyOS / GTKdialog
# Copyright (c) 2026 pp4mnk. Local, read-only browser history reporting.
set -eu
HISTORY=${CHROMIUM_HISTORY:-/home/chromium/.config/chromium/Default/History}
OUTPUT=${CHROMIUM_REPORT:-/root/chromium-top50-pp4mnk.txt}

error() {
  printf 'ERROR: %s\n' "$1" >&2
  if command -v gtkdialog >/dev/null 2>&1; then
    export ERROR_MESSAGE="$1"
    gtkdialog --center --program=ERROR_DIALOG 2>/dev/null || true
  fi
  exit 1
}
ERROR_DIALOG='<window title="Chromium History Analyzer - Error" window-position="1"><vbox><text><label>"An error occurred. Check the terminal for details."</label></text><button ok></button></vbox></window>'
export ERROR_DIALOG
command -v sqlite3 >/dev/null 2>&1 || error 'sqlite3 is missing. Install the sqlite3 command-line package (libsqlite3 alone is not enough).'
[ -r "$HISTORY" ] || error "Cannot read Chromium history: $HISTORY"
command -v gtkdialog >/dev/null 2>&1 || error 'gtkdialog is missing. Install GTKdialog to use the graphical interface.'

WORK=$(mktemp -d /tmp/pp4mnk-chromium-v3.XXXXXX) || exit 1
trap 'rm -rf "$WORK"' EXIT
trap 'exit 1' HUP INT TERM
DB="$WORK/History"
ROWS="$WORK/rows.txt"
if ! sqlite3 "$HISTORY" ".backup '$DB'"; then
  error 'Unable to create a temporary SQLite backup of Chromium history.'
fi
# Use a tab-separated export; URLs/domains are normalized to remove control characters.
if ! sqlite3 -noheader -separator '|' "$DB" > "$ROWS" <<'SQL'
WITH cleaned AS (
 SELECT lower(substr(host, 1, CASE WHEN instr(host, '/') > 0 THEN instr(host, '/') - 1 ELSE length(host) END)) AS domain, visit_count
 FROM (
   SELECT CASE WHEN instr(url, '://') > 0 THEN substr(url, instr(url, '://') + 3) ELSE url END AS host, visit_count
   FROM urls WHERE url LIKE 'http://%' OR url LIKE 'https://%'
 )
), grouped AS (
 SELECT CASE WHEN domain LIKE 'www.%' THEN substr(domain, 5) ELSE domain END AS domain, visit_count FROM cleaned
)
SELECT replace(replace(replace(domain, '|', ''), char(10), ''), char(13), '') AS Website,
       sum(visit_count) AS Visits
FROM grouped WHERE domain <> ''
GROUP BY Website ORDER BY Visits DESC, Website ASC LIMIT 50;
SQL
then
  error 'Unable to query the Chromium history database.'
fi
{
 printf 'pp4mnk Chromium History Analyzer v3 - EasyOS\n'
 printf 'TOP 50 MOST VISITED DOMAINS\n'
 printf 'Source: %s\n' "$HISTORY"
 printf 'Counts are recorded visits in retained Chromium history.\n\n'
 printf '%-48s %s\n' 'WEBSITE' 'VISITS'
 printf '%s\n' '---------------------------------------------------------------'
 awk -F '|' '{printf "%-48s %s\n", $1, $2}' "$ROWS"
} > "$OUTPUT"

# GTKdialog tree reads pipe-separated rows, with two columns.
# XML escape only file paths interpolated into XML attributes.
xml_escape() { printf '%s' "$1" | sed -e 's/\&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"; }
ROWS_XML=$(xml_escape "$ROWS")
OUTPUT_XML=$(xml_escape "$OUTPUT")
GUI="<window title=\"pp4mnk Chromium History Analyzer v3 - EasyOS\" default-width=\"680\" default-height=\"560\" window-position=\"1\">
<vbox spacing=\"8\">
 <frame Chromium - Top 50 Most Visited Websites>
  <text><label>\"Ranking by domain | Visits stored in Chromium history\"</label></text>
  <tree rules-hint=\"true\" headers-visible=\"true\">
   <label>Website|Visits</label>
   <input file>\"$ROWS_XML\"</input>
   <variable>HISTORY_TREE</variable>
  </tree>
 </frame>
 <text><label>\"Report saved to: $OUTPUT_XML\"</label></text>
 <hbox>
  <button>
   <label>Open text report</label>
   <action>sh -c 'if command -v defaulttexteditor >/dev/null 2>&amp;1; then defaulttexteditor \"\$1\"; elif command -v geany >/dev/null 2>&amp;1; then geany \"\$1\"; else xdg-open \"\$1\"; fi' sh '$OUTPUT_XML' &amp;</action>
  </button>
  <button cancel><label>Close</label></button>
 </hbox>
</vbox>
</window>"
export GUI
printf 'Report saved to: %s\n' "$OUTPUT"
gtkdialog --center --program=GUI
