import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

class IoHomeTransport implements HomeTransport {
  const IoHomeTransport({this.timeout = const Duration(seconds: 10)});

  final Duration timeout;

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) {
    return _send(method: 'GET', uri: uri, headers: headers);
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) {
    return _send(method: 'POST', uri: uri, headers: headers, body: body);
  }

  Future<HomeTransportResponse> _send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;

    try {
      final HttpClientRequest request = await client
          .openUrl(method, uri)
          .timeout(timeout);
      // Redirects are returned to the caller. Following them inside this
      // low-level transport could carry a Bearer token to a different origin.
      request.followRedirects = false;
      headers.forEach(
        (String name, String value) => request.headers.set(name, value),
      );
      if (body != null) {
        request.add(utf8.encode(body));
      }
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      final String responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);

      return HomeTransportResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } on TimeoutException {
      throw const HomeNetworkException('Превышено время ожидания backend');
    } on SocketException catch (exception) {
      throw HomeNetworkException(
        'Не удалось подключиться к backend: ${exception.message}',
      );
    } on IOException catch (exception) {
      throw HomeNetworkException('Ошибка соединения с backend: $exception');
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
