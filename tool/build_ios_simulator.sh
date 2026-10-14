#!/bin/zsh
# Build for the host simulator architecture without modifying the Flutter SDK.
set -euo pipefail
repo_dir="${0:A:h:h}"
app="${1:-benchmark}"
case "$app" in
  example|benchmark) ;;
  *) print -u2 'Usage: zsh tool/build_ios_simulator.sh [example|benchmark]'; exit 2 ;;
esac
sim_arch="$(uname -m)"
case "$sim_arch" in
  arm64|x86_64) ;;
  *) print -u2 "Unsupported host architecture: $sim_arch"; exit 2 ;;
esac
cd "$repo_dir/$app"
flutter build ios --simulator --debug --config-only --target=lib/main.dart
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$repo_dir/build/$app-ios-simulator" \
  ARCHS="$sim_arch" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO \
  FLUTTER_TARGET=lib/main.dart build
binary="$repo_dir/build/$app-ios-simulator/Build/Products/Debug-iphonesimulator/Runner.app/Runner"
xcrun lipo "$binary" -verify_arch "$sim_arch"
print "Built simulator app: ${binary:h} ($sim_arch)"
