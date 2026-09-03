#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../app"
flutter pub get
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
