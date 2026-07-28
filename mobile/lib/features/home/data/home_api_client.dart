import 'dart:convert';
import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/home/data/auth_home_transports.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';

class HomeApiClient {
  factory HomeApiClient({
    required Uri baseUri,
    required String userId,
    required HomeTransport transport,
    ReadSnapshotCache? cache,
  }) {
    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Значение обязательно');
    }
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

    return HomeApiClient._(
      baseUri: baseUri,
      userId: normalizedUserId,
      transport: transport,
      cache: cache,
    );
  }

  HomeApiClient._({
    required this.baseUri,
    required this.userId,
    required this.transport,
    required ReadSnapshotCache? cache,
  }) : _cache = cache;

  factory HomeApiClient.fromEnvironment() {
    return HomeApiClient(
      baseUri: Uri.parse(AppEnvironment.apiBaseUrl),
      userId: AppEnvironment.demoUserId,
      transport: DevelopmentHeaderHomeTransport.fromEnvironment(),
      cache: FileReadSnapshotCache.fromEnvironment(),
    );
  }

  static const Duration cacheTtl = Duration(hours: 36);

  final Uri baseUri;
  final String userId;
  final HomeTransport transport;
  final ReadSnapshotCache? _cache;

  Future<HomeSnapshot> fetchHome(DateTime localDate) async {
    final String localDateIso = _formatLocalDate(localDate);
    final ReadSnapshotGenerationToken cacheWriteToken =
        captureReadSnapshotGeneration(userId);
    try {
      final Uri uri = baseUri
          .resolve('/api/v1/home')
          .replace(
            queryParameters: <String, String>{'localDate': localDateIso},
          );
      final HomeTransportResponse response = await transport.get(
        uri: uri,
        headers: <String, String>{'Accept': 'application/json'},
      );
      final Object? decoded = _decodeJsonLenient(response.body);
      if (response.statusCode != 200) {
        throw HomeApiException(
          statusCode: response.statusCode,
          message: _errorMessage(decoded),
        );
      }
      final Map<String, dynamic> json = _requireJsonObject(decoded, 'Home');
      final HomeSnapshot snapshot = HomeSnapshot.fromJson(json);
      await _writeCacheBestEffort(
        variant: localDateIso,
        payload: jsonEncode(json),
        generationToken: cacheWriteToken,
      );
      return snapshot;
    } on Object catch (error, stackTrace) {
      if (!_canUseCache(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final HomeSnapshot? cached = await _readCached(
        variant: localDateIso,
        reason: _cacheReason(error),
      );
      if (cached != null) {
        return cached;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<HomeSnapshot?> _readCached({
    required String variant,
    required String reason,
  }) async {
    final ReadSnapshotCache? cache = _cache;
    if (cache == null) {
      return null;
    }
    try {
      final ReadSnapshotCacheEntry? entry = await cache.read(
        ownerId: userId,
        resource: ReadSnapshotResource.home,
        variant: variant,
      );
      if (entry == null) {
        return null;
      }
      try {
        final Map<String, dynamic> json = _requireJsonObject(
          _decodeJsonLenient(entry.payload),
          'Cached home',
        );
        return HomeSnapshot.fromJson(
          json,
          cacheMetadata: CachedReadMetadata(
            cachedAt: entry.storedAt,
            reason: reason,
          ),
        );
      } on Object {
        await cache.remove(
          ownerId: userId,
          resource: ReadSnapshotResource.home,
          variant: variant,
        );
        return null;
      }
    } on Object {
      return null;
    }
  }

  Future<void> _writeCacheBestEffort({
    required String variant,
    required String payload,
    required ReadSnapshotGenerationToken generationToken,
  }) async {
    final ReadSnapshotCache? cache = _cache;
    if (cache == null || !isReadSnapshotGenerationCurrent(generationToken)) {
      return;
    }
    try {
      await cache.write(
        ownerId: userId,
        resource: ReadSnapshotResource.home,
        variant: variant,
        payload: payload,
        ttl: cacheTtl,
      );
      if (!isReadSnapshotGenerationCurrent(generationToken)) {
        await _removePayloadIfCurrent(
          cache: cache,
          variant: variant,
          payload: payload,
        );
      }
    } on Object {
      // Do not keep an older snapshot after a newer authoritative response.
      try {
        await cache.remove(
          ownerId: userId,
          resource: ReadSnapshotResource.home,
          variant: variant,
        );
      } on Object {
        // A fresh response remains usable even when local storage is broken.
      }
    }
  }

  Future<void> _removePayloadIfCurrent({
    required ReadSnapshotCache cache,
    required String variant,
    required String payload,
  }) async {
    try {
      final ReadSnapshotCacheEntry? current = await cache.read(
        ownerId: userId,
        resource: ReadSnapshotResource.home,
        variant: variant,
      );
      if (current?.payload == payload) {
        await cache.remove(
          ownerId: userId,
          resource: ReadSnapshotResource.home,
          variant: variant,
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
    if (error is HomeApiException) {
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

  Map<String, dynamic> _requireJsonObject(Object? decoded, String label) {
    if (decoded is! Map<Object?, Object?>) {
      throw FormatException('$label response должен быть JSON-объектом');
    }
    return decoded.map<String, dynamic>((Object? key, Object? value) {
      if (key is! String) {
        throw FormatException('Ключи $label response должны быть строками');
      }
      return MapEntry<String, dynamic>(key, value);
    });
  }

  String _errorMessage(Object? decoded) {
    if (decoded is Map<Object?, Object?>) {
      final Object? message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return 'Backend отклонил запрос главного экрана';
  }

  String _cacheReason(Object error) {
    if (error is HomeApiException) {
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

  String _formatLocalDate(DateTime value) {
    final DateTime local = value.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class HomeApiException implements Exception {
  const HomeApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'Home API $statusCode: $message';
}
