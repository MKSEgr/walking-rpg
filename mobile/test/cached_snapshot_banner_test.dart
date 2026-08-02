import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/cached_snapshot_banner.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('cached route trust state stays complete on compact text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    const String reason =
        'Сервер временно недоступен, поэтому используется последняя '
        'подтверждённая копия маршрута.';
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
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CachedSnapshotBanner(
              metadata: CachedReadMetadata(
                cachedAt: DateTime.utc(2026, 7, 27, 9),
                reason: reason,
              ),
              title: 'Маршрут доступен только для чтения',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ExpeditionPanel), findsOneWidget);
    final Text badge = tester.widget<Text>(find.text('СОХРАНЁННЫЙ МАРШРУТ'));
    expect(badge.maxLines, isNull);
    expect(badge.overflow, TextOverflow.visible);
    expect(find.text('Маршрут доступен только для чтения'), findsOneWidget);
    expect(find.textContaining('27.07.2026'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);

    final Semantics banner = tester.widget<Semantics>(
      find.byKey(const Key('cached-snapshot-banner')),
    );
    expect(banner.container, isTrue);
    expect(banner.properties.liveRegion, isTrue);
    final Semantics heading = tester.widget<Semantics>(
      find.byKey(const Key('cached-snapshot-heading')),
    );
    expect(heading.properties.header, isTrue);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
