import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum ExpeditionNavigationDestination { expedition, journal }

/// Code-native identity for the two stable player destinations.
///
/// The glyph is deliberately decorative. The owning navigation control keeps
/// the complete destination label, selection semantics and callback.
class ExpeditionNavigationGlyph extends StatelessWidget {
  const ExpeditionNavigationGlyph({
    super.key,
    required this.destination,
    required this.selected,
    this.size = 24,
  }) : assert(size > 0);

  final ExpeditionNavigationDestination destination;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Color foreground =
        IconTheme.of(context).color ?? colors.onSurfaceVariant;
    final Color accent = switch (destination) {
      ExpeditionNavigationDestination.expedition => palette.energy,
      ExpeditionNavigationDestination.journal => palette.resonance,
    };

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _ExpeditionNavigationGlyphPainter(
              destination: destination,
              selected: selected,
              foreground: foreground,
              accent: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpeditionNavigationGlyphPainter extends CustomPainter {
  const _ExpeditionNavigationGlyphPainter({
    required this.destination,
    required this.selected,
    required this.foreground,
    required this.accent,
  });

  final ExpeditionNavigationDestination destination;
  final bool selected;
  final Color foreground;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    switch (destination) {
      case ExpeditionNavigationDestination.expedition:
        _paintExpedition(canvas, size);
        return;
      case ExpeditionNavigationDestination.journal:
        _paintJournal(canvas, size);
        return;
    }
  }

  void _paintExpedition(Canvas canvas, Size size) {
    final double unit = size.shortestSide;
    final Paint route = Paint()
      ..color = foreground.withValues(alpha: selected ? 0.96 : 0.74)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = unit * 0.09;
    final Path path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.76)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.82,
        size.width * 0.35,
        size.height * 0.43,
        size.width * 0.53,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.52,
        size.width * 0.68,
        size.height * 0.28,
        size.width * 0.82,
        size.height * 0.24,
      );

    if (selected) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.82, size.height * 0.24),
          width: unit * 0.43,
          height: unit * 0.43,
        ),
        -1.9,
        4.55,
        false,
        Paint()
          ..color = accent.withValues(alpha: 0.64)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = unit * 0.065,
      );
    }
    canvas.drawPath(path, route);

    final Paint node = Paint()
      ..color = foreground.withValues(alpha: selected ? 0.96 : 0.76);
    canvas
      ..drawCircle(
        Offset(size.width * 0.14, size.height * 0.76),
        unit * 0.075,
        node,
      )
      ..drawCircle(
        Offset(size.width * 0.53, size.height * 0.48),
        unit * 0.065,
        node,
      )
      ..drawCircle(
        Offset(size.width * 0.82, size.height * 0.24),
        unit * (selected ? 0.105 : 0.075),
        Paint()..color = selected ? accent : foreground,
      );
  }

  void _paintJournal(Canvas canvas, Size size) {
    final double unit = size.shortestSide;
    final Paint page = Paint()
      ..color = foreground.withValues(alpha: selected ? 0.96 : 0.74)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = unit * 0.075;
    final double centerX = size.width * 0.5;
    final Path leftPage = Path()
      ..moveTo(centerX - unit * 0.035, size.height * 0.24)
      ..quadraticBezierTo(
        size.width * 0.31,
        size.height * 0.13,
        size.width * 0.14,
        size.height * 0.22,
      )
      ..lineTo(size.width * 0.14, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height * 0.67,
        centerX - unit * 0.035,
        size.height * 0.79,
      )
      ..close();
    final Path rightPage = Path()
      ..moveTo(centerX + unit * 0.035, size.height * 0.24)
      ..quadraticBezierTo(
        size.width * 0.69,
        size.height * 0.13,
        size.width * 0.86,
        size.height * 0.22,
      )
      ..lineTo(size.width * 0.86, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.67,
        centerX + unit * 0.035,
        size.height * 0.79,
      )
      ..close();
    canvas
      ..drawPath(leftPage, page)
      ..drawPath(rightPage, page);

    final Paint trace = Paint()
      ..color = (selected ? accent : foreground).withValues(
        alpha: selected ? 0.88 : 0.48,
      )
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = unit * 0.06;
    if (selected) {
      final Path journalTrace = Path()
        ..moveTo(size.width * 0.24, size.height * 0.55)
        ..lineTo(size.width * 0.37, size.height * 0.39)
        ..lineTo(size.width * 0.63, size.height * 0.48)
        ..lineTo(size.width * 0.76, size.height * 0.34);
      canvas.drawPath(journalTrace, trace);
    } else {
      canvas
        ..drawLine(
          Offset(size.width * 0.24, size.height * 0.55),
          Offset(size.width * 0.37, size.height * 0.39),
          trace,
        )
        ..drawLine(
          Offset(size.width * 0.63, size.height * 0.48),
          Offset(size.width * 0.76, size.height * 0.34),
          trace,
        );
    }

    final Paint node = Paint()
      ..color = selected ? accent : foreground.withValues(alpha: 0.68);
    for (final Offset position in <Offset>[
      Offset(size.width * 0.24, size.height * 0.55),
      Offset(size.width * 0.63, size.height * 0.48),
      Offset(size.width * 0.76, size.height * 0.34),
    ]) {
      canvas.drawCircle(position, unit * 0.055, node);
    }
  }

  @override
  bool shouldRepaint(covariant _ExpeditionNavigationGlyphPainter oldDelegate) {
    return oldDelegate.destination != destination ||
        oldDelegate.selected != selected ||
        oldDelegate.foreground != foreground ||
        oldDelegate.accent != accent;
  }
}
