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
- image digest or embedded source SHA/tree differs from the approved candidate;
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

- approved source SHA and tree; the source must be commit
  `31027db88250e83112434db8cfcd85ed2b31fa8a` or a descendant because that is
  the first `master` commit containing the protected image provenance guard;
- successor release-candidate name; do not move or relabel `alpha-rc1`;
- immutable `ghcr.io/mksegr/walking-rpg-backend@sha256:...` digest and its
  successful publisher workflow/receipt;
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

## 3. Publish the approved backend image

The App Platform source must be an OCI image digest, not a Git branch or image
tag. A manual App Platform deployment from a branch pulls its current head,
which can advance after approval and before Flyway starts. Digests identify the
exact image before App Platform creates a deployment.

Before the first publication, configure the GitHub environment
`stage-release` with `@MKSEgr` as required reviewer. Dispatch
**Publish backend release candidate** from the repository default branch and
enter the approved full source commit and tree SHAs. The workflow fails unless:

- the dispatch itself uses the current `master` ref and that ref has not moved
  between dispatch and source verification;
- both inputs are lowercase 40-character object IDs;
- the checkout exactly matches both values, the commit is in `master` and it
  descends from the pinned provenance-guard baseline `31027db…`;
- the selected Dockerfile contains exactly the current reviewed JDK/JRE
  `tag@sha256` OCI index pins; an older source with mutable or superseded base
  refs is rejected before registry login and build;
- the selected source still contains the root-owned provenance files and the
  protected entrypoint's exact SHA/tree comparison contract;
- integrated `CI` and `Release quality` push workflows succeeded for that
  commit;
- every remote Action used by the publisher is bound to a reviewed full commit
  SHA from its direct upstream repository; adjacent release comments are not
  execution inputs;
- release-readiness passes and the Linux AMD64 image is published by digest;
- the image pulled back by that digest reports Linux AMD64, the non-root user,
  exact source labels/files, read-only root-owned provenance paths and a
  byte-identical protected entrypoint before the workflow writes a receipt.

Do not publish a source before `31027db…`, even if it is an ancestor of
`master` and its historical CI was green. Those images predate the startup
comparison and cannot satisfy the current receipt contract.

Treat an Action update as release code: verify the proposed SHA against the
direct upstream release tag, inspect its release notes and diff, and require a
separate CODEOWNER-approved PR plus the complete release gate. Never switch the
publisher back to a branch or moving tag. If an update fails, restore the
previous reviewed SHA in another PR and rerun every gate before publication.

Treat a Temurin base-image update as release code too. Resolve the tag to its
multi-platform OCI index digest through both Docker Hub metadata and the
registry manifest response; do not substitute an architecture-specific child
manifest. Update both Dockerfile pins, the CI policy constants and the
publisher's independent reviewed constants in one CODEOWNER-approved PR, then
require the complete release gate and real backend container build. Rollback
uses an already published application image digest; never rebuild historical
source against a moved or superseded base tag.

The image repository is fixed to
`ghcr.io/mksegr/walking-rpg-backend`. Because the source repository is public
and the reviewed App Spec contains no registry credential, make this package
public before applying the spec. Do not paste a GHCR token into the App Spec,
issue, PR or evidence. If a future decision requires a private image, add a
separate protected-credential design before changing this contract.

Download the workflow's `backend-image-receipt-<source-sha>` artifact, verify
its companion SHA-256 file, and record the workflow URL, artifact digest,
source SHA/tree and returned `sha256:...` image digest. Retain the included
offline provenance bundle for the exact receipt JSON; stage evidence validation
rejects an unattested or locally reconstructed receipt. A Git tag or image tag
is not a substitute for this digest.

## 4. Render the reviewed App Spec

Set only non-secret identifiers and public OIDC configuration in a private
operator shell:

```bash
export STAGE_BACKEND_IMAGE_DIGEST=sha256:REPLACE_WITH_64_LOWERCASE_HEX
export STAGE_BACKEND_SOURCE_GIT_SHA=REPLACE_WITH_40_LOWERCASE_HEX
export STAGE_BACKEND_SOURCE_GIT_TREE=REPLACE_WITH_40_LOWERCASE_HEX
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
`${alpha-db.*}` bindable references. It must contain the exact approved image
digest and no `github`, `branch`, `tag` or `deploy_on_push` source. Delete the
rendered file after applying it. Never commit it.

Create/update the app using the reviewed spec through the DigitalOcean control
plane or authenticated `doctl`. Creating resources is an owner-approved paid
action; the repository workflow does not do it automatically.

## 5. Bind database and identity

Confirm the resulting App Spec still has:

- fixed public GHCR repository and the approved immutable image digest, with no
  moving Git branch or image tag;
- `EXPECTED_SOURCE_GIT_SHA` and `EXPECTED_SOURCE_GIT_TREE` matching the image
  publisher receipt; the protected entrypoint rejects any mismatch with the
  provenance embedded during the image build;
- one 1 GiB backend instance;
- database component `alpha-db`, PostgreSQL 17, the custom database/user;
- `POSTGRES_PASSWORD` and `POSTGRES_CA_CERT` as encrypted runtime bindables;
- `SPRING_PROFILES_ACTIVE=stage`;
- exact Auth0 issuer, JWKS URL, audience and namespaced claims;
- management address `127.0.0.1:8081`;
- payment and push disabled by the protected profile.

Add the App as the database Trusted Source. No build step may connect to the
database; all bindables are runtime-only.

## 6. Deployment verification

Record the App Platform deployment ID and the image digest retained in the
deployed App Spec. Compare the digest with the approved publisher receipt
before any tester receives a build. Confirm startup succeeded with the same
embedded source SHA/tree; a mismatch must stop before Java and Flyway start.

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

## 7. Observability gate

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

## 8. Backup, restore and rollback boundary

TASK-006 requires a usable rollback target but does not replace TASK-009 and
TASK-010 drills:

1. record the previous safe App Platform deployment ID;
2. verify the platform offers rollback to it and that the candidate's Flyway
   schema remains binary-compatible;
3. do not activate `chapter-1-v2` while old binaries can receive traffic;
4. record PITR availability and recovery window;
5. perform the dated real-backup restore only under TASK-009 in an isolated
   target using the existing evidence template;
6. perform alert/stop/deployment rollback under TASK-010 and retain the strict
   [protected incident/rollback evidence](PRODUCTION_OPERATIONS_RUNBOOK.md#protected-incidentrollback-gate).

Ordinary rollback never uses a destructive database restore. Once new content
or schema has accepted writes incompatible with an older binary, use a forward
fix.

## 9. Evidence and completion

Use
[`digitalocean-stage-deployment-template.md`](evidence/digitalocean-stage-deployment-template.md)
as the human operator worksheet. Retain the result in the strict
[`digitalocean-stage-deployment-template.json`](evidence/digitalocean-stage-deployment-template.json)
format. Its exact control set covers the deployment, database, identity,
provider-isolation, probe, observability, backup and rollback gates above.

Any record containing a deployment claim requires an offline attestation from
`.github/workflows/protected-stage-evidence.yml`. That workflow runs behind the
`stage-release` environment, verifies the exact current-master publisher
receipt and its own protected attestation, preflights the complete stage record
and independently requests the public `/livez` and `/readyz` endpoints before
attesting the stage-evidence bytes. The endpoint is restricted to a
credential-free `*.ondigitalocean.app` HTTPS origin.

After downloading the retained inputs, verify them with:

```bash
python3 scripts/ci/verify_stage_deployment_evidence.py stage-evidence.json \
  --publisher-receipt backend-image-receipt.json \
  --publisher-receipt-attestation backend-image-receipt-attestation.jsonl \
  --evidence-attestation stage-evidence-attestation.jsonl \
  --require-validated
```

`--require-recorded` accepts an honest no-run `BLOCKED` handoff, including a
record with no publisher receipt yet. It never converts missing infrastructure
or a partial run into `VALIDATED`. `--prepare-attestation` is only a structural
preflight used by the protected workflow; consumers still require the emitted
attestation bundle.

TASK-006 remains open until evidence covers every issue #151 acceptance item.
Merge of repository code proves only `CODE_COMPLETE`, not `VALIDATED`.
