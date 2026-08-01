import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/validation/application/validation_evidence_exporter.dart';
import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';

void main() {
  test(
    'shares a bounded evidence file and removes the temporary copy',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'walking-rpg-validation-export-',
      );
      final List<ValidationEvidenceExportArtifact> shared =
          <ValidationEvidenceExportArtifact>[];
      final ValidationEvidenceExporter exporter = ValidationEvidenceExporter(
        directoryProvider: () async => directory,
        share: (ValidationEvidenceExportArtifact artifact, _) async {
          expect(await File(artifact.path).readAsString(), _evidenceJson);
          shared.add(artifact);
        },
        clock: () => DateTime.utc(2026, 7, 31, 18, 4, 5),
      );

      try {
        final ValidationEvidenceExportArtifact artifact = await exporter
            .saveAndShare(_evidenceJson);

        expect(
          artifact.fileName,
          'walking-rpg-validation-20260731T180405000Z.json',
        );
        expect(shared, <ValidationEvidenceExportArtifact>[artifact]);
        expect(await File(artifact.path).exists(), isFalse);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('rejects unknown or unsigned evidence before creating a file', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'walking-rpg-invalid-validation-export-',
    );
    bool shared = false;
    final ValidationEvidenceExporter exporter = ValidationEvidenceExporter(
      directoryProvider: () async => directory,
      share: (_, _) async {
        shared = true;
      },
    );

    try {
      await expectLater(
        exporter.saveAndShare('{"schemaVersion":"other"}'),
        throwsA(isA<FormatException>()),
      );
      expect(shared, isFalse);
      expect(directory.listSync(), isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'rejects evidence larger than 64 KiB before filesystem access',
    () async {
      bool directoryRequested = false;
      final ValidationEvidenceExporter exporter = ValidationEvidenceExporter(
        directoryProvider: () async {
          directoryRequested = true;
          throw StateError('directory must not be requested');
        },
        share: (_, _) async {},
      );
      final String oversized = List<String>.filled(
        ValidationEvidenceExporter.maxEncodedBytes + 1,
        'x',
      ).join();

      await expectLater(
        exporter.saveAndShare(oversized),
        throwsA(isA<FormatException>()),
      );
      expect(directoryRequested, isFalse);
    },
  );

  test('removes the temporary evidence file when sharing fails', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'walking-rpg-failed-validation-export-',
    );
    final ValidationEvidenceExporter exporter = ValidationEvidenceExporter(
      directoryProvider: () async => directory,
      share: (_, _) async {
        throw StateError('share sheet unavailable');
      },
    );

    try {
      await expectLater(exporter.saveAndShare(_evidenceJson), throwsStateError);
      expect(directory.listSync(), isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('rejects a tampered evidence checksum before sharing', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'walking-rpg-tampered-validation-export-',
    );
    bool shared = false;
    final ValidationEvidenceExporter exporter = ValidationEvidenceExporter(
      directoryProvider: () async => directory,
      share: (_, _) async {
        shared = true;
      },
    );

    try {
      await expectLater(
        exporter.saveAndShare(
          _evidenceJson.replaceFirst('Android 16', 'Android 17'),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(shared, isFalse);
      expect(directory.listSync(), isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'owner invalidation before share deletes the temporary evidence',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'walking-rpg-invalidated-validation-export-',
      );
      bool shared = false;
      final ValidationEvidenceExporter exporter = ValidationEvidenceExporter(
        directoryProvider: () async => directory,
        share: (_, _) async {
          shared = true;
        },
      );

      try {
        await expectLater(
          exporter.saveAndShare(
            _evidenceJson,
            beforeShare: () => throw StateError('owner invalidated'),
          ),
          throwsStateError,
        );
        expect(shared, isFalse);
        expect(directory.listSync(), isEmpty);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}

final String _evidenceJson = DeviceValidationEvidenceCodec.encode(
  DeviceValidationEvidenceSnapshot(
    launch: EvidenceLaunchMetadata(
      startedAtUtc: DateTime.utc(2026, 7, 31, 18),
      platform: 'android',
      operatingSystemVersion: 'Android 16',
      appVersion: '0.1.0',
      buildNumber: '46',
      sourceGitSha: '0123456789abcdef0123456789abcdef01234567',
      buildMode: 'debug',
      authenticationMode: 'oidc',
      healthSource: EvidenceHealthSource.healthConnect,
    ),
    updatedAtUtc: DateTime.utc(2026, 7, 31, 18),
    journal: const <EvidenceJournalEntry>[],
  ),
  exportedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
);
