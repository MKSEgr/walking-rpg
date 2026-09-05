// Render the real Home widget with synthetic accepted fixtures. These captures
// support design review and are never physical-device evidence.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

const bool _capture = bool.fromEnvironment('HOME_SCENE_CAPTURE');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!_capture) return;
    final String root = Platform.environment['FLUTTER_ROOT']!;
    final FontLoader font = FontLoader('Roboto');
    for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
      font.addFont(
        File(
          '$root/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await font.load();
    final FontLoader icons = FontLoader('MaterialIcons');
    icons.addFont(
      File(
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await icons.load();
  });

  const List<
    ({
      String name,
      String pet,
      String locale,
      bool dark,
      Size size,
      double scale,
      bool reduced,
    })
  >
  cases =
      <
        ({
          String name,
          String pet,
          String locale,
          bool dark,
          Size size,
          double scale,
          bool reduced,
        })
      >[
        (
          name: 'home-dark-spark-ru',
          pet: 'spark-v1',
          locale: 'ru',
          dark: true,
          size: Size(390, 844),
          scale: 1,
          reduced: false,
        ),
        (
          name: 'home-light-moss-ru',
          pet: 'moss-v1',
          locale: 'ru',
          dark: false,
          size: Size(390, 844),
          scale: 1,
          reduced: false,
        ),
        (
          name: 'home-dark-rune-en',
          pet: 'rune-v1',
          locale: 'en',
          dark: true,
          size: Size(390, 844),
          scale: 1,
          reduced: false,
        ),
        (
          name: 'home-narrow-large-ru',
          pet: 'spark-v1',
          locale: 'ru',
          dark: true,
          size: Size(320, 640),
          scale: 1.6,
          reduced: false,
        ),
        (
          name: 'home-large-text-en',
          pet: 'moss-v1',
          locale: 'en',
          dark: false,
          size: Size(500, 800),
          scale: 2,
          reduced: false,
        ),
        (
          name: 'home-reduced-motion-ru',
          pet: 'spark-v1',
          locale: 'ru',
          dark: true,
          size: Size(390, 844),
          scale: 1,
          reduced: true,
        ),
      ];
  for (final scenario in cases) {
    testWidgets('render ${scenario.name}', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(scenario.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const Key captureKey = Key('home-preview');
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: Locale(scenario.locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme:
                (scenario.dark
                        ? WalkingRpgTheme.dark()
                        : WalkingRpgTheme.light())
                    .copyWith(
                      textTheme:
                          (scenario.dark
                                  ? WalkingRpgTheme.dark()
                                  : WalkingRpgTheme.light())
                              .textTheme
                              .apply(fontFamily: 'Roboto'),
                    ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scenario.scale),
                disableAnimations: scenario.reduced,
              ),
              child: child!,
            ),
            home: MainNavigationShell(
              home: HomeScreen(loader: () async => _snapshot(scenario.pet)),
              platform: const SizedBox(),
              crew: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final Image image in tester.widgetList<Image>(
          find.byType(Image),
        )) {
          await precacheImage(
            image.image,
            tester.element(find.byKey(captureKey)),
          );
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scenario.scale == 1) {
        final Rect scene = tester.getRect(
          find.byKey(const Key('home-crew-scene')),
        );
        final Rect action = tester.getRect(
          find.byKey(const Key('home-sticky-action-panel')),
        );
        expect(scene.bottom, lessThanOrEqualTo(action.top));
        for (final String actor in <String>[
          'home-pilot-motion-portrait',
          'home-active-companion-portrait',
        ]) {
          final Rect bounds = tester.getRect(find.byKey(Key(actor)));
          expect(scene.contains(bounds.center), isTrue);
          expect(bounds.top, greaterThanOrEqualTo(scene.top));
          expect(bounds.bottom, lessThanOrEqualTo(scene.bottom));
        }
      }
      final RenderRepaintBoundary boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage();
        final ByteData bytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        final File file = File('build/home-previews/${scenario.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }, skip: !_capture);
  }
}

HomeSnapshot _snapshot(String petId) {
  final HomeSnapshot demo = HomeSnapshot.demo;
  return HomeSnapshot(
    localDate: demo.localDate,
    timeZone: demo.timeZone,
    dailySteps: 3240,
    dailyGoal: demo.dailyGoal,
    availableEnergy: 32,
    activityStateVersion: demo.activityStateVersion,
    economyVersion: demo.economyVersion,
    lastActivitySyncAt: demo.lastActivitySyncAt,
    serverTime: demo.serverTime,
    contentVersion: demo.contentVersion,
    expeditionId: demo.expeditionId,
    expeditionName: demo.expeditionName,
    currentNodeId: demo.currentNodeId,
    currentNodeName: demo.currentNodeName,
    expeditionProgress: 24,
    requiredEnergy: demo.requiredEnergy,
    expeditionStatus: demo.expeditionStatus,
    expeditionVersion: demo.expeditionVersion,
    unlockedEvent: null,
    pilotId: demo.pilotId,
    pilotName: demo.pilotName,
    pilotLevel: demo.pilotLevel,
    petId: petId,
    petName: switch (petId) {
      'moss-v1' => 'Мох',
      'rune-v1' => 'Навигатор',
      _ => 'Искра',
    },
    petSpecies: switch (petId) {
      'moss-v1' => 'терра',
      'rune-v1' => 'эхо',
      _ => 'люмин',
    },
    petEvolutionStage: 0,
    petLevel: 1,
    routeTrail: demo.routeTrail,
  );
}
