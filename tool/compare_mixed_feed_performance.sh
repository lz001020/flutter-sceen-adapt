#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
PERF_MIXED_FEED=1 \
PERF_SCROLL_COUNT=50 \
PERF_SCROLL_DURATION_MS=120 \
PERF_REPORT_LABEL=mixed_feed \
PERF_ROUNDS=3 \
PERF_AUTO_SCROLL=1 \
  "$repo_dir/tool/compare_list_performance.sh" "${1:-emulator-5554}"
