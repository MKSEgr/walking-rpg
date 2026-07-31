# Release policy

- Source changes enter `master` only through reviewed pull requests.
- Standard CI validates behavior; `Release quality` validates packaging and policy.
- CI candidates are unsigned/no-codesign and are never production artifacts.
- Production signing credentials live only in a protected environment.
- Android release configuration may consume only an explicitly selected
  external properties file and keystore; repository-local signing inputs and
  debug signing are forbidden.
- A synthetic signing rehearsal validates wiring only. Its identity and output
  are disposable and never satisfy production signing evidence.
- Each release metadata/backend/mobile candidate set must be built from one
  exact source commit and Git tree.
- Protected signing uses the post-merge `master` SHA after its push checks
  pass. CODEOWNER provenance is linked through equality with the approved PR
  head tree, so squash/rebase merge does not create a false same-SHA claim.
- Store submission requires an explicit owner approval and completed external-gate evidence.
- A new source commit always requires a new approval and a new candidate build.
- Synthetic backup/restore CI uses only disposable non-production data and
  never satisfies a dated production restore gate.
- A real restore requires owner approval, an isolated non-production target
  and redacted evidence; production dumps, credentials and connection strings
  are never committed.
