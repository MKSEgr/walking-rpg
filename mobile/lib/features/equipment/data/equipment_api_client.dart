import 'dart:convert';

import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/equipment/domain/equipment_result.dart';
import 'package:walking_rpg_mobile/features/home/data/auth_home_transports.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

class EquipmentApiClient {
  factory EquipmentApiClient({
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
    return EquipmentApiClient._(
      baseUri: baseUri,
      userId: normalizedUserId,
      transport: transport,
      cache: cache,
    );
  }

  EquipmentApiClient._({
    required this.baseUri,
    required this.userId,
    required this.transport,
    required ReadSnapshotCache? cache,
  }) : _cache = cache;

  factory EquipmentApiClient.fromEnvironment() {
    return EquipmentApiClient(
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

  Future<EquipmentResult> change({
    required String slotId,
    required String action,
    required String? itemInstanceId,
    required String idempotencyKey,
  }) async {
    final String normalizedSlotId = slotId.trim();
    final String normalizedAction = action.trim().toUpperCase();
    final String normalizedKey = idempotencyKey.trim();
    final String? normalizedItem = itemInstanceId?.trim();
    if (normalizedSlotId.isEmpty || normalizedKey.isEmpty) {
      throw ArgumentError('slotId и idempotencyKey обязательны');
    }
    if (normalizedAction != 'EQUIP' && normalizedAction != 'UNEQUIP') {
      throw ArgumentError.value(
        action,
        'action',
        'Ожидается EQUIP или UNEQUIP',
      );
    }
    if (normalizedAction == 'EQUIP' &&
        (normalizedItem == null || normalizedItem.isEmpty)) {
      throw ArgumentError('EQUIP требует itemInstanceId');
    }
    if (normalizedAction == 'UNEQUIP' &&
        normalizedItem != null &&
        normalizedItem.isNotEmpty) {
      throw ArgumentError('UNEQUIP не принимает itemInstanceId');
    }

    await invalidateReadSnapshotsBeforeMutation(_cache, ownerId: userId);

    final Uri uri = baseUri.resolve(
      '/api/v1/equipment/slots/'
      '${Uri.encodeComponent(normalizedSlotId)}/'
      '${normalizedAction == 'EQUIP' ? 'equip' : 'unequip'}',
    );
    final Map<String, Object> body = <String, Object>{
      'idempotencyKey': normalizedKey,
    };
    if (normalizedAction == 'EQUIP') {
      body['itemInstanceId'] = normalizedItem!;
    }
    final HomeTransportResponse response = await transport.post(
      uri: uri,
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final Object? decoded = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw EquipmentApiException(
        statusCode: response.statusCode,
        code: _errorCode(decoded),
        message: _errorMessage(decoded),
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Equipment response должен быть JSON-объектом',
      );
    }
    return EquipmentResult.fromJson(decoded);
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
    return 'EQUIPMENT_API_ERROR';
  }

  String _errorMessage(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final Object? message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return 'Backend отклонил изменение снаряжения';
  }
}

class EquipmentApiException implements Exception {
  const EquipmentApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'Equipment API $statusCode ($code): $message';
}
