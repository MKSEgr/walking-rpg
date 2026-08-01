import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

/// Static first-chapter key art.
///
/// The vista never invents route state. When [progress] is supplied, it must
/// come from an accepted server read model and is used only to light the
/// already-visible signal trail.
class ChapterVista extends StatelessWidget {
  const ChapterVista({
    super.key,
    required this.semanticLabel,
    this.progress,
    this.height = 190,
  }) : assert(height > 0);

  final String semanticLabel;
  final double? progress;
  final double height;

  double? get normalizedProgress {
    final double? value = progress;
    return value == null ? null : value.clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final double? safeProgress = normalizedProgress;
    final String progressLabel = safeProgress == null
        ? ''
        : ', маршрут ${(safeProgress * 100).round()}%';

    return Semantics(
      image: true,
      label: '$semanticLabel$progressLabel',
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: CustomPaint(
              isComplex: true,
              painter: _ChapterVistaPainter(
                progress: safeProgress,
                skyTop: palette.backdropTop,
                skyBottom: palette.backdropBottom,
                terrain: colors.surfaceContainerHigh,
                mist: colors.surface,
                route: colors.primary,
                dormantRoute: palette.routeLine,
                signal: palette.resonance,
                energy: palette.energy,
                foreground: colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterVistaPainter extends CustomPainter {
  const _ChapterVistaPainter({
    required this.progress,
    required this.skyTop,
    required this.skyBottom,
    required this.terrain,
    required this.mist,
    required this.route,
    required this.dormantRoute,
    required this.signal,
    required this.energy,
    required this.foreground,
  });

  final double? progress;
  final Color skyTop;
  final Color skyBottom;
  final Color terrain;
  final Color mist;
  final Color route;
  final Color dormantRoute;
  final Color signal;
  final Color energy;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final Rect bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            skyTop,
            Color.lerp(skyTop, skyBottom, 0.62)!,
            skyBottom,
          ],
          stops: const <double>[0, 0.54, 1],
        ).createShader(bounds),
    );

    final Offset beacon = Offset(size.width * 0.76, size.height * 0.3);
    canvas.drawCircle(
      beacon,
      size.shortestSide * 0.54,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                signal.withValues(alpha: 0.24),
                signal.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: beacon, radius: size.shortestSide * 0.54),
            ),
    );

    _paintStars(canvas, size);
    _paintHorizon(canvas, size);

    final Path routePath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.85)
      ..cubicTo(
        size.width * 0.23,
        size.height * 0.71,
        size.width * 0.33,
        size.height * 0.86,
        size.width * 0.48,
        size.height * 0.7,
      )
      ..cubicTo(
        size.width * 0.6,
        size.height * 0.58,
        size.width * 0.65,
        size.height * 0.69,
        size.width * 0.75,
        size.height * 0.58,
      );
    final Paint dormantRoutePaint = Paint()
      ..color = dormantRoute.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, dormantRoutePaint);

    final double? routeProgress = progress;
    if (routeProgress != null && routeProgress > 0) {
      canvas
        ..save()
        ..clipRect(
          Rect.fromLTRB(
            0,
            0,
            size.width * (0.05 + 0.7 * routeProgress),
            size.height,
          ),
        )
        ..drawPath(
          routePath,
          Paint()
            ..color = route.withValues(alpha: 0.92)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.3
            ..strokeCap = StrokeCap.round,
        )
        ..restore();
    }

    _paintRouteNodes(canvas, size, routeProgress);
    _paintBeacon(canvas, size, beacon);
    _paintForeground(canvas, size);
  }

  void _paintStars(Canvas canvas, Size size) {
    final Paint star = Paint()..color = foreground.withValues(alpha: 0.48);
    const List<Offset> normalizedStars = <Offset>[
      Offset(0.09, 0.2),
      Offset(0.18, 0.35),
      Offset(0.3, 0.14),
      Offset(0.43, 0.29),
      Offset(0.54, 0.12),
      Offset(0.9, 0.21),
    ];
    for (int index = 0; index < normalizedStars.length; index += 1) {
      final Offset point = normalizedStars[index];
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        index.isEven ? 1.4 : 1,
        star,
      );
    }
  }

  void _paintHorizon(Canvas canvas, Size size) {
    final Path distantRidge = Path()
      ..moveTo(0, size.height * 0.64)
      ..quadraticBezierTo(
        size.width * 0.16,
        size.height * 0.48,
        size.width * 0.34,
        size.height * 0.61,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.72,
        size.width * 0.68,
        size.height * 0.51,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.37,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      distantRidge,
      Paint()..color = terrain.withValues(alpha: 0.44),
    );

    final Path fog = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.66)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.55,
        size.width * 0.42,
        size.height * 0.74,
        size.width * 0.68,
        size.height * 0.6,
      )
      ..cubicTo(
        size.width * 0.83,
        size.height * 0.52,
        size.width * 0.92,
        size.height * 0.64,
        size.width * 1.08,
        size.height * 0.58,
      );
    canvas.drawPath(
      fog,
      Paint()
        ..color = mist.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(18.0, size.height * 0.13)
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintRouteNodes(Canvas canvas, Size size, double? routeProgress) {
    const List<Offset> points = <Offset>[
      Offset(0.08, 0.82),
      Offset(0.25, 0.76),
      Offset(0.43, 0.75),
      Offset(0.59, 0.65),
      Offset(0.74, 0.59),
    ];
    for (int index = 0; index < points.length; index += 1) {
      final Offset normalized = points[index];
      final Offset point = Offset(
        normalized.dx * size.width,
        normalized.dy * size.height,
      );
      final double nodeThreshold = index / (points.length - 1);
      final bool active =
          routeProgress != null && routeProgress + 0.001 >= nodeThreshold;
      final Color nodeColor = active ? route : dormantRoute;
      canvas
        ..drawCircle(
          point,
          active ? 9 : 7,
          Paint()..color = nodeColor.withValues(alpha: active ? 0.12 : 0.08),
        )
        ..drawCircle(
          point,
          active ? 3.6 : 2.8,
          Paint()..color = nodeColor.withValues(alpha: active ? 0.96 : 0.5),
        );
    }
  }

  void _paintBeacon(Canvas canvas, Size size, Offset signalCenter) {
    final double towerBottom = size.height * 0.78;
    final double towerTop = size.height * 0.31;
    final double towerHalfWidth = math.max(7.0, size.width * 0.025);
    final Path tower = Path()
      ..moveTo(signalCenter.dx - towerHalfWidth * 1.7, towerBottom)
      ..lineTo(signalCenter.dx - towerHalfWidth * 0.38, towerTop)
      ..lineTo(signalCenter.dx + towerHalfWidth * 0.38, towerTop)
      ..lineTo(signalCenter.dx + towerHalfWidth * 1.7, towerBottom)
      ..close();
    canvas.drawPath(tower, Paint()..color = foreground.withValues(alpha: 0.82));

    final Paint signalStroke = Paint()
      ..color = signal.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final double radius in <double>[13, 23, 34]) {
      canvas.drawArc(
        Rect.fromCircle(center: signalCenter, radius: radius),
        math.pi * 1.12,
        math.pi * 0.76,
        false,
        signalStroke,
      );
    }
    canvas
      ..drawCircle(
        signalCenter,
        10,
        Paint()..color = signal.withValues(alpha: 0.17),
      )
      ..drawCircle(signalCenter, 4.2, Paint()..color = energy);
  }

  void _paintForeground(Canvas canvas, Size size) {
    final Path foregroundRidge = Path()
      ..moveTo(0, size.height * 0.91)
      ..quadraticBezierTo(
        size.width * 0.17,
        size.height * 0.84,
        size.width * 0.32,
        size.height * 0.94,
      )
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height,
        size.width * 0.69,
        size.height * 0.9,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.82,
        size.width,
        size.height * 0.88,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      foregroundRidge,
      Paint()..color = skyBottom.withValues(alpha: 0.88),
    );
  }

  @override
  bool shouldRepaint(covariant _ChapterVistaPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.skyTop != skyTop ||
        oldDelegate.skyBottom != skyBottom ||
        oldDelegate.terrain != terrain ||
        oldDelegate.mist != mist ||
        oldDelegate.route != route ||
        oldDelegate.dormantRoute != dormantRoute ||
        oldDelegate.signal != signal ||
        oldDelegate.energy != energy ||
        oldDelegate.foreground != foreground;
  }
}
