import 'dart:math' as math;

import 'package:flutter/material.dart';

class ExpeditionIllustratedPortrait extends StatelessWidget {
  const ExpeditionIllustratedPortrait({
    super.key,
    required this.assetPath,
    required this.imageKey,
    required this.size,
    required this.accent,
    required this.border,
    required this.shadow,
    this.highlighted = false,
    this.stage = 0,
    this.haloColor,
  });

  final String assetPath;
  final Key imageKey;
  final double size;
  final Color accent;
  final Color border;
  final Color shadow;
  final bool highlighted;
  final int stage;
  final Color? haloColor;

  @override
  Widget build(BuildContext context) {
    final double radius = size * 0.29;
    final double inset = math.max(2.0, size * 0.035);
    final int safeStage = stage < 0
        ? 0
        : stage > 2
        ? 2
        : stage;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: (highlighted ? accent : border).withValues(
              alpha: highlighted ? 0.9 : 0.76,
            ),
            width: highlighted ? 2.2 : 1.25,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: shadow.withValues(alpha: 0.48),
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(math.max(0.0, radius - inset)),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.asset(
                  assetPath,
                  key: imageKey,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _PortraitSignalPainter(
                      accent: accent,
                      highlighted: highlighted,
                      stage: safeStage,
                      haloColor: haloColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortraitSignalPainter extends CustomPainter {
  const _PortraitSignalPainter({
    required this.accent,
    required this.highlighted,
    required this.stage,
    required this.haloColor,
  });

  final Color accent;
  final bool highlighted;
  final int stage;
  final Color? haloColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Paint signal = Paint()
      ..color = accent.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.shortestSide * 0.018)
      ..strokeCap = StrokeCap.round;
    final Rect orbit = Rect.fromLTWH(
      size.width * 0.07,
      size.height * 0.07,
      size.width * 0.86,
      size.height * 0.86,
    );
    final Color? halo = haloColor;
    if (halo != null) {
      final Rect haloBounds = Rect.fromCenter(
        center: Offset(size.width * 0.52, size.height * 0.2),
        width: size.width * 0.62,
        height: size.height * 0.19,
      );
      canvas
        ..drawOval(
          haloBounds,
          Paint()
            ..color = halo.withValues(alpha: 0.46)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.0, size.shortestSide * 0.047)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.max(2.0, size.shortestSide * 0.055),
            ),
        )
        ..drawArc(
          haloBounds,
          -math.pi * 0.92,
          math.pi * 1.84,
          false,
          Paint()
            ..color = halo.withValues(alpha: 0.92)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.1, size.shortestSide * 0.018)
            ..strokeCap = StrokeCap.round,
        );
    }
    if (stage > 0) {
      canvas.drawArc(orbit, -math.pi * 0.82, math.pi * 0.72, false, signal);
    }
    if (stage > 1) {
      canvas.drawArc(orbit, math.pi * 0.18, math.pi * 0.52, false, signal);
    }
    if (!highlighted) {
      return;
    }
    final Offset marker = Offset(size.width * 0.82, size.height * 0.18);
    canvas
      ..drawCircle(
        marker,
        size.shortestSide * 0.075,
        Paint()..color = const Color(0xF20B2028),
      )
      ..drawCircle(marker, size.shortestSide * 0.043, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _PortraitSignalPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.highlighted != highlighted ||
        oldDelegate.stage != stage ||
        oldDelegate.haloColor != haloColor;
  }
}
