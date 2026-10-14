#!/bin/sh
# pp4mnk Chromium History Analyzer v2 - EasyOS
# Read-only analysis of Chromium's browsing history.
set -eu
HISTORY='/home/chromium/.config/chromium/Default/History'
OUTPUT='/root/chromium-top50-pp4mnk.txt'
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo 'ERROR: sqlite3 command-line utility is not installed.' >&2
  echo 'The libsqlite3 shared library alone is not sufficient.' >&2
  exit 1
fi
if [ ! -r "$HISTORY" ]; then
  echo "ERROR: Cannot read Chromium history: $HISTORY" >&2
  exit 1
fi
TMPDIR_WORK=$(mktemp -d /tmp/pp4mnk-chromium.XXXXXX)
trap 'rm -rf "$TMPDIR_WORK"' EXIT HUP INT TERM
# SQLite backup handles a live browser database more safely than a plain file copy.
if ! sqlite3 "$HISTORY" ".backup '$TMPDIR_WORK/History'"; then
  echo 'ERROR: Could not create a temporary SQLite backup.' >&2
  exit 1
fi
{
  echo 'pp4mnk Chromium History Analyzer v2 - EasyOS'
  echo 'TOP 50 MOST VISITED DOMAINS'
  echo 'Source: /home/chromium/.config/chromium/Default/History'
  echo 'Counts are Chromium recorded visits in the retained history.'
  echo '------------------------------------------------------------'
  sqlite3 -header -column "$TMPDIR_WORK/History" <<'SQL'
WITH cleaned AS (
 SELECT lower(substr(host, 1, CASE WHEN instr(host, '/') > 0 THEN instr(host, '/') - 1 ELSE length(host) END)) AS domain, visit_count
 FROM (
   SELECT CASE
     WHEN instr(url, '://') > 0 THEN substr(url, instr(url, '://') + 3)
     ELSE url
   END AS host, visit_count
   FROM urls
   WHERE url LIKE 'http://%' OR url LIKE 'https://%'
 )
), grouped AS (
 SELECT CASE WHEN domain LIKE 'www.%' THEN substr(domain, 5) ELSE domain END AS domain, visit_count
 FROM cleaned
)
SELECT domain AS Website, sum(visit_count) AS Visits
FROM grouped
WHERE domain <> ''
GROUP BY domain
ORDER BY Visits DESC, Website ASC
LIMIT 50;
SQL
} | tee "$OUTPUT"
printf '\nReport saved to: %s\n' "$OUTPUT"
