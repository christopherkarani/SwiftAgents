#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <metrics.csv> [required_minutes]" >&2
  exit 64
fi

csv_file="$1"
required_minutes="${2:-60}"

if [ ! -f "$csv_file" ]; then
  echo "error: file not found: $csv_file" >&2
  exit 66
fi

if ! [[ "$required_minutes" =~ ^[0-9]+$ ]] || [ "$required_minutes" -le 0 ]; then
  echo "error: required_minutes must be a positive integer" >&2
  exit 65
fi

awk -F, -v required="$required_minutes" '
BEGIN {
  rows = 0
  streak = 0
  max_streak = 0
  new_start_violations = 0
}
NR == 1 {
  header = $0
  if (tolower($0) ~ /activeprevnextruncount/ || tolower($0) ~ /timestamp/) {
    next
  }
}
{
  rows++
  active = $2 + 0
  starts = $3 + 0

  if (starts > 0) {
    new_start_violations++
  }

  if (active == 0 && starts == 0) {
    streak++
    if (streak > max_streak) {
      max_streak = streak
    }
  } else {
    streak = 0
  }
}
END {
  status = (max_streak >= required) ? "PASS" : "FAIL"

  printf "rows_processed=%d\n", rows
  printf "max_zero_streak_minutes=%d\n", max_streak
  printf "required_zero_streak_minutes=%d\n", required
  printf "new_start_violations=%d\n", new_start_violations
  printf "status=%s\n", status

  if (status == "PASS") {
    exit 0
  }
  exit 2
}
' "$csv_file"
