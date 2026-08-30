# `alpha-rc3` release dossier

[Русский перевод](alpha-rc3-release-dossier.ru.md)

This dossier pins the post-gameplay-presentation validation baseline to an
accepted source tree, its post-merge `master` approval anchor, exact automated
gates and independently verified release artifacts. It is an engineering
candidate record, not production-signing, physical-device, stage, store or
product-value evidence.

## Decision record

| Field | Value |
|---|---|
| Candidate | `alpha-rc3` |
| Post-merge `master` anchor | [`ffd67f099256135ff0b9c7df5534516aa074bf74`](https://github.com/MKSEgr/walking-rpg/commit/ffd67f099256135ff0b9c7df5534516aa074bf74) |
| Artifact-producing source | [`dc2119a8305ecb7786f1c0a6fee8609d261f1195`](https://github.com/MKSEgr/walking-rpg/commit/dc2119a8305ecb7786f1c0a6fee8609d261f1195) |
| Exact content tree | `d622a8fc974f234c9a0744b9e99426a201dd2cad` |
| Accepted change | [PR #532](https://github.com/MKSEgr/walking-rpg/pull/532), authoritative saved journey decision event scenes |
| Artifact source timestamp | `2026-08-30T07:19:54Z` |
| Merge anchor timestamp | `2026-08-30T07:38:56Z` |
| Evidence verified | `2026-08-30` |
| Evidence recorder | Codex execution of [F0 issue #533](https://github.com/MKSEgr/walking-rpg/issues/533) |
| Decision authority | Repository maintainer accepting issue #533 through manual merge |

PR #532 was squash-merged. The merge changed commit identity while preserving
the accepted tree byte-for-byte: both the PR source and protected post-merge
`master` anchor resolve to `d622a8fc974f234c9a0744b9e99426a201dd2cad`.
Release artifacts record the PR source and that exact tree; the merge commit
records approval and integration of the same content.

`alpha-rc3` means the complete tuple above, not a branch name or movable label.
The decision takes effect when the PR closing issue #533 is merged. This record
must never be edited to point to another source, anchor or tree. A successor
requires a new candidate and its own evidence. The earlier `alpha-rc1` and
`alpha-rc2` records remain immutable historical candidates.

## Exact automated gates

The artifact-producing source
`dc2119a8305ecb7786f1c0a6fee8609d261f1195` produced successful Standard CI
and Release quality runs before PR #532 was accepted.

| Gate | Run | Result |
|---|---|---|
| Standard CI | [CI #1276 / run `33298949107`](https://github.com/MKSEgr/walking-rpg/actions/runs/33298949107) | `success` |
| Release quality | [Release quality #1157 / run `33298949103`](https://github.com/MKSEgr/walking-rpg/actions/runs/33298949103) | `success` |
| Release PR finalizer | [Finalizer #854 / run `33298949102`](https://github.com/MKSEgr/walking-rpg/actions/runs/33298949102) | `skipped` — not applicable to the source PR and not counted as a passed gate |

Standard CI covered repository/Auth0 contracts, Java 21 compilation, unit/API
tests, PostgreSQL integration and migration tests, Flutter formatting,
analysis and tests, Android debug host build and iOS simulator host build.

Release quality covered policy/build metadata, executable backend packaging
and protected container validation, synthetic PostgreSQL backup/restore,
Android unsigned AAB and iOS no-codesign archive. All five CI jobs and all five
Release quality jobs completed successfully.

## Retained artifacts and verified digests

All artifacts belong to Release quality run `33298949103`, report
`head_sha=dc2119a8305ecb7786f1c0a6fee8609d261f1195`, and expire on
`2026-09-13`. The archive digest is GitHub's SHA-256 of the downloaded ZIP.
During issue #533 execution, every ZIP was downloaded again, its SHA-256 was
matched to GitHub, and every payload checksum was independently recalculated
and matched to the checksum file inside the artifact.

| Artifact | ID | Archive SHA-256 | Payload and verified SHA-256 |
|---|---:|---|---|
| `release-build-metadata` | `9728298321` | `5236ea86916f45001c8e9f09ed84c8189fd19e7b94f1386a5a9ef37c40d97227` | `build-metadata.json`: `3556946bab3f8b52f6aaa4c013d2df678f7142c140b8324d5f50ab105de9a630` |
| `synthetic-backup-restore-evidence` | `9728301025` | `97ac34f11b30e6c4c6586eb2887670ca95e3ca457c21798d7995b057764fd61a` | `evidence.json`: `b9de80bee2cc7ee63c436d48a06456ef0bad815cd92fa50953dcdf8930f7e457` |
| `backend-release-candidate` | `9728311533` | `9e482dd39bcdc2b803b4756c45ab8865721099ba5493d16a70ec418d2a8befa9` | `walking-rpg-backend-0.1.0-SNAPSHOT.jar`: `d1a7a566cb915899013b6482eb7e2c08127f8b5e6b33c4a44c6d5df66bdd6276` |
| `ios-no-codesign-release-app` | `9728337079` | `a1496a60e50a51c16c0c653184e66346d09b4678ecacf95e3b7d22f9d445d35f` | `WalkingRPG-no-codesign.zip`: `f4887059e9eb396ca11c3a1456f2d6a87b0924e44b0e627acbf4065b63ba9c77` |
| `android-unsigned-release-aab` | `9728392138` | `dbeddd86d510c6b8ca2930033039aac8e90226d8f03a35a745d47aaabc79593b` | `app-release.aab`: `c4c2605750a4445271f96d50d6866cc164531396a6537fa5221ccb7337ccaada` |

## Build metadata

The retained schema-v2 build metadata records:

| Field | Value |
|---|---|
| Application | `0.1.0+1` |
| Source / tree | `dc2119a8305ecb7786f1c0a6fee8609d261f1195` / `d622a8fc974f234c9a0744b9e99426a201dd2cad` |
| Flutter / Java | `3.44.7` / `21.0.12+8.0.LTS` |
| Flyway latest version | `34` |
| Active content version | `chapter-1-v1` |
| Android | `com.walkingrpg.walking_rpg_mobile`; compile/target/min SDK `36/36/26` |
| iOS | `com.walkingrpg.walkingRpgMobile`; deployment target `14.0` |
| Signing declaration | Android and iOS: `external-protected-environment` |

## Synthetic restore evidence

The retained receipt is explicitly `scope=SYNTHETIC_CI`,
`productionValidated=false` and `actualProductionDrillRequired=true`. It
records PostgreSQL `17.10`, Flyway `34`, 37 fixture-covered application tables
and exact source/restored matches:

- schema: `6c758caad9225115660eb0a47a68c2bc61ca29f1326f66c711dd9cd51fef680e`;
- data: `ab1afab7e41a0f8592a2e86e466cd1f13054063e1c90c62972e5423082bf05c8`;
- sequences: `e0ca1b16b11db35b90e3eccba877939e6d59efa4f489b759098410001a3f2110`.

The synthetic database dump was intentionally not retained. This receipt does
not satisfy issue #154 or any real-backup restore gate.

## F0 freeze and ownership handoff

The code-only baseline is frozen. New source work before internal alpha is
limited to a reproducible release blocker, an evidence-tooling gap, protected
configuration wiring or a fix backed by physical/alpha evidence.

| Workstream | Linked tasks | Required external owner/action | Status |
|---|---|---|---|
| Physical activity | [#21](https://github.com/MKSEgr/walking-rpg/issues/21) | device-matrix owner and physical iOS/Android/Watch/provider access | `OWNER_ACTION_REQUIRED` |
| Identity | [#153](https://github.com/MKSEgr/walking-rpg/issues/153), [#175](https://github.com/MKSEgr/walking-rpg/issues/175) | Auth0/Telegram owner, tenant, bot and protected credentials | `OWNER_ACTION_REQUIRED` |
| Stage and recovery | [#151](https://github.com/MKSEgr/walking-rpg/issues/151), [#154](https://github.com/MKSEgr/walking-rpg/issues/154), [#155](https://github.com/MKSEgr/walking-rpg/issues/155) | infrastructure/incident owner, approved budget and protected environment | `OWNER_ACTION_REQUIRED` |
| Product/visual | [#156](https://github.com/MKSEgr/walking-rpg/issues/156) | product owner approval of first-world/pet direction | `PRODUCT_DECISION_REQUIRED` |
| Internal alpha | [#161](https://github.com/MKSEgr/walking-rpg/issues/161), [#162](https://github.com/MKSEgr/walking-rpg/issues/162) | research owner, cohort, consent/support and decision authority | `OWNER_ACTION_REQUIRED` |
| Accounts/signing/distribution | [#152](https://github.com/MKSEgr/walking-rpg/issues/152), [#158](https://github.com/MKSEgr/walking-rpg/issues/158), [#159](https://github.com/MKSEgr/walking-rpg/issues/159), [#160](https://github.com/MKSEgr/walking-rpg/issues/160) | account/signing owner, developer access and protected signing environment | `OWNER_ACTION_REQUIRED` |

This dossier identifies the required roles and gates; it does not silently
assign people, spend money, create accounts or provision credentials.

## External blockers and non-claims

This dossier proves a reproducible, code-complete engineering baseline only.
It does **not** claim that:

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

Before merge, closing the PR for issue #533 leaves no effective `alpha-rc3`
decision. After merge, any provenance mismatch or invalidated gate must create
a release-blocker issue and mark this candidate revoked in a new PR. Never edit
this record to relabel a different source, anchor or tree.

## Acceptance evidence

- [x] One tuple pins the post-merge anchor, artifact source and exact tree.
- [x] Standard CI and Release quality are successful on the accepted source;
      the non-applicable skipped finalizer is recorded without overstating it.
- [x] Five artifact IDs, archive digests and independently verified payload
      checksums are recorded.
- [x] Build metadata and synthetic restore scope were inspected.
- [x] External gates remain explicit non-claims with owner-action handoffs.
- [x] Issue #533 changes only release/evidence documentation and the F1
      inventory baseline validator; application/runtime code is unchanged.
