import 'dart:convert';
import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/home/data/auth_home_transports.dart';
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
      transport: DevelopmentHeaderHomeTransport.fromEnvironment(),
      cache: FileReadSnapshotCache.fromEnvironment(),
    );
  }

  static const Duration cacheTtl = Duration(days: 7);
  static const String cacheVariant = 'current';
  static const Set<String> _telemetryOnlyCommands = <String>{
    'RECORD_EXPERIMENT_EXPOSURE',
    'RECORD_COMPASS_IMPRESSION',
  };
  static final Map<String, int> _stateVersionHighWaterMarks = <String, int>{};

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
        headers: <String, String>{'Accept': 'application/json'},
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
    final bool telemetryOnly = _telemetryOnlyCommands.contains(
      normalizedCommandType,
    );
    final int? minimumStateVersion = telemetryOnly
        ? null
        : await _minimumKnownStateVersion();
    ReadSnapshotGenerationToken? cacheWriteToken;
    if (!telemetryOnly) {
      await invalidateReadSnapshotsBeforeMutation(_cache, ownerId: userId);
      cacheWriteToken = captureReadSnapshotGeneration(userId);
    }

    final HomeTransportResponse response = await transport.post(
      uri: baseUri.resolve('/api/v1/platform/commands'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
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
    if (!telemetryOnly && cacheWriteToken != null) {
      await _writePlatformBestEffort(
        payload: jsonEncode(snapshotJson),
        stateVersion: result.snapshot.stateVersion,
        generationToken: cacheWriteToken,
        minimumStateVersion: minimumStateVersion,
        requireKnownBaseline: true,
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
        final PlatformSnapshot snapshot = PlatformSnapshot.fromJson(
          json,
          cacheMetadata: CachedReadMetadata(
            cachedAt: entry.storedAt,
            reason: reason,
          ),
        );
        final int? highWaterMark = _stateVersionHighWaterMark;
        if (highWaterMark != null && snapshot.stateVersion < highWaterMark) {
          await cache.remove(
            ownerId: userId,
            resource: ReadSnapshotResource.platform,
            variant: cacheVariant,
          );
          return null;
        }
        _observeStateVersion(snapshot.stateVersion);
        return snapshot;
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

  Future<int?> _minimumKnownStateVersion() async {
    final ReadSnapshotCache? cache = _cache;
    final int? cachedStateVersion = cache == null
        ? null
        : await _cachedPlatformStateVersionFrom(cache);
    final int? highWaterMark = _stateVersionHighWaterMark;
    if (cachedStateVersion == null) {
      return highWaterMark;
    }
    _observeStateVersion(cachedStateVersion);
    if (highWaterMark == null || cachedStateVersion > highWaterMark) {
      return cachedStateVersion;
    }
    return highWaterMark;
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
        final int stateVersion = PlatformSnapshot.fromJson(json).stateVersion;
        final int? highWaterMark = _stateVersionHighWaterMark;
        if (highWaterMark != null && stateVersion < highWaterMark) {
          await cache.remove(
            ownerId: userId,
            resource: ReadSnapshotResource.platform,
            variant: cacheVariant,
          );
          return null;
        }
        _observeStateVersion(stateVersion);
        return stateVersion;
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
    bool requireKnownBaseline = false,
  }) async {
    final ReadSnapshotCache? cache = _cache;
    if (cache == null || !isReadSnapshotGenerationCurrent(generationToken)) {
      return;
    }
    try {
      final int? cachedStateVersion = await _cachedPlatformStateVersionFrom(
        cache,
      );
      int? requiredStateVersion = minimumStateVersion;
      final int? highWaterMark = _stateVersionHighWaterMark;
      if (highWaterMark != null &&
          (requiredStateVersion == null ||
              highWaterMark > requiredStateVersion)) {
        requiredStateVersion = highWaterMark;
      }
      if (cachedStateVersion != null &&
          (requiredStateVersion == null ||
              cachedStateVersion > requiredStateVersion)) {
        requiredStateVersion = cachedStateVersion;
      }
      if ((requireKnownBaseline && requiredStateVersion == null) ||
          (requiredStateVersion != null &&
              stateVersion < requiredStateVersion) ||
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
        return;
      }
      _observeStateVersion(stateVersion);
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

  String get _stateVersionScopeKey => '${baseUri.origin}|$userId';

  int? get _stateVersionHighWaterMark =>
      _stateVersionHighWaterMarks[_stateVersionScopeKey];

  void _observeStateVersion(int stateVersion) {
    final String key = _stateVersionScopeKey;
    final int? current = _stateVersionHighWaterMarks[key];
    if (current == null || stateVersion > current) {
      _stateVersionHighWaterMarks[key] = stateVersion;
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
