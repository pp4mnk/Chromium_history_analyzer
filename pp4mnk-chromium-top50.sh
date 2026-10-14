#!/bin/sh
# pp4mnk Chromium TOP 50 - EasyOS / Puppy Linux
# Read-only report grouped by website domain. Requires sqlite3.
set -eu
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo 'ERROR: sqlite3 is not installed. Install the sqlite3 package using PKGget.' >&2
  exit 1
fi
TMP="$(mktemp -d /tmp/pp4mnk-chromium-top50.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
LIST="$TMP/profiles"
: > "$LIST"
for base in /root/.config/chromium /home/spot/.config/chromium /root/.config/google-chrome /home/spot/.config/google-chrome /root/.config/chromium-browser /home/spot/.config/chromium-browser; do
  [ -d "$base" ] || continue
  for db in "$base"/Default/History "$base"/Profile\ */History; do
    [ -f "$db" ] && printf '%s\n' "$db" >> "$LIST"
  done
done
if [ ! -s "$LIST" ]; then
  echo 'No Chromium history database found in standard EasyOS locations.' >&2
  echo 'If you use a custom --user-data-dir, edit the base paths in this script.' >&2
  exit 1
fi
: > "$TMP/visits.tsv"
while IFS= read -r db; do
  echo "Reading: $db" >&2
  # SQLite reads the database without changing it, including current WAL records.
  sqlite3 -readonly -separator '|' "$db" 'PRAGMA busy_timeout=3000; SELECT url, visit_count, last_visit_time FROM urls WHERE visit_count > 0;' 2>/dev/null >> "$TMP/visits.tsv" || echo "WARNING: Unable to read $db" >&2
done < "$LIST"
if [ ! -s "$TMP/visits.tsv" ]; then
  echo 'No visit data found. Check Chromium profiles and sqlite3 permissions.' >&2
  exit 1
fi
awk -F '|' '
function domain(url, a, n, host) {
  if (url !~ /^https?:\/\//) return ""
  sub(/^https?:\/\//, "", url)
  split(url,a,"/"); host=tolower(a[1]); sub(/:[0-9]+$/, "", host)
  sub(/^www\./, "", host)
  return host
}
{
  d=domain($1); if (d=="") next
  count[d]+=$2
  if ($3>last[d]) last[d]=$3
}
END { for (d in count) printf "%d\t%s\t%s\n",count[d],d,last[d] }
' "$TMP/visits.tsv" | sort -t "$(printf '\t')" -k1,1nr | head -n 50 > "$TMP/top50.tsv"
REPORT="${HOME}/chromium-top50-pp4mnk.txt"
{
  echo 'PP4MNK - CHROMIUM TOP 50 MOST VISITED WEBSITES'
  echo 'EasyOS | Grouped by hostname | All detected Chromium profiles'
  echo 'NOTE: Counts come from Chromium visit_count and depend on retained history.'
  echo '---------------------------------------------------------------'
  printf '%-5s %-12s %s\n' 'RANK' 'VISITS' 'WEBSITE'
  awk -F '\t' '{printf "%-5d %-12s %s\n", NR, $1, $2}' "$TMP/top50.tsv"
} > "$REPORT"
cat "$REPORT"
printf '\nReport saved to: %s\n' "$REPORT"
