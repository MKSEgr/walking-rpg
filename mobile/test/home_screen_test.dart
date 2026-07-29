import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/daily_goal_policy.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('home screen renders loaded backend snapshot', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(loader: () async => HomeSnapshot.demo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сегодня: 0 / 6000'), findsOneWidget);
    expect(find.text('Навигатор'), findsOneWidget);
    expect(find.text('Искра'), findsOneWidget);
    expect(
      find.textContaining(
        'Стартовая личная цель: собрано 0 из 3 активных дней',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Доступная энергия: 0 · версия 0'),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('XP 20 / 100'), findsOneWidget);
    expect(find.text('Связь 10'), findsOneWidget);
    expect(find.text('Доступная энергия: 0 · версия 0'), findsOneWidget);
  });

  testWidgets('home screen spends energy and reloads unlocked event', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    int? sentEnergy;
    String? sentKey;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            loads += 1;
            return loads == 1 ? _readyToAdvance() : _eventReady();
          },
          idempotencyKeyFactory: () => 'fixed-key',
          advancer:
              ({
                required String expeditionId,
                required int energyToSpend,
                required String idempotencyKey,
              }) async {
                sentEnergy = energyToSpend;
                sentKey = idempotencyKey;
                return _advanceResult();
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Личная цель: медиана 3000 шагов за 3 дня +5%'),
      findsOneWidget,
    );

    final Finder advanceButton = find.widgetWithText(
      FilledButton,
      'Потратить 30 энергии',
    );
    await tester.scrollUntilVisible(
      advanceButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(advanceButton);
    await tester.pumpAndSettle();

    expect(sentEnergy, 30);
    expect(sentKey, 'fixed-key');
    expect(loads, 2);
    expect(find.text('Источник сигнала'), findsOneWidget);

    final Finder eventStateButton = find.widgetWithText(
      FilledButton,
      'Выберите решение события',
    );
    await tester.scrollUntilVisible(
      eventStateButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(eventStateButton, findsOneWidget);
  });

  testWidgets(
    'home screen keeps result visible until acknowledgement and reloads',
    (WidgetTester tester) async {
      int loads = 0;
      String? sentEventId;
      String? sentChoiceId;
      String? sentKey;
      String? acknowledgedReceiptId;
      String? acknowledgementKey;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            loader: () async {
              loads += 1;
              return switch (loads) {
                1 => _secondEventReady(),
                2 => _pendingEventResultHome(),
                _ => _acknowledgedEventResultHome(),
              };
            },
            idempotencyKeyFactory: () => 'event-key',
            eventResolver:
                ({
                  required String eventId,
                  required String choiceId,
                  required String idempotencyKey,
                }) async {
                  sentEventId = eventId;
                  sentChoiceId = choiceId;
                  sentKey = idempotencyKey;
                  return _eventResolutionResult();
                },
            eventResultAcknowledger:
                ({
                  required String receiptId,
                  required String idempotencyKey,
                }) async {
                  acknowledgedReceiptId = receiptId;
                  acknowledgementKey = idempotencyKey;
                  return EventResultAcknowledgement(
                    receiptId: receiptId,
                    eventId: 'echo-vault-v1',
                    status: 'ACKNOWLEDGED',
                    acknowledgedAt: '2026-07-26T06:01:00Z',
                    serverTime: '2026-07-26T06:01:00Z',
                  );
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder choiceButton = find.widgetWithText(
        FilledButton,
        'Стабилизировать ядро',
      );
      await tester.scrollUntilVisible(
        choiceButton,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      await tester.tap(choiceButton);
      await tester.pumpAndSettle();

      expect(sentEventId, 'echo-vault-v1');
      expect(sentChoiceId, 'stabilize-core');
      expect(sentKey, 'event-key');
      expect(loads, 2);

      final Finder pendingResult = find.byKey(
        const Key('pending-event-result-card'),
      );
      expect(pendingResult, findsOneWidget);
      expect(find.text('Стабильный резонанс'), findsOneWidget);
      expect(find.text('Следующий узел: Пепельная орбита'), findsOneWidget);

      final Finder acknowledgementButton = find.byKey(
        const Key('pending-event-result-acknowledge'),
      );
      await tester.scrollUntilVisible(
        acknowledgementButton,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      await tester.tap(acknowledgementButton);
      await tester.pumpAndSettle();

      expect(acknowledgedReceiptId, '22222222-2222-2222-2222-222222222222');
      expect(acknowledgementKey, 'event-key');
      expect(loads, 3);
      expect(pendingResult, findsNothing);
      expect(
        find.textContaining('0 / 55 энергии · Пепельная орбита'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('XP 90 / 100'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('XP 90 / 100'), findsOneWidget);
      expect(find.text('Связь 23'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Люминовый осколок × 2'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Люминовый осколок × 2'), findsOneWidget);
    },
  );

  testWidgets('pending result disables an overlapping ready event', (
    WidgetTester tester,
  ) async {
    int resolutions = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async => _pendingEventResultHome(includeReadyEvent: true),
          eventResolver:
              ({
                required String eventId,
                required String choiceId,
                required String idempotencyKey,
              }) async {
                resolutions += 1;
                return _eventResolutionResult();
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder choiceButton = find.widgetWithText(
      FilledButton,
      'Стабилизировать ядро',
    );
    await tester.scrollUntilVisible(
      choiceButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(choiceButton, findsOneWidget);
    expect(tester.widget<FilledButton>(choiceButton).onPressed, isNull);
    expect(resolutions, 0);
  });

  testWidgets('home screen can retry after backend error', (
    WidgetTester tester,
  ) async {
    int attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            attempts += 1;
            if (attempts == 1) {
              throw const HomeApiException(
                statusCode: 503,
                message: 'Backend недоступен',
              );
            }
            return HomeSnapshot.demo;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить состояние'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Сегодня: 0 / 6000'), findsOneWidget);
  });

  testWidgets(
    'cached home is clearly read-only while refresh stays available',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            loader: () async => _readyToAdvance(
              cacheMetadata: CachedReadMetadata(
                cachedAt: DateTime.utc(2026, 7, 27, 9),
                reason: 'Нет соединения с сервером',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cached-snapshot-banner')), findsOneWidget);
      expect(
        find.textContaining('Изменения временно недоступны'),
        findsOneWidget,
      );

      final Finder advanceFinder = find.widgetWithText(
        FilledButton,
        'Изменения недоступны офлайн',
      );
      await tester.scrollUntilVisible(
        advanceFinder,
        200,
        scrollable: find.byType(Scrollable),
      );
      final FilledButton advance = tester.widget<FilledButton>(advanceFinder);
      expect(advance.onPressed, isNull);

      final Finder refreshFinder = find.widgetWithText(
        OutlinedButton,
        'Обновить состояние',
      );
      await tester.scrollUntilVisible(
        refreshFinder,
        200,
        scrollable: find.byType(Scrollable),
      );
      final OutlinedButton refresh = tester.widget<OutlinedButton>(
        refreshFinder,
      );
      expect(refresh.onPressed, isNotNull);
    },
  );

  testWidgets(
    'cached pending result stays visible but cannot be acknowledged',
    (WidgetTester tester) async {
      int acknowledgementCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            loader: () async => _pendingEventResultHome(
              cacheMetadata: CachedReadMetadata(
                cachedAt: DateTime.utc(2026, 7, 27, 9),
                reason: 'Нет соединения с сервером',
              ),
            ),
            eventResultAcknowledger:
                ({
                  required String receiptId,
                  required String idempotencyKey,
                }) async {
                  acknowledgementCalls += 1;
                  throw StateError('cached snapshot must be read-only');
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pending-event-result-card')),
        findsOneWidget,
      );
      final Finder acknowledgementFinder = find.byKey(
        const Key('pending-event-result-acknowledge'),
      );
      await tester.scrollUntilVisible(
        acknowledgementFinder,
        200,
        scrollable: find.byType(Scrollable),
      );
      final FilledButton acknowledgement = tester.widget<FilledButton>(
        acknowledgementFinder,
      );
      expect(acknowledgement.onPressed, isNull);
      expect(find.text('Подтверждение недоступно офлайн'), findsOneWidget);
      expect(acknowledgementCalls, 0);
    },
  );
}

const DailyGoalPolicy _adaptiveGoalPolicy = DailyGoalPolicy(
  policyVersion: 'adaptive-median-v1',
  source: 'ADAPTIVE',
  baselineSteps: 3000,
  sampleDays: 3,
  lookbackDays: 7,
  minimumSampleDays: 3,
  defaultGoal: 6000,
  growthPercent: 5,
  roundingStep: 250,
  minimumGoal: 2000,
  maximumGoal: 12000,
);

HomeSnapshot _readyToAdvance({CachedReadMetadata? cacheMetadata}) {
  return HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 6842,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 68,
    activityStateVersion: 1,
    economyVersion: 1,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    expeditionProgress: 0,
    requiredEnergy: 30,
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 0,
    unlockedEvent: null,
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 20,
    pilotNextLevelExperience: 100,
    petName: 'Искра',
    petLevel: 1,
    petBond: 10,
    cacheMetadata: cacheMetadata,
  );
}

HomeSnapshot _eventReady() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 6842,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 38,
    activityStateVersion: 1,
    economyVersion: 2,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    expeditionProgress: 30,
    requiredEnergy: 30,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 1,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'signal-source-v1',
      title: 'Источник сигнала',
      summary: 'Маяк отвечает импульсом.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'analyze-signal',
          title: 'Проанализировать сигнал',
          description: 'Пилот сопоставит частоты маяка.',
          pilotExperienceReward: 40,
          petBondReward: 5,
        ),
        HomeEventChoice(
          choiceId: 'trust-spark',
          title: 'Довериться Искре',
          description: 'Питомец найдёт путь по свету.',
          pilotExperienceReward: 20,
          petBondReward: 15,
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 20,
    pilotNextLevelExperience: 100,
    petName: 'Искра',
    petLevel: 1,
    petBond: 10,
  );
}

HomeSnapshot _secondEventReady() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 10000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 25,
    activityStateVersion: 1,
    economyVersion: 3,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'lumen-gate',
    currentNodeName: 'Люминовые ворота',
    expeditionProgress: 45,
    requiredEnergy: 45,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 3,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'echo-vault-v1',
      title: 'Хранилище эха',
      summary: 'Ядро нестабильно.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'stabilize-core',
          title: 'Стабилизировать ядро',
          description: 'Навигатор зафиксирует резонанс.',
          pilotExperienceReward: 30,
          petBondReward: 8,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'lumen-shard',
            itemName: 'Люминовый осколок',
            quantity: 2,
          ),
        ),
        HomeEventChoice(
          choiceId: 'follow-echo',
          title: 'Последовать за эхом',
          description: 'Искра найдёт живой след.',
          pilotExperienceReward: 20,
          petBondReward: 18,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'echo-thread',
            itemName: 'Нить эха',
            quantity: 1,
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 60,
    pilotNextLevelExperience: 100,
    petName: 'Искра',
    petLevel: 1,
    petBond: 15,
  );
}

HomeSnapshot _pendingEventResultHome({
  CachedReadMetadata? cacheMetadata,
  bool includePending = true,
  bool includeReadyEvent = false,
}) {
  return HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 10000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 25,
    activityStateVersion: 1,
    economyVersion: 3,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'ash-orbit',
    currentNodeName: 'Пепельная орбита',
    expeditionProgress: 0,
    requiredEnergy: 55,
    expeditionStatus: includeReadyEvent ? 'EVENT_READY' : 'IN_PROGRESS',
    expeditionVersion: 4,
    unlockedEvent: includeReadyEvent ? _secondEventReady().unlockedEvent : null,
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 90,
    pilotNextLevelExperience: 100,
    petName: 'Искра',
    petLevel: 1,
    petBond: 23,
    inventory: const <HomeInventoryItem>[
      HomeInventoryItem(
        itemId: 'lumen-shard',
        name: 'Люминовый осколок',
        description: 'Стабильный фрагмент светового ядра.',
        quantity: 2,
        version: 1,
      ),
    ],
    pendingEventResult: includePending
        ? const PendingEventResult(
            receiptId: '22222222-2222-2222-2222-222222222222',
            eventId: 'echo-vault-v1',
            eventTitle: 'Хранилище эха',
            choiceId: 'stabilize-core',
            choiceTitle: 'Стабилизировать ядро',
            outcomeTitle: 'Стабильный резонанс',
            outcomeSummary: 'Ядро перестало разрушаться.',
            pilot: EventPilotReward(
              pilotId: 'navigator-v1',
              name: 'Навигатор',
              level: 1,
              experienceGained: 30,
              currentExperience: 90,
              nextLevelExperience: 100,
              version: 2,
            ),
            pet: EventPetReward(
              petId: 'spark-v1',
              name: 'Искра',
              level: 1,
              bondGained: 8,
              bond: 23,
              version: 2,
            ),
            material: EventMaterialReward(
              itemId: 'lumen-shard',
              name: 'Люминовый осколок',
              description: 'Стабильный фрагмент светового ядра.',
              quantityGained: 2,
              quantityAfter: 2,
              version: 1,
            ),
            nextNode: EventNextNode(
              nodeId: 'ash-orbit',
              name: 'Пепельная орбита',
            ),
            resolvedAt: '2026-07-26T06:00:00Z',
          )
        : null,
    cacheMetadata: cacheMetadata,
  );
}

HomeSnapshot _acknowledgedEventResultHome() {
  return _pendingEventResultHome(includePending: false);
}

ExpeditionAdvanceResult _advanceResult() {
  return const ExpeditionAdvanceResult(
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    energySpent: 30,
    energyBalanceAfter: 38,
    economyVersion: 2,
    progressAfter: 30,
    requiredEnergy: 30,
    expeditionVersion: 1,
    status: 'EVENT_READY',
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    unlockedEvent: ExpeditionEventResult(
      eventId: 'signal-source-v1',
      title: 'Источник сигнала',
      summary: 'Маяк отвечает импульсом.',
      status: 'READY',
    ),
    serverTime: '2026-07-26T06:00:00Z',
  );
}

EventResolutionResult _eventResolutionResult() {
  return const EventResolutionResult(
    receiptId: '22222222-2222-2222-2222-222222222222',
    handoffRequired: true,
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 4,
    eventId: 'echo-vault-v1',
    eventTitle: 'Хранилище эха',
    status: 'RESOLVED',
    choiceId: 'stabilize-core',
    choiceTitle: 'Стабилизировать ядро',
    outcomeTitle: 'Стабильный резонанс',
    outcomeSummary: 'Ядро перестало разрушаться.',
    pilot: EventPilotReward(
      pilotId: 'navigator-v1',
      name: 'Навигатор',
      level: 1,
      experienceGained: 30,
      currentExperience: 90,
      nextLevelExperience: 100,
      version: 2,
    ),
    pet: EventPetReward(
      petId: 'spark-v1',
      name: 'Искра',
      level: 1,
      bondGained: 8,
      bond: 23,
      version: 2,
    ),
    material: EventMaterialReward(
      itemId: 'lumen-shard',
      name: 'Люминовый осколок',
      description: 'Стабильный фрагмент светового ядра.',
      quantityGained: 2,
      quantityAfter: 2,
      version: 1,
    ),
    nextNode: EventNextNode(nodeId: 'ash-orbit', name: 'Пепельная орбита'),
    serverTime: '2026-07-26T06:00:00Z',
  );
}
