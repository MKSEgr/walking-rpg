import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:walking_rpg_mobile/core/commands/async_lock.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';

typedef CommandDirectoryProvider = Future<Directory> Function();
typedef CommandStoreClock = DateTime Function();

final class FileMobileCommandStore implements MobileCommandStore {
  FileMobileCommandStore({
    required CommandDirectoryProvider directoryProvider,
    CommandStoreClock? clock,
    this.fileName = 'walking_rpg_mobile_commands_v1.json',
  }) : _directoryProvider = directoryProvider,
       _clock = clock ?? DateTime.now;

  factory FileMobileCommandStore.fromEnvironment() {
    return FileMobileCommandStore(
      directoryProvider: getApplicationSupportDirectory,
    );
  }

  static const int schemaVersion = 1;

  final CommandDirectoryProvider _directoryProvider;
  final CommandStoreClock _clock;
  final String fileName;
  final AsyncLock _lock = AsyncLock();

  @override
  Future<List<MobileCommand>> load() {
    return _lock.run<List<MobileCommand>>(_loadUnlocked);
  }

  @override
  Future<void> save(List<MobileCommand> commands) {
    return _lock.run<void>(() => _saveUnlocked(commands));
  }

  @override
  Future<void> deleteOwner(String ownerId) {
    final String normalizedOwnerId = ownerId.trim();
    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Значение обязательно');
    }
    return _lock.run<void>(() async {
      final List<MobileCommand> commands = await _loadUnlocked();
      final List<MobileCommand> retained = commands
          .where(
            (MobileCommand command) => command.ownerId != normalizedOwnerId,
          )
          .toList(growable: false);
      if (retained.length != commands.length) {
        await _saveUnlocked(retained);
      }
    });
  }

  Future<List<MobileCommand>> _loadUnlocked() async {
    final Directory directory = await _directoryProvider();
    await directory.create(recursive: true);

    final File target = File(_path(directory, fileName));
    final File backup = File('${target.path}.bak');
    final File temporary = File('${target.path}.tmp');
    final List<File> existing = <File>[
      if (await target.exists()) target,
      if (await temporary.exists()) temporary,
      if (await backup.exists()) backup,
    ];
    if (existing.isEmpty) {
      return <MobileCommand>[];
    }

    final List<String> invalidPaths = <String>[];
    for (final File candidate in existing) {
      try {
        final List<MobileCommand> commands = _decode(
          await candidate.readAsString(),
        );
        if (candidate.path != target.path) {
          await _restore(candidate: candidate, target: target);
        }
        if (await temporary.exists()) {
          await temporary.delete();
        }
        return commands;
      } on Object {
        invalidPaths.add(candidate.path);
      }
    }

    throw MobileCommandStoreCorruptedException(invalidPaths);
  }

  Future<void> _saveUnlocked(List<MobileCommand> commands) async {
    final Directory directory = await _directoryProvider();
    await directory.create(recursive: true);

    final File target = File(_path(directory, fileName));
    final File backup = File('${target.path}.bak');
    final File temporary = File('${target.path}.tmp');
    final String encoded = jsonEncode(<String, Object?>{
      'version': schemaVersion,
      'commands': commands
          .map<Map<String, Object?>>(
            (MobileCommand command) => command.toJson(),
          )
          .toList(growable: false),
    });

    if (await temporary.exists()) {
      await temporary.delete();
    }
    await temporary.writeAsString(encoded, flush: true);

    if (await backup.exists()) {
      await backup.delete();
    }
    if (await target.exists()) {
      await target.rename(backup.path);
    }

    try {
      await temporary.rename(target.path);
      if (await backup.exists()) {
        await backup.delete();
      }
    } on Object {
      if (!await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  List<MobileCommand> _decode(String encoded) {
    final Object? decoded = jsonDecode(encoded);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Command store должен быть JSON-объектом');
    }
    final Map<String, Object?> envelope = decoded.map<String, Object?>((
      Object? key,
      Object? value,
    ) {
      if (key is! String) {
        throw const FormatException('Ключи command store должны быть строками');
      }
      return MapEntry<String, Object?>(key, value);
    });
    if (envelope['version'] != schemaVersion) {
      throw FormatException(
        'Неподдерживаемая версия command store: ${envelope['version']}',
      );
    }
    final Object? rawCommands = envelope['commands'];
    if (rawCommands is! List<Object?>) {
      throw const FormatException('Поле commands должно быть массивом');
    }

    return rawCommands
        .map<MobileCommand>((Object? item) {
          if (item is! Map<Object?, Object?>) {
            throw const FormatException(
              'Элемент commands должен быть объектом',
            );
          }
          final Map<String, Object?> commandJson = item.map<String, Object?>((
            Object? key,
            Object? value,
          ) {
            if (key is! String) {
              throw const FormatException(
                'Ключи mobile-команды должны быть строками',
              );
            }
            return MapEntry<String, Object?>(key, value);
          });
          return MobileCommand.fromJson(commandJson);
        })
        .toList(growable: false);
  }

  Future<void> _restore({required File candidate, required File target}) async {
    if (await target.exists()) {
      final String suffix = _clock().toUtc().microsecondsSinceEpoch.toString();
      await target.rename('${target.path}.corrupt-$suffix');
    }
    final List<int> bytes = await candidate.readAsBytes();
    await target.writeAsBytes(bytes, flush: true);
  }

  String _path(Directory directory, String name) {
    return '${directory.path}${Platform.pathSeparator}$name';
  }
}

final class MobileCommandStoreCorruptedException implements Exception {
  const MobileCommandStoreCorruptedException(this.paths);

  final List<String> paths;

  @override
  String toString() {
    return 'Не удалось прочитать mobile command store: ${paths.join(', ')}';
  }
}
