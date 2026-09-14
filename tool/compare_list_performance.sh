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

size_line="$(adb -s "$device_id" shell wm size | tail -n 1 | tr -d '\r')"
resolution="${size_line##*: }"
screen_width="${resolution%x*}"
screen_height="${resolution#*x}"
drag_x=$((screen_width * 50 / 100))
top_y=$((screen_height * 25 / 100))
bottom_y=$((screen_height * 80 / 100))

typeset -A result_p90
typeset -A result_p99
typeset -A result_frames
typeset -A result_janky

run_case() {
  local engine="$1"
  local target="$2"
  local report="$report_dir/${device_id}_${engine}_complex_list.txt"

  (
    cd "$example_dir"
    flutter build apk --profile --target "$target"
  )
  adb -s "$device_id" install -r "$apk_path" >/dev/null
  adb -s "$device_id" logcat -c
  adb -s "$device_id" shell am force-stop "$package_name"
  adb -s "$device_id" shell am start -n "$component_name" >/dev/null
  sleep 4

  for index in {1..30}; do
    if (( index <= 20 )); then
      adb -s "$device_id" shell input swipe \
        "$drag_x" "$bottom_y" "$drag_x" "$top_y" 250
    else
      adb -s "$device_id" shell input swipe \
        "$drag_x" "$top_y" "$drag_x" "$bottom_y" 250
    fi
  done
  sleep 2

  adb -s "$device_id" logcat -d -s flutter | \
    rg '\[demo:list_performance\]|Unhandled Exception|ERROR' > "$report" || true

  if ! rg -q "engine=$engine ready" "$report"; then
    print -u2 "$engine 未正常启动: $report"
    exit 1
  fi

  local summary="$(rg "engine=$engine totalFrames=" "$report" | tail -n 1)"
  if [[ -z "$summary" ]]; then
    print -u2 "$engine 未采集到足够帧: $report"
    exit 1
  fi

  result_frames[$engine]="$(print -r -- "$summary" | sed -E 's/.*totalFrames=([0-9]+).*/\1/')"
  result_p90[$engine]="$(print -r -- "$summary" | sed -E 's/.*p90=([0-9]+)us.*/\1/')"
  result_p99[$engine]="$(print -r -- "$summary" | sed -E 's/.*p99=([0-9]+)us.*/\1/')"
  result_janky[$engine]="$(print -r -- "$summary" | sed -E 's/.*janky16ms=([0-9]+).*/\1/')"
  print "$engine 完成: frames=${result_frames[$engine]} "
  print "  p90=${result_p90[$engine]}us p99=${result_p99[$engine]}us janky=${result_janky[$engine]}"
}

run_case screen_adapt lib/performance/screen_adapt_list_main.dart
run_case flutter_screenutil lib/performance/screenutil_list_main.dart

print ""
print "复杂列表性能对比 ($device_id / $resolution)"
print "screen_adapt:       frames=${result_frames[screen_adapt]} p90=${result_p90[screen_adapt]}us p99=${result_p99[screen_adapt]}us janky=${result_janky[screen_adapt]}"
print "flutter_screenutil: frames=${result_frames[flutter_screenutil]} p90=${result_p90[flutter_screenutil]}us p99=${result_p99[flutter_screenutil]}us janky=${result_janky[flutter_screenutil]}"

if (( result_p90[screen_adapt] < result_p90[flutter_screenutil] )); then
  print "p90: screen_adapt 更低"
elif (( result_p90[screen_adapt] > result_p90[flutter_screenutil] )); then
  print "p90: flutter_screenutil 更低"
else
  print "p90: 两者相同"
fi
