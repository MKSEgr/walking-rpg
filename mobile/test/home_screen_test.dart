import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/expedition_read_state.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/features/crafting/domain/crafting_result.dart';
import 'package:walking_rpg_mobile/features/equipment/domain/equipment_result.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/daily_goal_policy.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('home loading waits for an accepted route snapshot', (
    WidgetTester tester,
  ) async {
    final Completer<HomeSnapshot> loader = Completer<HomeSnapshot>();

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(loader: () => loader.future)),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-loading-state')), findsOneWidget);
    expect(find.byType(ExpeditionReadState), findsOneWidget);
    expect(find.byType(ExpeditionBackdrop), findsOneWidget);
    expect(find.text('Сверяем маршрут'), findsOneWidget);
    expect(find.byKey(const Key('home-expedition-vista')), findsNothing);

    loader.complete(HomeSnapshot.demo);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-loading-state')), findsNothing);
    expect(find.byKey(const Key('home-expedition-vista')), findsOneWidget);
  });

  testWidgets('home hero uses accepted chapter and companion state', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(loader: () async => HomeSnapshot.demo)),
    );
    await tester.pumpAndSettle();

    final Finder vistaFinder = find.byKey(const Key('home-expedition-vista'));
    expect(vistaFinder, findsOneWidget);
    final ChapterVista vista = tester.widget<ChapterVista>(vistaFinder);
    expect(vista.progress, HomeSnapshot.demo.expeditionProgressValue);
    expect(
      find.bySemanticsLabel(
        'Сигнал из туманного сектора, Внешний маяк, маршрут 0%',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-current-node-badge')), findsOneWidget);
    final Finder companionBadge = find.byKey(
      const Key('home-active-companion-badge'),
    );
    expect(companionBadge, findsOneWidget);
    expect(
      find.descendant(of: companionBadge, matching: find.text('ИСКРА · УР. 1')),
      findsOneWidget,
    );
    final Finder portraitFinder = find.byKey(
      const Key('home-active-companion-portrait'),
    );
    expect(portraitFinder, findsOneWidget);
    final CompanionPortrait portrait = tester.widget<CompanionPortrait>(
      portraitFinder,
    );
    expect(portrait.petId, 'spark-v1');
    expect(portrait.evolutionStage, 0);
    expect(find.byType(PilotPortrait), findsOneWidget);
    expect(find.bySemanticsLabel('Пилот Навигатор'), findsNothing);
    expect(
      find.byKey(const Key('home-team-companion-portrait')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('companion-illustration-spark-v1')),
      findsNWidgets(2),
    );
    expect(
      find.bySemanticsLabel('Искра, Люмин, форма 1, активный спутник'),
      findsOneWidget,
    );

    semantics.dispose();
  });

  testWidgets(
    'legacy cached companion stays textual without guessed identity',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(loader: () async => _readyToAdvance())),
      );
      await tester.pumpAndSettle();

      final Finder companionBadge = find.byKey(
        const Key('home-active-companion-badge'),
      );
      expect(companionBadge, findsOneWidget);
      expect(
        find.byKey(const Key('home-active-companion-portrait')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: companionBadge,
          matching: find.text('ИСКРА · УР. 1'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('home screen renders loaded backend snapshot', (
    WidgetTester tester,
  ) async {
    bool recoveryOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async => HomeSnapshot.demo,
          recoveryCount: 1,
          onOpenRecovery: () {
            recoveryOpened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-command-recovery')));
    expect(recoveryOpened, isTrue);
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

  testWidgets('authoritative generation reloads home in place', (
    WidgetTester tester,
  ) async {
    int generation = 0;
    int loads = 0;
    late StateSetter setHostState;
    Future<HomeSnapshot> loader() async {
      loads += 1;
      return HomeSnapshot.demo;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return HomeScreen(
              loader: loader,
              authoritativeRefreshGeneration: generation,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);

    setHostState(() {
      generation += 1;
    });
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('Walking RPG'), findsOneWidget);
  });

  testWidgets('network home records recipe once after card enters viewport', (
    WidgetTester tester,
  ) async {
    int generation = 0;
    late StateSetter setHostState;
    final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
    final List<String> keys = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return HomeScreen(
              loader: () async => _craftingReady(),
              authoritativeRefreshGeneration: generation,
              impressionRecorder:
                  ({
                    required String commandType,
                    required Map<String, Object?> payload,
                    required String idempotencyKey,
                  }) async {
                    expect(commandType, 'RECORD_COMPASS_IMPRESSION');
                    payloads.add(payload);
                    keys.add(idempotencyKey);
                    return null;
                  },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(payloads, isEmpty);

    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );

    setHostState(() {
      generation += 1;
    });
    await tester.pumpAndSettle();

    expect(payloads, <Map<String, Object?>>[
      <String, Object?>{
        'impression': 'RECIPE_READY',
        'contentVersion': 'chapter-1-v1',
      },
    ]);
    expect(keys, <String>[
      'compass-impression-chapter-1-v1-'
          'recipe-resonance-compass-v1-1-RECIPE_READY',
    ]);
  });

  testWidgets(
    'recipe behind sticky action is not counted until it is unobscured',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final List<String> impressions = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            loader: () async => _craftingReady(),
            impressionRecorder:
                ({
                  required String commandType,
                  required Map<String, Object?> payload,
                  required String idempotencyKey,
                }) async {
                  impressions.add(payload['impression']! as String);
                  return null;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(impressions, isEmpty);

      final Finder recipeViewport = find.byKey(
        const Key('home-recipe-viewport-resonance-compass-v1'),
      );
      final Finder stickyAction = find.byKey(
        const Key('home-sticky-action-panel'),
      );
      final ScrollPosition position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      final double coveredOffset =
          (position.pixels +
                  tester.getTopLeft(recipeViewport).dy -
                  tester.getTopLeft(stickyAction).dy -
                  1)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();

      position.jumpTo(coveredOffset);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(recipeViewport).dy,
        greaterThanOrEqualTo(tester.getTopLeft(stickyAction).dy),
      );
      expect(impressions, isEmpty);

      const double visibleExtent = 24;
      position.jumpTo(
        (position.pixels +
                tester.getTopLeft(recipeViewport).dy -
                tester.getTopLeft(stickyAction).dy +
                visibleExtent)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(recipeViewport).dy,
        lessThan(tester.getTopLeft(stickyAction).dy),
      );
      expect(impressions, <String>['RECIPE_READY']);
    },
  );

  testWidgets('failed recipe impression retries on authoritative reload', (
    WidgetTester tester,
  ) async {
    int generation = 0;
    int attempts = 0;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return HomeScreen(
              loader: () async => _craftingReady(),
              authoritativeRefreshGeneration: generation,
              impressionRecorder:
                  ({
                    required String commandType,
                    required Map<String, Object?> payload,
                    required String idempotencyKey,
                  }) async {
                    attempts += 1;
                    if (attempts == 1) {
                      throw StateError('temporary telemetry failure');
                    }
                    return null;
                  },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(attempts, 0);

    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );
    expect(attempts, 1);

    setHostState(() {
      generation += 1;
    });
    await tester.pumpAndSettle();
    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );

    expect(attempts, 2);
  });

  testWidgets(
    'failed impression from an older request retries the accepted snapshot',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int generation = 0;
      int attempts = 0;
      late StateSetter setHostState;
      final Completer<Object?> firstAttempt = Completer<Object?>();

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setHostState = setState;
              return HomeScreen(
                loader: () async => _craftingReady(),
                authoritativeRefreshGeneration: generation,
                impressionRecorder:
                    ({
                      required String commandType,
                      required Map<String, Object?> payload,
                      required String idempotencyKey,
                    }) {
                      attempts += 1;
                      if (attempts == 1) {
                        return firstAttempt.future;
                      }
                      return Future<Object?>.value();
                    },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(attempts, 1);

      setHostState(() {
        generation += 1;
      });
      await tester.pumpAndSettle();
      expect(attempts, 1);

      firstAttempt.completeError(StateError('old telemetry request failed'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
    },
  );

  testWidgets('superseded home request never records an impression', (
    WidgetTester tester,
  ) async {
    int generation = 0;
    int loads = 0;
    late StateSetter setHostState;
    final Completer<HomeSnapshot> stale = Completer<HomeSnapshot>();
    final Completer<HomeSnapshot> current = Completer<HomeSnapshot>();
    final List<String> impressions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return HomeScreen(
              loader: () {
                loads += 1;
                return loads == 1 ? stale.future : current.future;
              },
              authoritativeRefreshGeneration: generation,
              impressionRecorder:
                  ({
                    required String commandType,
                    required Map<String, Object?> payload,
                    required String idempotencyKey,
                  }) async {
                    impressions.add(payload['impression']! as String);
                    return null;
                  },
            );
          },
        ),
      ),
    );
    expect(loads, 1);

    setHostState(() {
      generation += 1;
    });
    await tester.pump();
    expect(loads, 2);

    stale.complete(_craftingReady());
    await tester.pump();
    expect(impressions, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    current.complete(_craftingCompleted());
    await tester.pumpAndSettle();
    expect(impressions, isEmpty);

    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );

    expect(impressions, <String>['RECIPE_CRAFTED']);
  });

  testWidgets('hidden home records an accepted snapshot only when visible', (
    WidgetTester tester,
  ) async {
    final Completer<HomeSnapshot> response = Completer<HomeSnapshot>();
    final List<String> impressions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationShell(
          home: HomeScreen(
            loader: () => response.future,
            impressionRecorder:
                ({
                  required String commandType,
                  required Map<String, Object?> payload,
                  required String idempotencyKey,
                }) async {
                  impressions.add(payload['impression']! as String);
                  return null;
                },
          ),
          platform: const Scaffold(body: Text('journal-content')),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('navigation-platform')));
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
    response.complete(_craftingReady());
    await tester.pumpAndSettle();

    expect(impressions, isEmpty);
    expect(find.text('journal-content'), findsOneWidget);

    await tester.tap(find.byKey(const Key('navigation-home')));
    await tester.pumpAndSettle();
    expect(impressions, isEmpty);

    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );

    expect(impressions, <String>['RECIPE_READY']);
  });

  testWidgets('covering route defers a visible recipe impression until pop', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final Completer<HomeSnapshot> response = Completer<HomeSnapshot>();
    final List<String> impressions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return HomeScreen(
              loader: () => response.future,
              onOpenAccount: () {
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => Scaffold(
                        body: Center(
                          child: FilledButton(
                            key: const Key('close-covering-route'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Закрыть аккаунт'),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              impressionRecorder:
                  ({
                    required String commandType,
                    required Map<String, Object?> payload,
                    required String idempotencyKey,
                  }) async {
                    impressions.add(payload['impression']! as String);
                    return null;
                  },
            );
          },
        ),
      ),
    );

    await tester.tap(find.byTooltip('Аккаунт'));
    await tester.pumpAndSettle();
    expect(find.text('Закрыть аккаунт'), findsOneWidget);

    response.complete(_craftingReady());
    await tester.pumpAndSettle();
    expect(impressions, isEmpty);

    await tester.tap(find.byKey(const Key('close-covering-route')));
    await tester.pumpAndSettle();

    expect(impressions, <String>['RECIPE_READY']);
  });

  testWidgets('backgrounded home defers a visible recipe until resume', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    final Completer<HomeSnapshot> response = Completer<HomeSnapshot>();
    final List<String> impressions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () => response.future,
          impressionRecorder:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                impressions.add(payload['impression']! as String);
                return null;
              },
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    response.complete(_craftingReady());
    await tester.pumpAndSettle();
    expect(impressions, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(impressions, <String>['RECIPE_READY']);
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

  testWidgets('home screen crafts and reloads authoritative inventory', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    String? sentRecipeId;
    String? sentKey;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            loads += 1;
            return loads == 1 ? _craftingReady() : _craftingCompleted();
          },
          idempotencyKeyFactory: () => 'craft-key',
          crafter:
              ({
                required String recipeId,
                required String idempotencyKey,
              }) async {
                sentRecipeId = recipeId;
                sentKey = idempotencyKey;
                return _craftingResult();
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder craftButton = find.byKey(
      const Key('craft-resonance-compass-v1'),
    );
    await tester.scrollUntilVisible(
      craftButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(craftButton).onPressed, isNotNull);

    await tester.tap(craftButton);
    await tester.pumpAndSettle();

    expect(sentRecipeId, 'resonance-compass-v1');
    expect(sentKey, 'craft-key');
    expect(loads, 2);
    final Finder uniqueItem = find.text(
      'Резонансный компас · уникальный предмет',
    );
    await tester.scrollUntilVisible(
      uniqueItem,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(uniqueItem, findsOneWidget);

    final Finder craftedStatus = find.text('Предмет уже создан');
    await tester.scrollUntilVisible(
      craftedStatus,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(craftedStatus, findsOneWidget);
  });

  testWidgets('cached home keeps crafting read-only', (
    WidgetTester tester,
  ) async {
    int craftCalls = 0;
    int impressionCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async => _craftingReady(
            cacheMetadata: CachedReadMetadata(
              cachedAt: DateTime.utc(2026, 7, 27, 9),
              reason: 'Нет соединения с сервером',
            ),
          ),
          crafter:
              ({
                required String recipeId,
                required String idempotencyKey,
              }) async {
                craftCalls += 1;
                return _craftingResult();
              },
          impressionRecorder:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                impressionCalls += 1;
                return null;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder craftButton = find.byKey(
      const Key('craft-resonance-compass-v1'),
    );
    await tester.scrollUntilVisible(
      craftButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(craftButton).onPressed, isNull);
    expect(find.text('Создание недоступно офлайн'), findsOneWidget);
    expect(craftCalls, 0);
    expect(impressionCalls, 0);
  });

  testWidgets('equipment unlocks and unequip locks resonance route', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    int keys = 0;
    final List<String> actions = <String>[];
    final List<String?> itemInstanceIds = <String?>[];
    final List<String> idempotencyKeys = <String>[];
    final List<String> impressions = <String>[];
    final List<String> impressionKeys = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            loads += 1;
            return _resonanceEventReady(equipped: loads == 2);
          },
          idempotencyKeyFactory: () => 'equipment-key-${++keys}',
          equipmentExecutor:
              ({
                required String slotId,
                required String action,
                required String? itemInstanceId,
                required String idempotencyKey,
              }) async {
                actions.add(action);
                itemInstanceIds.add(itemInstanceId);
                idempotencyKeys.add(idempotencyKey);
                return _equipmentResult(action: action);
              },
          impressionRecorder:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                expect(commandType, 'RECORD_COMPASS_IMPRESSION');
                impressions.add(payload['impression']! as String);
                impressionKeys.add(idempotencyKey);
                return null;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(impressions, isEmpty);

    final Finder routeChoice = find.byKey(
      const Key('home-event-choice-follow-resonance'),
    );
    await _scrollAboveStickyAction(tester, routeChoice);
    expect(tester.widget<FilledButton>(routeChoice).onPressed, isNull);
    expect(impressions, <String>['ROUTE_LOCKED']);
    expect(
      find.byKey(const Key('home-choice-locked-follow-resonance')),
      findsOneWidget,
    );

    final Finder equip = find.byKey(
      const Key('inventory-equip-resonance-compass'),
    );
    await tester.scrollUntilVisible(
      equip,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(equip);
    await tester.pumpAndSettle();

    expect(actions, <String>['EQUIP']);
    expect(itemInstanceIds, <String?>['33333333-3333-3333-3333-333333333333']);
    expect(idempotencyKeys, <String>['equipment-key-1']);
    expect(loads, 2);
    await _scrollAboveStickyAction(tester, routeChoice);
    expect(tester.widget<FilledButton>(routeChoice).onPressed, isNotNull);
    expect(impressions, <String>['ROUTE_LOCKED', 'ROUTE_AVAILABLE']);

    final Finder unequip = find.byKey(
      const Key('equipment-unequip-NAVIGATION'),
    );
    await tester.scrollUntilVisible(
      unequip,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(unequip);
    await tester.pumpAndSettle();

    expect(actions, <String>['EQUIP', 'UNEQUIP']);
    expect(itemInstanceIds, <String?>[
      '33333333-3333-3333-3333-333333333333',
      null,
    ]);
    expect(idempotencyKeys, <String>['equipment-key-1', 'equipment-key-2']);
    expect(loads, 3);
    await _scrollAboveStickyAction(tester, routeChoice);
    expect(tester.widget<FilledButton>(routeChoice).onPressed, isNull);
    expect(impressions, <String>['ROUTE_LOCKED', 'ROUTE_AVAILABLE']);
    expect(impressionKeys, <String>[
      'compass-impression-chapter-1-v2-'
          'route-mirror-delta-v1-follow-resonance-ROUTE_LOCKED',
      'compass-impression-chapter-1-v2-'
          'route-mirror-delta-v1-follow-resonance-ROUTE_AVAILABLE',
    ]);
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
    expect(find.byKey(const Key('home-error-state')), findsOneWidget);
    expect(find.byType(ExpeditionReadState), findsOneWidget);
    expect(find.textContaining('Backend недоступен'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-error-retry')));
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

Future<void> _scrollAboveStickyAction(
  WidgetTester tester,
  Finder target,
) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();

  final Finder stickyAction = find.byKey(const Key('home-sticky-action-panel'));
  final double targetTop = tester.getTopLeft(target).dy;
  final double stickyTop = tester.getTopLeft(stickyAction).dy;
  const double visibleExtent = 24;
  if (targetTop < stickyTop - visibleExtent) {
    return;
  }

  final ScrollPosition position = tester
      .state<ScrollableState>(find.byType(Scrollable))
      .position;
  position.jumpTo(
    (position.pixels + targetTop - stickyTop + visibleExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble(),
  );
  await tester.pumpAndSettle();
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

HomeSnapshot _craftingReady({CachedReadMetadata? cacheMetadata}) {
  return HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 10000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
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
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 4,
    unlockedEvent: null,
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
      HomeInventoryItem(
        itemId: 'echo-thread',
        name: 'Нить эха',
        description: 'Тонкая нить сохранённого сигнала.',
        quantity: 1,
        version: 1,
      ),
    ],
    craftingRecipes: const <HomeCraftingRecipe>[_readyRecipe],
    cacheMetadata: cacheMetadata,
  );
}

HomeSnapshot _craftingCompleted() {
  final HomeSnapshot ready = _craftingReady();
  return HomeSnapshot(
    localDate: ready.localDate,
    timeZone: ready.timeZone,
    dailySteps: ready.dailySteps,
    dailyGoal: ready.dailyGoal,
    dailyGoalPolicy: ready.dailyGoalPolicy,
    availableEnergy: ready.availableEnergy,
    activityStateVersion: ready.activityStateVersion,
    economyVersion: ready.economyVersion,
    lastActivitySyncAt: ready.lastActivitySyncAt,
    serverTime: ready.serverTime,
    contentVersion: ready.contentVersion,
    expeditionId: ready.expeditionId,
    expeditionName: ready.expeditionName,
    currentNodeId: ready.currentNodeId,
    currentNodeName: ready.currentNodeName,
    expeditionProgress: ready.expeditionProgress,
    requiredEnergy: ready.requiredEnergy,
    expeditionStatus: ready.expeditionStatus,
    expeditionVersion: ready.expeditionVersion,
    unlockedEvent: ready.unlockedEvent,
    pilotName: ready.pilotName,
    pilotLevel: ready.pilotLevel,
    pilotCurrentExperience: ready.pilotCurrentExperience,
    pilotNextLevelExperience: ready.pilotNextLevelExperience,
    petName: ready.petName,
    petLevel: ready.petLevel,
    petBond: ready.petBond,
    inventory: const <HomeInventoryItem>[
      HomeInventoryItem(
        itemId: 'resonance-compass',
        name: 'Резонансный компас',
        description: 'Уникальный прибор.',
        quantity: 1,
        version: 1,
        kind: 'UNIQUE',
      ),
    ],
    craftingRecipes: const <HomeCraftingRecipe>[
      HomeCraftingRecipe(
        recipeId: 'resonance-compass-v1',
        recipeVersion: '1',
        name: 'Резонансный компас',
        description: 'Собрать прибор из трофеев экспедиции.',
        status: 'CRAFTED',
        ingredients: <HomeCraftingIngredient>[
          HomeCraftingIngredient(
            itemId: 'lumen-shard',
            name: 'Люминовый осколок',
            requiredQuantity: 2,
            availableQuantity: 0,
          ),
          HomeCraftingIngredient(
            itemId: 'echo-thread',
            name: 'Нить эха',
            requiredQuantity: 1,
            availableQuantity: 0,
          ),
        ],
        result: HomeCraftingResultPreview(
          itemId: 'resonance-compass',
          name: 'Резонансный компас',
          description: 'Уникальный прибор.',
          kind: 'UNIQUE',
        ),
      ),
    ],
  );
}

HomeSnapshot _resonanceEventReady({required bool equipped}) {
  const String itemInstanceId = '33333333-3333-3333-3333-333333333333';
  return HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 8,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v2',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'mirror-delta',
    currentNodeName: 'Зеркальная дельта',
    expeditionProgress: 95,
    requiredEnergy: 95,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 20,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'mirror-delta-v1',
      title: 'Раздвоенный сигнал',
      summary: 'Два сигнала ведут к разным берегам.',
      status: 'READY',
      choices: <HomeEventChoice>[
        const HomeEventChoice(
          choiceId: 'survey-mirror-delta',
          title: 'Исследовать узел',
          description: 'Сохранить обычный маршрут.',
          pilotExperienceReward: 31,
          petBondReward: 6,
        ),
        HomeEventChoice(
          choiceId: 'follow-resonance',
          title: 'Пойти по резонансу',
          description: 'Настроить компас на скрытое отражение.',
          pilotExperienceReward: 35,
          petBondReward: 16,
          availability: equipped ? 'AVAILABLE' : 'LOCKED',
          requirement: const HomeChoiceRequirement(
            type: 'EQUIPPED_ITEM',
            slotId: 'NAVIGATION',
            slotName: 'Навигационный прибор',
            itemId: 'resonance-compass',
            itemName: 'Резонансный компас',
            description:
                'Экипируйте резонансный компас, чтобы увидеть скрытый маршрут.',
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 2,
    pilotCurrentExperience: 40,
    pilotNextLevelExperience: 160,
    petName: 'Искра',
    petLevel: 2,
    petBond: 40,
    inventory: <HomeInventoryItem>[
      HomeInventoryItem(
        itemInstanceId: itemInstanceId,
        itemId: 'resonance-compass',
        name: 'Резонансный компас',
        description: 'Уникальный навигационный прибор.',
        quantity: 1,
        version: 1,
        kind: 'UNIQUE',
        equippableSlotId: 'NAVIGATION',
        equippedSlotId: equipped ? 'NAVIGATION' : null,
      ),
    ],
    equipment: <HomeEquipmentSlot>[
      HomeEquipmentSlot(
        slotId: 'NAVIGATION',
        name: 'Навигационный прибор',
        description: 'Инструмент, влияющий на доступные маршруты.',
        status: equipped ? 'EQUIPPED' : 'EMPTY',
        version: equipped ? 1 : 2,
        item: equipped
            ? const HomeEquipmentItem(
                itemInstanceId: itemInstanceId,
                itemId: 'resonance-compass',
                name: 'Резонансный компас',
                description: 'Уникальный навигационный прибор.',
              )
            : null,
      ),
    ],
  );
}

const HomeCraftingRecipe _readyRecipe = HomeCraftingRecipe(
  recipeId: 'resonance-compass-v1',
  recipeVersion: '1',
  name: 'Резонансный компас',
  description: 'Собрать прибор из трофеев экспедиции.',
  status: 'READY',
  ingredients: <HomeCraftingIngredient>[
    HomeCraftingIngredient(
      itemId: 'lumen-shard',
      name: 'Люминовый осколок',
      requiredQuantity: 2,
      availableQuantity: 2,
    ),
    HomeCraftingIngredient(
      itemId: 'echo-thread',
      name: 'Нить эха',
      requiredQuantity: 1,
      availableQuantity: 1,
    ),
  ],
  result: HomeCraftingResultPreview(
    itemId: 'resonance-compass',
    name: 'Резонансный компас',
    description: 'Уникальный прибор.',
    kind: 'UNIQUE',
  ),
);

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

CraftingResult _craftingResult() {
  return const CraftingResult(
    contentVersion: 'crafting-v1',
    recipeId: 'resonance-compass-v1',
    recipeVersion: '1',
    recipeName: 'Резонансный компас',
    consumedIngredients: <CraftingIngredientResult>[
      CraftingIngredientResult(
        itemId: 'lumen-shard',
        name: 'Люминовый осколок',
        quantityConsumed: 2,
        quantityAfter: 0,
        version: 2,
      ),
      CraftingIngredientResult(
        itemId: 'echo-thread',
        name: 'Нить эха',
        quantityConsumed: 1,
        quantityAfter: 0,
        version: 2,
      ),
    ],
    craftedItem: CraftedUniqueItem(
      itemInstanceId: '33333333-3333-3333-3333-333333333333',
      itemId: 'resonance-compass',
      name: 'Резонансный компас',
      description: 'Уникальный прибор.',
      version: 1,
      craftedAt: '2026-07-26T06:00:00Z',
    ),
    serverTime: '2026-07-26T06:00:00Z',
  );
}

EquipmentResult _equipmentResult({required String action}) {
  return EquipmentResult(
    contentVersion: 'equipment-v1',
    slotId: 'NAVIGATION',
    slotName: 'Навигационный прибор',
    slotDescription: 'Инструмент, влияющий на доступные маршруты.',
    action: action,
    changed: true,
    version: action == 'EQUIP' ? 1 : 2,
    equippedItem: action == 'EQUIP'
        ? const EquippedItem(
            itemInstanceId: '33333333-3333-3333-3333-333333333333',
            itemId: 'resonance-compass',
            name: 'Резонансный компас',
            description: 'Уникальный навигационный прибор.',
            equippedAt: '2026-07-26T06:00:00Z',
          )
        : null,
    serverTime: '2026-07-26T06:00:00Z',
  );
}
