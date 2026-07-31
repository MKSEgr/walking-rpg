# Backup/restore drill evidence

Use this template only for an owner-approved restore of a real protected backup
into an isolated non-production target. The synthetic CI report is not a
completed copy of this template.

Do not include passwords, tokens, private hostnames, full connection strings,
raw user data or a database dump.

## Record

- Date/time (UTC):
- Operator:
- Approver:
- Change/release:
- Incident or drill ticket:
- Source environment label (non-secret):
- Backup process/version:
- Immutable archive identifier (non-secret):
- Archive checksum:
- PostgreSQL source version:
- PostgreSQL target version:
- Highest Flyway version:
- Isolated target label:
- Proof target was not production:

## Policy

- Expected RPO:
- Observed recovery point:
- RPO result: `PASS` / `FAIL`
- Expected RTO:
- Backup duration:
- Restore duration:
- Validation duration:
- Total recovery duration:
- RTO result: `PASS` / `FAIL`
- Backup retention/encryption policy reference:
- PITR policy/result:

## Preconditions

- [ ] Owner approved the drill.
- [ ] Source access used the protected secret store.
- [ ] No credential or private connection string was copied into evidence.
- [ ] Target was empty, isolated and incapable of serving production traffic.
- [ ] Archive checksum was verified before restore.
- [ ] Restore tooling versions were recorded.
- [ ] Rollback/incident owner was available.

## Restore

- Command/procedure reference (redacted):
- Restore flags:
- Start time:
- End time:
- Exit status:
- Warnings:
- Role/ACL handling:
- Sequence handling:
- Extensions/tablespaces handling:

## Validation

- [ ] Flyway history is present and current.
- [ ] Expected schemas and application tables exist.
- [ ] Selected non-sensitive row-count controls match.
- [ ] Selected non-sensitive invariant/hash controls match.
- [ ] Sequences are at or above restored maxima.
- [ ] Application readiness succeeds against the isolated target.
- [ ] Application smoke reads succeed without a mutation.
- [ ] No production traffic reached the target.

Control queries or hashes:

```text
Record only non-sensitive aggregate checks.
```

## Disposal

- Target disposal time:
- Disposal method/reference:
- Temporary credentials revoked:
- Temporary archive copies removed:
- Evidence retained at:

## Result

- Result: `PASS` / `FAIL`
- Deviations:
- Follow-up owner:
- Follow-up deadline:
- Final approver:

`VALIDATED` may be recorded only for a dated `PASS` with completed checks and
owner approval. A synthetic report with `scope=SYNTHETIC_CI` or
`productionValidated=false` can never satisfy this gate.
