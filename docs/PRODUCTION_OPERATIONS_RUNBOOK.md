# Production operations runbook

This runbook separates repository-verifiable A4b controls from actions that
require a real protected environment. A green CI run is not production
validation.

## Code-verifiable controls

The release candidate must satisfy all of the following:

- anonymous telemetry and crash requests are bounded by raw-body, DTO,
  per-client and process-global limits;
- forwarded client-address headers are not trusted by the application;
- public `/livez`, public `/readyz` and protected Prometheus have separate
  endpoint semantics;
- protected profiles bind the management listener to loopback by default;
- the loopback management listener remains HTTP; public-listener TLS is a
  deployment gate;
- JMX endpoint export and Spring/Tomcat/Hikari management MBeans remain disabled;
- servlet context parameters remain empty so they cannot late-bind Actuator
  overrides after the startup guard;
- the servlet/MVC roots and path-pattern parser remain canonical so ingress
  filtering and controller routing interpret paths identically;
- auto-configuration and eager initialization stay enabled, the runtime stays
  servlet-based and the JVM shutdown hook stays connected to graceful shutdown;
- all five canonical dispatcher types, including `REQUEST`, stay behind the
  security filter chain;
- health response caching remains disabled so readiness reflects the current
  database state;
- `DOWN`, `OUT_OF_SERVICE` and `UNKNOWN` readiness states return HTTP `503`;
- metrics require `ROLE_ADMIN`, expose no health details and carry no
  account/IP/payload labels;
- meter and observation deny filters remain empty so required series stay
  available, `http.server.requests` stays stable and the HTTP URI-tag ceiling
  remains 100;
- Prometheus remains pull-only; Pushgateway publishing stays disabled;
- HTTP, datasource, query, transaction and shutdown waits have finite
  protected-profile bounds;
- the PostgreSQL synthetic backup/restore drill passes with no production
  data or credential.

See [ADR 0026](adr/0026-production-operational-controls.md) for the canonical
contract.

## Public ingestion incident

The application-level limiter is per backend process. It is a bounded
defense-in-depth control, not a global user or IP quota.

When `413 PAYLOAD_TOO_LARGE` increases:

1. confirm the affected route (`telemetry` or `crash`) without retaining the
   rejected body;
2. compare the client build with the documented body/field limits;
3. do not raise a protected-profile limit before review and a new release
   candidate;
4. treat unexpected volume as an ingress abuse signal.

When `429 RATE_LIMITED` increases:

1. inspect only aggregate route/outcome counters;
2. verify the number of healthy backend instances and external ingress policy;
3. do not use raw remote addresses, subjects, event names, messages or stack
   traces as metric labels;
4. if cross-instance coordination is required, change the external
   WAF/gateway policy rather than claiming the in-process limiter is
   distributed.

Rejected requests must not create telemetry/crash rows. Any evidence containing
request bodies, tokens, raw client keys or database credentials is invalid.

## Probe and metrics topology

Protected profiles default to:

```text
public application listener
├── /api/v1/**
├── /livez
└── /readyz

loopback management listener (127.0.0.1:8081)
├── /actuator/health/liveness
├── /actuator/health/readiness
└── /actuator/prometheus  (ROLE_ADMIN)
```

`/livez` and `/readyz` are the canonical no-detail application-port aliases.
Liveness must not depend on PostgreSQL. Readiness includes PostgreSQL and may
remove an instance from traffic. Their Actuator counterparts remain on the
loopback management listener. Health responses expose neither component names
nor details.

Before a real deployment is marked validated, record evidence that:

- the management listener is not reachable from the public internet, while
  only `/livez` and `/readyz` are intentionally reachable as probes;
- only the intended orchestrator/monitoring path can reach it;
- Prometheus authentication and network policy work on the deployed topology;
- probe intervals and failure thresholds fit the configured timeout and drain
  budgets;
- dashboards and alerts are connected to the deployed service.

Those checks cannot be completed by repository CI.

## Timeout and shutdown review

The repository defaults are:

| Budget | Default |
|---|---:|
| HTTP connection | 5 s |
| HTTP keep-alive | 15 s |
| Async request | 10 s |
| Datasource acquisition | 5 s |
| Datasource validation | 3 s |
| JDBC query | 10 s |
| Transaction | 15 s |
| Graceful shutdown phase | 20 s |

Deployment owners must additionally verify load-balancer, orchestrator, OIDC
JWKS, PostgreSQL role-level statement/lock and infrastructure drain timeouts.
An outer timeout must not terminate a process before its inner request and
graceful-drain budgets can complete.

## Synthetic backup/restore drill

Requirements:

- Docker-compatible runtime;
- Java 21;
- Python 3;
- GNU `timeout` with `--kill-after` support;
- a clean Git worktree, index and untracked-file set at the exact commit being
  tested, in an isolated workspace with no concurrent writers;
- no production environment variables, credentials, dump or database;
- a new output path outside the repository that does not already exist, under
  an existing private parent directory.

Run:

```bash
expected_source_git_sha="$(git rev-parse HEAD)"
drill_parent="$(mktemp -d)"

scripts/operations/run-synthetic-backup-restore-drill.sh \
  "$drill_parent/full" \
  "$expected_source_git_sha"

python3 scripts/operations/verify-backup-restore-evidence.py \
  full \
  "$drill_parent/full" \
  "$expected_source_git_sha"
```

Expected files:

```text
walking-rpg-synthetic.dump
walking-rpg-synthetic.dump.sha256
archive.toc
evidence.json
evidence.json.sha256
```

The verifier must confirm:

- `schemaVersion` is `walking-rpg-backup-restore-evidence-v1`;
- `scope` is `SYNTHETIC_CI`;
- `productionValidated` is `false`;
- `sourceGitSha` equals the explicitly expected 40-character tested commit and
  `sourceTreeClean` is `true`;
- the JSON has no duplicate or undeclared fields and all timestamps are full
  RFC 3339 UTC instants;
- archive and evidence checksums match;
- the PostgreSQL image/tool versions, restore flags, Flyway V13 schema and
  application-table set match the exact reviewed contract;
- source and restored schema, data and sequence manifests match exactly;
- the applied Flyway chain is current.

The full synthetic output is disposable runner-local data. CI verifies it and
uploads only `evidence.json` plus its checksum; the dump, dump checksum and TOC
are never uploaded. None of these files may be committed as production
evidence.

The retained artifact is a receipt, not the full archive proof. Download it
into a directory containing exactly its two files and run:

```bash
python3 scripts/operations/verify-backup-restore-evidence.py \
  receipt \
  DOWNLOADED_RECEIPT_DIRECTORY \
  EXPECTED_TESTED_HEAD_SHA
```

Receipt verification proves strict schema, checksum self-consistency and
binding to the supplied commit. It does not authenticate who produced the
files. Provenance also requires a trusted GitHub Actions run for the same head
SHA and the `actions/upload-artifact` digest recorded in that run's summary.
Only `full` mode, executed before upload, verifies the disposable archive and
TOC themselves. Neither mode proves a production restore.

## Actual backup/restore gate

A real restore remains `EXTERNAL_VALIDATION_REQUIRED`. Use the
[evidence template](evidence/backup-restore-drill-template.md) only after an
owner-approved drill in an isolated protected environment.

The dated evidence must cover:

- backup source/process and immutable archive identifier, without credentials;
- PostgreSQL and Flyway versions;
- archive checksum verification before restore;
- isolated target and explicit proof it was not production;
- schema and selected non-sensitive control-data checks;
- measured backup and restore durations;
- agreed RPO/RTO result;
- role/ACL/PITR behavior;
- target disposal;
- incident/rollback owner approval.

Production credentials, dumps and connection strings must never be committed.

## Rollback

Operational rollback preparation can be documented and tested synthetically,
but the deployment drill remains external.

For ordinary backend/config/content rollback:

1. stop cohort or rollout expansion;
2. preserve privacy-safe metrics and immutable incident evidence;
3. disable risky remote-config capability before reverting code that depends
   on it;
4. verify schema and binary compatibility;
5. deploy or forward-fix through the protected release process.

Durable event-result handoff retains its stricter rule:

1. disable activation on the whole new backend pool;
2. drain capable pending receipts to zero;
3. only then roll back to a binary that does not support the handoff.

The exact receipt query and sequence remain in
[the closed beta runbook](CLOSED_BETA_RUNBOOK.md#rollback).

## External validation checklist

Do not mark A4 operational validation complete until all are evidenced:

- real OIDC/database secrets supplied by a protected secret store;
- canonical production DNS/TLS endpoint and least-privilege database role;
- deployed management network policy;
- external WAF/gateway or distributed abuse controls where required;
- dashboards, alerting, log retention/redaction and incident ownership;
- rollback drill;
- backup scheduling, encryption, retention, PITR and RPO/RTO policy;
- dated restore of a real backup in an isolated environment.
