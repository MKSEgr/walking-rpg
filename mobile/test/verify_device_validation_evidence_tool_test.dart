import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';

import '../tool/verify_device_validation_evidence.dart' as verifier;

const String _sourceSha = '0123456789abcdef0123456789abcdef01234567';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'walking-rpg-evidence-verifier-',
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('accepts a valid export bound to an exact physical candidate', () async {
    final File evidence = await _writeEvidence(directory, _physicalEvidence());
    final StringBuffer output = StringBuffer();
    final StringBuffer error = StringBuffer();

    final int result = await verifier.runDeviceValidationEvidenceVerifier(
      _physicalArguments(evidence.path),
      output: output,
      errorOutput: error,
    );

    expect(result, 0);
    expect(error.toString(), isEmpty);
    expect(output.toString(), contains('Device validation evidence valid.'));
    expect(output.toString(), contains('sourceGitSha=$_sourceSha'));
    expect(output.toString(), contains('healthSource=health_connect'));
    expect(output.toString(), contains('journalEntries=3'));
    expect(output.toString(), isNot(contains('Android 16')));
  });

  test('generic schema review accepts development fixtures', () async {
    final File evidence = await _writeEvidence(
      directory,
      _developmentEvidence(),
    );

    final int result = await verifier.runDeviceValidationEvidenceVerifier(
      <String>[evidence.path],
      output: StringBuffer(),
      errorOutput: StringBuffer(),
    );

    expect(result, 0);
  });

  test('physical mode preserves an explicit blocked Health result', () async {
    final File evidence = await _writeEvidence(
      directory,
      _blockedPhysicalEvidence(),
    );
    final StringBuffer output = StringBuffer();

    final int result = await verifier.runDeviceValidationEvidenceVerifier(
      _physicalArguments(evidence.path),
      output: output,
      errorOutput: StringBuffer(),
    );

    expect(result, 0);
    expect(output.toString(), contains('journalEntries=1'));
  });

  test('physical mode rejects development Health evidence', () async {
    final File evidence = await _writeEvidence(
      directory,
      _developmentEvidence(),
    );
    final StringBuffer error = StringBuffer();

    final int result = await verifier.runDeviceValidationEvidenceVerifier(
      _physicalArguments(evidence.path),
      output: StringBuffer(),
      errorOutput: error,
    );

    expect(result, 1);
    expect(error.toString(), contains('platform Health source'));
  });

  test('physical mode requires all exact candidate expectations', () async {
    final File evidence = await _writeEvidence(directory, _physicalEvidence());
    final StringBuffer error = StringBuffer();

    final int result = await verifier.runDeviceValidationEvidenceVerifier(
      <String>[
        '--require-physical-health',
        '--expect-source-git-sha',
        _sourceSha,
        evidence.path,
      ],
      output: StringBuffer(),
      errorOutput: error,
    );

    expect(result, 2);
    expect(error.toString(), contains('arguments are invalid'));
  });

  test('rejects every exact candidate metadata mismatch', () async {
    final File evidence = await _writeEvidence(directory, _physicalEvidence());
    final Map<String, String> mismatches = <String, String>{
      '--expect-source-git-sha': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      '--expect-app-version': '0.2.0',
      '--expect-build-number': '47',
      '--expect-platform': 'ios',
    };

    for (final MapEntry<String, String> mismatch in mismatches.entries) {
      final StringBuffer error = StringBuffer();
      final int result = await verifier.runDeviceValidationEvidenceVerifier(
        <String>[mismatch.key, mismatch.value, evidence.path],
        output: StringBuffer(),
        errorOutput: error,
      );

      expect(result, 1, reason: mismatch.key);
      expect(
        error.toString(),
        contains('does not match'),
        reason: mismatch.key,
      );
    }
  });

  test('rejects a checksum-broken export without echoing it', () async {
    final File evidence = await _writeEvidence(directory, _physicalEvidence());
    await evidence.writeAsString(
      (await evidence.readAsString()).replaceFirst(
        '"authoritativeTotal":6842',
        '"authoritativeTotal":6843',
      ),
      flush: true,
    );
    final StringBuffer error = StringBuffer();

    final int result = await verifier.runDeviceValidationEvidenceVerifier(
      <String>[evidence.path],
      output: StringBuffer(),
      errorOutput: error,
    );

    expect(result, 1);
    expect(error.toString(), contains('checksum verification failed'));
    expect(error.toString(), isNot(contains('authoritativeTotal')));
    expect(error.toString(), isNot(contains(evidence.path)));
  });

  test('rejects malformed UTF-8 before schema parsing', () async {
    final File evidence = File('${directory.path}/invalid.json');
    await evidence.writeAsBytes(<int>[0xc3, 0x28], flush: true);
    final StringBuffer error = StringBuffer();

    final int result = await verifier.runDeviceValidationEvidenceVerifier(
      <String>[evidence.path],
      output: StringBuffer(),
      errorOutput: error,
    );

    expect(result, 1);
    expect(error.toString(), contains('not strict UTF-8'));
  });

  test(
    'rejects a file above the schema byte limit before reading it',
    () async {
      final File evidence = File('${directory.path}/oversized.json');
      await evidence.writeAsBytes(
        List<int>.filled(
          DeviceValidationEvidenceCodec.maxEncodedBytes + 1,
          0x20,
        ),
        flush: true,
      );
      final StringBuffer error = StringBuffer();

      final int result = await verifier.runDeviceValidationEvidenceVerifier(
        <String>[evidence.path],
        output: StringBuffer(),
        errorOutput: error,
      );

      expect(result, 1);
      expect(error.toString(), contains('exceeds the 64 KiB limit'));
    },
  );

  test(
    'rejects an export without a Health observation in physical mode',
    () async {
      final DeviceValidationEvidenceSnapshot empty =
          DeviceValidationEvidenceSnapshot(
            launch: _launch(EvidenceHealthSource.healthConnect),
            updatedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
            journal: const <EvidenceJournalEntry>[],
          );
      final File evidence = await _writeEvidence(directory, empty);
      final StringBuffer error = StringBuffer();

      final int result = await verifier.runDeviceValidationEvidenceVerifier(
        _physicalArguments(evidence.path),
        output: StringBuffer(),
        errorOutput: error,
      );

      expect(result, 1);
      expect(error.toString(), contains('recorded Health observation'));
    },
  );
}

List<String> _physicalArguments(String path) {
  return <String>[
    '--require-physical-health',
    '--expect-source-git-sha',
    _sourceSha,
    '--expect-app-version',
    '0.1.0',
    '--expect-build-number',
    '46',
    '--expect-platform',
    'android',
    path,
  ];
}

Future<File> _writeEvidence(
  Directory directory,
  DeviceValidationEvidenceSnapshot snapshot,
) async {
  final File file = File('${directory.path}/evidence.json');
  await file.writeAsString(
    DeviceValidationEvidenceCodec.encode(
      snapshot,
      exportedAtUtc: DateTime.utc(2026, 7, 31, 18, 5),
    ),
    flush: true,
  );
  return file;
}

DeviceValidationEvidenceSnapshot _physicalEvidence() {
  return DeviceValidationEvidenceSnapshot(
    launch: _launch(EvidenceHealthSource.healthConnect),
    updatedAtUtc: DateTime.utc(2026, 7, 31, 18, 4, 9),
    latestHealth: EvidenceHealthObservation(
      status: EvidenceObservationStatus.succeeded,
      providerState: EvidenceProviderState.available,
      permissionState: EvidencePermissionState.requestSucceeded,
      authoritativeTotal: 6842,
      localDate: '2026-07-31',
      timeZone: 'Europe/Berlin',
      includeManualEntries: false,
      durationMs: 120,
    ),
    journal: <EvidenceJournalEntry>[
      EvidenceJournalEntry(
        sequence: 1,
        scenario: EvidenceScenario.provider,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 0,
      ),
      EvidenceJournalEntry(
        sequence: 2,
        scenario: EvidenceScenario.permission,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 0,
      ),
      EvidenceJournalEntry(
        sequence: 3,
        scenario: EvidenceScenario.read,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 120,
      ),
    ],
  );
}

DeviceValidationEvidenceSnapshot _blockedPhysicalEvidence() {
  return DeviceValidationEvidenceSnapshot(
    launch: _launch(EvidenceHealthSource.healthConnect),
    updatedAtUtc: DateTime.utc(2026, 7, 31, 18, 4, 9),
    latestHealth: EvidenceHealthObservation(
      status: EvidenceObservationStatus.blocked,
      providerState: EvidenceProviderState.unavailable,
      permissionState: EvidencePermissionState.unknown,
      includeManualEntries: false,
      durationMs: 120,
      errorCategory: EvidenceErrorCategory.providerUnavailable,
    ),
    journal: <EvidenceJournalEntry>[
      EvidenceJournalEntry(
        sequence: 1,
        scenario: EvidenceScenario.provider,
        outcome: EvidenceOutcome.blocked,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 120,
        errorCategory: EvidenceErrorCategory.providerUnavailable,
      ),
    ],
  );
}

DeviceValidationEvidenceSnapshot _developmentEvidence() {
  return DeviceValidationEvidenceSnapshot(
    launch: _launch(EvidenceHealthSource.development),
    updatedAtUtc: DateTime.utc(2026, 7, 31, 18, 4, 9),
    latestHealth: EvidenceHealthObservation(
      status: EvidenceObservationStatus.succeeded,
      providerState: EvidenceProviderState.notApplicable,
      permissionState: EvidencePermissionState.notRequired,
      authoritativeTotal: 6842,
      localDate: '2026-07-31',
      timeZone: 'Europe/Berlin',
      includeManualEntries: false,
      durationMs: 120,
    ),
    journal: <EvidenceJournalEntry>[
      EvidenceJournalEntry(
        sequence: 1,
        scenario: EvidenceScenario.provider,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 0,
      ),
      EvidenceJournalEntry(
        sequence: 2,
        scenario: EvidenceScenario.permission,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 0,
      ),
      EvidenceJournalEntry(
        sequence: 3,
        scenario: EvidenceScenario.read,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 120,
      ),
    ],
  );
}

EvidenceLaunchMetadata _launch(EvidenceHealthSource healthSource) {
  return EvidenceLaunchMetadata(
    startedAtUtc: DateTime.utc(2026, 7, 31, 18),
    platform: 'android',
    operatingSystemVersion: 'Android 16',
    appVersion: '0.1.0',
    buildNumber: '46',
    sourceGitSha: _sourceSha,
    buildMode: 'debug',
    authenticationMode: 'oidc',
    healthSource: healthSource,
  );
}
