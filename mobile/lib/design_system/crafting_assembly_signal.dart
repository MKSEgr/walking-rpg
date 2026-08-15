import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum CraftingAssemblySignalKind { resonanceCompass, prismSextant, unknown }

/// Presentation identities for server-authored crafting recipes.
///
/// Only an exact stable recipe ID selects a known assembly contour. Player-
/// facing names and result copy are deliberately ignored so future recipes do
/// not borrow the resonance-compass identity.
abstract final class CraftingAssemblySignalCatalog {
  static CraftingAssemblySignalKind kindFor(String recipeId) {
    return switch (recipeId) {
      'resonance-compass-v1' => CraftingAssemblySignalKind.resonanceCompass,
      'prism-sextant-v1' => CraftingAssemblySignalKind.prismSextant,
      _ => CraftingAssemblySignalKind.unknown,
    };
  }
}

/// Keeps a variable server-owned ingredient list inside a quiet visual field.
///
/// The cap affects decorative nodes only. Exact ingredient names and quantities
/// remain in the adjacent recipe rows.
abstract final class CraftingAssemblySignalLayout {
  static const int maxVisibleIngredients = 4;

  static int visibleIngredientCountFor(int ingredientCount) {
    return math.min(math.max(ingredientCount, 0), maxVisibleIngredients);
  }

  static bool hasOverflow(int ingredientCount) {
    return ingredientCount > maxVisibleIngredients;
  }
}

/// Code-native transformation contour for one accepted crafting recipe.
///
/// Ingredient sufficiency is presentation-only and comes from literal accepted
/// quantities. Whether the output route is open comes only from the server-
/// authored recipe status. The widget owns no semantics because the surrounding
/// recipe already exposes the exact names, quantities, result and action state.
class CraftingAssemblySignal extends StatelessWidget {
  const CraftingAssemblySignal({
    super.key,
    required this.recipeId,
    required this.status,
    required this.ingredientAvailability,
    this.height = 112,
  }) : assert(height > 0);

  final String recipeId;
  final String status;
  final List<bool> ingredientAvailability;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final CraftingAssemblySignalKind kind =
        CraftingAssemblySignalCatalog.kindFor(recipeId);

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          key: Key('crafting-assembly-signal-$recipeId-${kind.name}-$status'),
          width: double.infinity,
          height: height,
          child: CustomPaint(
            painter: _CraftingAssemblySignalPainter(
              kind: kind,
              status: status,
              ingredientAvailability: List<bool>.of(
                ingredientAvailability,
                growable: false,
              ),
              lumen: colors.primary,
              energy: palette.energy,
              resonance: palette.resonance,
              surface: colors.surfaceContainerHigh,
              route: palette.routeLine,
              outline: colors.outlineVariant,
              foreground: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _CraftingAssemblySignalPainter extends CustomPainter {
  const _CraftingAssemblySignalPainter({
    required this.kind,
    required this.status,
    required this.ingredientAvailability,
    required this.lumen,
    required this.energy,
    required this.resonance,
    required this.surface,
    required this.route,
    required this.outline,
    required this.foreground,
  });

  final CraftingAssemblySignalKind kind;
  final String status;
  final List<bool> ingredientAvailability;
  final Color lumen;
  final Color energy;
  final Color resonance;
  final Color surface;
  final Color route;
  final Color outline;
  final Color foreground;

  bool get _isReady => status == 'READY';
  bool get _isCrafted => status == 'CRAFTED';

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double unit = size.height;
    final Color identityAccent = switch (kind) {
      CraftingAssemblySignalKind.resonanceCompass => resonance,
      CraftingAssemblySignalKind.prismSextant => lumen,
      CraftingAssemblySignalKind.unknown => foreground,
    };
    final Color stateAccent = _isCrafted
        ? lumen
        : _isReady
        ? energy
        : identityAccent;
    final RRect frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(unit * 0.025),
      Radius.circular(unit * 0.2),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = Color.alphaBlend(
          identityAccent.withValues(alpha: 0.09),
          surface.withValues(alpha: 0.97),
        ),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.018
        ..color = stateAccent.withValues(alpha: 0.48),
    );

    _paintField(canvas, size, unit, identityAccent);

    final int visibleCount =
        CraftingAssemblySignalLayout.visibleIngredientCountFor(
          ingredientAvailability.length,
        );
    final List<Offset> inputNodes = _ingredientNodes(size, visibleCount);
    final Offset core = Offset(size.width * 0.53, size.height * 0.5);
    final Offset output = Offset(size.width * 0.84, size.height * 0.5);
    for (int index = 0; index < inputNodes.length; index++) {
      final bool sufficient = ingredientAvailability[index];
      _paintIngredientRoute(
        canvas,
        size,
        from: inputNodes[index],
        to: core,
        sufficient: sufficient,
      );
      _paintIngredientNode(
        canvas,
        inputNodes[index],
        unit,
        sufficient: sufficient,
      );
    }
    if (inputNodes.isEmpty) {
      _paintOpenInput(canvas, Offset(size.width * 0.17, core.dy), unit);
    }
    if (CraftingAssemblySignalLayout.hasOverflow(
      ingredientAvailability.length,
    )) {
      _paintOverflow(canvas, Offset(size.width * 0.27, core.dy), unit);
    }

    _paintOutputRoute(canvas, core, output, unit, stateAccent);
    switch (kind) {
      case CraftingAssemblySignalKind.resonanceCompass:
        _paintResonanceCore(canvas, core, unit, stateAccent);
      case CraftingAssemblySignalKind.prismSextant:
        _paintPrismCore(canvas, core, unit, stateAccent);
      case CraftingAssemblySignalKind.unknown:
        _paintUnknownCore(canvas, core, unit, identityAccent);
    }
    _paintOutputNode(canvas, output, unit, stateAccent);
  }

  void _paintField(
    Canvas canvas,
    Size size,
    double unit,
    Color identityAccent,
  ) {
    final Paint field = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.012
      ..strokeCap = StrokeCap.round
      ..color = identityAccent.withValues(alpha: 0.2);
    final Offset center = Offset(size.width * 0.53, size.height * 0.5);
    canvas.drawArc(
      Rect.fromCenter(center: center, width: unit * 1.38, height: unit * 0.72),
      math.pi * 0.12,
      math.pi * 0.58,
      false,
      field,
    );
    canvas.drawArc(
      Rect.fromCenter(center: center, width: unit * 1.38, height: unit * 0.72),
      math.pi * 1.1,
      math.pi * 0.48,
      false,
      field,
    );
  }

  List<Offset> _ingredientNodes(Size size, int count) {
    if (count <= 0) {
      return const <Offset>[];
    }
    if (count == 1) {
      return <Offset>[Offset(size.width * 0.16, size.height * 0.5)];
    }
    return List<Offset>.generate(count, (int index) {
      final double fraction = index / (count - 1);
      return Offset(size.width * 0.16, size.height * (0.23 + fraction * 0.54));
    });
  }

  void _paintIngredientRoute(
    Canvas canvas,
    Size size, {
    required Offset from,
    required Offset to,
    required bool sufficient,
  }) {
    final Path path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(
        size.width * 0.31,
        from.dy,
        size.width * 0.34,
        to.dy,
        to.dx,
        to.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.018
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(route, outline, 0.35)!.withValues(alpha: 0.62),
    );
    if (sufficient) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * 0.026
          ..strokeCap = StrokeCap.round
          ..color = energy.withValues(alpha: 0.82),
      );
    }
  }

  void _paintIngredientNode(
    Canvas canvas,
    Offset center,
    double unit, {
    required bool sufficient,
  }) {
    final Color accent = sufficient ? energy : outline;
    canvas.drawCircle(
      center,
      unit * 0.058,
      Paint()
        ..color = Color.alphaBlend(
          accent.withValues(alpha: sufficient ? 0.32 : 0.08),
          surface,
        ),
    );
    canvas.drawCircle(
      center,
      unit * 0.058,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.017
        ..color = accent.withValues(alpha: sufficient ? 0.94 : 0.58),
    );
    if (sufficient) {
      canvas.drawCircle(center, unit * 0.018, Paint()..color = energy);
    }
  }

  void _paintOpenInput(Canvas canvas, Offset center, double unit) {
    canvas.drawCircle(
      center,
      unit * 0.052,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.016
        ..color = outline.withValues(alpha: 0.56),
    );
  }

  void _paintOverflow(Canvas canvas, Offset center, double unit) {
    final Paint dot = Paint()..color = foreground.withValues(alpha: 0.54);
    for (final double offset in <double>[-1, 0, 1]) {
      canvas.drawCircle(
        center + Offset(0, offset * unit * 0.045),
        unit * 0.012,
        dot,
      );
    }
  }

  void _paintOutputRoute(
    Canvas canvas,
    Offset core,
    Offset output,
    double unit,
    Color stateAccent,
  ) {
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.018
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(route, outline, 0.35)!.withValues(alpha: 0.64);
    canvas.drawLine(core, output, base);
    if (_isReady || _isCrafted) {
      canvas.drawLine(
        core,
        output,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.032
          ..strokeCap = StrokeCap.round
          ..color = stateAccent.withValues(alpha: 0.9),
      );
    }
  }

  void _paintResonanceCore(
    Canvas canvas,
    Offset center,
    double unit,
    Color stateAccent,
  ) {
    final double radius = unit * 0.18;
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.018
      ..color = resonance.withValues(alpha: 0.82);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Color.alphaBlend(resonance.withValues(alpha: 0.16), surface),
    );
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(center, radius * 0.62, ring);
    final Path needle = Path()
      ..moveTo(center.dx, center.dy - radius * 0.75)
      ..lineTo(center.dx + radius * 0.27, center.dy + radius * 0.16)
      ..lineTo(center.dx, center.dy + radius * 0.48)
      ..lineTo(center.dx - radius * 0.27, center.dy + radius * 0.16)
      ..close();
    canvas.drawPath(
      needle,
      Paint()..color = stateAccent.withValues(alpha: 0.94),
    );
    canvas.drawCircle(center, unit * 0.024, Paint()..color = lumen);
  }

  void _paintUnknownCore(
    Canvas canvas,
    Offset center,
    double unit,
    Color identityAccent,
  ) {
    final List<Offset> points = <Offset>[
      center + Offset(-unit * 0.1, unit * 0.08),
      center + Offset(0, -unit * 0.11),
      center + Offset(unit * 0.11, unit * 0.07),
    ];
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.016
      ..color = identityAccent.withValues(alpha: 0.62);
    canvas
      ..drawLine(points[0], points[1], line)
      ..drawLine(points[1], points[2], line);
    for (final Offset point in points) {
      canvas.drawCircle(
        point,
        unit * 0.027,
        Paint()..color = identityAccent.withValues(alpha: 0.78),
      );
    }
  }

  void _paintPrismCore(
    Canvas canvas,
    Offset center,
    double unit,
    Color stateAccent,
  ) {
    final double radius = unit * 0.2;
    final Path prism = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.88, center.dy + radius * 0.62)
      ..lineTo(center.dx - radius * 0.88, center.dy + radius * 0.62)
      ..close();
    canvas.drawPath(
      prism,
      Paint()..color = Color.alphaBlend(lumen.withValues(alpha: 0.16), surface),
    );
    canvas.drawPath(
      prism,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.02
        ..strokeJoin = StrokeJoin.round
        ..color = stateAccent.withValues(alpha: 0.9),
    );
    canvas.drawLine(
      center + Offset(-radius * 0.48, radius * 0.18),
      center + Offset(radius * 0.56, radius * 0.18),
      Paint()
        ..strokeWidth = unit * 0.018
        ..strokeCap = StrokeCap.round
        ..color = resonance.withValues(alpha: 0.84),
    );
  }

  void _paintOutputNode(
    Canvas canvas,
    Offset center,
    double unit,
    Color stateAccent,
  ) {
    final bool active = _isReady || _isCrafted;
    canvas.drawCircle(
      center,
      unit * 0.09,
      Paint()
        ..color = Color.alphaBlend(
          stateAccent.withValues(alpha: active ? 0.26 : 0.08),
          surface,
        ),
    );
    canvas.drawCircle(
      center,
      unit * 0.09,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.02
        ..color = stateAccent.withValues(alpha: active ? 0.9 : 0.5),
    );
    if (_isCrafted) {
      final Paint check = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.024
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = lumen;
      final Path path = Path()
        ..moveTo(center.dx - unit * 0.035, center.dy)
        ..lineTo(center.dx - unit * 0.008, center.dy + unit * 0.028)
        ..lineTo(center.dx + unit * 0.045, center.dy - unit * 0.035);
      canvas.drawPath(path, check);
      return;
    }
    canvas.drawCircle(
      center,
      unit * 0.022,
      Paint()..color = stateAccent.withValues(alpha: active ? 0.94 : 0.42),
    );
  }

  @override
  bool shouldRepaint(covariant _CraftingAssemblySignalPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.status != status ||
        !listEquals(
          oldDelegate.ingredientAvailability,
          ingredientAvailability,
        ) ||
        oldDelegate.lumen != lumen ||
        oldDelegate.energy != energy ||
        oldDelegate.resonance != resonance ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route ||
        oldDelegate.outline != outline ||
        oldDelegate.foreground != foreground;
  }
}
