import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum QuestRouteSignalKind { steps, events, squad, unknown }

enum QuestRouteSignalTone { lumen, energy, resonance, neutral }

/// Presentation vocabulary for server-authored quest metrics.
///
/// Exact metric values select a known mark. Names and quest IDs are deliberately
/// ignored so future content cannot borrow an unrelated objective symbol.
abstract final class QuestRouteSignalCatalog {
  static QuestRouteSignalKind kindFor(String metric) {
    return switch (metric) {
      'TOTAL_ACCEPTED_STEPS' => QuestRouteSignalKind.steps,
      'RESOLVED_EVENTS' => QuestRouteSignalKind.events,
      'SQUAD_MEMBERSHIP' => QuestRouteSignalKind.squad,
      _ => QuestRouteSignalKind.unknown,
    };
  }

  static QuestRouteSignalTone toneFor(String metric) {
    return switch (metric) {
      'TOTAL_ACCEPTED_STEPS' => QuestRouteSignalTone.lumen,
      'RESOLVED_EVENTS' => QuestRouteSignalTone.resonance,
      'SQUAD_MEMBERSHIP' => QuestRouteSignalTone.energy,
      _ => QuestRouteSignalTone.neutral,
    };
  }
}

/// Decorative metric mark for a server-authored quest.
class QuestRouteSignal extends StatelessWidget {
  const QuestRouteSignal({
    super.key,
    required this.questId,
    required this.metric,
    required this.ready,
    required this.claimed,
    this.size = 72,
  });

  final String questId;
  final String metric;
  final bool ready;
  final bool claimed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final QuestRouteSignalTone tone = QuestRouteSignalCatalog.toneFor(metric);
    final Color metricAccent = switch (tone) {
      QuestRouteSignalTone.lumen => colors.primary,
      QuestRouteSignalTone.energy => palette.energy,
      QuestRouteSignalTone.resonance => palette.resonance,
      QuestRouteSignalTone.neutral => colors.onSurfaceVariant,
    };
    final Color stateAccent = claimed
        ? colors.primary
        : ready
        ? palette.energy
        : metricAccent;

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          key: Key(
            'quest-route-signal-$questId-'
            '${QuestRouteSignalCatalog.kindFor(metric).name}',
          ),
          dimension: size,
          child: CustomPaint(
            painter: _QuestRouteSignalPainter(
              kind: QuestRouteSignalCatalog.kindFor(metric),
              accent: metricAccent,
              stateAccent: stateAccent,
              surface: colors.surfaceContainerHigh,
              route: palette.routeLine,
              ready: ready,
              claimed: claimed,
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact route trace that keeps the exact numeric progress in semantics.
class QuestRouteProgress extends StatelessWidget {
  const QuestRouteProgress({
    super.key,
    required this.questId,
    required this.questName,
    required this.metric,
    required this.progress,
    required this.target,
    required this.ready,
    required this.claimed,
  });

  final String questId;
  final String questName;
  final String metric;
  final int progress;
  final int target;
  final bool ready;
  final bool claimed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final QuestRouteSignalTone tone = QuestRouteSignalCatalog.toneFor(metric);
    final Color metricAccent = switch (tone) {
      QuestRouteSignalTone.lumen => colors.primary,
      QuestRouteSignalTone.energy => palette.energy,
      QuestRouteSignalTone.resonance => palette.resonance,
      QuestRouteSignalTone.neutral => colors.onSurfaceVariant,
    };
    final Color activeAccent = claimed
        ? colors.primary
        : ready
        ? palette.energy
        : metricAccent;
    final double normalized = target <= 0
        ? 0
        : (progress / target).clamp(0.0, 1.0).toDouble();

    return Semantics(
      key: Key('quest-route-progress-$questId'),
      container: true,
      label: context.l10n.platformQuestProgressSemantics(
        questName,
        progress,
        target,
      ),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$progress / $target',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: activeAccent),
            ),
            const SizedBox(height: 5),
            SizedBox(
              key: Key('quest-route-trail-$questId'),
              height: 34,
              width: double.infinity,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _QuestRouteProgressPainter(
                    progress: normalized,
                    accent: activeAccent,
                    surface: colors.surfaceContainerHighest,
                    route: palette.routeLine,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestRouteSignalPainter extends CustomPainter {
  const _QuestRouteSignalPainter({
    required this.kind,
    required this.accent,
    required this.stateAccent,
    required this.surface,
    required this.route,
    required this.ready,
    required this.claimed,
  });

  final QuestRouteSignalKind kind;
  final Color accent;
  final Color stateAccent;
  final Color surface;
  final Color route;
  final bool ready;
  final bool claimed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final double unit = size.shortestSide;
    final Offset center = size.center(Offset.zero);
    final RRect frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(unit * 0.025),
      Radius.circular(unit * 0.27),
    );
    final Paint frameFill = Paint()
      ..color = Color.alphaBlend(
        accent.withValues(alpha: 0.12),
        surface.withValues(alpha: 0.96),
      );
    final Paint frameLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.025
      ..color = stateAccent.withValues(alpha: ready || claimed ? 0.75 : 0.48);
    canvas.drawRRect(frame, frameFill);
    canvas.drawRRect(frame, frameLine);

    final Paint orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.025
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(route, accent, 0.45)!.withValues(alpha: 0.48);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.34),
      math.pi * 0.08,
      math.pi * 0.58,
      false,
      orbit,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.34),
      math.pi * 1.12,
      math.pi * 0.42,
      false,
      orbit,
    );

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.052
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: 0.94);
    final Paint fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.03
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: 0.78);
    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: 0.94);

    switch (kind) {
      case QuestRouteSignalKind.steps:
        _paintSteps(canvas, size, stroke, fill);
      case QuestRouteSignalKind.events:
        _paintEvents(canvas, size, stroke, fine, fill);
      case QuestRouteSignalKind.squad:
        _paintSquad(canvas, size, fine, fill);
      case QuestRouteSignalKind.unknown:
        _paintUnknown(canvas, size, fine, fill);
    }

    if (ready || claimed) {
      final Offset statusCenter = Offset(size.width * 0.76, size.height * 0.24);
      final Paint statusFill = Paint()..color = stateAccent;
      canvas.drawCircle(statusCenter, unit * 0.085, statusFill);
      if (claimed) {
        final Paint check = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.028
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = surface;
        final Path path = Path()
          ..moveTo(statusCenter.dx - unit * 0.035, statusCenter.dy)
          ..lineTo(
            statusCenter.dx - unit * 0.008,
            statusCenter.dy + unit * 0.027,
          )
          ..lineTo(
            statusCenter.dx + unit * 0.045,
            statusCenter.dy - unit * 0.032,
          );
        canvas.drawPath(path, check);
      }
    }
  }

  Offset _point(Size size, double x, double y) {
    return Offset(size.width * x, size.height * y);
  }

  void _paintSteps(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final Path routePath = Path()
      ..moveTo(size.width * 0.24, size.height * 0.72)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.62,
        size.width * 0.58,
        size.height * 0.44,
        size.width * 0.72,
        size.height * 0.3,
      );
    canvas.drawPath(routePath, stroke);
    _drawFootprint(canvas, _point(size, 0.39, 0.59), size, -0.62, fill);
    _drawFootprint(canvas, _point(size, 0.59, 0.43), size, -0.62, fill);
  }

  void _drawFootprint(
    Canvas canvas,
    Offset center,
    Size size,
    double angle,
    Paint fill,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.shortestSide * 0.1,
        height: size.shortestSide * 0.17,
      ),
      fill,
    );
    canvas.restore();
  }

  void _paintEvents(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset source = _point(size, 0.33, 0.68);
    final Offset signal = _point(size, 0.69, 0.31);
    canvas.drawLine(source, signal, stroke);
    canvas.drawCircle(source, size.shortestSide * 0.055, fill);
    canvas.drawCircle(signal, size.shortestSide * 0.055, fill);
    for (final double radius in <double>[0.14, 0.24]) {
      canvas.drawArc(
        Rect.fromCircle(center: signal, radius: size.shortestSide * radius),
        math.pi * 0.66,
        math.pi * 0.52,
        false,
        fine,
      );
    }
  }

  void _paintSquad(Canvas canvas, Size size, Paint fine, Paint fill) {
    final List<Offset> crew = <Offset>[
      _point(size, 0.5, 0.3),
      _point(size, 0.29, 0.65),
      _point(size, 0.71, 0.65),
    ];
    canvas.drawLine(crew[0], crew[1], fine);
    canvas.drawLine(crew[1], crew[2], fine);
    canvas.drawLine(crew[2], crew[0], fine);
    for (final Offset member in crew) {
      canvas.drawCircle(member, size.shortestSide * 0.075, fill);
    }
  }

  void _paintUnknown(Canvas canvas, Size size, Paint fine, Paint fill) {
    final List<Offset> stars = <Offset>[
      _point(size, 0.28, 0.64),
      _point(size, 0.43, 0.34),
      _point(size, 0.62, 0.55),
      _point(size, 0.73, 0.28),
    ];
    for (int index = 0; index < stars.length - 1; index += 1) {
      canvas.drawLine(stars[index], stars[index + 1], fine);
    }
    for (final Offset star in stars) {
      canvas.drawCircle(star, size.shortestSide * 0.045, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _QuestRouteSignalPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.accent != accent ||
        oldDelegate.stateAccent != stateAccent ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route ||
        oldDelegate.ready != ready ||
        oldDelegate.claimed != claimed;
  }
}

class _QuestRouteProgressPainter extends CustomPainter {
  const _QuestRouteProgressPainter({
    required this.progress,
    required this.accent,
    required this.surface,
    required this.route,
  });

  final double progress;
  final Color accent;
  final Color surface;
  final Color route;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final double strokeWidth = math.min(size.height * 0.1, 3.2);
    final List<Offset> nodes = <Offset>[
      Offset(size.width * 0.04, size.height * 0.62),
      Offset(size.width * 0.27, size.height * 0.34),
      Offset(size.width * 0.5, size.height * 0.62),
      Offset(size.width * 0.73, size.height * 0.32),
      Offset(size.width * 0.96, size.height * 0.56),
    ];
    final Path path = _smoothPath(nodes);
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = route.withValues(alpha: 0.38);
    canvas.drawPath(path, base);

    if (progress > 0) {
      final pathMetric = path.computeMetrics().first;
      final Paint active = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 0.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent.withValues(alpha: 0.92);
      canvas.drawPath(
        pathMetric.extractPath(0, pathMetric.length * progress),
        active,
      );
    }

    final Paint inactiveNode = Paint()
      ..style = PaintingStyle.fill
      ..color = Color.alphaBlend(
        route.withValues(alpha: 0.2),
        surface.withValues(alpha: 0.98),
      );
    final Paint inactiveLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = route.withValues(alpha: 0.55);
    final Paint activeNode = Paint()
      ..style = PaintingStyle.fill
      ..color = accent;

    for (int index = 0; index < nodes.length; index += 1) {
      final double threshold = index / (nodes.length - 1);
      final bool reached = progress > 0 && threshold <= progress;
      canvas.drawCircle(
        nodes[index],
        reached ? 5.2 : 4.4,
        reached ? activeNode : inactiveNode,
      );
      if (!reached) {
        canvas.drawCircle(nodes[index], 4.4, inactiveLine);
      }
    }
  }

  Path _smoothPath(List<Offset> nodes) {
    final Path path = Path()..moveTo(nodes.first.dx, nodes.first.dy);
    for (int index = 1; index < nodes.length; index += 1) {
      final Offset previous = nodes[index - 1];
      final Offset current = nodes[index];
      final Offset midpoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    path.lineTo(nodes.last.dx, nodes.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant _QuestRouteProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route;
  }
}
