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
  --require-recorded
```

The validator accepts only study codes `P01`–`P12`, one exact candidate and the ten
ordered protocol milestones. It checks UTC/elapsed arithmetic, observed-source codes,
consent/privacy invariants and metric bounds. `completedUnaided=true` additionally
requires every milestone through result ACK within 600 seconds, no facilitator help,
clear next-action comprehension and a confirmed first-day reward. A passing JSON record
proves structural completeness and redaction boundaries, not that external evidence is
true or that #161 is complete.

## Identity and contract

- Protocol ID: `walking-rpg-internal-alpha-v1`
- Candidate:
- Protocol commit SHA:
- Study code (`P01`–`P12`):
- Platform: `ios` / `android`
- Session start/end UTC:
- Moderator role:
- Consent confirmed before collection: `PASS` / `FAIL`
- Withdrawal route explained: `PASS` / `FAIL`
- Exact candidate/start gates verified: `PASS` / `FAIL`
- Stop/pause invoked: `NO` / `YES`

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
- Permission granted: `YES` / `NO` / `NOT_APPLICABLE`
- First-day reward by cutoff: `YES` / `NO` / `DATA_GAP`
- Candidate sessions / crash-free sessions:
- Authoritative sync attempts / failed non-cancelled sync attempts:
- Applicable mandatory milestones / recorded mandatory milestones:
- Next-action comprehension: `CLEAR` / `PARTIAL` / `UNCLEAR` / `DATA_GAP`
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
- Participant-level deletion deadline UTC:
- Raw evidence committed to Git: `NO`
