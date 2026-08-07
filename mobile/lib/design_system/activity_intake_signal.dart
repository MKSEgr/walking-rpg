import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

/// Static field illustration for the step-reading trust boundary.
///
/// The signal deliberately owns no activity value, permission state or
/// synchronization result. Those remain in the surrounding authoritative
/// first-journey flow.
class ActivityIntakeSignal extends StatelessWidget {
  const ActivityIntakeSignal({super.key, this.height = 124})
    : assert(height > 0);

  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;

    return Semantics(
      container: true,
      image: true,
      label:
          'Сигнал подключения шагов: только количество шагов, '
          'без геолокации',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: CustomPaint(
              painter: _ActivityIntakeSignalPainter(
                lumen: colors.primary,
                energy: palette.energy,
                resonance: palette.resonance,
                surface: colors.surfaceContainerHigh,
                route: palette.routeLine,
                outline: colors.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityIntakeSignalPainter extends CustomPainter {
  const _ActivityIntakeSignalPainter({
    required this.lumen,
    required this.energy,
    required this.resonance,
    required this.surface,
    required this.route,
    required this.outline,
  });

  final Color lumen;
  final Color energy;
  final Color resonance;
  final Color surface;
  final Color route;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final Rect bounds = Offset.zero & size;
    final double unit = size.shortestSide;
    final RRect frame = RRect.fromRectAndRadius(
      bounds.deflate(math.max(2.0, unit * 0.018)),
      Radius.circular(math.min(24.0, unit * 0.19)),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(lumen.withValues(alpha: 0.09), surface),
            Color.alphaBlend(resonance.withValues(alpha: 0.1), surface),
          ],
        ).createShader(bounds),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = Color.lerp(outline, resonance, 0.24)!.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, unit * 0.016),
    );

    canvas
      ..save()
      ..clipRRect(frame);
    _paintQuietField(canvas, size, unit);

    final Path routePath = Path()
      ..moveTo(size.width * 0.09, size.height * 0.7)
      ..cubicTo(
        size.width * 0.27,
        size.height * 0.76,
        size.width * 0.34,
        size.height * 0.31,
        size.width * 0.53,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.59,
        size.width * 0.7,
        size.height * 0.43,
        size.width * 0.78,
        size.height * 0.43,
      );
    final PathMetric metric = routePath.computeMetrics().first;
    canvas.drawPath(
      routePath,
      Paint()
        ..color = Color.lerp(route, outline, 0.22)!.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(2.2, unit * 0.028),
    );

    for (int index = 0; index < 3; index += 1) {
      final double fraction = 0.17 + index * 0.22;
      final Tangent? tangent = metric.getTangentForOffset(
        metric.length * fraction,
      );
      if (tangent != null) {
        _paintStep(
          canvas,
          tangent,
          unit,
          left: index.isEven,
          color: index == 2 ? energy : lumen,
        );
      }
    }

    _paintPrivacyGate(
      canvas,
      Offset(size.width * 0.82, size.height * 0.43),
      unit,
    );
    canvas.restore();
  }

  void _paintQuietField(Canvas canvas, Size size, double unit) {
    final Paint contour = Paint()
      ..color = resonance.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.2, unit * 0.012);
    final Offset gate = Offset(size.width * 0.82, size.height * 0.43);
    canvas
      ..drawArc(
        Rect.fromCenter(center: gate, width: unit * 0.8, height: unit * 0.8),
        math.pi * 1.1,
        math.pi * 0.78,
        false,
        contour,
      )
      ..drawArc(
        Rect.fromCenter(center: gate, width: unit * 1.08, height: unit * 1.08),
        math.pi * 1.14,
        math.pi * 0.7,
        false,
        contour,
      );

    final Paint star = Paint()..color = lumen.withValues(alpha: 0.38);
    for (final Offset position in <Offset>[
      Offset(size.width * 0.17, size.height * 0.25),
      Offset(size.width * 0.46, size.height * 0.2),
      Offset(size.width * 0.63, size.height * 0.77),
    ]) {
      canvas.drawCircle(position, math.max(1.4, unit * 0.015), star);
    }
  }

  void _paintStep(
    Canvas canvas,
    Tangent tangent,
    double unit, {
    required bool left,
    required Color color,
  }) {
    final double angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
    canvas
      ..save()
      ..translate(tangent.position.dx, tangent.position.dy)
      ..rotate(angle)
      ..translate(0, left ? -unit * 0.055 : unit * 0.055);

    final RRect sole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: unit * 0.12,
        height: unit * 0.055,
      ),
      Radius.circular(unit * 0.028),
    );
    canvas.drawRRect(sole, Paint()..color = color.withValues(alpha: 0.88));
    canvas.drawCircle(
      Offset(unit * 0.075, 0),
      unit * 0.025,
      Paint()..color = color.withValues(alpha: 0.94),
    );
    canvas.restore();
  }

  void _paintPrivacyGate(Canvas canvas, Offset center, double unit) {
    final double radius = unit * 0.19;
    final Path shield = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius * 0.88,
        center.dy - radius * 0.68,
        center.dx + radius * 0.72,
        center.dy + radius * 0.28,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.5,
        center.dy + radius * 0.78,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.5,
        center.dy + radius * 0.78,
        center.dx - radius * 0.72,
        center.dy + radius * 0.28,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.88,
        center.dy - radius * 0.68,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(shield, Paint()..color = surface.withValues(alpha: 0.96));
    canvas.drawPath(
      shield,
      Paint()
        ..color = resonance.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, unit * 0.022),
    );

    final Paint gateLine = Paint()
      ..color = lumen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2.0, unit * 0.026);
    canvas
      ..drawLine(
        Offset(center.dx - radius * 0.3, center.dy),
        Offset(center.dx + radius * 0.3, center.dy),
        gateLine,
      )
      ..drawCircle(
        Offset(center.dx, center.dy),
        radius * 0.22,
        Paint()..color = energy,
      );
  }

  @override
  bool shouldRepaint(covariant _ActivityIntakeSignalPainter oldDelegate) {
    return oldDelegate.lumen != lumen ||
        oldDelegate.energy != energy ||
        oldDelegate.resonance != resonance ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route ||
        oldDelegate.outline != outline;
  }
}
