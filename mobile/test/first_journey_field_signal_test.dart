import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';
import 'package:walking_rpg_mobile/features/onboarding/presentation/first_journey_screen.dart';

import 'support/first_journey_fixture.dart';
import 'support/platform_fixture.dart';

void main() {
  testWidgets('first journey field signals stay complete on compact text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    const String notice =
        'Отложенная команда ждёт соединения и будет проверена без второй '
        'награды.';
    const String error =
        'Команда подтверждена, но актуальное состояние маршрута не загрузилось.';
    final FirstJourneyProgress progress = FirstJourneyProgress(
      home: firstJourneyHome(
        cacheMetadata: CachedReadMetadata(
          cachedAt: DateTime.utc(2026, 8, 2, 18),
          reason: 'Нет соединения с сервером',
        ),
      ),
      platform: platformSnapshot(
        completedOnboardingSteps: const <String>[],
        resolvedEventCount: 0,
        totalAcceptedSteps: 0,
      ),
    );

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
        home: FirstJourneyScreen(
          progress: progress,
          busy: false,
          onWelcome: () {},
          onSync: () {},
          onSelectPet: (_) {},
          onAdvance: () {},
          onResolve: (_) {},
          onContinueAfterActivity: () {},
          onFinish: () {},
          onContinueLater: () {},
          notice: notice,
          errorMessage: error,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpeditionNotice), findsNWidgets(3));
    expect(find.text('СОХРАНЁННЫЙ ПУТЬ'), findsOneWidget);
    expect(find.text('СИГНАЛ МАРШРУТА'), findsOneWidget);
    expect(find.text('СОСТОЯНИЕ ТРЕБУЕТ ПРОВЕРКИ'), findsOneWidget);
    expect(find.text(notice), findsOneWidget);
    expect(find.text(error), findsOneWidget);

    final ExpeditionNotice saved = tester.widget<ExpeditionNotice>(
      find.byKey(const Key('first-journey-read-only-signal')),
    );
    final ExpeditionNotice info = tester.widget<ExpeditionNotice>(
      find.byKey(const Key('first-journey-notice-signal')),
    );
    final ExpeditionNotice uncertain = tester.widget<ExpeditionNotice>(
      find.byKey(const Key('first-journey-error-signal')),
    );
    expect(saved.tone, ExpeditionNoticeTone.neutral);
    expect(info.tone, ExpeditionNoticeTone.lumen);
    expect(uncertain.tone, ExpeditionNoticeTone.resonance);

    for (final Key key in <Key>[
      const Key('first-journey-read-only-signal'),
      const Key('first-journey-notice-signal'),
      const Key('first-journey-error-signal'),
    ]) {
      final Semantics liveSignal = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(Semantics),
            ),
          )
          .firstWhere(
            (Semantics widget) =>
                widget.container && widget.properties.liveRegion == true,
          );
      expect(liveSignal.properties.liveRegion, isTrue);
    }

    final Text errorLabel = tester.widget<Text>(
      find.text('СОСТОЯНИЕ ТРЕБУЕТ ПРОВЕРКИ'),
    );
    expect(errorLabel.maxLines, isNull);
    expect(errorLabel.overflow, TextOverflow.visible);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
