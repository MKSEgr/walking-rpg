# `alpha-rc1` release dossier

[Русский перевод](alpha-rc1-release-dossier.ru.md)

This dossier pins the first validation-programme baseline to one immutable
post-bootstrap `master` commit and its integrated push checks. It is an
engineering candidate record, not production-signing, device, stage or store
evidence.

## Decision record

| Field | Value |
|---|---|
| Candidate | `alpha-rc1` |
| Source commit | [`8d2b859b2f9b6a85530601eec45b3ccee612aaba`](https://github.com/MKSEgr/walking-rpg/commit/8d2b859b2f9b6a85530601eec45b3ccee612aaba) |
| Git tree | `979e7299f62be8cdb4af1e62b5b80f4615043acc` |
| Source timestamp | `2026-08-07T13:05:09Z` |
| Evidence verified | `2026-08-07` |
| Evidence recorder | Codex execution of [TASK-001 / issue #147](https://github.com/MKSEgr/walking-rpg/issues/147) |
| Decision authority | Repository maintainer accepting TASK-001 through manual merge |

`alpha-rc1` means exactly the commit and tree above. The decision record takes
effect when the TASK-001 PR is merged; until then issue #147 remains open. The
label must never be silently moved to another SHA. A successor source commit
requires a new candidate decision and a complete dossier from that commit's
own integrated checks.

The selected commit is the squash merge of
[`[TASK-000] Bootstrap the validation programme`](https://github.com/MKSEgr/walking-rpg/pull/163).
It is the first post-W0.1 `master` state, and legacy autonomous-scope issues
[#26](https://github.com/MKSEgr/walking-rpg/issues/26) and
[#29](https://github.com/MKSEgr/walking-rpg/issues/29) are closed.

## Integrated push gates

Both required workflows were triggered by the same `push` to `master`; each
reports the exact source commit above and completed successfully.

| Gate | Run | Started | Completed | Result |
|---|---|---|---|---|
| Standard CI | [`CI #580` / run `31181017936`](https://github.com/MKSEgr/walking-rpg/actions/runs/31181017936) | `2026-08-07T13:05:13Z` | `2026-08-07T13:10:22Z` | `success` |
| Release packaging and policy | [`Release quality #461` / run `31181017679`](https://github.com/MKSEgr/walking-rpg/actions/runs/31181017679) | `2026-08-07T13:05:13Z` | `2026-08-07T13:14:01Z` | `success` |

Successful Standard CI jobs:

- repository structure;
- backend Java 21 compile, test compile, unit/API and PostgreSQL
  integration/migration tests;
- Flutter 3.44.7 format, analyze and tests;
- Android host debug APK;
- iOS host simulator debug build.

Successful Release quality jobs:

- release policy and deterministic metadata;
- executable backend package;
- sanitized synthetic PostgreSQL backup/restore drill;
- Android unsigned AAB;
- iOS no-codesign application archive.

## Retained artifacts and digests

All artifacts below belong to Release quality run `31181017679`, report
`head_sha=8d2b859b2f9b6a85530601eec45b3ccee612aaba`, and were retained by GitHub
Actions for 14 days. The artifact digest is the SHA-256 of the downloaded
artifact ZIP reported by GitHub; the payload digest is read from the retained
checksum file and was independently recalculated after download.

| Artifact | ID | GitHub artifact SHA-256 | Payload and verified SHA-256 |
|---|---:|---|---|
| `release-build-metadata` | `8994762914` | `f7751f8d844ffee32a5bb7e59d349b5274f5ed15cd3e7edf687c5544fa7dd797` | `build-metadata.json`: `2fce13c5dc2292da73ff2b3e8445a7e3361e616d2ed0a024be04a9fb527b3589` |
| `backend-release-candidate` | `8994764977` | `e5e20b34de151cd4935c0de10eb13e19e7ebf3d630438c64c8f465e29ddab2e4` | `walking-rpg-backend-0.1.0-SNAPSHOT.jar`: `ae43eff739e3527c4b625f466886208c96c0793b0923c5a2d3757f145b83a4d1` |
| `synthetic-backup-restore-evidence` | `8994781320` | `f221257f115c2db2e05df1aedde749271cd6968b9542b505f6d7a22a99da9fa4` | `evidence.json`: `ba67ad54c158c5af2c229bb1b1c74c136e727d9e3d25fac27f05e9edbab7fc54` |
| `android-unsigned-release-aab` | `8995010209` | `dc41c081573b4cfb0a35b654f63a36c547f9cb9b2979a6aa81f25e420c13e1e2` | `app-release.aab`: `c9b75c62bd2f90720dfba9ed7a3f7a0c9a529abff23c68b97dbc8c66a565a02b` |
| `ios-no-codesign-release-app` | `8994878378` | `3ea353140910a822f1786e118c62ef58998b0b1b593093af8c1d6a3f5db7ed15` | `WalkingRPG-no-codesign.zip`: `84753b025f3fe9bf805f20eeaab509b9c23f8a3640e297e1d649bfa81a5027dc` |

The successful CI run retained no diagnostics artifacts because its upload
steps are failure-only.

### Build metadata

The retained schema-v2 metadata was independently regenerated from the pinned
checkout and matched byte-for-byte.

| Field | Value |
|---|---|
| Application | `0.1.0+1` |
| Source commit / tree | `8d2b859b2f9b6a85530601eec45b3ccee612aaba` / `979e7299f62be8cdb4af1e62b5b80f4615043acc` |
| Flutter / Java | `3.44.7` / `21` |
| Flyway latest version | `17` |
| Active content version | `chapter-1-v1` |
| Android | `com.walkingrpg.walking_rpg_mobile`; compile/target/min SDK `36/36/26` |
| iOS | `com.walkingrpg.walkingRpgMobile`; deployment target `14.0` |
| Signing declaration | Android and iOS: `external-protected-environment` |

### Synthetic restore evidence

The retained restore receipt is explicitly
`scope=SYNTHETIC_CI`, `productionValidated=false` and
`actualProductionDrillRequired=true`. It records PostgreSQL `17.10`, Flyway
version `17`, all 33 application tables covered by fixtures, and exact matching
source/restored manifests:

- schema: `26b728b6d926e18fcc04ccba90dfc21838a721c976ac025326af67a8d5b2c411`;
- data: `2fe09f8796ae05c737250b282e612cec76ccf88d39e8ba1cdce4840a53c751fd`;
- sequences: `e0ca1b16b11db35b90e3eccba877939e6d59efa4f489b759098410001a3f2110`.

The synthetic database dump was intentionally not retained. This receipt does
not satisfy the real-backup restore gate.

## Verification performed

- exact `master` SHA was resolved independently through GitHub and
  `git ls-remote`;
- Git tree was resolved from the pinned commit and matched retained build
  metadata;
- both push workflow conclusions and every job conclusion were checked on the
  exact SHA;
- all five release artifacts were downloaded through GitHub and their artifact
  ZIP SHA-256 values matched GitHub provenance;
- all retained payload checksum files matched independently calculated
  SHA-256 values;
- build metadata was regenerated with
  `scripts/generate-build-metadata.sh` from the pinned checkout and compared
  byte-for-byte;
- the synthetic restore receipt checksum and its explicit non-production scope
  were verified.

No credential, signing material, token, raw health/identity data or PII is
stored in this dossier.

## Feature freeze after the baseline

`alpha-rc1` is immutable. Work after this baseline is limited to:

1. release blockers that affect safety, economy, data integrity, mandatory
   launch flows or rollback;
2. physical-device fixes backed by reproducible redacted evidence;
3. production wiring/configuration required by the E2, E3 and E7 gates while
   preserving fail-closed defaults;
4. evidence-driven fixes with a linked defect, affected scenario and rerun.

Gameplay expansion, broad design changes and speculative platform work remain
outside the freeze. Any permitted source change creates a successor candidate;
it does not mutate or re-label `alpha-rc1`.

## External blockers and non-claims

This dossier proves only a reproducible code-complete engineering baseline.
It does **not** claim that:

- Android or iOS artifacts are production-signed or installable distribution
  candidates;
- HealthKit/Health Connect or account lifecycle scenarios passed on physical
  devices;
- a production-like stage, real OIDC provider, TLS database, monitoring or
  real-backup restore exists;
- developer accounts, public URLs, store declarations, submission or review
  gates are complete;
- product value, usability, retention or closed-beta thresholds are validated.

Those gates remain owned by their linked tasks in
[`VALIDATION_BACKLOG.md`](../VALIDATION_BACKLOG.md).

## Stop and rollback

Before merge, closing the TASK-001 PR leaves no effective `alpha-rc1`
decision. After merge, any provenance mismatch or invalidated integrated gate
must create a release-blocker issue and mark this dossier revoked in a new PR.
Never edit this record to point `alpha-rc1` at another SHA; create and validate
a successor candidate instead.

## Acceptance evidence

- [x] One exact SHA/tree is the only `alpha-rc1` baseline.
- [x] Standard CI and Release quality push runs are green on that same SHA.
- [x] Artifact names, IDs, available digests and build metadata are recorded
  without secrets.
- [x] Release documentation and the changelog link to this dossier.
- [x] TASK-001 changes are limited to release/evidence documentation.
