# Release policy

- Source changes enter `master` only through reviewed pull requests.
- Standard CI validates behavior; `Release quality` validates packaging and policy.
- CI candidates are unsigned/no-codesign and are never production artifacts.
- Production signing credentials live only in a protected environment.
- Store submission requires an explicit owner approval and completed external-gate evidence.
- A new source commit always requires a new approval and a new candidate build.
- Synthetic backup/restore CI uses only disposable non-production data and
  never satisfies a dated production restore gate.
- A real restore requires owner approval, an isolated non-production target
  and redacted evidence; production dumps, credentials and connection strings
  are never committed.
