# Internal alpha session evidence template

> Copy this file into approved restricted evidence storage. Commit only a reviewed,
> aggregated and redacted derivative. Never include participant identity, account/device
> identifiers, tokens, raw Health samples, private URLs or support conversations.

The normative machine-verifiable companion is
`internal-alpha-session-template.json`. Copy it outside Git, keep the exact key and
milestone order, fill only sanitized codes/counts/digests and validate the reviewed
record with:

```bash
python3 scripts/ci/verify_internal_alpha_session.py \
  <redacted-participant-session.json> \
  --kickoff <approved-ready-kickoff.json> \
  --require-recorded
```

The validator accepts only study codes `P01`–`P12`, one exact candidate, one referenced
kickoff contract and the ten ordered protocol milestones. It checks UTC/elapsed
arithmetic, observed-source codes, consent/privacy invariants and metric bounds. The
validator checks the exact kickoff file digest and requires its protocol, candidate,
platform artifact, observation window and shared deletion deadline to match the session.
The session must fall inside that observation window. Recorded comprehension requires a
sanitized next-action summary code. Both requested help and unsolicited facilitator help
are recorded for every milestone and the comprehension task. `completedUnaided` must
equal the evidence-derived result: no `NOT_REACHED` journey tail, every observed stage
on time, result ACK by 09:00, clear comprehension during the 09:00–10:00 task, no stop
and no help. Intermediate `DATA_GAP` stages lower instrumentation coverage but do not
lower unaided completion when the remaining evidence satisfies that predicate. First-day
reward remains a separate outcome metric. Its cutoff is derived from the sanitized local
UTC offset, restricted to the RU cohort's UTC+02 through UTC+12 whole-hour zones: before
cutoff it stays `PENDING` unless already `YES`; `NO` and `DATA_GAP` are accepted only at
or after cutoff. Event resolution and reward delivery remain separate: `YES` requires a
dedicated authoritative reward-receipt UTC timestamp at or before cutoff, while every
non-`YES` status requires that timestamp to be null. The receipt must be at or after the
authoritative first-event resolution when that milestone is observed; a milestone
`DATA_GAP` does not erase an independently confirmed authoritative reward receipt, but
the receipt must still follow the latest observed prerequisite journey milestone. A
late receipt requires the redaction review to occur again after that evidence arrives.
Result ACK must complete by 09:00, and
`registration_shown` anchors the timer at session start/zero seconds.
Locale/authentication must complete by 02:00,
permission/sync/applicable ENERGY by 04:00, companion/node by 06:00, and event/result
ACK by 09:00. The selected locale is required when observed and must be one of the
kickoff-approved languages. An unshown permission request uses
`NOT_APPLICABLE/permission_not_requested` for both the decision and ENERGY stages. A
session stopped before that stage may instead keep the permission decision and all
following stages in its legitimate `NOT_REACHED` tail. A
permission denial may use `NOT_APPLICABLE/permission_denied` for `first_energy` while
the supported limited path continues; a denial followed by an earlier stop may instead
put ENERGY in the `NOT_REACHED` tail. Granted permission with no activity data uses
`NOT_APPLICABLE/no_activity_data` for ENERGY. Instrumentation coverage excludes those
non-applicable stages and the `NOT_REACHED` tail; a participant withdrawal requires
`STOPPED` and forces both post-flow qualitative answers to `DATA_GAP`. A shown
permission request whose decision evidence is missing uses `permissionDecision=DATA_GAP`
with a permission milestone instrumentation gap; because the request was shown, ENERGY
cannot use `permission_not_requested`. If withdrawal occurs after the prompt but before
a decision, the outcome and legitimate withdrawn tail use `NOT_REACHED`. Sync metrics separately record total and
successful authoritative attempts plus failed non-cancelled attempts, so cancelled
attempts cannot satisfy the journey. A sync receipt `DATA_GAP` preserves unaided
completion only with at least one successful authoritative attempt. A session-level
withdrawal status and UTC time cover withdrawals even after the final milestone; no
milestone or comprehension may be recorded afterward, and qualitative answers are
discarded; an authoritative reward receipt must also be no later than withdrawal. The
kickoff-wide evidence deadline must be later than every session's derived
first-day reward cutoff so a `PENDING` result can be resolved before deletion. For
terminal `NO` or `DATA_GAP`, redaction review must occur again at or after the cutoff;
`PENDING` retains the pre-cutoff behavior. A passing JSON record
proves structural completeness and redaction boundaries, not that external evidence is
true or that #161 is complete.

Recorded session JSON filenames are exact and contain only contract fields:

`internal-alpha-v1_<source-sha>_<platform>_<study-code>_<YYYYMMDDTHHMMSSZ>_session.json`

The CLI rejects arbitrary names and any filename that does not match the validated
candidate, platform, study code and session start UTC.

After the first `NOT_REACHED`, every remaining milestone must also be `NOT_REACHED`.
An observed sync receipt requires at least one non-failed authoritative sync attempt,
and every finding must link a positive GitHub issue number regardless of severity.

## Identity and contract

- Protocol ID: `walking-rpg-internal-alpha-v1`
- Candidate:
- Protocol commit SHA:
- Kickoff record SHA-256:
- Kickoff observation window UTC:
- Kickoff-wide participant evidence deletion deadline UTC:
- Study code (`P01`–`P12`):
- Platform: `ios` / `android`
- Device environment: `physical_device`
- Session driver: `participant`
- Adult eligibility confirmed: `PASS` / `FAIL`
- Selected locale: `ru` / `en`
- Session start/end UTC:
- Moderator role:
- Consent confirmed before collection: `PASS` / `FAIL`
- Withdrawal route explained: `PASS` / `FAIL`
- Exact candidate/start gates verified: `PASS` / `FAIL`
- Stop/pause invoked: `NO` / `YES`
- Withdrawal status and UTC: `NOT_WITHDRAWN` / `WITHDREW`

## Timed milestones

| Stage | UTC/elapsed time | Source | Result | Help requested |
|---|---|---|---|---|
| Registration shown | | client observation | | |
| Locale selected | | client/server | | |
| Authenticated shell | | authoritative/client | | |
| Permission decision | | platform/client | | |
| First sync receipt | | authoritative | | |
| First ENERGY | | authoritative | | |
| Companion selected | | authoritative | | |
| First node available | | authoritative | | |
| First event resolved | | authoritative | | |
| Result ACK | | authoritative | | |

## Outcome

- Completed first ten minutes unaided: `PASS` / `FAIL`
- Permission request shown: `YES` / `NO`
- Permission decision: `GRANTED` / `DENIED` / `NOT_APPLICABLE` / `DATA_GAP` /
  `NOT_REACHED`
- First-day reward receipt UTC, UTC offset minutes and derived cutoff UTC:
- First-day reward by cutoff: `YES` / `NO` / `DATA_GAP` / `PENDING`
- Candidate sessions / crash-free sessions:
- Authoritative sync attempts / successful authoritative attempts /
  failed non-cancelled sync attempts:
- Applicable mandatory milestones before first `NOT_REACHED` / recorded milestones:
- Next-action sanitized summary code, comprehension, UTC/elapsed time, help requested
  and facilitator help provided:
  `CLEAR` / `PARTIAL` / `UNCLEAR` / `DATA_GAP`
- Walking felt part of an adventure: `YES` / `PARTIAL` / `NO` / `DATA_GAP`
- Companion created a reason to return: `YES` / `PARTIAL` / `NO` / `DATA_GAP`

## Findings

| Stage | Safe coded observation | Severity | Reproducible | Owner | Issue |
|---|---|---|---|---|---|
| | | `STOP` / `FIX_BEFORE_EXPAND` / `EXPERIMENT` / `LATER` | | | |

## Evidence handling

- Storage category:
- Evidence filename prefix:
- Redaction review role/date UTC:
- Participant evidence deletion deadline UTC (must equal kickoff-wide deadline):
- Raw evidence committed to Git: `NO`
