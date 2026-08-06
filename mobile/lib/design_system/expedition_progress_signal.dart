import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum ExpeditionProgressSignalKind { outerBeacon, unknown }

/// Presentation identities for server-authored expeditions.
///
/// Only an exact stable expedition ID selects a known route contour. Names,
/// node copy and content versions deliberately do not participate in dispatch,
/// so future expeditions keep a neutral signal field.
abstract final class ExpeditionProgressSignalCatalog {
  static ExpeditionProgressSignalKind kindFor(String expeditionId) {
    return switch (expeditionId) {
      'starter-expedition-v1' => ExpeditionProgressSignalKind.outerBeacon,
      _ => ExpeditionProgressSignalKind.unknown,
    };
  }
}

/// Decorative route trace for literal accepted expedition ENERGY progress.
///
/// The adjacent screen copy remains the accessible source for exact progress,
/// target and current-node values. Painted samples are not chapter nodes and
/// never decide route availability, the next action or completion.
class ExpeditionProgressSignal extends StatelessWidget {
  const ExpeditionProgressSignal({
    super.key,
    required this.expeditionId,
    required this.progress,
    required this.target,
    this.height = 88,
  }) : assert(height > 0);

  final String expeditionId;
  final int progress;
  final int target;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final ExpeditionProgressSignalKind kind =
        ExpeditionProgressSignalCatalog.kindFor(expeditionId);
    final bool known = kind == ExpeditionProgressSignalKind.outerBeacon;
    final double acceptedProgress = target <= 0
        ? 0
        : (progress / target).clamp(0.0, 1.0).toDouble();

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          key: Key('expedition-progress-signal-$expeditionId-${kind.name}'),
          width: double.infinity,
          height: height,
          child: CustomPaint(
            painter: _ExpeditionProgressSignalPainter(
              kind: kind,
              progress: acceptedProgress,
              identityAccent: known ? colors.primary : colors.onSurfaceVariant,
              progressAccent: known ? palette.energy : colors.onSurfaceVariant,
              resonance: known ? palette.resonance : colors.outlineVariant,
              surface: colors.surfaceContainerHigh,
              route: palette.routeLine,
              outline: colors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpeditionProgressSignalPainter extends CustomPainter {
  const _ExpeditionProgressSignalPainter({
    required this.kind,
    required this.progress,
    required this.identityAccent,
    required this.progressAccent,
    required this.resonance,
    required this.surface,
    required this.route,
    required this.outline,
  });

  final ExpeditionProgressSignalKind kind;
  final double progress;
  final Color identityAccent;
  final Color progressAccent;
  final Color resonance;
  final Color surface;
  final Color route;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double unit = math.min(size.width, size.height);
    final Rect bounds = Offset.zero & size;
    final RRect frame = RRect.fromRectAndRadius(
      bounds.deflate(unit * 0.025),
      Radius.circular(unit * 0.22),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = Color.alphaBlend(
          identityAccent.withValues(alpha: 0.08),
          surface.withValues(alpha: 0.97),
        ),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = identityAccent.withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.022,
    );

    if (kind == ExpeditionProgressSignalKind.outerBeacon) {
      _drawOuterBeaconField(canvas, size, unit);
    } else {
      _drawUnknownField(canvas, size, unit);
    }

    final Path trace = _traceFor(size);
    final PathMetric metric = trace.computeMetrics().first;
    canvas.drawPath(
      trace,
      Paint()
        ..color = Color.lerp(route, outline, 0.3)!.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = unit * 0.035,
    );
    if (progress > 0) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..color = progressAccent.withValues(alpha: 0.96)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = unit * 0.062,
      );
    }

    for (final double fraction in const <double>[0, 0.25, 0.5, 0.75, 1]) {
      final Tangent? tangent = metric.getTangentForOffset(
        metric.length * fraction,
      );
      if (tangent == null) {
        continue;
      }
      final bool accepted = progress > 0 && fraction <= progress + 0.001;
      canvas.drawCircle(
        tangent.position,
        unit * (fraction == 1 ? 0.064 : 0.046),
        Paint()
          ..color = accepted ? progressAccent : surface.withValues(alpha: 0.98)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        tangent.position,
        unit * (fraction == 1 ? 0.064 : 0.046),
        Paint()
          ..color = accepted
              ? progressAccent
              : identityAccent.withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.022,
      );
    }
  }

  Path _traceFor(Size size) {
    final Path trace = Path();
    if (kind == ExpeditionProgressSignalKind.outerBeacon) {
      return trace
        ..moveTo(size.width * 0.08, size.height * 0.72)
        ..cubicTo(
          size.width * 0.27,
          size.height * 0.7,
          size.width * 0.34,
          size.height * 0.35,
          size.width * 0.52,
          size.height * 0.47,
        )
        ..cubicTo(
          size.width * 0.66,
          size.height * 0.56,
          size.width * 0.74,
          size.height * 0.32,
          size.width * 0.88,
          size.height * 0.34,
        );
    }
    return trace
      ..moveTo(size.width * 0.08, size.height * 0.64)
      ..lineTo(size.width * 0.31, size.height * 0.42)
      ..lineTo(size.width * 0.52, size.height * 0.62)
      ..lineTo(size.width * 0.7, size.height * 0.38)
      ..lineTo(size.width * 0.88, size.height * 0.55);
  }

  void _drawOuterBeaconField(Canvas canvas, Size size, double unit) {
    final Paint contour = Paint()
      ..color = resonance.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = unit * 0.018;
    canvas
      ..drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.88, size.height * 0.34),
          width: unit * 0.62,
          height: unit * 0.62,
        ),
        math.pi * 1.08,
        math.pi * 0.84,
        false,
        contour,
      )
      ..drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.88, size.height * 0.34),
          width: unit * 0.9,
          height: unit * 0.9,
        ),
        math.pi * 1.12,
        math.pi * 0.76,
        false,
        contour,
      );

    final Offset beacon = Offset(size.width * 0.88, size.height * 0.34);
    final Path tower = Path()
      ..moveTo(beacon.dx, beacon.dy - unit * 0.16)
      ..lineTo(beacon.dx + unit * 0.1, beacon.dy + unit * 0.1)
      ..lineTo(beacon.dx, beacon.dy + unit * 0.055)
      ..lineTo(beacon.dx - unit * 0.1, beacon.dy + unit * 0.1)
      ..close();
    canvas.drawPath(tower, Paint()..color = identityAccent);
  }

  void _drawUnknownField(Canvas canvas, Size size, double unit) {
    final Paint line = Paint()
      ..color = identityAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = unit * 0.018;
    final List<Offset> stars = <Offset>[
      Offset(size.width * 0.18, size.height * 0.27),
      Offset(size.width * 0.47, size.height * 0.22),
      Offset(size.width * 0.78, size.height * 0.25),
    ];
    canvas
      ..drawLine(stars[0], stars[1], line)
      ..drawLine(stars[1], stars[2], line);
    for (final Offset star in stars) {
      canvas.drawCircle(star, unit * 0.026, Paint()..color = identityAccent);
    }
  }

  @override
  bool shouldRepaint(covariant _ExpeditionProgressSignalPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.progress != progress ||
        oldDelegate.identityAccent != identityAccent ||
        oldDelegate.progressAccent != progressAccent ||
        oldDelegate.resonance != resonance ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route ||
        oldDelegate.outline != outline;
  }
}
