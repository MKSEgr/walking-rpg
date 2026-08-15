import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum ExpeditionNodeSignalKind {
  outerBeacon,
  lumenGate,
  ashOrbit,
  glassMarsh,
  silentQuarry,
  copperRavine,
  ionGarden,
  frostAntenna,
  obsidianCrossing,
  pulseFoundry,
  mirrorDelta,
  stormArchive,
  emberStation,
  auroraBridge,
  voidOrchard,
  starWell,
  horizonSpire,
  dawnRelay,
  resonancePocket,
  spectrumObservatory,
  unknown,
}

enum ExpeditionNodeSignalTone { lumen, energy, resonance, neutral }

enum ExpeditionNodeSignalRole { current, next }

/// Presentation identities for the current server-authored chapter nodes.
///
/// Only an exact stable node ID selects a known landmark. The accepted display
/// name is deliberately ignored so future content cannot borrow an unrelated
/// identity by reusing familiar copy.
abstract final class ExpeditionNodeSignalCatalog {
  static ExpeditionNodeSignalKind kindFor(String nodeId) {
    return switch (nodeId) {
      'outer-beacon' => ExpeditionNodeSignalKind.outerBeacon,
      'lumen-gate' => ExpeditionNodeSignalKind.lumenGate,
      'ash-orbit' => ExpeditionNodeSignalKind.ashOrbit,
      'glass-marsh' => ExpeditionNodeSignalKind.glassMarsh,
      'silent-quarry' => ExpeditionNodeSignalKind.silentQuarry,
      'copper-ravine' => ExpeditionNodeSignalKind.copperRavine,
      'ion-garden' => ExpeditionNodeSignalKind.ionGarden,
      'frost-antenna' => ExpeditionNodeSignalKind.frostAntenna,
      'obsidian-crossing' => ExpeditionNodeSignalKind.obsidianCrossing,
      'pulse-foundry' => ExpeditionNodeSignalKind.pulseFoundry,
      'mirror-delta' => ExpeditionNodeSignalKind.mirrorDelta,
      'storm-archive' => ExpeditionNodeSignalKind.stormArchive,
      'ember-station' => ExpeditionNodeSignalKind.emberStation,
      'aurora-bridge' => ExpeditionNodeSignalKind.auroraBridge,
      'void-orchard' => ExpeditionNodeSignalKind.voidOrchard,
      'star-well' => ExpeditionNodeSignalKind.starWell,
      'horizon-spire' => ExpeditionNodeSignalKind.horizonSpire,
      'dawn-relay' => ExpeditionNodeSignalKind.dawnRelay,
      'resonance-pocket' => ExpeditionNodeSignalKind.resonancePocket,
      'spectrum-observatory' => ExpeditionNodeSignalKind.spectrumObservatory,
      _ => ExpeditionNodeSignalKind.unknown,
    };
  }

  static ExpeditionNodeSignalTone toneFor(String nodeId) {
    return switch (nodeId) {
      'ash-orbit' ||
      'silent-quarry' ||
      'copper-ravine' ||
      'pulse-foundry' ||
      'ember-station' ||
      'dawn-relay' => ExpeditionNodeSignalTone.energy,
      'glass-marsh' ||
      'frost-antenna' ||
      'mirror-delta' ||
      'storm-archive' ||
      'void-orchard' ||
      'resonance-pocket' => ExpeditionNodeSignalTone.resonance,
      'outer-beacon' ||
      'lumen-gate' ||
      'ion-garden' ||
      'obsidian-crossing' ||
      'aurora-bridge' ||
      'star-well' ||
      'horizon-spire' => ExpeditionNodeSignalTone.lumen,
      'spectrum-observatory' => ExpeditionNodeSignalTone.lumen,
      _ => ExpeditionNodeSignalTone.neutral,
    };
  }
}

/// A code-native landmark for exactly one accepted expedition node.
///
/// This component does not render route order, adjacent nodes or availability.
/// It pairs one exact node identity with the complete server-provided name;
/// [role] distinguishes accepted current state from an explicit next-node
/// handoff, while [completed] presents accepted current expedition status only.
class ExpeditionNodeSignal extends StatelessWidget {
  const ExpeditionNodeSignal({
    super.key,
    required this.nodeId,
    required this.nodeName,
    required this.completed,
    this.role = ExpeditionNodeSignalRole.current,
    this.markSize = 42,
  }) : assert(role == ExpeditionNodeSignalRole.current || !completed);

  final String nodeId;
  final String nodeName;
  final bool completed;
  final ExpeditionNodeSignalRole role;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final ExpeditionNodeSignalKind kind = ExpeditionNodeSignalCatalog.kindFor(
      nodeId,
    );
    final ExpeditionNodeSignalTone tone = ExpeditionNodeSignalCatalog.toneFor(
      nodeId,
    );
    final Color accent = switch (tone) {
      ExpeditionNodeSignalTone.lumen => colors.primary,
      ExpeditionNodeSignalTone.energy => palette.energy,
      ExpeditionNodeSignalTone.resonance => palette.resonance,
      ExpeditionNodeSignalTone.neutral => colors.onSurfaceVariant,
    };
    final bool next = role == ExpeditionNodeSignalRole.next;
    final String semanticLabel = next
        ? context.l10n.expeditionNextNodeSemantics(nodeName)
        : context.l10n.expeditionCurrentNodeSemantics(
            nodeName,
            completed ? context.l10n.expeditionCompletedSemanticSuffix : '',
          );

    return Semantics(
      key: Key(
        next
            ? 'expedition-next-node-signal-$nodeId-${kind.name}'
            : 'expedition-node-signal-$nodeId-${kind.name}',
      ),
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 11, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RepaintBoundary(
                  child: SizedBox.square(
                    key: Key(
                      next
                          ? 'expedition-next-node-mark-$nodeId-${kind.name}'
                          : 'expedition-node-mark-$nodeId-${kind.name}',
                    ),
                    dimension: markSize,
                    child: CustomPaint(
                      painter: _ExpeditionNodeSignalPainter(
                        kind: kind,
                        accent: accent,
                        surface: colors.surfaceContainerHigh,
                        route: palette.routeLine,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    nodeName.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                if (next) ...<Widget>[
                  const SizedBox(width: 7),
                  Icon(Icons.arrow_forward, size: 16, color: accent),
                ] else if (completed) ...<Widget>[
                  const SizedBox(width: 7),
                  Icon(Icons.flag_outlined, size: 16, color: accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpeditionNodeSignalPainter extends CustomPainter {
  const _ExpeditionNodeSignalPainter({
    required this.kind,
    required this.accent,
    required this.surface,
    required this.route,
  });

  final ExpeditionNodeSignalKind kind;
  final Color accent;
  final Color surface;
  final Color route;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double unit = size.shortestSide;
    final Rect bounds = Offset.zero & size;
    final Offset center = bounds.center;
    final RRect frame = RRect.fromRectAndRadius(
      bounds.deflate(unit * 0.035),
      Radius.circular(unit * 0.28),
    );
    final Paint frameFill = Paint()
      ..color = Color.alphaBlend(
        accent.withValues(alpha: 0.13),
        surface.withValues(alpha: 0.96),
      );
    final Paint frameLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.025
      ..color = accent.withValues(alpha: 0.58);
    canvas.drawRRect(frame, frameFill);
    canvas.drawRRect(frame, frameLine);

    final Paint field = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.018
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(route, accent, 0.3)!.withValues(alpha: 0.42);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.35),
      math.pi * 0.1,
      math.pi * 0.48,
      false,
      field,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.35),
      math.pi * 1.08,
      math.pi * 0.42,
      false,
      field,
    );

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.052
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: 0.96);
    final Paint fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.028
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: 0.76);
    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: 0.94);

    switch (kind) {
      case ExpeditionNodeSignalKind.outerBeacon:
        _paintOuterBeacon(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.lumenGate:
        _paintLumenGate(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.ashOrbit:
        _paintAshOrbit(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.glassMarsh:
        _paintGlassMarsh(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.silentQuarry:
        _paintSilentQuarry(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.copperRavine:
        _paintCopperRavine(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.ionGarden:
        _paintIonGarden(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.frostAntenna:
        _paintFrostAntenna(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.obsidianCrossing:
        _paintObsidianCrossing(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.pulseFoundry:
        _paintPulseFoundry(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.mirrorDelta:
        _paintMirrorDelta(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.stormArchive:
        _paintStormArchive(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.emberStation:
        _paintEmberStation(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.auroraBridge:
        _paintAuroraBridge(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.voidOrchard:
        _paintVoidOrchard(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.starWell:
        _paintStarWell(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.horizonSpire:
        _paintHorizonSpire(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.dawnRelay:
        _paintDawnRelay(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.resonancePocket:
        _paintResonancePocket(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.spectrumObservatory:
        _paintSpectrumObservatory(canvas, size, stroke, fine, fill);
      case ExpeditionNodeSignalKind.unknown:
        _paintUnknown(canvas, size, fine, fill);
    }
  }

  void _paintOuterBeacon(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset top = _at(size, 0.5, 0.27);
    canvas.drawLine(_at(size, 0.5, 0.38), _at(size, 0.5, 0.73), stroke);
    canvas.drawLine(_at(size, 0.37, 0.73), _at(size, 0.63, 0.73), fine);
    canvas.drawCircle(top, size.shortestSide * 0.065, fill);
    canvas.drawArc(_circle(top, size, 0.16), -0.7, 1.4, false, fine);
    canvas.drawArc(_circle(top, size, 0.25), -0.58, 1.16, false, fine);
  }

  void _paintLumenGate(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path gate = Path()
      ..moveTo(size.width * 0.3, size.height * 0.72)
      ..lineTo(size.width * 0.3, size.height * 0.45)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.2,
        size.width * 0.7,
        size.height * 0.45,
      )
      ..lineTo(size.width * 0.7, size.height * 0.72);
    canvas.drawPath(gate, stroke);
    canvas.drawLine(_at(size, 0.22, 0.72), _at(size, 0.78, 0.72), fine);
    canvas.drawCircle(_at(size, 0.5, 0.48), size.shortestSide * 0.052, fill);
  }

  void _paintAshOrbit(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset center = _at(size, 0.5, 0.5);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.28);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.58,
        height: size.height * 0.28,
      ),
      fine,
    );
    canvas.restore();
    canvas.drawCircle(center, size.shortestSide * 0.085, stroke);
    _dot(canvas, _at(size, 0.7, 0.37), size, 0.045, fill);
    _dot(canvas, _at(size, 0.29, 0.61), size, 0.032, fill);
    _dot(canvas, _at(size, 0.65, 0.68), size, 0.026, fill);
  }

  void _paintGlassMarsh(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path upper = Path()
      ..moveTo(size.width * 0.22, size.height * 0.44)
      ..lineTo(size.width * 0.38, size.height * 0.27)
      ..lineTo(size.width * 0.51, size.height * 0.45)
      ..lineTo(size.width * 0.68, size.height * 0.29)
      ..lineTo(size.width * 0.78, size.height * 0.43);
    final Path lower = Path()
      ..moveTo(size.width * 0.22, size.height * 0.56)
      ..lineTo(size.width * 0.38, size.height * 0.73)
      ..lineTo(size.width * 0.51, size.height * 0.55)
      ..lineTo(size.width * 0.68, size.height * 0.71)
      ..lineTo(size.width * 0.78, size.height * 0.57);
    canvas.drawPath(upper, stroke);
    canvas.drawPath(lower, fine);
    canvas.drawCircle(_at(size, 0.5, 0.5), size.shortestSide * 0.035, fill);
  }

  void _paintSilentQuarry(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path steps = Path()
      ..moveTo(size.width * 0.24, size.height * 0.31)
      ..lineTo(size.width * 0.48, size.height * 0.31)
      ..lineTo(size.width * 0.48, size.height * 0.47)
      ..lineTo(size.width * 0.65, size.height * 0.47)
      ..lineTo(size.width * 0.65, size.height * 0.64)
      ..lineTo(size.width * 0.78, size.height * 0.64);
    canvas.drawPath(steps, stroke);
    canvas.drawArc(
      Rect.fromCenter(
        center: _at(size, 0.45, 0.55),
        width: size.width * 0.44,
        height: size.height * 0.34,
      ),
      0.18,
      math.pi * 0.78,
      false,
      fine,
    );
    _dot(canvas, _at(size, 0.75, 0.64), size, 0.045, fill);
  }

  void _paintCopperRavine(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path left = Path()
      ..moveTo(size.width * 0.31, size.height * 0.25)
      ..lineTo(size.width * 0.41, size.height * 0.42)
      ..lineTo(size.width * 0.34, size.height * 0.58)
      ..lineTo(size.width * 0.43, size.height * 0.76);
    final Path right = Path()
      ..moveTo(size.width * 0.68, size.height * 0.25)
      ..lineTo(size.width * 0.57, size.height * 0.43)
      ..lineTo(size.width * 0.65, size.height * 0.57)
      ..lineTo(size.width * 0.56, size.height * 0.76);
    canvas.drawPath(left, stroke);
    canvas.drawPath(right, stroke);
    canvas.drawLine(_at(size, 0.39, 0.5), _at(size, 0.61, 0.5), fine);
    canvas.drawCircle(_at(size, 0.5, 0.5), size.shortestSide * 0.04, fill);
  }

  void _paintIonGarden(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    canvas.drawLine(_at(size, 0.5, 0.72), _at(size, 0.5, 0.35), stroke);
    final Path leftLeaf = Path()
      ..moveTo(size.width * 0.5, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.29,
        size.height * 0.48,
        size.width * 0.3,
        size.height * 0.33,
      )
      ..quadraticBezierTo(
        size.width * 0.47,
        size.height * 0.36,
        size.width * 0.5,
        size.height * 0.55,
      );
    final Path rightLeaf = Path()
      ..moveTo(size.width * 0.5, size.height * 0.48)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.41,
        size.width * 0.72,
        size.height * 0.27,
      )
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.3,
        size.width * 0.5,
        size.height * 0.48,
      );
    canvas.drawPath(leftLeaf, fine);
    canvas.drawPath(rightLeaf, fine);
    _dot(canvas, _at(size, 0.5, 0.28), size, 0.055, fill);
    _dot(canvas, _at(size, 0.27, 0.28), size, 0.025, fill);
  }

  void _paintFrostAntenna(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset center = _at(size, 0.5, 0.45);
    canvas.drawLine(_at(size, 0.5, 0.3), _at(size, 0.5, 0.73), stroke);
    canvas.drawLine(_at(size, 0.32, 0.45), _at(size, 0.68, 0.45), fine);
    canvas.drawLine(_at(size, 0.37, 0.32), _at(size, 0.63, 0.58), fine);
    canvas.drawLine(_at(size, 0.63, 0.32), _at(size, 0.37, 0.58), fine);
    canvas.drawCircle(center, size.shortestSide * 0.05, fill);
    canvas.drawArc(
      _circle(_at(size, 0.5, 0.31), size, 0.16),
      3.7,
      1.72,
      false,
      fine,
    );
  }

  void _paintObsidianCrossing(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path bridge = Path()
      ..moveTo(size.width * 0.22, size.height * 0.62)
      ..lineTo(size.width * 0.35, size.height * 0.42)
      ..lineTo(size.width * 0.49, size.height * 0.55)
      ..lineTo(size.width * 0.63, size.height * 0.36)
      ..lineTo(size.width * 0.78, size.height * 0.58);
    canvas.drawPath(bridge, stroke);
    canvas.drawLine(_at(size, 0.23, 0.69), _at(size, 0.77, 0.69), fine);
    _dot(canvas, _at(size, 0.22, 0.62), size, 0.045, fill);
    _dot(canvas, _at(size, 0.78, 0.58), size, 0.045, fill);
  }

  void _paintPulseFoundry(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path hex = Path()
      ..moveTo(size.width * 0.5, size.height * 0.22)
      ..lineTo(size.width * 0.72, size.height * 0.35)
      ..lineTo(size.width * 0.72, size.height * 0.64)
      ..lineTo(size.width * 0.5, size.height * 0.77)
      ..lineTo(size.width * 0.28, size.height * 0.64)
      ..lineTo(size.width * 0.28, size.height * 0.35)
      ..close();
    canvas.drawPath(hex, fine);
    final Path pulse = Path()
      ..moveTo(size.width * 0.31, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.52)
      ..lineTo(size.width * 0.49, size.height * 0.37)
      ..lineTo(size.width * 0.57, size.height * 0.62)
      ..lineTo(size.width * 0.65, size.height * 0.48)
      ..lineTo(size.width * 0.7, size.height * 0.48);
    canvas.drawPath(pulse, stroke);
    _dot(canvas, _at(size, 0.5, 0.22), size, 0.032, fill);
  }

  void _paintMirrorDelta(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path fork = Path()
      ..moveTo(size.width * 0.5, size.height * 0.75)
      ..lineTo(size.width * 0.5, size.height * 0.52)
      ..lineTo(size.width * 0.3, size.height * 0.28)
      ..moveTo(size.width * 0.5, size.height * 0.52)
      ..lineTo(size.width * 0.7, size.height * 0.28);
    canvas.drawPath(fork, stroke);
    canvas.drawLine(_at(size, 0.3, 0.68), _at(size, 0.7, 0.68), fine);
    _dot(canvas, _at(size, 0.3, 0.28), size, 0.05, fill);
    _dot(canvas, _at(size, 0.7, 0.28), size, 0.05, fill);
  }

  void _paintStormArchive(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final RRect archive = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        size.width * 0.25,
        size.height * 0.29,
        size.width * 0.75,
        size.height * 0.71,
      ),
      Radius.circular(size.shortestSide * 0.07),
    );
    canvas.drawRRect(archive, fine);
    canvas.drawLine(_at(size, 0.34, 0.42), _at(size, 0.66, 0.42), fine);
    canvas.drawLine(_at(size, 0.34, 0.58), _at(size, 0.66, 0.58), fine);
    final Path bolt = Path()
      ..moveTo(size.width * 0.55, size.height * 0.22)
      ..lineTo(size.width * 0.42, size.height * 0.48)
      ..lineTo(size.width * 0.55, size.height * 0.48)
      ..lineTo(size.width * 0.45, size.height * 0.76);
    canvas.drawPath(bolt, stroke);
    _dot(canvas, _at(size, 0.55, 0.22), size, 0.025, fill);
  }

  void _paintEmberStation(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset center = _at(size, 0.5, 0.5);
    canvas.drawCircle(center, size.shortestSide * 0.14, stroke);
    canvas.drawArc(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.52,
        height: size.height * 0.4,
      ),
      0.1,
      math.pi * 0.9,
      false,
      fine,
    );
    canvas.drawLine(_at(size, 0.3, 0.72), _at(size, 0.7, 0.72), fine);
    _dot(canvas, center, size, 0.055, fill);
    _dot(canvas, _at(size, 0.31, 0.37), size, 0.025, fill);
    _dot(canvas, _at(size, 0.69, 0.37), size, 0.025, fill);
  }

  void _paintAuroraBridge(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Rect arch = Rect.fromLTRB(
      size.width * 0.2,
      size.height * 0.3,
      size.width * 0.8,
      size.height * 0.78,
    );
    canvas.drawArc(arch, math.pi, math.pi, false, stroke);
    canvas.drawArc(
      arch.deflate(size.shortestSide * 0.1),
      math.pi,
      math.pi,
      false,
      fine,
    );
    canvas.drawLine(_at(size, 0.2, 0.55), _at(size, 0.8, 0.55), fine);
    _dot(canvas, _at(size, 0.2, 0.55), size, 0.04, fill);
    _dot(canvas, _at(size, 0.8, 0.55), size, 0.04, fill);
    _dot(canvas, _at(size, 0.5, 0.31), size, 0.035, fill);
  }

  void _paintVoidOrchard(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path branches = Path()
      ..moveTo(size.width * 0.5, size.height * 0.75)
      ..lineTo(size.width * 0.5, size.height * 0.42)
      ..lineTo(size.width * 0.32, size.height * 0.29)
      ..moveTo(size.width * 0.5, size.height * 0.51)
      ..lineTo(size.width * 0.68, size.height * 0.32)
      ..moveTo(size.width * 0.5, size.height * 0.62)
      ..lineTo(size.width * 0.7, size.height * 0.56);
    canvas.drawPath(branches, stroke);
    canvas.drawCircle(_at(size, 0.3, 0.27), size.shortestSide * 0.07, fine);
    canvas.drawCircle(_at(size, 0.7, 0.29), size.shortestSide * 0.065, fine);
    canvas.drawCircle(_at(size, 0.73, 0.55), size.shortestSide * 0.055, fine);
    _dot(canvas, _at(size, 0.5, 0.75), size, 0.03, fill);
  }

  void _paintStarWell(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset center = _at(size, 0.5, 0.58);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.5,
        height: size.height * 0.25,
      ),
      stroke,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.28,
        height: size.height * 0.13,
      ),
      fine,
    );
    canvas.drawLine(_at(size, 0.5, 0.25), _at(size, 0.5, 0.41), fine);
    canvas.drawLine(_at(size, 0.42, 0.33), _at(size, 0.58, 0.33), fine);
    _dot(canvas, _at(size, 0.5, 0.33), size, 0.04, fill);
  }

  void _paintHorizonSpire(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path spire = Path()
      ..moveTo(size.width * 0.35, size.height * 0.73)
      ..lineTo(size.width * 0.5, size.height * 0.22)
      ..lineTo(size.width * 0.65, size.height * 0.73);
    canvas.drawPath(spire, stroke);
    canvas.drawLine(_at(size, 0.2, 0.72), _at(size, 0.8, 0.72), fine);
    canvas.drawLine(_at(size, 0.4, 0.55), _at(size, 0.6, 0.55), fine);
    _dot(canvas, _at(size, 0.5, 0.22), size, 0.04, fill);
  }

  void _paintDawnRelay(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    canvas.drawArc(
      Rect.fromLTRB(
        size.width * 0.24,
        size.height * 0.35,
        size.width * 0.76,
        size.height * 0.82,
      ),
      math.pi,
      math.pi,
      false,
      stroke,
    );
    canvas.drawLine(_at(size, 0.2, 0.66), _at(size, 0.8, 0.66), fine);
    canvas.drawLine(_at(size, 0.5, 0.66), _at(size, 0.5, 0.28), stroke);
    canvas.drawArc(
      _circle(_at(size, 0.5, 0.27), size, 0.17),
      -0.65,
      1.3,
      false,
      fine,
    );
    _dot(canvas, _at(size, 0.5, 0.27), size, 0.045, fill);
  }

  void _paintResonancePocket(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset center = _at(size, 0.5, 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.58,
        height: size.height * 0.46,
      ),
      stroke,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: _at(size, 0.54, 0.48),
        width: size.width * 0.34,
        height: size.height * 0.26,
      ),
      fine,
    );
    canvas.drawArc(_circle(center, size, 0.22), 0.5, 3.8, false, fine);
    _dot(canvas, _at(size, 0.6, 0.45), size, 0.05, fill);
  }

  void _paintUnknown(Canvas canvas, Size size, Paint fine, Paint fill) {
    const List<Offset> points = <Offset>[
      Offset(0.3, 0.62),
      Offset(0.43, 0.35),
      Offset(0.63, 0.45),
      Offset(0.7, 0.68),
    ];
    final Path constellation = Path()
      ..moveTo(size.width * points.first.dx, size.height * points.first.dy);
    for (final Offset point in points.skip(1)) {
      constellation.lineTo(size.width * point.dx, size.height * point.dy);
    }
    canvas.drawPath(constellation, fine);
    for (int index = 0; index < points.length; index++) {
      _dot(
        canvas,
        _at(size, points[index].dx, points[index].dy),
        size,
        index == 1 ? 0.052 : 0.035,
        fill,
      );
    }
  }

  void _paintSpectrumObservatory(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset center = _at(size, 0.5, 0.48);
    final Path prism = Path()
      ..moveTo(size.width * 0.5, size.height * 0.2)
      ..lineTo(size.width * 0.72, size.height * 0.67)
      ..lineTo(size.width * 0.28, size.height * 0.67)
      ..close();
    canvas.drawPath(prism, stroke);
    canvas.drawArc(_circle(center, size, 0.52), 0.18, 2.78, false, fine);
    canvas.drawLine(_at(size, 0.2, 0.75), _at(size, 0.8, 0.75), fine);
    _dot(canvas, center, size, 0.045, fill);
  }

  Offset _at(Size size, double x, double y) {
    return Offset(size.width * x, size.height * y);
  }

  Rect _circle(Offset center, Size size, double diameter) {
    return Rect.fromCircle(
      center: center,
      radius: size.shortestSide * diameter / 2,
    );
  }

  void _dot(
    Canvas canvas,
    Offset center,
    Size size,
    double radius,
    Paint fill,
  ) {
    canvas.drawCircle(center, size.shortestSide * radius, fill);
  }

  @override
  bool shouldRepaint(_ExpeditionNodeSignalPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.accent != accent ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route;
  }
}
