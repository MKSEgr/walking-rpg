import 'dart:convert';
import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/home/data/auth_home_transports.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

class EventApiClient {
  factory EventApiClient({
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
    return EventApiClient._(
      baseUri: baseUri,
      userId: normalizedUserId,
      transport: transport,
      cache: cache,
    );
  }

  EventApiClient._({
    required this.baseUri,
    required this.userId,
    required this.transport,
    required ReadSnapshotCache? cache,
  }) : _cache = cache;

  factory EventApiClient.fromEnvironment() {
    return EventApiClient(
      baseUri: Uri.parse(AppEnvironment.apiBaseUrl),
      userId: AppEnvironment.demoUserId,
      transport: DevelopmentHeaderHomeTransport.fromEnvironment(),
      cache: FileReadSnapshotCache.fromEnvironment(),
    );
  }

  static const String durableHandoffCapability = 'durable-event-result-v1';
  static const String clientCapabilitiesHeader = 'X-Walking-RPG-Capabilities';

  final Uri baseUri;
  final String userId;
  final HomeTransport transport;
  final ReadSnapshotCache? _cache;

  Future<EventResolutionResult> resolve({
    required String eventId,
    required String choiceId,
    required String idempotencyKey,
  }) async {
    final String normalizedEventId = eventId.trim();
    final String normalizedChoiceId = choiceId.trim();
    final String normalizedKey = idempotencyKey.trim();
    if (normalizedEventId.isEmpty ||
        normalizedChoiceId.isEmpty ||
        normalizedKey.isEmpty) {
      throw ArgumentError('eventId, choiceId и idempotencyKey обязательны');
    }

    await invalidateReadSnapshotsBeforeMutation(_cache, ownerId: userId);

    final Uri uri = baseUri.resolve(
      '/api/v1/events/${Uri.encodeComponent(normalizedEventId)}/resolve',
    );
    final HomeTransportResponse response = await transport.post(
      uri: uri,
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        clientCapabilitiesHeader: durableHandoffCapability,
      },
      body: jsonEncode(<String, Object>{
        'choiceId': normalizedChoiceId,
        'idempotencyKey': normalizedKey,
      }),
    );

    final Object? decoded = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw EventApiException(
        statusCode: response.statusCode,
        code: _errorCode(decoded),
        message: _errorMessage(decoded),
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Event response должен быть JSON-объектом');
    }
    return EventResolutionResult.fromJson(decoded);
  }

  Future<EventResultAcknowledgement> acknowledge({
    required String receiptId,
  }) async {
    final String normalizedReceiptId = receiptId.trim();
    if (normalizedReceiptId.isEmpty) {
      throw ArgumentError('receiptId обязателен');
    }

    await invalidateReadSnapshotsBeforeMutation(_cache, ownerId: userId);

    final Uri uri = baseUri.resolve(
      '/api/v1/event-results/'
      '${Uri.encodeComponent(normalizedReceiptId)}/acknowledge',
    );
    final HomeTransportResponse response = await transport.post(
      uri: uri,
      headers: <String, String>{'Accept': 'application/json'},
      body: '',
    );

    final Object? decoded = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw EventApiException(
        statusCode: response.statusCode,
        code: _errorCode(decoded),
        message: _errorMessage(
          decoded,
          fallback: 'Backend отклонил подтверждение результата события',
        ),
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Event acknowledgement response должен быть JSON-объектом',
      );
    }
    return EventResultAcknowledgement.fromJson(decoded);
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
    return 'EVENT_API_ERROR';
  }

  String _errorMessage(
    Object? decoded, {
    String fallback = 'Backend отклонил выбор события',
  }) {
    if (decoded is Map<String, dynamic>) {
      final Object? message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }
}

class EventApiException implements Exception {
  const EventApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'Event API $statusCode ($code): $message';
}
