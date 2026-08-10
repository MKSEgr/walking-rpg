#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKFLOW="$ROOT_DIR/.github/workflows/publish-backend-release-candidate.yml"
DOCKERFILE="$ROOT_DIR/backend/Dockerfile"

fail() {
  printf 'Backend publisher contract test failed: %s\n' "$1" >&2
  exit 1
}

baseline_count=$(grep -Ec \
  '^      PROVENANCE_GUARD_BASELINE_SHA: [0-9a-f]{40}$' \
  "$WORKFLOW" || true)
[ "$baseline_count" -eq 1 ] \
  || fail 'workflow must declare exactly one lowercase provenance baseline'

baseline_sha=$(sed -n \
  's/^      PROVENANCE_GUARD_BASELINE_SHA: \([0-9a-f]\{40\}\)$/\1/p' \
  "$WORKFLOW")

jdk_pin_count=$(grep -Ec \
  '^      APPROVED_JDK_BASE_IMAGE: eclipse-temurin:21-jdk-jammy@sha256:[0-9a-f]{64}$' \
  "$WORKFLOW" || true)
[ "$jdk_pin_count" -eq 1 ] \
  || fail 'workflow must declare exactly one reviewed JDK base image pin'
jre_pin_count=$(grep -Ec \
  '^      APPROVED_JRE_BASE_IMAGE: eclipse-temurin:21-jre-jammy@sha256:[0-9a-f]{64}$' \
  "$WORKFLOW" || true)
[ "$jre_pin_count" -eq 1 ] \
  || fail 'workflow must declare exactly one reviewed JRE base image pin'

jdk_base_image=$(sed -n \
  's/^      APPROVED_JDK_BASE_IMAGE: \(eclipse-temurin:21-jdk-jammy@sha256:[0-9a-f]\{64\}\)$/\1/p' \
  "$WORKFLOW")
jre_base_image=$(sed -n \
  's/^      APPROVED_JRE_BASE_IMAGE: \(eclipse-temurin:21-jre-jammy@sha256:[0-9a-f]\{64\}\)$/\1/p' \
  "$WORKFLOW")
[ "$(sed -n '1p' "$DOCKERFILE")" = "FROM $jdk_base_image AS build" ] \
  || fail 'publisher JDK pin must match the protected Dockerfile'
grep -Fxq "FROM $jre_base_image" "$DOCKERFILE" \
  || fail 'publisher JRE pin must match the protected Dockerfile'

git -C "$ROOT_DIR" cat-file -e "$baseline_sha^{commit}" \
  || fail 'pinned provenance baseline is not a repository commit'
git -C "$ROOT_DIR" merge-base --is-ancestor "$baseline_sha" HEAD \
  || fail 'current source predates the pinned provenance baseline'

baseline_parent=$(git -C "$ROOT_DIR" rev-parse "$baseline_sha^1")
if git -C "$ROOT_DIR" merge-base --is-ancestor \
  "$baseline_sha" "$baseline_parent"; then
  fail 'baseline ancestry check accepted a pre-guard commit'
fi

git -C "$ROOT_DIR" show "$baseline_sha:backend/docker-entrypoint.sh" \
  | grep -Fq \
    'container source Git SHA does not match the approved deployment SHA' \
  || fail 'baseline commit does not contain the source SHA startup guard'
git -C "$ROOT_DIR" show "$baseline_sha:backend/docker-entrypoint.sh" \
  | grep -Fq \
    'container source Git tree does not match the approved deployment tree' \
  || fail 'baseline commit does not contain the source tree startup guard'
if git -C "$ROOT_DIR" show "$baseline_parent:backend/docker-entrypoint.sh" \
  | grep -Fq \
    'container source Git SHA does not match the approved deployment SHA'; then
  fail 'pinned baseline is not the first master commit with the provenance guard'
fi

grep -Fq 'test "$GITHUB_REF" = '\''refs/heads/master'\''' "$WORKFLOW" \
  || fail 'publisher must reject dispatches outside master'
grep -Fq 'test "$GITHUB_WORKFLOW_SHA" = "$GITHUB_SHA"' "$WORKFLOW" \
  || fail 'publisher must bind its workflow definition to the dispatched commit'
grep -Fq 'test "$GITHUB_SHA" = "$(git rev-parse origin/master)"' "$WORKFLOW" \
  || fail 'publisher must reject a master ref that moved after dispatch'
grep -Fq '"$PROVENANCE_GUARD_BASELINE_SHA" "$SOURCE_GIT_SHA"' "$WORKFLOW" \
  || fail 'publisher must reject source commits before the provenance baseline'
grep -Fq 'base_instruction_count="$(grep -Eic' "$WORKFLOW" \
  || fail 'publisher must enumerate every historical source base instruction'
grep -Fq 'test "$base_instruction_count" -eq 2' "$WORKFLOW" \
  || fail 'publisher must reject additional historical source stages'
grep -Fq 'expected_base_instructions="$(printf ' "$WORKFLOW" \
  || fail 'publisher must require its current reviewed JDK base pin'
grep -Fq "'FROM %s AS build\\nFROM %s\\n'" "$WORKFLOW" \
  || fail 'publisher must compare both historical base instructions in order'
grep -Fq '"$APPROVED_JDK_BASE_IMAGE" "$APPROVED_JRE_BASE_IMAGE")"' \
  "$WORKFLOW" \
  || fail 'publisher must require its current reviewed JRE base pin'
base_guard_line=$(grep -n -F 'base_instruction_count=' "$WORKFLOW" \
  | cut -d: -f1)
registry_login_line=$(grep -n -F 'name: Log in to GitHub Container Registry' \
  "$WORKFLOW" | cut -d: -f1)
[ "$base_guard_line" -lt "$registry_login_line" ] \
  || fail 'publisher must verify historical base pins before registry login'
grep -Fq 'docker pull --platform linux/amd64 "$image_reference"' "$WORKFLOW" \
  || fail 'publisher must inspect the image returned by the registry'
grep -Fq \
  '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
  "$WORKFLOW" \
  || fail 'publisher must verify the image source revision label'
grep -Fq \
  '{{index .Config.Labels "game.stepbeyond.source-tree"}}' \
  "$WORKFLOW" \
  || fail 'publisher must verify the image source tree label'
grep -Fq 'cmp --' "$WORKFLOW" \
  || fail 'publisher must compare the embedded entrypoint with approved source'
grep -Fq 'IMAGE_DIGEST: ${{ steps.verify_image.outputs.image_digest }}' \
  "$WORKFLOW" \
  || fail 'receipt must depend on successful image contract verification'
grep -Fq '"provenanceGuardBaselineSha": os.environ[' "$WORKFLOW" \
  || fail 'receipt must record the pinned provenance baseline'

printf '%s\n' 'Protected backend publisher contract checks passed.'
