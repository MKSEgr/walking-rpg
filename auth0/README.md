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

The exact tenant domain, client IDs, connection credentials, SMTP settings and
Management API credentials belong in Auth0 and the protected stage secret
store, not in this directory. Follow
[ADR 0035](../docs/adr/0035-auth0-alpha-authentication-contract.md) for the
environment matrix and validation gates.
