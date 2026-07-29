import 'dart:convert';

import 'package:walking_rpg_mobile/features/account/domain/account_deletion_receipt.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

final class AccountApiClient {
  AccountApiClient({required Uri baseUri, required HomeTransport transport})
    : baseUri = _validatedBaseUri(baseUri),
      _transport = transport;

  final Uri baseUri;
  final HomeTransport _transport;

  Future<String> exportAccount() async {
    final HomeTransportResponse response = await _transport.get(
      uri: baseUri.resolve('/api/v1/account/export'),
      headers: const <String, String>{'Accept': 'application/json'},
    );
    final Object? decoded = _decodeJsonLenient(response.body);
    if (response.statusCode != 200) {
      throw _apiException(response.statusCode, decoded);
    }
    final Map<String, dynamic> document = _requireJsonObject(
      decoded,
      'Account export',
    );
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  Future<AccountDeletionReceipt> requestDeletion({
    required String idempotencyKey,
  }) async {
    final String normalizedKey = _requireText(idempotencyKey, 'idempotencyKey');
    final HomeTransportResponse response = await _transport.post(
      uri: baseUri.resolve('/api/v1/account/deletion-requests'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Idempotency-Key': normalizedKey,
      },
      body: jsonEncode(const <String, String>{'confirmation': 'DELETE'}),
    );
    final Object? decoded = _decodeJsonLenient(response.body);
    if (response.statusCode != 200) {
      throw _apiException(response.statusCode, decoded);
    }
    return AccountDeletionReceipt.fromJson(
      _requireJsonObject(decoded, 'Account deletion'),
    );
  }

  static Uri _validatedBaseUri(Uri value) {
    if ((value.scheme != 'http' && value.scheme != 'https') ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.hasQuery ||
        value.hasFragment) {
      throw ArgumentError.value(
        value,
        'baseUri',
        'Нужен абсолютный HTTP(S) URI без userInfo, query и fragment',
      );
    }
    return value;
  }

  static Object? _decodeJsonLenient(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic> _requireJsonObject(Object? value, String label) {
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

  static AccountApiException _apiException(int statusCode, Object? decoded) {
    if (decoded is Map<Object?, Object?>) {
      final Map<String, dynamic> json = decoded.map<String, dynamic>((
        Object? key,
        Object? value,
      ) {
        return MapEntry<String, dynamic>(key is String ? key : '', value);
      });
      return AccountApiException(
        statusCode: statusCode,
        code: _optionalString(json['code']) ?? 'ACCOUNT_API_ERROR',
        message:
            _optionalString(json['message']) ??
            'Backend отклонил запрос управления аккаунтом',
        details: _optionalMap(json['details']),
      );
    }
    return AccountApiException(
      statusCode: statusCode,
      code: 'ACCOUNT_API_ERROR',
      message: 'Backend отклонил запрос управления аккаунтом',
    );
  }

  static String _requireText(String value, String field) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'Значение обязательно');
    }
    return normalized;
  }

  static String? _optionalString(Object? value) {
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
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

final class AccountApiException implements Exception {
  const AccountApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, Object?> details;

  bool get retryable =>
      statusCode == 408 ||
      statusCode == 429 ||
      (statusCode >= 500 && statusCode < 600);

  @override
  String toString() => 'Account API $statusCode ($code): $message';
}
