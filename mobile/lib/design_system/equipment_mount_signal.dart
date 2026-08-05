import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum EquipmentMountSignalKind { navigation, unknown }

enum EquipmentMountItemKind { empty, resonanceCompass, unknown }

enum EquipmentMountSignalState {
  navigationEmpty,
  resonanceCompassMounted,
  neutral,
}

/// Presentation identities for server-authored equipment slots and items.
///
/// Only exact stable IDs select a known mount or instrument. Player-facing
/// names and descriptions are deliberately ignored so future content cannot
/// inherit an unrelated equipment identity.
abstract final class EquipmentMountSignalCatalog {
  static EquipmentMountSignalKind kindFor(String slotId) {
    return switch (slotId) {
      'NAVIGATION' => EquipmentMountSignalKind.navigation,
      _ => EquipmentMountSignalKind.unknown,
    };
  }

  static EquipmentMountItemKind itemKindFor(String? itemId) {
    return switch (itemId) {
      null => EquipmentMountItemKind.empty,
      'resonance-compass' => EquipmentMountItemKind.resonanceCompass,
      _ => EquipmentMountItemKind.unknown,
    };
  }

  static EquipmentMountSignalState stateFor({
    required String slotId,
    required String status,
    required String? itemId,
  }) {
    return switch ((slotId, status, itemId)) {
      ('NAVIGATION', 'EMPTY', null) =>
        EquipmentMountSignalState.navigationEmpty,
      ('NAVIGATION', 'EQUIPPED', 'resonance-compass') =>
        EquipmentMountSignalState.resonanceCompassMounted,
      _ => EquipmentMountSignalState.neutral,
    };
  }
}

/// Code-native field mount for one accepted equipment slot.
///
/// The frame reads its state only from the server-provided slot status and item
/// ID. It owns no equipment action or route availability and stays decorative
/// beside the complete slot and item copy.
class EquipmentMountSignal extends StatelessWidget {
  const EquipmentMountSignal({
    super.key,
    required this.slotId,
    required this.status,
    required this.itemId,
    this.height = 112,
  }) : assert(height > 0);

  final String slotId;
  final String status;
  final String? itemId;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final EquipmentMountSignalKind kind = EquipmentMountSignalCatalog.kindFor(
      slotId,
    );
    final EquipmentMountItemKind itemKind =
        EquipmentMountSignalCatalog.itemKindFor(itemId);
    final EquipmentMountSignalState state =
        EquipmentMountSignalCatalog.stateFor(
          slotId: slotId,
          status: status,
          itemId: itemId,
        );

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          key: Key(
            'equipment-mount-signal-$slotId-${kind.name}-'
            '${itemKind.name}-$status',
          ),
          width: double.infinity,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height * 0.2),
            child: CustomPaint(
              painter: _EquipmentMountSignalPainter(
                kind: kind,
                itemKind: itemKind,
                state: state,
                mounted: status == 'EQUIPPED',
                lumen: colors.primary,
                energy: palette.energy,
                resonance: palette.resonance,
                surface: colors.surfaceContainerHigh,
                foreground: colors.onSurfaceVariant,
                outline: colors.outlineVariant,
                route: palette.routeLine,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EquipmentMountSignalPainter extends CustomPainter {
  const _EquipmentMountSignalPainter({
    required this.kind,
    required this.itemKind,
    required this.state,
    required this.mounted,
    required this.lumen,
    required this.energy,
    required this.resonance,
    required this.surface,
    required this.foreground,
    required this.outline,
    required this.route,
  });

  final EquipmentMountSignalKind kind;
  final EquipmentMountItemKind itemKind;
  final EquipmentMountSignalState state;
  final bool mounted;
  final Color lumen;
  final Color energy;
  final Color resonance;
  final Color surface;
  final Color foreground;
  final Color outline;
  final Color route;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double unit = size.height;
    final Offset center = Offset(size.width * 0.5, size.height * 0.5);
    final double radius = math.min(unit * 0.31, size.width * 0.16);
    final Color identityAccent = kind == EquipmentMountSignalKind.navigation
        ? resonance
        : foreground;
    final Color stateAccent = switch (state) {
      EquipmentMountSignalState.navigationEmpty => identityAccent,
      EquipmentMountSignalState.resonanceCompassMounted => energy,
      EquipmentMountSignalState.neutral => foreground,
    };
    final RRect frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(unit * 0.025),
      Radius.circular(unit * 0.2),
    );

    canvas.drawRRect(
      frame,
      Paint()
        ..color = Color.alphaBlend(
          identityAccent.withValues(alpha: 0.08),
          surface.withValues(alpha: 0.98),
        ),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.016
        ..color = stateAccent.withValues(alpha: mounted ? 0.72 : 0.42),
    );

    switch (kind) {
      case EquipmentMountSignalKind.navigation:
        _paintNavigationField(canvas, size, center, radius, stateAccent);
      case EquipmentMountSignalKind.unknown:
        _paintUnknownField(canvas, size, center, radius, stateAccent);
    }
    _paintMount(canvas, center, radius, stateAccent);
  }

  void _paintNavigationField(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    Color stateAccent,
  ) {
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.017
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(route, outline, 0.34)!.withValues(alpha: 0.68);
    final Paint active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.026
      ..strokeCap = StrokeCap.round
      ..color = stateAccent.withValues(alpha: 0.82);
    final Path upper = Path()
      ..moveTo(size.width * 0.07, size.height * 0.7)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.7,
        center.dx - radius * 1.55,
        center.dy - radius * 0.8,
        center.dx - radius,
        center.dy - radius * 0.2,
      );
    final Path lower = Path()
      ..moveTo(center.dx + radius, center.dy + radius * 0.2)
      ..cubicTo(
        center.dx + radius * 1.55,
        center.dy + radius * 0.8,
        size.width * 0.76,
        size.height * 0.3,
        size.width * 0.93,
        size.height * 0.3,
      );
    canvas
      ..drawPath(upper, base)
      ..drawPath(lower, base);
    if (mounted) {
      canvas
        ..drawPath(upper, active)
        ..drawPath(lower, active);
    }
    _paintRouteNode(
      canvas,
      Offset(size.width * 0.07, size.height * 0.7),
      size.height,
      mounted ? stateAccent : route,
    );
    _paintRouteNode(
      canvas,
      Offset(size.width * 0.93, size.height * 0.3),
      size.height,
      mounted ? stateAccent : route,
    );
  }

  void _paintUnknownField(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    Color stateAccent,
  ) {
    final List<Offset> points = <Offset>[
      Offset(size.width * 0.12, size.height * 0.64),
      Offset(center.dx - radius * 1.35, size.height * 0.28),
      Offset(center.dx + radius * 1.42, size.height * 0.7),
      Offset(size.width * 0.88, size.height * 0.36),
    ];
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.014
      ..color = stateAccent.withValues(alpha: 0.42);
    final Path constellation = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      constellation.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(constellation, line);
    for (final Offset point in points) {
      _paintRouteNode(canvas, point, size.height, stateAccent);
    }
  }

  void _paintMount(
    Canvas canvas,
    Offset center,
    double radius,
    Color stateAccent,
  ) {
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.09
      ..color = stateAccent.withValues(alpha: mounted ? 0.9 : 0.56);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Color.alphaBlend(
          stateAccent.withValues(alpha: mounted ? 0.18 : 0.06),
          surface,
        ),
    );
    canvas
      ..drawCircle(center, radius, ring)
      ..drawCircle(center, radius * 0.72, ring);

    switch (itemKind) {
      case EquipmentMountItemKind.empty:
        _paintEmptyMount(canvas, center, radius, stateAccent);
      case EquipmentMountItemKind.resonanceCompass:
        _paintResonanceCompass(canvas, center, radius, stateAccent);
      case EquipmentMountItemKind.unknown:
        _paintUnknownItem(canvas, center, radius, stateAccent);
    }
  }

  void _paintEmptyMount(
    Canvas canvas,
    Offset center,
    double radius,
    Color stateAccent,
  ) {
    final Paint bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1
      ..strokeCap = StrokeCap.round
      ..color = stateAccent.withValues(alpha: 0.54);
    for (int index = 0; index < 4; index++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.5),
        index * math.pi / 2 + math.pi * 0.12,
        math.pi * 0.25,
        false,
        bracket,
      );
    }
  }

  void _paintResonanceCompass(
    Canvas canvas,
    Offset center,
    double radius,
    Color stateAccent,
  ) {
    final Path needle = Path()
      ..moveTo(center.dx, center.dy - radius * 0.52)
      ..lineTo(center.dx + radius * 0.23, center.dy + radius * 0.1)
      ..lineTo(center.dx, center.dy + radius * 0.42)
      ..lineTo(center.dx - radius * 0.23, center.dy + radius * 0.1)
      ..close();
    canvas.drawPath(
      needle,
      Paint()..color = stateAccent.withValues(alpha: mounted ? 0.98 : 0.62),
    );
    canvas.drawCircle(center, radius * 0.11, Paint()..color = lumen);
  }

  void _paintUnknownItem(
    Canvas canvas,
    Offset center,
    double radius,
    Color stateAccent,
  ) {
    final List<Offset> points = <Offset>[
      center + Offset(-radius * 0.34, radius * 0.25),
      center + Offset(0, -radius * 0.38),
      center + Offset(radius * 0.36, radius * 0.22),
    ];
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.08
      ..color = stateAccent.withValues(alpha: 0.64);
    canvas
      ..drawLine(points[0], points[1], line)
      ..drawLine(points[1], points[2], line);
    for (final Offset point in points) {
      canvas.drawCircle(
        point,
        radius * 0.1,
        Paint()..color = stateAccent.withValues(alpha: 0.78),
      );
    }
  }

  void _paintRouteNode(Canvas canvas, Offset center, double unit, Color color) {
    canvas.drawCircle(
      center,
      unit * 0.04,
      Paint()..color = Color.alphaBlend(color.withValues(alpha: 0.22), surface),
    );
    canvas.drawCircle(
      center,
      unit * 0.04,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.014
        ..color = color.withValues(alpha: 0.76),
    );
  }

  @override
  bool shouldRepaint(covariant _EquipmentMountSignalPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.itemKind != itemKind ||
        oldDelegate.state != state ||
        oldDelegate.mounted != mounted ||
        oldDelegate.lumen != lumen ||
        oldDelegate.energy != energy ||
        oldDelegate.resonance != resonance ||
        oldDelegate.surface != surface ||
        oldDelegate.foreground != foreground ||
        oldDelegate.outline != outline ||
        oldDelegate.route != route;
  }
}
