import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';

void main() {
  test('only transient OAuth responses are retryable', () {
    expect(
      FlutterAppAuthOidcClient.isRetryableOAuthError('server_error'),
      isTrue,
    );
    expect(
      FlutterAppAuthOidcClient.isRetryableOAuthError(
        'temporarily_unavailable',
      ),
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
}
