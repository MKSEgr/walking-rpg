# Internal alpha decision template

> One record per immutable candidate and protocol version. Replace every placeholder.
> A template or unsigned record is not an expand decision.

The normative machine-verifiable companion is
`internal-alpha-decision-template.json`. Copy it outside Git, preserve its exact key
order, replace the owner-input fields and validate the reviewed record before signing:

```bash
python3 scripts/ci/verify_internal_alpha_decision.py \
  <approved-decision-record.json> \
  --require-decided
```

The validator uses integer cross-multiplication, so rounded percentages cannot turn
strict `>70%`, `>55%`, `>99.5%` or `<1%` failures into passes. `EXPAND` fails closed
for a data gap, invalid cohort, threshold miss, qualitative miss, stop/fix finding or
open release blocker. This Markdown record adds reviewed narrative; it cannot override
a failing JSON record or prove the referenced external evidence.

Before approval, cross-check the quantitative decision fields against the exact READY
kickoff and every redacted participant record:

```bash
python3 scripts/ci/verify_internal_alpha_decision_evidence.py \
  <approved-decision-record.json> \
  --kickoff <approved-ready-kickoff.json> \
  --session <P01-session.json> \
  --session <P02-session.json> \
  --session <P12-session.json>
```

For a reviewed `STOP`/`FIX_AND_RERUN` decision made before the first session, omit
`--session` entirely. The decision must then record `started=0`, zero derivable cohort
counts and `DATA_GAP` for all six metrics; the package digest still binds the exact
READY kickoff. An `EXPAND` decision cannot pass without all 12 participant records.

The cross-check reruns all three underlying contracts, requires unique study codes and
exact session filenames, reconciles started/platform/withdrawal/stopped-or-paused counts
and recomputes every quantitative metric. Actual invitations and exclusions remain
reviewed owner inputs because the kickoff records only the planned cohort; this permits
truthful early `STOP`/`FIX_AND_RERUN` decisions. The tool also counts each unique linked
finding issue once by severity and rejects conflicting severities for the same issue.
`alphaEvidencePackageSha256` is
the SHA-256 of a domain-separated manifest containing the exact kickoff digest and each
exact session-file digest sorted by study code. Therefore argument order is irrelevant,
while any byte change requires a new package digest and review. A
`PENDING`/`DATA_GAP` reward or unknown shown permission forces the corresponding
decision metric to `DATA_GAP`; missing evidence cannot be counted as a failed
participant merely to manufacture a measured rate. The tool does not derive qualitative
support or current open-release-blocker status; those remain reviewed owner inputs and
can only make `EXPAND` stricter.

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
