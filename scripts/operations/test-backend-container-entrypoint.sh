#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ENTRYPOINT_SOURCE="$ROOT_DIR/backend/docker-entrypoint.sh"
TEST_TMPDIR=${TMPDIR:-$ROOT_DIR}
TEST_ROOT=$(mktemp -d "$TEST_TMPDIR/walking-rpg-entrypoint.XXXXXXXXXX")
ENTRYPOINT="$TEST_ROOT/walking-rpg-entrypoint"
PROVENANCE_DIRECTORY="$TEST_ROOT/provenance"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home"

cat > "$TEST_ROOT/bin/java" <<'EOF'
#!/usr/bin/env sh
set -eu
[ -z "${POSTGRES_CA_CERT+x}" ] \
  || { echo 'POSTGRES_CA_CERT leaked to the JVM process' >&2; exit 91; }
printf '%s\n' "$*" > "$ENTRYPOINT_TEST_ARGUMENTS"
EOF
chmod 0555 "$TEST_ROOT/bin/java"

VALID_CA='-----BEGIN CERTIFICATE-----
YWxwaGEtY2E=
-----END CERTIFICATE-----'
SOURCE_GIT_SHA=1111111111111111111111111111111111111111
SOURCE_GIT_TREE=2222222222222222222222222222222222222222

mkdir -p "$PROVENANCE_DIRECTORY"
printf '%s\n' "$SOURCE_GIT_SHA" > "$PROVENANCE_DIRECTORY/source-git-sha"
printf '%s\n' "$SOURCE_GIT_TREE" > "$PROVENANCE_DIRECTORY/source-git-tree"
sed \
  "s#^readonly IMAGE_PROVENANCE_DIRECTORY=.*#readonly IMAGE_PROVENANCE_DIRECTORY=$PROVENANCE_DIRECTORY#" \
  "$ENTRYPOINT_SOURCE" > "$ENTRYPOINT"
chmod 0555 "$ENTRYPOINT"

HOME="$TEST_ROOT/home" \
PATH="$TEST_ROOT/bin:$PATH" \
ENTRYPOINT_TEST_ARGUMENTS="$TEST_ROOT/java-arguments" \
SPRING_PROFILES_ACTIVE=stage \
EXPECTED_SOURCE_GIT_SHA="$SOURCE_GIT_SHA" \
EXPECTED_SOURCE_GIT_TREE="$SOURCE_GIT_TREE" \
IMAGE_PROVENANCE_DIRECTORY=/runtime-override-must-be-ignored \
POSTGRES_HOST=alpha-db.example.com \
POSTGRES_PORT=25060 \
POSTGRES_DB=walking_rpg \
POSTGRES_USER=walking_rpg_app \
POSTGRES_PASSWORD=not-a-real-password \
POSTGRES_CA_CERT="$VALID_CA" \
  "$ENTRYPOINT"

[ "$(cat "$TEST_ROOT/java-arguments")" = \
  '-jar /app/walking-rpg-backend.jar' ] \
  || { echo 'entrypoint passed unexpected JVM arguments' >&2; exit 1; }
[ "$(stat -c '%a' "$TEST_ROOT/home/.postgresql")" = '700' ] \
  || { echo 'pgJDBC certificate directory mode is not 0700' >&2; exit 1; }
[ "$(stat -c '%a' "$TEST_ROOT/home/.postgresql/root.crt")" = '600' ] \
  || { echo 'pgJDBC root certificate mode is not 0600' >&2; exit 1; }
[ "$(cat "$TEST_ROOT/home/.postgresql/root.crt")" = "$VALID_CA" ] \
  || { echo 'pgJDBC root certificate content changed' >&2; exit 1; }

if HOME="$TEST_ROOT/rejected-home" \
  PATH="$TEST_ROOT/bin:$PATH" \
  ENTRYPOINT_TEST_ARGUMENTS="$TEST_ROOT/rejected-arguments" \
  SPRING_PROFILES_ACTIVE=local \
  EXPECTED_SOURCE_GIT_SHA="$SOURCE_GIT_SHA" \
  EXPECTED_SOURCE_GIT_TREE="$SOURCE_GIT_TREE" \
  POSTGRES_HOST=alpha-db.example.com \
  POSTGRES_PORT=25060 \
  POSTGRES_DB=walking_rpg \
  POSTGRES_USER=walking_rpg_app \
  POSTGRES_PASSWORD=not-a-real-password \
  POSTGRES_CA_CERT="$VALID_CA" \
    "$ENTRYPOINT" >/dev/null 2>&1; then
  echo 'entrypoint accepted an unprotected profile' >&2
  exit 1
fi

if HOME="$TEST_ROOT/rejected-ca-home" \
  PATH="$TEST_ROOT/bin:$PATH" \
  ENTRYPOINT_TEST_ARGUMENTS="$TEST_ROOT/rejected-ca-arguments" \
  SPRING_PROFILES_ACTIVE=stage \
  EXPECTED_SOURCE_GIT_SHA="$SOURCE_GIT_SHA" \
  EXPECTED_SOURCE_GIT_TREE="$SOURCE_GIT_TREE" \
  POSTGRES_HOST=alpha-db.example.com \
  POSTGRES_PORT=25060 \
  POSTGRES_DB=walking_rpg \
  POSTGRES_USER=walking_rpg_app \
  POSTGRES_PASSWORD=not-a-real-password \
  POSTGRES_CA_CERT='not-a-certificate' \
    "$ENTRYPOINT" >/dev/null 2>&1; then
  echo 'entrypoint accepted an invalid CA certificate' >&2
  exit 1
fi

if HOME="$TEST_ROOT/rejected-source-home" \
  PATH="$TEST_ROOT/bin:$PATH" \
  ENTRYPOINT_TEST_ARGUMENTS="$TEST_ROOT/rejected-source-arguments" \
  SPRING_PROFILES_ACTIVE=stage \
  EXPECTED_SOURCE_GIT_SHA=3333333333333333333333333333333333333333 \
  EXPECTED_SOURCE_GIT_TREE="$SOURCE_GIT_TREE" \
  IMAGE_PROVENANCE_DIRECTORY="$TEST_ROOT/forged-provenance" \
  IMAGE_SOURCE_GIT_SHA=3333333333333333333333333333333333333333 \
  POSTGRES_HOST=alpha-db.example.com \
  POSTGRES_PORT=25060 \
  POSTGRES_DB=walking_rpg \
  POSTGRES_USER=walking_rpg_app \
  POSTGRES_PASSWORD=not-a-real-password \
  POSTGRES_CA_CERT="$VALID_CA" \
    "$ENTRYPOINT" >/dev/null 2>&1; then
  echo 'entrypoint accepted an image built from another source commit' >&2
  exit 1
fi

printf '%s\n' 'Protected backend container entrypoint checks passed.'
