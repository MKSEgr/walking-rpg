import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/auth_gate.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_store.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';
import 'package:walking_rpg_mobile/core/auth/owner_local_state_cleaner.dart';
import 'package:walking_rpg_mobile/features/onboarding/presentation/first_journey_gate.dart';

import 'support/in_memory_mobile_command_store.dart';
import 'support/in_memory_read_snapshot_cache.dart';

void main() {
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });
}

final class _UnusedSessionStore implements AuthSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> clearSession({
    required String ownerId,
    bool cleanupRequired = false,
  }) async {}

  @override
  Future<AuthSessionStoreState> read() async {
    return const AuthSessionStoreState();
  }

  @override
  Future<String> write(AuthSession session) async => 'unused';

  @override
  Future<void> writeRefreshedSession(
    AuthSession session, {
    required String sessionGeneration,
  }) async {}
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
