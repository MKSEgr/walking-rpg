# Telegram login validation evidence

This template records redacted external evidence for ADR 0037. Never paste a
Telegram/Auth0 token, authorization code, Client ID/Secret, Management API
token, raw `sub`, phone number, username, chat identifier, email address or
device identifier into this file, GitHub or CI logs.

## Provenance

| Field | Value |
|---|---|
| Date / UTC window | `BLOCKED` |
| Tester / operator role | `BLOCKED` |
| Source SHA / tree | `BLOCKED` |
| App version / build | `BLOCKED` |
| Auth0 stage tenant alias | `BLOCKED` |
| Auth0 connection ID suffix or redacted reference | `BLOCKED` |
| Telegram bot public name | `BLOCKED` |
| Post Login Action version | `BLOCKED` |

## Configuration review

| Check | Status | Redacted evidence reference |
|---|---|---|
| Callback is exact Auth0 `/login/callback` HTTPS URL | `BLOCKED` | `BLOCKED` |
| Connection is `telegram`, OIDC, back channel and PKCE S256 | `BLOCKED` | `BLOCKED` |
| Scopes are exactly `openid profile` | `BLOCKED` | `BLOCKED` |
| `phone` and `telegram:bot_access` are absent | `BLOCKED` | `BLOCKED` |
| Connection is not domain-level | `BLOCKED` | `BLOCKED` |
| Only the intended stage Native Application is enabled | `BLOCKED` | `BLOCKED` |
| Step Beyond Post Login Action is active | `BLOCKED` | `BLOCKED` |

## Physical-device matrix

Record only device model family and OS version; omit serials and advertising or
installation identifiers.

| Platform / locale | Login | Cancel | Refresh / revoke | Logout / reinstall | Account switch | Sensitive reauth | Result / issue |
|---|---|---|---|---|---|---|---|
| iOS / ru | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` |
| iOS / en | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` |
| Android / ru | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` |
| Android / en | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` | `BLOCKED` |

## Token and privacy outcomes

Record `PASS`/`FAIL` only; do not copy token or claim values.

| Check | Status | Notes / issue |
|---|---|---|
| Auth0 issuer, audience, expiry and string subject accepted | `BLOCKED` | `BLOCKED` |
| Wrong issuer/audience or malformed subject rejected | `BLOCKED` | `BLOCKED` |
| Signed namespaced device claim present | `BLOCKED` | `BLOCKED` |
| Interactive signed fresh-auth claim present | `BLOCKED` | `BLOCKED` |
| Refresh cannot manufacture fresh authentication | `BLOCKED` | `BLOCKED` |
| No phone-number consent shown or stored for this connection | `BLOCKED` | `BLOCKED` |
| No bot direct-message permission requested | `BLOCKED` | `BLOCKED` |
| User without Telegram username receives a safe display-name fallback | `BLOCKED` | `BLOCKED` |
| Different provider/account cannot satisfy same-subject reauthentication | `BLOCKED` | `BLOCKED` |
| Previous owner's local cache/outbox is not exposed after switch | `BLOCKED` | `BLOCKED` |

## Decision

- Overall result: `BLOCKED`
- Open defects / rerun links: `BLOCKED`
- Configuration owner approval: `BLOCKED`
- Rollback target and disable procedure checked: `BLOCKED`

Do not mark Telegram `VALIDATED` while any required row is `BLOCKED` or `FAIL`.
