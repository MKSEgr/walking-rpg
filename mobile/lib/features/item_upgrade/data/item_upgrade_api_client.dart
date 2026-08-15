import 'dart:convert';

import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/home/data/auth_home_transports.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/item_upgrade/domain/item_upgrade_result.dart';

class ItemUpgradeApiClient {
  factory ItemUpgradeApiClient({
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
    return ItemUpgradeApiClient._(
      baseUri: baseUri,
      userId: normalizedUserId,
      transport: transport,
      cache: cache,
    );
  }

  ItemUpgradeApiClient._({
    required this.baseUri,
    required this.userId,
    required this.transport,
    required ReadSnapshotCache? cache,
  }) : _cache = cache;

  factory ItemUpgradeApiClient.fromEnvironment() {
    return ItemUpgradeApiClient(
      baseUri: Uri.parse(AppEnvironment.apiBaseUrl),
      userId: AppEnvironment.demoUserId,
      transport: DevelopmentHeaderHomeTransport.fromEnvironment(),
      cache: FileReadSnapshotCache.fromEnvironment(),
    );
  }

  final Uri baseUri;
  final String userId;
  final HomeTransport transport;
  final ReadSnapshotCache? _cache;

  Future<ItemUpgradeResult> apply({
    required String upgradeId,
    required String idempotencyKey,
  }) async {
    final String normalizedUpgradeId = upgradeId.trim();
    final String normalizedKey = idempotencyKey.trim();
    if (normalizedUpgradeId.isEmpty || normalizedKey.isEmpty) {
      throw ArgumentError('upgradeId и idempotencyKey обязательны');
    }

    await invalidateReadSnapshotsBeforeMutation(_cache, ownerId: userId);

    final Uri uri = baseUri.resolve(
      '/api/v1/item-upgrades/'
      '${Uri.encodeComponent(normalizedUpgradeId)}/apply',
    );
    final HomeTransportResponse response = await transport.post(
      uri: uri,
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, Object>{'idempotencyKey': normalizedKey}),
    );

    final Object? decoded = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw ItemUpgradeApiException(
        statusCode: response.statusCode,
        code: _errorCode(decoded),
        message: _errorMessage(decoded),
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Item upgrade response должен быть JSON-объектом',
      );
    }
    return ItemUpgradeResult.fromJson(decoded);
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
    return 'ITEM_UPGRADE_API_ERROR';
  }

  String _errorMessage(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final Object? message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return 'Backend отклонил улучшение предмета';
  }
}

class ItemUpgradeApiException implements Exception {
  const ItemUpgradeApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'Item upgrade API $statusCode ($code): $message';
}
