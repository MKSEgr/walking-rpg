import 'package:flutter/foundation.dart';
import 'package:walking_rpg_mobile/core/auth/auth_access_token_provider.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';

final class BearerHomeTransport implements HomeTransport {
  BearerHomeTransport({
    required Uri apiBaseUri,
    required HomeTransport inner,
    required AuthAccessTokenProvider tokenProvider,
  }) : _apiOrigin = apiBaseUri.origin,
       _inner = inner,
       _tokenProvider = tokenProvider;

  static const Set<String> _blockedHeaders = <String>{
    'authorization',
    'x-user-id',
    'x-device-id',
    'x-mock-user',
    'x-mock-authorities',
  };

  final String _apiOrigin;
  final HomeTransport _inner;
  final AuthAccessTokenProvider _tokenProvider;

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) {
    return _send(
      uri: uri,
      headers: headers,
      operation: (Map<String, String> authenticated) =>
          _inner.get(uri: uri, headers: authenticated),
    );
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) {
    return _send(
      uri: uri,
      headers: headers,
      operation: (Map<String, String> authenticated) =>
          _inner.post(uri: uri, headers: authenticated, body: body),
    );
  }

  Future<HomeTransportResponse> _send({
    required Uri uri,
    required Map<String, String> headers,
    required Future<HomeTransportResponse> Function(Map<String, String> headers)
    operation,
  }) async {
    if (uri.origin != _apiOrigin) {
      throw StateError('Bearer token нельзя отправлять за пределы API origin');
    }
    final String accessToken = await _tokenForRequest();
    HomeTransportResponse response = await operation(
      _withBearer(headers, accessToken),
    );
    if (response.statusCode != 401) {
      return response;
    }

    final String refreshedToken;
    try {
      refreshedToken = await _tokenProvider.refreshAfterUnauthorized(
        accessToken,
      );
    } on AuthRefreshUnavailableException catch (error) {
      throw HomeNetworkException(error.toString());
    }
    response = await operation(_withBearer(headers, refreshedToken));
    if (response.statusCode == 401) {
      _tokenProvider.rejectSession(
        'Backend повторно отклонил обновлённую сессию.',
      );
      throw const AuthReauthenticationRequiredException();
    }
    return response;
  }

  Future<String> _tokenForRequest() async {
    try {
      return await _tokenProvider.accessToken();
    } on AuthRefreshUnavailableException catch (error) {
      throw HomeNetworkException(error.toString());
    }
  }

  Map<String, String> _withBearer(Map<String, String> headers, String token) {
    return <String, String>{
      ..._sanitize(headers),
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> _sanitize(Map<String, String> headers) {
    return <String, String>{
      for (final MapEntry<String, String> entry in headers.entries)
        if (!_blockedHeaders.contains(entry.key.toLowerCase()))
          entry.key: entry.value,
    };
  }
}

final class DevelopmentHeaderHomeTransport implements HomeTransport {
  DevelopmentHeaderHomeTransport({
    required String userId,
    required String deviceId,
    HomeTransport inner = const IoHomeTransport(),
  }) : _userId = _requireText(userId, 'userId'),
       _deviceId = _requireText(deviceId, 'deviceId'),
       _inner = inner {
    if (kReleaseMode) {
      throw StateError(
        'Development identity headers запрещены в production build',
      );
    }
  }

  factory DevelopmentHeaderHomeTransport.fromEnvironment({
    HomeTransport inner = const IoHomeTransport(),
  }) {
    final String mode = AppEnvironment.mobileAuthMode.trim().toLowerCase();
    if (mode != 'development' && mode != 'dev' && mode != 'dev-header') {
      throw StateError(
        'Development transport доступен только при '
        'MOBILE_AUTH_MODE=development',
      );
    }
    return DevelopmentHeaderHomeTransport(
      userId: AppEnvironment.demoUserId,
      deviceId: AppEnvironment.demoDeviceId,
      inner: inner,
    );
  }

  static const Set<String> _blockedHeaders = <String>{
    'authorization',
    'x-user-id',
    'x-device-id',
    'x-mock-user',
    'x-mock-authorities',
  };

  final String _userId;
  final String _deviceId;
  final HomeTransport _inner;

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) {
    return _inner.get(uri: uri, headers: _headers(headers));
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) {
    return _inner.post(uri: uri, headers: _headers(headers), body: body);
  }

  Map<String, String> _headers(Map<String, String> headers) {
    return <String, String>{
      for (final MapEntry<String, String> entry in headers.entries)
        if (!_blockedHeaders.contains(entry.key.toLowerCase()))
          entry.key: entry.value,
      'X-User-Id': _userId,
      'X-Device-Id': _deviceId,
    };
  }

  static String _requireText(String value, String field) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'Значение обязательно');
    }
    return normalized;
  }
}
