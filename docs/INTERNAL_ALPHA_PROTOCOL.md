# Internal alpha protocol

- Protocol ID: `walking-rpg-internal-alpha-v1`
- Decision authority, Product Owner, Release Owner, Cohort Owner and Support Owner: `@MKSEgr`.
- Geography: Russia.
- Languages: Russian and English; registration requires an explicit choice and presents Russian first.
- Cohort: 12 participants, including at least 4 real users on iOS and 4 on Android.
- Recruitment status: `BLOCKED` until every start gate below has dated evidence.
- Source of owner decisions: [issue #148 owner decision](https://github.com/MKSEgr/walking-rpg/issues/148#issuecomment-5226010194).

Merge of the pull request that introduces this document approves this protocol version.
It does not approve recruitment, prove a physical test, or mark an external gate as
`VALIDATED`. Every session must use one immutable candidate and this protocol version.

## Start gate

The Cohort Owner records one kickoff decision before the first invitation. Recruitment
must remain blocked unless every row is `PASS`; `BLOCKED`, `UNKNOWN` and stale evidence
are failures.

| Gate | Required evidence | Current dependency |
|---|---|---|
| Physical activity | Required HealthKit/Health Connect matrix passed without loss or duplicate ENERGY | [#21](https://github.com/MKSEgr/walking-rpg/issues/21) |
| Identity lifecycle | Real Auth0 login, refresh, revoke, logout, switch, export and deletion passed on iOS and Android | [#153](https://github.com/MKSEgr/walking-rpg/issues/153) |
| Protected stage | Immutable deployment, private management surface, monitoring and rollback readiness | [#151](https://github.com/MKSEgr/walking-rpg/issues/151) |
| Product flow | Approved first-journey direction with no open critical accessibility or comprehension blocker | [#156](https://github.com/MKSEgr/walking-rpg/issues/156) |
| Application identity | Developer accounts, application IDs and public privacy/support/deletion routes verified | [#152](https://github.com/MKSEgr/walking-rpg/issues/152) |
| Candidate | Protected signed iOS and Android artifacts tied to one source SHA/tree | [#158](https://github.com/MKSEgr/walking-rpg/issues/158) |
| Distribution | Clean install, first launch, upgrade and rollback passed on internal tracks | [#160](https://github.com/MKSEgr/walking-rpg/issues/160) |
| Operations | Owner available for the whole moderated window and one hour after it; private participant support route tested | kickoff record |
| Research safety | Consent text, withdrawal route, redaction review and evidence retention date approved | kickoff record |
| Observability | Mandatory milestone coverage can be measured and crash/sync/support views are available | kickoff record |

### Machine-verifiable kickoff preflight

The normative template is
`docs/evidence/internal-alpha-kickoff-template.json` with schema
`walking-rpg-internal-alpha-kickoff-v1`. Its committed `recordStatus=TEMPLATE`
is intentionally not recruitment evidence. A reviewed copy is checked with:

```bash
python3 scripts/ci/verify_internal_alpha_kickoff.py \
  <approved-kickoff-record.json> \
  --require-ready
```

`--require-ready` accepts only one exact candidate, the approved owners and
12-participant RU/EN cohort, an ordered observation/support window, a bounded
participant-evidence deletion date and all ten ordered `PASS` gates with
SHA-256 evidence-package digests. Unknown/reordered fields, placeholders,
`BLOCKED`, raw URLs/paths/contact details and identifier-like credential text
fail closed. Passing the validator proves record completeness, not the truth
of external evidence; the referenced gate owners remain responsible for that.

## Exact candidate contract

The kickoff record must list all of the following. A branch name, moving tag, latest
artifact or successful run on another SHA is not acceptable.

- source commit SHA and Git tree SHA;
- app version and build number for both platforms;
- iOS bundle ID, Android application ID and distribution-track names;
- artifact checksums and protected build/run identifiers;
- backend image digest, deployment receipt and stage environment name;
- active content version and remote-config version;
- protocol ID and protocol commit SHA;
- UTC observation window and owner approval timestamp.

Any source, identity, environment, content, remote-config or protocol change creates a
new candidate. Already collected sessions stay attached to the old candidate and are
never silently pooled with the successor.

## Recruitment, consent and support

- Invite exactly 12 adults who can give informed consent; do not recruit minors.
- Include at least 4 participants who run the real iOS candidate and 4 who run the real
  Android candidate. Emulator-only or developer-driven sessions do not count.
- Participation is voluntary. Consent explains purpose, duration, Health permission,
  telemetry categories, evidence retention, withdrawal and the support route.
- A refusal or withdrawal has no penalty. Stop collection immediately and remove
  research evidence where the approved retention/legal policy permits.
- Do not place names, emails, account IDs, device IDs, raw Health samples, tokens,
  screenshots with personal notifications or a participant-code lookup key in Git.
- Use study codes `P01`–`P12`; store the identity mapping only in approved restricted
  research storage, separately from session evidence.
- Run sessions only in pre-announced moderated windows. `@MKSEgr` is reachable through
  the approved private participant channel for the full window and one hour afterwards.
- Record the support-channel category and the fact it was tested; do not commit a
  private address, invitation link or participant conversation.

## First-ten-minutes script

The facilitator starts the timer when the participant sees the first interactive
registration screen. No hints, pointing or corrective actions are allowed unless a
safety/stop condition fires. A request for help is recorded with the current stage and
the session continues only if it remains safe; that session is not an unaided
completion.

| Window | Participant task | Observable completion |
|---|---|---|
| 00:00–02:00 | Choose RU/EN, sign in and reach the permission explanation | Authenticated shell visible; chosen locale recorded |
| 02:00–04:00 | Decide on step permission and perform the first authoritative sync | Permission outcome and sync receipt recorded; ENERGY visible when granted/data exists |
| 04:00–06:00 | Choose a companion and continue the journey | Server-confirmed companion selection and first node available |
| 06:00–09:00 | Enter the node, resolve the first event and inspect the reward | Event choice, immutable result receipt and explicit result ACK recorded |
| 09:00–10:00 | Explain what walking changes and what they would do next | Verbatim-safe coded summary plus next-action comprehension rating |

Before the timed flow, the moderator verifies consent and the exact candidate without
teaching the UI. After it, ask the participant whether the walk felt part of an
adventure, whether the companion creates a reason to return, and what was confusing.
Capture coded notes, not a transcript containing personal data.

## Metrics and approved thresholds

The owner-approved thresholds are evaluated against the fixed cohort. Percentages are
reported together with integer numerators and denominators; rounding never turns a
failure into a pass.

| Metric | Definition | Pass threshold |
|---|---|---|
| Unaided first-ten-minutes completion | Reaches explicit first event-result ACK and explains the next action without facilitator help | at least `9/12` |
| Step-permission acceptance | Participants granting the supported physical activity permission / participants shown the request | `>70%`; for 12 eligible participants, at least `9/12` |
| First-day reward | Participants with an authoritative reward receipt by end of their first UTC/local study day / started participants | `>55%`; for 12 starters, at least `7/12` |
| Crash-free sessions | Sessions without a captured app crash / all candidate sessions | `>99.5%` |
| Sync error rate | Failed non-cancelled authoritative sync attempts / all authoritative sync attempts | `<1%` |
| Instrumentation coverage | Participants with every applicable mandatory milestone / participants reaching that stage | `>=95%` |
| Release blockers | Open privacy, security, wrong-owner, data-loss, duplicate-reward, install or lifecycle blocker | exactly `0` |

Also report p50/p90 time to authenticated shell, first sync, first ENERGY, first node,
first event, result receipt and explicit ACK. These timings diagnose friction but do
not replace the approved pass thresholds. Permission denial is a valid participant
choice; the UI must explain the limited path and must not coerce a grant.

## Stop and pause authority

`@MKSEgr` may stop the study or either platform immediately. The moderator pauses the
affected session first and escalates; no attempt to preserve a metric outranks safety.

Stop all recruitment immediately for:

- suspected privacy/security exposure, wrong-account data, credential leakage or
  consent/withdrawal failure;
- loss or duplication of accepted activity, ENERGY, inventory, reward or immutable
  history;
- destructive account action affecting the wrong owner or failing to honour the
  confirmed participant request;
- an uncontained P0/P1 incident, corrupted evidence boundary, unavailable support
  owner, or a candidate that cannot be tied to exact source and deployment evidence.

Pause the affected platform for a reproducible crash, install/upgrade failure, auth
lifecycle failure, Health provider regression or monitoring blind spot. A threshold
miss without an immediate safety risk blocks expansion and produces `FIX_AND_RERUN`;
it does not permit adding replacement participants to hide the miss.

Resume requires a dated incident disposition, successor candidate when any relevant
boundary changed, repeated start-gate review and explicit Release Owner approval.

## Evidence, privacy and retention

Use [the session template](evidence/internal-alpha-session-template.md) once per
participant and [the decision template](evidence/internal-alpha-decision-template.md)
once per candidate. Store raw logs, screenshots and exports only in approved restricted
evidence storage. The repository may contain only reviewed, aggregated and redacted
records.

Evidence names use:

`internal-alpha-v1_<candidate>_<platform>_<study-code>_<session-start-UTC>_<kind>`

where `<kind>` is one of `session`, `milestones`, `diagnostics` or `decision`. Do not
put names, account/device identifiers, email addresses, access URLs or tokens in a
filename or free-text note.

At kickoff, record one deletion date no later than 90 days after the final alpha
decision for participant-level research evidence. Aggregated non-identifying metrics
and the signed decision record may remain with release evidence. Apply an earlier
approved legal/privacy deadline when one exists. The Support Owner records deletion
completion outside Git.

## Defect triage and rerun

| Severity | Meaning | Required action |
|---|---|---|
| `STOP` | Safety, privacy, wrong owner, data loss/duplication or release blocker | Stop recruitment; incident handling; no resume without owner approval |
| `FIX_BEFORE_EXPAND` | Threshold miss or reproducible failure in the mandatory flow | Open one bounded issue, fix, create successor candidate and rerun affected/full cohort as decided |
| `EXPERIMENT` | Comprehension or value hypothesis with no release-blocking defect | Preserve finding and define measurable follow-up after alpha decision |
| `LATER` | Out-of-scope observation with no material alpha impact | Backlog with rationale; no scope expansion during the study |

Every finding records candidate, platform, protocol version, first affected stage,
reproduction status, severity, owner and linked issue. A rerun never overwrites the
original outcome. If the script, thresholds or cohort rules change, increment the
protocol ID and do not pool results without an explicit comparability decision.

## Final decision

After all 12 planned participants or an earlier stop, `@MKSEgr` signs exactly one:

- `EXPAND`: every approved threshold passes, instrumentation is interpretable, no
  release blocker remains, and qualitative evidence supports walking as adventure plus
  companion-driven return motivation;
- `FIX_AND_RERUN`: the value hypothesis remains plausible, but one or more thresholds,
  mandatory gates or comprehension outcomes require a focused successor cycle;
- `STOP`: safety, operational feasibility or the core value hypothesis does not justify
  further cohort expansion.

The signed record includes exact candidate/protocol, invited/started/completed counts,
per-platform counts, every numerator/denominator, incidents, exclusions, evidence
location category, open defects and rationale. Expansion to closed beta is forbidden
without an `EXPAND` record. Before signature, run the decision-evidence cross-check
documented in [the decision template](evidence/internal-alpha-decision-template.md); its
deterministic package digest binds the exact kickoff and ordered participant-record
digests, and its safely derived counts must match the decision. The kickoff's planned
cohort does not prove how many invitations were actually sent; invitations and
exclusions remain reviewed inputs, especially for an early stop. Passing that
cross-check proves internal consistency, not the truth or approval of external evidence.
If the study stops before its first session, the cross-check accepts the kickoff-only
package only with zero started/platform/withdrawal/stop counts and six decision metric
`DATA_GAP` values; it never permits `EXPAND`. Findings from supplied sessions are a
validated lower bound, so a signed decision may retain additional reviewed pre-session
or operational incidents, and decision recording must follow READY kickoff approval.
Issue #162 owns the product decision;
issue #161 owns the actual first-journey study.
