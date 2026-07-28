import 'dart:convert';
import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';
import 'package:walking_rpg_mobile/features/home/data/auth_home_transports.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

class ExpeditionApiClient {
  factory ExpeditionApiClient({
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

    return ExpeditionApiClient._(
      baseUri: baseUri,
      userId: normalizedUserId,
      transport: transport,
      cache: cache,
    );
  }

  ExpeditionApiClient._({
    required this.baseUri,
    required this.userId,
    required this.transport,
    required ReadSnapshotCache? cache,
  }) : _cache = cache;

  factory ExpeditionApiClient.fromEnvironment() {
    return ExpeditionApiClient(
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

  Future<ExpeditionAdvanceResult> advance({
    required String expeditionId,
    required int energyToSpend,
    required String idempotencyKey,
  }) async {
    if (energyToSpend <= 0) {
      throw ArgumentError.value(
        energyToSpend,
        'energyToSpend',
        'Значение должно быть положительным',
      );
    }
    final String normalizedExpeditionId = expeditionId.trim();
    final String normalizedKey = idempotencyKey.trim();
    if (normalizedExpeditionId.isEmpty || normalizedKey.isEmpty) {
      throw ArgumentError('expeditionId и idempotencyKey обязательны');
    }

    await invalidateReadSnapshotsBeforeMutation(_cache, ownerId: userId);

    final Uri uri = baseUri.resolve(
      '/api/v1/expeditions/${Uri.encodeComponent(normalizedExpeditionId)}/advance',
    );
    final HomeTransportResponse response = await transport.post(
      uri: uri,
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, Object>{
        'energyToSpend': energyToSpend,
        'idempotencyKey': normalizedKey,
      }),
    );

    final Object? decoded = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw ExpeditionApiException(
        statusCode: response.statusCode,
        code: _errorCode(decoded),
        message: _errorMessage(decoded),
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expedition response должен быть JSON-объектом',
      );
    }
    return ExpeditionAdvanceResult.fromJson(decoded);
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
    return 'EXPEDITION_API_ERROR';
  }

  String _errorMessage(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final Object? message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return 'Backend отклонил продвижение экспедиции';
  }
}

class ExpeditionApiException implements Exception {
  const ExpeditionApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'Expedition API $statusCode ($code): $message';
}
