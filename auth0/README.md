# Auth0 alpha configuration

This directory contains public, secret-free inputs for the Auth0 EU tenant.
It is not proof that a tenant, connection or credential exists.

## Post Login Action

Deploy actions/step-beyond-token-contract.js with the Node 22 runtime and add
it to the Login / Post Login flow. The Action applies only to the custom API
identifier https://api.stepbeyond.game and:

- validates the native client's bounded ext-installation-id parameter;
- emits https://api.stepbeyond.game/device_id on interactive and refresh
  access tokens;
- emits https://api.stepbeyond.game/auth_time only from Auth0's recorded
  interactive authentication methods;
- denies a matching API transaction when required signed inputs are absent.

Run the secret-free contract tests with:

    node --test auth0/actions/step-beyond-token-contract.test.js

## Telegram OIDC connection

Telegram is an upstream Auth0 Enterprise OIDC connection; the native app and
backend continue trusting only Auth0. The reviewed connection template,
minimal-scope policy, owner provisioning steps, validation matrix and rollback
procedure are in [`telegram/README.md`](telegram/README.md) and
[ADR 0037](../docs/adr/0037-telegram-login-through-auth0.md).

Run its secret-free contract test with:

    node --test auth0/telegram/telegram-oidc-connection.test.js

The exact tenant domain, client IDs, connection credentials, SMTP settings and
Management API credentials belong in Auth0 and the protected stage secret
store, not in this directory. Follow
[ADR 0035](../docs/adr/0035-auth0-alpha-authentication-contract.md) for the
environment matrix and validation gates.
