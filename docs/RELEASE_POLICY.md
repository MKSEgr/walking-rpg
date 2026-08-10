# Release policy

Current engineering baseline:
[`alpha-rc1` release dossier](evidence/alpha-rc1-release-dossier.md).

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
- Protected backend build stages use reviewed human-readable Temurin tags bound
  to exact multi-platform OCI index digests; tag-only, digest-only, variable and
  platform-expression refs are rejected by CI.
- The protected Dockerfile performs no live OS package-manager installation.
  Its pinned Temurin JDK supplies the reviewed downloader and `jar` extractor;
  the Maven archive is verified before either `unzip` or `jar` can read it.
- The publisher independently requires its current JDK/JRE pins in the selected
  source before registry login. Historical source with older pins is not
  rebuilt; rollback selects an already published immutable application digest.
- PostgreSQL integration, migration, operational and synthetic restore tests
  use one reviewed multi-platform OCI index digest through the shared test
  factory. Local Compose uses the same image as an exact readable
  `tag@sha256` reference; direct constructors, moving refs and digest drift are
  rejected by CI.
- GitHub-hosted jobs use reviewed versioned `ubuntu-24.04` and `macos-26`
  labels. Mutable `-latest`, expressions, collections and unreviewed runner
  labels are rejected across every workflow; runner OS migrations require a
  separate reviewed PR and the full platform matrix.
- Hosted runner labels do not pin GitHub's weekly VM image release. The exact
  image version remains recorded in each job log; full VM-image immutability
  would require a separately governed self-hosted runner contract.
- Maven 3.9.16 and Gradle 9.1.0 wrapper downloads are bound to reviewed
  SHA-256 checksums. Both Maven launchers verify the archive before extraction;
  Gradle uses its native `distributionSha256Sum`, and CI also pins the tracked
  official wrapper JAR bytes. A build-tool upgrade must update URL, checksum
  and policy constants in one reviewed PR.
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
