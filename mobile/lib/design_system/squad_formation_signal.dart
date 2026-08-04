import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

/// Visual compression rules for the server-authored squad member count.
///
/// The exact count always remains visible as text in the owning card. The
/// painter caps only decorative nodes so a future larger squad cannot make the
/// formation unreadable or imply a client-side membership limit.
abstract final class SquadFormationLayout {
  static const int maximumVisibleMembers = 6;

  static int visibleMemberCountFor(int memberCount) {
    return memberCount.clamp(0, maximumVisibleMembers).toInt();
  }

  static bool hasOverflow(int memberCount) {
    return memberCount > maximumVisibleMembers;
  }
}

/// Decorative formation signal for the accepted server-owned squad state.
///
/// Member identities and roles are deliberately not encoded. The surrounding
/// card remains the accessible source for the squad name, exact member count
/// and identifier.
class SquadFormationSignal extends StatelessWidget {
  const SquadFormationSignal({
    super.key,
    required this.connected,
    required this.memberCount,
    this.size = 112,
  });

  final bool connected;
  final int memberCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final int visibleMembers = SquadFormationLayout.visibleMemberCountFor(
      memberCount,
    );
    final bool hasOverflow = SquadFormationLayout.hasOverflow(memberCount);

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          key: Key(
            'squad-formation-signal-'
            '${connected ? 'connected' : 'open'}-$visibleMembers'
            '${hasOverflow ? '-overflow' : ''}',
          ),
          dimension: size,
          child: CustomPaint(
            painter: _SquadFormationSignalPainter(
              connected: connected,
              visibleMembers: visibleMembers,
              hasOverflow: hasOverflow,
              accent: palette.resonance,
              lumen: colors.primary,
              surface: colors.surfaceContainerHigh,
              route: palette.routeLine,
              outline: colors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SquadFormationSignalPainter extends CustomPainter {
  const _SquadFormationSignalPainter({
    required this.connected,
    required this.visibleMembers,
    required this.hasOverflow,
    required this.accent,
    required this.lumen,
    required this.surface,
    required this.route,
    required this.outline,
  });

  final bool connected;
  final int visibleMembers;
  final bool hasOverflow;
  final Color accent;
  final Color lumen;
  final Color surface;
  final Color route;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double unit = size.shortestSide;
    final Offset center = size.center(Offset.zero);
    final RRect frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(unit * 0.025),
      Radius.circular(unit * 0.27),
    );
    final Paint frameFill = Paint()
      ..color = Color.alphaBlend(
        accent.withValues(alpha: connected ? 0.14 : 0.07),
        surface.withValues(alpha: 0.96),
      );
    final Paint frameLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.022
      ..color = (connected ? accent : outline).withValues(alpha: 0.62);
    canvas.drawRRect(frame, frameFill);
    canvas.drawRRect(frame, frameLine);

    final Rect orbitRect = Rect.fromCenter(
      center: center,
      width: unit * 0.68,
      height: unit * 0.68,
    );
    final Paint orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.022
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        route,
        accent,
        connected ? 0.5 : 0.2,
      )!.withValues(alpha: connected ? 0.62 : 0.34);
    canvas.drawArc(orbitRect, math.pi * 0.12, math.pi * 0.66, false, orbit);
    canvas.drawArc(orbitRect, math.pi * 1.02, math.pi * 0.73, false, orbit);

    final List<Offset> memberNodes = connected
        ? _memberPositions(size, visibleMembers)
        : _openChannelPositions(size);
    final Paint link = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.018
      ..strokeCap = StrokeCap.round
      ..color = (connected ? accent : route).withValues(
        alpha: connected ? 0.52 : 0.28,
      );
    for (final Offset member in memberNodes) {
      canvas.drawLine(center, member, link);
    }

    _paintHub(canvas, center, unit);
    for (final Offset member in memberNodes) {
      _paintMember(canvas, member, unit, active: connected);
    }
    if (hasOverflow) {
      _paintOverflow(canvas, size, unit);
    }
  }

  void _paintHub(Canvas canvas, Offset center, double unit) {
    final Paint halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.024
      ..color = (connected ? lumen : outline).withValues(alpha: 0.68);
    final Paint fill = Paint()
      ..color = Color.alphaBlend(
        (connected ? lumen : outline).withValues(alpha: 0.22),
        surface,
      );
    canvas.drawCircle(center, unit * 0.13, fill);
    canvas.drawCircle(center, unit * 0.13, halo);

    final Path beacon = Path()
      ..moveTo(center.dx, center.dy - unit * 0.075)
      ..lineTo(center.dx + unit * 0.075, center.dy)
      ..lineTo(center.dx, center.dy + unit * 0.075)
      ..lineTo(center.dx - unit * 0.075, center.dy)
      ..close();
    canvas.drawPath(
      beacon,
      Paint()..color = (connected ? lumen : outline).withValues(alpha: 0.94),
    );
  }

  void _paintMember(
    Canvas canvas,
    Offset center,
    double unit, {
    required bool active,
  }) {
    final Color nodeColor = active ? accent : outline;
    final Paint nodeFill = Paint()
      ..color = Color.alphaBlend(
        nodeColor.withValues(alpha: active ? 0.24 : 0.08),
        surface,
      );
    final Paint nodeLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.022
      ..color = nodeColor.withValues(alpha: active ? 0.88 : 0.5);
    canvas.drawCircle(center, unit * 0.075, nodeFill);
    canvas.drawCircle(center, unit * 0.075, nodeLine);
    if (active) {
      canvas.drawCircle(
        center,
        unit * 0.028,
        Paint()..color = accent.withValues(alpha: 0.96),
      );
    }
  }

  void _paintOverflow(Canvas canvas, Size size, double unit) {
    final Paint signal = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.018
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.72);
    final Offset source = Offset(size.width * 0.79, size.height * 0.27);
    for (final double radius in <double>[0.06, 0.11]) {
      canvas.drawArc(
        Rect.fromCircle(center: source, radius: unit * radius),
        -math.pi * 0.45,
        math.pi * 0.72,
        false,
        signal,
      );
    }
  }

  List<Offset> _memberPositions(Size size, int count) {
    final List<List<Offset>> normalized = <List<Offset>>[
      const <Offset>[],
      const <Offset>[Offset(0.5, 0.2)],
      const <Offset>[Offset(0.27, 0.35), Offset(0.73, 0.35)],
      const <Offset>[Offset(0.5, 0.2), Offset(0.24, 0.7), Offset(0.76, 0.7)],
      const <Offset>[
        Offset(0.28, 0.28),
        Offset(0.72, 0.28),
        Offset(0.72, 0.72),
        Offset(0.28, 0.72),
      ],
      const <Offset>[
        Offset(0.5, 0.19),
        Offset(0.76, 0.38),
        Offset(0.67, 0.75),
        Offset(0.33, 0.75),
        Offset(0.24, 0.38),
      ],
      const <Offset>[
        Offset(0.5, 0.18),
        Offset(0.76, 0.36),
        Offset(0.73, 0.69),
        Offset(0.5, 0.82),
        Offset(0.27, 0.69),
        Offset(0.24, 0.36),
      ],
    ];
    return normalized[count]
        .map(
          (Offset point) =>
              Offset(size.width * point.dx, size.height * point.dy),
        )
        .toList(growable: false);
  }

  List<Offset> _openChannelPositions(Size size) {
    return const <Offset>[
          Offset(0.5, 0.2),
          Offset(0.24, 0.7),
          Offset(0.76, 0.7),
        ]
        .map(
          (Offset point) =>
              Offset(size.width * point.dx, size.height * point.dy),
        )
        .toList(growable: false);
  }

  @override
  bool shouldRepaint(covariant _SquadFormationSignalPainter oldDelegate) {
    return oldDelegate.connected != connected ||
        oldDelegate.visibleMembers != visibleMembers ||
        oldDelegate.hasOverflow != hasOverflow ||
        oldDelegate.accent != accent ||
        oldDelegate.lumen != lumen ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route ||
        oldDelegate.outline != outline;
  }
}
