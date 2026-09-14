#!/bin/zsh

set -euo pipefail

repo_dir="${0:A:h:h}"
example_dir="$repo_dir/example"
device_id="${1:-emulator-5554}"
package_name="com.example.example"
component_name="$package_name/$package_name.MainActivity"
report_dir="$repo_dir/build/performance"
apk_path="$example_dir/build/app/outputs/flutter-apk/app-profile.apk"
max_p90_us="${PERF_MAX_P90_US:-16667}"
max_janky_percent="${PERF_MAX_JANK_PERCENT:-5}"

if ! adb -s "$device_id" get-state >/dev/null 2>&1; then
  print -u2 "设备不可用: $device_id"
  exit 1
fi

mkdir -p "$report_dir"

if [[ "${PERF_SKIP_BUILD:-0}" != "1" ]]; then
  (
    cd "$example_dir"
    flutter build apk --profile
  )
fi

adb -s "$device_id" install -r "$apk_path" >/dev/null
adb -s "$device_id" logcat -c
adb -s "$device_id" shell am force-stop "$package_name"
adb -s "$device_id" shell am start \
  -n "$component_name" \
  --es route /performance_demo >/dev/null

sleep 4

size_line="$(adb -s "$device_id" shell wm size | tail -n 1 | tr -d '\r')"
resolution="${size_line##*: }"
screen_width="${resolution%x*}"
screen_height="${resolution#*x}"

if [[ ! "$screen_width" =~ '^[0-9]+$' || ! "$screen_height" =~ '^[0-9]+$' ]]; then
  print -u2 "无法解析设备分辨率: $size_line"
  exit 1
fi

start_x=$((screen_width * 20 / 100))
end_x=$((screen_width * 80 / 100))
drag_y=$((screen_height * 55 / 100))

# Android 16 KB page-size compatibility prompts can cover the first launch.
# Tapping the dialog's OK position is harmless when no prompt is present.
dialog_x=$((screen_width * 46 / 100))
dialog_y=$((screen_height * 81 / 100))
adb -s "$device_id" shell input tap "$dialog_x" "$dialog_y"
sleep 1

adb -s "$device_id" shell dumpsys gfxinfo "$package_name" reset >/dev/null

for index in {1..30}; do
  if (( index % 2 == 1 )); then
    adb -s "$device_id" shell input swipe \
      "$start_x" "$drag_y" "$end_x" "$drag_y" 220
  else
    adb -s "$device_id" shell input swipe \
      "$end_x" "$drag_y" "$start_x" "$drag_y" 220
  fi
done

sleep 2

gfx_report="$report_dir/android_gfxinfo.txt"
flutter_report="$report_dir/flutter_frames.txt"
adb -s "$device_id" shell dumpsys gfxinfo "$package_name" > "$gfx_report"
adb -s "$device_id" logcat -d -s flutter | \
  rg '\[demo:performance\]|Unhandled Exception|ERROR' > "$flutter_report" || true

if ! rg -q 'gesture=30 ' "$flutter_report"; then
  print -u2 "性能操作未完成，请检查启动弹窗或页面路由: $flutter_report"
  exit 1
fi

if ! rg -q 'frames=60 ' "$flutter_report"; then
  print -u2 "未采集到足够的 Flutter FrameTiming: $flutter_report"
  exit 1
fi

summary_line="$(rg 'totalFrames=' "$flutter_report" | tail -n 1)"
total_frames="$(print -r -- "$summary_line" | sed -E 's/.*totalFrames=([0-9]+).*/\1/')"
total_p90="$(print -r -- "$summary_line" | sed -E 's/.*totalP90=([0-9]+)us.*/\1/')"
total_janky="$(print -r -- "$summary_line" | sed -E 's/.*totalJanky16ms=([0-9]+).*/\1/')"

result="PASS"
if (( total_p90 > max_p90_us || total_janky * 100 > total_frames * max_janky_percent )); then
  result="FAIL"
fi

print "性能自动化完成"
print "设备: $device_id ($resolution)"
print "Flutter 帧报告: $flutter_report"
print "Android gfxinfo: $gfx_report"
print "结果: $result (frames=$total_frames p90=${total_p90}us "
print "      janky=$total_janky, 阈值 p90<=${max_p90_us}us / janky<=${max_janky_percent}%)"
print ""
rg 'frames=|gesture=' "$flutter_report" || true

android_frames="$(rg 'Total frames rendered:' "$gfx_report" | head -n 1 | sed -E 's/.*: ([0-9]+).*/\1/')"
if [[ -n "$android_frames" && "$android_frames" != "0" ]]; then
  rg 'Janky frames|50th percentile|90th percentile|95th percentile|99th percentile' \
    "$gfx_report" || true
else
  print "Android gfxinfo 未统计 Flutter SurfaceView 帧，已忽略其无效分位数。"
fi

if [[ "$result" == "FAIL" ]]; then
  exit 1
fi
