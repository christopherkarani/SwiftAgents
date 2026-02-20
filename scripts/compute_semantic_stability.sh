#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <semantic_baseline.csv>" >&2
  exit 64
fi

csv_file="$1"
if [ ! -f "$csv_file" ]; then
  echo "error: file not found: $csv_file" >&2
  exit 66
fi

awk -F, '
function trim(s) {
  gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
  return s
}
function update(metric, value) {
  v = trim(value)
  if (v == "") {
    return
  }
  if (v + 0 < 0 || v + 0 > 1) {
    invalid = 1
    return
  }
  sum[metric] += (v + 0)
  cnt[metric] += 1
}
BEGIN {
  invalid = 0
  metrics[1] = "routing"
  metrics[2] = "handoff"
  metrics[3] = "failure_class"
  metrics[4] = "tool_args"
  metrics[5] = "output_correct"

  weight["routing"] = 25
  weight["handoff"] = 25
  weight["failure_class"] = 15
  weight["tool_args"] = 15
  weight["output_correct"] = 20
}
NR == 1 { next }
{
  update("routing", $2)
  update("handoff", $3)
  update("failure_class", $4)
  update("tool_args", $5)
  update("output_correct", $6)
}
END {
  if (invalid) {
    print "error=invalid_value_out_of_range"
    exit 65
  }

  weighted_sum = 0
  total_weight = 0
  missing = 0

  for (i = 1; i <= 5; i++) {
    m = metrics[i]
    if (cnt[m] == 0) {
      printf "%s_coverage=0\n", m
      printf "%s_parity_pct=NA\n", m
      missing = 1
      continue
    }

    pct[m] = (sum[m] / cnt[m]) * 100
    weighted_sum += pct[m] * weight[m]
    total_weight += weight[m]

    printf "%s_coverage=%d\n", m, cnt[m]
    printf "%s_parity_pct=%.2f\n", m, pct[m]
  }

  if (total_weight == 0) {
    print "overall_semantic_stability_pct=NA"
    print "status=FAIL"
    exit 2
  }

  overall = weighted_sum / total_weight
  printf "overall_semantic_stability_pct=%.2f\n", overall

  if (missing) {
    print "status=FAIL"
    print "reason=missing_dimension_coverage"
    exit 2
  }

  status = "PASS"
  if (overall < 99.0) { status = "FAIL" }
  if (pct["tool_args"] < 99.5) { status = "FAIL" }
  if (pct["output_correct"] < 99.0) { status = "FAIL" }

  printf "status=%s\n", status

  if (status == "PASS") {
    exit 0
  }
  exit 2
}
' "$csv_file"
