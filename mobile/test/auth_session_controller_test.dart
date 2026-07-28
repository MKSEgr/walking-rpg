import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_store.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';
import 'package:walking_rpg_mobile/core/auth/owner_local_state_cleaner.dart';

void main() {
  test('restores a secure session without requiring network access', () async {
    final OidcConfiguration oidc = _oidc();
    final _MemorySessionStore store = _MemorySessionStore(
      _session(oidc, subject: 'user-1', expiresAt: _future),
    );
    final _FakeOidcClient client = _FakeOidcClient();
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      client: client,
    );

    await controller.initialize();

    expect(controller.state, AuthLifecycleState.authenticated);
    expect(controller.identity?.subject, 'user-1');
    expect(client.refreshCalls, 0);
  });

  test('deduplicates concurrent refresh requests', () async {
    final OidcConfiguration oidc = _oidc();
    final _MemorySessionStore store = _MemorySessionStore(
      _session(oidc, subject: 'user-1', expiresAt: _past),
    );
    final _FakeOidcClient client = _FakeOidcClient(
      refreshResponse: _response(
        oidc,
        subject: 'user-1',
        accessTokenSuffix: 'new',
        expiresAt: _future,
      ),
    );
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      client: client,
    );
    await controller.initialize();

    final Future<String> first = controller.accessToken();
    final Future<String> second = controller.accessToken();
    final List<String> tokens = await Future.wait(<Future<String>>[
      first,
      second,
    ]);

    expect(client.refreshCalls, 1);
    expect(tokens[0], tokens[1]);
    expect(store.session?.tokens.accessToken, tokens.first);
  });

  test('invalid grant requires a new interactive login', () async {
    final OidcConfiguration oidc = _oidc();
    final _MemorySessionStore store = _MemorySessionStore(
      _session(oidc, subject: 'user-1', expiresAt: _past),
    );
    final _FakeOidcClient client = _FakeOidcClient(
      refreshError: const AuthInvalidGrantException(),
    );
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      client: client,
    );
    await controller.initialize();

    await expectLater(
      controller.accessToken(),
      throwsA(isA<AuthReauthenticationRequiredException>()),
    );
    await _waitForState(
      controller,
      AuthLifecycleState.reauthenticationRequired,
    );

    expect(store.session, isNull);
    expect(controller.identity, isNull);
  });

  test(
    'forced reauthentication persists a tombstone before runtime stops',
    () async {
      final OidcConfiguration oidc = _oidc();
      final _MemorySessionStore store = _MemorySessionStore(
        _session(oidc, subject: 'user-1', expiresAt: _future),
      );
      final AuthSessionController controller = _controller(
        oidc: oidc,
        store: store,
        client: _FakeOidcClient(),
      );
      await controller.initialize();
      final String ownerId = controller.identity!.ownerId;
      final Completer<void> stopped = Completer<void>();
      controller.registerRuntimeStopper(() => stopped.future);

      controller.rejectSession('expired');
      await Future<void>.delayed(Duration.zero);

      expect(controller.state, AuthLifecycleState.stoppingRuntime);
      expect(store.session, isNull);
      expect(store.lastOwnerId, ownerId);

      stopped.complete();
      await _waitForState(
        controller,
        AuthLifecycleState.reauthenticationRequired,
      );
    },
  );

  test('refresh cannot reactivate a session after logout starts', () async {
    final OidcConfiguration oidc = _oidc();
    final Completer<void> refreshWriteStarted = Completer<void>();
    final Completer<void> releaseRefreshWrite = Completer<void>();
    final _MemorySessionStore store = _MemorySessionStore(
      _session(oidc, subject: 'user-1', expiresAt: _past),
      refreshWriteStarted: refreshWriteStarted,
      releaseRefreshWrite: releaseRefreshWrite,
    );
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      client: _FakeOidcClient(
        refreshResponse: _response(
          oidc,
          subject: 'user-1',
          accessTokenSuffix: 'rotated',
          expiresAt: _future,
        ),
      ),
    );
    await controller.initialize();

    final Future<String> refresh = controller.accessToken();
    await refreshWriteStarted.future;
    await controller.logout();
    releaseRefreshWrite.complete();

    await expectLater(
      refresh,
      throwsA(isA<AuthReauthenticationRequiredException>()),
    );
    expect(store.session, isNull);
    expect(controller.state, AuthLifecycleState.unauthenticated);
  });

  test('stale refresh cannot overwrite a later same-account sign-in', () async {
    final OidcConfiguration oidc = _oidc();
    final Completer<void> refreshWriteStarted = Completer<void>();
    final Completer<void> releaseRefreshWrite = Completer<void>();
    final _MemorySessionStore store = _MemorySessionStore(
      _session(oidc, subject: 'user-1', expiresAt: _past),
      refreshWriteStarted: refreshWriteStarted,
      releaseRefreshWrite: releaseRefreshWrite,
    );
    final _FakeOidcClient client = _FakeOidcClient(
      refreshResponse: _response(
        oidc,
        subject: 'user-1',
        accessTokenSuffix: 'stale-refresh',
        expiresAt: _future,
      ),
      authorizeResponse: _response(
        oidc,
        subject: 'user-1',
        accessTokenSuffix: 'replacement',
        expiresAt: _future,
      ),
    );
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      client: client,
    );
    await controller.initialize();

    final Future<String> staleRefresh = controller.accessToken();
    await refreshWriteStarted.future;
    await controller.logout();
    await controller.signIn();
    final String replacementToken = store.session!.tokens.accessToken;
    releaseRefreshWrite.complete();

    await expectLater(
      staleRefresh,
      throwsA(isA<AuthReauthenticationRequiredException>()),
    );
    expect(controller.state, AuthLifecycleState.authenticated);
    expect(controller.identity?.subject, 'user-1');
    expect(store.session?.tokens.accessToken, replacementToken);
    expect(replacementToken, contains('replacement'));
  });

  test('obsolete invalid_grant cannot reject a replacement session', () async {
    final OidcConfiguration oidc = _oidc();
    final Completer<OidcTokenResponseData> delayedRefresh =
        Completer<OidcTokenResponseData>();
    final _MemorySessionStore store = _MemorySessionStore(
      _session(oidc, subject: 'user-1', expiresAt: _past),
    );
    final _FakeOidcClient client = _FakeOidcClient(
      refreshFuture: delayedRefresh.future,
      authorizeResponse: _response(
        oidc,
        subject: 'user-2',
        accessTokenSuffix: 'replacement',
        expiresAt: _future,
      ),
    );
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      client: client,
    );
    await controller.initialize();

    final Future<String> staleRefresh = controller.accessToken();
    await Future<void>.delayed(Duration.zero);
    await controller.logout();
    await controller.signIn();
    delayedRefresh.completeError(const AuthInvalidGrantException());

    await expectLater(
      staleRefresh,
      throwsA(isA<AuthReauthenticationRequiredException>()),
    );
    expect(controller.state, AuthLifecycleState.authenticated);
    expect(controller.identity?.subject, 'user-2');
    expect(store.session?.identity.subject, 'user-2');
  });

  test('reauthenticating as the same account preserves owner data', () async {
    final OidcConfiguration oidc = _oidc();
    final AuthSession original = _session(
      oidc,
      subject: 'user-1',
      expiresAt: _future,
    );
    final _MemorySessionStore store = _MemorySessionStore(original);
    final _RecordingCleaner cleaner = _RecordingCleaner();
    final _FakeOidcClient client = _FakeOidcClient(
      authorizeResponse: _response(
        oidc,
        subject: 'user-1',
        accessTokenSuffix: 'reauth',
        expiresAt: _future,
      ),
    );
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      client: client,
      cleaner: cleaner,
    );
    await controller.initialize();
    controller.rejectSession('test');
    await _waitForState(
      controller,
      AuthLifecycleState.reauthenticationRequired,
    );

    await controller.signIn();

    expect(controller.state, AuthLifecycleState.authenticated);
    expect(cleaner.clearedOwners, isEmpty);
  });

  test('account switch clears the previous owner before activation', () async {
    final OidcConfiguration oidc = _oidc();
    final AuthSession original = _session(
      oidc,
      subject: 'user-1',
      expiresAt: _future,
    );
    final _MemorySessionStore store = _MemorySessionStore(original);
    final _RecordingCleaner cleaner = _RecordingCleaner();
    final _FakeOidcClient client = _FakeOidcClient(
      authorizeResponse: _response(
        oidc,
        subject: 'user-2',
        accessTokenSuffix: 'new-account',
        expiresAt: _future,
      ),
    );
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      client: client,
      cleaner: cleaner,
    );
    await controller.initialize();
    final String previousOwner = controller.identity!.ownerId;
    controller.rejectSession('test');
    await _waitForState(
      controller,
      AuthLifecycleState.reauthenticationRequired,
    );

    await controller.signIn();

    expect(cleaner.clearedOwners, <String>[previousOwner]);
    expect(controller.identity?.subject, 'user-2');
  });

  test('logout waits for runtime stop and clears the active owner', () async {
    final OidcConfiguration oidc = _oidc();
    final AuthSession original = _session(
      oidc,
      subject: 'user-1',
      expiresAt: _future,
    );
    final _MemorySessionStore store = _MemorySessionStore(original);
    final _RecordingCleaner cleaner = _RecordingCleaner();
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      client: _FakeOidcClient(),
      cleaner: cleaner,
    );
    await controller.initialize();
    final String ownerId = controller.identity!.ownerId;
    final Completer<void> stopped = Completer<void>();
    controller.registerRuntimeStopper(() => stopped.future);

    final Future<void> logout = controller.logout();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, AuthLifecycleState.stoppingRuntime);
    expect(cleaner.clearedOwners, isEmpty);
    expect(store.session, isNull);
    expect(store.lastOwnerId, ownerId);
    expect(store.cleanupRequired, isTrue);

    stopped.complete();
    await logout;

    expect(cleaner.clearedOwners, <String>[ownerId]);
    expect(store.session, isNull);
    expect(controller.state, AuthLifecycleState.unauthenticated);
  });

  test(
    'rejected-session owner survives restart and protects account switch',
    () async {
      final OidcConfiguration oidc = _oidc();
      final _MemorySessionStore store = _MemorySessionStore(
        _session(oidc, subject: 'user-1', expiresAt: _future),
      );
      final AuthSessionController first = _controller(
        oidc: oidc,
        store: store,
        client: _FakeOidcClient(),
      );
      await first.initialize();
      final String previousOwner = first.identity!.ownerId;
      first.rejectSession('expired');
      await _waitForState(first, AuthLifecycleState.reauthenticationRequired);

      expect(store.session, isNull);
      expect(store.lastOwnerId, previousOwner);

      final _RecordingCleaner cleaner = _RecordingCleaner();
      final AuthSessionController restarted = _controller(
        oidc: oidc,
        store: store,
        cleaner: cleaner,
        client: _FakeOidcClient(
          authorizeResponse: _response(
            oidc,
            subject: 'user-2',
            accessTokenSuffix: 'switched',
            expiresAt: _future,
          ),
        ),
      );
      await restarted.initialize();
      expect(restarted.state, AuthLifecycleState.reauthenticationRequired);

      await restarted.signIn();

      expect(cleaner.clearedOwners, <String>[previousOwner]);
      expect(restarted.identity?.subject, 'user-2');
    },
  );

  test('partial logout cleanup is retried even for the same account', () async {
    final OidcConfiguration oidc = _oidc();
    final AuthSession original = _session(
      oidc,
      subject: 'user-1',
      expiresAt: _future,
    );
    final _MemorySessionStore store = _MemorySessionStore(null);
    store._state = AuthSessionStoreState(
      lastOwnerId: original.identity.ownerId,
      cleanupRequired: true,
    );
    final _RecordingCleaner cleaner = _RecordingCleaner();
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      cleaner: cleaner,
      client: _FakeOidcClient(
        authorizeResponse: _response(
          oidc,
          subject: 'user-1',
          accessTokenSuffix: 'after-cleanup',
          expiresAt: _future,
        ),
      ),
    );
    await controller.initialize();

    await controller.signIn();

    expect(cleaner.clearedOwners, <String>[original.identity.ownerId]);
    expect(controller.state, AuthLifecycleState.authenticated);
    expect(store.cleanupRequired, isFalse);
  });

  test('signIn is ignored while an authenticated runtime is active', () async {
    final OidcConfiguration oidc = _oidc();
    final _MemorySessionStore store = _MemorySessionStore(
      _session(oidc, subject: 'user-1', expiresAt: _future),
    );
    final _FakeOidcClient client = _FakeOidcClient(
      authorizeResponse: _response(
        oidc,
        subject: 'user-2',
        accessTokenSuffix: 'unexpected',
        expiresAt: _future,
      ),
    );
    final AuthSessionController controller = _controller(
      oidc: oidc,
      store: store,
      client: client,
    );
    await controller.initialize();

    await controller.signIn();

    expect(client.authorizeCalls, 0);
    expect(controller.identity?.subject, 'user-1');
  });
}

final DateTime _past = DateTime.utc(2026, 7, 28, 9);
final DateTime _future = DateTime.utc(2026, 7, 28, 12);

AuthSessionController _controller({
  required OidcConfiguration oidc,
  required _MemorySessionStore store,
  required _FakeOidcClient client,
  _RecordingCleaner? cleaner,
}) {
  return AuthSessionController(
    configuration: MobileAuthConfiguration(
      mode: MobileAuthMode.oidc,
      apiBaseUri: Uri.parse('https://api.example'),
      refreshSkew: const Duration(seconds: 60),
      oidc: oidc,
    ),
    sessionStore: store,
    oidcClient: client,
    localStateCleaner: cleaner ?? _RecordingCleaner(),
    clock: () => DateTime.utc(2026, 7, 28, 10),
  );
}

OidcConfiguration _oidc() {
  return OidcConfiguration(
    issuer: Uri.parse('https://identity.example/realms/walking'),
    clientId: 'walking-mobile',
    redirectUri: Uri.parse('com.walkingrpg.app:/oauthredirect'),
    postLogoutRedirectUri: Uri.parse('com.walkingrpg.app:/logout'),
    scopes: const <String>['openid', 'profile', 'offline_access'],
    allowInsecureConnections: false,
  );
}

AuthSession _session(
  OidcConfiguration oidc, {
  required String subject,
  required DateTime expiresAt,
}) {
  return AuthSession.fromResponse(
    configuration: oidc,
    response: _response(
      oidc,
      subject: subject,
      accessTokenSuffix: 'initial',
      expiresAt: expiresAt,
    ),
  );
}

OidcTokenResponseData _response(
  OidcConfiguration oidc, {
  required String subject,
  required String accessTokenSuffix,
  required DateTime expiresAt,
}) {
  final String idToken = _jwt(<String, Object?>{
    'iss': oidc.issuer.toString(),
    'sub': subject,
    'preferred_username': subject,
    'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
  });
  return OidcTokenResponseData(
    accessToken:
        '${_jwt(<String, Object?>{'iss': oidc.issuer.toString(), 'sub': subject, 'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}-$accessTokenSuffix',
    accessTokenExpiration: expiresAt,
    refreshToken: 'refresh-$subject',
    idToken: idToken,
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

Future<void> _waitForState(
  AuthSessionController controller,
  AuthLifecycleState expected,
) async {
  for (int attempt = 0; attempt < 20; attempt += 1) {
    if (controller.state == expected) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('State ${controller.state} did not become $expected');
}

final class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore(
    AuthSession? session, {
    this.refreshWriteStarted,
    this.releaseRefreshWrite,
  }) : _state = AuthSessionStoreState(
         session: session,
         sessionGeneration: session == null ? null : 'generation-0',
         lastOwnerId: session?.identity.ownerId,
       );

  final Completer<void>? refreshWriteStarted;
  final Completer<void>? releaseRefreshWrite;
  AuthSessionStoreState _state;
  int _nextGeneration = 1;

  AuthSession? get session => _state.session;

  String? get lastOwnerId => _state.lastOwnerId;

  bool get cleanupRequired => _state.cleanupRequired;

  @override
  Future<void> clear() async {
    _state = const AuthSessionStoreState();
  }

  @override
  Future<void> clearSession({
    required String ownerId,
    bool cleanupRequired = false,
  }) async {
    _state = AuthSessionStoreState(
      lastOwnerId: ownerId,
      cleanupRequired: cleanupRequired,
    );
  }

  @override
  Future<AuthSessionStoreState> read() async => _state;

  @override
  Future<String> write(AuthSession value) async {
    final String generation = 'generation-${_nextGeneration++}';
    _state = AuthSessionStoreState(
      session: value,
      sessionGeneration: generation,
      lastOwnerId: value.identity.ownerId,
    );
    return generation;
  }

  @override
  Future<void> writeRefreshedSession(
    AuthSession value, {
    required String sessionGeneration,
  }) async {
    final Completer<void>? started = refreshWriteStarted;
    if (started != null && !started.isCompleted) {
      started.complete();
    }
    await releaseRefreshWrite?.future;
    if (_state.session == null ||
        _state.lastOwnerId != value.identity.ownerId ||
        _state.sessionGeneration != sessionGeneration) {
      throw AuthSessionStoreException(
        'session invalidated during refresh',
        lastOwnerId: _state.lastOwnerId,
      );
    }
    _state = AuthSessionStoreState(
      session: value,
      sessionGeneration: sessionGeneration,
      lastOwnerId: value.identity.ownerId,
    );
  }
}

final class _RecordingCleaner implements LocalStateCleaner {
  final List<String> clearedOwners = <String>[];

  @override
  Future<void> clear(String ownerId) async {
    clearedOwners.add(ownerId);
  }
}

final class _FakeOidcClient implements OidcAuthorizationClient {
  _FakeOidcClient({
    this.authorizeResponse,
    this.refreshResponse,
    this.refreshFuture,
    this.refreshError,
  });

  final OidcTokenResponseData? authorizeResponse;
  final OidcTokenResponseData? refreshResponse;
  final Future<OidcTokenResponseData>? refreshFuture;
  final Object? refreshError;
  int refreshCalls = 0;
  int authorizeCalls = 0;

  @override
  Future<OidcTokenResponseData> authorize(
    OidcConfiguration configuration,
  ) async {
    authorizeCalls += 1;
    return authorizeResponse ??
        (throw StateError('authorize response is not configured'));
  }

  @override
  Future<void> endSession(
    OidcConfiguration configuration, {
    required String idToken,
  }) async {}

  @override
  Future<OidcTokenResponseData> refresh(
    OidcConfiguration configuration, {
    required String refreshToken,
  }) async {
    refreshCalls += 1;
    final Object? error = refreshError;
    if (error != null) {
      throw error;
    }
    final Future<OidcTokenResponseData>? pending = refreshFuture;
    if (pending != null) {
      return pending;
    }
    return refreshResponse ??
        (throw StateError('refresh response is not configured'));
  }
}
