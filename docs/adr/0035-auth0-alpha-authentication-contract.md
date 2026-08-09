# 0035 — Auth0 contract for internal alpha

- Status: Accepted with external blockers; provider set extended by
  [ADR 0037](0037-telegram-login-through-auth0.md)
- Decision date: 2026-08-09
- Product / configuration owner: [@MKSEgr](https://github.com/MKSEgr)
- Related task: [issue #150](https://github.com/MKSEgr/walking-rpg/issues/150)
- Provider: Auth0 B2C, EU region

## Context

The mobile PKCE session, secure token storage, refresh/logout, owner cleanup and
backend JWT validation already exist. Internal alpha still needs one exact
provider contract. In particular, the native client previously omitted the API
audience and selected locale, and it had no installation identifier that Auth0
could sign for activity idempotency. The backend also expected the reserved
auth_time claim in an access token even though the provider's standard value
belongs to the ID-token contract.

This ADR decides the public contract and code-complete wiring. It does not claim
that an Auth0 tenant, social credentials, SMTP provider or physical-device flow
has been validated.

## Decision

Auth0 Universal Login is the only identity boundary for alpha. Step Beyond does
not collect or store passwords. Enabled connections are:

1. email one-time code — mandatory fallback for every tester;
2. Sign in with Apple — enabled for the assigned iOS validation group;
3. Google — enabled for the assigned Android validation group and optionally
   alongside Apple on iOS.

At this decision date, SMS, local passwords, guest accounts, VK, Yandex and
Telegram were out of alpha scope. ADR 0037 later adds Telegram through Auth0;
MAX remains deferred. A participant uses one assigned identity during alpha.
Identities are not automatically linked by matching email or other profile
claims; explicit account linking is a future decision because attribute
equality alone is not proof of account ownership.

## Environment matrix

| Environment | Auth mode | Auth0 boundary | Status / owner |
|---|---|---|---|
| local / test | dev-header or synthetic OIDC | no real tenant or secrets | code complete |
| internal alpha stage (exact deployment name/hosting undecided) | dedicated Auth0 EU development tenant, one Native Application and one custom API | exact tenant/client values BLOCKED, @MKSEgr, 2026-08-09 |
| public production | separate Auth0 EU production tenant/application/API | disabled and BLOCKED until a public-release decision, @MKSEgr |

Stage and production never share client IDs, refresh tokens, connection
credentials or tenant secrets. Production remains fail-closed while its exact
configuration is absent.

## OIDC and token contract

| Field | Alpha contract |
|---|---|
| Flow | Authorization Code + PKCE through the system browser |
| Stage issuer | `https://<assigned-stage-tenant>.eu.auth0.com/`; exact tenant name BLOCKED |
| Stage native client ID | exact public identifier BLOCKED until the application exists |
| Production issuer/client | separate exact values BLOCKED; production remains disabled |
| API audience | https://api.stepbeyond.game |
| Redirect | com.walkingrpg.app:/oauthredirect |
| Post logout | com.walkingrpg.app:/logout |
| Scopes | openid profile offline_access walking-rpg.user |
| Access token | JWT, 15 minute lifetime |
| Refresh token | rotating; 30 day inactivity, 90 day absolute lifetime, reuse detection enabled |
| UI locale | selected ru or en sent as ui_locales |
| User identity | exact signed iss + sub |
| Device claim | https://api.stepbeyond.game/device_id |
| Fresh-auth claim | https://api.stepbeyond.game/auth_time |

The mobile client creates a random 128-bit lowercase hexadecimal installation
ID in platform secure storage under step_beyond_installation_id_v1. It is
device-scoped, outside tokens and owner-local data, survives logout and account
switch, and rotates when secure storage is missing or malformed. A platform may
retain Keychain data across reinstall, so backend correctness does not assume
that reinstall rotates it. It is sent to Auth0 as ext-installation-id during
interactive authorization and refresh exchange. It is never sent directly to
the game API.

The versioned Post Login Action in auth0/actions validates that input and places
it in the signed device claim. Backend stage/prod configuration must set:

    OIDC_DEVICE_CLAIM=https://api.stepbeyond.game/device_id
    OIDC_AUTHENTICATION_TIME_CLAIM=https://api.stepbeyond.game/auth_time

For account deletion the app always starts an interactive request with
prompt=login and max_age=0. The Action derives the latest authentication
timestamp from Auth0's recorded authentication methods and emits the signed
fresh-auth claim. Refresh exchange deliberately does not create freshness.
Missing, stale, future or malformed values fail closed at the backend.

## Lifecycle contract

- Cold start may restore the secure session and refresh shortly before expiry.
- invalid_grant, revoked refresh token or a second backend 401 requires
  interactive sign-in.
- Logout publishes the local owner tombstone, clears owner-scoped cache/outbox,
  deletes tokens and makes a best-effort OIDC end-session request.
- Reinstall follows the normal secure-session recovery/login path. It creates a
  new installation ID when platform storage was removed; retained Keychain data
  may preserve the previous value and must be covered by physical validation.
- Account switch clears the previous owner's local state before the replacement
  session is exposed.
- Game-data deletion remains server-authoritative and requires recent signed
  authentication. Deletion of the Auth0 identity is a separate provider action;
  it must not be reported complete until its provider receipt exists.

## Secret delivery and rotation

Claim names, audience and redirect URIs are committed. Tenant domain and native
client ID are public deployment metadata rather than secrets, but their exact
stage values do not exist yet and will be delivered through protected CI
variables. Social, SMTP and Management API credentials are secrets and belong
only in provider/protected secret stores; they must not appear in committed
files, CI logs, issues, PRs or evidence.

Rotation procedure:

1. create the replacement credential in the provider;
2. update the protected stage secret and deploy one new candidate;
3. validate issuer, audience, JWKS, login, refresh and revoke with redacted
   evidence;
4. revoke the old credential;
5. on failure, disable the stage profile and revoke the test credential rather
   than falling back to development headers.

## External blockers

| Blocked action | Owner | Date recorded | Required evidence |
|---|---|---|---|
| Create the Auth0 EU development tenant, Native Application and custom API | @MKSEgr | 2026-08-09 | redacted tenant/application/API identifiers |
| Register callback/logout URLs and deploy the Post Login Action | @MKSEgr | 2026-08-09 | Action version and redacted configuration export |
| Configure email OTP with an external SMTP provider | @MKSEgr | 2026-08-09 | delivery test without address/code disclosure |
| Configure Apple and Google connections | @MKSEgr | 2026-08-09 | provider status and assigned physical test group |
| Provide protected stage secrets and validate real JWT claims | @MKSEgr | 2026-08-09 | redacted claim checklist, no token |
| Implement or operate Auth0-identity deletion and retain a provider receipt | @MKSEgr | 2026-08-09 | deletion/replay evidence without PII |
| Run login, refresh, revoke, logout, reinstall and account-switch on physical iOS/Android | @MKSEgr | 2026-08-09 | issue #153 evidence tied to exact build/SHA |

Until those actions are complete, the contract is CODE_COMPLETE but not
VALIDATED, and protected profiles remain disabled.

## Verification and rollback

Automated checks cover audience/locale/installation parameters, persistence of
the installation ID, the Auth0 Action's interactive/refresh behavior,
namespaced device extraction, configurable fresh-auth extraction and existing
session lifecycle regressions.

Rollback is to remove or disable the Action version, revoke alpha credentials
and disable the protected stage profile. It is forbidden to restore X-User-Id
or X-Device-Id as a production trust boundary.

## Provider references

- [Authorization Code with PKCE](https://auth0.com/docs/get-started/authentication-and-authorization-flow/authorization-code-flow-with-pkce)
- [Universal Login internationalization](https://auth0.com/docs/customize/internationalization-and-localization/universal-login-internationalization)
- [Custom access-token claims](https://auth0.com/docs/secure/tokens/json-web-tokens/create-custom-claims)
- [Post Login Action event](https://auth0.com/docs/actions/reference/post-login/post-login-event-object)
