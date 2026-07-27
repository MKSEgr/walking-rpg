import 'dart:convert';

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
    );
  }

  PlatformApiClient._({
    required this.baseUri,
    required this.userId,
    required this.transport,
  });

  factory PlatformApiClient.fromEnvironment() {
    return PlatformApiClient(
      baseUri: Uri.parse(AppEnvironment.apiBaseUrl),
      userId: AppEnvironment.demoUserId,
      transport: const IoHomeTransport(),
    );
  }

  final Uri baseUri;
  final String userId;
  final HomeTransport transport;

  Future<PlatformSnapshot> fetchSnapshot() async {
    final HomeTransportResponse response = await transport.get(
      uri: baseUri.resolve('/api/v1/platform'),
      headers: <String, String>{
        'Accept': 'application/json',
        'X-User-Id': userId,
      },
    );
    final Object? decoded = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw _apiException(response.statusCode, decoded);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Platform response должен быть JSON-объектом',
      );
    }
    return PlatformSnapshot.fromJson(decoded);
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
    final Object? decoded = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw _apiException(response.statusCode, decoded);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Platform command response должен быть JSON-объектом',
      );
    }
    return PlatformCommandResult.fromJson(decoded);
  }

  Object? _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const FormatException('Backend вернул некорректный JSON');
    }
  }

  PlatformApiException _apiException(int statusCode, Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      return PlatformApiException(
        statusCode: statusCode,
        code: _optionalString(decoded, 'code') ?? 'PLATFORM_API_ERROR',
        message:
            _optionalString(decoded, 'message') ??
            'Backend отклонил platform-запрос',
        details: _optionalMap(decoded['details']),
      );
    }
    return PlatformApiException(
      statusCode: statusCode,
      code: 'PLATFORM_API_ERROR',
      message: 'Backend отклонил platform-запрос',
      details: const <String, Object?>{},
    );
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
