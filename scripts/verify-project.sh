#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

printf '%s\n' "Checking required project files..."
for file in \
  "$ROOT_DIR/PROJECT_VISION.md" \
  "$ROOT_DIR/backend/pom.xml" \
  "$ROOT_DIR/mobile/pubspec.yaml" \
  "$ROOT_DIR/mobile/android/app/src/main/AndroidManifest.xml" \
  "$ROOT_DIR/mobile/ios/Podfile.lock" \
  "$ROOT_DIR/mobile/ios/Runner/Info.plist" \
  "$ROOT_DIR/mobile/ios/Runner/Runner.entitlements" \
  "$ROOT_DIR/docs/ARCHITECTURE.md" \
  "$ROOT_DIR/scripts/bootstrap-action-pin-policy.sh" \
  "$ROOT_DIR/scripts/ci/action-pin-policy-requirements.txt" \
  "$ROOT_DIR/scripts/ci/test_bootstrap_action_pin_policy.py" \
  "$ROOT_DIR/scripts/ci/verify_backend_base_pins.py" \
  "$ROOT_DIR/scripts/ci/test_verify_backend_base_pins.py" \
  "$ROOT_DIR/scripts/ci/verify_postgres_image_pins.py" \
  "$ROOT_DIR/scripts/ci/test_verify_postgres_image_pins.py" \
  "$ROOT_DIR/scripts/ci/verify_action_pins.py" \
  "$ROOT_DIR/scripts/ci/test_verify_action_pins.py" \
  "$ROOT_DIR/scripts/ci/verify_runner_image_pins.py" \
  "$ROOT_DIR/scripts/ci/test_verify_runner_image_pins.py" \
  "$ROOT_DIR/scripts/ci/verify_workflow_toolchain_pins.py" \
  "$ROOT_DIR/scripts/ci/test_verify_workflow_toolchain_pins.py" \
  "$ROOT_DIR/scripts/ci/verify_flutter_pub_lock.py" \
  "$ROOT_DIR/scripts/ci/test_verify_flutter_pub_lock.py" \
  "$ROOT_DIR/scripts/ci/verify_ios_pod_lock.py" \
  "$ROOT_DIR/scripts/ci/test_verify_ios_pod_lock.py" \
  "$ROOT_DIR/scripts/ci/verify_build_tool_wrapper_pins.py" \
  "$ROOT_DIR/scripts/ci/test_verify_build_tool_wrapper_pins.py"; do
  if [ ! -f "$file" ]; then
    echo "Missing: $file" >&2
    exit 1
  fi
done

ACTION_POLICY_PYTHON=${ACTION_POLICY_PYTHON:-python3}
ACTION_PIN_POLICY_VENV=${ACTION_PIN_POLICY_VENV:-"$ROOT_DIR/.venv/action-pin-policy"}
if ! "$ACTION_POLICY_PYTHON" -c \
  'import yaml; raise SystemExit(yaml.__version__ != "6.0.3")' \
  >/dev/null 2>&1; then
  printf '%s\n' "Bootstrapping pinned GitHub Action policy parser..."
  PYTHON="$ACTION_POLICY_PYTHON" \
    ACTION_PIN_POLICY_VENV="$ACTION_PIN_POLICY_VENV" \
    sh "$ROOT_DIR/scripts/bootstrap-action-pin-policy.sh"
  ACTION_POLICY_PYTHON=
  for candidate in \
    "$ACTION_PIN_POLICY_VENV/bin/python" \
    "$ACTION_PIN_POLICY_VENV/Scripts/python.exe"; do
    if [ -x "$candidate" ]; then
      ACTION_POLICY_PYTHON=$candidate
      break
    fi
  done
  if [ -z "$ACTION_POLICY_PYTHON" ]; then
    echo "Action pin policy virtualenv has no supported Python executable." >&2
    exit 1
  fi
fi

printf '%s\n' "Checking immutable backend container base images..."
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/verify_backend_base_pins.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/test_verify_backend_base_pins.py"

printf '%s\n' "Checking immutable PostgreSQL test infrastructure..."
PYTHONDONTWRITEBYTECODE=1 \
  "$ACTION_POLICY_PYTHON" "$ROOT_DIR/scripts/ci/verify_postgres_image_pins.py"
PYTHONDONTWRITEBYTECODE=1 \
  "$ACTION_POLICY_PYTHON" "$ROOT_DIR/scripts/ci/test_verify_postgres_image_pins.py"

printf '%s\n' "Checking immutable GitHub Action references..."
PYTHONDONTWRITEBYTECODE=1 \
  "$ACTION_POLICY_PYTHON" "$ROOT_DIR/scripts/ci/verify_action_pins.py"
PYTHONDONTWRITEBYTECODE=1 \
  "$ACTION_POLICY_PYTHON" "$ROOT_DIR/scripts/ci/test_verify_action_pins.py"
PYTHONDONTWRITEBYTECODE=1 \
  "$ACTION_POLICY_PYTHON" "$ROOT_DIR/scripts/ci/test_bootstrap_action_pin_policy.py"

printf '%s\n' "Checking explicit GitHub-hosted runner OS labels..."
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/verify_runner_image_pins.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/test_verify_runner_image_pins.py"

printf '%s\n' "Checking exact GitHub workflow toolchains..."
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/verify_workflow_toolchain_pins.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/test_verify_workflow_toolchain_pins.py"

printf '%s\n' "Checking frozen Flutter pub dependencies..."
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/verify_flutter_pub_lock.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/test_verify_flutter_pub_lock.py"

printf '%s\n' "Checking frozen iOS CocoaPods dependencies..."
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/verify_ios_pod_lock.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/test_verify_ios_pod_lock.py"

printf '%s\n' "Checking immutable build-tool wrapper downloads..."
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/verify_build_tool_wrapper_pins.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/scripts/ci/test_verify_build_tool_wrapper_pins.py"

printf '%s\n' "Project structure is complete."

if command -v java >/dev/null 2>&1; then
  java -version
else
  echo "Java is not installed; backend build skipped."
fi

if command -v flutter >/dev/null 2>&1; then
  (
    cd "$ROOT_DIR/mobile" &&
      flutter pub get --enforce-lockfile &&
      flutter analyze --no-pub &&
      flutter test --no-pub
  )
else
  echo "Flutter is not installed; mobile checks skipped."
fi
