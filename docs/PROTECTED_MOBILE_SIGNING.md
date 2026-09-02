# Protected mobile signing

This runbook defines the boundary between source-controlled release candidates
and externally signed mobile artifacts.

Ordinary GitHub Actions intentionally create:

- an unsigned Android AAB;
- an iOS release app built with `--no-codesign`.

They are review artifacts, not files for direct store submission.

## Preconditions

Before any protected signing attempt:

1. the source commit is the current post-merge `master` commit;
2. Standard CI and Release quality push checks are green for that exact
   `master` SHA;
3. the source tree SHA matches the head tree of the CODEOWNER-approved pull
   request that produced the `master` commit;
4. the final Android application ID and iOS Bundle ID are approved;
5. the production OIDC clients and redirect URIs match those identifiers;
6. the owner explicitly approved signing from that `master` SHA and tree;
7. signing identities are available outside the repository;
8. the output and temporary secret locations are outside the checkout.

Squash/rebase merge may intentionally create a different commit SHA from the
approved PR head. Equality is therefore established by the full Git tree, while
the signed build is always produced from the tested post-merge `master` SHA.
Changing that source tree after approval requires a new PR, candidate, checks
and signing approval.

## Android

### Source contract

The application explicitly uses:

```text
compileSdk = 36
targetSdk  = 36
minSdk     = 26
```

The upload key must be distinct from a debug key. Google Play App Signing owns
the app-signing key; the protected environment owns the upload key used for the
AAB.

### External properties

Create a protected properties file outside the repository with exactly these
keys:

```properties
storeFile=/protected/path/walking-rpg-upload.jks
storePassword=<protected value>
keyAlias=<protected value>
keyPassword=<protected value>
```

Both the properties file and `storeFile` must resolve to regular files outside
the repository. Empty values, unknown keys, repository-local files and missing
keystores fail closed.

Do not place the file at `mobile/android/key.properties`; the project does not
implicitly load repository-local signing configuration.

### Invocation

Expose only the external properties-file path to Gradle:

```bash
export ORG_GRADLE_PROJECT_walkingRpgSigningProperties=/protected/path/android-signing.properties

cd mobile
flutter build appbundle --release \
  --dart-define=MOBILE_AUTH_MODE=oidc \
  --dart-define=API_BASE_URL=https://api.example.invalid \
  --dart-define=OIDC_ISSUER=https://identity.example.invalid/realms/walking-rpg \
  --dart-define=OIDC_CLIENT_ID=walking-rpg-mobile \
  "--dart-define=OIDC_SCOPES=openid profile offline_access walking-rpg.user" \
  --dart-define=OIDC_REDIRECT_URI=com.walkingrpg.app:/oauthredirect \
  --dart-define=OIDC_POST_LOGOUT_REDIRECT_URI=com.walkingrpg.app:/logout
```

Production values must come from the protected environment; the `.invalid`
examples above are not deployable configuration.

After the build:

1. verify the AAB signature and certificate fingerprint;
2. verify target API 36 from the built package;
3. calculate SHA-256;
4. record the exact post-merge `master` commit SHA, Git tree SHA, approved PR
   and build/tool versions;
5. remove the external properties file and temporary keystore material from
   the runner;
6. retain only the approved artifact and redacted evidence.

### Synthetic CI rehearsal

Release-quality CI may generate a short-lived test keystore under
`RUNNER_TEMP` and use it only to evaluate the protected Gradle configuration.
It does not upload a synthetic signed artifact. A passing rehearsal means only
that the source-controlled wiring accepts a valid external contract and rejects
unsafe inputs.

## iOS

iOS signing remains disabled in ordinary CI. The protected environment must
provide:

- final Bundle ID;
- Apple Developer team ID;
- Distribution certificate in a temporary keychain;
- App Store provisioning profile;
- reviewed export options;
- [Xcode 26 or newer with the iOS 26 SDK](https://developer.apple.com/news/upcoming-requirements/);
- explicit owner approval.

The certificate, private key, profile, temporary keychain and export options
must remain outside the checkout and must be deleted after export.

Before retaining an IPA:

1. verify the archive Bundle ID, entitlements and HealthKit capability;
2. verify the signing identity and embedded profile;
3. record Xcode/SDK, app version/build, post-merge `master` commit/tree,
   approved PR and artifact SHA-256;
4. install through TestFlight on supported physical devices;
5. verify login redirect, Health permission, export and account deletion;
6. retain redacted evidence without profiles, certificates or secret paths.

An unsigned/no-codesign CI app cannot be promoted by attaching a signature
afterward without repeating the protected build from the approved post-merge
`master` SHA and tree.

## Required retained evidence

The sanitized handoff uses
[`signed-candidate-template.json`](evidence/signed-candidate-template.json).
Only a `RECORDED` + `READY` record that passes `--require-ready` may unblock
physical install/distribution work. A committed `TEMPLATE`, a structurally
valid `BLOCKED` record, or ordinary unsigned/no-codesign CI output is not
signed-candidate evidence.

`--require-ready` is an online, fail-closed check. It resolves `master` and the
successful `CI` and `Release quality` runs through the GitHub API rather than
trusting a local remote-tracking ref or copied conclusion strings. The checkout
must also have canonical `origin` set to `MKSEgr/walking-rpg`.

Each `verifierReceiptSha256` identifies an offline GitHub artifact-attestation
bundle for the corresponding artifact. The validator invokes
`gh attestation verify` and restricts the signer to
`.github/workflows/protected-mobile-signing.yml` in this repository. That
protected workflow may create the attestation only after the platform-native
signature verifier has succeeded and the recorded public certificate
fingerprint has been extracted from the same artifact. Plain JSON written by
the evidence author, an ordinary CI artifact, or an attestation from another
workflow does not satisfy the contract.

The protected workflow is manually dispatched against the exact current
`master` SHA, reads a signed IPA/AAB only from a private draft-release asset,
verifies its native signature and expected public certificate fingerprint, and
retains an offline attestation bundle. The validator independently repeats the
native signature/fingerprint extraction and enforces the attestation
`--source-digest` against `source.commitSha`. Only successful `push` runs count
as source CI evidence; manually dispatched workflow results cannot replace the
required master checks.

Retained evidence may contain:

- date and operator;
- repository, exact post-merge `master` commit SHA and Git tree SHA;
- approved pull request and its matching head tree SHA;
- platform, toolchain and SDK versions;
- final public application identifier;
- public certificate fingerprint;
- artifact SHA-256;
- signing-verifier result;
- store track and build number;
- device install/update result;
- owner approval reference.

It must not contain:

- passwords or tokens;
- private keys or keystores;
- provisioning-profile contents;
- private certificate archives;
- secret-file or private runner paths;
- production API/database credentials.

## Failure handling

Stop without upload when:

- the source commit differs from the owner-approved post-merge `master` SHA;
- its Git tree differs from the CODEOWNER-approved PR head tree;
- a signing input is missing, empty or repository-local;
- the release build uses a debug identity;
- application identifiers do not match store/IdP records;
- target API or required entitlements differ from the reviewed contract;
- signing verification fails;
- cleanup of temporary secret material cannot be confirmed.

Do not weaken the unsigned/no-codesign CI path to bypass a protected signing
failure.
