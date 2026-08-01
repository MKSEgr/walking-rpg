import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum ExpeditionPanelTone { neutral, lumen, energy, resonance }

class ExpeditionBackdrop extends StatelessWidget {
  const ExpeditionBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                palette.backdropTop,
                Color.lerp(palette.backdropTop, colors.surfaceContainer, 0.48)!,
                palette.backdropBottom,
              ],
              stops: const <double>[0, 0.46, 1],
            ),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _ExpeditionBackdropPainter(
              routeColor: palette.routeLine,
              glowColor: colors.primary,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class ExpeditionPanel extends StatelessWidget {
  const ExpeditionPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.tone = ExpeditionPanelTone.neutral,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final ExpeditionPanelTone tone;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Color accent = switch (tone) {
      ExpeditionPanelTone.neutral => colors.primary,
      ExpeditionPanelTone.lumen => colors.primary,
      ExpeditionPanelTone.energy => palette.energy,
      ExpeditionPanelTone.resonance => palette.resonance,
    };
    final double accentOpacity = tone == ExpeditionPanelTone.neutral
        ? 0.035
        : 0.12;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: tone == ExpeditionPanelTone.neutral
              ? palette.panelBorder
              : accent.withValues(alpha: 0.52),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              accent.withValues(alpha: accentOpacity),
              colors.surfaceContainerHigh.withValues(alpha: 0.96),
            ),
            colors.surfaceContainer.withValues(alpha: 0.9),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class ExpeditionBadge extends StatelessWidget {
  const ExpeditionBadge({
    super.key,
    required this.label,
    required this.icon,
    this.tone = ExpeditionPanelTone.lumen,
  });

  final String label;
  final IconData icon;
  final ExpeditionPanelTone tone;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Color accent = switch (tone) {
      ExpeditionPanelTone.neutral => colors.onSurfaceVariant,
      ExpeditionPanelTone.lumen => colors.primary,
      ExpeditionPanelTone.energy => palette.energy,
      ExpeditionPanelTone.resonance => palette.resonance,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpeditionProgressRing extends StatelessWidget {
  const ExpeditionProgressRing({
    super.key,
    required this.progress,
    required this.value,
    required this.label,
    this.tone = ExpeditionPanelTone.lumen,
    this.size = 116,
  });

  final double progress;
  final String value;
  final String label;
  final ExpeditionPanelTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Color accent = switch (tone) {
      ExpeditionPanelTone.neutral => colors.onSurfaceVariant,
      ExpeditionPanelTone.lumen => colors.primary,
      ExpeditionPanelTone.energy => palette.energy,
      ExpeditionPanelTone.resonance => palette.resonance,
    };
    final double safeProgress = progress.clamp(0, 1).toDouble();

    return Semantics(
      label: '$label, $value',
      value: '${(safeProgress * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CircularProgressIndicator(
              value: safeProgress,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              color: accent,
              backgroundColor: colors.surfaceContainerHighest,
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.09),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      value,
                      maxLines: 1,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: accent),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpeditionSectionTitle extends StatelessWidget {
  const ExpeditionSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: colors.primary, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpeditionBackdropPainter extends CustomPainter {
  const _ExpeditionBackdropPainter({
    required this.routeColor,
    required this.glowColor,
  });

  final Color routeColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final Paint glow = Paint()
      ..shader =
          RadialGradient(
            colors: <Color>[
              glowColor.withValues(alpha: 0.13),
              glowColor.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.82, size.height * 0.12),
              radius: size.shortestSide * 0.58,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.12),
      size.shortestSide * 0.58,
      glow,
    );

    final Paint contour = Paint()
      ..color = routeColor.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Offset radarCenter = Offset(size.width * 0.94, size.height * 0.2);
    final double contourStep = math.max(38.0, size.shortestSide * 0.12);
    for (int index = 1; index <= 5; index += 1) {
      canvas.drawCircle(radarCenter, contourStep * index, contour);
    }

    final Paint route = Paint()
      ..color = routeColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final Path path = Path()
      ..moveTo(-18, size.height * 0.73)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.58,
        size.width * 0.26,
        size.height * 0.86,
        size.width * 0.52,
        size.height * 0.68,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.55,
        size.width * 0.82,
        size.height * 0.76,
        size.width + 20,
        size.height * 0.56,
      );
    canvas.drawPath(path, route);

    final Paint node = Paint()..color = routeColor.withValues(alpha: 0.34);
    for (final Offset point in <Offset>[
      Offset(size.width * 0.12, size.height * 0.68),
      Offset(size.width * 0.49, size.height * 0.69),
      Offset(size.width * 0.79, size.height * 0.65),
    ]) {
      canvas.drawCircle(point, 4.5, node);
      canvas.drawCircle(point, 9.5, contour);
    }
  }

  @override
  bool shouldRepaint(covariant _ExpeditionBackdropPainter oldDelegate) {
    return oldDelegate.routeColor != routeColor ||
        oldDelegate.glowColor != glowColor;
  }
}
