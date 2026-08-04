import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum WeeklyRouteSignalKind { firstSignal, unknown }

/// Presentation identities for server-authored weekly routes.
///
/// Only an exact stable route ID selects a known signal. Season names and
/// display copy are deliberately ignored so future routes cannot inherit an
/// unrelated visual identity.
abstract final class WeeklyRouteSignalCatalog {
  static WeeklyRouteSignalKind kindFor(String routeId) {
    return switch (routeId) {
      'weekly-route-1' => WeeklyRouteSignalKind.firstSignal,
      _ => WeeklyRouteSignalKind.unknown,
    };
  }
}

/// Code-native beacon for accepted weekly-route ENERGY progress.
///
/// The waypoints are decorative samples along one progress trace, not chapter
/// nodes or server-owned milestones. Exact progress remains visible as text
/// and as one complete semantic value.
class WeeklyRouteSignal extends StatelessWidget {
  const WeeklyRouteSignal({
    super.key,
    required this.routeId,
    required this.seasonName,
    required this.progress,
    required this.target,
    this.size = 120,
  });

  final String routeId;
  final String seasonName;
  final int progress;
  final int target;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final WeeklyRouteSignalKind kind = WeeklyRouteSignalCatalog.kindFor(
      routeId,
    );
    final double normalized = target <= 0
        ? 0
        : (progress / target).clamp(0.0, 1.0).toDouble();
    final Color identityAccent = kind == WeeklyRouteSignalKind.firstSignal
        ? palette.resonance
        : colors.onSurfaceVariant;
    final Color progressAccent = kind == WeeklyRouteSignalKind.firstSignal
        ? palette.energy
        : colors.onSurfaceVariant;

    return Semantics(
      key: Key('weekly-route-signal-$routeId-${kind.name}'),
      container: true,
      label:
          'Недельный маршрут «$seasonName»: '
          '$progress из $target ENERGY',
      value: '${(normalized * 100).round()}%',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RepaintBoundary(
              child: SizedBox.square(
                key: Key('weekly-route-beacon-$routeId-${kind.name}'),
                dimension: size,
                child: CustomPaint(
                  painter: _WeeklyRouteSignalPainter(
                    kind: kind,
                    progress: normalized,
                    identityAccent: identityAccent,
                    progressAccent: progressAccent,
                    lumen: colors.primary,
                    surface: colors.surfaceContainerHigh,
                    route: palette.routeLine,
                    outline: colors.outlineVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$progress / $target ENERGY',
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: progressAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyRouteSignalPainter extends CustomPainter {
  const _WeeklyRouteSignalPainter({
    required this.kind,
    required this.progress,
    required this.identityAccent,
    required this.progressAccent,
    required this.lumen,
    required this.surface,
    required this.route,
    required this.outline,
  });

  final WeeklyRouteSignalKind kind;
  final double progress;
  final Color identityAccent;
  final Color progressAccent;
  final Color lumen;
  final Color surface;
  final Color route;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double unit = size.shortestSide;
    final Offset center = size.center(Offset.zero);
    final RRect frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(unit * 0.025),
      Radius.circular(unit * 0.24),
    );
    final Paint frameFill = Paint()
      ..color = Color.alphaBlend(
        identityAccent.withValues(alpha: 0.1),
        surface.withValues(alpha: 0.96),
      );
    final Paint frameLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.022
      ..color = identityAccent.withValues(alpha: 0.52);
    canvas.drawRRect(frame, frameFill);
    canvas.drawRRect(frame, frameLine);

    _paintField(canvas, size, center, unit);

    final Path trace = _traceFor(size);
    final PathMetric metric = trace.computeMetrics().first;
    final Paint baseTrace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.026
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Color.lerp(route, outline, 0.35)!.withValues(alpha: 0.62);
    final Paint acceptedTrace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.046
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = progressAccent.withValues(alpha: 0.94);
    canvas.drawPath(trace, baseTrace);
    if (progress > 0) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        acceptedTrace,
      );
    }

    const List<double> samples = <double>[0, 0.25, 0.5, 0.75, 1];
    for (final double fraction in samples) {
      final Tangent? tangent = metric.getTangentForOffset(
        metric.length * fraction,
      );
      if (tangent == null) {
        continue;
      }
      _paintWaypoint(
        canvas,
        tangent.position,
        unit,
        accepted: progress > 0 && fraction <= progress + 0.001,
        endpoint: fraction == 1,
      );
    }

    final Tangent? start = metric.getTangentForOffset(0);
    final Tangent? finish = metric.getTangentForOffset(metric.length);
    if (start != null) {
      _paintOrigin(canvas, start.position, unit);
    }
    if (finish != null) {
      _paintBeacon(canvas, finish.position, unit, complete: progress >= 1);
    }
  }

  void _paintField(Canvas canvas, Size size, Offset center, double unit) {
    final Paint field = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.014
      ..strokeCap = StrokeCap.round
      ..color = identityAccent.withValues(alpha: 0.26);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.37),
      math.pi * 0.08,
      math.pi * 0.48,
      false,
      field,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.37),
      math.pi * 1.05,
      math.pi * 0.38,
      false,
      field,
    );

    if (kind == WeeklyRouteSignalKind.firstSignal) {
      final Offset source = Offset(size.width * 0.78, size.height * 0.23);
      for (final double radius in <double>[0.07, 0.13]) {
        canvas.drawArc(
          Rect.fromCircle(center: source, radius: unit * radius),
          -math.pi * 0.48,
          math.pi * 0.82,
          false,
          field,
        );
      }
      return;
    }

    for (final Offset point in <Offset>[
      Offset(size.width * 0.22, size.height * 0.25),
      Offset(size.width * 0.72, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.68),
    ]) {
      canvas.drawCircle(point, unit * 0.018, field);
    }
  }

  Path _traceFor(Size size) {
    return switch (kind) {
      WeeklyRouteSignalKind.firstSignal =>
        Path()
          ..moveTo(size.width * 0.16, size.height * 0.77)
          ..cubicTo(
            size.width * 0.31,
            size.height * 0.69,
            size.width * 0.24,
            size.height * 0.42,
            size.width * 0.45,
            size.height * 0.45,
          )
          ..cubicTo(
            size.width * 0.65,
            size.height * 0.48,
            size.width * 0.61,
            size.height * 0.2,
            size.width * 0.81,
            size.height * 0.25,
          )
          ..cubicTo(
            size.width * 0.92,
            size.height * 0.31,
            size.width * 0.77,
            size.height * 0.58,
            size.width * 0.84,
            size.height * 0.78,
          ),
      WeeklyRouteSignalKind.unknown =>
        Path()
          ..moveTo(size.width * 0.18, size.height * 0.73)
          ..quadraticBezierTo(
            size.width * 0.33,
            size.height * 0.29,
            size.width * 0.51,
            size.height * 0.52,
          )
          ..quadraticBezierTo(
            size.width * 0.69,
            size.height * 0.75,
            size.width * 0.82,
            size.height * 0.3,
          ),
    };
  }

  void _paintWaypoint(
    Canvas canvas,
    Offset center,
    double unit, {
    required bool accepted,
    required bool endpoint,
  }) {
    final double radius = unit * (endpoint ? 0.047 : 0.036);
    final Color nodeColor = accepted ? progressAccent : outline;
    final Paint fill = Paint()
      ..color = Color.alphaBlend(
        nodeColor.withValues(alpha: accepted ? 0.34 : 0.08),
        surface,
      );
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.018
      ..color = nodeColor.withValues(alpha: accepted ? 0.95 : 0.52);
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, line);
  }

  void _paintOrigin(Canvas canvas, Offset center, double unit) {
    final Path diamond = Path()
      ..moveTo(center.dx, center.dy - unit * 0.055)
      ..lineTo(center.dx + unit * 0.055, center.dy)
      ..lineTo(center.dx, center.dy + unit * 0.055)
      ..lineTo(center.dx - unit * 0.055, center.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = lumen.withValues(alpha: 0.94));
  }

  void _paintBeacon(
    Canvas canvas,
    Offset center,
    double unit, {
    required bool complete,
  }) {
    final Color beaconColor = complete ? lumen : identityAccent;
    final Paint signal = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.016
      ..strokeCap = StrokeCap.round
      ..color = beaconColor.withValues(alpha: complete ? 0.9 : 0.58);
    for (final double radius in <double>[0.075, 0.115]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: unit * radius),
        -math.pi * 0.83,
        math.pi * 0.66,
        false,
        signal,
      );
    }
    if (complete) {
      canvas.drawCircle(
        center,
        unit * 0.025,
        Paint()..color = lumen.withValues(alpha: 0.98),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyRouteSignalPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.progress != progress ||
        oldDelegate.identityAccent != identityAccent ||
        oldDelegate.progressAccent != progressAccent ||
        oldDelegate.lumen != lumen ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route ||
        oldDelegate.outline != outline;
  }
}
