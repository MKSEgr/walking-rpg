import 'dart:convert';

import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';

class HomeApiClient {
  factory HomeApiClient({
    required Uri baseUri,
    required String userId,
    required HomeTransport transport,
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
    );
  }

  HomeApiClient._({
    required this.baseUri,
    required this.userId,
    required this.transport,
  });

  factory HomeApiClient.fromEnvironment() {
    return HomeApiClient(
      baseUri: Uri.parse(AppEnvironment.apiBaseUrl),
      userId: AppEnvironment.demoUserId,
      transport: const IoHomeTransport(),
    );
  }

  final Uri baseUri;
  final String userId;
  final HomeTransport transport;

  Future<HomeSnapshot> fetchHome(DateTime localDate) async {
    final Uri uri = baseUri
        .resolve('/api/v1/home')
        .replace(
          queryParameters: <String, String>{
            'localDate': _formatLocalDate(localDate),
          },
        );
    final HomeTransportResponse response = await transport.get(
      uri: uri,
      headers: <String, String>{
        'Accept': 'application/json',
        'X-User-Id': userId,
      },
    );

    final Object? decoded = _decodeJson(response.body);
    if (response.statusCode != 200) {
      throw HomeApiException(
        statusCode: response.statusCode,
        message: _errorMessage(decoded),
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Home response должен быть JSON-объектом');
    }

    return HomeSnapshot.fromJson(decoded);
  }

  Object? _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const FormatException('Backend вернул некорректный JSON');
    }
  }

  String _errorMessage(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final Object? message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return 'Backend отклонил запрос главного экрана';
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
