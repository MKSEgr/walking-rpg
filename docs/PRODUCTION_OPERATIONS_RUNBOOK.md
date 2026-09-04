# Production operations runbook

This runbook separates repository-verifiable A4b controls from actions that
require a real protected environment. A green CI run is not production
validation.

The internal-alpha DigitalOcean topology, paid deployment sequence and
environment-specific evidence contract are in
[DIGITALOCEAN_STAGE_RUNBOOK.md](DIGITALOCEAN_STAGE_RUNBOOK.md). This document
remains the provider-neutral application operations contract.

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
- the PostgreSQL image/tool versions, restore flags, Flyway V33 schema and
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
[Markdown evidence worksheet](evidence/backup-restore-drill-template.md) only
after an owner-approved drill in an isolated protected environment, then retain
the outcome in the strict
[`walking-rpg-protected-backup-restore-v1` JSON record](evidence/backup-restore-drill-template.json).

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
The JSON contract intentionally contains only bounded identifiers, hashes,
timestamps, booleans, measurements and issue numbers. The archive and raw
database evidence stay outside GitHub.

Any record containing a restore claim must bind the exact `RECORDED VALIDATED`
stage record and its attestation from `.github/workflows/protected-stage-evidence.yml`.
After cleanup, place only the sanitized JSON inputs in the approved draft-release
asset location and run `.github/workflows/protected-backup-restore-evidence.yml`
behind the same `stage-release` environment. That workflow confirms current
master provenance, preflights the full record and attests its exact bytes; it
does not perform the restore or upload a backup.

Verify the retained chain with:

```bash
python3 scripts/ci/verify_backup_restore_evidence.py backup-restore-evidence.json \
  --stage-evidence stage-deployment-evidence.json \
  --stage-evidence-attestation stage-deployment-evidence-attestation.jsonl \
  --evidence-attestation backup-restore-evidence-attestation.jsonl \
  --require-validated
```

`--require-recorded` accepts an honest no-run `BLOCKED` handoff with no external
claims. `--prepare-attestation` is only the protected workflow preflight;
downstream consumers still require the final restore-evidence attestation.

## `chapter-1-v2` activation

Flyway V14 must finish with exactly one active `chapter-1-v1` row and one
inactive staged `chapter-1-v2` row. Do not activate v2 as part of migration or
while any backend binary that does not know `resonance-pocket` can receive
traffic. V15 then backfills `activated_at` for the already-active v1 row and
leaves staged v2 `NULL`; its first explicit publish sets the timestamp once.

Before applying V15, inspect the v2 row:

```sql
SELECT content_version, is_active, created_by, created_at
FROM content_release
WHERE content_version = 'chapter-1-v2';
```

The expected untouched state is `is_active = false` and
`created_by = 'flyway'`. If v2 was already activated or published by a V14
backend, `created_at` is only the latest publish time and must not be used as
the first-activation baseline. Recover the original UTC timestamp from
immutable rollout/audit evidence and seed it explicitly before Flyway:

```sql
BEGIN;
ALTER TABLE content_release
    ADD COLUMN IF NOT EXISTS activated_at timestamptz;
UPDATE content_release
SET activated_at = TIMESTAMPTZ '<verified-first-activation-utc>'
WHERE content_version = 'chapter-1-v2'
  AND activated_at IS NULL;
COMMIT;
```

Without that explicit history V15 intentionally fails. Do not satisfy the
preflight by copying mutable `created_at`.

Activation sequence:

1. apply Flyway through V19 and deploy the new backend while v1 remains active;
2. verify bootstrap reports v1 with 18 nodes and Home exposes no
   `follow-resonance`, including in `lockedChoices`;
3. remove every old backend instance from traffic and wait for its graceful
   drain to finish;
4. verify service discovery/load-balancer state contains only the reviewed new
   binary;
5. publish `chapter-1-v2` through
   `POST /api/v1/admin/platform/content-releases` with the reviewed release
   notes and staged content payload; record returned `activatedAt` and verify a
   same-version republish preserves it;
6. verify bootstrap reports v2 in both version fields with 19 nodes, then use a
   non-production validation account at `mirror-delta-v1` to confirm locked and
   equipped projections;
7. monitor unknown-choice responses, event-resolution failures and Home 5xx
   before expanding the cohort.

The activation request content must match the staged V14 definition:

```json
{
  "contentVersion": "chapter-1-v2",
  "releaseNotes": "Первая глава: 18 основных узлов и опциональный резонансный маршрут.",
  "content": {
    "contentVersion": "chapter-1-v2",
    "chapterId": "signal-chapter-1",
    "nodeCount": 19,
    "topology": "resonance-route-v1"
  }
}
```

Before considering a rollback, drain writes and record both counts:

```sql
SELECT
    (SELECT count(*)
     FROM expedition_progress
     WHERE current_node_id = 'resonance-pocket') AS active_route_states,
    (SELECT count(*)
     FROM processed_event_resolution
     WHERE event_id = 'mirror-delta-v1'
       AND choice_id = 'follow-resonance') AS persisted_route_results;
```

Rollback to an old binary is allowed only if activation has been stopped and
both counts are zero. Once any route result is persisted, reactivating v1 or
deploying a binary unaware of the optional node is prohibited; use a forward
fix. Exact replay remains available on the new binary even if activation is
stopped.

## `chapter-1-v3` activation

Flyway V18 stages `chapter-1-v3` inactive and leaves the current release
unchanged. Activate it only after every pre-V18 backend has drained; those
instances do not know `storm-scriptorium` and cannot serve a persisted v3
route state.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v3",
  "releaseNotes": "Первая глава: второй опциональный маршрут через грозовой скрипторий.",
  "content": {
    "contentVersion": "chapter-1-v3",
    "chapterId": "signal-chapter-1",
    "nodeCount": 20,
    "topology": "storm-rift-v1"
  }
}
```

Then verify bootstrap reports v3 with 20 nodes and a non-production account at
`storm-archive-v1` sees `enter-storm-rift` locked without the compass and
available with it. Before rollback, require zero progress rows at
`storm-scriptorium` and zero `enter-storm-rift` resolution rows; otherwise use
a forward fix on a v3-capable binary.

## `chapter-1-v4` activation

Flyway V19 stages `chapter-1-v4` inactive and leaves the current release
unchanged. Activate it only after every pre-V19 backend has drained; those
instances do not know `root-memory` or `light-canopy` and cannot serve a
persisted v4 route state.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v4",
  "releaseNotes": "Первая глава: развилка Сада пустоты через память корней и световую крону.",
  "content": {
    "contentVersion": "chapter-1-v4",
    "chapterId": "signal-chapter-1",
    "nodeCount": 22,
    "topology": "void-orchard-fork-v1"
  }
}
```

Then verify bootstrap reports v4 with 22 nodes. A non-production account at
`void-orchard-v1` must see both `descend-root-echo` and
`climb-light-canopy`; each choice must enter its own optional node, whose two
server-owned resolutions return to `star-well`.

Before rollback, drain writes and require both counts to be zero:

```sql
SELECT
    (SELECT count(*)
     FROM expedition_progress
     WHERE current_node_id IN ('root-memory', 'light-canopy'))
        AS active_orchard_states,
    (SELECT count(*)
     FROM processed_event_resolution
     WHERE event_id = 'void-orchard-v1'
       AND choice_id IN ('descend-root-echo', 'climb-light-canopy'))
        AS persisted_orchard_results;
```

Once either count is non-zero, use a forward fix on a v4-capable binary.

## `chapter-1-v5` activation

Flyway V20 stages `chapter-1-v5` inactive and leaves the current release
unchanged. Activate it only after every pre-V20 backend has drained. This gate
enables the `prism-sextant-v1` recipe, equipment compatibility and its route as
one cluster-wide content change.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v5",
  "releaseNotes": "Первая глава: призматический секстант и скрытый путь через спектральную обсерваторию.",
  "content": {
    "contentVersion": "chapter-1-v5",
    "chapterId": "signal-chapter-1",
    "nodeCount": 23,
    "topology": "prism-sextant-route-v1"
  }
}
```

Then verify bootstrap reports v5 with 23 nodes. Home must expose both recipes;
a non-production account at `star-well-v1` must see `align-prism-sextant`
locked without the sextant, locked with the compass, and available with the
sextant equipped. Resolve the route through `spectrum-observatory-v1` and
verify that both choices return to `horizon-spire`.

Before rollback, drain writes and require both counts to be zero:

```sql
SELECT
    (SELECT count(*)
     FROM expedition_progress
     WHERE current_node_id = 'spectrum-observatory')
        AS active_spectrum_states,
    (SELECT count(*)
     FROM processed_event_resolution
     WHERE event_id = 'star-well-v1'
       AND choice_id = 'align-prism-sextant')
        AS persisted_spectrum_results;
```

Once either count is non-zero, use a forward fix on a v5-capable binary.

## Prism Sextant refinement rollout

Flyway V21 adds `rarity`/`upgraded_at` to unique inventory and immutable
item-upgrade command tables. Existing level-1 prism sextants are backfilled as
`UNCOMMON`; a compatibility trigger also normalizes level-1 sextants written by
a pre-V21 backend during a rolling deploy. Deploy V21-capable backends before
exposing the mobile action. The definition remains hidden unless
`chapter-1-v5` is active.

Verify the schema and invariant after migration:

```sql
SELECT version, rarity, count(*)
FROM unique_inventory_item
WHERE item_id = 'prism-sextant'
GROUP BY version, rarity
ORDER BY version, rarity;
```

Only `1/UNCOMMON` and `2/RARE` are valid. A backend rollback leaves the additive
V21 schema and refined items in place; do not undo the migration. Disable the
new mobile/backend action and use a forward fix if persisted refinement rows
need correction.

## `chapter-1-v6` activation

Flyway V22 stages `chapter-1-v6` inactive and leaves the current release
unchanged. Activate it only after every pre-V22 backend has drained. V6 keeps
23 nodes and adds `trace-second-dawn` to `spectrum-observatory-v1`.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v6",
  "releaseNotes": "Первая глава: откалиброванный секстант открывает выбор второго рассвета.",
  "content": {
    "contentVersion": "chapter-1-v6",
    "chapterId": "signal-chapter-1",
    "nodeCount": 23,
    "topology": "calibrated-sextant-choice-v1"
  }
}
```

At `spectrum-observatory-v1`, verify the choice is locked for an unequipped or
level-1 sextant and available only for an equipped level-2/RARE sextant. After
resolution, verify `3 × dawn-fragment` and the rejoin at `horizon-spire`.
Before backend rollback, require zero persisted `trace-second-dawn` results;
otherwise use a forward fix on a v6-capable binary.

## `chapter-1-v7` activation

Flyway V23 stages `chapter-1-v7` inactive and leaves the current release
unchanged. Activate it only after every pre-V23 backend has drained. V7 adds
`open-second-dawn` to `dawn-relay-v1` and one optional node, increasing the
catalog from 23 to 24 nodes.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v7",
  "releaseNotes": "Первая глава: откалиброванный секстант открывает эпилог второго рассвета.",
  "content": {
    "contentVersion": "chapter-1-v7",
    "chapterId": "signal-chapter-1",
    "nodeCount": 24,
    "topology": "second-dawn-epilogue-v1"
  }
}
```

At `dawn-relay-v1`, verify the choice is absent on v6, locked for an
unequipped or level-1 sextant on v7, and available only for an equipped
level-2/RARE sextant. Resolve it and verify `+1 dawn-fragment` plus the handoff
to `second-dawn-threshold`. Both epilogue choices must finish the expedition;
verify `anchor-second-dawn` grants `2 × ion-bloom` and
`leap-beyond-dawn` grants `2 × dawn-fragment`.

Do not roll back to a pre-V23 binary while any user is at
`second-dawn-threshold` or while v7 event results need replay/delivery. Stop
activation and use a forward fix once the new route has persisted user state.

## Second Dawn attunement rollout

Flyway V24 stages `chapter-1-v8` inactive, keeps its 24-node V7 topology and
expands the unique-item invariant to allow `prism-sextant 3/EPIC`. Deploy and
drain every pre-V24 backend before activating v8. The server-owned
`prism-sextant-second-dawn-attunement-v1` definition remains hidden on v1-v7.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v8",
  "releaseNotes": "Первая глава: секстант принимает настройку второго рассвета.",
  "content": {
    "contentVersion": "chapter-1-v8",
    "chapterId": "signal-chapter-1",
    "nodeCount": 24,
    "topology": "second-dawn-attunement-v1"
  }
}
```

After migration, verify that only the supported sextant states exist:

```sql
SELECT version, rarity, count(*)
FROM unique_inventory_item
WHERE item_id = 'prism-sextant'
GROUP BY version, rarity
ORDER BY version, rarity;
```

Allowed pairs are `1/UNCOMMON`, `2/RARE` and `3/EPIC`. Before enabling the
action, verify a level-2 item with all three material stacks projects the
attunement as `READY`; exact replay must return the original level-3 result.
Do not roll back to a pre-V24 binary after a level-3 item or EPIC processed
result has persisted. Disable the action and use a forward fix instead.

## EPIC Sextant uncharted-verge rollout

Flyway V25 stages `chapter-1-v9` inactive and adds one optional node to the
V8 topology. Deploy and drain every pre-V25 backend before activation. The
server-owned `cross-uncharted-verge` choice remains absent on v1-v8.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v9",
  "releaseNotes": "Первая глава: EPIC-секстант открывает неизведанный рубеж за вторым рассветом.",
  "content": {
    "contentVersion": "chapter-1-v9",
    "chapterId": "signal-chapter-1",
    "nodeCount": 25,
    "topology": "epic-sextant-uncharted-verge-v1"
  }
}
```

Before activation, confirm that a level-2 equipped sextant projects
`cross-uncharted-verge` as locked with `minimumUpgradeLevel: 3`, while a
level-3 item projects it as available. Resolve the route and verify the next
node is `uncharted-verge`; both of its choices must complete the expedition,
and exact replay must not duplicate XP, bond or materials.

Do not roll back to a pre-V25 binary while any user is at `uncharted-verge`
or while v9 route results need replay/delivery. Stop activation and use a
forward fix after the new route has persisted user state.

## Pet-guided uncharted-verge rollout

Flyway V26 stages `chapter-1-v10` inactive without changing the 25-node v9
topology. Deploy and drain every pre-V26 backend before activation. V1-v9 do
not expose the three new pet-specific choice IDs.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v10",
  "releaseNotes": "Первая глава: активный питомец открывает собственный исход на неизведанном рубеже.",
  "content": {
    "contentVersion": "chapter-1-v10",
    "chapterId": "signal-chapter-1",
    "nodeCount": 25,
    "topology": "pet-guided-uncharted-outcomes-v1"
  }
}
```

Before activation, select each of `spark-v1`, `moss-v1` and `rune-v1` on a
test account at `uncharted-verge`. Home must expose exactly that pet's choice
as available and the other two as `ACTIVE_PET` locks. Resolve one outcome and
verify the matching pet receives bond, the expected material is credited once,
the expedition completes and exact replay is immutable.

Do not roll back to a pre-V26 binary after v10 choices have persisted. Stop
activation and forward-fix; a pre-V26 instance cannot replay those choice IDs.

## Adult starter-pet evolution rollout

Flyway V27 stages `chapter-1-v11` inactive without changing the 25-node v10
topology. Deploy and drain every pre-V27 backend before activation. V1-v10 cap
pet evolution at stage `1`; v11 enables the server-authoritative `1 → 2`
transition.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v11",
  "releaseNotes": "Первая глава: Искра, Мох и Руна открывают взрослую форму через второй порог связи.",
  "content": {
    "contentVersion": "chapter-1-v11",
    "chapterId": "signal-chapter-1",
    "nodeCount": 25,
    "topology": "adult-starter-pet-evolution-v1"
  }
}
```

Before activation, verify that a stage-1 Spark at bond `139` receives
`requiredBond=140` without mutation, while bond `140` produces stage `2`,
level increment, the adult name and the matching `pet_progress` synchronization.
Repeat for Moss at `125` and Rune at `150`; exact replay must return the saved
response without another level increment.

Do not roll back to a pre-V27 binary after any stage-2 state has persisted.
Stop activation and forward-fix; an older binary cannot correctly project or
enforce the adult-form maximum.

## Adult-pet frontier route rollout

Flyway V28 stages `chapter-1-v12` inactive and adds one content node without
changing active v11 or existing pet/expedition state. Deploy and drain every
pre-V28 backend before activation. V1-v11 do not expose the new route choice
IDs or `constellation-sanctuary-v1`.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v12",
  "releaseNotes": "Первая глава: взрослый активный питомец открывает путь в Святилище созвездий.",
  "content": {
    "contentVersion": "chapter-1-v12",
    "chapterId": "signal-chapter-1",
    "nodeCount": 26,
    "topology": "adult-pet-frontier-route-v1"
  }
}
```

Before activation, place a stage-1 and stage-2 copy of each starter pet at
`uncharted-verge`. Home must keep all adult routes locked for stage 1. At stage
2 it must expose exactly the route of the active pet, with the other two
remaining `ACTIVE_PET` locks and `minimumEvolutionStage=2`. Direct stage-1
resolution must leave progression, inventory and expedition rows unchanged.
Resolve the available route, verify the transition to
`constellation-sanctuary`, acknowledge the result, then complete either final
choice and replay both commands without duplicate rewards.

Do not roll back to a pre-V28 binary after a v12 route result or sanctuary
state has persisted. Stop activation, return the active release to v11 for new
journeys if safe, and forward-fix binaries that must read the new node and
choice IDs.

## Signal Reader sanctuary outcome rollout

Flyway V29 stages `chapter-1-v13` inactive without changing the 26-node v12
topology, active v12 or existing platform/pet/expedition state. Deploy and
drain every pre-V29 backend before activation. V1-v12 neither expose nor
accept `decode-sanctuary-signal`.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v13",
  "releaseNotes": "Первая глава: навык «Чтение сигналов» открывает скрытый исход Святилища созвездий.",
  "content": {
    "contentVersion": "chapter-1-v13",
    "chapterId": "signal-chapter-1",
    "nodeCount": 26,
    "topology": "signal-reader-sanctuary-choice-v1"
  }
}
```

Before activation, place otherwise identical users with and without
`signal-reader` at `constellation-sanctuary-v1`. Home must return the new
choice as `LOCKED/UNLOCKED_SKILL` for the latter and `AVAILABLE` for the
former. A direct locked resolution must leave progression, inventory and
expedition rows unchanged. Resolve the available choice, acknowledge its
result and replay the command without duplicate rewards.

Do not roll back to a pre-V29 binary while v13 is active: old instances do not
know the choice ID. Return the active release to v12, drain v13 traffic, and
forward-fix any persisted v13 result or state that an older binary cannot read.

## Signal Reader secret route rollout

Flyway V30 stages `chapter-1-v14` inactive with a 27th node,
`hidden-signal-observatory`, without changing active v13 or existing
platform/pet/expedition state. Deploy and drain every pre-V30 backend before
activation. V1-v13 retain terminal `decode-sanctuary-signal` semantics and
cannot start the new route.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v14",
  "releaseNotes": "Первая глава: Чтение сигналов открывает Обсерваторию скрытого сигнала.",
  "content": {
    "contentVersion": "chapter-1-v14",
    "chapterId": "signal-chapter-1",
    "nodeCount": 27,
    "topology": "signal-reader-secret-route-v1"
  }
}
```

Before activation, complete `decode-sanctuary-signal` once under v13 and
verify terminal completion. Activate v14, repeat with another eligible user,
verify the transition to `hidden-signal-observatory`, then complete and replay
each terminal choice without duplicate rewards.

A content rollback from v14 to v13 prevents new secret-route transitions but
keeps the new event definitions readable so an already persisted observatory
state can finish. Do not roll back to a pre-V30 binary after such a state has
persisted: return content to v13 for new journeys, drain v14 traffic, and
forward-fix binaries that must read the 27th node.

## Trail Memory secret route rollout

Flyway V31 stages `chapter-1-v15` inactive with a 28th node,
`memory-constellation`, without changing active v14 or existing
platform/pet/expedition state. Deploy and drain every pre-V31 backend before
activation. V1-v14 retain the two terminal observatory outcomes and cannot
accept `reconstruct-forgotten-route`.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v15",
  "releaseNotes": "Первая глава: «Память маршрута» восстанавливает путь к Созвездию памяти.",
  "content": {
    "contentVersion": "chapter-1-v15",
    "chapterId": "signal-chapter-1",
    "nodeCount": 28,
    "topology": "trail-memory-secret-route-v1"
  }
}
```

Before activation, verify that v14 users at the observatory see only two
terminal outcomes. Activate v15 and compare otherwise identical users with
and without `trail-memory`: Home must project the new route as AVAILABLE and
LOCKED/UNLOCKED_SKILL respectively. Resolve the available route, complete
both memory-constellation outcomes in separate journeys and replay commands
without duplicate rewards.

A content rollback from v15 to v14 blocks new memory-route transitions but
keeps an already persisted `memory-constellation` state completable. Do not
roll back to a pre-V31 binary after such a state has persisted; return content
to v14 for new journeys and forward-fix binaries that must read the 28th node.

## Energy Discipline Dawn Meridian rollout

Flyway V32 stages `chapter-1-v16` inactive with a 29th node,
`dawn-meridian`, without changing active v15 or existing
platform/pet/expedition state. Deploy and drain every pre-V32 backend before
activation. V1-v15 retain the two terminal Memory Constellation outcomes and
cannot accept `stabilize-dawn-current`.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v16",
  "releaseNotes": "Первая глава: «Дисциплина энергии» стабилизирует путь к Меридиану рассвета.",
  "content": {
    "contentVersion": "chapter-1-v16",
    "chapterId": "signal-chapter-1",
    "nodeCount": 29,
    "topology": "energy-discipline-dawn-meridian-v1"
  }
}
```

Before activation, verify that v15 users at `memory-constellation` see only
two terminal outcomes. Activate v16 and compare otherwise identical users
with and without `energy-discipline`: Home must project the new route as
AVAILABLE and LOCKED/UNLOCKED_SKILL respectively. Resolve the available route,
complete both `dawn-meridian` outcomes in separate journeys and replay
commands without duplicate rewards.

A content rollback from v16 to v15 blocks new Dawn Meridian transitions but
keeps an already persisted `dawn-meridian` state completable. Do not roll back
to a pre-V32 binary after such a state has persisted; return content to v15 for
new journeys and forward-fix binaries that must read the 29th node.

## Steady Step First-Light Causeway rollout

Flyway V33 stages `chapter-1-v17` inactive with a 30th node,
`first-light-causeway`, without changing active v16 or existing
platform/pet/expedition state. Deploy and drain every pre-V33 backend before
activation. V1-v16 retain the two terminal Dawn Meridian outcomes and cannot
accept `cross-first-light-causeway`.

Publish the exact staged payload:

```json
{
  "contentVersion": "chapter-1-v17",
  "releaseNotes": "Первая глава: «Ровный шаг» открывает Переход первого света.",
  "content": {
    "contentVersion": "chapter-1-v17",
    "chapterId": "signal-chapter-1",
    "nodeCount": 30,
    "topology": "steady-step-first-light-causeway-v1"
  }
}
```

Before activation, verify that v16 users at `dawn-meridian` see only two
terminal outcomes. Activate v17 and compare otherwise identical users with and
without `steady-step`: Home must project the new route as AVAILABLE and
LOCKED/UNLOCKED_SKILL respectively. Resolve the available route, complete both
`first-light-causeway` outcomes in separate journeys and replay commands
without duplicate rewards.

A content rollback from v17 to v16 blocks new First-Light Causeway transitions
but keeps an already persisted `first-light-causeway` state completable. Do not
roll back to a pre-V33 binary after such a state has persisted; return content
to v16 for new journeys and forward-fix binaries that must read the 30th node.

## Repeatable expedition journey rollout

Flyway V34 creates `expedition_journey_cycle`, backfills every existing
expedition as journey 1, adds immutable journey-start receipts and changes
event uniqueness from once per account expedition to once per journey. It does
not change route state, active content, ENERGY, pilot/pet progression, skills,
inventory or equipment.

Deploy V34-capable binaries and drain every pre-V34 backend before allowing a
player to start journey 2. A pre-V34 event writer always stores the compatibility
default `journey_number=1`; after a cycle advances, such a writer could assign a
new event to the wrong journey. No separate content publication or remote-config
activation is required.

Before enabling traffic, verify:

1. Flyway reports V34 and `expedition_journey_cycle` has one row for every
   existing `expedition_progress` row;
2. no pre-V34 application instance remains in the pool;
3. a completed synthetic account starts journey 2 exactly once, returns to
   `outer-beacon`, keeps its permanent progression and spends ENERGY only on
   the following advance;
4. replay of the start key returns the same receipt and a stale new key returns
   `EXPEDITION_JOURNEY_STATE_CONFLICT`;
5. the same event can resolve in journey 2, while duplicate resolution inside
   that journey is still rejected.

After any `journey_number > 1` or journey-start receipt exists, rollback to a
pre-V34 binary is prohibited. Stop rollout expansion and forward-fix a V34+
binary; content rollback remains available and does not reset the cycle.

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
