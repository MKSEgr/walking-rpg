import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/expedition_crew_scene.dart';
import 'package:walking_rpg_mobile/design_system/expedition_home_atmosphere.dart';

/// Fits the cast into the space left by the HUD. Short landscape displays use
/// side-by-side, independently scrollable gameplay and HUD regions.
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
      builder: (BuildContext context, BoxConstraints viewport) {
        final EdgeInsets safePadding = MediaQuery.paddingOf(context);
        final Widget background = Image.asset(
          'assets/scenes/home_frontier_v3.webp',
          key: const Key('home-fullscreen-background'),
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        );
        final Widget sceneLayer = _SceneMask(
          viewportHeight: viewport.maxHeight,
          child: scene,
        );
        final bool useShortLandscape =
            viewport.maxWidth > viewport.maxHeight &&
            viewport.maxHeight <= _shortLandscapeMaximumHeight;
        return ClipRect(
          key: const Key('home-expedition-visual-stage'),
          child: CustomMultiChildLayout(
            delegate: useShortLandscape
                ? _ShortLandscapeHomeStageLayout(
                    topInset: topInset,
                    bottomInset: bottomInset,
                    leftInset: safePadding.left,
                    rightInset: safePadding.right,
                  )
                : _HomeStageLayout(
                    topInset,
                    bottomInset,
                    safePadding.left,
                    safePadding.right,
                  ),
            children: <Widget>[
              LayoutId(id: _Layer.background, child: background),
              LayoutId(id: _Layer.scene, child: sceneLayer),
              const LayoutId(
                id: _Layer.atmosphere,
                child: ExpeditionHomeAtmosphere(),
              ),
              LayoutId(id: _Layer.details, child: details),
              if (useShortLandscape)
                LayoutId(
                  id: _Layer.controls,
                  child: _LandscapeHudScroller(header: header, footer: footer),
                )
              else ...<Widget>[
                LayoutId(id: _Layer.header, child: header),
                LayoutId(id: _Layer.footer, child: footer),
              ],
            ],
          ),
        );
      },
    );
  }
}

const double _shortLandscapeMaximumHeight = 480;

class _LandscapeHudScroller extends StatefulWidget {
  const _LandscapeHudScroller({required this.header, required this.footer});

  final Widget header;
  final Widget footer;

  @override
  State<_LandscapeHudScroller> createState() => _LandscapeHudScrollerState();
}

class _LandscapeHudScrollerState extends State<_LandscapeHudScroller> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: true,
    child: SingleChildScrollView(
      key: const Key('home-landscape-hud-scroll'),
      controller: _controller,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          widget.header,
          const SizedBox(height: 12),
          widget.footer,
        ],
      ),
    ),
  );
}

class _SceneMask extends StatelessWidget {
  const _SceneMask({required this.viewportHeight, required this.child});

  final double viewportHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (Rect bounds) => LinearGradient(
      colors: const <Color>[
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: bounds.height < viewportHeight
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
        stops: bounds.height < viewportHeight
            ? const <double>[0.10, 0.235, 0.71, 0.90]
            : const <double>[0, 0.035, 0.965, 1],
      ).createShader(bounds),
      child: child,
    ),
  );
}

enum _Layer { background, scene, atmosphere, details, header, footer, controls }

class _HomeStageLayout extends MultiChildLayoutDelegate {
  _HomeStageLayout(
    this.topInset,
    this.bottomInset,
    this.leftInset,
    this.rightInset,
  );

  final double topInset;
  final double bottomInset;
  final double leftInset;
  final double rightInset;

  @override
  void performLayout(Size size) {
    layoutChild(_Layer.background, BoxConstraints.tight(size));
    positionChild(_Layer.background, Offset.zero);
    layoutChild(_Layer.atmosphere, BoxConstraints.tight(size));
    positionChild(_Layer.atmosphere, Offset.zero);
    final double gutter = size.width < 360 ? 12 : 20;
    final BoxConstraints hud = BoxConstraints.tightFor(
      width: math.max(0, size.width - leftInset - rightInset - gutter * 2),
    );
    final Size header = layoutChild(_Layer.header, hud);
    final Size footer = layoutChild(_Layer.footer, hud);
    final double contentLeft = leftInset + gutter;
    positionChild(_Layer.header, Offset(contentLeft, topInset));
    final double footerTop = size.height - bottomInset - footer.height;
    positionChild(_Layer.footer, Offset(contentLeft, footerTop));

    final double gapTop = topInset + header.height + 12;
    final double gapHeight = math.max(0, footerTop - 12 - gapTop);
    final double actorHeight = math.max(0, gapHeight - 52);
    const Rect subjects = ExpeditionCrewScene.subjectBounds;
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
      bottomInset != oldDelegate.bottomInset ||
      leftInset != oldDelegate.leftInset ||
      rightInset != oldDelegate.rightInset;
}

/// Uses the otherwise scarce horizontal space on short landscape displays.
/// Gameplay details and the HUD have separate scroll positions, so neither a
/// large text setting nor an optional sync action can collapse gameplay to a
/// zero-height viewport.
class _ShortLandscapeHomeStageLayout extends MultiChildLayoutDelegate {
  _ShortLandscapeHomeStageLayout({
    required this.topInset,
    required this.bottomInset,
    required this.leftInset,
    required this.rightInset,
  });

  final double topInset;
  final double bottomInset;
  final double leftInset;
  final double rightInset;

  @override
  void performLayout(Size size) {
    layoutChild(_Layer.background, BoxConstraints.tight(size));
    positionChild(_Layer.background, Offset.zero);
    layoutChild(_Layer.atmosphere, BoxConstraints.tight(size));
    positionChild(_Layer.atmosphere, Offset.zero);

    final double safeTop = topInset.clamp(0, size.height).toDouble();
    final double safeBottom = (size.height - bottomInset)
        .clamp(safeTop, size.height)
        .toDouble();
    final double contentHeight = math.max(0, safeBottom - safeTop);
    final double gutter = size.width < 700 ? 12 : 20;
    final double contentLeft = leftInset + gutter;
    final double contentRight = math.max(
      contentLeft,
      size.width - rightInset - gutter,
    );
    final double contentWidth = math.max(0, contentRight - contentLeft);
    final double separation = contentWidth >= 360 ? 12 : 8;
    final double controlsWidth = math.min(
      contentWidth,
      math.min(320, math.max(200, contentWidth * 0.42)),
    );
    final double detailsWidth = math.max(
      0,
      contentWidth - separation - controlsWidth,
    );

    layoutChild(
      _Layer.details,
      BoxConstraints.tight(Size(detailsWidth, contentHeight)),
    );
    positionChild(_Layer.details, Offset(contentLeft, safeTop));
    layoutChild(
      _Layer.controls,
      BoxConstraints.tight(Size(controlsWidth, contentHeight)),
    );
    positionChild(
      _Layer.controls,
      Offset(contentLeft + detailsWidth + separation, safeTop),
    );

    const Rect subjects = ExpeditionCrewScene.subjectBounds;
    final double actorHeight = math.max(0, size.height - 24);
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
        size.height / 2 - artHeight * subjects.center.dy,
      ),
    );
  }

  @override
  bool shouldRelayout(_ShortLandscapeHomeStageLayout oldDelegate) =>
      topInset != oldDelegate.topInset ||
      bottomInset != oldDelegate.bottomInset ||
      leftInset != oldDelegate.leftInset ||
      rightInset != oldDelegate.rightInset;
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
