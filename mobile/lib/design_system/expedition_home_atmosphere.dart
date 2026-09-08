import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_destination_visibility.dart';

const Duration _homeAtmosphereRevealDuration = Duration(milliseconds: 1600);

/// A finite, presentation-only reveal above the Home scene.
///
/// The painter settles after 1.6 seconds and never owns a perpetual ticker.
/// Reduced-motion users receive the final still frame immediately.
class ExpeditionHomeAtmosphere extends StatefulWidget {
  const ExpeditionHomeAtmosphere({super.key});

  @override
  State<ExpeditionHomeAtmosphere> createState() =>
      _ExpeditionHomeAtmosphereState();
}

class _ExpeditionHomeAtmosphereState extends State<ExpeditionHomeAtmosphere>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late AppLifecycleState _lifecycleState;
  bool _reduceMotion = false;
  bool _tickerEnabled = true;
  bool _destinationVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _homeAtmosphereRevealDuration,
    );
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.of(context);
    _destinationVisible = NavigationDestinationVisibility.of(context);
    _synchronizeAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _synchronizeAnimation();
  }

  void _synchronizeAnimation() {
    if (_reduceMotion) {
      _controller.stop(canceled: false);
      _controller.value = 1;
      return;
    }
    if (!_tickerEnabled ||
        !_destinationVisible ||
        _lifecycleState != AppLifecycleState.resumed) {
      _controller.stop(canceled: false);
      return;
    }
    if (_controller.value < 1 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    key: const Key('home-expedition-atmosphere'),
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) => CustomPaint(
            key: const Key('home-expedition-atmosphere-paint'),
            painter: ExpeditionHomeAtmospherePainter(
              progress: Curves.easeOutCubic.transform(_controller.value),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

@immutable
class ExpeditionHomeAtmospherePainter extends CustomPainter {
  const ExpeditionHomeAtmospherePainter({required this.progress})
    : assert(progress >= 0 && progress <= 1);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || size.isEmpty) return;
    final Rect bounds = Offset.zero & size;
    final double revealOffset = (1 - progress) * size.height * 0.025;

    final Paint vignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.12),
        radius: 0.94,
        colors: <Color>[
          Colors.transparent,
          const Color(0xFF020A0F).withValues(alpha: 0.20 * progress),
        ],
        stops: const <double>[0.48, 1],
      ).createShader(bounds);
    canvas.drawRect(bounds, vignette);

    _drawMistHaze(
      canvas,
      size,
      center: const Offset(0.24, 0.76),
      width: 0.72,
      height: 0.17,
      offset: revealOffset,
      opacity: 0.075 * progress,
    );
    _drawMistHaze(
      canvas,
      size,
      center: const Offset(0.73, 0.84),
      width: 0.88,
      height: 0.22,
      offset: revealOffset * 0.55,
      opacity: 0.105 * progress,
    );

    const List<Offset> motes = <Offset>[
      Offset(0.10, 0.38),
      Offset(0.18, 0.57),
      Offset(0.80, 0.31),
      Offset(0.89, 0.48),
      Offset(0.07, 0.70),
      Offset(0.93, 0.66),
    ];
    final Paint motePaint = Paint()..style = PaintingStyle.fill;
    for (int index = 0; index < motes.length; index += 1) {
      final Offset mote = motes[index];
      final double drift = revealOffset * (0.16 + index * 0.035);
      final double radius = 0.8 + (index % 3) * 0.45;
      motePaint.color = const Color(
        0xFF72E7E2,
      ).withValues(alpha: (0.18 + (index % 2) * 0.07) * progress);
      canvas.drawCircle(
        Offset(mote.dx * size.width, mote.dy * size.height + drift),
        radius,
        motePaint,
      );
    }
  }

  void _drawMistHaze(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double width,
    required double height,
    required double offset,
    required double opacity,
  }) {
    final Rect hazeBounds = Rect.fromCenter(
      center: Offset(center.dx * size.width, center.dy * size.height + offset),
      width: size.width * width,
      height: size.height * height,
    );
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFFD9FAF6).withValues(alpha: opacity),
          const Color(0xFF78C8CA).withValues(alpha: opacity * 0.34),
          Colors.transparent,
        ],
        stops: const <double>[0, 0.58, 1],
      ).createShader(hazeBounds);
    canvas.drawOval(hazeBounds, paint);
  }

  @override
  bool shouldRepaint(ExpeditionHomeAtmospherePainter oldDelegate) =>
      progress != oldDelegate.progress;
}
