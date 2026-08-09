#!/usr/bin/env sh
set -eu

fail() {
  printf '%s\n' "Protected backend startup rejected: $*" >&2
  exit 1
}

case "${SPRING_PROFILES_ACTIVE:-}" in
  stage|prod) ;;
  *) fail 'SPRING_PROFILES_ACTIVE must be exactly stage or prod' ;;
esac

: "${EXPECTED_SOURCE_GIT_SHA:?EXPECTED_SOURCE_GIT_SHA is required}"
: "${EXPECTED_SOURCE_GIT_TREE:?EXPECTED_SOURCE_GIT_TREE is required}"
readonly IMAGE_PROVENANCE_DIRECTORY=/usr/local/share/walking-rpg
IMAGE_SOURCE_GIT_SHA=$(cat "$IMAGE_PROVENANCE_DIRECTORY/source-git-sha") \
  || fail 'container source Git SHA metadata is unreadable'
IMAGE_SOURCE_GIT_TREE=$(cat "$IMAGE_PROVENANCE_DIRECTORY/source-git-tree") \
  || fail 'container source Git tree metadata is unreadable'

case "$EXPECTED_SOURCE_GIT_SHA" in
  *[!0-9a-f]*|'') fail 'EXPECTED_SOURCE_GIT_SHA must be lowercase hexadecimal' ;;
esac
case "$EXPECTED_SOURCE_GIT_TREE" in
  *[!0-9a-f]*|'') fail 'EXPECTED_SOURCE_GIT_TREE must be lowercase hexadecimal' ;;
esac
[ "${#EXPECTED_SOURCE_GIT_SHA}" -eq 40 ] \
  || fail 'EXPECTED_SOURCE_GIT_SHA must contain exactly 40 characters'
[ "${#EXPECTED_SOURCE_GIT_TREE}" -eq 40 ] \
  || fail 'EXPECTED_SOURCE_GIT_TREE must contain exactly 40 characters'
[ "$EXPECTED_SOURCE_GIT_SHA" = "$IMAGE_SOURCE_GIT_SHA" ] \
  || fail 'container source Git SHA does not match the approved deployment SHA'
[ "$EXPECTED_SOURCE_GIT_TREE" = "$IMAGE_SOURCE_GIT_TREE" ] \
  || fail 'container source Git tree does not match the approved deployment tree'

: "${POSTGRES_HOST:?POSTGRES_HOST is required}"
: "${POSTGRES_PORT:?POSTGRES_PORT is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${POSTGRES_CA_CERT:?POSTGRES_CA_CERT is required}"

case "$POSTGRES_CA_CERT" in
  *'-----BEGIN CERTIFICATE-----'*'-----END CERTIFICATE-----'*) ;;
  *) fail 'POSTGRES_CA_CERT must contain a PEM certificate' ;;
esac

certificate_directory="${HOME:?HOME is required}/.postgresql"
certificate_path="$certificate_directory/root.crt"
temporary_certificate="$certificate_directory/root.crt.tmp.$$"

cleanup() {
  rm -f -- "$temporary_certificate"
}
trap cleanup EXIT HUP INT TERM

umask 077
install -d -m 0700 "$certificate_directory"
printf '%s\n' "$POSTGRES_CA_CERT" > "$temporary_certificate"
chmod 0600 "$temporary_certificate"
mv -f -- "$temporary_certificate" "$certificate_path"
trap - EXIT HUP INT TERM

unset POSTGRES_CA_CERT

exec java -jar /app/walking-rpg-backend.jar
