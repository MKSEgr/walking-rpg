import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/character_cosmetics.dart';
import 'package:walking_rpg_mobile/design_system/character_motion_atlas.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum PilotMotionClip {
  idle(row: 0, frameCount: 6, framesPerSecond: 8, loops: true),
  runRight(row: 1, frameCount: 8, framesPerSecond: 12, loops: true),
  runLeft(row: 2, frameCount: 8, framesPerSecond: 12, loops: true),
  greet(row: 3, frameCount: 4, framesPerSecond: 8, loops: false),
  jump(row: 4, frameCount: 5, framesPerSecond: 10, loops: false),
  tired(row: 5, frameCount: 8, framesPerSecond: 8, loops: false),
  waiting(row: 6, frameCount: 6, framesPerSecond: 6, loops: true),
  sensing(row: 7, frameCount: 6, framesPerSecond: 8, loops: true),
  inspect(row: 8, frameCount: 6, framesPerSecond: 6, loops: true);

  const PilotMotionClip({
    required this.row,
    required this.frameCount,
    required this.framesPerSecond,
    required this.loops,
  });

  final int row;
  final int frameCount;
  final int framesPerSecond;
  final bool loops;

  Duration get duration =>
      Duration(milliseconds: (frameCount * 1000 / framesPerSecond).round());
}

enum PilotLookDirection {
  north,
  northNorthEast,
  northEast,
  eastNorthEast,
  east,
  eastSouthEast,
  southEast,
  southSouthEast,
  south,
  southSouthWest,
  southWest,
  westSouthWest,
  west,
  westNorthWest,
  northWest,
  northNorthWest;

  int get row => index < 8 ? 9 : 10;
  int get column => index % 8;
  double get degrees => index * 22.5;
}

class PilotMotionPortrait extends StatelessWidget {
  const PilotMotionPortrait({
    super.key,
    required this.pilotId,
    required this.name,
    this.size = 72,
    this.highlighted = false,
    this.equippedCosmeticIds = const <String>{},
    this.clip = PilotMotionClip.idle,
    this.lookDirection,
    this.play = true,
    this.loop = false,
  }) : assert(size > 0);

  static const String navigatorPilotId = 'navigator-v1';
  static const String navigatorMotionAssetPath =
      'assets/characters/pilot_navigator_motion_v1.png';

  final String pilotId;
  final String name;
  final double size;
  final bool highlighted;
  final Set<String> equippedCosmeticIds;
  final PilotMotionClip clip;
  final PilotLookDirection? lookDirection;
  final bool play;
  final bool loop;

  bool get hasNavigatorScarf {
    return equippedCosmeticIds.contains(CharacterCosmeticIds.pilotScarf);
  }

  String? get motionAssetPath {
    if (pilotId != navigatorPilotId || hasNavigatorScarf) {
      return null;
    }
    return navigatorMotionAssetPath;
  }

  bool get hasMotionAsset => motionAssetPath != null;

  @override
  Widget build(BuildContext context) {
    final String? assetPath = motionAssetPath;
    if (assetPath == null) {
      return PilotPortrait(
        name: name,
        size: size,
        highlighted: highlighted,
        equippedCosmeticIds: equippedCosmeticIds,
      );
    }

    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final double radius = size * 0.29;
    final double inset = math.max(2.0, size * 0.035);
    final PilotLookDirection? direction = lookDirection;

    return Semantics(
      image: true,
      label: 'Пилот $name',
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: (highlighted ? colors.primary : palette.panelBorder)
                    .withValues(alpha: highlighted ? 0.9 : 0.76),
                width: highlighted ? 2.2 : 1.25,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.48),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  math.max(0.0, radius - inset),
                ),
                child: CharacterMotionAtlasPlayer(
                  assetPath: assetPath,
                  frameKeyPrefix: 'pilot-motion-frame-$pilotId',
                  clipRow: clip.row,
                  frameCount: clip.frameCount,
                  clipDuration: clip.duration,
                  clipLoops: clip.loops,
                  lookRow: direction?.row,
                  lookColumn: direction?.column,
                  play: play,
                  loop: loop,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
