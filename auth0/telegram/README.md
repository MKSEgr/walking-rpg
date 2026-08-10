# Telegram Login through Auth0

This directory defines the secret-free, repository-verifiable part of the
Telegram login connection. It does not prove that a bot, Telegram credential,
Auth0 connection or physical-device flow exists.

The native application remains an Auth0 Authorization Code + PKCE client.
Telegram is an upstream OpenID Connect provider shown by Auth0 Universal Login;
the mobile app and game backend never exchange Telegram tokens directly.

## Fixed contract

Use `connection.template.json` for an Auth0 Enterprise OpenID Connect
connection with these exact settings:

- connection name `telegram`, display name `Telegram`;
- purpose: user authentication only;
- discovery URL
  `https://oauth.telegram.org/.well-known/openid-configuration`;
- back-channel Authorization Code flow;
- PKCE method `S256`, serialized as Auth0's lowercase connection setting
  `connection_settings.pkce: "s256"`;
- scopes exactly `openid profile`;
- explicit ID-token mapping for `name`, `preferred_username` and `picture`;
- visible Universal Login button;
- not promoted to a domain-level connection;
- enabled only for the environment's Step Beyond Native Application.

Telegram does not expose a separate UserInfo endpoint. The connection therefore
maps only claims from the validated Telegram ID token and does not configure a
`userinfo_scope`.

Do not change the Auth0 option to uppercase `S256`: Telegram/OIDC discovery
names the code-challenge method `S256`, while Auth0's Management API accepts
the configuration enum `s256` (or `auto`). The committed explicit value keeps
the intended SHA-256 method and is covered by the contract test.

Do not add `phone` or `telegram:bot_access`. Step Beyond neither needs the
user's phone number nor permission for the bot to send direct messages during
authentication.

Run the secret-free contract test with:

    node --test auth0/telegram/telegram-oidc-connection.test.js

## Owner provisioning

These actions require `@MKSEgr` access and remain external validation:

1. In BotFather, create or select the Step Beyond bot. Its public name, image
   and description must clearly identify Step Beyond.
2. Open **Login Widget** for the bot and register exactly the Auth0 callback:
   `https://<stage-tenant>.eu.auth0.com/login/callback`. Add a custom-domain
   callback only when that domain is actually configured in Auth0.
3. Obtain the Telegram Client ID and Client Secret. Store the secret only in
   Auth0; never paste either credential, a Management API token or an exported
   connection containing secrets into Git, issues, PRs, CI logs or evidence.
4. In the Auth0 EU stage tenant, create an Enterprise **Open ID Connect**
   connection from the reviewed template. Replace the two `@@...@@` values
   only inside the protected Auth0 configuration flow.
5. Enable the connection only for the stage Native Application. Do not use the
   deprecated `enabled_clients` create-connection field and do not promote it
   to domain level.
6. Confirm that New Universal Login shows a `Telegram` button for both the
   Russian and English application locales. Keep email OTP as the recovery
   method assigned to the tester cohort.
7. Keep the existing Step Beyond Post Login Action after the Telegram
   connection in the Auth0 Login flow so the game access token still receives
   the signed installation and fresh-auth claims.

The template is intentionally not a credential renderer. Apply it through the
Auth0 Dashboard or a protected Management API workflow that prevents request
bodies and secrets from reaching terminal history or CI output.

## Validation

Use `docs/evidence/telegram-login-validation-template.md` on physical iOS and
Android devices. At minimum verify:

- Russian and English entry copy and Universal Login provider choice;
- successful Telegram login, cancellation and provider error;
- Auth0 access-token issuer/audience/expiry and exact subject stability;
- signed Step Beyond `device_id` and `auth_time` claims without recording a
  token or raw subject in evidence;
- display-name fallback when no Telegram username exists;
- refresh, revoked refresh token, logout, reinstall and account switch;
- sensitive reauthentication accepts the same Auth0 subject and rejects a
  different Telegram or email identity;
- no phone-number consent and no permission for bot direct messages;
- one assigned login method per alpha tester, so an existing email/Apple/Google
  user does not accidentally create a second game profile.

## Rollback and incident response

Disable `telegram` for the stage Native Application first. If a credential may
have leaked, rotate or revoke it in BotFather and remove the old secret from
Auth0. Re-run email OTP login and the affected logout/account-switch scenarios.
Never bypass Auth0 by accepting a Telegram ID token at the game API.

Provider references:

- [Telegram Login and OIDC](https://core.telegram.org/bots/telegram-login)
- [Auth0 OIDC Enterprise connection](https://auth0.com/docs/authenticate/identity-providers/enterprise-identity-providers/oidc)
- [Auth0 OIDC PKCE and claim mapping](https://auth0.com/docs/authenticate/identity-providers/enterprise-identity-providers/configure-pkce-claim-mapping-for-oidc)
