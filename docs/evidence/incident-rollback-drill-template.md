# Incident and deployment rollback drill worksheet

Use this worksheet only for an approved controlled incident on the protected
non-production stage. It is not machine-verifiable completion evidence. Retain
the sanitized result in
[`incident-rollback-drill-template.json`](incident-rollback-drill-template.json)
and authenticate its exact bytes through the protected workflow in the
production operations runbook.

Never include credentials, tokens, private endpoints, raw logs, user data,
database contents, provider subjects or device identifiers.

## Provenance

- UTC window:
- Incident/drill ticket:
- Current stage evidence and attestation digests:
- Accepted backup/restore evidence and attestation digests:
- Previous known-good publisher receipt and attestation digests:
- Current deployment ID and immutable image digest:
- Rollback deployment ID and immutable image digest:
- Current and rollback source SHA/tree:

## Approved scenario

- Scenario: `backend_readiness_failure` / `auth_dependency_failure` /
  `config_regression` / `content_activation_guard`
- Failure injection procedure reference:
- Proof scope was controlled stage only:
- Incident owner role:
- Stop authority role:
- Expected detection target:
- Expected recovery target:

## Timeline

- Incident started:
- Alert detected:
- Owner acknowledged:
- Stop decision:
- Rollback started:
- Rollback completed:
- Post-rollback validation completed:
- Observed detection time:
- Observed RTO:

## Controls

- [ ] Drill and failure injection were approved and bounded.
- [ ] Alert delivery worked and retained evidence is redacted.
- [ ] Incident owner acknowledged; stop authority stopped expansion.
- [ ] Previous deployment and schema compatibility were preverified.
- [ ] Protected rollback completed successfully.
- [ ] Public `/livez` and `/readyz` passed after rollback.
- [ ] Authentication and critical Home/activity read flows passed.
- [ ] Management stayed private and no production traffic was affected.
- [ ] Accepted backup/restore fallback remained available.
- [ ] Communications and follow-up issues were recorded.
- [ ] Detection and RTO met the approved targets.

## Cleanup and decision

- Failure injection removed:
- Risky remote/config capability disabled:
- Temporary access revoked:
- Secret exposure detected:
- Evidence contains personal data:
- Result: `VALIDATED` / `BLOCKED`
- Defect issue numbers:
- Next action owner/deadline:
- Release owner approval:

The drill remains `BLOCKED` if any required control fails or was not run. A
synthetic rehearsal, CI run or stage deployment alone cannot close issue #155.
