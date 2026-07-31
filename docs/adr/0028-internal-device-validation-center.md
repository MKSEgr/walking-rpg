# ADR 0028: internal physical-device Validation Center

- Status: Accepted
- Date: 2026-07-31

## Context

HealthKit and Health Connect behavior cannot be validated honestly by unit
tests, an Android emulator or an iOS Simulator. The release gate requires
dated evidence from physical iPhone and Android devices, including provider,
permission, lifecycle and authoritative backend outcomes.

Ad-hoc screenshots and console logs are weak evidence. They are difficult to
tie to an exact source revision, omit intermediate checkpoints and commonly
contain account identifiers, tokens, endpoints, local paths or raw provider
data. A production diagnostics surface would create a different risk: it could
retain health-adjacent data on normal user devices or make an internal tool
reachable in a store build.

The repository therefore needs a small internal evidence mechanism without
changing the external validation gate or treating generated JSON as proof that
any physical-device scenario was actually executed.

## Decision

### Internal-only boundary

The mobile application provides a `ValidationCenterScreen` only when the
compile-time flag `ENABLE_VALIDATION_CENTER=true` is set in a non-release
build. The flag defaults to `false`.

When the flag is requested, startup validation requires:

- `VALIDATION_SOURCE_GIT_SHA`: the exact 40-character lowercase Git commit
  SHA used for the build.

Application version and build number come from the installed native package
through `PackageInfo`. Independent dart-defines are deliberately not accepted
for these fields, so evidence cannot claim a build number different from the
binary being exercised.

An enabled center in `kReleaseMode`, an invalid SHA or invalid build metadata
fails closed. It is not enough merely to hide a route or button in release UI.

### Per-launch journal

The center owns an in-memory journal for one authenticated owner and one auth
session revision within an application launch. It is not written to
preferences, application support storage, command outbox, read cache or
backend. The live owner and session revision are checked again after every
asynchronous boundary. Logout, a new session, owner change, controller disposal
or process termination destroys the journal; entries from different owners or
sessions must never be merged.

The journal records only coarse, ordered scenarios needed by the physical
protocol:

- provider availability/selection;
- permission result;
- aggregated daily-total read result;
- sync result;
- authoritative reload/checkpoint result.

Each journal entry has only `sequence`, `scenario`, `outcome`, `startedAtUtc`,
`durationMs` and a nullable coarse `errorCategory`. Durations use a monotonic
clock so wall-clock, timezone and NTP changes cannot alter them. Typed details
live in the separate `latestHealth`, `latestSync` and
`authoritativeCheckpoint` snapshots;
the journal is not a free-form logging map. A permission state of
`request_succeeded` means the platform request completed, not that HealthKit
proved read authorization.

The whole launch is bounded to 64 entries and the schema-v1 export is bounded
to 64 KiB. Normal actions may consume at most the first 63 slots so a terminal
blocked `journal_limit_reached` entry can remain visible when the next complete
action no longer fits; further actions then stop. A multi-entry action may leave
unused capacity rather than be partially recorded. The exporter must not
silently produce apparently complete evidence.

Schema verification preserves the same causal model: journal timestamps are
nondecreasing; every known Health action forms a contiguous
`provider → permission → read` group; each successful sync uses the latest
preceding successful read group; and typed observations bind to the latest
corresponding journal entry. Authoritative activity/event facts must reproduce
the first-journey milestone derivation. `energyGranted` must equal the number
of crossed 100-step thresholds. A `journal_limit_reached` marker is unique,
terminal and capacity-derived, and a 64-entry journal without that marker is
rejected.

### Evidence envelope and integrity

The export uses schema
`walking-rpg-device-validation-evidence-v1` and redaction policy
`walking-rpg-evidence-redaction-v1`. It contains:

- export/update time and per-launch start time in UTC;
- platform, OS, build/auth mode and Health source category;
- application version/build number and exact source Git SHA;
- latest typed Health read, sync and authoritative reload observations;
- the bounded ordered scenario journal;
- a `checksum` object with a SHA-256 digest of the deterministic UTF-8 evidence
  payload, excluding the checksum field itself.

The checksum payload is compact `jsonEncode` of the first nine top-level
members in schema-defined insertion order: `schemaVersion`, `redactionPolicy`,
`exportedAtUtc`, `updatedAtUtc`, `launch`, `latestHealth`, `latestSync`,
`authoritativeCheckpoint` and `journal`. The `checksum` object is appended
last. The verifier first requires this exact compact canonical envelope, so
pretty-printing or reordering is rejected before digest comparison.

The checksum detects accidental mutation between export and review. It is not
a signature, device attestation or proof of tester identity.

Before encoding, values pass an allowlist redaction policy. The journal and
export must not contain:

- raw HealthKit/Health Connect samples or timestamps of individual samples;
- access, refresh or ID tokens, authorization headers or cookies;
- user, account, subject, device, installation, command, idempotency,
  diagnostic or crash identifiers;
- endpoint hosts/URLs, request/response bodies, local filesystem paths or raw
  exception text;
- provider record/source identifiers or free-form tester notes.

Aggregated totals and server-returned numeric outcomes are allowed only in the
typed fields defined by schema v1. Unknown keys and free-form diagnostic maps
are rejected rather than copied into evidence.

### Temporary share lifecycle

Export is explicit. The app creates one temporary JSON file, invokes the
platform share sheet, and attempts deletion in a `finally` path after the share
operation returns or fails. The file is not a durable journal or an automatic
upload. A reviewer verifies schema, source SHA, redaction policy and checksum
before attaching the JSON to the manual evidence template.

Deletion of the temporary file reduces retention but cannot revoke a copy the
tester deliberately shared into another application. The protocol therefore
requires a redaction review before distribution.

### Validation status

Implementation and automated tests for the center are `CODE_COMPLETE` when CI
passes. Physical Health, permission, provider, midnight/timezone, lifecycle and
battery scenarios remain `EXTERNAL_VALIDATION_REQUIRED` until dated evidence
from the required device matrix is reviewed. Neither an empty export nor a
synthetic/emulator run may be labeled `VALIDATED`.

## Consequences

- A device run can be tied to exact application and source metadata without
  retaining secrets or owner identifiers.
- Permission, read, sync and authoritative reload can be reviewed as one
  ordered launch rather than reconstructed from screenshots.
- Evidence is deliberately ephemeral and bounded; testers must export it
  before ending the authenticated launch.
- SHA-256 protects transport integrity but provides no authenticity guarantee.
- Physical devices, configured providers, tester actions and human evidence
  review remain unavoidable external work.

## Rejected alternatives

### Persist the journal between launches

Rejected because it broadens health-adjacent retention, complicates owner
separation and can combine checkpoints from different builds or sessions.

### Upload evidence automatically

Rejected because issue 46 does not establish an evidence backend, retention
policy, access control or consent boundary. Schema-v1 export is tester-initiated
and local.

### Export application logs or arbitrary diagnostic maps

Rejected because logs and free-form maps can contain identifiers, endpoints,
paths, exception text and raw provider details that the evidence does not need.

### Enable the center in production behind navigation obscurity

Rejected because a hidden route is not a build boundary. The explicit flag,
non-release check and startup metadata validation are all required.

### Treat checksum success as device validation

Rejected because a digest proves only that bytes were not accidentally changed
after deterministic schema-v1 export. It does not prove device identity,
execution of the scenario or correctness of the recorded observation.
