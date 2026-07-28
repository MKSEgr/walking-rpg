import 'dart:convert';

import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';

class PlatformApiClient {
  factory PlatformApiClient({
    required Uri baseUri,
    required String userId,
    required HomeTransport transport,
    ReadSnapshotCache? cache,
  }) {
    final String normalizedUserId = _requireText(userId, 'userId');
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
    return PlatformApiClient._(
      baseUri: baseUri,
      userId: normalizedUserId,
      transport: transport,
      cache: cache,
    );
  }

  PlatformApiClient._({
    required this.baseUri,
    required this.userId,
    required this.transport,
    required ReadSnapshotCache? cache,
  }) : _cache = cache;

  factory PlatformApiClient.fromEnvironment() {
    return PlatformApiClient(
      baseUri: Uri.parse(AppEnvironment.apiBaseUrl),
      userId: AppEnvironment.demoUserId,
      transport: const IoHomeTransport(),
      cache: FileReadSnapshotCache.fromEnvironment(),
    );
  }

  static const Duration cacheTtl = Duration(days: 7);
  static const String cacheVariant = 'current';
  static const String _experimentExposureCommand = 'RECORD_EXPERIMENT_EXPOSURE';

  final Uri baseUri;
  final String userId;
  final HomeTransport transport;
  final ReadSnapshotCache? _cache;

  Future<PlatformSnapshot> fetchSnapshot() async {
    final ReadSnapshotGenerationToken cacheWriteToken =
        captureReadSnapshotGeneration(userId);
    try {
      final HomeTransportResponse response = await transport.get(
        uri: baseUri.resolve('/api/v1/platform'),
        headers: <String, String>{
          'Accept': 'application/json',
          'X-User-Id': userId,
        },
      );
      final Object? decoded = _decodeJsonLenient(response.body);
      if (response.statusCode != 200) {
        throw _apiException(response.statusCode, decoded);
      }
      final Map<String, dynamic> json = _requireJsonObject(decoded, 'Platform');
      final PlatformSnapshot snapshot = PlatformSnapshot.fromJson(json);
      await _writePlatformBestEffort(
        payload: jsonEncode(json),
        stateVersion: snapshot.stateVersion,
        generationToken: cacheWriteToken,
      );
      return snapshot;
    } on Object catch (error, stackTrace) {
      if (!_canUseCache(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final PlatformSnapshot? cached = await _readCached(
        reason: _cacheReason(error),
      );
      if (cached != null) {
        return cached;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<PlatformCommandResult> execute({
    required String commandType,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async {
    final String normalizedCommandType = _requireText(
      commandType,
      'commandType',
    ).toUpperCase();
    final String normalizedKey = _requireText(idempotencyKey, 'idempotencyKey');
    final bool recordsExposure =
        normalizedCommandType == _experimentExposureCommand;
    final int? minimumStateVersion = recordsExposure
        ? null
        : await _cachedPlatformStateVersion();
    ReadSnapshotGenerationToken? cacheWriteToken;
    if (!recordsExposure) {
      await invalidateReadSnapshotsBeforeMutation(_cache, ownerId: userId);
      cacheWriteToken = captureReadSnapshotGeneration(userId);
    }

    final HomeTransportResponse response = await transport.post(
      uri: baseUri.resolve('/api/v1/platform/commands'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
      body: jsonEncode(<String, Object?>{
        'commandType': normalizedCommandType,
        'idempotencyKey': normalizedKey,
        'payload': payload,
      }),
    );
    final Object? decoded = _decodeJsonLenient(response.body);
    if (response.statusCode != 200) {
      throw _apiException(response.statusCode, decoded);
    }
    final Map<String, dynamic> json = _requireJsonObject(
      decoded,
      'Platform command',
    );
    final PlatformCommandResult result = PlatformCommandResult.fromJson(json);
    final Map<String, dynamic> snapshotJson = _requireJsonObject(
      json['snapshot'],
      'Platform command snapshot',
    );
    if (!recordsExposure && cacheWriteToken != null) {
      await _writePlatformBestEffort(
        payload: jsonEncode(snapshotJson),
        stateVersion: result.snapshot.stateVersion,
        generationToken: cacheWriteToken,
        minimumStateVersion: minimumStateVersion,
      );
    }
    return result;
  }

  Future<PlatformSnapshot?> _readCached({required String reason}) async {
    final ReadSnapshotCache? cache = _cache;
    if (cache == null) {
      return null;
    }
    try {
      final ReadSnapshotCacheEntry? entry = await cache.read(
        ownerId: userId,
        resource: ReadSnapshotResource.platform,
        variant: cacheVariant,
      );
      if (entry == null) {
        return null;
      }
      try {
        final Map<String, dynamic> json = _requireJsonObject(
          _decodeJsonLenient(entry.payload),
          'Cached platform',
        );
        return PlatformSnapshot.fromJson(
          json,
          cacheMetadata: CachedReadMetadata(
            cachedAt: entry.storedAt,
            reason: reason,
          ),
        );
      } on Object {
        await cache.remove(
          ownerId: userId,
          resource: ReadSnapshotResource.platform,
          variant: cacheVariant,
        );
        return null;
      }
    } on Object {
      return null;
    }
  }

  Future<int?> _cachedPlatformStateVersion() async {
    final ReadSnapshotCache? cache = _cache;
    if (cache == null) {
      return null;
    }
    return _cachedPlatformStateVersionFrom(cache);
  }

  Future<int?> _cachedPlatformStateVersionFrom(ReadSnapshotCache cache) async {
    try {
      final ReadSnapshotCacheEntry? entry = await cache.read(
        ownerId: userId,
        resource: ReadSnapshotResource.platform,
        variant: cacheVariant,
      );
      if (entry == null) {
        return null;
      }
      try {
        final Map<String, dynamic> json = _requireJsonObject(
          _decodeJsonLenient(entry.payload),
          'Cached platform',
        );
        return PlatformSnapshot.fromJson(json).stateVersion;
      } on Object {
        await cache.remove(
          ownerId: userId,
          resource: ReadSnapshotResource.platform,
          variant: cacheVariant,
        );
        return null;
      }
    } on Object {
      return null;
    }
  }

  Future<void> _writePlatformBestEffort({
    required String payload,
    required int stateVersion,
    required ReadSnapshotGenerationToken generationToken,
    int? minimumStateVersion,
  }) async {
    final ReadSnapshotCache? cache = _cache;
    if (cache == null || !isReadSnapshotGenerationCurrent(generationToken)) {
      return;
    }
    try {
      final int? cachedStateVersion = await _cachedPlatformStateVersionFrom(
        cache,
      );
      int requiredStateVersion = minimumStateVersion ?? -1;
      if (cachedStateVersion != null &&
          cachedStateVersion > requiredStateVersion) {
        requiredStateVersion = cachedStateVersion;
      }
      if (stateVersion < requiredStateVersion ||
          !isReadSnapshotGenerationCurrent(generationToken)) {
        return;
      }
      await cache.write(
        ownerId: userId,
        resource: ReadSnapshotResource.platform,
        variant: cacheVariant,
        payload: payload,
        ttl: cacheTtl,
      );
      if (!isReadSnapshotGenerationCurrent(generationToken)) {
        await _removePayloadIfCurrent(cache: cache, payload: payload);
      }
    } on Object {
      // Do not keep an older snapshot after a newer authoritative response.
      try {
        await cache.invalidateOwner(
          ownerId: userId,
          resources: const <ReadSnapshotResource>{
            ReadSnapshotResource.platform,
          },
        );
      } on Object {
        // A fresh response remains usable even when local storage is broken.
      }
    }
  }

  Future<void> _removePayloadIfCurrent({
    required ReadSnapshotCache cache,
    required String payload,
  }) async {
    try {
      final ReadSnapshotCacheEntry? current = await cache.read(
        ownerId: userId,
        resource: ReadSnapshotResource.platform,
        variant: cacheVariant,
      );
      if (current?.payload == payload) {
        await cache.remove(
          ownerId: userId,
          resource: ReadSnapshotResource.platform,
          variant: cacheVariant,
        );
      }
    } on Object {
      // Best effort cleanup: never fail the successful network read.
    }
  }

  bool _canUseCache(Object error) {
    if (error is HomeNetworkException || error is FormatException) {
      return true;
    }
    if (error is PlatformApiException) {
      return error.statusCode == 408 ||
          error.statusCode == 429 ||
          (error.statusCode >= 500 && error.statusCode < 600);
    }
    return false;
  }

  Object? _decodeJsonLenient(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> _requireJsonObject(Object? value, String label) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('$label response должен быть JSON-объектом');
    }
    return value.map<String, dynamic>((Object? key, Object? item) {
      if (key is! String) {
        throw FormatException('Ключи $label response должны быть строками');
      }
      return MapEntry<String, dynamic>(key, item);
    });
  }

  PlatformApiException _apiException(int statusCode, Object? decoded) {
    if (decoded is Map<Object?, Object?>) {
      final Map<String, dynamic> json = decoded.map<String, dynamic>((
        Object? key,
        Object? item,
      ) {
        if (key is! String) {
          return MapEntry<String, dynamic>('', item);
        }
        return MapEntry<String, dynamic>(key, item);
      });
      return PlatformApiException(
        statusCode: statusCode,
        code: _optionalString(json, 'code') ?? 'PLATFORM_API_ERROR',
        message:
            _optionalString(json, 'message') ??
            'Backend отклонил platform-запрос',
        details: _optionalMap(json['details']),
      );
    }
    return PlatformApiException(
      statusCode: statusCode,
      code: 'PLATFORM_API_ERROR',
      message: 'Backend отклонил platform-запрос',
      details: const <String, Object?>{},
    );
  }

  String _cacheReason(Object error) {
    if (error is PlatformApiException) {
      if (error.statusCode == 408) {
        return 'Backend не ответил вовремя';
      }
      if (error.statusCode == 429) {
        return 'Backend временно ограничил запросы';
      }
      return 'Backend временно недоступен';
    }
    if (error is FormatException) {
      return 'Backend вернул некорректное состояние';
    }
    return 'Нет соединения с сервером';
  }

  static String _requireText(String value, String field) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'Значение обязательно');
    }
    return normalized;
  }

  static String? _optionalString(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  static Map<String, Object?> _optionalMap(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return const <String, Object?>{};
    }
    return value.map<String, Object?>((Object? key, Object? item) {
      if (key is! String) {
        throw const FormatException('Ключи details должны быть строками');
      }
      return MapEntry<String, Object?>(key, item);
    });
  }
}

class PlatformApiException implements Exception {
  const PlatformApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => 'Platform API $statusCode ($code): $message';
}
