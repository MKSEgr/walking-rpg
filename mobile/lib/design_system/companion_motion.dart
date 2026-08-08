import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/companion_growth.dart';
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
  north(0),
  northNorthEast(1),
  northEast(2),
  eastNorthEast(3),
  east(4),
  eastSouthEast(5),
  southEast(6),
  southSouthEast(7),
  south(8),
  southSouthWest(9),
  southWest(10),
  westSouthWest(11),
  west(12),
  westNorthWest(13),
  northWest(14),
  northNorthWest(15);

  const CompanionLookDirection(this.index);

  final int index;

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

  bool get hasMotionAsset => petId == 'spark-v1';

  @override
  Widget build(BuildContext context) {
    if (!hasMotionAsset) {
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
    final String activeLabel = active ? ', активный спутник' : '';

    return Semantics(
      image: true,
      label:
          '$name, $species, ${CompanionGrowth.formLabel(evolutionStage)}'
          '$activeLabel',
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
                child: _SparkMotionPlayer(
                  clip: clip,
                  lookDirection: lookDirection,
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

class _SparkMotionPlayer extends StatefulWidget {
  const _SparkMotionPlayer({
    required this.clip,
    required this.lookDirection,
    required this.play,
    required this.loop,
  });

  final CompanionMotionClip clip;
  final CompanionLookDirection? lookDirection;
  final bool play;
  final bool loop;

  @override
  State<_SparkMotionPlayer> createState() => _SparkMotionPlayerState();
}

class _SparkMotionPlayerState extends State<_SparkMotionPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.clip.duration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion != _reduceMotion || !_controller.isAnimating) {
      _reduceMotion = reduceMotion;
      _applyPlayback();
    }
  }

  @override
  void didUpdateWidget(covariant _SparkMotionPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip != widget.clip ||
        oldWidget.lookDirection != widget.lookDirection ||
        oldWidget.play != widget.play ||
        oldWidget.loop != widget.loop) {
      _applyPlayback();
    }
  }

  void _applyPlayback() {
    _controller
      ..stop()
      ..duration = widget.clip.duration;
    if (_reduceMotion || !widget.play || widget.lookDirection != null) {
      _controller.value = 0;
      return;
    }
    if (widget.loop && widget.clip.loops) {
      _controller.repeat();
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final CompanionLookDirection? lookDirection = widget.lookDirection;
        if (lookDirection != null) {
          return _SparkAtlasFrame(
            row: lookDirection.row,
            column: lookDirection.column,
          );
        }
        final int frame = math.min(
          (_controller.value * widget.clip.frameCount).floor(),
          widget.clip.frameCount - 1,
        );
        return _SparkAtlasFrame(row: widget.clip.row, column: frame);
      },
    );
  }
}

class _SparkAtlasFrame extends StatelessWidget {
  const _SparkAtlasFrame({required this.row, required this.column});

  static const String assetPath =
      'assets/characters/companion_spark_motion_v1.png';
  static const double atlasWidth = 1536;
  static const double atlasHeight = 2288;
  static const double cellWidth = 192;
  static const double cellHeight = 208;

  final int row;
  final int column;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale = math.min(
          constraints.maxWidth / cellWidth,
          constraints.maxHeight / cellHeight,
        );
        final double frameWidth = cellWidth * scale;
        final double frameHeight = cellHeight * scale;
        final double sheetWidth = atlasWidth * scale;
        final double sheetHeight = atlasHeight * scale;

        return Center(
          child: SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: ClipRect(
              key: Key('companion-motion-frame-spark-v1-$row-$column'),
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: sheetWidth,
                maxWidth: sheetWidth,
                minHeight: sheetHeight,
                maxHeight: sheetHeight,
                child: Transform.translate(
                  offset: Offset(-column * frameWidth, -row * frameHeight),
                  child: Image.asset(
                    assetPath,
                    width: sheetWidth,
                    height: sheetHeight,
                    fit: BoxFit.fill,
                    alignment: Alignment.topLeft,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
