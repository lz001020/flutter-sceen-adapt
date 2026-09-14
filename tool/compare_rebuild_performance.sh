#!/bin/zsh

set -euo pipefail

repo_dir="${0:A:h:h}"
example_dir="$repo_dir/example"
device_id="${1:-emulator-5554}"
package_name="com.example.example"
component_name="$package_name/$package_name.MainActivity"
report_dir="$repo_dir/build/performance"
apk_path="$example_dir/build/app/outputs/flutter-apk/app-profile.apk"

if ! adb -s "$device_id" get-state >/dev/null 2>&1; then
  print -u2 "设备不可用: $device_id"
  exit 1
fi

mkdir -p "$report_dir"

typeset -A result_total
typeset -A result_build
typeset -A result_raster
typeset -A result_frames

run_case() {
  local engine="$1"
  local target="$2"
  local report="$report_dir/${device_id}_${engine}_rebuild.txt"

  (
    cd "$example_dir"
    flutter build apk --profile --target "$target"
  )
  adb -s "$device_id" install -r "$apk_path" >/dev/null
  adb -s "$device_id" logcat -c
  adb -s "$device_id" shell am force-stop "$package_name"
  adb -s "$device_id" shell am start -n "$component_name" >/dev/null
  sleep 12

  adb -s "$device_id" logcat -d -s flutter | \
    rg '\[demo:rebuild_performance\]|Unhandled Exception|ERROR' > "$report" || true

  local summary="$(rg "engine=$engine totalFrames=" "$report" | tail -n 1)"
  if [[ -z "$summary" ]]; then
    print -u2 "$engine 未采集到足够帧: $report"
    exit 1
  fi

  result_frames[$engine]="$(print -r -- "$summary" | sed -E 's/.*totalFrames=([0-9]+).*/\1/')"
  result_total[$engine]="$(print -r -- "$summary" | sed -E 's/.*p90=([0-9]+)us.*/\1/')"
  result_build[$engine]="$(print -r -- "$summary" | sed -E 's/.*buildP90=([0-9]+)us.*/\1/')"
  result_raster[$engine]="$(print -r -- "$summary" | sed -E 's/.*rasterP90=([0-9]+)us.*/\1/')"
}

run_case screen_adapt_const lib/performance/screen_adapt_rebuild_main.dart
run_case flutter_screenutil_inline lib/performance/screenutil_rebuild_main.dart

print "复杂列表高频重建对比 ($device_id)"
print "screen_adapt const:      frames=${result_frames[screen_adapt_const]} totalP90=${result_total[screen_adapt_const]}us buildP90=${result_build[screen_adapt_const]}us rasterP90=${result_raster[screen_adapt_const]}us"
print "flutter_screenutil inline: frames=${result_frames[flutter_screenutil_inline]} totalP90=${result_total[flutter_screenutil_inline]}us buildP90=${result_build[flutter_screenutil_inline]}us rasterP90=${result_raster[flutter_screenutil_inline]}us"
