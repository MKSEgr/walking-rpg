import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum FirstJourneyRouteSignalKind {
  welcome,
  healthPermission,
  firstSync,
  petSelection,
  firstExpedition,
  firstEvent,
  unknown,
}

enum FirstJourneyRouteSignalTone { lumen, energy, resonance, neutral }

/// Presentation identities for the server-authored first-journey milestones.
///
/// Only exact stable step IDs select a known mark. Step order and completion
/// remain inputs from the accepted platform snapshot; display copy is never
/// used to infer a visual identity.
abstract final class FirstJourneyRouteSignalCatalog {
  static FirstJourneyRouteSignalKind kindFor(String stepId) {
    return switch (stepId) {
      'welcome' => FirstJourneyRouteSignalKind.welcome,
      'health-permission' => FirstJourneyRouteSignalKind.healthPermission,
      'first-sync' => FirstJourneyRouteSignalKind.firstSync,
      'pet-selection' => FirstJourneyRouteSignalKind.petSelection,
      'first-expedition' => FirstJourneyRouteSignalKind.firstExpedition,
      'first-event' => FirstJourneyRouteSignalKind.firstEvent,
      _ => FirstJourneyRouteSignalKind.unknown,
    };
  }

  static FirstJourneyRouteSignalTone toneFor(String stepId) {
    return switch (stepId) {
      'welcome' || 'first-sync' => FirstJourneyRouteSignalTone.lumen,
      'first-expedition' => FirstJourneyRouteSignalTone.energy,
      'health-permission' ||
      'pet-selection' ||
      'first-event' => FirstJourneyRouteSignalTone.resonance,
      _ => FirstJourneyRouteSignalTone.neutral,
    };
  }
}

/// Code-native route signal for accepted first-journey milestone state.
///
/// The painter follows the exact ordered [steps] list and marks only IDs found
/// in [completedSteps]. It does not select a current step, predict availability
/// or turn the onboarding sequence into chapter topology.
class FirstJourneyRouteSignal extends StatelessWidget {
  const FirstJourneyRouteSignal({
    super.key,
    required this.steps,
    required this.completedSteps,
    this.height = 112,
  });

  final List<String> steps;
  final Set<String> completedSteps;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final int completedCount = steps.where(completedSteps.contains).length;
    final String semanticLabel = steps.isEmpty
        ? context.l10n.firstJourneyRouteEmptySemantics
        : context.l10n.firstJourneyRouteProgressSemantics(
            completedCount,
            steps.length,
          );

    return Semantics(
      key: Key(
        steps.isEmpty
            ? 'first-journey-route-signal-empty'
            : 'first-journey-route-signal-$completedCount-${steps.length}',
      ),
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _FirstJourneyRouteSignalPainter(
                steps: List<String>.unmodifiable(steps),
                completedSteps: Set<String>.unmodifiable(completedSteps),
                lumen: colors.primary,
                energy: palette.energy,
                resonance: palette.resonance,
                surface: colors.surfaceContainerHigh,
                route: palette.routeLine,
                outline: colors.outlineVariant,
                neutral: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FirstJourneyRouteSignalPainter extends CustomPainter {
  const _FirstJourneyRouteSignalPainter({
    required this.steps,
    required this.completedSteps,
    required this.lumen,
    required this.energy,
    required this.resonance,
    required this.surface,
    required this.route,
    required this.outline,
    required this.neutral,
  });

  final List<String> steps;
  final Set<String> completedSteps;
  final Color lumen;
  final Color energy;
  final Color resonance;
  final Color surface;
  final Color route;
  final Color outline;
  final Color neutral;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final Rect bounds = Offset.zero & size;
    final double unit = size.shortestSide;
    final RRect frame = RRect.fromRectAndRadius(
      bounds.deflate(math.max(2.0, unit * 0.018)),
      Radius.circular(math.min(24.0, unit * 0.2)),
    );
    final Paint frameFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.alphaBlend(lumen.withValues(alpha: 0.08), surface),
          Color.alphaBlend(resonance.withValues(alpha: 0.1), surface),
        ],
      ).createShader(bounds);
    final Paint frameLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, unit * 0.016)
      ..color = Color.lerp(outline, resonance, 0.26)!.withValues(alpha: 0.58);
    canvas.drawRRect(frame, frameFill);
    canvas.drawRRect(frame, frameLine);
    _paintSignalField(canvas, size);

    final List<Offset> positions = _positionsFor(size, steps.length);
    if (positions.isEmpty) {
      _paintEmptyRoute(canvas, size);
      return;
    }

    final double spacing = positions.length < 2
        ? size.width
        : positions[1].dx - positions.first.dx;
    final double nodeRadius = math
        .min(18, spacing.abs() * 0.34)
        .clamp(5.5, 18.0)
        .toDouble();

    final Paint baseRoute = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, nodeRadius * 0.14)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Color.lerp(route, outline, 0.34)!.withValues(alpha: 0.64);
    final Path routePath = _routePath(positions);
    canvas.drawPath(routePath, baseRoute);

    for (int index = 0; index < positions.length - 1; index += 1) {
      final String currentStep = steps[index];
      final String nextStep = steps[index + 1];
      if (!completedSteps.contains(currentStep) ||
          !completedSteps.contains(nextStep)) {
        continue;
      }
      final Color acceptedAccent = Color.lerp(
        _accentFor(currentStep),
        _accentFor(nextStep),
        0.5,
      )!;
      final Paint acceptedRoute = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.0, nodeRadius * 0.23)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = acceptedAccent.withValues(alpha: 0.82);
      canvas.drawPath(
        _routePath(<Offset>[positions[index], positions[index + 1]]),
        acceptedRoute,
      );
    }

    for (int index = 0; index < positions.length; index += 1) {
      final String stepId = steps[index];
      _paintMilestone(
        canvas,
        positions[index],
        nodeRadius,
        stepId,
        completed: completedSteps.contains(stepId),
      );
    }
  }

  List<Offset> _positionsFor(Size size, int count) {
    if (count <= 0) {
      return const <Offset>[];
    }
    final double horizontalInset = math.min(30.0, size.width * 0.09);
    final double usableWidth = math.max(0.0, size.width - horizontalInset * 2);
    if (count == 1) {
      return <Offset>[size.center(Offset.zero)];
    }
    return List<Offset>.generate(count, (int index) {
      final double progress = index / (count - 1);
      final double x = horizontalInset + usableWidth * progress;
      final double wave = math.sin(progress * math.pi * 2 - math.pi * 0.55);
      final double y = size.height * (0.5 + wave * 0.14);
      return Offset(x, y);
    }, growable: false);
  }

  Path _routePath(List<Offset> positions) {
    final Path path = Path();
    if (positions.isEmpty) {
      return path;
    }
    path.moveTo(positions.first.dx, positions.first.dy);
    for (int index = 1; index < positions.length; index += 1) {
      final Offset previous = positions[index - 1];
      final Offset current = positions[index];
      final double midpointX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        midpointX,
        previous.dy,
        midpointX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    return path;
  }

  Color _accentFor(String stepId) {
    return switch (FirstJourneyRouteSignalCatalog.toneFor(stepId)) {
      FirstJourneyRouteSignalTone.lumen => lumen,
      FirstJourneyRouteSignalTone.energy => energy,
      FirstJourneyRouteSignalTone.resonance => resonance,
      FirstJourneyRouteSignalTone.neutral => neutral,
    };
  }

  void _paintMilestone(
    Canvas canvas,
    Offset center,
    double radius,
    String stepId, {
    required bool completed,
  }) {
    final Color identityAccent = _accentFor(stepId);
    final Color stateAccent = completed ? identityAccent : neutral;
    final Paint halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, radius * 0.1)
      ..color = stateAccent.withValues(alpha: completed ? 0.54 : 0.28);
    final Paint fill = Paint()
      ..color = Color.alphaBlend(
        stateAccent.withValues(alpha: completed ? 0.22 : 0.07),
        surface,
      );
    final Paint core = Paint()
      ..color = stateAccent.withValues(alpha: completed ? 0.96 : 0.54);

    if (completed) {
      canvas.drawCircle(
        center,
        radius * 1.22,
        Paint()..color = stateAccent.withValues(alpha: 0.08),
      );
    }
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, halo);
    canvas.drawCircle(center, radius * 0.12, core);
    _paintGlyph(
      canvas,
      center,
      radius,
      FirstJourneyRouteSignalCatalog.kindFor(stepId),
      core.color,
    );
  }

  void _paintGlyph(
    Canvas canvas,
    Offset center,
    double radius,
    FirstJourneyRouteSignalKind kind,
    Color accent,
  ) {
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, radius * 0.11)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent;
    final Paint fill = Paint()..color = accent;

    switch (kind) {
      case FirstJourneyRouteSignalKind.welcome:
        _paintWelcome(canvas, center, radius, stroke, fill);
      case FirstJourneyRouteSignalKind.healthPermission:
        _paintHealthPermission(canvas, center, radius, stroke);
      case FirstJourneyRouteSignalKind.firstSync:
        _paintFirstSync(canvas, center, radius, stroke);
      case FirstJourneyRouteSignalKind.petSelection:
        _paintPetSelection(canvas, center, radius, fill);
      case FirstJourneyRouteSignalKind.firstExpedition:
        _paintFirstExpedition(canvas, center, radius, stroke);
      case FirstJourneyRouteSignalKind.firstEvent:
        _paintFirstEvent(canvas, center, radius, stroke, fill);
      case FirstJourneyRouteSignalKind.unknown:
        _paintUnknown(canvas, center, radius, stroke, fill);
    }
  }

  void _paintWelcome(
    Canvas canvas,
    Offset center,
    double radius,
    Paint stroke,
    Paint fill,
  ) {
    canvas.drawCircle(center, radius * 0.18, fill);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.42),
      math.pi * 1.12,
      math.pi * 0.76,
      false,
      stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.64),
      math.pi * 1.18,
      math.pi * 0.64,
      false,
      stroke,
    );
  }

  void _paintHealthPermission(
    Canvas canvas,
    Offset center,
    double radius,
    Paint stroke,
  ) {
    final Path pulse = Path()
      ..moveTo(center.dx - radius * 0.7, center.dy)
      ..lineTo(center.dx - radius * 0.34, center.dy)
      ..lineTo(center.dx - radius * 0.12, center.dy - radius * 0.38)
      ..lineTo(center.dx + radius * 0.08, center.dy + radius * 0.38)
      ..lineTo(center.dx + radius * 0.3, center.dy)
      ..lineTo(center.dx + radius * 0.7, center.dy);
    canvas.drawPath(pulse, stroke);
  }

  void _paintFirstSync(
    Canvas canvas,
    Offset center,
    double radius,
    Paint stroke,
  ) {
    final Rect orbit = Rect.fromCircle(center: center, radius: radius * 0.48);
    canvas.drawArc(orbit, math.pi * 0.12, math.pi * 0.8, false, stroke);
    canvas.drawArc(orbit, math.pi * 1.12, math.pi * 0.8, false, stroke);
    canvas.drawLine(
      Offset(center.dx + radius * 0.48, center.dy - radius * 0.1),
      Offset(center.dx + radius * 0.28, center.dy - radius * 0.28),
      stroke,
    );
    canvas.drawLine(
      Offset(center.dx - radius * 0.48, center.dy + radius * 0.1),
      Offset(center.dx - radius * 0.28, center.dy + radius * 0.28),
      stroke,
    );
  }

  void _paintPetSelection(
    Canvas canvas,
    Offset center,
    double radius,
    Paint fill,
  ) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.18),
        width: radius * 0.64,
        height: radius * 0.54,
      ),
      fill,
    );
    for (final Offset toe in <Offset>[
      Offset(center.dx - radius * 0.38, center.dy - radius * 0.24),
      Offset(center.dx, center.dy - radius * 0.38),
      Offset(center.dx + radius * 0.38, center.dy - radius * 0.24),
    ]) {
      canvas.drawCircle(toe, radius * 0.15, fill);
    }
  }

  void _paintFirstExpedition(
    Canvas canvas,
    Offset center,
    double radius,
    Paint stroke,
  ) {
    final Path routeMark = Path()
      ..moveTo(center.dx - radius * 0.55, center.dy + radius * 0.42)
      ..cubicTo(
        center.dx - radius * 0.18,
        center.dy + radius * 0.28,
        center.dx - radius * 0.16,
        center.dy - radius * 0.28,
        center.dx + radius * 0.2,
        center.dy - radius * 0.2,
      )
      ..lineTo(center.dx + radius * 0.54, center.dy - radius * 0.38);
    canvas.drawPath(routeMark, stroke);
    canvas.drawLine(
      Offset(center.dx + radius * 0.54, center.dy - radius * 0.38),
      Offset(center.dx + radius * 0.34, center.dy - radius * 0.42),
      stroke,
    );
    canvas.drawLine(
      Offset(center.dx + radius * 0.54, center.dy - radius * 0.38),
      Offset(center.dx + radius * 0.48, center.dy - radius * 0.18),
      stroke,
    );
  }

  void _paintFirstEvent(
    Canvas canvas,
    Offset center,
    double radius,
    Paint stroke,
    Paint fill,
  ) {
    canvas.drawLine(
      Offset(center.dx, center.dy + radius * 0.55),
      Offset(center.dx, center.dy - radius * 0.08),
      stroke,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.08),
      Offset(center.dx - radius * 0.48, center.dy - radius * 0.46),
      stroke,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.08),
      Offset(center.dx + radius * 0.48, center.dy - radius * 0.46),
      stroke,
    );
    canvas.drawCircle(
      Offset(center.dx - radius * 0.5, center.dy - radius * 0.48),
      radius * 0.11,
      fill,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.5, center.dy - radius * 0.48),
      radius * 0.11,
      fill,
    );
  }

  void _paintUnknown(
    Canvas canvas,
    Offset center,
    double radius,
    Paint stroke,
    Paint fill,
  ) {
    final List<Offset> stars = <Offset>[
      Offset(center.dx - radius * 0.48, center.dy + radius * 0.22),
      Offset(center.dx - radius * 0.05, center.dy - radius * 0.44),
      Offset(center.dx + radius * 0.5, center.dy + radius * 0.06),
    ];
    canvas.drawLine(stars[0], stars[1], stroke);
    canvas.drawLine(stars[1], stars[2], stroke);
    for (final Offset star in stars) {
      canvas.drawCircle(star, radius * 0.1, fill);
    }
  }

  void _paintSignalField(Canvas canvas, Size size) {
    final Paint signal = Paint()
      ..color = Color.lerp(route, resonance, 0.36)!.withValues(alpha: 0.34);
    for (final Offset point in <Offset>[
      Offset(size.width * 0.08, size.height * 0.22),
      Offset(size.width * 0.22, size.height * 0.8),
      Offset(size.width * 0.47, size.height * 0.18),
      Offset(size.width * 0.72, size.height * 0.83),
      Offset(size.width * 0.92, size.height * 0.26),
    ]) {
      canvas.drawCircle(
        point,
        math.max(1.1, size.shortestSide * 0.011),
        signal,
      );
    }
  }

  void _paintEmptyRoute(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final Paint openRoute = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, size.shortestSide * 0.018)
      ..strokeCap = StrokeCap.round
      ..color = outline.withValues(alpha: 0.48);
    canvas.drawArc(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.46,
        height: size.height * 0.42,
      ),
      math.pi * 0.12,
      math.pi * 1.42,
      false,
      openRoute,
    );
    _paintUnknown(
      canvas,
      center,
      math.min(18.0, size.shortestSide * 0.18),
      openRoute,
      Paint()..color = neutral.withValues(alpha: 0.58),
    );
  }

  @override
  bool shouldRepaint(covariant _FirstJourneyRouteSignalPainter oldDelegate) {
    return !listEquals(oldDelegate.steps, steps) ||
        !setEquals(oldDelegate.completedSteps, completedSteps) ||
        oldDelegate.lumen != lumen ||
        oldDelegate.energy != energy ||
        oldDelegate.resonance != resonance ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route ||
        oldDelegate.outline != outline ||
        oldDelegate.neutral != neutral;
  }
}
