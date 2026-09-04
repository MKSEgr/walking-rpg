# Internal distribution-track validation

This runbook records the external evidence required by
[#160](https://github.com/MKSEgr/walking-rpg/issues/160). It covers clean
install, upgrade and stop/rollback readiness for one exact signed iOS/Android
candidate on TestFlight internal testing and Google Play internal testing.

Repository CI can verify the contract, but it cannot perform or approve a
physical-device run. A merged template or passing unit test is not
`VALIDATED` evidence.

## Preconditions

Before starting either platform run:

1. select the exact current post-merge `master` source;
2. obtain a `RECORDED READY` signed-candidate record that passes
   `verify_signed_candidate_evidence.py --require-ready`;
3. retain the candidate evidence, its protected evidence attestation, both
   signed artifacts and their artifact-attestation bundles;
4. confirm that the candidate build number is greater than the previous
   supported internal build number;
5. assign an approved tester and release validator without storing a personal
   account, device identifier or email address in evidence;
6. confirm the release owner and stop authority.

Changing the source, artifact, application ID, version, build number or track
requires a new record. Results from different candidates must not be combined.

## Required platform scenarios

Each iOS and Android record contains the same exact scenario set:

- clean install from the platform's internal track;
- upgrade from the previous supported internal build;
- launch after install and upgrade;
- production-like authentication;
- authoritative Home read;
- migration and owner-scoped data preservation;
- absence of data from another owner;
- internal-track version visibility;
- tester access;
- stop-distribution procedure;
- rollback/recovery-build communication procedure.

Every result is exactly `PASS`, `FAIL` or `NOT_RUN`. `VALIDATED` requires all
eleven results to be `PASS` on both platforms. A failed scenario requires a
separate GitHub defect issue number. A scenario that was not run is never
treated as a pass.

Platform stores generally do not support arbitrary binary downgrade. The
stop/rollback scenarios therefore verify the approved stop-distribution and
recovery-build path, its owner and its communication procedure; they do not
claim that an unsupported downgrade occurred.

## Evidence states

Use
[`internal-track-validation-template.json`](evidence/internal-track-validation-template.json)
as the source format.

- `TEMPLATE / OWNER_INPUT_REQUIRED` is the committed empty template.
- `RECORDED / BLOCKED` identifies an exact candidate and a coarse blocker. A
  no-run blocker contains no device, OS, previous-build or defect metadata.
- `RECORDED / BLOCKED` may retain partial run results only after protected
  attestation; every `FAIL` links to a defect issue.
- `RECORDED / VALIDATED` requires both complete platform runs, safe cleanup,
  release-owner approval and protected attestation of the exact record bytes.

The only retained device value is the coarse category `iphone_physical` or
`android_physical`; OS versions are bounded numeric values. Do not record
device IDs, tester identities, account names, health values, tokens, secret
paths, signing material or provisioning data.

## Candidate binding

The track record stores the SHA-256 of the exact signed-candidate JSON and its
offline evidence-attestation bundle. For each platform it repeats only fields
that the validator compares byte-for-byte with that candidate:

- application ID;
- signed artifact SHA-256;
- app version and build number;
- exact internal distribution track.

Validation then runs the signed-candidate validator again with the original
account record, IPA/AAB and artifact-attestation bundles. This prevents an
install result from being moved to another source, build, application or
track.

## Protected attestation

Any record containing a physical run claim must be attested by
`.github/workflows/protected-internal-track-evidence.yml`. The workflow:

1. runs behind the existing `protected-mobile-signing` environment;
2. checks out the exact current `master` source;
3. downloads every input from private draft-release assets;
4. independently verifies the complete signed-candidate evidence chain;
5. preflights the exact internal-track record;
6. emits an offline GitHub build-provenance bundle for those record bytes.

The workflow's `--prepare-attestation` mode checks only whether a record is
eligible to be attested. It is not a public validation result. Consumers must
use the resulting bundle with `--evidence-attestation`; the validator pins the
signer workflow and source digest. A local JSON file, ordinary CI output or an
attestation from another workflow cannot satisfy `--require-validated`.

## Validation command

After downloading the retained files, run:

```bash
BUNDLETOOL_JAR=/protected/tools/bundletool-all-1.18.3.jar \
python3 scripts/ci/verify_internal_track_evidence.py internal-track-evidence.json \
  --signed-candidate signed-candidate-evidence.json \
  --signed-candidate-attestation signed-candidate-evidence-attestation.jsonl \
  --account-readiness store-account-readiness.json \
  --ios-artifact candidate.ipa \
  --ios-artifact-attestation ios-artifact-attestation.jsonl \
  --android-artifact candidate.aab \
  --android-artifact-attestation android-artifact-attestation.jsonl \
  --evidence-attestation internal-track-evidence-attestation.jsonl \
  --require-validated
```

Use `--require-recorded` when accepting an honest no-run blocker. It does not
convert `BLOCKED` into `VALIDATED`.

## Stop and cleanup

Stop the affected track and open a release blocker when a run detects:

- install or launch failure;
- migration or owner-data loss;
- another owner's data;
- accepted invalid/stale authentication;
- a track/build mismatch;
- missing tester controls or an unowned stop path;
- secret/signing-material exposure.

Revoke temporary tester access and remove local test data after the run. If
cleanup cannot be confirmed, the overall record remains `BLOCKED`. Rerun only
the affected scenarios after a merged fix, using a new evidence record when
the candidate source or artifact changes.

## Non-claims

This repository contract does not claim that TestFlight, Google Play, an iOS
device or an Android device was accessed. It does not close #160. That issue
remains open until accepted, dated external evidence for both platforms is
reviewed.
