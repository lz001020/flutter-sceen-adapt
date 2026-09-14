#!/bin/zsh

set -euo pipefail

repo_dir="${0:A:h:h}"
device_id="${1:-emulator-5554}"

PERF_SCROLL_COUNT=50 \
PERF_SCROLL_DURATION_MS=60 \
PERF_SCROLL_PAUSE_SECONDS=0.08 \
PERF_REPORT_LABEL=fast_complex_list \
  "$repo_dir/tool/compare_list_performance.sh" "$device_id"
