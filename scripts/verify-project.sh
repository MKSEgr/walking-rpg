#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

printf '%s\n' "Checking required project files..."
for file in \
  "$ROOT_DIR/PROJECT_VISION.md" \
  "$ROOT_DIR/backend/pom.xml" \
  "$ROOT_DIR/mobile/pubspec.yaml" \
  "$ROOT_DIR/mobile/android/app/src/main/AndroidManifest.xml" \
  "$ROOT_DIR/mobile/ios/Runner/Info.plist" \
  "$ROOT_DIR/mobile/ios/Runner/Runner.entitlements" \
  "$ROOT_DIR/docs/ARCHITECTURE.md" \
  "$ROOT_DIR/scripts/ci/action-pin-policy-requirements.txt" \
  "$ROOT_DIR/scripts/ci/verify_action_pins.py" \
  "$ROOT_DIR/scripts/ci/test_verify_action_pins.py"; do
  if [ ! -f "$file" ]; then
    echo "Missing: $file" >&2
    exit 1
  fi
done

printf '%s\n' "Checking immutable GitHub Action references..."
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/verify_action_pins.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/test_verify_action_pins.py"

printf '%s\n' "Project structure is complete."

if command -v java >/dev/null 2>&1; then
  java -version
else
  echo "Java is not installed; backend build skipped."
fi

if command -v flutter >/dev/null 2>&1; then
  (cd "$ROOT_DIR/mobile" && flutter pub get && flutter analyze && flutter test)
else
  echo "Flutter is not installed; mobile checks skipped."
fi
