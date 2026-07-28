import 'dart:convert';

import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';

class ActivityApiClient {
  factory ActivityApiClient({
    required Uri baseUri,
    required String userId,
    required String deviceId,
    required HomeTransport transport,
    ReadSnapshotCache? cache,
  }) {
    final String normalizedUserId = _requireText(userId, 'userId');
    final String normalizedDeviceId = _requireText(deviceId, 'deviceId');
    if (baseUri.scheme != 'http' && baseUri.scheme != 'https') {
      throw ArgumentError.value(
        baseUri,
        'baseUri',
        'Поддерживаются только http и https',
      );
    }
    if (baseUri.host.isEmpty) {
      throw ArgumentError.value(baseUri, 'baseUri', 'Host обязателен');
    }

    return ActivityApiClient._(
      baseUri: baseUri,
      userId: normalizedUserId,
      deviceId: normalizedDeviceId,
      transport: transport,
      cache: cache,
    );
  }

  ActivityApiClient._({
    required this.baseUri,
    required this.userId,
    required this.deviceId,
    required this.transport,
    required ReadSnapshotCache? cache,
  }) : _cache = cache;

  factory ActivityApiClient.fromEnvironment() {
    return ActivityApiClient(
      baseUri: Uri.parse(AppEnvironment.apiBaseUrl),
      userId: AppEnvironment.demoUserId,
      deviceId: AppEnvironment.demoDeviceId,
      transport: const IoHomeTransport(),
      cache: FileReadSnapshotCache.fromEnvironment(),
    );
  }

  final Uri baseUri;
  final String userId;
  final String deviceId;
  final HomeTransport transport;
  final ReadSnapshotCache? _cache;

  Future<ActivitySyncResult> sync({
    required StepReading reading,
    required String idempotencyKey,
  }) async {
    final String normalizedKey = _requireText(idempotencyKey, 'idempotencyKey');
    await invalidateReadSnapshotsBeforeMutation(_cache, ownerId: userId);

    final Uri uri = baseUri.resolve('/api/v1/activity/sync');
    final HomeTransportResponse response = await transport.post(
      uri: uri,
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-User-Id': userId,
        'X-Device-Id': deviceId,
      },
      body: jsonEncode(<String, Object?>{
        'localDate': reading.localDateIso,
        'timeZone': reading.timeZone,
        'authoritativeTotal': reading.authoritativeTotal,
        'buckets': const <Object>[],
        'syncCursor': reading.syncCursor,
        'idempotencyKey': normalizedKey,
        'attestation': null,
      }),
    );

    final Object? decoded = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw ActivityApiException(
        statusCode: response.statusCode,
        code: _errorCode(decoded),
        message: _errorMessage(decoded),
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Activity response должен быть JSON-объектом',
      );
    }
    return ActivitySyncResult.fromJson(decoded);
  }

  Object? _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const FormatException('Backend вернул некорректный JSON');
    }
  }

  String _errorCode(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final Object? code = decoded['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }
    return 'ACTIVITY_API_ERROR';
  }

  String _errorMessage(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final Object? message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return 'Backend отклонил синхронизацию активности';
  }

  static String _requireText(String value, String field) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'Значение обязательно');
    }
    return normalized;
  }
}

class ActivityApiException implements Exception {
  const ActivityApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'Activity API $statusCode ($code): $message';
}
