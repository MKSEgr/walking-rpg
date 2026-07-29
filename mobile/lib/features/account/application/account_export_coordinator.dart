import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

typedef AccountExportDirectoryProvider = Future<Directory> Function();
typedef AccountExportShare =
    Future<void> Function(
      AccountExportArtifact artifact,
      Rect? sharePositionOrigin,
    );
typedef AccountExportClock = DateTime Function();

final class AccountExportArtifact {
  const AccountExportArtifact({
    required this.fileName,
    required this.path,
    required this.createdAt,
  });

  final String fileName;
  final String path;
  final DateTime createdAt;
}

final class AccountExportCoordinator {
  AccountExportCoordinator({
    required AccountExportDirectoryProvider directoryProvider,
    required AccountExportShare share,
    AccountExportClock? clock,
  }) : _directoryProvider = directoryProvider,
       _share = share,
       _clock = clock ?? DateTime.now;

  factory AccountExportCoordinator.fromEnvironment() {
    return AccountExportCoordinator(
      directoryProvider: getTemporaryDirectory,
      share: _shareFile,
    );
  }

  final AccountExportDirectoryProvider _directoryProvider;
  final AccountExportShare _share;
  final AccountExportClock _clock;

  Future<AccountExportArtifact> saveAndShare(
    String json, {
    Rect? sharePositionOrigin,
  }) async {
    if (json.trim().isEmpty) {
      throw const FormatException('Экспорт аккаунта не может быть пустым');
    }
    final DateTime timestamp = _clock().toUtc();
    final Directory directory = await _directoryProvider();
    await directory.create(recursive: true);
    final String fileName =
        'walking-rpg-data-${_fileTimestamp(timestamp)}.json';
    final File file = File('${directory.path}/$fileName');
    await file.writeAsString(json, flush: true);
    final AccountExportArtifact artifact = AccountExportArtifact(
      fileName: fileName,
      path: file.path,
      createdAt: timestamp,
    );
    try {
      await _share(artifact, sharePositionOrigin);
      return artifact;
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<void> _shareFile(
    AccountExportArtifact artifact,
    Rect? sharePositionOrigin,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(artifact.path, mimeType: 'application/json')],
        fileNameOverrides: <String>[artifact.fileName],
        subject: 'Экспорт данных Walking RPG',
        text: 'Архив данных аккаунта Walking RPG.',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  static String _fileTimestamp(DateTime value) {
    return value
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll('.', '');
  }
}
