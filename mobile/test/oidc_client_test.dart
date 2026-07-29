import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';

void main() {
  test('only transient OAuth responses are retryable', () {
    expect(
      FlutterAppAuthOidcClient.isRetryableOAuthError('server_error'),
      isTrue,
    );
    expect(
      FlutterAppAuthOidcClient.isRetryableOAuthError('temporarily_unavailable'),
      isTrue,
    );
    expect(FlutterAppAuthOidcClient.isRetryableOAuthError(null), isTrue);

    for (final String permanentError in <String>[
      'invalid_request',
      'invalid_client',
      'unauthorized_client',
      'unsupported_grant_type',
      'invalid_scope',
      'access_denied',
    ]) {
      expect(
        FlutterAppAuthOidcClient.isRetryableOAuthError(permanentError),
        isFalse,
        reason: permanentError,
      );
    }
  });

  test('fresh authorization requests login and max_age zero', () async {
    final _RecordingAppAuth appAuth = _RecordingAppAuth();
    final FlutterAppAuthOidcClient client = FlutterAppAuthOidcClient(
      appAuth: appAuth,
    );

    await client.authorize(_oidc(), forceLogin: true);

    expect(appAuth.lastAuthorization?.promptValues, <String>['login']);
    expect(appAuth.lastAuthorization?.additionalParameters, <String, String>{
      'max_age': '0',
    });
  });
}

final class _RecordingAppAuth extends FlutterAppAuth {
  AuthorizationTokenRequest? lastAuthorization;

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async {
    lastAuthorization = request;
    return AuthorizationTokenResponse(
      'access-token',
      'refresh-token',
      DateTime.utc(2026, 7, 29, 6),
      'id-token',
      'Bearer',
      const <String>['openid'],
      const <String, dynamic>{},
      const <String, dynamic>{},
    );
  }
}

OidcConfiguration _oidc() {
  return OidcConfiguration(
    issuer: Uri.parse('https://identity.example/realms/walking'),
    clientId: 'walking-mobile',
    redirectUri: Uri.parse('com.walkingrpg.app:/oauthredirect'),
    postLogoutRedirectUri: Uri.parse('com.walkingrpg.app:/logout'),
    scopes: const <String>['openid'],
    allowInsecureConnections: false,
  );
}
