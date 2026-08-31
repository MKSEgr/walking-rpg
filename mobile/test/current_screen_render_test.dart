import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_store.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';
import 'package:walking_rpg_mobile/core/auth/owner_local_state_cleaner.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_controller.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_scope.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/account/data/account_api_client.dart';
import 'package:walking_rpg_mobile/features/account/presentation/account_screen.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/auth/presentation/auth_expedition_screen.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/domain/daily_goal_policy.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/domain/weekly_activity_rhythm.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';
import 'package:walking_rpg_mobile/features/onboarding/presentation/first_journey_screen.dart';
import 'package:walking_rpg_mobile/features/platform/presentation/platform_screen.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_screen.dart';
import 'package:walking_rpg_mobile/features/validation/application/validation_evidence_controller.dart';
import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';
import 'package:walking_rpg_mobile/features/validation/presentation/validation_center_screen.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

import 'support/first_journey_fixture.dart';
import 'support/in_memory_mobile_command_store.dart';
import 'support/platform_fixture.dart';

const Key _captureKey = Key('current-screen-capture');
const List<String> _completeJourneySteps = <String>[
  'welcome',
  'health-permission',
  'first-sync',
  'pet-selection',
  'first-expedition',
  'first-event',
];

void main() {
  testWidgets('render every current working screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Directory output = Directory('test/render_output');
    if (output.existsSync()) {
      output.deleteSync(recursive: true);
    }
    output.createSync(recursive: true);

    final AppLocaleController localeController = AppLocaleController(
      store: _MemoryLocaleStore('ru'),
    );
    await localeController.initialize();
    addTearDown(localeController.dispose);

    await _pumpScreen(
      tester,
      localeController,
      AppLocaleChoiceScreen(controller: localeController),
    );
    await _capture(tester, '01-language-selection');

    await _pumpScreen(
      tester,
      localeController,
      AuthExpeditionScreen(
        reauthentication: false,
        busy: false,
        onSignIn: () {},
      ),
    );
    await _capture(tester, '02-sign-in');

    await _renderFirstJourneyScreens(tester, localeController);
    await _renderMainScreens(tester, localeController);
    await _renderAccount(tester, localeController);
    await _renderRecovery(tester, localeController);
    await _renderValidationCenter(tester, localeController);
  });
}

Future<void> _renderFirstJourneyScreens(
  WidgetTester tester,
  AppLocaleController localeController,
) async {
  final List<({String name, FirstJourneyScreen screen})> screens = <
    ({String name, FirstJourneyScreen screen})
  >[
    (
      name: '03-first-journey-welcome',
      screen: _firstJourneyScreen(
        home: firstJourneyHome(),
        completedSteps: const <String>[],
      ),
    ),
    (
      name: '04-first-journey-activity',
      screen: _firstJourneyScreen(
        home: firstJourneyHome(),
        completedSteps: const <String>['welcome'],
      ),
    ),
    (
      name: '05-first-journey-energy-reward',
      screen: _firstJourneyScreen(
        home: firstJourneyHome(synced: true, energy: 30),
        completedSteps: const <String>['welcome'],
        activityReward: firstJourneyActivityResult,
      ),
    ),
    (
      name: '06-first-journey-pet',
      screen: _firstJourneyScreen(
        home: firstJourneyHome(synced: true, energy: 30),
        completedSteps: const <String>['welcome'],
      ),
    ),
    (
      name: '07-first-journey-expedition',
      screen: _firstJourneyScreen(
        home: firstJourneyHome(synced: true, energy: 30),
        completedSteps: const <String>['welcome', 'pet-selection'],
      ),
    ),
    (
      name: '08-first-journey-event',
      screen: _firstJourneyScreen(
        home: firstJourneyHome(synced: true, eventReady: true),
        completedSteps: const <String>['welcome', 'pet-selection'],
      ),
    ),
    (
      name: '09-first-journey-completion',
      screen: _firstJourneyScreen(
        home: firstJourneyHome(
          synced: true,
          firstEventResolved: true,
          petBond: 15,
        ),
        completedSteps: const <String>['welcome', 'pet-selection'],
        eventReward: firstJourneyResolutionResult(),
      ),
    ),
  ];

  for (final ({String name, FirstJourneyScreen screen}) entry in screens) {
    await _pumpScreen(tester, localeController, entry.screen);
    await _capture(tester, entry.name);
  }
}

FirstJourneyScreen _firstJourneyScreen({
  required HomeSnapshot home,
  required List<String> completedSteps,
  ActivitySyncResult? activityReward,
  EventResolutionResult? eventReward,
}) {
  return FirstJourneyScreen(
    progress: FirstJourneyProgress(
      home: home,
      platform: platformSnapshot(
        completedOnboardingSteps: completedSteps,
        resolvedEventCount: home.currentNodeId == 'outer-beacon' ? 0 : 1,
        totalAcceptedSteps: home.dailySteps,
      ),
    ),
    busy: false,
    onWelcome: () {},
    onSync: () {},
    onSelectPet: (String _) {},
    onAdvance: () {},
    onResolve: (HomeEventChoice _) {},
    onContinueAfterActivity: () {},
    onFinish: () {},
    onContinueLater: () {},
    onOpenAccount: () {},
    onOpenRecovery: () {},
    activityReward: activityReward,
    eventReward: eventReward,
  );
}

Future<void> _renderMainScreens(
  WidgetTester tester,
  AppLocaleController localeController,
) async {
  final HomeSnapshot home = _currentHomeSnapshot();
  final shell = MainNavigationShell(
    home: HomeScreen(
      loader: () async => home,
      onOpenAccount: () {},
      onOpenRecovery: () {},
      activitySyncAction: FilledButton.icon(
        onPressed: null,
        icon: Icon(Icons.sync),
        label: Text('Синхронизировать шаги'),
      ),
    ),
    platform: PlatformScreen(
      loader: () async => platformSnapshot(
        completedOnboardingSteps: _completeJourneySteps,
        sparkLevel: 5,
        sparkBond: 430,
        sparkEvolutionStage: 1,
        sparkEvolutionBond: 180,
        seasonXp: 520,
        weeklyRouteProgress: 86,
        includeProfileCosmetics: true,
        squad: const <String, dynamic>{
          'squadId': '11111111-1111-1111-1111-111111111111',
          'name': 'Северный импульс',
          'ownerUserId': 'pilot-owner',
          'memberUserIds': <String>[
            'pilot-owner',
            'pilot-member-1',
            'pilot-member-2',
          ],
        },
      ),
      homeLoader: () async => home,
      recordExperimentExposures: false,
      onOpenAccount: () {},
      onOpenRecovery: () {},
    ),
  );

  await _pumpScreen(tester, localeController, shell);
  await _capture(tester, '10-expedition-overview');

  final Finder homeList = find
      .descendant(of: find.byType(HomeScreen), matching: find.byType(ListView))
      .first;
  await tester.drag(homeList, const Offset(0, -650));
  await tester.pump(const Duration(milliseconds: 500));
  await _capture(tester, '11-expedition-route-and-progress');

  await tester.tap(find.byKey(const Key('navigation-platform')));
  await tester.pump(const Duration(milliseconds: 500));
  await _capture(tester, '12-journal-overview');

  final Finder platformList = find.byKey(const Key('platform-screen-list'));
  await tester.drag(platformList, const Offset(0, -700));
  await tester.pump(const Duration(milliseconds: 500));
  await _capture(tester, '13-journal-progression');

  for (int index = 0; index < 6; index += 1) {
    await tester.drag(platformList, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 120));
  }
  await tester.pump(const Duration(milliseconds: 500));
  await _capture(tester, '14-journal-collection-and-squad');
}

Future<void> _renderAccount(
  WidgetTester tester,
  AppLocaleController localeController,
) async {
  final AuthSessionController controller = AuthSessionController(
    configuration: MobileAuthConfiguration(
      mode: MobileAuthMode.development,
      apiBaseUri: Uri.parse('https://api.walking-rpg.example'),
      refreshSkew: const Duration(minutes: 1),
      developmentUserId: 'pilot-render',
      developmentDeviceId: 'render-device',
    ),
    sessionStore: _NoopAuthSessionStore(),
    oidcClient: _NoopOidcClient(),
    localStateCleaner: const _NoopLocalStateCleaner(),
  );
  await controller.initialize();
  addTearDown(controller.dispose);

  const AuthIdentity identity = AuthIdentity(
    ownerId: 'pilot-render-owner',
    issuer: 'https://id.walking-rpg.example/',
    subject: 'mksegr',
    displayName: 'MKSEgr',
    isDevelopment: false,
  );
  await _pumpScreen(
    tester,
    localeController,
    AccountScreen(
      controller: controller,
      identity: identity,
      apiClient: AccountApiClient(
        baseUri: Uri.parse('https://api.walking-rpg.example'),
        transport: const _NoopHomeTransport(),
      ),
      recoveryCount: 2,
      onOpenRecovery: () async {},
      onOpenValidation: () async {},
    ),
  );
  await _capture(tester, '15-account-overview');

  final Finder accountList = find.byKey(const Key('account-scroll'));
  for (int index = 0; index < 3; index += 1) {
    await tester.drag(accountList, const Offset(0, -650));
    await tester.pump(const Duration(milliseconds: 120));
  }
  await tester.pump(const Duration(milliseconds: 500));
  await _capture(tester, '16-account-data-and-security');
}

Future<void> _renderRecovery(
  WidgetTester tester,
  AppLocaleController localeController,
) async {
  final StepReading reading = StepReading(
    authoritativeTotal: 6842,
    localDate: DateTime(2026, 8, 31),
    timeZone: 'Europe/Berlin',
  );
  final MobileCommand pending = MobileCommand.pending(
    ownerId: 'owner-1',
    type: MobileCommandType.activitySync,
    idempotencyKey: 'render-pending',
    fingerprint: 'render-pending-fingerprint',
    payload: reading.toJson(),
    now: DateTime.utc(2026, 8, 31, 8),
  );
  final MobileCommand failed = MobileCommand.pending(
    ownerId: 'owner-1',
    type: MobileCommandType.expeditionAdvance,
    idempotencyKey: 'render-failed',
    fingerprint: 'render-failed-fingerprint',
    payload: const <String, Object?>{
      'expeditionId': 'starter-expedition-v1',
      'energyToSpend': 30,
    },
    now: DateTime.utc(2026, 8, 31, 8, 1),
  ).withAttemptFailure(
    now: DateTime.utc(2026, 8, 31, 8, 2),
    error: StateError('Render-only rejected command'),
    terminal: true,
    category: MobileCommandFailureCategory.rejected,
  );
  final MobileCommandRuntime runtime = _recoveryRuntime(
    InMemoryMobileCommandStore(<MobileCommand>[pending, failed]),
  );
  addTearDown(runtime.close);

  await _pumpScreen(
    tester,
    localeController,
    MobileCommandRecoveryScreen(runtime: runtime),
  );
  await _capture(tester, '17-recovery');
}

Future<void> _renderValidationCenter(
  WidgetTester tester,
  AppLocaleController localeController,
) async {
  final ValidationEvidenceController controller = ValidationEvidenceController(
    ownerId: 'owner-1',
    activeOwnerProvider: () => 'owner-1',
    sessionRevision: 0,
    activeSessionRevisionProvider: () => 0,
    launch: EvidenceLaunchMetadata(
      startedAtUtc: DateTime.utc(2026, 8, 31, 8),
      platform: 'android',
      operatingSystemVersion: 'Android 16',
      appVersion: '0.1.0',
      buildNumber: 'current',
      sourceGitSha: '16c8873c87ba755a7b81faba83d1a34850216665',
      buildMode: 'debug',
      authenticationMode: 'oidc',
      healthSource: EvidenceHealthSource.healthConnect,
    ),
    stepReader: () async => StepReading(
      authoritativeTotal: 6842,
      localDate: DateTime(2026, 8, 31),
      timeZone: 'Europe/Berlin',
    ),
    synchronizer: (_) async => firstJourneyActivityResult,
    homeLoader: () async => firstJourneyHome(synced: true, energy: 30),
    platformLoader: () async => platformSnapshot(
      completedOnboardingSteps: _completeJourneySteps,
      totalAcceptedSteps: 6842,
    ),
    clock: () => DateTime.utc(2026, 8, 31, 8, 4),
    monotonicMillis: () => 5,
  );
  addTearDown(controller.dispose);

  await _pumpScreen(
    tester,
    localeController,
    ValidationCenterScreen(
      controller: controller,
      activeOwnerProvider: () => 'owner-1',
    ),
  );
  await _capture(tester, '18-validation-center');

  final Finder validationList = find.byType(ListView).first;
  for (int index = 0; index < 4; index += 1) {
    await tester.drag(validationList, const Offset(0, -650));
    await tester.pump(const Duration(milliseconds: 120));
  }
  await tester.pump(const Duration(milliseconds: 500));
  await _capture(tester, '19-validation-evidence');
}

Future<void> _pumpScreen(
  WidgetTester tester,
  AppLocaleController localeController,
  Widget screen,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: WalkingRpgTheme.dark(),
      builder: (BuildContext context, Widget? child) {
        return RepaintBoundary(
          key: _captureKey,
          child: AppLocaleScope(
            controller: localeController,
            child: child!,
          ),
        );
      },
      home: screen,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump();
  final RenderRepaintBoundary boundary = tester.renderObject<
    RenderRepaintBoundary
  >(find.byKey(_captureKey));
  final ui.Image image = await boundary.toImage(pixelRatio: 1);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('Could not encode $name');
  }
  File(
    'test/render_output/$name.png',
  ).writeAsBytesSync(bytes.buffer.asUint8List(), flush: true);
  image.dispose();
  debugPrint('Rendered $name');
}

HomeSnapshot _currentHomeSnapshot() {
  return const HomeSnapshot(
    localDate: '2026-08-31',
    timeZone: 'Europe/Berlin',
    dailySteps: 6842,
    dailyGoal: 6000,
    dailyGoalPolicy: DailyGoalPolicy(
      policyVersion: 'adaptive-median-v1',
      source: 'ADAPTIVE',
      baselineSteps: 5600,
      sampleDays: 7,
      lookbackDays: 7,
      minimumSampleDays: 3,
      defaultGoal: 6000,
      growthPercent: 5,
      roundingStep: 250,
      minimumGoal: 2000,
      maximumGoal: 12000,
    ),
    weeklyActivityRhythm: WeeklyActivityRhythm(
      activeDays: 5,
      windowDays: 7,
      targetActiveDays: 4,
      targetReached: true,
      days: <WeeklyActivityDay>[
        WeeklyActivityDay(localDate: '2026-08-25', active: true),
        WeeklyActivityDay(localDate: '2026-08-26', active: true),
        WeeklyActivityDay(localDate: '2026-08-27', active: false),
        WeeklyActivityDay(localDate: '2026-08-28', active: true),
        WeeklyActivityDay(localDate: '2026-08-29', active: false),
        WeeklyActivityDay(localDate: '2026-08-30', active: true),
        WeeklyActivityDay(localDate: '2026-08-31', active: true),
      ],
    ),
    availableEnergy: 38,
    activityStateVersion: 4,
    economyVersion: 7,
    lastActivitySyncAt: '2026-08-31T07:55:00Z',
    serverTime: '2026-08-31T08:00:00Z',
    contentVersion: 'chapter-1-v15',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'lumen-gate',
    currentNodeName: 'Люминовые ворота',
    expeditionProgress: 30,
    requiredEnergy: 45,
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 12,
    expeditionJourneyNumber: 2,
    journeyStartedAt: '2026-08-29T06:00:00Z',
    unlockedEvent: null,
    routeTrail: <HomeExpeditionRouteNode>[
      HomeExpeditionRouteNode(
        nodeId: 'outer-beacon',
        nodeName: 'Внешний маяк',
        state: 'VISITED',
        decision: HomeExpeditionRouteDecision(
          choiceId: 'follow-pulse',
          choiceTitle: 'Пойти за импульсом',
          outcomeTitle: 'Найден маяк',
        ),
      ),
      HomeExpeditionRouteNode(
        nodeId: 'lumen-gate',
        nodeName: 'Люминовые ворота',
        state: 'CURRENT',
      ),
      HomeExpeditionRouteNode(
        nodeId: 'echo-vault',
        nodeName: 'Хранилище эха',
        state: 'FUTURE',
      ),
    ],
    pilotId: 'navigator-v1',
    pilotName: 'Навигатор',
    pilotLevel: 6,
    pilotCurrentExperience: 810,
    pilotNextLevelExperience: 1200,
    petId: 'spark-v1',
    petName: 'Искра-звездочёт',
    petSpecies: 'Люмин',
    petLevel: 5,
    petBond: 430,
    petEvolutionStage: 1,
    inventory: <HomeInventoryItem>[
      HomeInventoryItem(
        itemId: 'lumen-shard',
        name: 'Люминовый осколок',
        description: 'Стабильный фрагмент светового ядра.',
        quantity: 2,
        version: 1,
      ),
      HomeInventoryItem(
        itemId: 'echo-thread',
        name: 'Нить эха',
        description: 'Тонкая нить сохранённого сигнала.',
        quantity: 1,
        version: 1,
      ),
    ],
  );
}

MobileCommandRuntime _recoveryRuntime(InMemoryMobileCommandStore store) {
  return MobileCommandRuntime(
    ownerId: 'owner-1',
    store: store,
    activitySender: ({
      required StepReading reading,
      required String idempotencyKey,
    }) async => ActivitySyncResult(
      acceptedTotal: reading.authoritativeTotal,
      acceptedDelta: reading.authoritativeTotal,
      energyGranted: 30,
      energyBalanceAfter: 30,
      economyVersion: 1,
      riskStatus: 'ACCEPTED',
      stateVersion: 1,
      serverTime: '2026-08-31T08:10:00Z',
    ),
    expeditionSender: ({
      required String expeditionId,
      required int energyToSpend,
      required String idempotencyKey,
    }) async => throw StateError('unused'),
    eventSender: ({
      required String eventId,
      required String choiceId,
      required String idempotencyKey,
    }) async => throw StateError('unused'),
  );
}

final class _MemoryLocaleStore implements AppLocaleStore {
  _MemoryLocaleStore(this.value);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String languageCode) async {
    value = languageCode;
  }
}

final class _NoopAuthSessionStore implements AuthSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> clearSession({
    required String ownerId,
    bool cleanupRequired = false,
  }) async {}

  @override
  Future<AuthSessionStoreState> read() async => const AuthSessionStoreState();

  @override
  Future<String> write(AuthSession session) async => 'render-generation';

  @override
  Future<void> writeRefreshedSession(
    AuthSession session, {
    required String sessionGeneration,
  }) async {}
}

final class _NoopOidcClient implements OidcAuthorizationClient {
  @override
  Future<OidcTokenResponseData> authorize(
    OidcConfiguration configuration, {
    bool forceLogin = false,
  }) async => throw UnimplementedError();

  @override
  Future<void> endSession(
    OidcConfiguration configuration, {
    required String idToken,
  }) async {}

  @override
  Future<OidcTokenResponseData> refresh(
    OidcConfiguration configuration, {
    required String refreshToken,
  }) async => throw UnimplementedError();
}

final class _NoopLocalStateCleaner implements LocalStateCleaner {
  const _NoopLocalStateCleaner();

  @override
  Future<void> clear(String ownerId) async {}
}

final class _NoopHomeTransport implements HomeTransport {
  const _NoopHomeTransport();

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) async => const HomeTransportResponse(statusCode: 200, body: '{}');

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async => const HomeTransportResponse(statusCode: 200, body: '{}');
}
