import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';

void main() {
  test('derives an opaque stable owner partition from issuer and subject', () {
    final OidcConfiguration configuration = _configuration();
    final String idToken = _jwt(<String, Object?>{
      'iss': configuration.issuer.toString(),
      'sub': 'employee-123',
      'preferred_username': 'max.egorov',
      'exp': 2000000000,
    });
    final AuthSession first = AuthSession.fromResponse(
      configuration: configuration,
      response: OidcTokenResponseData(
        accessToken: _jwt(<String, Object?>{
          'iss': configuration.issuer.toString(),
          'sub': 'employee-123',
          'exp': 2000000000,
        }),
        accessTokenExpiration: DateTime.fromMillisecondsSinceEpoch(
          2000000000 * 1000,
          isUtc: true,
        ),
        idToken: idToken,
        refreshToken: 'refresh-1',
      ),
    );
    final AuthSession second = AuthSession.fromResponse(
      configuration: configuration,
      response: OidcTokenResponseData(
        accessToken: first.tokens.accessToken,
        accessTokenExpiration: first.tokens.accessTokenExpiration,
        idToken: idToken,
        refreshToken: 'refresh-2',
      ),
    );

    expect(first.identity.ownerId, second.identity.ownerId);
    expect(first.identity.ownerId, startsWith('oidc-'));
    expect(first.identity.ownerId, isNot(contains('employee-123')));
    expect(first.identity.displayName, 'max.egorov');
  });

  test('uses the provider profile name when a username is absent', () {
    final OidcConfiguration configuration = _configuration();
    final String subject = 'oidc|telegram|123456789';
    final AuthSession session = AuthSession.fromResponse(
      configuration: configuration,
      response: OidcTokenResponseData(
        accessToken: _jwt(<String, Object?>{
          'iss': configuration.issuer.toString(),
          'sub': subject,
          'exp': 2000000000,
        }),
        accessTokenExpiration: DateTime.fromMillisecondsSinceEpoch(
          2000000000 * 1000,
          isUtc: true,
        ),
        idToken: _jwt(<String, Object?>{
          'iss': configuration.issuer.toString(),
          'sub': subject,
          'name': 'Telegram Explorer',
          'exp': 2000000000,
        }),
      ),
    );

    expect(session.identity.displayName, 'Telegram Explorer');
  });

  test('rejects a token issued by another issuer', () {
    final OidcConfiguration configuration = _configuration();

    expect(
      () => AuthSession.fromResponse(
        configuration: configuration,
        response: OidcTokenResponseData(
          accessToken: _jwt(<String, Object?>{
            'iss': 'https://attacker.example',
            'sub': 'employee-123',
            'exp': 2000000000,
          }),
          accessTokenExpiration: DateTime.fromMillisecondsSinceEpoch(
            2000000000 * 1000,
            isUtc: true,
          ),
        ),
      ),
      throwsA(isA<AuthTokenException>()),
    );
  });

  test('rejects issuer claim whitespace without normalizing it', () {
    final OidcConfiguration configuration = _configuration();

    for (final String issuer in <String>[
      ' ${configuration.issuer}',
      '${configuration.issuer} ',
    ]) {
      expect(
        () => AuthSession.fromResponse(
          configuration: configuration,
          response: OidcTokenResponseData(
            accessToken: _jwt(<String, Object?>{
              'iss': issuer,
              'sub': 'employee-123',
              'exp': 2000000000,
            }),
            accessTokenExpiration: DateTime.fromMillisecondsSinceEpoch(
              2000000000 * 1000,
              isUtc: true,
            ),
          ),
        ),
        throwsA(isA<AuthTokenException>()),
      );
    }
  });

  test('keeps exact whitespace-sensitive subject identities distinct', () {
    final OidcConfiguration configuration = _configuration();
    final AuthSession plain = _session(configuration, subject: 'employee-123');
    final AuthSession spaced = _session(
      configuration,
      subject: 'employee-123 ',
    );

    expect(spaced.identity.subject, 'employee-123 ');
    expect(spaced.identity.ownerId, isNot(plain.identity.ownerId));
  });

  test('rejects subject changes returned during refresh', () {
    final OidcConfiguration configuration = _configuration();
    final AuthSession session = _session(
      configuration,
      subject: 'employee-123',
    );

    expect(
      () => session.refreshed(
        configuration: configuration,
        response: OidcTokenResponseData(
          accessToken: _jwt(<String, Object?>{
            'iss': configuration.issuer.toString(),
            'sub': 'employee-456',
            'exp': 2000000000,
          }),
          accessTokenExpiration: DateTime.fromMillisecondsSinceEpoch(
            2000000000 * 1000,
            isUtc: true,
          ),
          idToken: _jwt(<String, Object?>{
            'iss': configuration.issuer.toString(),
            'sub': 'employee-456',
            'exp': 2000000000,
          }),
        ),
      ),
      throwsA(isA<AuthTokenException>()),
    );
  });

  test('rejects mismatched access-token and ID-token identities', () {
    final OidcConfiguration configuration = _configuration();

    expect(
      () => AuthSession.fromResponse(
        configuration: configuration,
        response: OidcTokenResponseData(
          accessToken: _jwt(<String, Object?>{
            'iss': configuration.issuer.toString(),
            'sub': 'access-user',
            'exp': 2000000000,
          }),
          accessTokenExpiration: DateTime.fromMillisecondsSinceEpoch(
            2000000000 * 1000,
            isUtc: true,
          ),
          idToken: _jwt(<String, Object?>{
            'iss': configuration.issuer.toString(),
            'sub': 'id-user',
            'exp': 2000000000,
          }),
        ),
      ),
      throwsA(isA<AuthTokenException>()),
    );
  });

  test('requires an exact issuer identifier match', () {
    final OidcConfiguration configuration = _configuration();

    expect(
      () => AuthSession.fromResponse(
        configuration: configuration,
        response: OidcTokenResponseData(
          accessToken: _jwt(<String, Object?>{
            'iss': '${configuration.issuer}/',
            'sub': 'employee-123',
            'exp': 2000000000,
          }),
          accessTokenExpiration: DateTime.fromMillisecondsSinceEpoch(
            2000000000 * 1000,
            isUtc: true,
          ),
        ),
      ),
      throwsA(isA<AuthTokenException>()),
    );
    expect(
      () => canonicalIssuer('${configuration.issuer}?tenant=other'),
      throwsA(isA<AuthTokenException>()),
    );
  });

  test('validates refreshed access-token identity without a new ID token', () {
    final OidcConfiguration configuration = _configuration();
    final AuthSession session = _session(
      configuration,
      subject: 'employee-123',
    );

    expect(
      () => session.refreshed(
        configuration: configuration,
        response: OidcTokenResponseData(
          accessToken: _jwt(<String, Object?>{
            'iss': configuration.issuer.toString(),
            'sub': 'employee-456',
            'exp': 2000000000,
          }),
          accessTokenExpiration: DateTime.fromMillisecondsSinceEpoch(
            2000000000 * 1000,
            isUtc: true,
          ),
        ),
      ),
      throwsA(isA<AuthTokenException>()),
    );
  });
}

OidcConfiguration _configuration() {
  return OidcConfiguration(
    issuer: Uri.parse('https://identity.example/realms/walking'),
    clientId: 'walking-mobile',
    audience: 'https://api.stepbeyond.game',
    redirectUri: Uri.parse('com.walkingrpg.app:/oauthredirect'),
    postLogoutRedirectUri: Uri.parse('com.walkingrpg.app:/logout'),
    scopes: const <String>['openid', 'profile', 'offline_access'],
    allowInsecureConnections: false,
  );
}

AuthSession _session(
  OidcConfiguration configuration, {
  required String subject,
}) {
  final String token = _jwt(<String, Object?>{
    'iss': configuration.issuer.toString(),
    'sub': subject,
    'exp': 2000000000,
  });
  return AuthSession.fromResponse(
    configuration: configuration,
    response: OidcTokenResponseData(
      accessToken: token,
      accessTokenExpiration: DateTime.fromMillisecondsSinceEpoch(
        2000000000 * 1000,
        isUtc: true,
      ),
      idToken: token,
      refreshToken: 'refresh-$subject',
    ),
  );
}

String _jwt(Map<String, Object?> claims) {
  String encode(Map<String, Object?> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${encode(<String, Object?>{'alg': 'none', 'typ': 'JWT'})}.'
      '${encode(claims)}.signature';
}
