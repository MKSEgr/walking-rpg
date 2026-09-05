import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/expedition_crew_scene.dart';

/// Measures the HUD before fitting the cast into the uncovered part of the
/// scene. Detail scrolling has its own clipped viewport between the controls.
class ExpeditionHomeStage extends StatelessWidget {
  const ExpeditionHomeStage({
    super.key,
    required this.scene,
    required this.header,
    required this.footer,
    required this.details,
    required this.topInset,
    required this.bottomInset,
  });

  final Widget scene;
  final Widget header;
  final Widget footer;
  final Widget details;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewport) => ClipRect(
      key: const Key('home-expedition-visual-stage'),
      child: CustomMultiChildLayout(
        delegate: _HomeStageLayout(topInset, bottomInset),
        children: <Widget>[
          LayoutId(
            id: _Layer.background,
            child: Image.asset(
              'assets/scenes/home_frontier_v3.webp',
              key: const Key('home-fullscreen-background'),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          LayoutId(
            id: _Layer.scene,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (Rect bounds) => LinearGradient(
                colors: const <Color>[
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: bounds.height < viewport.maxHeight
                    ? const <double>[0, 0.24, 0.82, 1]
                    : const <double>[0, 0.04, 0.96, 1],
              ).createShader(bounds),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (Rect bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const <Color>[
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: bounds.height < viewport.maxHeight
                      ? const <double>[0.10, 0.235, 0.71, 0.90]
                      : const <double>[0, 0.035, 0.965, 1],
                ).createShader(bounds),
                child: scene,
              ),
            ),
          ),
          LayoutId(id: _Layer.details, child: details),
          LayoutId(id: _Layer.header, child: header),
          LayoutId(id: _Layer.footer, child: footer),
        ],
      ),
      ),
    );
  }
}

enum _Layer { background, scene, details, header, footer }

class _HomeStageLayout extends MultiChildLayoutDelegate {
  _HomeStageLayout(this.topInset, this.bottomInset);

  final double topInset;
  final double bottomInset;

  @override
  void performLayout(Size size) {
    layoutChild(_Layer.background, BoxConstraints.tight(size));
    positionChild(_Layer.background, Offset.zero);
    final double gutter = size.width < 360 ? 12 : 20;
    final BoxConstraints hud = BoxConstraints.tightFor(
      width: math.max(0, size.width - gutter * 2),
    );
    final Size header = layoutChild(_Layer.header, hud);
    final Size footer = layoutChild(_Layer.footer, hud);
    positionChild(_Layer.header, Offset(gutter, topInset));
    final double footerTop = size.height - bottomInset - footer.height;
    positionChild(_Layer.footer, Offset(gutter, footerTop));

    final double gapTop = topInset + header.height + 12;
    final double gapHeight = math.max(0, footerTop - 12 - gapTop);
    final double actorHeight = math.max(0, gapHeight - 52);
    final Rect subjects = ExpeditionCrewScene.subjectBounds;
    final double artHeight = math.max(
      1,
      math.min(
        actorHeight / subjects.height,
        (size.width - 24) / (subjects.width * ExpeditionCrewScene.aspectRatio),
      ),
    );
    final double artWidth = artHeight * ExpeditionCrewScene.aspectRatio;
    layoutChild(_Layer.scene, BoxConstraints.tight(Size(artWidth, artHeight)));
    positionChild(
      _Layer.scene,
      Offset(
        size.width / 2 - artWidth * subjects.center.dx,
        gapTop + actorHeight / 2 - artHeight * subjects.center.dy,
      ),
    );
    layoutChild(
      _Layer.details,
      BoxConstraints.tight(Size(size.width, gapHeight)),
    );
    positionChild(_Layer.details, Offset(0, gapTop));
  }

  @override
  bool shouldRelayout(_HomeStageLayout oldDelegate) =>
      topInset != oldDelegate.topInset ||
      bottomInset != oldDelegate.bottomInset;
}

/// A restrained smoked-glass surface shared by the Home HUD controls.
class ExpeditionHudPanel extends StatelessWidget {
  const ExpeditionHudPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xE0152228), Color(0xC008151D)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x668D8267)),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Padding(padding: padding, child: child),
  );
}
