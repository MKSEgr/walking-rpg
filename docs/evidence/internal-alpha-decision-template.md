# Internal alpha decision template

> One record per immutable candidate and protocol version. Replace every placeholder.
> A template or unsigned record is not an expand decision.

## Contract

- Protocol ID: `walking-rpg-internal-alpha-v1`
- Protocol commit SHA:
- Candidate/source SHA/tree SHA:
- iOS version/build/bundle ID/artifact checksum:
- Android version/build/application ID/artifact checksum:
- Backend image digest/deployment receipt/stage:
- Content and remote-config versions:
- Observation window UTC:
- Decision date UTC:
- Decision authority: `@MKSEgr`
- Evidence storage category:
- Participant-level evidence deletion deadline UTC:

## Start gates

| Gate | Status | Dated evidence |
|---|---|---|
| Physical activity | `PASS` / `FAIL` | |
| Identity lifecycle | `PASS` / `FAIL` | |
| Protected stage | `PASS` / `FAIL` | |
| Product flow | `PASS` / `FAIL` | |
| Application identity | `PASS` / `FAIL` | |
| Signed candidate | `PASS` / `FAIL` | |
| Internal-track distribution | `PASS` / `FAIL` | |
| Operations/support | `PASS` / `FAIL` | |
| Consent/privacy | `PASS` / `FAIL` | |
| Observability | `PASS` / `FAIL` | |

## Cohort

- Invited / started / completed:
- iOS real users:
- Android real users:
- Withdrawn:
- Excluded before analysis and pre-declared reason:
- Sessions stopped/paused:

## Thresholds

| Metric | Numerator | Denominator | Rate | Required | Result |
|---|---:|---:|---:|---:|---|
| Unaided first-ten-minutes completion | | 12 | | `>=9/12` | `PASS` / `FAIL` |
| Step-permission acceptance | | | | `>70%` | `PASS` / `FAIL` |
| First-day reward | | 12 | | `>55%` | `PASS` / `FAIL` |
| Crash-free sessions | | | | `>99.5%` | `PASS` / `FAIL` |
| Sync error rate | | | | `<1%` | `PASS` / `FAIL` |
| Instrumentation coverage | | | | `>=95%` | `PASS` / `FAIL` |
| Open release blockers | | | | `0` | `PASS` / `FAIL` |

## Timings and comprehension

- p50/p90 authenticated shell:
- p50/p90 first sync:
- p50/p90 first ENERGY:
- p50/p90 first node:
- p50/p90 first event:
- p50/p90 result receipt:
- p50/p90 explicit ACK:
- Walking-as-adventure `YES` / `PARTIAL` / `NO` counts:
- Companion-return-motivation `YES` / `PARTIAL` / `NO` counts:
- Material comprehension findings:

## Incidents and defects

| Severity | Count | Issue/evidence references | Disposition |
|---|---:|---|---|
| `STOP` | | | |
| `FIX_BEFORE_EXPAND` | | | |
| `EXPERIMENT` | | | |
| `LATER` | | | |

## Decision

Select exactly one:

- [ ] `EXPAND`
- [ ] `FIX_AND_RERUN`
- [ ] `STOP`

Rationale:

Required next actions, owners and dates:

-

Decision authority confirmation:

- GitHub handle: `@MKSEgr`
- Confirmation date UTC:
- Confirmation reference:
