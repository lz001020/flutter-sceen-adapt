#!/bin/zsh
# Read-only validation; does not stage, commit, upload or publish.
set -euo pipefail
repo_dir="${0:A:h:h}"
cd "$repo_dir"
flutter pub get
(cd example && flutter pub get)
(cd benchmark && flutter pub get)
dart format --output=none --set-exit-if-changed lib test example/lib example/test benchmark/lib benchmark/test
flutter analyze
flutter test
(cd example && flutter analyze && flutter test)
(cd benchmark && flutter analyze && flutter test)
git diff --check
flutter pub publish --dry-run
