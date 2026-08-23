# `alpha-rc2` release dossier

[Русский перевод](alpha-rc2-release-dossier.ru.md)

This dossier pins the post-roadmap validation baseline to an accepted source
tree, its post-merge `master` approval anchor, exact automated gates and
verified release artifacts. It is an engineering candidate record, not
production-signing, physical-device, stage, store or product-value evidence.

## Decision record

| Field | Value |
|---|---|
| Candidate | `alpha-rc2` |
| Post-merge `master` anchor | [`70520cdc57bd0f1f8cafd7205ce1903afa19c5a9`](https://github.com/MKSEgr/walking-rpg/commit/70520cdc57bd0f1f8cafd7205ce1903afa19c5a9) |
| Artifact-producing source | [`3e5a1623bd2f53a9fe5eeb17d822431cf7b29b23`](https://github.com/MKSEgr/walking-rpg/commit/3e5a1623bd2f53a9fe5eeb17d822431cf7b29b23) |
| Exact content tree | `09a809cc126c24b8abf5214f60d527958bc71a03` |
| Accepted change | [PR #467](https://github.com/MKSEgr/walking-rpg/pull/467), forward delivery roadmap |
| Artifact source timestamp | `2026-08-23T20:27:18Z` |
| Merge anchor timestamp | `2026-08-23T20:44:56Z` |
| Evidence verified | `2026-08-23` |
| Evidence recorder | Codex execution of [F0 issue #468](https://github.com/MKSEgr/walking-rpg/issues/468) |
| Decision authority | Repository maintainer accepting issue #468 through manual merge |

PR #467 was squash-merged. The merge changes commit identity while preserving
the accepted tree byte-for-byte: both the PR source and the protected
post-merge `master` anchor resolve to
`09a809cc126c24b8abf5214f60d527958bc71a03`. Release artifacts record the PR
source commit and that exact tree; the merge commit records approval and
integration of the same content.

`alpha-rc2` means the complete tuple above, not only a branch name or movable
label. The decision takes effect when the issue #468 PR is merged. The record
must never be edited to point to another source, anchor or tree. A successor
requires a new candidate and its own evidence.

## Exact automated gates

All gates below ran against artifact-producing source
`3e5a1623bd2f53a9fe5eeb17d822431cf7b29b23` before PR #467 was accepted.
Every job completed successfully.

| Gate | Run | Started | Completed | Result |
|---|---|---|---|---|
| Standard CI | [CI #1083 / run `32664456691`](https://github.com/MKSEgr/walking-rpg/actions/runs/32664456691) | `2026-08-23T20:27:23Z` | `2026-08-23T20:31:51Z` | `success` |
| Release quality | [Release quality #964 / run `32664456649`](https://github.com/MKSEgr/walking-rpg/actions/runs/32664456649) | `2026-08-23T20:27:23Z` | `2026-08-23T20:35:34Z` | `success` |
| Release finalizer | [Finalizer #693 / run `32664456635`](https://github.com/MKSEgr/walking-rpg/actions/runs/32664456635) | `2026-08-23T20:27:23Z` | `2026-08-23T20:35:41Z` | `success` |

Standard CI covered repository/Auth0 contracts, Java 21 compilation, unit/API
tests, PostgreSQL integration and migration tests, Flutter formatting,
analysis and tests, Android debug host build and iOS simulator host build.

Release quality covered policy/build metadata, executable backend packaging and
protected container validation, synthetic PostgreSQL backup/restore, Android
unsigned AAB and iOS no-codesign archive.

## Retained artifacts and verified digests

All artifacts belong to Release quality run `32664456649`, report
`head_sha=3e5a1623bd2f53a9fe5eeb17d822431cf7b29b23`, and expire on
`2026-09-06`. The archive digest is GitHub's SHA-256 of the downloaded ZIP.
Each ZIP was downloaded again during issue #468 execution; its SHA-256 matched
GitHub, and every payload checksum was independently recalculated.

| Artifact | ID | Archive SHA-256 | Payload and verified SHA-256 |
|---|---:|---|---|
| `release-build-metadata` | `9499622733` | `3d59024fbb629d6f1afef116da45ec5ba3b935007e4d616aed9702febbe7fdae` | `build-metadata.json`: `62467b575b336a5a7712d8fbadfeea10086cf911a1062fc4eb9b90270eaa46fe` |
| `backend-release-candidate` | `9499636180` | `731813a9a710ef1b38493ffbe702b464695874fa1f861560c7413f8d8ff72e7b` | `walking-rpg-backend-0.1.0-SNAPSHOT.jar`: `385478abf8949da2c2fcbe74066f3ccdb9952f90a017733d2ca47edec9085c65` |
| `synthetic-backup-restore-evidence` | `9499624257` | `32799d6e9b75e3818739f17e7b3511580d0d735f38bf2af54e160ebe9e181543` | `evidence.json`: `d8eaad08565d8516d7b47f7c5d961878ff5d8411af07b7d5a3f8658d1706789e` |
| `android-unsigned-release-aab` | `9499726494` | `05187e6a45b624785010bc6579f84deb86a5520efd4014eb525fbcae163d37da` | `app-release.aab`: `6d729dce28cf0926f391f01f5311b3154cab2987ec5ca8335e7872f21bacb356` |
| `ios-no-codesign-release-app` | `9499654080` | `02586b0927fb0952cdbcf35d923f84e31eb732a29a4a110db7a6a3ba9a619017` | `WalkingRPG-no-codesign.zip`: `32794aeda409c6b8b4863c1ab9372651b4707ac2c85f937bcff209dc7eca7ed7` |

## Build metadata

The retained schema-v2 build metadata records:

| Field | Value |
|---|---|
| Application | `0.1.0+1` |
| Source / tree | `3e5a1623bd2f53a9fe5eeb17d822431cf7b29b23` / `09a809cc126c24b8abf5214f60d527958bc71a03` |
| Flutter / Java | `3.44.7` / `21.0.12+8.0.LTS` |
| Flyway latest version | `34` |
| Active content version | `chapter-1-v1` |
| Android | `com.walkingrpg.walking_rpg_mobile`; compile/target/min SDK `36/36/26` |
| iOS | `com.walkingrpg.walkingRpgMobile`; deployment target `14.0` |
| Signing declaration | Android and iOS: `external-protected-environment` |

## Synthetic restore evidence

The retained receipt is explicitly `scope=SYNTHETIC_CI`,
`productionValidated=false` and `actualProductionDrillRequired=true`. It
records PostgreSQL `17.10`, Flyway `34`, 37 fixture-covered application
tables and exact source/restored matches:

- schema: `6c758caad9225115660eb0a47a68c2bc61ca29f1326f66c711dd9cd51fef680e`;
- data: `03cba3a8337ab1c8d954a7d10ead099946a0ab7e95fc8186e6bc8b4e6b5148e9`;
- sequences: `e0ca1b16b11db35b90e3eccba877939e6d59efa4f489b759098410001a3f2110`.

The synthetic database dump was intentionally not retained. This receipt does
not satisfy issue #154 or any real-backup restore gate.

## F0 freeze and ownership handoff

The code-only baseline is frozen. New source work before internal alpha is
limited to a reproducible release blocker, an evidence-tooling gap, protected
configuration wiring or a fix backed by physical/alpha evidence.

| Workstream | Linked tasks | Required external owner/action | Status |
|---|---|---|---|
| Physical activity | [#149](https://github.com/MKSEgr/walking-rpg/issues/149), [#21](https://github.com/MKSEgr/walking-rpg/issues/21) | device matrix owner and physical iOS/Android/Watch/provider access | `OWNER_ACTION_REQUIRED` |
| Identity | [#153](https://github.com/MKSEgr/walking-rpg/issues/153), [#175](https://github.com/MKSEgr/walking-rpg/issues/175) | Auth0/Telegram owner, tenant, bot and protected credentials | `OWNER_ACTION_REQUIRED` |
| Stage and recovery | [#151](https://github.com/MKSEgr/walking-rpg/issues/151), [#154](https://github.com/MKSEgr/walking-rpg/issues/154), [#155](https://github.com/MKSEgr/walking-rpg/issues/155) | infrastructure/incident owner, approved budget and protected environment | `OWNER_ACTION_REQUIRED` |
| Product/visual | [#156](https://github.com/MKSEgr/walking-rpg/issues/156) | product owner approval of first-world/pet direction | `PRODUCT_DECISION_REQUIRED` |
| Internal alpha | [#157](https://github.com/MKSEgr/walking-rpg/issues/157), [#161](https://github.com/MKSEgr/walking-rpg/issues/161), [#162](https://github.com/MKSEgr/walking-rpg/issues/162) | research owner, cohort, consent/support and decision authority | `OWNER_ACTION_REQUIRED` |
| Accounts/signing/distribution | [#152](https://github.com/MKSEgr/walking-rpg/issues/152), [#158](https://github.com/MKSEgr/walking-rpg/issues/158), [#159](https://github.com/MKSEgr/walking-rpg/issues/159), [#160](https://github.com/MKSEgr/walking-rpg/issues/160) | account/signing owner, developer access and protected signing environment | `OWNER_ACTION_REQUIRED` |

This dossier identifies the required roles and gates; it does not silently
assign people, spend money, create accounts or provision credentials.

## External blockers and non-claims

This dossier proves a reproducible, code-complete engineering baseline only. It
does **not** claim that:

- Android or iOS artifacts are production-signed or distributed;
- HealthKit/Health Connect passed on physical devices;
- Auth0, Telegram, account lifecycle or destructive deletion passed end to end;
- a production-like stage, real TLS database, monitoring, restore or rollback
  drill exists;
- developer accounts, public URLs, store declarations or review are complete;
- visual direction, first-journey comprehension, retention or product value is
  validated.

The authoritative order remains
[`FORWARD_ROADMAP.md`](../FORWARD_ROADMAP.md). External tasks stay open until
their own dated evidence and acceptance rules are satisfied.

## Stop and rollback

Before merge, closing the issue #468 PR leaves no effective `alpha-rc2`
decision. After merge, any provenance mismatch or invalidated gate must create
a release-blocker issue and mark this candidate revoked in a new PR. Never edit
this record to relabel a different source, anchor or tree.

## Acceptance evidence

- [x] One tuple pins the post-merge anchor, artifact source and exact tree.
- [x] Standard CI, Release quality and finalizer are successful on the accepted
      artifact source.
- [x] Five artifact IDs, archive digests and independently verified payload
      checksums are recorded.
- [x] Build metadata and synthetic restore scope were inspected.
- [x] External gates remain explicit non-claims with owner-action handoffs.
- [x] Issue #468 changes only release/evidence documentation.
