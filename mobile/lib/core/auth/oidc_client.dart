import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';

abstract interface class OidcAuthorizationClient {
  Future<OidcTokenResponseData> authorize(OidcConfiguration configuration);

  Future<OidcTokenResponseData> refresh(
    OidcConfiguration configuration, {
    required String refreshToken,
  });

  Future<void> endSession(
    OidcConfiguration configuration, {
    required String idToken,
  });
}

final class FlutterAppAuthOidcClient implements OidcAuthorizationClient {
  const FlutterAppAuthOidcClient({
    FlutterAppAuth appAuth = const FlutterAppAuth(),
  }) : _appAuth = appAuth;

  final FlutterAppAuth _appAuth;

  @override
  Future<OidcTokenResponseData> authorize(
    OidcConfiguration configuration,
  ) async {
    final AuthorizationTokenResponse response = await _translate(
      () => _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          configuration.clientId,
          configuration.redirectUri.toString(),
          issuer: configuration.issuer.toString(),
          scopes: configuration.scopes,
          allowInsecureConnections: configuration.allowInsecureConnections,
        ),
      ),
    );
    return _fromResponse(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiration: response.accessTokenExpirationDateTime,
      idToken: response.idToken,
      tokenType: response.tokenType,
      scopes: response.scopes,
    );
  }

  @override
  Future<OidcTokenResponseData> refresh(
    OidcConfiguration configuration, {
    required String refreshToken,
  }) async {
    final TokenResponse response = await _translate(
      () => _appAuth.token(
        TokenRequest(
          configuration.clientId,
          configuration.redirectUri.toString(),
          issuer: configuration.issuer.toString(),
          refreshToken: refreshToken,
          scopes: configuration.scopes,
          allowInsecureConnections: configuration.allowInsecureConnections,
        ),
      ),
    );
    return _fromResponse(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiration: response.accessTokenExpirationDateTime,
      idToken: response.idToken,
      tokenType: response.tokenType,
      scopes: response.scopes,
    );
  }

  @override
  Future<void> endSession(
    OidcConfiguration configuration, {
    required String idToken,
  }) async {
    await _translate(
      () => _appAuth.endSession(
        EndSessionRequest(
          idTokenHint: idToken,
          postLogoutRedirectUrl: configuration.postLogoutRedirectUri.toString(),
          issuer: configuration.issuer.toString(),
          allowInsecureConnections: configuration.allowInsecureConnections,
        ),
      ),
    );
  }

  @visibleForTesting
  static bool isRetryableOAuthError(String? oauthError) {
    return oauthError == null ||
        oauthError == 'server_error' ||
        oauthError == 'temporarily_unavailable';
  }

  OidcTokenResponseData _fromResponse({
    required String? accessToken,
    required String? refreshToken,
    required DateTime? expiration,
    required String? idToken,
    required String? tokenType,
    required List<String>? scopes,
  }) {
    final String? normalizedToken = accessToken?.trim();
    if (normalizedToken == null || normalizedToken.isEmpty) {
      throw const AuthProviderException(
        'Identity provider не вернул access token',
        retryable: false,
      );
    }
    final DateTime? resolvedExpiration =
        expiration?.toUtc() ?? tokenExpirationFromJwt(normalizedToken);
    if (resolvedExpiration == null) {
      throw const AuthProviderException(
        'Identity provider не вернул срок действия access token',
        retryable: false,
      );
    }
    return OidcTokenResponseData(
      accessToken: normalizedToken,
      accessTokenExpiration: resolvedExpiration,
      refreshToken: refreshToken,
      idToken: idToken,
      tokenType: tokenType,
      scopes: scopes,
    );
  }

  Future<T> _translate<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FlutterAppAuthUserCancelledException catch (_, stackTrace) {
      Error.throwWithStackTrace(const AuthUserCancelledException(), stackTrace);
    } on FlutterAppAuthPlatformException catch (error, stackTrace) {
      final String? oauthError = error.platformErrorDetails.error;
      if (oauthError == FlutterAppAuthOAuthError.invalidGrant) {
        Error.throwWithStackTrace(
          const AuthInvalidGrantException(),
          stackTrace,
        );
      }
      final bool retryable = isRetryableOAuthError(oauthError);
      Error.throwWithStackTrace(
        AuthProviderException(
          error.platformErrorDetails.errorDescription ??
              error.message ??
              'Ошибка identity provider',
          code: oauthError ?? error.code,
          retryable: retryable,
        ),
        stackTrace,
      );
    } on AuthProviderException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AuthProviderException(
          'Не удалось выполнить OIDC-операцию: $error',
          retryable: true,
        ),
        stackTrace,
      );
    }
  }
}

final class AuthUserCancelledException implements Exception {
  const AuthUserCancelledException();

  @override
  String toString() => 'Авторизация отменена пользователем';
}

final class AuthInvalidGrantException implements Exception {
  const AuthInvalidGrantException();

  @override
  String toString() => 'Refresh token больше не действителен';
}

final class AuthProviderException implements Exception {
  const AuthProviderException(
    this.message, {
    required this.retryable,
    this.code,
  });

  final String message;
  final String? code;
  final bool retryable;

  @override
  String toString() => message;
}
