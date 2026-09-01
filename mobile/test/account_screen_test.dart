import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_store.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';
import 'package:walking_rpg_mobile/core/auth/owner_local_state_cleaner.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/account/data/account_api_client.dart';
import 'package:walking_rpg_mobile/features/account/presentation/account_screen.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

import 'support/in_memory_mobile_command_store.dart';

void main() {
  testWidgets('account deletion requires two confirmations and fresh login', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final OidcConfiguration oidc = _oidc();
    final _MemoryStore store = _MemoryStore(
      _session(oidc, subject: 'user-1', suffix: 'initial'),
    );
    final _FakeOidcClient oidcClient = _FakeOidcClient(
      authorizeResponse: _response(
        oidc,
        subject: 'user-1',
        suffix: 'confirmed',
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
      oidcClient: oidcClient,
      localStateCleaner: _NoopCleaner(),
      clock: () => DateTime.utc(2026, 7, 29, 5),
    );
    await controller.initialize();
    final _AccountTransport transport = _AccountTransport();
    bool recoveryOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: AccountScreen(
          controller: controller,
          identity: controller.identity!,
          apiClient: AccountApiClient(
            baseUri: Uri.parse('https://api.example'),
            transport: transport,
          ),
          idempotencyKeyFactory: () => 'delete-widget-test',
          recoveryCount: 2,
          onOpenRecovery: () async {
            recoveryOpened = true;
          },
        ),
      ),
    );

    expect(find.byType(ExpeditionBackdrop), findsOneWidget);
    expect(find.byKey(const Key('account-pilot-dossier')), findsOneWidget);
    expect(find.byKey(const Key('account-pilot-portrait')), findsOneWidget);
    expect(
      find.byKey(const Key('account-identity-route-oidc')),
      findsOneWidget,
    );
    expect(find.byType(PilotPortrait), findsOneWidget);
    expect(find.text('ДОСЬЕ ПИЛОТА'), findsOneWidget);
    expect(find.text('OIDC ПОДТВЕРЖДЕНА'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Досье пилота, user-1, Защищённая OIDC-сессия'),
      findsOneWidget,
    );
    expect(find.text('Ожидают проверки: 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-command-recovery')));
    expect(recoveryOpened, isTrue);

    final Finder deleteButton = find.byKey(const Key('account-delete-button'));
    await Scrollable.ensureVisible(
      tester.element(deleteButton),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pump();
    expect(deleteButton.hitTestable(), findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('account-delete-intent-dialog')),
      findsOneWidget,
    );
    expect(find.text('НЕОБРАТИМОЕ ДЕЙСТВИЕ'), findsOneWidget);
    expect(find.text('Удалить аккаунт?'), findsOneWidget);
    expect(find.byKey(const Key('account-delete-phrase')), findsNothing);

    await tester.tap(find.byKey(const Key('account-delete-continue')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('account-delete-phrase-dialog')),
      findsOneWidget,
    );
    expect(find.text('ПОСЛЕДНЯЯ ГРАНИЦА'), findsOneWidget);
    expect(find.byKey(const Key('account-delete-phrase')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('account-delete-confirm')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('account-delete-phrase')),
      'УДАЛИТЬ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('account-delete-confirm')));
    await tester.pumpAndSettle();

    expect(oidcClient.forceLoginRequests, <bool>[true]);
    expect(transport.postCalls, 1);
    expect(transport.lastHeaders?['Idempotency-Key'], 'delete-widget-test');
    expect(controller.state, AuthLifecycleState.unauthenticated);
    expect(controller.notice, contains('11111111-1111-1111-1111-111111111111'));
    expect(store.session, isNull);
    semantics.dispose();
  });

  testWidgets('English account boundary supports compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final OidcConfiguration oidc = _oidc();
    final AuthSessionController controller = AuthSessionController(
      configuration: MobileAuthConfiguration(
        mode: MobileAuthMode.oidc,
        apiBaseUri: Uri.parse('https://api.example'),
        refreshSkew: const Duration(seconds: 60),
        oidc: oidc,
      ),
      sessionStore: _MemoryStore(
        _session(oidc, subject: 'account-english-user', suffix: 'initial'),
      ),
      oidcClient: _FakeOidcClient(
        authorizeResponse: _response(
          oidc,
          subject: 'account-english-user',
          suffix: 'confirmed',
        ),
      ),
      localStateCleaner: _NoopCleaner(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: WalkingRpgTheme.dark(),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: AccountScreen(
          controller: controller,
          identity: controller.identity!,
          apiClient: AccountApiClient(
            baseUri: Uri.parse('https://api.example'),
            transport: _AccountTransport(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account and data'), findsOneWidget);
    expect(find.text('PILOT DOSSIER'), findsOneWidget);
    expect(
      find.byKey(const Key('account-identity-route-oidc')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Pilot dossier, account-english-user, Protected OIDC session',
      ),
      findsOneWidget,
    );
    final Finder deleteButton = find.byKey(const Key('account-delete-button'));
    await _bringAccountIntoView(tester, deleteButton);
    expect(find.text('Delete account'), findsWidgets);
    expect(deleteButton.hitTestable(), findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsOneWidget);
    await _bringDecisionActionIntoView(
      tester,
      find.byKey(const Key('account-delete-continue')),
    );
    await tester.tap(find.byKey(const Key('account-delete-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Enter DELETE in uppercase:'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('account-delete-phrase')),
      'УДАЛИТЬ',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('account-delete-confirm')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('account-delete-phrase')),
      'DELETE',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('account-delete-confirm')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('account recovery count follows runtime changes while open', (
    WidgetTester tester,
  ) async {
    final AuthSessionController controller = AuthSessionController(
      configuration: MobileAuthConfiguration(
        mode: MobileAuthMode.development,
        apiBaseUri: Uri.parse('https://api.example'),
        refreshSkew: const Duration(seconds: 60),
        developmentUserId: 'account-recovery-user',
        developmentDeviceId: 'account-recovery-device',
      ),
      sessionStore: _MemoryStore(
        _session(_oidc(), subject: 'unused', suffix: 'unused'),
      ),
      oidcClient: _FakeOidcClient(
        authorizeResponse: _response(
          _oidc(),
          subject: 'unused',
          suffix: 'unused',
        ),
      ),
      localStateCleaner: _NoopCleaner(),
    );
    await controller.initialize();
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: controller.identity!.ownerId,
      store: InMemoryMobileCommandStore(),
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async => throw StateError('offline'),
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async => throw StateError('unused'),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw StateError('unused'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          controller: controller,
          identity: controller.identity!,
          apiClient: AccountApiClient(
            baseUri: Uri.parse('https://api.example'),
            transport: _AccountTransport(),
          ),
          commandRuntime: runtime,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Все действия отправлены'), findsOneWidget);

    await expectLater(
      runtime.syncActivity(
        reading: StepReading(
          authoritativeTotal: 1200,
          localDate: DateTime.utc(2026, 7, 30),
          timeZone: 'UTC',
        ),
        idempotencyKey: 'account-pending',
      ),
      throwsStateError,
    );
    await tester.pumpAndSettle();

    expect(find.text('Ожидают проверки: 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await runtime.close();
    controller.dispose();
  });

  testWidgets('account clears transient recovery warning after returning', (
    WidgetTester tester,
  ) async {
    final AuthSessionController controller = AuthSessionController(
      configuration: MobileAuthConfiguration(
        mode: MobileAuthMode.development,
        apiBaseUri: Uri.parse('https://api.example'),
        refreshSkew: const Duration(seconds: 60),
        developmentUserId: 'account-recovery-user',
        developmentDeviceId: 'account-recovery-device',
      ),
      sessionStore: _MemoryStore(
        _session(_oidc(), subject: 'unused', suffix: 'unused'),
      ),
      oidcClient: _FakeOidcClient(
        authorizeResponse: _response(
          _oidc(),
          subject: 'unused',
          suffix: 'unused',
        ),
      ),
      localStateCleaner: _NoopCleaner(),
    );
    await controller.initialize();
    final _TransientCommandStore store = _TransientCommandStore();
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: controller.identity!.ownerId,
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async => throw StateError('unused'),
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async => throw StateError('unused'),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw StateError('unused'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          controller: controller,
          identity: controller.identity!,
          apiClient: AccountApiClient(
            baseUri: Uri.parse('https://api.example'),
            transport: _AccountTransport(),
          ),
          commandRuntime: runtime,
          onOpenRecovery: () async {
            store.failReads = false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Локальная очередь требует внимания'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-command-recovery')));
    await tester.pumpAndSettle();

    expect(find.text('Все действия отправлены'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await runtime.close();
    controller.dispose();
  });

  testWidgets('validation entry exists only when shell supplies its route', (
    WidgetTester tester,
  ) async {
    final AuthSessionController controller = AuthSessionController(
      configuration: MobileAuthConfiguration(
        mode: MobileAuthMode.development,
        apiBaseUri: Uri.parse('https://api.example'),
        refreshSkew: const Duration(seconds: 60),
        developmentUserId: 'validation-owner',
        developmentDeviceId: 'validation-device',
      ),
      sessionStore: _MemoryStore(
        _session(_oidc(), subject: 'unused', suffix: 'unused'),
      ),
      oidcClient: _FakeOidcClient(
        authorizeResponse: _response(
          _oidc(),
          subject: 'unused',
          suffix: 'unused',
        ),
      ),
      localStateCleaner: _NoopCleaner(),
    );
    await controller.initialize();

    Widget account({Future<void> Function()? onOpenValidation}) {
      return MaterialApp(
        home: AccountScreen(
          controller: controller,
          identity: controller.identity!,
          apiClient: AccountApiClient(
            baseUri: Uri.parse('https://api.example'),
            transport: _AccountTransport(),
          ),
          onOpenValidation: onOpenValidation,
        ),
      );
    }

    await tester.pumpWidget(account());
    expect(find.byKey(const Key('account-validation-center')), findsNothing);

    bool opened = false;
    await tester.pumpWidget(
      account(
        onOpenValidation: () async {
          opened = true;
        },
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('account-validation-center')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-validation-center')));
    await tester.pump();
    expect(opened, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('full account supports compact enlarged text without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    final OidcConfiguration oidc = _oidc();
    final AuthSessionController controller = AuthSessionController(
      configuration: MobileAuthConfiguration(
        mode: MobileAuthMode.oidc,
        apiBaseUri: Uri.parse('https://api.example'),
        refreshSkew: const Duration(seconds: 60),
        oidc: oidc,
      ),
      sessionStore: _MemoryStore(
        _session(
          oidc,
          subject: 'navigator-with-a-long-call-sign',
          suffix: 'compact',
        ),
      ),
      oidcClient: _FakeOidcClient(
        authorizeResponse: _response(
          oidc,
          subject: 'navigator-with-a-long-call-sign',
          suffix: 'confirmed',
        ),
      ),
      localStateCleaner: _NoopCleaner(),
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    await controller.initialize();
    bool recoveryOpened = false;
    bool validationOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: AccountScreen(
          controller: controller,
          identity: controller.identity!,
          apiClient: AccountApiClient(
            baseUri: Uri.parse('https://api.example'),
            transport: _AccountTransport(),
          ),
          recoveryCount: 120,
          onOpenRecovery: () async {
            recoveryOpened = true;
          },
          onOpenValidation: () async {
            validationOpened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('account-pilot-dossier-compact')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-link-compact')), findsNWidgets(2));
    expect(find.text('99+'), findsOneWidget);
    _expectNoAccountLayoutException(tester);

    await _bringAccountIntoView(
      tester,
      find.byKey(const Key('account-command-recovery')),
    );
    await tester.tap(find.byKey(const Key('account-command-recovery')));
    await tester.pump();
    expect(recoveryOpened, isTrue);

    await _bringAccountIntoView(
      tester,
      find.byKey(const Key('account-validation-center')),
    );
    await tester.tap(find.byKey(const Key('account-validation-center')));
    await tester.pump();
    expect(validationOpened, isTrue);

    await _bringAccountIntoView(
      tester,
      find.byKey(const Key('account-export-button')),
    );
    final Text exportLabel = tester.widget<Text>(
      find.text('Создать и передать JSON'),
    );
    expect(exportLabel.maxLines, 2);
    _expectNoAccountLayoutException(tester);

    await _bringAccountIntoView(
      tester,
      find.byKey(const Key('account-delete-button')),
    );
    expect(
      find.byKey(const Key('account-danger-zone-compact')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('account-delete-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('account-delete-intent-dialog')),
      findsOneWidget,
    );
    await _bringDecisionActionIntoView(
      tester,
      find.byKey(const Key('account-delete-continue')),
    );
    _expectNoAccountLayoutException(tester);

    await tester.tap(find.byKey(const Key('account-delete-continue')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('account-delete-phrase-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-delete-phrase')), findsOneWidget);
    await _bringDecisionActionIntoView(
      tester,
      find.byKey(const Key('account-delete-confirm')),
    );
    _expectNoAccountLayoutException(tester);
    await tester.tap(find.byKey(const Key('expedition-decision-cancel')));
    await tester.pumpAndSettle();

    await _bringAccountIntoView(tester, find.byKey(const Key('logout-button')));
    final Text logoutLabel = tester.widget<Text>(
      find.text('Выйти и очистить локальные данные'),
    );
    expect(logoutLabel.maxLines, 2);
    _expectNoAccountLayoutException(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    semantics.dispose();
    controller.dispose();
  });
}

Future<void> _bringAccountIntoView(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await Scrollable.ensureVisible(
    tester.element(target),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pump();
}

Future<void> _bringDecisionActionIntoView(
  WidgetTester tester,
  Finder target,
) async {
  expect(target, findsOneWidget);
  final Finder dialogScrollable = find
      .descendant(
        of: find.byKey(const Key('expedition-decision-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  expect(dialogScrollable, findsOneWidget);
  await tester.scrollUntilVisible(target, 160, scrollable: dialogScrollable);
  await tester.pumpAndSettle();
}

void _expectNoAccountLayoutException(WidgetTester tester) {
  final Object? exception = tester.takeException();
  if (exception == null) {
    return;
  }
  fail(
    exception is FlutterError ? exception.toStringDeep() : exception.toString(),
  );
}

final class _TransientCommandStore implements MobileCommandStore {
  bool failReads = true;
  List<MobileCommand> commands = <MobileCommand>[];

  @override
  Future<void> deleteOwner(String ownerId) async {
    commands = commands
        .where((MobileCommand command) => command.ownerId != ownerId)
        .toList(growable: false);
  }

  @override
  Future<List<MobileCommand>> load() async {
    if (failReads) {
      throw StateError('private path /command-store.json');
    }
    return <MobileCommand>[...commands];
  }

  @override
  Future<void> save(List<MobileCommand> commands) async {
    this.commands = <MobileCommand>[...commands];
  }
}

final class _AccountTransport implements HomeTransport {
  int postCalls = 0;
  Map<String, String>? lastHeaders;

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    postCalls += 1;
    lastHeaders = Map<String, String>.of(headers);
    return const HomeTransportResponse(
      statusCode: 200,
      body: '''
        {
          "receiptId": "11111111-1111-1111-1111-111111111111",
          "status": "COMPLETED",
          "requestedAt": "2026-07-29T05:00:00Z",
          "completedAt": "2026-07-29T05:00:00Z",
          "replayed": false
        }
      ''',
    );
  }
}

final class _FakeOidcClient implements OidcAuthorizationClient {
  _FakeOidcClient({required this.authorizeResponse});

  final OidcTokenResponseData authorizeResponse;
  final List<bool> forceLoginRequests = <bool>[];

  @override
  Future<OidcTokenResponseData> authorize(
    OidcConfiguration configuration, {
    bool forceLogin = false,
  }) async {
    forceLoginRequests.add(forceLogin);
    return authorizeResponse;
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
  }) {
    throw UnimplementedError();
  }
}

final class _MemoryStore implements AuthSessionStore {
  _MemoryStore(AuthSession value)
    : _state = AuthSessionStoreState(
        session: value,
        sessionGeneration: 'generation-1',
        lastOwnerId: value.identity.ownerId,
      );

  AuthSessionStoreState _state;

  AuthSession? get session => _state.session;

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
  Future<String> write(AuthSession session) async {
    _state = AuthSessionStoreState(
      session: session,
      sessionGeneration: 'generation-2',
      lastOwnerId: session.identity.ownerId,
    );
    return 'generation-2';
  }

  @override
  Future<void> writeRefreshedSession(
    AuthSession session, {
    required String sessionGeneration,
  }) async {
    if (_state.sessionGeneration != sessionGeneration) {
      throw StateError('stale session generation');
    }
    _state = AuthSessionStoreState(
      session: session,
      sessionGeneration: sessionGeneration,
      lastOwnerId: session.identity.ownerId,
    );
  }
}

final class _NoopCleaner implements LocalStateCleaner {
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

AuthSession _session(
  OidcConfiguration oidc, {
  required String subject,
  required String suffix,
}) {
  return AuthSession.fromResponse(
    configuration: oidc,
    response: _response(oidc, subject: subject, suffix: suffix),
  );
}

OidcTokenResponseData _response(
  OidcConfiguration oidc, {
  required String subject,
  required String suffix,
}) {
  final DateTime expiresAt = DateTime.utc(2026, 7, 29, 6);
  return OidcTokenResponseData(
    accessToken:
        '${_jwt(<String, Object?>{'iss': oidc.issuer.toString(), 'sub': subject, 'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}-$suffix',
    accessTokenExpiration: expiresAt,
    refreshToken: 'refresh-$subject',
    idToken: _jwt(<String, Object?>{
      'iss': oidc.issuer.toString(),
      'sub': subject,
      'preferred_username': subject,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
    }),
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
