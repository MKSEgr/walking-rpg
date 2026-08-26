#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MOBILE_DIR="$ROOT_DIR/mobile"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or is not available in PATH." >&2
  exit 1
fi

cd "$MOBILE_DIR"
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --fatal-infos
flutter test

echo "Mobile project is ready. Android and iOS host projects are versioned in the repository."
