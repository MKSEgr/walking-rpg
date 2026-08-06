import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum SeasonRewardSealIdentity { firstSignal, unknown }

/// Presentation identities for server-authored seasons.
///
/// Only an exact stable season ID selects a known seal. Season names and level
/// copy deliberately do not participate in dispatch, so future seasons keep a
/// neutral identity.
abstract final class SeasonRewardSealCatalog {
  static SeasonRewardSealIdentity identityFor(String seasonId) {
    return switch (seasonId) {
      'signal-season-1' || 'season-1' => SeasonRewardSealIdentity.firstSignal,
      _ => SeasonRewardSealIdentity.unknown,
    };
  }
}

/// Decorative seal for one reward level exposed by the existing claim action.
///
/// The parent remains responsible for deciding whether a reward can be claimed
/// and for exposing its complete level label. This widget only repeats the
/// accepted season identity and literal level position as visual orientation.
class SeasonRewardSeal extends StatelessWidget {
  const SeasonRewardSeal({
    super.key,
    required this.seasonId,
    required this.level,
    required this.totalLevels,
    this.size = 24,
  }) : assert(level > 0),
       assert(totalLevels > 0),
       assert(size > 0);

  final String seasonId;
  final int level;
  final int totalLevels;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final SeasonRewardSealIdentity identity =
        SeasonRewardSealCatalog.identityFor(seasonId);
    final bool known = identity == SeasonRewardSealIdentity.firstSignal;
    final double progress = (level / totalLevels).clamp(0.0, 1.0).toDouble();

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          key: Key('season-reward-seal-$seasonId-$level-${identity.name}'),
          dimension: size,
          child: CustomPaint(
            painter: _SeasonRewardSealPainter(
              identity: identity,
              progress: progress,
              accent: known ? palette.energy : colors.onSurfaceVariant,
              resonance: known ? palette.resonance : colors.outlineVariant,
              lumen: known ? colors.primary : colors.onSurfaceVariant,
              surface: colors.surfaceContainerHigh,
              route: palette.routeLine,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonRewardSealPainter extends CustomPainter {
  const _SeasonRewardSealPainter({
    required this.identity,
    required this.progress,
    required this.accent,
    required this.resonance,
    required this.lumen,
    required this.surface,
    required this.route,
  });

  final SeasonRewardSealIdentity identity;
  final double progress;
  final Color accent;
  final Color resonance;
  final Color lumen;
  final Color surface;
  final Color route;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double unit = size.shortestSide;
    canvas
      ..save()
      ..translate((size.width - unit) / 2, (size.height - unit) / 2)
      ..scale(unit / 100);

    const Rect frameBounds = Rect.fromLTWH(3, 3, 94, 94);
    final RRect frame = RRect.fromRectAndRadius(
      frameBounds,
      const Radius.circular(28),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.34, -0.42),
          radius: 1.18,
          colors: <Color>[
            accent.withValues(alpha: 0.2),
            surface.withValues(alpha: 0.98),
          ],
        ).createShader(frameBounds),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = resonance.withValues(alpha: 0.64)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    const Rect progressRing = Rect.fromLTWH(17, 17, 66, 66);
    canvas.drawArc(
      progressRing,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = route.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4,
    );
    if (progress > 0) {
      canvas.drawArc(
        progressRing,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5.5,
      );
    }

    switch (identity) {
      case SeasonRewardSealIdentity.firstSignal:
        _drawFirstSignal(canvas);
        break;
      case SeasonRewardSealIdentity.unknown:
        _drawUnknown(canvas);
        break;
    }
    _drawRewardPulse(canvas);
    canvas.restore();
  }

  void _drawFirstSignal(Canvas canvas) {
    final Paint routePaint = Paint()
      ..color = lumen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4;
    final Path path = Path()
      ..moveTo(28, 65)
      ..quadraticBezierTo(38, 62, 43, 51)
      ..lineTo(56, 56)
      ..lineTo(69, 37);
    canvas.drawPath(path, routePaint);

    final Paint node = Paint()..color = lumen;
    for (final Offset position in const <Offset>[
      Offset(28, 65),
      Offset(43, 51),
      Offset(56, 56),
    ]) {
      canvas.drawCircle(position, 3.4, node);
    }
    final Path beacon = Path()
      ..moveTo(69, 27)
      ..lineTo(76, 40)
      ..lineTo(69, 37)
      ..lineTo(62, 40)
      ..close();
    canvas.drawPath(beacon, Paint()..color = resonance);
  }

  void _drawUnknown(Canvas canvas) {
    final Paint line = Paint()
      ..color = lumen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.8;
    final Paint node = Paint()..color = lumen;
    const List<Offset> points = <Offset>[
      Offset(31, 63),
      Offset(47, 38),
      Offset(68, 58),
    ];
    canvas
      ..drawLine(points[0], points[1], line)
      ..drawLine(points[1], points[2], line);
    for (final Offset position in points) {
      canvas.drawCircle(position, 3.8, node);
    }
  }

  void _drawRewardPulse(Canvas canvas) {
    final Paint pulse = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    canvas
      ..drawLine(const Offset(78, 75), const Offset(78, 87), pulse)
      ..drawLine(const Offset(72, 81), const Offset(84, 81), pulse)
      ..drawLine(const Offset(74, 77), const Offset(82, 85), pulse)
      ..drawLine(const Offset(82, 77), const Offset(74, 85), pulse);
  }

  @override
  bool shouldRepaint(covariant _SeasonRewardSealPainter oldDelegate) {
    return oldDelegate.identity != identity ||
        oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.resonance != resonance ||
        oldDelegate.lumen != lumen ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route;
  }
}
