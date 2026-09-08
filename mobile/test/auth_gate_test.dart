import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/auth_gate.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_store.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';
import 'package:walking_rpg_mobile/core/auth/owner_local_state_cleaner.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/onboarding/presentation/first_journey_gate.dart';

import 'support/in_memory_mobile_command_store.dart';
import 'support/in_memory_read_snapshot_cache.dart';

void main() {
  testWidgets('initializing session uses the expedition boundary state', (
    WidgetTester tester,
  ) async {
    final AuthSessionController controller = AuthSessionController(
      configuration: MobileAuthConfiguration(
        mode: MobileAuthMode.development,
        apiBaseUri: Uri.parse('https://api.example'),
        refreshSkew: const Duration(seconds: 60),
        developmentUserId: 'initializing-user',
        developmentDeviceId: 'initializing-device',
      ),
      sessionStore: _UnusedSessionStore(),
      oidcClient: _UnusedOidcClient(),
      localStateCleaner: _UnusedLocalStateCleaner(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: AuthGate(
          controller: controller,
          cache: InMemoryReadSnapshotCache(),
          commandStore: InMemoryMobileCommandStore(),
        ),
      ),
    );

    expect(find.byKey(const Key('auth-initializing-screen')), findsOneWidget);
    expect(find.text('Восстанавливаем маршрут'), findsOneWidget);
    expect(find.text('КАНАЛ ЭКСПЕДИЦИИ'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('keeps journey loaders stable across auth gate rebuilds', (
    WidgetTester tester,
  ) async {
    final AuthSessionController controller = AuthSessionController(
      configuration: MobileAuthConfiguration(
        mode: MobileAuthMode.development,
        apiBaseUri: Uri.parse('https://api.example'),
        refreshSkew: const Duration(seconds: 60),
        developmentUserId: 'auth-refresh-user',
        developmentDeviceId: 'auth-refresh-device',
      ),
      sessionStore: _UnusedSessionStore(),
      oidcClient: _UnusedOidcClient(),
      localStateCleaner: _UnusedLocalStateCleaner(),
    );
    await controller.initialize();
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache();
    final InMemoryMobileCommandStore commandStore =
        InMemoryMobileCommandStore();

    Widget buildApp() => MaterialApp(
      home: AuthGate(
        controller: controller,
        cache: cache,
        commandStore: commandStore,
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pump();
    final FirstJourneyGate before = tester.widget<FirstJourneyGate>(
      find.byType(FirstJourneyGate),
    );

    // AuthGate rebuilds whenever the controller publishes refreshed tokens.
    // The shell state and its API clients remain the same for the same owner.
    await tester.pumpWidget(buildApp());
    await tester.pump();
    final FirstJourneyGate after = tester.widget<FirstJourneyGate>(
      find.byType(FirstJourneyGate),
    );

    expect(after, isNot(same(before)));
    expect(after.homeLoader, same(before.homeLoader));
    expect(after.platformLoader, same(before.platformLoader));
    expect(after.synchronizer, same(before.synchronizer));
    expect(after.commandRuntime, same(before.commandRuntime));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('authenticated runtime sends the next journey command', (
    WidgetTester tester,
  ) async {
    final AuthSessionController controller = AuthSessionController(
      configuration: MobileAuthConfiguration(
        mode: MobileAuthMode.development,
        apiBaseUri: Uri.parse('https://api.example'),
        refreshSkew: const Duration(seconds: 60),
        developmentUserId: 'journey-user',
        developmentDeviceId: 'journey-device',
      ),
      sessionStore: _UnusedSessionStore(),
      oidcClient: _UnusedOidcClient(),
      localStateCleaner: _UnusedLocalStateCleaner(),
    );
    final _JourneyTransport transport = _JourneyTransport();

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedApplicationShell(
          controller: controller,
          identity: AuthIdentity.development('journey-user'),
          cache: InMemoryReadSnapshotCache(),
          commandStore: InMemoryMobileCommandStore(),
          transport: transport,
        ),
      ),
    );
    await tester.pump();

    final FirstJourneyGate gate = tester.widget<FirstJourneyGate>(
      find.byType(FirstJourneyGate),
    );
    final result = await gate.commandRuntime.beginNextJourney(
      expeditionId: 'starter-expedition-v1',
      expectedJourneyNumber: 2,
      idempotencyKey: 'journey-key',
    );

    expect(result.journeyNumber, 3);
    expect(
      transport.postUri?.path,
      '/api/v1/expeditions/starter-expedition-v1/journeys',
    );
    expect(jsonDecode(transport.postBody!), <String, Object>{
      'expectedJourneyNumber': 2,
      'idempotencyKey': 'journey-key',
    });

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('auth rejection removes every authenticated overlay route', (
    WidgetTester tester,
  ) async {
    final OidcConfiguration oidc = _oidc();
    final AuthSession session = _session(oidc);
    final _UnusedSessionStore store = _UnusedSessionStore(
      AuthSessionStoreState(
        session: session,
        sessionGeneration: 'generation-1',
        lastOwnerId: session.identity.ownerId,
      ),
    );
    final AuthSessionController controller = AuthSessionController(
      configuration: MobileAuthConfiguration(
        mode: MobileAuthMode.oidc,
        apiBaseUri: Uri.parse('https://api.example'),
        refreshSkew: const Duration(seconds: 60),
        oidc: oidc,
      ),
      sessionStore: store,
      oidcClient: _UnusedOidcClient(),
      localStateCleaner: _UnusedLocalStateCleaner(),
      clock: () => DateTime.utc(2026, 7, 30, 10),
    );
    await controller.initialize();
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: AuthGate(
          controller: controller,
          cache: InMemoryReadSnapshotCache(),
          commandStore: InMemoryMobileCommandStore(),
        ),
      ),
    );
    await tester.pump();
    expect(controller.state, AuthLifecycleState.authenticated);
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            const Scaffold(body: Text('private owner route')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('private owner route'), findsOneWidget);

    controller.rejectSession('session expired');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('private owner route'), findsNothing);
    expect(controller.state, isNot(AuthLifecycleState.authenticated));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });
}

final class _UnusedSessionStore implements AuthSessionStore {
  _UnusedSessionStore([this.state = const AuthSessionStoreState()]);

  AuthSessionStoreState state;

  @override
  Future<void> clear() async {
    state = const AuthSessionStoreState();
  }

  @override
  Future<void> clearSession({
    required String ownerId,
    bool cleanupRequired = false,
  }) async {
    state = AuthSessionStoreState(
      lastOwnerId: ownerId,
      cleanupRequired: cleanupRequired,
    );
  }

  @override
  Future<AuthSessionStoreState> read() async {
    return state;
  }

  @override
  Future<String> write(AuthSession session) async {
    state = AuthSessionStoreState(
      session: session,
      sessionGeneration: 'generation-written',
      lastOwnerId: session.identity.ownerId,
    );
    return 'generation-written';
  }

  @override
  Future<void> writeRefreshedSession(
    AuthSession session, {
    required String sessionGeneration,
  }) async {
    state = AuthSessionStoreState(
      session: session,
      sessionGeneration: sessionGeneration,
      lastOwnerId: session.identity.ownerId,
    );
  }
}

final class _JourneyTransport implements HomeTransport {
  Uri? postUri;
  String? postBody;

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    return const HomeTransportResponse(statusCode: 503, body: '{}');
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    postUri = uri;
    postBody = body;
    return const HomeTransportResponse(
      statusCode: 200,
      body: '''{
        "contentVersion": "chapter-1-v2",
        "expeditionId": "starter-expedition-v1",
        "expeditionName": "Сигнал из туманного сектора",
        "journeyNumber": 3,
        "progressAfter": 0,
        "requiredEnergy": 30,
        "expeditionVersion": 8,
        "status": "IN_PROGRESS",
        "currentNodeId": "outer-beacon",
        "currentNodeName": "Внешний маяк",
        "serverTime": "2026-09-08T12:00:00Z"
      }''',
    );
  }
}

final class _UnusedOidcClient implements OidcAuthorizationClient {
  @override
  Future<OidcTokenResponseData> authorize(
    OidcConfiguration configuration, {
    bool forceLogin = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> endSession(
    OidcConfiguration configuration, {
    required String idToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<OidcTokenResponseData> refresh(
    OidcConfiguration configuration, {
    required String refreshToken,
  }) {
    throw UnimplementedError();
  }
}

final class _UnusedLocalStateCleaner implements LocalStateCleaner {
  @override
  Future<void> clear(String ownerId) async {}
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

AuthSession _session(OidcConfiguration oidc) {
  final DateTime expiresAt = DateTime.utc(2026, 7, 30, 12);
  String jwt(Map<String, Object?> claims) {
    String encode(Map<String, Object?> value) {
      return base64Url
          .encode(utf8.encode(jsonEncode(value)))
          .replaceAll('=', '');
    }

    return '${encode(<String, Object?>{'alg': 'none'})}.'
        '${encode(claims)}.signature';
  }

  return AuthSession.fromResponse(
    configuration: oidc,
    response: OidcTokenResponseData(
      accessToken: jwt(<String, Object?>{
        'iss': oidc.issuer.toString(),
        'sub': 'route-user',
        'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      }),
      accessTokenExpiration: expiresAt,
      refreshToken: 'refresh-route-user',
      idToken: jwt(<String, Object?>{
        'iss': oidc.issuer.toString(),
        'sub': 'route-user',
        'preferred_username': 'route-user',
        'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      }),
      tokenType: 'Bearer',
      scopes: oidc.scopes,
    ),
  );
}
