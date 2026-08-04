# ADR 0033 — Canonical platform command fingerprints

- Status: Accepted
- Date: 2026-08-04

## Context

`processed_roadmap_command` prevents a platform command from being applied
twice by storing a SHA-256 request fingerprint with its immutable response.
The previous serializer sorted the outer envelope but passed the nested
`payload` map to Jackson unchanged.

JSON object member order has no business meaning. In addition,
`PlatformCommandRequest` uses `Map.copyOf`, whose iteration order is not
specified and may differ between JVM processes. A two-field command such as
`RECORD_COMPASS_IMPRESSION` or `RECORD_EXPERIMENT_EXPOSURE` could therefore
produce a different fingerprint after restart or on another backend instance
and return a false `409 IDEMPOTENCY_CONFLICT` for the same payload.

The canonical path also used Spring's shared API `ObjectMapper`. A response-only
serializer change such as enabling indentation therefore changed the persistent
hash of an otherwise identical request after deployment.

## Decision

- Fingerprints recursively sort every JSON object key before serialization.
- New canonical hashes use a dedicated immutable writer with indentation
  disabled instead of inheriting API mapper configuration.
- JSON array order, scalar value and scalar type remain significant.
- The canonical command alias is still selected before hashing, so
  `BUY_COSMETIC`/`PURCHASE_COSMETIC` compatibility is unchanged.
- New `processed_roadmap_command` rows keep the existing schema and store the
  canonical SHA-256 in `request_fingerprint`; raw payload is not persisted.
- Replay also recognizes both historical top-level orders for the declared
  two-field platform payloads. Zero- and one-field payloads already have one
  possible legacy encoding. The fallback is bounded and never permutes an
  arbitrary attacker-sized map.
- Replay-only compatibility candidates also retain the immediately preceding
  shared API mapper encoding and the known compact/indented formatting variants.
  At most canonical, observed and reversed two-field encodings are evaluated
  per writer; none of these candidates is persisted for a new command.
- A hash mismatch after canonical and bounded legacy comparison remains a
  fail-closed idempotency conflict before state, event or provider mutation.

## Consequences

Exact replay is stable across backend restarts, instances and JSON object-key
reordering, including when API response formatting changes. The dedicated
writer preserves the previous default compact byte encoding. Bounded
replay-only candidates also keep rows written by the preceding shared mapper,
including pretty-printed hashes, replayable across the upgrade without a data
migration. No health, telemetry or command payload is added to persistent
storage.

During a mixed-binary rollout, an old instance still has the defect described
above and may reject a canonical row written by a new instance. This is not a
new failure mode, but the guarantee becomes complete only after all backend
instances run this decision. Deployment should drain the old command-serving
instances before relying on cross-instance replay as a release gate.

## Revisit when

- a declared platform command needs more than two top-level payload fields and
  historical pre-canonical rows must be supported;
- JSON numeric normalization becomes part of the business-payload contract;
- fingerprints move to an explicit versioned database column.
