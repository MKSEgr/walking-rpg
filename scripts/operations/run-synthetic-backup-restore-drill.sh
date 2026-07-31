#!/usr/bin/env bash
set -euo pipefail

umask 077

fail() {
  printf 'Synthetic backup/restore drill error: %s\n' "$1" >&2
  exit 1
}

require_exact_clean_source() {
  local actual_source_git_sha
  local untracked_files
  actual_source_git_sha=$(
    git -C "$ROOT_DIR" rev-parse --verify HEAD 2>/dev/null
  ) || fail 'the repository Git SHA could not be resolved'
  [ "$actual_source_git_sha" = "$EXPECTED_SOURCE_GIT_SHA" ] \
    || fail 'the repository Git SHA does not match EXPECTED_SOURCE_GIT_SHA'
  git -C "$ROOT_DIR" --no-pager diff \
    --no-ext-diff \
    --quiet \
    --ignore-submodules=none \
    -- \
    || fail 'the repository worktree must be clean'
  git -C "$ROOT_DIR" --no-pager diff \
    --cached \
    --no-ext-diff \
    --quiet \
    --ignore-submodules=none \
    -- \
    || fail 'the repository index must be clean'
  untracked_files=$(
    git -C "$ROOT_DIR" ls-files --others --exclude-standard
  ) || fail 'the repository untracked-file set could not be resolved'
  [ -z "$untracked_files" ] \
    || fail 'the repository must not contain untracked files'
}

if [ "$#" -ne 2 ]; then
  fail 'usage: run-synthetic-backup-restore-drill.sh OUTPUT_DIRECTORY EXPECTED_SOURCE_GIT_SHA'
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
OUTPUT_ARGUMENT=$1
EXPECTED_SOURCE_GIT_SHA=$2

[[ "$EXPECTED_SOURCE_GIT_SHA" =~ ^[0-9a-f]{40}$ ]] \
  || fail 'EXPECTED_SOURCE_GIT_SHA must be exactly 40 lowercase hex characters'

case "$OUTPUT_ARGUMENT" in
  ''|/|.|..)
    fail 'OUTPUT_DIRECTORY must be a new, dedicated directory'
    ;;
esac

if [ -e "$OUTPUT_ARGUMENT" ] || [ -L "$OUTPUT_ARGUMENT" ]; then
  fail 'OUTPUT_DIRECTORY must not already exist'
fi

OUTPUT_PARENT=$(dirname -- "$OUTPUT_ARGUMENT")
[ -d "$OUTPUT_PARENT" ] \
  || fail 'OUTPUT_DIRECTORY parent must already exist'
OUTPUT_PARENT=$(CDPATH= cd -- "$OUTPUT_PARENT" && pwd)
OUTPUT_DIRECTORY="$OUTPUT_PARENT/$(basename -- "$OUTPUT_ARGUMENT")"

case "$OUTPUT_DIRECTORY" in
  "$ROOT_DIR"|"$ROOT_DIR"/*)
    fail 'OUTPUT_DIRECTORY must be outside the repository'
    ;;
esac

command -v docker >/dev/null 2>&1 || fail 'Docker is required'
docker info >/dev/null 2>&1 || fail 'Docker daemon is not available'
command -v java >/dev/null 2>&1 || fail 'Java 21 is required'
command -v python3 >/dev/null 2>&1 || fail 'Python 3 is required'
command -v timeout >/dev/null 2>&1 || fail 'GNU timeout is required'

JAVA_MAJOR=$(
  java -version 2>&1 \
    | awk -F '[\".]' '/version/ { if ($2 == "1") print $3; else print $2; exit }'
)
[ "$JAVA_MAJOR" = '21' ] || fail "Java 21 is required; found Java $JAVA_MAJOR"

require_exact_clean_source

printf '%s\n' 'Running isolated synthetic PostgreSQL backup/restore drill...'
(
  cd "$ROOT_DIR/backend"
  timeout --kill-after=30s 15m \
    ./mvnw \
      --batch-mode \
      --no-transfer-progress \
      -Dtest=BackupRestoreDrillIntegrationTest \
      "-DwalkingRpg.backupRestoreEvidenceDirectory=$OUTPUT_DIRECTORY" \
      "-DwalkingRpg.sourceGitSha=$EXPECTED_SOURCE_GIT_SHA" \
      -DwalkingRpg.sourceTreeClean=true \
      clean \
      test
)

require_exact_clean_source

python3 \
  "$SCRIPT_DIR/verify-backup-restore-evidence.py" \
  full \
  "$OUTPUT_DIRECTORY" \
  "$EXPECTED_SOURCE_GIT_SHA"

require_exact_clean_source

printf 'Synthetic backup/restore drill passed. Evidence: %s/evidence.json\n' \
  "$OUTPUT_DIRECTORY"
