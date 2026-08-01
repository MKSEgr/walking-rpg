import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';

typedef ValidationEvidenceDirectoryProvider = Future<Directory> Function();
typedef ValidationEvidenceShare =
    Future<void> Function(
      ValidationEvidenceExportArtifact artifact,
      Rect? sharePositionOrigin,
    );
typedef ValidationEvidenceExportClock = DateTime Function();
typedef ValidationEvidencePreShareCheck = void Function();

abstract interface class ValidationEvidenceExportService {
  Future<ValidationEvidenceExportArtifact> saveAndShare(
    String json, {
    Rect? sharePositionOrigin,
    ValidationEvidencePreShareCheck? beforeShare,
  });
}

final class ValidationEvidenceExportArtifact {
  const ValidationEvidenceExportArtifact({
    required this.fileName,
    required this.path,
    required this.createdAt,
  });

  final String fileName;
  final String path;
  final DateTime createdAt;
}

final class ValidationEvidenceExporter
    implements ValidationEvidenceExportService {
  ValidationEvidenceExporter({
    required ValidationEvidenceDirectoryProvider directoryProvider,
    required ValidationEvidenceShare share,
    ValidationEvidenceExportClock? clock,
  }) : _directoryProvider = directoryProvider,
       _share = share,
       _clock = clock ?? DateTime.now;

  factory ValidationEvidenceExporter.fromEnvironment() {
    return ValidationEvidenceExporter(
      directoryProvider: getTemporaryDirectory,
      share: _shareFile,
    );
  }

  static const String schemaVersion =
      DeviceValidationEvidenceCodec.schemaVersion;
  static const int maxEncodedBytes =
      DeviceValidationEvidenceCodec.maxEncodedBytes;

  final ValidationEvidenceDirectoryProvider _directoryProvider;
  final ValidationEvidenceShare _share;
  final ValidationEvidenceExportClock _clock;

  @override
  Future<ValidationEvidenceExportArtifact> saveAndShare(
    String json, {
    Rect? sharePositionOrigin,
    ValidationEvidencePreShareCheck? beforeShare,
  }) async {
    _validateEnvelope(json);
    final DateTime timestamp = _clock().toUtc();
    final Directory directory = await _directoryProvider();
    await directory.create(recursive: true);
    final String fileName =
        'walking-rpg-validation-${_fileTimestamp(timestamp)}.json';
    final File file = File('${directory.path}/$fileName');
    final ValidationEvidenceExportArtifact artifact =
        ValidationEvidenceExportArtifact(
          fileName: fileName,
          path: file.path,
          createdAt: timestamp,
        );
    try {
      await file.writeAsString(json, flush: true);
      beforeShare?.call();
      await _share(artifact, sharePositionOrigin);
      return artifact;
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static void _validateEnvelope(String json) {
    if (json.trim().isEmpty) {
      throw const FormatException('Validation evidence не может быть пустым');
    }
    if (utf8.encode(json).length > maxEncodedBytes) {
      throw const FormatException('Validation evidence превышает 64 KiB');
    }
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != schemaVersion) {
      throw const FormatException(
        'Validation evidence содержит неизвестную schema version',
      );
    }
    final Object? rawChecksum = decoded['checksum'];
    if (rawChecksum is! Map<String, dynamic> ||
        rawChecksum['algorithm'] != 'SHA-256' ||
        rawChecksum['value'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(rawChecksum['value']! as String)) {
      throw const FormatException(
        'Validation evidence не содержит корректный SHA-256 checksum',
      );
    }
    if (!DeviceValidationEvidenceCodec.verify(json)) {
      throw const FormatException(
        'Validation evidence не прошло schema, redaction или checksum review',
      );
    }
  }

  static Future<void> _shareFile(
    ValidationEvidenceExportArtifact artifact,
    Rect? sharePositionOrigin,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(artifact.path, mimeType: 'application/json')],
        fileNameOverrides: <String>[artifact.fileName],
        subject: 'Walking RPG · device validation evidence',
        text: 'Воспроизводимое evidence физической проверки Walking RPG.',
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
