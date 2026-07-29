import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/account/application/account_export_coordinator.dart';

void main() {
  test(
    'writes the JSON export before invoking the platform share sheet',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'walking-rpg-account-export-',
      );
      final List<AccountExportArtifact> shared = <AccountExportArtifact>[];
      final AccountExportCoordinator coordinator = AccountExportCoordinator(
        directoryProvider: () async => directory,
        share: (AccountExportArtifact artifact, _) async {
          expect(await File(artifact.path).readAsString(), '{"user":[]}');
          shared.add(artifact);
        },
        clock: () => DateTime.utc(2026, 7, 29, 5, 6, 7),
      );

      try {
        final AccountExportArtifact artifact = await coordinator.saveAndShare(
          '{"user":[]}',
        );

        expect(artifact.fileName, 'walking-rpg-data-20260729T050607000Z.json');
        expect(await File(artifact.path).exists(), isFalse);
        expect(shared, <AccountExportArtifact>[artifact]);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('does not create or share an empty export', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'walking-rpg-empty-export-',
    );
    bool shared = false;
    final AccountExportCoordinator coordinator = AccountExportCoordinator(
      directoryProvider: () async => directory,
      share: (_, _) async {
        shared = true;
      },
    );

    try {
      await expectLater(
        coordinator.saveAndShare('  '),
        throwsA(isA<FormatException>()),
      );
      expect(shared, isFalse);
      expect(directory.listSync(), isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('removes the temporary export when sharing fails', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'walking-rpg-failed-export-',
    );
    final AccountExportCoordinator coordinator = AccountExportCoordinator(
      directoryProvider: () async => directory,
      share: (_, _) async {
        throw StateError('share sheet unavailable');
      },
    );

    try {
      await expectLater(
        coordinator.saveAndShare('{"user":[]}'),
        throwsStateError,
      );
      expect(directory.listSync(), isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
