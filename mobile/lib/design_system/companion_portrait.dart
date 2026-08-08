import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/design_system/character_cosmetics.dart';
import 'package:walking_rpg_mobile/design_system/companion_growth.dart';
import 'package:walking_rpg_mobile/design_system/illustrated_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum CompanionIdentity { spark, moss, rune, unknown }

class CompanionPortrait extends StatelessWidget {
  const CompanionPortrait({
    super.key,
    required this.petId,
    required this.name,
    required this.species,
    required this.evolutionStage,
    this.active = false,
    this.size = 72,
    this.equippedCosmeticIds = const <String>{},
  });

  final String petId;
  final String name;
  final String species;
  final int evolutionStage;
  final bool active;
  final double size;
  final Set<String> equippedCosmeticIds;

  CompanionIdentity get identity {
    return switch (petId) {
      'spark-v1' => CompanionIdentity.spark,
      'moss-v1' => CompanionIdentity.moss,
      'rune-v1' => CompanionIdentity.rune,
      _ => CompanionIdentity.unknown,
    };
  }

  String? get illustrationAsset {
    final int stage = safeEvolutionStage;
    return switch (identity) {
      CompanionIdentity.spark => switch (stage) {
        0 => 'assets/characters/companion_spark_stage0.webp',
        1 => 'assets/characters/companion_spark_stage1.webp',
        _ => 'assets/characters/companion_spark.webp',
      },
      CompanionIdentity.moss => switch (stage) {
        0 => 'assets/characters/companion_moss_stage0.webp',
        1 => 'assets/characters/companion_moss_stage1.webp',
        _ => 'assets/characters/companion_moss.webp',
      },
      CompanionIdentity.rune => switch (stage) {
        0 => 'assets/characters/companion_rune_stage0.webp',
        1 => 'assets/characters/companion_rune_stage1.webp',
        _ => 'assets/characters/companion_rune.webp',
      },
      CompanionIdentity.unknown => null,
    };
  }

  int get safeEvolutionStage {
    return CompanionGrowth.illustratedStage(evolutionStage);
  }

  bool get hasSparkHalo {
    return identity == CompanionIdentity.spark &&
        equippedCosmeticIds.contains(CharacterCosmeticIds.sparkHalo);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Color accent = switch (identity) {
      CompanionIdentity.spark => colors.primary,
      CompanionIdentity.moss => colors.secondary,
      CompanionIdentity.rune => palette.resonance,
      CompanionIdentity.unknown => colors.onSurfaceVariant,
    };
    final int safeStage = safeEvolutionStage;
    final String? assetPath = illustrationAsset;

    return Semantics(
      image: true,
      label: context.l10n.companionPortraitDescription(
        name: name,
        species: species,
        stage: evolutionStage,
        active: active,
        hasSparkHalo: hasSparkHalo,
      ),
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: assetPath == null
              ? CustomPaint(
                  isComplex: true,
                  painter: _CompanionPortraitPainter(
                    identity: identity,
                    stage: safeStage,
                    active: active,
                    accent: accent,
                    foreground: colors.onSurface,
                    surface: colors.surfaceContainerHigh,
                    border: palette.panelBorder,
                    shadow: palette.shadow,
                  ),
                )
              : ExpeditionIllustratedPortrait(
                  assetPath: assetPath,
                  imageKey: Key(
                    'companion-illustration-$petId-stage-$safeStage',
                  ),
                  size: size,
                  accent: accent,
                  border: palette.panelBorder,
                  shadow: palette.shadow,
                  highlighted: active,
                  stage: safeStage,
                  haloColor: hasSparkHalo ? palette.energy : null,
                ),
        ),
      ),
    );
  }
}

class _CompanionPortraitPainter extends CustomPainter {
  const _CompanionPortraitPainter({
    required this.identity,
    required this.stage,
    required this.active,
    required this.accent,
    required this.foreground,
    required this.surface,
    required this.border,
    required this.shadow,
  });

  final CompanionIdentity identity;
  final int stage;
  final bool active;
  final Color accent;
  final Color foreground;
  final Color surface;
  final Color border;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final double scale = size.shortestSide / 100;
    canvas
      ..save()
      ..translate(
        (size.width - size.shortestSide) / 2,
        (size.height - size.shortestSide) / 2,
      )
      ..scale(scale);

    const Rect frameRect = Rect.fromLTWH(3, 3, 94, 94);
    final RRect frame = RRect.fromRectAndRadius(
      frameRect,
      const Radius.circular(29),
    );
    canvas.drawRRect(
      frame.shift(const Offset(0, 3)),
      Paint()
        ..color = shadow.withValues(alpha: 0.48)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.28, -0.4),
          radius: 1.18,
          colors: <Color>[
            accent.withValues(alpha: 0.27),
            surface.withValues(alpha: 0.98),
          ],
        ).createShader(frameRect),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = (active ? accent : border).withValues(
          alpha: active ? 0.86 : 0.72,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2.2 : 1.25,
    );

    _drawField(canvas);
    switch (identity) {
      case CompanionIdentity.spark:
        _drawSpark(canvas);
        break;
      case CompanionIdentity.moss:
        _drawMoss(canvas);
        break;
      case CompanionIdentity.rune:
        _drawRune(canvas);
        break;
      case CompanionIdentity.unknown:
        _drawUnknown(canvas);
        break;
    }
    _drawActiveMarker(canvas);
    canvas.restore();
  }

  void _drawField(Canvas canvas) {
    final Paint field = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(const Offset(50, 51), 34, field);
    if (stage > 0) {
      canvas.drawArc(
        const Rect.fromLTWH(11, 12, 78, 78),
        -math.pi * 0.72,
        math.pi * 1.18,
        false,
        field..strokeWidth = 1.6,
      );
    }
    if (stage > 1) {
      canvas.drawArc(
        const Rect.fromLTWH(7, 8, 86, 86),
        math.pi * 0.18,
        math.pi * 1.1,
        false,
        field..strokeWidth = 1.15,
      );
    }
    final Paint signal = Paint()..color = accent.withValues(alpha: 0.58);
    for (final Offset point in <Offset>[
      const Offset(20, 29),
      const Offset(82, 42),
      const Offset(27, 80),
    ]) {
      canvas.drawCircle(point, 1.7, signal);
    }
  }

  void _drawSpark(Canvas canvas) {
    final Paint glow = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(50, 53), 26, glow);

    final Paint tail = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;
    final Path tailPath = Path()
      ..moveTo(67, 66)
      ..cubicTo(87, 70, 80, 48, 69, 48);
    canvas.drawPath(tailPath, tail);

    final Paint body = Paint()..color = accent.withValues(alpha: 0.9);
    final Path silhouette = Path()
      ..moveTo(31, 43)
      ..lineTo(28, 22)
      ..lineTo(43, 31)
      ..quadraticBezierTo(50, 27, 57, 31)
      ..lineTo(72, 22)
      ..lineTo(69, 44)
      ..quadraticBezierTo(75, 54, 69, 68)
      ..quadraticBezierTo(61, 80, 50, 80)
      ..quadraticBezierTo(39, 80, 31, 68)
      ..quadraticBezierTo(25, 54, 31, 43)
      ..close();
    canvas.drawPath(silhouette, body);

    final Paint face = Paint()..color = surface.withValues(alpha: 0.92);
    canvas.drawOval(const Rect.fromLTWH(35, 47, 30, 24), face);
    final Paint eye = Paint()..color = foreground.withValues(alpha: 0.88);
    canvas
      ..drawCircle(const Offset(43, 56), 2, eye)
      ..drawCircle(const Offset(57, 56), 2, eye);
    final Path spark = Path()
      ..moveTo(50, 59)
      ..lineTo(53, 64)
      ..lineTo(50, 69)
      ..lineTo(47, 64)
      ..close();
    canvas.drawPath(spark, Paint()..color = foreground.withValues(alpha: 0.8));

    if (stage > 0) {
      final Paint crown = Paint()
        ..color = foreground.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(const Offset(43, 28), const Offset(39, 18), crown)
        ..drawLine(const Offset(50, 26), const Offset(50, 14), crown)
        ..drawLine(const Offset(57, 28), const Offset(62, 18), crown);
    }
  }

  void _drawMoss(Canvas canvas) {
    final Paint body = Paint()..color = accent.withValues(alpha: 0.88);
    canvas.drawOval(const Rect.fromLTWH(20, 39, 60, 40), body);
    canvas.drawCircle(const Offset(50, 37), 19, body);
    for (final Offset foot in <Offset>[
      const Offset(31, 76),
      const Offset(69, 76),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: foot, width: 17, height: 8),
        body,
      );
    }

    final Paint shell = Paint()
      ..color = surface.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas
      ..drawArc(
        const Rect.fromLTWH(27, 46, 46, 27),
        math.pi,
        math.pi,
        false,
        shell,
      )
      ..drawLine(const Offset(36, 48), const Offset(42, 72), shell)
      ..drawLine(const Offset(64, 48), const Offset(58, 72), shell);

    final Paint eye = Paint()..color = foreground.withValues(alpha: 0.86);
    canvas
      ..drawCircle(const Offset(43, 38), 2.1, eye)
      ..drawCircle(const Offset(57, 38), 2.1, eye);

    final Paint stem = Paint()
      ..color = foreground.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stage > 0 ? 2.4 : 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 19), Offset(50, stage > 0 ? 6 : 10), stem);
    final Paint leaf = Paint()..color = accent.withValues(alpha: 0.98);
    canvas
      ..drawOval(const Rect.fromLTWH(38, 8, 13, 8), leaf)
      ..drawOval(const Rect.fromLTWH(50, 6, 14, 9), leaf);
    if (stage > 0) {
      canvas
        ..drawOval(const Rect.fromLTWH(31, 13, 14, 9), leaf)
        ..drawOval(const Rect.fromLTWH(59, 12, 13, 8), leaf);
    }
  }

  void _drawRune(Canvas canvas) {
    final Paint wave = Paint()
      ..color = accent.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(
        const Rect.fromLTWH(17, 31, 24, 42),
        math.pi * 0.55,
        math.pi * 0.9,
        false,
        wave,
      )
      ..drawArc(
        const Rect.fromLTWH(59, 31, 24, 42),
        -math.pi * 0.45,
        math.pi * 0.9,
        false,
        wave,
      );

    final Paint body = Paint()..color = accent.withValues(alpha: 0.88);
    final Path silhouette = Path()
      ..moveTo(50, 19)
      ..lineTo(71, 39)
      ..lineTo(66, 70)
      ..lineTo(50, 82)
      ..lineTo(34, 70)
      ..lineTo(29, 39)
      ..close();
    canvas.drawPath(silhouette, body);
    canvas.drawCircle(
      const Offset(50, 48),
      16,
      Paint()..color = surface.withValues(alpha: 0.72),
    );

    final Paint eye = Paint()..color = foreground.withValues(alpha: 0.9);
    canvas
      ..drawCircle(const Offset(44, 47), 2.4, eye)
      ..drawCircle(const Offset(56, 47), 2.4, eye);
    final Path rune = Path()
      ..moveTo(50, 53)
      ..lineTo(56, 60)
      ..lineTo(50, 69)
      ..lineTo(44, 60)
      ..close();
    canvas.drawPath(
      rune,
      Paint()
        ..color = foreground.withValues(alpha: 0.76)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (stage > 0) {
      final Paint orbit = Paint()
        ..color = foreground.withValues(alpha: 0.64)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
        const Rect.fromLTWH(20, 15, 60, 70),
        -math.pi * 0.28,
        math.pi * 1.55,
        false,
        orbit,
      );
    }
  }

  void _drawUnknown(Canvas canvas) {
    final Paint outline = Paint()
      ..color = accent.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(50, 50), 23, outline);
    canvas.drawPath(
      Path()
        ..moveTo(50, 28)
        ..lineTo(66, 68)
        ..lineTo(34, 68)
        ..close(),
      outline,
    );
  }

  void _drawActiveMarker(Canvas canvas) {
    if (!active) {
      return;
    }
    canvas.drawCircle(
      const Offset(82, 18),
      7,
      Paint()..color = surface.withValues(alpha: 0.95),
    );
    canvas.drawCircle(const Offset(82, 18), 4.2, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _CompanionPortraitPainter oldDelegate) {
    return oldDelegate.identity != identity ||
        oldDelegate.stage != stage ||
        oldDelegate.active != active ||
        oldDelegate.accent != accent ||
        oldDelegate.foreground != foreground ||
        oldDelegate.surface != surface ||
        oldDelegate.border != border ||
        oldDelegate.shadow != shadow;
  }
}
