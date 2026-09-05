import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/design_system/character_motion_atlas.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum CompanionMotionClip {
  idle(row: 0, frameCount: 6, framesPerSecond: 8, loops: true),
  runRight(row: 1, frameCount: 8, framesPerSecond: 12, loops: true),
  runLeft(row: 2, frameCount: 8, framesPerSecond: 12, loops: true),
  greet(row: 3, frameCount: 4, framesPerSecond: 8, loops: false),
  jump(row: 4, frameCount: 5, framesPerSecond: 10, loops: false),
  tired(row: 5, frameCount: 8, framesPerSecond: 8, loops: false),
  waiting(row: 6, frameCount: 6, framesPerSecond: 6, loops: true),
  sensing(row: 7, frameCount: 6, framesPerSecond: 8, loops: true),
  inspect(row: 8, frameCount: 6, framesPerSecond: 6, loops: true);

  const CompanionMotionClip({
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

enum CompanionLookDirection {
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

class CompanionMotionPortrait extends StatelessWidget {
  const CompanionMotionPortrait({
    super.key,
    required this.petId,
    required this.name,
    required this.species,
    required this.evolutionStage,
    this.active = false,
    this.size = 78,
    this.clip = CompanionMotionClip.idle,
    this.lookDirection,
    this.play = true,
    this.loop = false,
    this.framed = true,
  }) : assert(size > 0);

  final String petId;
  final String name;
  final String species;
  final int evolutionStage;
  final bool active;
  final double size;
  final CompanionMotionClip clip;
  final CompanionLookDirection? lookDirection;
  final bool play;
  final bool loop;

  /// Scene actors share their environment instead of drawing a portrait tile.
  final bool framed;

  String? get motionAssetPath => switch (petId) {
    'spark-v1' => 'assets/characters/companion_spark_motion_v1.png',
    'moss-v1' => 'assets/characters/companion_moss_motion_v1.png',
    'rune-v1' => 'assets/characters/companion_rune_motion_v1.png',
    _ => null,
  };

  bool get hasMotionAsset => motionAssetPath != null;

  @override
  Widget build(BuildContext context) {
    final String? assetPath = motionAssetPath;
    if (assetPath == null) {
      return CompanionPortrait(
        petId: petId,
        name: name,
        species: species,
        evolutionStage: evolutionStage,
        active: active,
        size: size,
      );
    }

    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Widget motion = CharacterMotionAtlasPlayer(
      assetPath: assetPath,
      frameKeyPrefix: 'companion-motion-frame-$petId',
      clipRow: clip.row,
      frameCount: clip.frameCount,
      clipDuration: clip.duration,
      clipLoops: clip.loops,
      lookRow: lookDirection?.row,
      lookColumn: lookDirection?.column,
      play: play,
      loop: loop,
    );
    if (!framed) {
      return Semantics(
        image: true,
        label: context.l10n.companionPortraitDescription(
          name: name,
          species: species,
          stage: evolutionStage,
          active: active,
          hasSparkHalo: false,
        ),
        child: RepaintBoundary(
          child: SizedBox.square(dimension: size, child: motion),
        ),
      );
    }
    return Semantics(
      image: true,
      label: context.l10n.companionPortraitDescription(
        name: name,
        species: species,
        stage: evolutionStage,
        active: active,
        hasSparkHalo: false,
      ),
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(size * 0.3),
            border: Border.all(
              color: (active ? colors.primary : palette.panelBorder).withValues(
                alpha: active ? 0.86 : 0.72,
              ),
              width: active ? 2.2 : 1.25,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.shadow.withValues(alpha: 0.48),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.3),
            child: SizedBox.square(
              dimension: size,
              child: Padding(
                padding: EdgeInsets.all(size * 0.035),
                child: motion,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
