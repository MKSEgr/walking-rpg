import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

abstract final class ProfileCosmeticIds {
  static const String trailBanner = 'trail-banner';
  static const String dawnFrame = 'dawn-frame';
}

enum _ProfileCosmeticVariant { trailBanner, dawnFrame, unknown }

_ProfileCosmeticVariant _variantFor(String? cosmeticId) {
  return switch (cosmeticId) {
    ProfileCosmeticIds.trailBanner => _ProfileCosmeticVariant.trailBanner,
    ProfileCosmeticIds.dawnFrame => _ProfileCosmeticVariant.dawnFrame,
    _ => _ProfileCosmeticVariant.unknown,
  };
}

/// Applies presentation-only profile art selected by an exact server-owned ID.
///
/// The decoration never changes the accepted chapter, route or crew state.
/// Unknown future IDs preserve the unmodified child instead of borrowing a
/// visual treatment from player-facing copy.
class ProfileCosmeticFrame extends StatelessWidget {
  const ProfileCosmeticFrame({
    super.key,
    required this.cosmeticId,
    required this.child,
  });

  final String? cosmeticId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final _ProfileCosmeticVariant variant = _variantFor(cosmeticId);
    if (variant == _ProfileCosmeticVariant.unknown) {
      return Semantics(
        container: true,
        explicitChildNodes: true,
        child: KeyedSubtree(
          key: Key('profile-cosmetic-frame-fallback-${cosmeticId ?? 'none'}'),
          child: child,
        ),
      );
    }

    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: RepaintBoundary(
        key: Key('profile-cosmetic-frame-$cosmeticId'),
        child: CustomPaint(
          foregroundPainter: _ProfileCosmeticFramePainter(
            variant: variant,
            lumen: colors.primary,
            energy: palette.energy,
            resonance: palette.resonance,
            ink: palette.backdropTop,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Compact catalog preview for a server-owned PROFILE cosmetic.
///
/// The surrounding cosmetic card remains the accessible source for the name,
/// slot, ownership and action. Unknown IDs receive a neutral constellation.
class ProfileCosmeticPreview extends StatelessWidget {
  const ProfileCosmeticPreview({
    super.key,
    required this.cosmeticId,
    this.size = 52,
  }) : assert(size > 0);

  final String cosmeticId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final _ProfileCosmeticVariant variant = _variantFor(cosmeticId);

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.25),
              border: Border.all(
                color: palette.panelBorder.withValues(alpha: 0.78),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.25 - 1),
              child: CustomPaint(
                key: Key(
                  variant == _ProfileCosmeticVariant.unknown
                      ? 'profile-cosmetic-preview-fallback-$cosmeticId'
                      : 'profile-cosmetic-preview-$cosmeticId',
                ),
                painter: _ProfileCosmeticPreviewPainter(
                  variant: variant,
                  surface: colors.surfaceContainerHighest,
                  lumen: colors.primary,
                  energy: palette.energy,
                  resonance: palette.resonance,
                  foreground: colors.onSurfaceVariant,
                  ink: palette.backdropTop,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCosmeticFramePainter extends CustomPainter {
  const _ProfileCosmeticFramePainter({
    required this.variant,
    required this.lumen,
    required this.energy,
    required this.resonance,
    required this.ink,
  });

  final _ProfileCosmeticVariant variant;
  final Color lumen;
  final Color energy;
  final Color resonance;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final RRect clip = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(math.min(22.0, size.shortestSide / 2)),
    );
    canvas
      ..save()
      ..clipRRect(clip);
    switch (variant) {
      case _ProfileCosmeticVariant.trailBanner:
        _paintTrailBanner(canvas, size);
        break;
      case _ProfileCosmeticVariant.dawnFrame:
        _paintDawnFrame(canvas, size);
        break;
      case _ProfileCosmeticVariant.unknown:
        break;
    }
    canvas.restore();
  }

  void _paintTrailBanner(Canvas canvas, Size size) {
    final double bannerWidth = math.min(42.0, size.width * 0.15);
    final double bannerHeight = math.min(76.0, size.height * 0.42);
    final double left = math.max(10.0, size.width * 0.045);
    final Path banner = Path()
      ..moveTo(left, 0)
      ..lineTo(left + bannerWidth, 0)
      ..lineTo(left + bannerWidth, bannerHeight)
      ..lineTo(left + bannerWidth / 2, bannerHeight - bannerWidth * 0.28)
      ..lineTo(left, bannerHeight)
      ..close();
    final Rect bannerBounds = Rect.fromLTWH(left, 0, bannerWidth, bannerHeight);
    canvas.drawPath(
      banner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            ink.withValues(alpha: 0.94),
            resonance.withValues(alpha: 0.88),
          ],
        ).createShader(bannerBounds),
    );
    canvas.drawPath(
      banner,
      Paint()
        ..color = lumen.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final double routeX = left + bannerWidth / 2;
    final double routeTop = bannerHeight * 0.22;
    final double routeBottom = bannerHeight * 0.68;
    canvas.drawLine(
      Offset(routeX, routeTop),
      Offset(routeX, routeBottom),
      Paint()
        ..color = lumen.withValues(alpha: 0.82)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    for (final double fraction in <double>[0, 0.5, 1]) {
      canvas.drawCircle(
        Offset(routeX, routeTop + (routeBottom - routeTop) * fraction),
        fraction == 0.5 ? 3.2 : 2.4,
        Paint()..color = fraction == 0.5 ? energy : lumen,
      );
    }
  }

  void _paintDawnFrame(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final RRect frame = RRect.fromRectAndRadius(
      bounds.deflate(1.4),
      const Radius.circular(22),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: <Color>[
            resonance.withValues(alpha: 0.76),
            energy.withValues(alpha: 0.94),
            lumen.withValues(alpha: 0.72),
          ],
        ).createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );

    final Offset dawn = Offset(size.width * 0.82, size.height);
    final double radius = math.min(34.0, size.shortestSide * 0.2);
    canvas.drawCircle(
      dawn,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            energy.withValues(alpha: 0.42),
            energy.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: dawn, radius: radius)),
    );
    final Paint ray = Paint()
      ..color = energy.withValues(alpha: 0.74)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final Offset direction in <Offset>[
      const Offset(-1, -0.1),
      const Offset(-0.78, -0.58),
      const Offset(-0.32, -0.88),
    ]) {
      canvas.drawLine(
        dawn + direction * (radius * 0.52),
        dawn + direction * (radius * 0.86),
        ray,
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: dawn, radius: radius * 0.45),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = energy.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileCosmeticFramePainter oldDelegate) {
    return variant != oldDelegate.variant ||
        lumen != oldDelegate.lumen ||
        energy != oldDelegate.energy ||
        resonance != oldDelegate.resonance ||
        ink != oldDelegate.ink;
  }
}

class _ProfileCosmeticPreviewPainter extends CustomPainter {
  const _ProfileCosmeticPreviewPainter({
    required this.variant,
    required this.surface,
    required this.lumen,
    required this.energy,
    required this.resonance,
    required this.foreground,
    required this.ink,
  });

  final _ProfileCosmeticVariant variant;
  final Color surface;
  final Color lumen;
  final Color energy;
  final Color resonance;
  final Color foreground;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Rect bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[ink, Color.lerp(ink, surface, 0.72)!, surface],
        ).createShader(bounds),
    );
    switch (variant) {
      case _ProfileCosmeticVariant.trailBanner:
        _paintBannerPreview(canvas, size);
        break;
      case _ProfileCosmeticVariant.dawnFrame:
        _paintDawnPreview(canvas, size);
        break;
      case _ProfileCosmeticVariant.unknown:
        _paintFallbackPreview(canvas, size);
        break;
    }
  }

  void _paintBannerPreview(Canvas canvas, Size size) {
    final Path banner = Path()
      ..moveTo(size.width * 0.24, size.height * 0.1)
      ..lineTo(size.width * 0.76, size.height * 0.1)
      ..lineTo(size.width * 0.76, size.height * 0.86)
      ..lineTo(size.width * 0.5, size.height * 0.7)
      ..lineTo(size.width * 0.24, size.height * 0.86)
      ..close();
    canvas.drawPath(
      banner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[lumen, resonance],
        ).createShader(Offset.zero & size),
    );
    final Paint route = Paint()
      ..color = ink.withValues(alpha: 0.86)
      ..strokeWidth = math.max(1.2, size.width * 0.035)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.26),
      Offset(size.width * 0.5, size.height * 0.62),
      route,
    );
    for (final double y in <double>[0.26, 0.44, 0.62]) {
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * y),
        size.width * (y == 0.44 ? 0.07 : 0.05),
        Paint()..color = y == 0.44 ? energy : ink,
      );
    }
  }

  void _paintDawnPreview(Canvas canvas, Size size) {
    final Offset dawn = Offset(size.width * 0.5, size.height * 0.72);
    final double radius = size.shortestSide * 0.18;
    canvas.drawCircle(
      dawn,
      radius * 2.2,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            energy.withValues(alpha: 0.46),
            energy.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: dawn, radius: radius * 2.2)),
    );
    canvas.drawArc(
      Rect.fromCircle(center: dawn, radius: radius),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = energy
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, size.width * 0.045),
    );
    final Paint frame = Paint()
      ..shader = LinearGradient(
        colors: <Color>[resonance, energy, lumen],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, size.width * 0.045);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.12,
          size.height * 0.12,
          size.width * 0.76,
          size.height * 0.76,
        ),
        Radius.circular(size.width * 0.14),
      ),
      frame,
    );
  }

  void _paintFallbackPreview(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = foreground.withValues(alpha: 0.54)
      ..strokeWidth = math.max(1.0, size.width * 0.025);
    final List<Offset> points = <Offset>[
      Offset(size.width * 0.27, size.height * 0.64),
      Offset(size.width * 0.46, size.height * 0.34),
      Offset(size.width * 0.72, size.height * 0.58),
    ];
    canvas
      ..drawLine(points[0], points[1], line)
      ..drawLine(points[1], points[2], line);
    for (final Offset point in points) {
      canvas.drawCircle(
        point,
        size.width * 0.055,
        Paint()..color = foreground.withValues(alpha: 0.78),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileCosmeticPreviewPainter oldDelegate) {
    return variant != oldDelegate.variant ||
        surface != oldDelegate.surface ||
        lumen != oldDelegate.lumen ||
        energy != oldDelegate.energy ||
        resonance != oldDelegate.resonance ||
        foreground != oldDelegate.foreground ||
        ink != oldDelegate.ink;
  }
}
