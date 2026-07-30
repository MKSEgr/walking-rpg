import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/presentation/platform_screen.dart';

import 'support/platform_fixture.dart';

void main() {
  testWidgets('renders platform snapshot and resumes guided first journey', (
    WidgetTester tester,
  ) async {
    final PlatformSnapshot initial = platformSnapshot();
    int resumes = 0;
    bool recoveryOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => initial,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          recoveryUnavailable: true,
          onOpenRecovery: () {
            recoveryOpened = true;
          },
          onResumeFirstJourney: () {
            resumes += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('platform-command-recovery')));
    expect(recoveryOpened, isTrue);
    expect(find.text('Путевой журнал'), findsOneWidget);
    expect(find.text('Сезон первого сигнала'), findsWidgets);
    expect(find.text('1/6'), findsOneWidget);

    final Finder resume = find.byKey(
      const Key('platform-resume-first-journey'),
    );
    await tester.tap(resume);
    await tester.pumpAndSettle();

    expect(resumes, 1);
    await tester.scrollUntilVisible(
      find.text('Искра · уровень 1'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Искра · уровень 1'), findsOneWidget);
  });

  testWidgets('authoritative generation reloads journal without losing input', (
    WidgetTester tester,
  ) async {
    int generation = 0;
    int loads = 0;
    late StateSetter setHostState;
    Future<PlatformSnapshot> loader() async {
      loads += 1;
      return platformSnapshot();
    }

    Future<HomeSnapshot> homeLoader() async => HomeSnapshot.demo;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return PlatformScreen(
              loader: loader,
              homeLoader: homeLoader,
              recordExperimentExposures: false,
              authoritativeRefreshGeneration: generation,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Finder squadName = find.byKey(const Key('platform-squad-name'));
    await tester.scrollUntilVisible(
      squadName,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.enterText(squadName, 'Сохранённый отряд');
    await tester.pump();
    expect(loads, 1);

    setHostState(() {
      generation += 1;
    });
    await tester.pumpAndSettle();

    expect(loads, 2);
    await tester.scrollUntilVisible(
      find.byKey(const Key('platform-squad-name'), skipOffstage: false),
      300,
      scrollable: find.byType(Scrollable),
    );
    final TextField refreshedSquadName = tester.widget<TextField>(
      find.byKey(const Key('platform-squad-name'), skipOffstage: false),
    );
    expect(refreshedSquadName.controller?.text, 'Сохранённый отряд');
  });

  testWidgets('enables squad actions when text is entered', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async => platformCommandResult(
                commandType: commandType,
                idempotencyKey: idempotencyKey,
                snapshot: platformSnapshot(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder squadName = find.byKey(const Key('platform-squad-name'));
    await tester.scrollUntilVisible(
      squadName,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.enterText(squadName, 'Первые ходоки');
    await tester.pump();

    final FilledButton create = tester.widget<FilledButton>(
      find.byKey(const Key('platform-create-squad')),
    );
    expect(create.onPressed, isNotNull);

    final Finder squadId = find.byKey(const Key('platform-squad-id'));
    await tester.enterText(squadId, '11111111-1111-1111-1111-111111111111');
    await tester.pump();

    final OutlinedButton join = tester.widget<OutlinedButton>(
      find.byKey(const Key('platform-join-squad')),
    );
    expect(join.onPressed, isNotNull);
  });

  testWidgets('shows backend message instead of exception internals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async => throw const PlatformApiException(
                statusCode: 409,
                code: 'PLATFORM_STATE_CONFLICT',
                message: 'Недостаточно сезонного опыта',
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder selectPet = find.byKey(
      const Key('platform-select-pet-moss-v1'),
    );
    await tester.scrollUntilVisible(
      selectPet,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(selectPet);
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось выполнить действие: Недостаточно сезонного опыта'),
      findsOneWidget,
    );
  });

  testWidgets('cached journal is read-only and does not guess ENERGY balance', (
    WidgetTester tester,
  ) async {
    int commands = 0;
    final PlatformSnapshot cached = platformSnapshot(
      cacheMetadata: CachedReadMetadata(
        cachedAt: DateTime.utc(2026, 7, 27, 9),
        reason: 'Нет соединения с сервером',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => cached,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                commands += 1;
                return platformCommandResult(
                  commandType: commandType,
                  idempotencyKey: idempotencyKey,
                  snapshot: cached,
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cached-snapshot-banner')), findsOneWidget);
    final Finder resume = find.byKey(
      const Key('platform-resume-first-journey'),
    );
    final FilledButton resumeButton = tester.widget<FilledButton>(resume);
    expect(resumeButton.onPressed, isNull);

    final Finder weekly = find.byKey(const Key('platform-advance-weekly'));
    await tester.scrollUntilVisible(
      weekly,
      300,
      scrollable: find.byType(Scrollable),
    );
    final FilledButton weeklyButton = tester.widget<FilledButton>(weekly);
    expect(weeklyButton.onPressed, isNull);
    expect(find.text('Баланс ENERGY сейчас недоступен'), findsOneWidget);
    expect(commands, 0);

    final Finder refreshFinder = find.widgetWithText(
      OutlinedButton,
      'Обновить журнал',
    );
    await tester.scrollUntilVisible(
      refreshFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final OutlinedButton refresh = tester.widget<OutlinedButton>(refreshFinder);
    expect(refresh.onPressed, isNotNull);
  });

  testWidgets('fresh journal disables weekly spend when home is unavailable', (
    WidgetTester tester,
  ) async {
    int commands = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => throw StateError('home unavailable'),
          recordExperimentExposures: false,
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                commands += 1;
                return platformCommandResult(
                  commandType: commandType,
                  idempotencyKey: idempotencyKey,
                  snapshot: platformSnapshot(),
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder weekly = find.byKey(const Key('platform-advance-weekly'));
    await tester.scrollUntilVisible(
      weekly,
      300,
      scrollable: find.byType(Scrollable),
    );
    final FilledButton weeklyButton = tester.widget<FilledButton>(weekly);
    expect(weeklyButton.onPressed, isNull);
    expect(find.text('Баланс ENERGY сейчас недоступен'), findsOneWidget);
    expect(find.text('Потратить 10 ENERGY'), findsNothing);
    expect(commands, 0);
  });
}
