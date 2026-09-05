import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_destination_visibility.dart';
import 'package:walking_rpg_mobile/design_system/companion_motion.dart';
import 'package:walking_rpg_mobile/design_system/pilot_motion.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

/// A shared foreground for the current crew, with finite, decorative reactions.
/// The caller supplies the accepted identity; animation never advances a route.
class ExpeditionCrewScene extends StatefulWidget {
  const ExpeditionCrewScene({
    super.key,
    required this.background,
    required this.pilotName,
    required this.greetingLabel,
    required this.scrollController,
    required this.height,
    this.petId,
    this.petName,
    this.petSpecies,
    this.petEvolutionStage,
  });

  final Widget background;
  final String pilotName;
  final String greetingLabel;
  final ScrollController scrollController;
  final double height;
  final String? petId;
  final String? petName;
  final String? petSpecies;
  final int? petEvolutionStage;

  @override
  State<ExpeditionCrewScene> createState() => _ExpeditionCrewSceneState();
}

class _ExpeditionCrewSceneState extends State<ExpeditionCrewScene>
    with WidgetsBindingObserver {
  bool _inViewport = true;
  bool _visibilityCheckScheduled = false;
  bool _resumed = true;
  int _greeting = 0;

  @override
  void initState() {
    super.initState();
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.scrollController.addListener(_scheduleVisibilityCheck);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(ExpeditionCrewScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_scheduleVisibilityCheck);
      widget.scrollController.addListener(_scheduleVisibilityCheck);
    }
    if (oldWidget.petId != widget.petId) {
      _greeting = 0;
    }
    _scheduleVisibilityCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _resumed = state == AppLifecycleState.resumed);
  }

  @override
  void didChangeMetrics() => _scheduleVisibilityCheck();

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (!mounted) return;
      final RenderObject? object = context.findRenderObject();
      final RenderObject? viewport = Scrollable.maybeOf(
        context,
      )?.context.findRenderObject();
      if (object is! RenderBox || !object.hasSize) return;
      final Rect bounds = object.localToGlobal(Offset.zero) & object.size;
      final Rect visibleBounds = viewport is RenderBox && viewport.hasSize
          ? viewport.localToGlobal(Offset.zero) & viewport.size
          : Offset.zero & MediaQuery.sizeOf(context);
      final bool visible = bounds.overlaps(visibleBounds);
      if (visible != _inViewport) {
        setState(() => _inViewport = visible);
      }
    });
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scheduleVisibilityCheck);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool play =
        _resumed &&
        _inViewport &&
        NavigationDestinationVisibility.of(context) &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context);
    final bool hasPet =
        widget.petId != null &&
        widget.petName != null &&
        widget.petSpecies != null &&
        widget.petEvolutionStage != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            final double pilotSize = (width * 0.82).clamp(210, 300).toDouble();
            final double petSize = (width * 0.44).clamp(116, 168).toDouble();
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                widget.background,
                IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CrewGroundPainter(
                        palette: context.walkingRpgPalette,
                        hasPet: hasPet,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: hasPet ? width * 0.025 : (width - pilotSize) / 2,
                  bottom: 26,
                  child: KeyedSubtree(
                    key: ValueKey<String>('pilot-reaction-$_greeting'),
                    child: PilotMotionPortrait(
                      key: const Key('home-pilot-motion-portrait'),
                      pilotId: PilotMotionPortrait.navigatorPilotId,
                      name: widget.pilotName,
                      size: pilotSize,
                      framed: false,
                      play: play,
                      clip: _greeting == 0 || !play
                          ? PilotMotionClip.idle
                          : PilotMotionClip.greet,
                    ),
                  ),
                ),
                if (hasPet)
                  Positioned(
                    left: width * 0.53,
                    bottom: 25,
                    child: KeyedSubtree(
                      key: ValueKey<String>('pet-reaction-$_greeting'),
                      child: CompanionMotionPortrait(
                        key: const Key('home-active-companion-portrait'),
                        petId: widget.petId!,
                        name: widget.petName!,
                        species: widget.petSpecies!,
                        evolutionStage: widget.petEvolutionStage!,
                        active: true,
                        size: petSize,
                        framed: false,
                        play: play,
                        clip: _greeting == 0 || !play
                            ? CompanionMotionClip.idle
                            : CompanionMotionClip.greet,
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton.filledTonal(
                    key: const Key('home-greet-crew'),
                    tooltip: widget.greetingLabel,
                    onPressed: play ? () => setState(() => _greeting++) : null,
                    icon: const Icon(Icons.waving_hand_outlined, size: 21),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 18,
                  child: ExcludeSemantics(
                    child: Text(
                      context.l10n.homeCrewTitle.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 2,
                        color: WalkingRpgColors.moonMist.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CrewGroundPainter extends CustomPainter {
  const _CrewGroundPainter({required this.palette, required this.hasPet});

  final WalkingRpgPalette palette;
  final bool hasPet;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect ground = Rect.fromLTWH(
      -size.width * 0.3,
      size.height * 0.77,
      size.width * 1.6,
      size.height * 0.55,
    );
    canvas.drawOval(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF416B70),
            WalkingRpgColors.deepWater,
            WalkingRpgColors.ink,
          ],
        ).createShader(ground),
    );
    canvas.drawArc(
      ground.deflate(3),
      3.5,
      2.4,
      false,
      Paint()
        ..color = palette.panelHighlight.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    for (final double x in <double>[hasPet ? 0.43 : 0.5, if (hasPet) 0.75]) {
      final Rect shadow = Rect.fromCenter(
        center: Offset(size.width * x, size.height - 34),
        width: size.width * 0.27,
        height: 17,
      );
      canvas.drawOval(
        shadow,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              WalkingRpgColors.ink.withValues(alpha: 0.75),
              WalkingRpgColors.ink.withValues(alpha: 0),
            ],
          ).createShader(shadow),
      );
    }
  }

  @override
  bool shouldRepaint(_CrewGroundPainter oldDelegate) =>
      oldDelegate.palette != palette || oldDelegate.hasPet != hasPet;
}
