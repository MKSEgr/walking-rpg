import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/presentation/platform_screen.dart';

import 'support/platform_fixture.dart';

void main() {
  testWidgets('renders platform snapshot and completes onboarding command', (
    WidgetTester tester,
  ) async {
    final PlatformSnapshot initial = platformSnapshot();
    final PlatformSnapshot updated = platformSnapshot(
      stateVersion: 4,
      completedOnboardingSteps: const <String>['welcome', 'health-permission'],
    );
    String? sentType;
    Map<String, Object?>? sentPayload;
    String? sentKey;
    int serverStateChanges = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => initial,
          homeLoader: () async => HomeSnapshot.demo,
          idempotencyKeyFactory: (String type) => 'fixed-$type',
          recordExperimentExposures: false,
          onServerStateChanged: () {
            serverStateChanges += 1;
          },
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                sentType = commandType;
                sentPayload = payload;
                sentKey = idempotencyKey;
                return platformCommandResult(
                  commandType: commandType,
                  idempotencyKey: idempotencyKey,
                  snapshot: updated,
                  message: 'Шаг onboarding завершён',
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Путевой журнал'), findsOneWidget);
    expect(find.text('Сезон первого сигнала'), findsWidgets);
    expect(find.text('1/4'), findsOneWidget);

    final Finder complete = find.byKey(
      const Key('platform-complete-onboarding-health-permission'),
    );
    await tester.tap(complete);
    await tester.pumpAndSettle();

    expect(sentType, 'COMPLETE_ONBOARDING_STEP');
    expect(sentPayload, <String, Object?>{'stepId': 'health-permission'});
    expect(sentKey, 'fixed-COMPLETE_ONBOARDING_STEP');
    expect(serverStateChanges, 1);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('Шаг onboarding завершён'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-complete-onboarding-first-sync')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Искра · уровень 1'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Искра · уровень 1'), findsOneWidget);
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

    final Finder complete = find.byKey(
      const Key('platform-complete-onboarding-health-permission'),
    );
    await tester.tap(complete);
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось выполнить действие: Недостаточно сезонного опыта'),
      findsOneWidget,
    );
  });
}
