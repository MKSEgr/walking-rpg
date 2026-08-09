# ADR 0018: Mobile OIDC session and authenticated transport

- Status: Accepted
- Date: 2026-07-28

## Context

Backend production authentication now accepts only validated JWT/OIDC identities. The
mobile client previously sent `X-User-Id` and `X-Device-Id`, which are valid only for the
explicit local/test `DEV_HEADER` backend profile.

The client also has two owner-scoped persistence mechanisms:

- server-confirmed read-only snapshots;
- restart-safe pending command outbox.

Authentication therefore must define not only browser login, but also token refresh,
account switching, logout, and cleanup of owner-scoped state.

## Decision

Production mobile builds use OAuth 2.0 Authorization Code with PKCE through AppAuth.

Configuration is supplied through compile-time Dart defines:

- `MOBILE_AUTH_MODE=oidc`;
- `OIDC_ISSUER`;
- `OIDC_CLIENT_ID`;
- `OIDC_AUDIENCE`;
- `OIDC_REDIRECT_URI`;
- `OIDC_POST_LOGOUT_REDIRECT_URI`;
- `OIDC_SCOPES` (defaults to `openid profile offline_access walking-rpg.user`);
- `AUTH_REFRESH_SKEW_SECONDS`.

The default redirect scheme is `com.walkingrpg.app`.

Access, refresh, and ID tokens are stored only through platform secure storage. The
ordinary file cache and command outbox never contain tokens.

Every backend request is sent through one authenticated transport that:

1. removes caller-supplied authorization and identity headers;
2. refuses to attach a bearer token outside the configured API origin;
3. refreshes once after the first `401`;
4. retries the exact request once with the refreshed token;
5. requires a new login after a second `401`.

The selected `ru` or `en` locale is sent to Universal Login as `ui_locales`.
The app also creates one random 128-bit lowercase hexadecimal installation ID in
platform secure storage. It survives logout/account switch and rotates only when
secure storage is missing or malformed. It is sent to the provider as
`ext-installation-id` during authorization and refresh. A platform Keychain may
retain it across reinstall; backend correctness does not depend on rotation. The
provider validates it and copies it into the signed access-token device claim.
Mobile never sends a production device identifier header to the backend.

The local storage owner is a SHA-256 partition derived from the exact OIDC issuer
identifier and access-token subject; the raw provider subject is not used in cache
filenames. When an ID token is present, its issuer and subject must match the access token.

## Session lifecycle

- Cold start restores a secure session without forcing network access.
- An access token is refreshed shortly before expiry or after the first `401`.
- `invalid_grant` and a repeated `401` require interactive login.
- A transient refresh failure is surfaced as a retryable network failure so read-only
  offline snapshots remain usable.
- Reauthentication as the same issuer/subject preserves pending commands and snapshots.
- A secure owner tombstone survives process restart after token rejection. It protects
  account-switch cleanup even when no active token remains.
- Signing in as another issuer/subject clears the previous owner's snapshots and
  commands before the new session becomes active.
- Explicit logout persists a session-invalidated tombstone before waiting for the
  command runtime, then clears snapshots and commands for the current owner and performs
  best-effort OIDC end-session.
- Refresh-token rotation updates only the token envelope and can never reactivate an
  owner marker invalidated by logout or forced reauthentication.

In-flight reads cannot repopulate an owner cache after logout because logout advances
the same mutation generation fence used by gameplay mutations.

## Development mode

`MOBILE_AUTH_MODE=development` enables the existing identity headers only in non-release
builds. Production builds fail closed if development mode is selected.

## Consequences

- The identity provider must register the native redirect and post-logout URIs and
  expose the exact API audience selected in ADR 0035.
- The provider must issue an ID token containing stable `iss` and `sub` claims, a
  rotating refresh token when `offline_access` is granted, and the
  `walking-rpg.user` scope for game API access.
- The Auth0 Post Login Action owns the namespaced device and fresh-auth claims;
  tenant deployment and physical-device validation remain external gates.
- Android and iOS host projects must retain their redirect scheme configuration.
- iOS disables the shared URL disk cache before AppAuth starts so token responses are not
  persisted in `cache.db`.
- Physical-device validation is still required for provider-specific login, logout,
  browser return, keychain/keystore behavior, and token rotation.
