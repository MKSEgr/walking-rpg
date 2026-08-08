import 'dart:math' as math;

import 'package:flutter/material.dart';

class CharacterMotionAtlasPlayer extends StatefulWidget {
  const CharacterMotionAtlasPlayer({
    super.key,
    required this.assetPath,
    required this.frameKeyPrefix,
    required this.clipRow,
    required this.frameCount,
    required this.clipDuration,
    required this.clipLoops,
    required this.play,
    required this.loop,
    this.lookRow,
    this.lookColumn,
  }) : assert(frameCount > 0),
       assert((lookRow == null) == (lookColumn == null));

  final String assetPath;
  final String frameKeyPrefix;
  final int clipRow;
  final int frameCount;
  final Duration clipDuration;
  final bool clipLoops;
  final int? lookRow;
  final int? lookColumn;
  final bool play;
  final bool loop;

  @override
  State<CharacterMotionAtlasPlayer> createState() =>
      _CharacterMotionAtlasPlayerState();
}

class _CharacterMotionAtlasPlayerState extends State<CharacterMotionAtlasPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.clipDuration,
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
  void didUpdateWidget(covariant CharacterMotionAtlasPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath ||
        oldWidget.clipRow != widget.clipRow ||
        oldWidget.frameCount != widget.frameCount ||
        oldWidget.clipDuration != widget.clipDuration ||
        oldWidget.clipLoops != widget.clipLoops ||
        oldWidget.lookRow != widget.lookRow ||
        oldWidget.lookColumn != widget.lookColumn ||
        oldWidget.play != widget.play ||
        oldWidget.loop != widget.loop) {
      _applyPlayback();
    }
  }

  void _applyPlayback() {
    _controller
      ..stop()
      ..duration = widget.clipDuration;
    if (_reduceMotion || !widget.play || widget.lookRow != null) {
      _controller.value = 0;
      return;
    }
    if (widget.loop && widget.clipLoops) {
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
        final int? lookRow = widget.lookRow;
        final int? lookColumn = widget.lookColumn;
        if (lookRow != null && lookColumn != null) {
          return _CharacterMotionAtlasFrame(
            assetPath: widget.assetPath,
            frameKeyPrefix: widget.frameKeyPrefix,
            row: lookRow,
            column: lookColumn,
          );
        }
        final int frame = math.min(
          (_controller.value * widget.frameCount).floor(),
          widget.frameCount - 1,
        );
        return _CharacterMotionAtlasFrame(
          assetPath: widget.assetPath,
          frameKeyPrefix: widget.frameKeyPrefix,
          row: widget.clipRow,
          column: frame,
        );
      },
    );
  }
}

class _CharacterMotionAtlasFrame extends StatelessWidget {
  const _CharacterMotionAtlasFrame({
    required this.assetPath,
    required this.frameKeyPrefix,
    required this.row,
    required this.column,
  });

  static const double atlasWidth = 1536;
  static const double atlasHeight = 2288;
  static const double cellWidth = 192;
  static const double cellHeight = 208;

  final String assetPath;
  final String frameKeyPrefix;
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
              key: Key('$frameKeyPrefix-$row-$column'),
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
