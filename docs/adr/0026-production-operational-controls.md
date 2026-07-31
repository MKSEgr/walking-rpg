# ADR 0026: production operational controls

- Status: Accepted
- Date: 2026-07-30

## Context

ADR 0017 deliberately left anonymous telemetry/crash ingestion without a
production abuse boundary. ADR 0025 isolated development providers and unsafe
datasources, but explicitly did not implement operational ingress, monitoring
or backup/restore validation.

The remaining autonomous A4b slice must make the backend safe to package and
exercise without claiming that CI is a production deployment. In particular:

- anonymous ingestion needs bounded memory, request size and request rate;
- liveness, readiness and metrics must not share one generic public health
  surface;
- connection, database and shutdown waits need explicit finite budgets;
- the PostgreSQL backup/restore procedure needs a reproducible synthetic drill
  that carries no production data or secret.

Production DNS/TLS, credentials, network policy, a distributed limiter,
monitoring/alerting and a dated restore of a real backup still require an
external environment and evidence.

## Decision

### Anonymous ingestion

`POST /api/v1/telemetry/events` and
`POST /api/v1/diagnostics/crashes` remain anonymous so that startup and
pre-authentication failures can be reported. Authentication, when present,
may associate the accepted record with the canonical subject; a client-supplied
user identifier is never accepted.

Both routes have two in-process token buckets:

- a direct-client bucket derived from the servlet remote address;
- a process-global bucket for the route.

Forwarded headers are not trusted by the application. Protected profiles use
`server.forward-headers-strategy=none`; deployment ingress must not treat an
arbitrary client-supplied `X-Forwarded-For` as limiter identity. Salted hashes
of direct-client keys are kept only in bounded in-memory state and expire after
inactivity. Raw addresses are not persisted, logged or used as metric labels.

The default policy is:

| Route | Body | Client rate / burst | Process rate / burst |
|---|---:|---:|---:|
| telemetry | 16 KiB | 60/minute / 20 | 6,000/minute / 1,000 |
| crash | 64 KiB | 6/minute / 3 | 600/minute / 100 |

At most 10,000 client buckets are retained, with a ten-minute idle TTL.
Protected profiles reject configuration that disables a limit or raises it
outside the reviewed operational envelope.

Rejected bodies do not call the application service and therefore create no
database state. Oversized input returns `413 PAYLOAD_TOO_LARGE`; rate
exhaustion returns `429 RATE_LIMITED` with `Retry-After`. Both responses carry
`Cache-Control: no-store`. Error responses use the existing privacy-safe API
envelope and do not echo a request body, client key or raw exception.

DTO limits remain a second boundary after the raw body limit:

- telemetry event name: 100 characters; attributes: at most 64 top-level keys;
- crash platform: 32; app version: 64; error type: 160; message: 2,000
  characters;
- crash stack trace: 32,768 characters; context: at most 64 top-level keys.

The error-type limit deliberately matches the existing PostgreSQL
`varchar(160)` column. This slice does not introduce arbitrary payload-derived
metric tags.

These controls are per process and are defense in depth. Cross-instance rate
coordination, WAF/CDN policy, trusted proxy topology and load/abuse evidence are
external gates.

### Operational endpoints

Actuator discovery and `info` exposure are disabled. The supported operational
surface is:

| Endpoint | Meaning | Application authorization |
|---|---|---|
| `/livez` | canonical application-port liveness alias; no dependency detail | anonymous |
| `/readyz` | canonical application-port readiness alias; includes PostgreSQL | anonymous |
| `/actuator/health/liveness` | management-port liveness counterpart | anonymous |
| `/actuator/health/readiness` | management-port readiness counterpart | anonymous |
| `/actuator/prometheus` | management-port low-cardinality metrics | `ROLE_ADMIN` |

Health component names and details are never returned. Other `/actuator/**`
routes are denied, and JMX endpoint export is disabled.
The separate Spring application admin MXBean plus Tomcat and Hikari management
MBeans are disabled as well.
Protected profiles also reject servlet context parameters so late container
initialization cannot override the pre-context Actuator policy.
The main servlet context and MVC servlet stay at the root, and MVC remains on
the path-pattern parser used by the ingress filter.
Protected profiles cannot disable or exclude auto-configuration, defer guard
beans through lazy initialization, switch away from the servlet runtime or
disconnect the JVM shutdown hook from graceful shutdown.
Security filter registration remains active for request, async, error, forward
and include dispatches; protected profiles cannot remove `REQUEST`.

In `stage` and `prod`, Actuator traffic uses a dedicated loopback listener
(`127.0.0.1:8081` by default), separate from the public application listener.
The management listener remains HTTP on loopback. The application listener may
use application-native TLS or external termination according to the deployment;
that public TLS topology remains an external gate.
Spring's additional health paths publish only the canonical no-detail
`/livez` and `/readyz` aliases on the application listener so an orchestrator
does not need access to the management listener. Making the loopback Actuator
counterparts or Prometheus reachable through a real monitoring path requires
an explicit external network policy; CI does not validate that policy.
Health response caching is disabled so a previously healthy readiness response
cannot conceal a later database outage.
The explicit aggregation order prioritizes `DOWN`, `OUT_OF_SERVICE` and
`UNKNOWN` over `UP`; each non-ready status maps to HTTP `503`.

Prometheus metrics must use bounded route/status/outcome tags. Account IDs,
remote addresses, tokens, request bodies, event names, crash messages and
stack traces are forbidden as labels. The public-ingress outcome `accepted`
means admitted by the rate/body filter; DTO validation or the controller may
still return a later `4xx/5xx`.
Protected profiles reject meter and observation deny filters so required JVM,
HTTP and public-ingress series cannot be silently disabled. Observation-backed
meters remain enabled, the `http.server.requests` name stays stable and the
HTTP URI-tag ceiling remains 100.
Prometheus remains pull-only; Pushgateway publishing and its configuration are
rejected in protected profiles.

### Operational timeouts

Finite defaults are part of the reviewed configuration:

- HTTP connection: 5 seconds;
- HTTP keep-alive: 15 seconds and at most 100 requests;
- asynchronous request: 10 seconds;
- datasource acquisition: 5 seconds;
- datasource validation: 3 seconds;
- JDBC query: 10 seconds;
- transaction: 15 seconds;
- graceful shutdown phase: 20 seconds.

The server also bounds request headers, parameters and swallowed request data.
Protected-profile startup validation rejects missing, non-positive or relaxed
values outside the reviewed envelope. Database-role `statement_timeout`,
`lock_timeout` and infrastructure drain timing still require validation
against the real deployment.

### Synthetic backup/restore drill

The repository contains a synthetic PostgreSQL 17 drill:

1. start isolated source and target PostgreSQL
   `postgres:17.10-alpine3.24` containers pinned to the reviewed
   multi-platform index digest
   `sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193`;
2. apply Flyway V1 through the current migration;
3. load a non-production fixture that covers every application table;
4. create a custom-format archive without owner, ACL or tablespace state;
5. verify the archive checksum before restore;
6. restore into a fresh target with single-transaction, exit-on-error,
   no-owner, no-privileges and no-tablespaces semantics;
7. compare exact schema, data and sequence manifests;
8. emit machine-verifiable evidence.

The command is:

```bash
EXPECTED_SOURCE_GIT_SHA="$(git rev-parse HEAD)"
scripts/operations/run-synthetic-backup-restore-drill.sh \
  OUTPUT_DIR \
  "$EXPECTED_SOURCE_GIT_SHA"
python3 scripts/operations/verify-backup-restore-evidence.py \
  full \
  OUTPUT_DIR \
  "$EXPECTED_SOURCE_GIT_SHA"
```

`OUTPUT_DIR` must be outside the repository and must not already exist. The
repository must be an isolated workspace with no concurrent writers and no
worktree, index or untracked changes. The runner repeats this assertion before
the drill, after Maven and after full verification. The evidence has
`schemaVersion=walking-rpg-backup-restore-evidence-v1`,
`scope=SYNTHETIC_CI`, `productionValidated=false`, the exact tested head SHA
and a clean-tree assertion. The strict verifier rejects duplicate or unknown
JSON fields and offers separate `full` and retained `receipt` modes. The
retained receipt is useful only with the trusted CI run, matching head SHA and
recorded upload-artifact digest; its checksum alone is not producer
authentication.

The synthetic drill proves that the versioned schema and fixture can round-trip
with the packaged tooling. It does not prove production credentials, roles,
ACLs, backup scheduling, encryption, retention, object storage, PITR, RPO/RTO
or restoration of an actual dated backup.

## Consequences

- A single anonymous client or request cannot consume unbounded process memory
  or write an unbounded burst through the two public ingestion routes.
- Probes and metrics have distinct semantics and exposure.
- Operational waits no longer depend only on framework defaults.
- CI can catch a broken PostgreSQL archive/restore path without production
  access.
- A per-process limiter is not a distributed quota and must not be described as
  one.
- The actual management network, alerts and restore readiness stay
  `EXTERNAL_VALIDATION_REQUIRED`.

## Verification

- deterministic limiter tests use an injected clock and verify `413`, `429`,
  `Retry-After`, bucket eviction and zero writes on rejection;
- security tests verify the exact actuator allowlist and metrics
  authorization;
- protected-runtime tests cover operational bounds and alternate property
  forms;
- the synthetic drill verifies archive checksum and exact schema/data/sequence
  manifests;
- release-readiness checks pin the configuration, tests, runbook and evidence
  contract.

Operational procedure and external gates are defined in
[the production operations runbook](../PRODUCTION_OPERATIONS_RUNBOOK.md).
