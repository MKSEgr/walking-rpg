import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_destination_visibility.dart';
import 'package:walking_rpg_mobile/design_system/companion_motion.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/expedition_crew_scene.dart';
import 'package:walking_rpg_mobile/design_system/pilot_motion.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('crew greets together without continuous animation', (
    tester,
  ) async {
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(_scene(scroll: scroll));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('pilot-motion-frame-navigator-v1-0-5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('companion-motion-frame-spark-v1-0-5')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('home-greet-crew')));
    await tester.pump();
    expect(
      find.byKey(const Key('pilot-motion-frame-navigator-v1-3-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('companion-motion-frame-spark-v1-3-0')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scene stops when scrolled away, hidden or backgrounded', (
    tester,
  ) async {
    final ScrollController scroll = ScrollController();
    final ValueNotifier<bool> visible = ValueNotifier<bool>(true);
    addTearDown(scroll.dispose);
    addTearDown(visible.dispose);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, value, _) => NavigationDestinationVisibility(
          isVisible: value,
          child: _scene(scroll: scroll),
        ),
      ),
    );
    await tester.pumpAndSettle();
    bool playing() => tester
        .widget<PilotMotionPortrait>(find.byType(PilotMotionPortrait))
        .play;
    expect(playing(), isTrue);
    scroll.jumpTo(700);
    await tester.pumpAndSettle();
    expect(playing(), isFalse);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(playing(), isTrue);
    visible.value = false;
    await tester.pumpAndSettle();
    expect(playing(), isFalse);
    visible.value = true;
    await tester.pumpAndSettle();
    // The platform leaves resumed via inactive. A fully paused scheduler does
    // not build frames, so inspect the stopped actors before pausing it.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(playing(), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(playing(), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(playing(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion holds both actors still', (tester) async {
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(_scene(scroll: scroll, reduceMotion: true));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('pilot-motion-frame-navigator-v1-0-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('companion-motion-frame-spark-v1-0-0')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('home-greet-crew')))
          .onPressed,
      isNull,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('unknown companion keeps the neutral portrait fallback', (
    tester,
  ) async {
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(_scene(scroll: scroll, petId: 'future-pet'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CompanionMotionPortrait>(find.byType(CompanionMotionPortrait))
          .hasMotionAsset,
      isFalse,
    );
    expect(find.byType(CompanionPortrait), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _scene({
  required ScrollController scroll,
  bool reduceMotion = false,
  String petId = 'spark-v1',
}) => MaterialApp(
  theme: WalkingRpgTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      size: const Size(390, 844),
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        controller: scroll,
        child: Column(
          children: <Widget>[
            ExpeditionCrewScene(
              background: const ColoredBox(color: WalkingRpgColors.deepWater),
              pilotName: 'Навигатор',
              greetingLabel: 'Поприветствовать экипаж',
              scrollController: scroll,
              height: 330,
              petId: petId,
              petName: 'Искра',
              petSpecies: 'люмин',
              petEvolutionStage: 0,
            ),
            const SizedBox(height: 1200),
          ],
        ),
      ),
    ),
  ),
);
