import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum ProgressionSigilKind {
  steadyStep,
  trailMemory,
  energyDiscipline,
  signalReader,
  pathOpened,
  petFriend,
  skillApprentice,
  questRunner,
  weeklyRoute,
  squadMember,
  newLook,
  seasonThree,
  unknown,
}

enum ProgressionSigilTone { lumen, energy, resonance }

/// Presentation identities for the current server-authored progression catalog.
///
/// Only exact stable IDs select a known sigil. Display names and descriptions
/// are deliberately ignored so future content cannot borrow an unrelated mark.
abstract final class ProgressionSigilCatalog {
  static ProgressionSigilKind kindFor(String identity) {
    return switch (identity) {
      'steady-step' => ProgressionSigilKind.steadyStep,
      'trail-memory' => ProgressionSigilKind.trailMemory,
      'energy-discipline' => ProgressionSigilKind.energyDiscipline,
      'signal-reader' => ProgressionSigilKind.signalReader,
      'onboarding-complete' => ProgressionSigilKind.pathOpened,
      'pet-friend' => ProgressionSigilKind.petFriend,
      'skill-apprentice' => ProgressionSigilKind.skillApprentice,
      'quest-runner' => ProgressionSigilKind.questRunner,
      'weekly-route-complete' => ProgressionSigilKind.weeklyRoute,
      'squad-member' => ProgressionSigilKind.squadMember,
      'first-cosmetic' => ProgressionSigilKind.newLook,
      'season-level-3' => ProgressionSigilKind.seasonThree,
      _ => ProgressionSigilKind.unknown,
    };
  }

  static ProgressionSigilTone toneFor(String identity) {
    return switch (identity) {
      'energy-discipline' ||
      'quest-runner' ||
      'weekly-route-complete' ||
      'season-level-3' => ProgressionSigilTone.energy,
      'trail-memory' ||
      'signal-reader' ||
      'skill-apprentice' ||
      'first-cosmetic' => ProgressionSigilTone.resonance,
      _ => ProgressionSigilTone.lumen,
    };
  }
}

/// A small code-native progression mark selected from an exact server ID.
///
/// The sigil is decorative next to the complete server-provided name and
/// explicit locked/unlocked copy. [active] affects presentation only and never
/// derives whether a skill or achievement is actually unlocked.
class ProgressionSigil extends StatelessWidget {
  const ProgressionSigil({
    super.key,
    required this.identity,
    required this.active,
    this.size = 56,
  });

  final String identity;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final ProgressionSigilTone tone = ProgressionSigilCatalog.toneFor(identity);
    final Color semanticAccent = switch (tone) {
      ProgressionSigilTone.lumen => colors.primary,
      ProgressionSigilTone.energy => palette.energy,
      ProgressionSigilTone.resonance => palette.resonance,
    };
    final Color accent = active
        ? semanticAccent
        : colors.onSurfaceVariant.withValues(alpha: 0.72);

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          key: Key(
            'progression-sigil-$identity-${active ? 'active' : 'locked'}',
          ),
          dimension: size,
          child: CustomPaint(
            painter: _ProgressionSigilPainter(
              kind: ProgressionSigilCatalog.kindFor(identity),
              accent: accent,
              surface: colors.surfaceContainerHigh,
              route: palette.routeLine,
              active: active,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressionSigilPainter extends CustomPainter {
  const _ProgressionSigilPainter({
    required this.kind,
    required this.accent,
    required this.surface,
    required this.route,
    required this.active,
  });

  final ProgressionSigilKind kind;
  final Color accent;
  final Color surface;
  final Color route;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Rect bounds = Offset.zero & size;
    final double unit = size.shortestSide;
    final Offset center = bounds.center;
    final RRect frame = RRect.fromRectAndRadius(
      bounds.deflate(unit * 0.025),
      Radius.circular(unit * 0.28),
    );
    final Paint frameFill = Paint()
      ..color = Color.alphaBlend(
        accent.withValues(alpha: active ? 0.13 : 0.055),
        surface.withValues(alpha: 0.96),
      );
    final Paint frameLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.025
      ..color = accent.withValues(alpha: active ? 0.62 : 0.32);
    canvas.drawRRect(frame, frameFill);
    canvas.drawRRect(frame, frameLine);

    final Paint orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.025
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        route,
        accent,
        0.38,
      )!.withValues(alpha: active ? 0.5 : 0.28);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.34),
      math.pi * 0.16,
      math.pi * 0.56,
      false,
      orbit,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.34),
      math.pi * 1.14,
      math.pi * 0.43,
      false,
      orbit,
    );

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.052
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: active ? 0.96 : 0.67);
    final Paint fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.03
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: active ? 0.82 : 0.5);
    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: active ? 0.94 : 0.62);

    switch (kind) {
      case ProgressionSigilKind.steadyStep:
        _paintSteadyStep(canvas, size, stroke, fill);
      case ProgressionSigilKind.trailMemory:
        _paintTrailMemory(canvas, size, stroke, fine, fill);
      case ProgressionSigilKind.energyDiscipline:
        _paintEnergyDiscipline(canvas, size, stroke, fine);
      case ProgressionSigilKind.signalReader:
        _paintSignalReader(canvas, size, stroke, fine, fill);
      case ProgressionSigilKind.pathOpened:
        _paintPathOpened(canvas, size, stroke, fine, fill);
      case ProgressionSigilKind.petFriend:
        _paintPetFriend(canvas, size, fill);
      case ProgressionSigilKind.skillApprentice:
        _paintSkillApprentice(canvas, size, fine, fill);
      case ProgressionSigilKind.questRunner:
        _paintQuestRunner(canvas, size, stroke, fine, fill);
      case ProgressionSigilKind.weeklyRoute:
        _paintWeeklyRoute(canvas, size, fine, fill);
      case ProgressionSigilKind.squadMember:
        _paintSquadMember(canvas, size, fine, fill);
      case ProgressionSigilKind.newLook:
        _paintNewLook(canvas, size, stroke, fine);
      case ProgressionSigilKind.seasonThree:
        _paintSeasonThree(canvas, size, stroke, fill);
      case ProgressionSigilKind.unknown:
        _paintUnknown(canvas, size, fine, fill);
    }
  }

  Offset _point(Size size, double x, double y) {
    return Offset(size.width * x, size.height * y);
  }

  void _paintSteadyStep(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final Path path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.71)
      ..cubicTo(
        size.width * 0.36,
        size.height * 0.65,
        size.width * 0.58,
        size.height * 0.39,
        size.width * 0.75,
        size.height * 0.31,
      );
    canvas.drawPath(path, stroke);
    _drawRotatedOval(canvas, _point(size, 0.39, 0.57), size, -0.55, fill);
    _drawRotatedOval(canvas, _point(size, 0.61, 0.42), size, -0.55, fill);
  }

  void _drawRotatedOval(
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
        width: size.shortestSide * 0.12,
        height: size.shortestSide * 0.2,
      ),
      fill,
    );
    canvas.restore();
  }

  void _paintTrailMemory(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset start = _point(size, 0.28, 0.72);
    final Offset junction = _point(size, 0.5, 0.53);
    final Offset upper = _point(size, 0.66, 0.28);
    final Offset lower = _point(size, 0.74, 0.62);
    canvas.drawLine(start, junction, stroke);
    canvas.drawLine(junction, upper, fine);
    canvas.drawLine(junction, lower, fine);
    for (final Offset node in <Offset>[start, junction, upper, lower]) {
      canvas.drawCircle(node, size.shortestSide * 0.055, fill);
    }
  }

  void _paintEnergyDiscipline(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
  ) {
    final Offset center = size.center(Offset.zero);
    canvas.drawCircle(center, size.shortestSide * 0.25, fine);
    final Path bolt = Path()
      ..moveTo(size.width * 0.55, size.height * 0.25)
      ..lineTo(size.width * 0.37, size.height * 0.53)
      ..lineTo(size.width * 0.5, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.76)
      ..lineTo(size.width * 0.66, size.height * 0.43)
      ..lineTo(size.width * 0.53, size.height * 0.43);
    canvas.drawPath(bolt, stroke);
  }

  void _paintSignalReader(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset source = _point(size, 0.34, 0.66);
    canvas.drawCircle(source, size.shortestSide * 0.055, fill);
    for (final double radius in <double>[0.16, 0.28]) {
      canvas.drawArc(
        Rect.fromCircle(center: source, radius: size.shortestSide * radius),
        -math.pi * 0.48,
        math.pi * 0.55,
        false,
        fine,
      );
    }
    canvas.drawLine(source, _point(size, 0.7, 0.31), stroke);
    canvas.drawCircle(_point(size, 0.7, 0.31), size.shortestSide * 0.045, fill);
  }

  void _paintPathOpened(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path gate = Path()
      ..moveTo(size.width * 0.31, size.height * 0.7)
      ..lineTo(size.width * 0.31, size.height * 0.41)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.2,
        size.width * 0.69,
        size.height * 0.41,
      )
      ..lineTo(size.width * 0.69, size.height * 0.7);
    canvas.drawPath(gate, stroke);
    final Path routePath = Path()
      ..moveTo(size.width * 0.5, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.57,
        size.height * 0.59,
        size.width * 0.5,
        size.height * 0.38,
      );
    canvas.drawPath(routePath, fine);
    canvas.drawCircle(_point(size, 0.5, 0.35), size.shortestSide * 0.045, fill);
  }

  void _paintPetFriend(Canvas canvas, Size size, Paint fill) {
    canvas.drawOval(
      Rect.fromCenter(
        center: _point(size, 0.5, 0.59),
        width: size.shortestSide * 0.29,
        height: size.shortestSide * 0.24,
      ),
      fill,
    );
    for (final Offset toe in <Offset>[
      _point(size, 0.34, 0.4),
      _point(size, 0.45, 0.32),
      _point(size, 0.57, 0.32),
      _point(size, 0.68, 0.4),
    ]) {
      canvas.drawCircle(toe, size.shortestSide * 0.065, fill);
    }
  }

  void _paintSkillApprentice(Canvas canvas, Size size, Paint fine, Paint fill) {
    final Offset center = _point(size, 0.5, 0.51);
    final List<Offset> satellites = <Offset>[
      _point(size, 0.5, 0.25),
      _point(size, 0.27, 0.66),
      _point(size, 0.73, 0.66),
    ];
    for (final Offset satellite in satellites) {
      canvas.drawLine(center, satellite, fine);
      canvas.drawCircle(satellite, size.shortestSide * 0.065, fill);
    }
    canvas.drawCircle(center, size.shortestSide * 0.095, fill);
  }

  void _paintQuestRunner(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path routePath = Path()
      ..moveTo(size.width * 0.24, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.79,
        size.width * 0.58,
        size.height * 0.58,
      )
      ..lineTo(size.width * 0.67, size.height * 0.35);
    canvas.drawPath(routePath, fine);
    canvas.drawCircle(_point(size, 0.24, 0.7), size.shortestSide * 0.045, fill);
    canvas.drawLine(_point(size, 0.67, 0.7), _point(size, 0.67, 0.28), stroke);
    final Path flag = Path()
      ..moveTo(size.width * 0.69, size.height * 0.29)
      ..lineTo(size.width * 0.82, size.height * 0.35)
      ..lineTo(size.width * 0.69, size.height * 0.43)
      ..close();
    canvas.drawPath(flag, fill);
  }

  void _paintWeeklyRoute(Canvas canvas, Size size, Paint fine, Paint fill) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide * 0.24;
    canvas.drawCircle(center, radius, fine);
    for (int index = 0; index < 7; index += 1) {
      final double angle = -math.pi / 2 + (math.pi * 2 * index / 7);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        size.shortestSide * 0.035,
        fill,
      );
    }
  }

  void _paintSquadMember(Canvas canvas, Size size, Paint fine, Paint fill) {
    final List<Offset> nodes = <Offset>[
      _point(size, 0.5, 0.29),
      _point(size, 0.3, 0.67),
      _point(size, 0.7, 0.67),
    ];
    final Path links = Path()
      ..moveTo(nodes[0].dx, nodes[0].dy)
      ..lineTo(nodes[1].dx, nodes[1].dy)
      ..lineTo(nodes[2].dx, nodes[2].dy)
      ..close();
    canvas.drawPath(links, fine);
    for (final Offset node in nodes) {
      canvas.drawCircle(node, size.shortestSide * 0.085, fill);
    }
  }

  void _paintNewLook(Canvas canvas, Size size, Paint stroke, Paint fine) {
    final Path framePath = Path()
      ..moveTo(size.width * 0.5, size.height * 0.24)
      ..lineTo(size.width * 0.71, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height * 0.76)
      ..lineTo(size.width * 0.29, size.height * 0.5)
      ..close();
    canvas.drawPath(framePath, stroke);
    canvas.drawLine(_point(size, 0.65, 0.25), _point(size, 0.65, 0.38), fine);
    canvas.drawLine(_point(size, 0.59, 0.315), _point(size, 0.71, 0.315), fine);
  }

  void _paintSeasonThree(Canvas canvas, Size size, Paint stroke, Paint fill) {
    const List<double> xValues = <double>[0.31, 0.5, 0.69];
    const List<double> tops = <double>[0.62, 0.45, 0.28];
    for (int index = 0; index < xValues.length; index += 1) {
      final double x = xValues[index];
      final double top = tops[index];
      canvas.drawLine(_point(size, x, 0.72), _point(size, x, top), stroke);
      canvas.drawCircle(_point(size, x, top), size.shortestSide * 0.055, fill);
    }
  }

  void _paintUnknown(Canvas canvas, Size size, Paint fine, Paint fill) {
    final List<Offset> nodes = <Offset>[
      _point(size, 0.28, 0.62),
      _point(size, 0.42, 0.36),
      _point(size, 0.56, 0.56),
      _point(size, 0.72, 0.32),
      _point(size, 0.73, 0.69),
    ];
    final Path constellation = Path()..moveTo(nodes.first.dx, nodes.first.dy);
    for (final Offset node in nodes.skip(1)) {
      constellation.lineTo(node.dx, node.dy);
    }
    canvas.drawPath(constellation, fine);
    for (final Offset node in nodes) {
      canvas.drawCircle(node, size.shortestSide * 0.045, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressionSigilPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.accent != accent ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route ||
        oldDelegate.active != active;
  }
}
