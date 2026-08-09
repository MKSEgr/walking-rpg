# Mobile authentication security review

Date: 2026-07-28

This review records the invariants required before the mobile OIDC session slice may be merged.

## Identity

- The access-token `iss` and `sub` claims define the authenticated local identity.
- OIDC issuer comparison is exact; trailing slashes and whitespace are not normalized into another issuer.
- An ID token, when present, must describe the same issuer and subject as the access token.
- Claim identifiers remain whitespace-sensitive so distinct backend subjects cannot collapse into one local owner partition.
- Upstream providers terminate at Auth0 Universal Login. Telegram tokens are
  never accepted by the mobile session or game API; the validated Auth0
  issuer/subject remains the only production owner boundary.
- Telegram requests only `openid profile`. Phone-number and bot direct-message
  permissions are excluded from the reviewed connection contract.

## Session invalidation

- Logout and forced reauthentication persist an invalidated-session tombstone before waiting for command-runtime shutdown.
- Refresh-token rotation is bound to a unique persisted session generation and never reactivates an invalidated owner marker.
- Session-store mutations are serialized; an obsolete refresh cannot overwrite or delete a later sign-in, including same-account ABA.
- Explicit logout persists both invalidation and the pending local-cleanup obligation before waiting for runtime shutdown.
- Partial local cleanup is persisted and retried after process restart.
- Failed invalidation retries never delete an already-persisted tombstone.
- Token-envelope deletion runs even when a tombstone write fails.
- Refresh persistence failures surface as transient unavailability only while the originating session remains current.
- Restore errors carry the pending cleanup obligation into the next sign-in.
- The owner marker and token envelope carry the same random generation; any
  missing or mismatched record fails closed and requires reauthentication.

## Transport

- Bearer tokens are attached only to the configured API origin.
- Authenticated HTTP requests never follow redirects automatically.
- Caller-supplied authorization and development identity headers are removed.
- A first HTTP 401 performs one serialized refresh and one identical request replay.
- A repeated 401 invalidates the session only when the replayed token is still current; a stale replay cannot tear down a newer token.

## Local state

- Read snapshots and durable commands are partitioned by an opaque owner derived from issuer and subject.
- Account switching clears the previous owner before activating the new session.
- Explicit logout waits for admitted command work, then clears owner-scoped snapshots, commands, and secure tokens.
- The account route is dismissed once from the auth-state transition; logout completion never performs a second pop.

The automated suite covers session restore, concurrent refresh, invalid grant, logout ordering, failed tombstone writes and deletion, forced reauthentication ordering, refresh/logout races, raw refresh persistence failures, account switching, runtime shutdown, exact identity matching, redirect rejection, same-origin transport behavior, and stale repeated-401 rejection.
