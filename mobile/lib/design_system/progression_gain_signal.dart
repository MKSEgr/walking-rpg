import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum ProgressionGainKind { pilotExperience, petBond }

enum ProgressionGainIdentity { navigator, spark, moss, rune, unknown }

enum ProgressionGainTone { lumen, energy, resonance, neutral }

/// Presentation identities for accepted event progression rewards.
///
/// Only an exact reward channel and server-owned subject ID select a known
/// mark. Player-facing names and reward amounts deliberately do not take part
/// in dispatch, so future pilots and pets keep a neutral identity.
abstract final class ProgressionGainSignalCatalog {
  static ProgressionGainIdentity identityFor({
    required ProgressionGainKind kind,
    required String subjectId,
  }) {
    if (kind == ProgressionGainKind.pilotExperience &&
        subjectId == 'navigator-v1') {
      return ProgressionGainIdentity.navigator;
    }
    if (kind == ProgressionGainKind.petBond) {
      return switch (subjectId) {
        'spark-v1' => ProgressionGainIdentity.spark,
        'moss-v1' => ProgressionGainIdentity.moss,
        'rune-v1' => ProgressionGainIdentity.rune,
        _ => ProgressionGainIdentity.unknown,
      };
    }
    return ProgressionGainIdentity.unknown;
  }

  static ProgressionGainTone toneFor({
    required ProgressionGainKind kind,
    required String subjectId,
  }) {
    return switch (identityFor(kind: kind, subjectId: subjectId)) {
      ProgressionGainIdentity.navigator ||
      ProgressionGainIdentity.moss => ProgressionGainTone.lumen,
      ProgressionGainIdentity.spark => ProgressionGainTone.energy,
      ProgressionGainIdentity.rune => ProgressionGainTone.resonance,
      ProgressionGainIdentity.unknown => ProgressionGainTone.neutral,
    };
  }
}

/// Decorative signal for one accepted pilot-XP or companion-bond gain.
///
/// The complete server-provided subject name, gained amount and resulting
/// total remain in the surrounding copy. This mark never derives progression,
/// level changes or reward availability.
class ProgressionGainSignal extends StatelessWidget {
  const ProgressionGainSignal({
    super.key,
    required this.kind,
    required this.subjectId,
    this.size = 44,
  }) : assert(size > 0);

  final ProgressionGainKind kind;
  final String subjectId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final ProgressionGainIdentity identity =
        ProgressionGainSignalCatalog.identityFor(
          kind: kind,
          subjectId: subjectId,
        );
    final ProgressionGainTone tone = ProgressionGainSignalCatalog.toneFor(
      kind: kind,
      subjectId: subjectId,
    );
    final Color accent = switch (tone) {
      ProgressionGainTone.lumen => colors.primary,
      ProgressionGainTone.energy => palette.energy,
      ProgressionGainTone.resonance => palette.resonance,
      ProgressionGainTone.neutral => colors.onSurfaceVariant,
    };

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          key: Key(
            'progression-gain-signal-${kind.name}-$subjectId-'
            '${identity.name}',
          ),
          dimension: size,
          child: CustomPaint(
            painter: _ProgressionGainSignalPainter(
              identity: identity,
              accent: accent,
              surface: colors.surfaceContainerHigh,
              route: palette.routeLine,
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the decorative gain mark beside the complete server-owned reward copy.
class ProgressionGainSignalLayout extends StatelessWidget {
  const ProgressionGainSignalLayout({
    super.key,
    required this.kind,
    required this.subjectId,
    required this.child,
    this.signalSize = 44,
  }) : assert(signalSize > 0);

  final ProgressionGainKind kind;
  final String subjectId;
  final Widget child;
  final double signalSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 260;
        final Widget signal = ProgressionGainSignal(
          kind: kind,
          subjectId: subjectId,
          size: signalSize,
        );
        return KeyedSubtree(
          key: Key(
            'progression-gain-layout-${kind.name}-$subjectId-'
            '${compact ? 'compact' : 'wide'}',
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[signal, const SizedBox(height: 8), child],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    signal,
                    const SizedBox(width: 9),
                    Expanded(child: child),
                  ],
                ),
        );
      },
    );
  }
}

class _ProgressionGainSignalPainter extends CustomPainter {
  const _ProgressionGainSignalPainter({
    required this.identity,
    required this.accent,
    required this.surface,
    required this.route,
  });

  final ProgressionGainIdentity identity;
  final Color accent;
  final Color surface;
  final Color route;

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

    const Rect frameBounds = Rect.fromLTWH(3, 3, 94, 94);
    final RRect frame = RRect.fromRectAndRadius(
      frameBounds,
      const Radius.circular(27),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.42),
          radius: 1.2,
          colors: <Color>[
            accent.withValues(alpha: 0.2),
            surface.withValues(alpha: 0.98),
          ],
        ).createShader(frameBounds),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = accent.withValues(alpha: 0.64)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final Paint field = Paint()
      ..color = route.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas
      ..drawArc(
        const Rect.fromLTWH(15, 15, 70, 70),
        -math.pi * 0.82,
        math.pi * 1.08,
        false,
        field,
      )
      ..drawCircle(
        const Offset(25, 29),
        2,
        Paint()..color = route.withValues(alpha: 0.62),
      )
      ..drawCircle(
        const Offset(34, 80),
        1.7,
        Paint()..color = route.withValues(alpha: 0.5),
      );

    switch (identity) {
      case ProgressionGainIdentity.navigator:
        _drawNavigator(canvas);
        break;
      case ProgressionGainIdentity.spark:
        _drawSpark(canvas);
        break;
      case ProgressionGainIdentity.moss:
        _drawMoss(canvas);
        break;
      case ProgressionGainIdentity.rune:
        _drawRune(canvas);
        break;
      case ProgressionGainIdentity.unknown:
        _drawUnknown(canvas);
        break;
    }
    _drawGainPulse(canvas);
    canvas.restore();
  }

  Paint get _line => Paint()
    ..color = accent
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 4;

  void _drawNavigator(Canvas canvas) {
    final Path routePath = Path()
      ..moveTo(23, 68)
      ..quadraticBezierTo(35, 62, 42, 48)
      ..lineTo(59, 57)
      ..lineTo(70, 39);
    canvas.drawPath(routePath, _line);
    final Paint point = Paint()..color = accent;
    for (final Offset position in const <Offset>[
      Offset(23, 68),
      Offset(42, 48),
      Offset(59, 57),
    ]) {
      canvas.drawCircle(position, 3.5, point);
    }
    final Path pointer = Path()
      ..moveTo(70, 29)
      ..lineTo(77, 43)
      ..lineTo(70, 39)
      ..lineTo(63, 43)
      ..close();
    canvas.drawPath(pointer, point);
  }

  void _drawSpark(Canvas canvas) {
    final Path bolt = Path()
      ..moveTo(54, 22)
      ..lineTo(32, 54)
      ..lineTo(47, 52)
      ..lineTo(40, 78)
      ..lineTo(68, 42)
      ..lineTo(52, 45)
      ..close();
    canvas.drawPath(bolt, Paint()..color = accent.withValues(alpha: 0.78));
    canvas.drawPath(bolt, _line..strokeWidth = 2.6);
  }

  void _drawMoss(Canvas canvas) {
    final Paint line = _line;
    canvas
      ..drawLine(const Offset(50, 72), const Offset(50, 39), line)
      ..drawArc(
        const Rect.fromLTWH(27, 32, 24, 20),
        math.pi * 0.05,
        math.pi * 0.9,
        false,
        line,
      )
      ..drawArc(
        const Rect.fromLTWH(49, 27, 25, 22),
        math.pi * 0.15,
        math.pi * 0.9,
        false,
        line,
      )
      ..drawCircle(
        const Offset(50, 72),
        11,
        Paint()
          ..color = accent.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill,
      )
      ..drawArc(
        const Rect.fromLTWH(39, 61, 22, 18),
        0,
        math.pi,
        false,
        line..strokeWidth = 3,
      );
  }

  void _drawRune(Canvas canvas) {
    final Path diamond = Path()
      ..moveTo(50, 24)
      ..lineTo(68, 49)
      ..lineTo(50, 74)
      ..lineTo(32, 49)
      ..close();
    canvas.drawPath(diamond, Paint()..color = accent.withValues(alpha: 0.16));
    canvas.drawPath(diamond, _line);
    canvas
      ..drawLine(const Offset(41, 49), const Offset(59, 49), _line)
      ..drawArc(
        const Rect.fromLTWH(24, 35, 52, 30),
        -math.pi * 0.42,
        math.pi * 0.84,
        false,
        _line..strokeWidth = 2.2,
      );
  }

  void _drawUnknown(Canvas canvas) {
    final Paint line = _line..strokeWidth = 2.6;
    final Paint point = Paint()..color = accent;
    const List<Offset> points = <Offset>[
      Offset(31, 64),
      Offset(47, 37),
      Offset(68, 58),
    ];
    canvas
      ..drawLine(points[0], points[1], line)
      ..drawLine(points[1], points[2], line);
    for (final Offset position in points) {
      canvas.drawCircle(position, 4, point);
    }
  }

  void _drawGainPulse(Canvas canvas) {
    final Paint pulse = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;
    final Path arrow = Path()
      ..moveTo(72, 78)
      ..lineTo(82, 68)
      ..lineTo(92, 78)
      ..moveTo(82, 68)
      ..lineTo(82, 88);
    canvas.drawPath(arrow, pulse);
  }

  @override
  bool shouldRepaint(covariant _ProgressionGainSignalPainter oldDelegate) {
    return oldDelegate.identity != identity ||
        oldDelegate.accent != accent ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route;
  }
}
