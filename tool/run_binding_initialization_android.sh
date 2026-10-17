#!/bin/zsh
# Builds and installs smoke-test demo APKs; does not publish or clear logcat.
set -euo pipefail
repo_dir="${0:A:h:h}"
device_id="${1:?Usage: zsh tool/run_binding_initialization_android.sh <device-id>}"
run_stamp="$(date +%Y%m%d%H%M%S)-$$"
result_dir="$repo_dir/build/binding-initialization-$run_stamp"
mkdir -p "$result_dir"
cd "$repo_dir/demo"
for mode in profile release; do
  for scenario in repeat conflict; do
    run_id="$run_stamp-$mode-$scenario"
    build_log="$result_dir/$mode-$scenario-build.log"
    device_log="$result_dir/$mode-$scenario-device.log"
    print "Building $mode / $scenario"
    if ! flutter build apk "--$mode" --no-pub \
      --target=../tool/binding_initialization_smoke.dart \
      "--dart-define=SCREEN_ADAPT_BINDING_SMOKE_CASE=$scenario" \
      "--dart-define=SCREEN_ADAPT_BINDING_SMOKE_RUN=$run_id" \
      > "$build_log" 2>&1; then
      tail -n 60 "$build_log"
      exit 1
    fi
    adb -s "$device_id" shell am force-stop dev.designscale.regression
    adb -s "$device_id" install -r "build/app/outputs/flutter-apk/app-$mode.apk"
    adb -s "$device_id" shell am start -W -n dev.designscale.regression/.MainActivity
    passed=0
    for attempt in {1..30}; do
      adb -s "$device_id" logcat -d -v brief \
        -s flutter AndroidRuntime > "$device_log"
      if rg -F "FAIL binding initialization: $scenario mode=$mode run=$run_id" "$device_log"; then
        tail -n 80 "$device_log"
        exit 1
      fi
      if rg -F "PASS binding initialization: $scenario mode=$mode run=$run_id" "$device_log"; then
        passed=1
        break
      fi
      sleep 1
    done
    if (( ! passed )); then
      print "Timed out waiting for test result: $mode / $scenario"
      tail -n 80 "$device_log"
      exit 1
    fi
  done
done
print "All four Android initialization checks passed. Logs: $result_dir"
