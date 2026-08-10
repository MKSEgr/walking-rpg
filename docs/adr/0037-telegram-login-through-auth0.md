# 0037 — Telegram login through Auth0

- Status: Accepted with external blockers
- Decision date: 2026-08-09
- Product / configuration owner: [@MKSEgr](https://github.com/MKSEgr)
- Related task: [issue #175](https://github.com/MKSEgr/walking-rpg/issues/175)
- Extends: [ADR 0035](0035-auth0-alpha-authentication-contract.md)
- Provider: Telegram OIDC behind Auth0 Universal Login

## Context

ADR 0035 intentionally excluded Telegram from the initial alpha provider set.
The product owner has now chosen to add Telegram and to defer MAX. Telegram
publishes an OpenID Connect discovery document and supports Authorization Code
with PKCE, while Auth0 can broker an OIDC Enterprise connection and map claims
from the upstream ID token without a UserInfo endpoint.

The existing mobile application already authenticates only against Auth0 using
the system browser. The backend trusts only Auth0 access tokens with the exact
Step Beyond issuer, audience and namespaced claims. Adding provider-specific
token validation to either component would create a second identity boundary
and is unnecessary.

## Decision

Telegram becomes an optional internal-alpha sign-in method. MAX remains out of
scope. Auth0 stays the only issuer accepted by the native client and game API:

    native app -> Auth0 Universal Login -> Telegram OIDC
               <- Auth0 code/tokens     <- Telegram identity

The Auth0 connection contract is committed as
`auth0/telegram/connection.template.json`:

| Field | Decision |
|---|---|
| Connection name | `telegram` |
| Strategy | Auth0 Enterprise `oidc` |
| Discovery | `https://oauth.telegram.org/.well-known/openid-configuration` |
| Channel / response | back channel / authorization code |
| Upstream PKCE | `S256` |
| Upstream scopes | exactly `openid profile` |
| Profile source | validated Telegram ID-token claims only |
| Login UI | visible `Telegram` Universal Login button |
| Availability | only the environment's Step Beyond Native Application |
| Domain promotion | disabled |

`S256` above is the protocol method advertised by OIDC discovery. Auth0's
connection JSON serializes that choice as the documented lowercase enum
`connection_settings.pkce: "s256"`; changing this configuration property to
uppercase is not part of the accepted contract.

The connection must not request `phone` or `telegram:bot_access`. Authentication
does not need a phone number and does not grant the bot permission to send
messages. Client ID, Client Secret, Auth0 Management API tokens and rendered
provider configuration remain outside the repository.

The mobile app continues sending Auth0 `audience`, `ui_locales` and the bounded
installation ID. The existing Post Login Action continues issuing signed Step
Beyond `device_id` and `auth_time` claims. The backend requires no
provider-specific change and never accepts a Telegram ID token directly.

The app entry text names Telegram in Russian and English, but provider choice
remains hosted by Universal Login. A separate native Telegram SDK and a direct
Telegram button inside the app are not added for alpha.

## Identity and account lifecycle

An Auth0 identity created through `telegram` is a distinct subject from an
email, Apple or Google identity, even when a person believes the accounts are
the same. The alpha rule remains one assigned sign-in method per participant.
No automatic merge by phone, username, display name or any other profile claim
is allowed.

Sensitive reauthentication still requires `prompt=login`, `max_age=0` and the
same Auth0 issuer/subject. Choosing another Telegram account or another
connection fails closed in the mobile session controller. Explicit account
linking and unlinking remain a separate pre-beta decision and implementation.

Deleting Step Beyond game data or an Auth0 user does not delete the person's
Telegram account. Evidence and user-facing language must keep those operations
distinct.

## Consequences

- No mobile authentication protocol or backend JWT boundary is forked.
- Telegram can be disabled per Auth0 application without publishing a new app
  build.
- Auth0 becomes responsible for validating the upstream Telegram ID token;
  Step Beyond validates only the resulting Auth0 access token.
- A bot, BotFather callback, provider credentials, Auth0 connection and
  physical-device evidence are still required before the feature is marked
  `VALIDATED`.
- Provider availability and Auth0 plan limits must be checked in the actual
  tenant; repository code does not claim commercial entitlement.

## External blockers

| Blocked action | Owner | Date recorded | Required evidence |
|---|---|---|---|
| Create/select the Step Beyond Telegram bot and register the exact Auth0 callback | @MKSEgr | 2026-08-09 | redacted bot/callback status, no credential |
| Store Telegram Client ID/Secret in protected Auth0 configuration | @MKSEgr | 2026-08-09 | redacted connection inventory |
| Enable `telegram` only for the stage Native Application and deploy the existing Action | @MKSEgr | 2026-08-09 | redacted application/flow status |
| Validate RU/EN login lifecycle on physical iOS and Android | @MKSEgr | 2026-08-09 | completed Telegram evidence template tied to exact build/SHA |

Until those actions pass, the repository portion is `CODE_COMPLETE` but the
Telegram sign-in method is `EXTERNAL_VALIDATION_REQUIRED`.

## Rollback

Disable the `telegram` connection for the stage Native Application. On suspected
credential exposure, rotate or revoke the Telegram credential and remove the
old Auth0 secret. Do not add direct Telegram token acceptance as a fallback.

## References

- [Telegram Login / OpenID Connect](https://core.telegram.org/bots/telegram-login)
- [Auth0 OIDC Enterprise connections](https://auth0.com/docs/authenticate/identity-providers/enterprise-identity-providers/oidc)
- [Auth0 OIDC PKCE and claim mapping](https://auth0.com/docs/authenticate/identity-providers/enterprise-identity-providers/configure-pkce-claim-mapping-for-oidc)
