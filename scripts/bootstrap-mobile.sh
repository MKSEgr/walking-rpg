#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MOBILE_DIR="$ROOT_DIR/mobile"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or is not available in PATH." >&2
  exit 1
fi

cd "$MOBILE_DIR"
flutter create --platforms=android,ios --org com.walkingrpg --project-name walking_rpg_mobile .
flutter pub get
flutter analyze
flutter test

echo "Mobile project is ready. Run: cd mobile && flutter run"
