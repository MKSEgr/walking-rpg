import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

class IoHomeTransport implements HomeTransport {
  const IoHomeTransport({
    this.timeout = const Duration(seconds: 10),
  });

  final Duration timeout;

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;

    try {
      final HttpClientRequest request =
          await client.getUrl(uri).timeout(timeout);
      headers.forEach(
        (String name, String value) => request.headers.set(name, value),
      );
      final HttpClientResponse response =
          await request.close().timeout(timeout);
      final String body =
          await utf8.decoder.bind(response).join().timeout(timeout);

      return HomeTransportResponse(
        statusCode: response.statusCode,
        body: body,
      );
    } on TimeoutException {
      throw const HomeNetworkException('Превышено время ожидания backend');
    } on SocketException catch (exception) {
      throw HomeNetworkException(
        'Не удалось подключиться к backend: ${exception.message}',
      );
    } finally {
      client.close(force: true);
    }
  }
}

class HomeNetworkException implements Exception {
  const HomeNetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}
