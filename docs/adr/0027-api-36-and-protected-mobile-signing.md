# ADR 0027: explicit API 36 and protected mobile signing

- Status: Accepted
- Date: 2026-07-31

## Context

Release candidates are built in ordinary pull-request CI as an unsigned Android
App Bundle and an iOS app without code signing. This deliberately proves source
and packaging without placing production signing identities in the repository
or in an unprotected workflow.

The Android project previously inherited `compileSdk` and `targetSdk` from the
selected Flutter SDK. That made a store requirement depend on an indirect tool
default and did not record the effective target API in source-controlled release
metadata. Google Play requires new phone/tablet apps and updates to target
[Android 16 / API 36 from 2026-08-31](https://support.google.com/googleplay/android-developer/answer/11926878).

Production signing also needs an executable boundary before credentials exist.
The boundary must let a protected environment provide an upload key without
making ordinary CI signed, accepting a repository-local secret file or falling
back to the debug key.

## Decision

### Android SDK contract

The Android application explicitly declares:

- `compileSdk = 36`;
- `targetSdk = 36`;
- `minSdk = 26`.

Release metadata and policy checks read these literal values from the project.
Changing the Flutter SDK must not silently change the store target.

### Ordinary release-quality CI

Ordinary CI remains credential-free:

- Android produces an unsigned release AAB;
- iOS produces a release app with `--no-codesign`;
- neither artifact is a production or store-upload candidate;
- release jobs check out the exact pull-request head that is named by the
  metadata and release evidence.

CI may exercise the Android signing configuration with a disposable synthetic
keystore outside the checkout. It must not upload the synthetic signed output,
reuse that identity, or claim that production signing was validated.

### Protected Android signing

Android production signing is opt-in through the Gradle project property
`walkingRpgSigningProperties`. In CI this can be supplied without putting a
path in the command line through
`ORG_GRADLE_PROJECT_walkingRpgSigningProperties`.

The referenced properties file:

- is a canonical regular file outside the repository;
- contains exactly `storeFile`, `storePassword`, `keyAlias` and `keyPassword`;
- points to a canonical regular keystore outside the repository;
- contains no empty values.

Missing opt-in keeps the release build unsigned. Once opt-in is present,
missing, extra or invalid configuration fails the build. The release build
never uses `signingConfigs.debug`.

The keystore and properties file are materialized only by the protected
environment, deleted after the build and never retained as artifacts.

### Protected iOS signing

iOS signing remains an external protected-environment gate. A signed archive
requires the final Bundle ID, Apple team, Distribution identity, App Store
profile and owner approval. The repository does not embed a team, certificate,
profile or private export configuration merely to make no-codesign CI green.

The same post-merge source/tree, evidence and cleanup rules apply when the
protected iOS pipeline is connected.

### Approval and evidence

A signed candidate is valid only when all of the following establish one
reviewed source tree and one tested post-merge source commit:

- CODEOWNER approval of the pull-request head tree;
- equality between that tree and the post-merge `master` tree;
- Standard CI and Release quality push checks for the exact `master` SHA;
- protected-environment approval;
- artifact digest and signing verification;
- final application identifiers;
- device install/update evidence.

No password, private key, provisioning profile, private connection string or
secret-file path is copied into retained evidence.

## Consequences

- API 36 compliance is reviewable in source and reproducible metadata.
- Flutter upgrades cannot silently lower or raise the target API.
- Developers can still build the ordinary unsigned release candidate without
  possessing production credentials.
- Android signing configuration can be rehearsed without creating a reusable
  signing identity.
- A successful synthetic rehearsal does not satisfy Apple/Google developer
  account, production signing, store upload or device-validation gates.

## Rejected alternatives

### Keep `flutter.targetSdkVersion`

Rejected because a store contract would continue to depend on the selected
Flutter toolchain rather than the reviewed source tree.

### Sign release builds with the debug key

Rejected because it can hide missing production signing and creates an artifact
that is neither an honest unsigned candidate nor a valid store candidate.

### Track `key.properties` or a keystore

Rejected because ignore rules are not a secret-management boundary and Git
history is difficult to purge reliably.

### Put passwords directly in workflow commands

Rejected because command lines, process listings and diagnostic output broaden
secret exposure. The workflow passes only the external properties-file path;
the protected file owns secret values.

### Treat a synthetic key as production validation

Rejected because it proves only Gradle wiring. Store identity, account
ownership, protected secret handling and device installation remain external.
