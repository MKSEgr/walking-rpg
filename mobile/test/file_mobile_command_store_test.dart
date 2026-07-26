import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/commands/file_mobile_command_store.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';

void main() {
  late Directory directory;
  late FileMobileCommandStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'walking-rpg-command-store-',
    );
    store = FileMobileCommandStore(
      directoryProvider: () async => directory,
      clock: () => DateTime.utc(2026, 7, 26, 9),
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('saves and loads versioned command envelope', () async {
    final MobileCommand command = _command('key-1');

    await store.save(<MobileCommand>[command]);
    final List<MobileCommand> restored = await store.load();

    expect(restored, hasLength(1));
    expect(restored.single.commandId, command.commandId);
    expect(restored.single.payload, command.payload);
  });

  test('restores backup after interrupted replace', () async {
    final MobileCommand command = _command('key-backup');
    await store.save(<MobileCommand>[command]);
    final File target = File(_targetPath(directory, store.fileName));
    final File backup = await target.rename('${target.path}.bak');
    expect(await backup.exists(), isTrue);
    expect(await target.exists(), isFalse);

    final List<MobileCommand> restored = await store.load();

    expect(restored.single.idempotencyKey, 'key-backup');
    expect(await target.exists(), isTrue);
  });

  test('prefers a valid temporary replacement over an older backup', () async {
    final MobileCommand oldCommand = _command('old-key');
    final MobileCommand newCommand = _command('new-key');
    await store.save(<MobileCommand>[oldCommand]);
    final File target = File(_targetPath(directory, store.fileName));
    final File backup = await target.rename('${target.path}.bak');
    final File temporary = File('${target.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        'version': FileMobileCommandStore.schemaVersion,
        'commands': <Map<String, Object?>>[newCommand.toJson()],
      }),
      flush: true,
    );
    expect(await backup.exists(), isTrue);

    final List<MobileCommand> restored = await store.load();

    expect(restored.single.idempotencyKey, 'new-key');
    expect(await target.exists(), isTrue);
    expect(await temporary.exists(), isFalse);
  });

  test('restores valid temporary file from first interrupted write', () async {
    final MobileCommand command = _command('key-temp');
    final File temporary = File(
      '${_targetPath(directory, store.fileName)}.tmp',
    );
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        'version': FileMobileCommandStore.schemaVersion,
        'commands': <Map<String, Object?>>[command.toJson()],
      }),
      flush: true,
    );

    final List<MobileCommand> restored = await store.load();

    expect(restored.single.idempotencyKey, 'key-temp');
    expect(await File(_targetPath(directory, store.fileName)).exists(), isTrue);
  });

  test('uses valid backup when target is corrupted', () async {
    final MobileCommand command = _command('key-valid');
    await store.save(<MobileCommand>[command]);
    final File target = File(_targetPath(directory, store.fileName));
    final File backup = File('${target.path}.bak');
    await backup.writeAsBytes(await target.readAsBytes(), flush: true);
    await target.writeAsString('{broken-json', flush: true);

    final List<MobileCommand> restored = await store.load();

    expect(restored.single.idempotencyKey, 'key-valid');
    final List<FileSystemEntity> files = await directory.list().toList();
    expect(
      files.where((FileSystemEntity file) => file.path.contains('.corrupt-')),
      isNotEmpty,
    );
  });

  test('does not silently overwrite an unreadable store', () async {
    final File target = File(_targetPath(directory, store.fileName));
    await target.writeAsString('{broken-json', flush: true);

    await expectLater(
      store.load(),
      throwsA(isA<MobileCommandStoreCorruptedException>()),
    );
    expect(await target.readAsString(), '{broken-json');
  });

  test('rejects unsupported schema version', () async {
    final File target = File(_targetPath(directory, store.fileName));
    await target.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 999,
        'commands': const <Object>[],
      }),
      flush: true,
    );

    await expectLater(
      store.load(),
      throwsA(isA<MobileCommandStoreCorruptedException>()),
    );
  });
}

MobileCommand _command(String key) {
  return MobileCommand.pending(
    ownerId: 'user-1',
    type: MobileCommandType.activitySync,
    idempotencyKey: key,
    fingerprint: 'fingerprint-$key',
    payload: <String, Object?>{
      'authoritativeTotal': 100,
      'localDate': '2026-07-26',
      'timeZone': 'UTC',
      'syncCursor': null,
    },
    now: DateTime.utc(2026, 7, 26, 9),
  );
}

String _targetPath(Directory directory, String fileName) {
  return '${directory.path}${Platform.pathSeparator}$fileName';
}
