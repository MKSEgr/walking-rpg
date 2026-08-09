import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_store.dart';

void main() {
  test(
    'rejects a stale refresh after same-owner session replacement',
    () async {
      final OidcConfiguration oidc = _oidc();
      final _MemorySecureStorage storage = _MemorySecureStorage();
      final SecureAuthSessionStore store = SecureAuthSessionStore(
        storage: storage,
      );
      final AuthSession original = _session(
        oidc,
        subject: 'user-1',
        marker: 'original',
      );
      final String originalGeneration = await store.write(original);

      await store.clearSession(ownerId: original.identity.ownerId);
      final AuthSession replacement = _session(
        oidc,
        subject: 'user-1',
        marker: 'replacement',
      );
      final String replacementGeneration = await store.write(replacement);
      final AuthSession staleRefresh = original.refreshed(
        configuration: oidc,
        response: _response(oidc, subject: 'user-1', marker: 'stale-refresh'),
      );

      await expectLater(
        store.writeRefreshedSession(
          staleRefresh,
          sessionGeneration: originalGeneration,
        ),
        throwsA(isA<AuthSessionStoreException>()),
      );

      final AuthSessionStoreState restored = await store.read();
      expect(replacementGeneration, isNot(originalGeneration));
      expect(restored.sessionGeneration, replacementGeneration);
      expect(
        restored.session?.tokens.accessToken,
        replacement.tokens.accessToken,
      );
    },
  );

  test('fails closed when owner marker and token envelope disagree', () async {
    final OidcConfiguration oidc = _oidc();
    final _MemorySecureStorage storage = _MemorySecureStorage();
    final SecureAuthSessionStore store = SecureAuthSessionStore(
      storage: storage,
    );
    final AuthSession first = _session(
      oidc,
      subject: 'user-1',
      marker: 'first',
    );
    await store.write(first);
    final String firstEnvelope = storage.values[store.storageKey]!;

    final AuthSession second = _session(
      oidc,
      subject: 'user-2',
      marker: 'second',
    );
    await store.write(second);
    storage.values[store.storageKey] = firstEnvelope;

    await expectLater(
      store.read(),
      throwsA(
        isA<AuthSessionStoreException>().having(
          (AuthSessionStoreException error) => error.cleanupRequired,
          'cleanupRequired',
          isTrue,
        ),
      ),
    );

    final AuthSessionStoreState invalidated = await store.read();
    expect(invalidated.session, isNull);
    expect(invalidated.lastOwnerId, second.identity.ownerId);
    expect(invalidated.cleanupRequired, isTrue);
  });

  test('corrupt token envelope preserves the cleanup obligation', () async {
    final OidcConfiguration oidc = _oidc();
    final _MemorySecureStorage storage = _MemorySecureStorage();
    final SecureAuthSessionStore store = SecureAuthSessionStore(
      storage: storage,
    );
    final AuthSession session = _session(
      oidc,
      subject: 'user-1',
      marker: 'corrupt-envelope',
    );
    await store.write(session);
    storage.values[store.storageKey] = 'not-json';

    await expectLater(
      store.read(),
      throwsA(
        isA<AuthSessionStoreException>().having(
          (AuthSessionStoreException error) => error.cleanupRequired,
          'cleanupRequired',
          isTrue,
        ),
      ),
    );

    final AuthSessionStoreState invalidated = await store.read();
    expect(invalidated.session, isNull);
    expect(invalidated.lastOwnerId, session.identity.ownerId);
    expect(invalidated.cleanupRequired, isTrue);
  });

  test('failed tombstone write still deletes the token envelope', () async {
    final OidcConfiguration oidc = _oidc();
    final _MemorySecureStorage storage = _MemorySecureStorage();
    final SecureAuthSessionStore store = SecureAuthSessionStore(
      storage: storage,
    );
    final AuthSession session = _session(
      oidc,
      subject: 'user-1',
      marker: 'marker-write-failure',
    );
    await store.write(session);
    storage.failNextWriteKey = store.ownerStateKey;

    await expectLater(
      store.clearSession(
        ownerId: session.identity.ownerId,
        cleanupRequired: true,
      ),
      throwsA(isA<StateError>()),
    );

    expect(storage.values.containsKey(store.storageKey), isFalse);
    final AuthSessionStoreState restored = await store.read();
    expect(restored.session, isNull);
    expect(restored.lastOwnerId, session.identity.ownerId);
  });

  test('failed token publication leaves an invalidated owner marker', () async {
    final OidcConfiguration oidc = _oidc();
    final _MemorySecureStorage storage = _MemorySecureStorage();
    final SecureAuthSessionStore store = SecureAuthSessionStore(
      storage: storage,
    );
    final AuthSession session = _session(
      oidc,
      subject: 'user-1',
      marker: 'failed-write',
    );
    storage.failNextWriteKey = store.storageKey;

    await expectLater(store.write(session), throwsA(isA<StateError>()));

    final AuthSessionStoreState invalidated = await store.read();
    expect(invalidated.session, isNull);
    expect(invalidated.lastOwnerId, session.identity.ownerId);
    expect(storage.values.containsKey(store.storageKey), isFalse);
  });
}

final class _MemorySecureStorage implements AuthSecureStorage {
  final Map<String, String> values = <String, String>{};
  String? failNextWriteKey;

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (failNextWriteKey == key) {
      failNextWriteKey = null;
      throw StateError('simulated secure-storage write failure');
    }
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

OidcConfiguration _oidc() {
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
  OidcConfiguration oidc, {
  required String subject,
  required String marker,
}) {
  return AuthSession.fromResponse(
    configuration: oidc,
    response: _response(oidc, subject: subject, marker: marker),
  );
}

OidcTokenResponseData _response(
  OidcConfiguration oidc, {
  required String subject,
  required String marker,
}) {
  final String token = _jwt(<String, Object?>{
    'iss': oidc.issuer.toString(),
    'sub': subject,
    'jti': marker,
    'exp': 2000000000,
  });
  return OidcTokenResponseData(
    accessToken: token,
    accessTokenExpiration: DateTime.fromMillisecondsSinceEpoch(
      2000000000 * 1000,
      isUtc: true,
    ),
    refreshToken: 'refresh-$subject',
    idToken: token,
    tokenType: 'Bearer',
    scopes: oidc.scopes,
  );
}

String _jwt(Map<String, Object?> claims) {
  String encode(Map<String, Object?> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${encode(<String, Object?>{'alg': 'none'})}.'
      '${encode(claims)}.signature';
}
