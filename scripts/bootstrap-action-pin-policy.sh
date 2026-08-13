#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PYTHON=${PYTHON:-python3}
VENV_DIR=${ACTION_PIN_POLICY_VENV:-"$ROOT_DIR/.venv/action-pin-policy"}
REQUIREMENTS="$ROOT_DIR/scripts/ci/action-pin-policy-requirements.txt"

if ! "$PYTHON" -c \
  'import sys; raise SystemExit(sys.version_info[:2] != (3, 12))'; then
  echo "Action pin policy bootstrap requires Python 3.12." >&2
  exit 1
fi

if [ ! -x "$VENV_DIR/bin/python" ] || \
  ! "$VENV_DIR/bin/python" -c \
    'import yaml; raise SystemExit(yaml.__version__ != "6.0.3")' \
    >/dev/null 2>&1; then
  "$PYTHON" -m venv "$VENV_DIR"
  "$VENV_DIR/bin/python" -m pip install \
    --disable-pip-version-check \
    --only-binary=:all: \
    --require-hashes \
    -r "$REQUIREMENTS"
fi

"$VENV_DIR/bin/python" -c \
  'import yaml; raise SystemExit(yaml.__version__ != "6.0.3")'
