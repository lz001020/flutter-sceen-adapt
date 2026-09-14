#!/bin/zsh

set -euo pipefail

repo_dir="${0:A:h:h}"
example_dir="$repo_dir/example"
device_id="${1:-emulator-5554}"
package_name="com.example.example"
component_name="$package_name/$package_name.MainActivity"
report_dir="$repo_dir/build/performance"
apk_path="$example_dir/build/app/outputs/flutter-apk/app-profile.apk"
scroll_count="${PERF_SCROLL_COUNT:-30}"
scroll_duration_ms="${PERF_SCROLL_DURATION_MS:-250}"
scroll_pause_seconds="${PERF_SCROLL_PAUSE_SECONDS:-0}"
report_label="${PERF_REPORT_LABEL:-complex_list}"
rounds="${PERF_ROUNDS:-1}"
auto_scroll="${PERF_AUTO_SCROLL:-0}"

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

typeset -a adapt_frames adapt_p90 adapt_p99 adapt_janky adapt_build adapt_raster
typeset -a util_frames util_p90 util_p99 util_janky util_build util_raster

median() {
  local count=$#
  local index=$(((count + 1) / 2))
  print -l -- "$@" | sort -n | sed -n "${index}p"
}

record_result() {
  local engine="$1" frames="$2" p90="$3" p99="$4"
  local janky="$5" build="$6" raster="$7"
  if [[ "$engine" == "screen_adapt" ]]; then
    adapt_frames+=("$frames")
    adapt_p90+=("$p90")
    adapt_p99+=("$p99")
    adapt_janky+=("$janky")
    adapt_build+=("$build")
    adapt_raster+=("$raster")
  else
    util_frames+=("$frames")
    util_p90+=("$p90")
    util_p99+=("$p99")
    util_janky+=("$janky")
    util_build+=("$build")
    util_raster+=("$raster")
  fi
}

run_case() {
  local engine="$1" target="$2" round="$3"
  local report="$report_dir/${device_id}_${engine}_${report_label}_round${round}.txt"
  local -a build_command=(flutter build apk --profile --target "$target")
  if [[ "$auto_scroll" == "1" ]]; then
    build_command+=(
      --dart-define=PERF_AUTO_SCROLL=true
      --dart-define=PERF_SCROLL_COUNT="$scroll_count"
      --dart-define=PERF_SCROLL_DURATION_MS="$scroll_duration_ms"
    )
  fi

  (cd "$example_dir" && "${build_command[@]}")
  adb -s "$device_id" install -r "$apk_path" >/dev/null
  adb -s "$device_id" logcat -c
  adb -s "$device_id" shell am force-stop "$package_name"
  adb -s "$device_id" shell am start -n "$component_name" >/dev/null
  sleep 4

  if [[ "$auto_scroll" == "1" ]]; then
    local complete=0
    for attempt in {1..40}; do
      if adb -s "$device_id" logcat -d -s flutter | \
          rg -q "engine=$engine automationComplete=$scroll_count"; then
        complete=1
        break
      fi
      sleep 0.25
    done
    if (( complete == 0 )); then
      print -u2 "$engine 第 $round 轮自动滚动未完成"
      exit 1
    fi
  else
    local forward_count=$((scroll_count * 2 / 3))
    for ((index = 1; index <= scroll_count; index++)); do
      if (( index <= forward_count )); then
        adb -s "$device_id" shell input swipe \
          "$drag_x" "$bottom_y" "$drag_x" "$top_y" "$scroll_duration_ms"
      else
        adb -s "$device_id" shell input swipe \
          "$drag_x" "$top_y" "$drag_x" "$bottom_y" "$scroll_duration_ms"
      fi
      if [[ "$scroll_pause_seconds" != "0" ]]; then
        sleep "$scroll_pause_seconds"
      fi
    done
  fi
  sleep 1

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

  local frames="$(print -r -- "$summary" | sed -E 's/.*totalFrames=([0-9]+).*/\1/')"
  local p90="$(print -r -- "$summary" | sed -E 's/.*p90=([0-9]+)us.*/\1/')"
  local p99="$(print -r -- "$summary" | sed -E 's/.*p99=([0-9]+)us.*/\1/')"
  local janky="$(print -r -- "$summary" | sed -E 's/.*janky16ms=([0-9]+).*/\1/')"
  local build="$(print -r -- "$summary" | sed -E 's/.*buildP90=([0-9]+)us.*/\1/')"
  local raster="$(print -r -- "$summary" | sed -E 's/.*rasterP90=([0-9]+)us.*/\1/')"
  record_result "$engine" "$frames" "$p90" "$p99" "$janky" "$build" "$raster"
  print "第 $round 轮 $engine: frames=$frames totalP90=${p90}us"
  print "  buildP90=${build}us rasterP90=${raster}us p99=${p99}us janky=$janky"
}

for ((round = 1; round <= rounds; round++)); do
  if (( round % 2 == 1 )); then
    run_case screen_adapt lib/performance/screen_adapt_list_main.dart "$round"
    run_case flutter_screenutil lib/performance/screenutil_list_main.dart "$round"
  else
    run_case flutter_screenutil lib/performance/screenutil_list_main.dart "$round"
    run_case screen_adapt lib/performance/screen_adapt_list_main.dart "$round"
  fi
done

adapt_frames_median="$(median "${adapt_frames[@]}")"
adapt_p90_median="$(median "${adapt_p90[@]}")"
adapt_p99_median="$(median "${adapt_p99[@]}")"
adapt_janky_median="$(median "${adapt_janky[@]}")"
adapt_build_median="$(median "${adapt_build[@]}")"
adapt_raster_median="$(median "${adapt_raster[@]}")"
util_frames_median="$(median "${util_frames[@]}")"
util_p90_median="$(median "${util_p90[@]}")"
util_p99_median="$(median "${util_p99[@]}")"
util_janky_median="$(median "${util_janky[@]}")"
util_build_median="$(median "${util_build[@]}")"
util_raster_median="$(median "${util_raster[@]}")"

print ""
print "复杂列表 $rounds 轮中位数 ($device_id / $resolution / ${scroll_duration_ms}ms x $scroll_count)"
print "screen_adapt:       frames=$adapt_frames_median totalP90=${adapt_p90_median}us buildP90=${adapt_build_median}us rasterP90=${adapt_raster_median}us p99=${adapt_p99_median}us janky=$adapt_janky_median"
print "flutter_screenutil: frames=$util_frames_median totalP90=${util_p90_median}us buildP90=${util_build_median}us rasterP90=${util_raster_median}us p99=${util_p99_median}us janky=$util_janky_median"

frame_delta=$((adapt_frames_median - util_frames_median))
if (( frame_delta < 0 )); then
  frame_delta=$((-frame_delta))
fi
frame_average=$(((adapt_frames_median + util_frames_median) / 2))
frame_delta_percent=$((frame_delta * 10000 / frame_average))
print "帧数中位数差异: $((frame_delta_percent / 100)).$((frame_delta_percent % 100))%"
