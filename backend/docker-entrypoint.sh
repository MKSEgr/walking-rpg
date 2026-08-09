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
