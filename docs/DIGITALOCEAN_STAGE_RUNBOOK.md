# DigitalOcean internal-alpha stage runbook

This runbook applies [ADR 0036](adr/0036-digitalocean-alpha-stage.md) to
`walking-rpg-alpha-eu`. It prepares and validates a paid external environment;
repository CI cannot execute these steps or mark TASK-006 validated.

## Authority and stop rules

- Hosting Owner: `@MKSEgr`.
- Release Owner / stop authority: `@MKSEgr`.
- Planned region: Frankfurt (`fra`).
- Monthly creation gate: owner confirms the current estimate is at or below
  `$30` before creating resources.
- Never paste DigitalOcean tokens, database credentials, Auth0 tokens, CA
  contents, raw logs or user data into Git, PRs or issue comments.

Stop immediately on any of the following:

- App Spec contains an unresolved `@@...@@` token;
- source commit differs from the approved candidate;
- database uses `sslmode=require`, an IP literal or a connection URL containing
  credentials;
- protected container starts without the managed CA;
- database is open beyond reviewed Trusted Sources;
- runtime role is superuser/createdb/createrole/replication;
- management port is reachable publicly;
- payment/push development provider is available;
- alert delivery, deployment rollback target or PITR path is absent;
- secrets, identity data or health data appear in retained evidence.

## 1. Prerequisites

Record owner approval for:

- DigitalOcean project and billing;
- one PostgreSQL 17 Standard node in Frankfurt, no standby;
- one App Platform 1 GiB service;
- Auth0 EU issuer, JWKS URL and API audience from ADR 0035;
- runtime log destination and retention period;
- alert email or Slack destination.

Choose and record:

- approved source SHA and tree;
- new release-candidate name; do not move `alpha-rc1`;
- database cluster name, database name and custom user;
- previous safe App Platform deployment ID, if this is an update;
- maintenance window and planned UTC deployment interval.

## 2. Create the managed database

In the DigitalOcean control plane:

1. Create PostgreSQL **Standard**, version **17**, one node, region Frankfurt.
2. Create database `walking_rpg` and user `walking_rpg_app`; do not use
   `defaultdb` or `doadmin` in the application.
3. Ensure the runtime user has no superuser, createdb, createrole, replication
   or bypass-RLS attributes. It may own only the application database/schema
   needed by Flyway and runtime DML.
4. Enable the provider's `verify-full` connection details and confirm the CA is
   available.
5. Configure backup/PITR and the owner-approved maintenance window. Record
   configuration metadata, not credentials.

The first application deployment may temporarily fail before the app is added
as a Trusted Source. Do not disable Trusted Sources as a workaround. Attach the
app to the database and allow only that app plus a time-bounded drill source
when a restore check explicitly requires one.

## 3. Render the reviewed App Spec

Set only non-secret identifiers and public OIDC configuration in a private
operator shell:

```bash
export STAGE_POSTGRES_CLUSTER_NAME=walking-rpg-alpha-pg-fra
export STAGE_POSTGRES_DATABASE=walking_rpg
export STAGE_POSTGRES_USER=walking_rpg_app
export STAGE_OIDC_ISSUER_URI=https://TENANT.eu.auth0.com/
export STAGE_OIDC_JWK_SET_URI=https://TENANT.eu.auth0.com/.well-known/jwks.json
export STAGE_OIDC_AUDIENCE=https://api.stepbeyond.game

umask 077
rendered_spec="$(mktemp)"
python3 scripts/operations/render_digitalocean_stage_spec.py > "$rendered_spec"
```

Inspect the diff against `infra/digitalocean/app.yaml.template`. The rendered
file must contain no credential or CA value: database secrets remain
`${alpha-db.*}` bindable references. Delete the rendered file after applying
it. Never commit it.

Create/update the app using the reviewed spec through the DigitalOcean control
plane or authenticated `doctl`. Creating resources is an owner-approved paid
action; the repository workflow does not do it automatically.

## 4. Bind database and identity

Confirm the resulting App Spec still has:

- `deploy_on_push: false`;
- one 1 GiB backend instance;
- database component `alpha-db`, PostgreSQL 17, the custom database/user;
- `POSTGRES_PASSWORD` and `POSTGRES_CA_CERT` as encrypted runtime bindables;
- `SPRING_PROFILES_ACTIVE=stage`;
- exact Auth0 issuer, JWKS URL, audience and namespaced claims;
- management address `127.0.0.1:8081`;
- payment and push disabled by the protected profile.

Add the App as the database Trusted Source. No build step may connect to the
database; all bindables are runtime-only.

## 5. Deployment verification

Record the App Platform deployment ID and `source_commit_hash`. Compare it with
the approved 40-character SHA and tree before any tester receives a build.

Verify from an external network:

```bash
curl --fail --silent --show-error https://STAGE-ENDPOINT/livez
curl --fail --silent --show-error https://STAGE-ENDPOINT/readyz
```

Expected result is HTTP 200 with no component details. Then verify:

- `/readyz` becomes non-200 when database access is safely blocked during a
  maintenance test, while `/livez` stays 200;
- port `8081` and `/actuator/**` are not reachable through public ingress;
- an unsigned, expired, wrong-audience or wrong-issuer JWT cannot reach API;
- a valid alpha token can access only its owner-scoped data;
- sandbox purchase and development push paths are unavailable;
- Enhanced Threat Control does not challenge legitimate iOS/Android API calls;
- no token, authorization header, database value, raw identity or health data
  appears in deployment/runtime logs.

Inside an owner-approved database session, record only redacted results from:

```sql
SELECT current_user;
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolreplication,
       rolbypassrls
FROM pg_roles
WHERE rolname = current_user;
SELECT ssl, version, cipher
FROM pg_stat_ssl
WHERE pid = pg_backend_pid();
SELECT installed_rank, version, success
FROM flyway_schema_history
ORDER BY installed_rank DESC
LIMIT 1;
```

Expected: custom application user; every role privilege flag is false; TLS is
true; latest successful Flyway version is repository-current. The JDBC startup
guard, canonical host, provider CA and `sslmode=verify-full` configuration are
recorded together because `pg_stat_ssl` alone cannot prove hostname checking.

## 6. Observability gate

Before marking deployment validated:

- connect the declared deployment, CPU, memory and restart alerts to the
  approved email/Slack destination;
- receive and timestamp at least the successful-deployment notification;
- capture App Platform CPU, memory, restart, request and latency dashboard
  links;
- configure a supported runtime log destination and record its retention and
  access policy; App Platform build/deploy logs are retained separately, while
  runtime log retention requires forwarding;
- verify log access is least-privilege and perform a redaction review;
- record who acknowledges incidents and how the cohort is stopped.

Do not add a log token to the repository App Spec. Configure it as an encrypted
provider value and retain only the destination name/policy in evidence.

## 7. Backup, restore and rollback boundary

TASK-006 requires a usable rollback target but does not replace TASK-009 and
TASK-010 drills:

1. record the previous safe App Platform deployment ID;
2. verify the platform offers rollback to it and that the candidate's Flyway
   schema remains binary-compatible;
3. do not activate `chapter-1-v2` while old binaries can receive traffic;
4. record PITR availability and recovery window;
5. perform the dated real-backup restore only under TASK-009 in an isolated
   target using the existing evidence template;
6. perform alert/stop/deployment rollback under TASK-010.

Ordinary rollback never uses a destructive database restore. Once new content
or schema has accepted writes incompatible with an older binary, use a forward
fix.

## 8. Evidence and completion

Fill
[`digitalocean-stage-deployment-template.md`](evidence/digitalocean-stage-deployment-template.md)
with redacted links and results. TASK-006 remains open until evidence covers
every issue #151 acceptance item. Merge of repository code proves only
`CODE_COMPLETE`, not `VALIDATED`.
