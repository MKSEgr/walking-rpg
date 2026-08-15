import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum EventChoiceSignalKind {
  frequency,
  companion,
  stabilize,
  echo,
  survey,
  resonance,
  chart,
  compass,
  prism,
  unknown,
}

enum EventChoiceSignalTone { lumen, energy, resonance, neutral }

/// Presentation vocabulary for accepted event choices.
///
/// A mark is selected only by an exact server-owned event/choice pair. This
/// prevents a familiar choice ID inside future content from borrowing an
/// identity that has not been reviewed for that event.
abstract final class EventChoiceSignalCatalog {
  static const Map<String, EventChoiceSignalKind>
  _knownKinds = <String, EventChoiceSignalKind>{
    'signal-source-v1::analyze-signal': EventChoiceSignalKind.frequency,
    'signal-source-v1::trust-spark': EventChoiceSignalKind.companion,
    'signal-source-v1::trust-companion': EventChoiceSignalKind.companion,
    'echo-vault-v1::stabilize-core': EventChoiceSignalKind.stabilize,
    'echo-vault-v1::follow-echo': EventChoiceSignalKind.echo,
    'ash-orbit-v1::survey-ash-orbit': EventChoiceSignalKind.survey,
    'ash-orbit-v1::trust-ash-orbit': EventChoiceSignalKind.companion,
    'glass-marsh-v1::survey-glass-marsh': EventChoiceSignalKind.survey,
    'glass-marsh-v1::trust-glass-marsh': EventChoiceSignalKind.companion,
    'silent-quarry-v1::survey-silent-quarry': EventChoiceSignalKind.survey,
    'silent-quarry-v1::trust-silent-quarry': EventChoiceSignalKind.companion,
    'copper-ravine-v1::survey-copper-ravine': EventChoiceSignalKind.survey,
    'copper-ravine-v1::trust-copper-ravine': EventChoiceSignalKind.companion,
    'ion-garden-v1::survey-ion-garden': EventChoiceSignalKind.survey,
    'ion-garden-v1::trust-ion-garden': EventChoiceSignalKind.companion,
    'frost-antenna-v1::survey-frost-antenna': EventChoiceSignalKind.survey,
    'frost-antenna-v1::trust-frost-antenna': EventChoiceSignalKind.companion,
    'obsidian-crossing-v1::survey-obsidian-crossing':
        EventChoiceSignalKind.survey,
    'obsidian-crossing-v1::trust-obsidian-crossing':
        EventChoiceSignalKind.companion,
    'pulse-foundry-v1::survey-pulse-foundry': EventChoiceSignalKind.survey,
    'pulse-foundry-v1::trust-pulse-foundry': EventChoiceSignalKind.companion,
    'mirror-delta-v1::survey-mirror-delta': EventChoiceSignalKind.survey,
    'mirror-delta-v1::trust-mirror-delta': EventChoiceSignalKind.companion,
    'mirror-delta-v1::follow-resonance': EventChoiceSignalKind.resonance,
    'storm-archive-v1::survey-storm-archive': EventChoiceSignalKind.survey,
    'storm-archive-v1::trust-storm-archive': EventChoiceSignalKind.companion,
    'ember-station-v1::survey-ember-station': EventChoiceSignalKind.survey,
    'ember-station-v1::trust-ember-station': EventChoiceSignalKind.companion,
    'aurora-bridge-v1::survey-aurora-bridge': EventChoiceSignalKind.survey,
    'aurora-bridge-v1::trust-aurora-bridge': EventChoiceSignalKind.companion,
    'void-orchard-v1::survey-void-orchard': EventChoiceSignalKind.survey,
    'void-orchard-v1::trust-void-orchard': EventChoiceSignalKind.companion,
    'star-well-v1::survey-star-well': EventChoiceSignalKind.survey,
    'star-well-v1::trust-star-well': EventChoiceSignalKind.companion,
    'star-well-v1::align-prism-sextant': EventChoiceSignalKind.prism,
    'horizon-spire-v1::survey-horizon-spire': EventChoiceSignalKind.survey,
    'horizon-spire-v1::trust-horizon-spire': EventChoiceSignalKind.companion,
    'dawn-relay-v1::survey-dawn-relay': EventChoiceSignalKind.survey,
    'dawn-relay-v1::trust-dawn-relay': EventChoiceSignalKind.companion,
    'resonance-pocket-v1::map-hidden-current': EventChoiceSignalKind.chart,
    'resonance-pocket-v1::follow-compass-pulse': EventChoiceSignalKind.compass,
    'spectrum-observatory-v1::chart-invisible-constellation':
        EventChoiceSignalKind.chart,
    'spectrum-observatory-v1::chase-dawn-refraction':
        EventChoiceSignalKind.prism,
    'spectrum-observatory-v1::trace-second-dawn': EventChoiceSignalKind.prism,
    'dawn-relay-v1::open-second-dawn': EventChoiceSignalKind.prism,
    'second-dawn-threshold-v1::anchor-second-dawn': EventChoiceSignalKind.chart,
    'second-dawn-threshold-v1::leap-beyond-dawn':
        EventChoiceSignalKind.companion,
  };

  static EventChoiceSignalKind kindFor({
    required String eventId,
    required String choiceId,
  }) {
    return _knownKinds['$eventId::$choiceId'] ?? EventChoiceSignalKind.unknown;
  }

  static EventChoiceSignalTone toneFor({
    required String eventId,
    required String choiceId,
  }) {
    return switch (kindFor(eventId: eventId, choiceId: choiceId)) {
      EventChoiceSignalKind.frequency ||
      EventChoiceSignalKind.stabilize ||
      EventChoiceSignalKind.survey => EventChoiceSignalTone.lumen,
      EventChoiceSignalKind.companion => EventChoiceSignalTone.energy,
      EventChoiceSignalKind.echo ||
      EventChoiceSignalKind.resonance ||
      EventChoiceSignalKind.chart ||
      EventChoiceSignalKind.compass => EventChoiceSignalTone.resonance,
      EventChoiceSignalKind.prism => EventChoiceSignalTone.lumen,
      EventChoiceSignalKind.unknown => EventChoiceSignalTone.neutral,
    };
  }
}

/// Decorative mark for one accepted event choice.
///
/// [muted] changes contrast only. It does not decide whether the owning action
/// is enabled, locked or selected, and the complete server copy remains in the
/// owning control's semantics.
class EventChoiceSignal extends StatelessWidget {
  const EventChoiceSignal({
    super.key,
    required this.eventId,
    required this.choiceId,
    this.muted = false,
    this.size = 52,
  });

  final String eventId;
  final String choiceId;
  final bool muted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final EventChoiceSignalKind kind = EventChoiceSignalCatalog.kindFor(
      eventId: eventId,
      choiceId: choiceId,
    );
    final EventChoiceSignalTone tone = EventChoiceSignalCatalog.toneFor(
      eventId: eventId,
      choiceId: choiceId,
    );
    final Color semanticAccent = switch (tone) {
      EventChoiceSignalTone.lumen => colors.primary,
      EventChoiceSignalTone.energy => palette.energy,
      EventChoiceSignalTone.resonance => palette.resonance,
      EventChoiceSignalTone.neutral => colors.onSurfaceVariant,
    };
    final Color accent = muted
        ? colors.onSurfaceVariant.withValues(alpha: 0.72)
        : semanticAccent;

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          key: Key(
            'event-choice-signal-$eventId-$choiceId-${kind.name}-'
            '${muted ? 'muted' : 'active'}',
          ),
          dimension: size,
          child: CustomPaint(
            painter: _EventChoiceSignalPainter(
              kind: kind,
              accent: accent,
              surface: colors.surfaceContainerHigh,
              route: palette.routeLine,
              muted: muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps a choice mark, complete server copy and optional reward art readable.
class EventChoiceSignalLayout extends StatelessWidget {
  const EventChoiceSignalLayout({
    super.key,
    required this.eventId,
    required this.choiceId,
    required this.child,
    this.muted = false,
    this.trailing,
  });

  final String eventId;
  final String choiceId;
  final Widget child;
  final bool muted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 260;
        final Widget signal = EventChoiceSignal(
          eventId: eventId,
          choiceId: choiceId,
          muted: muted,
        );
        return KeyedSubtree(
          key: Key(
            'event-choice-layout-$eventId-$choiceId-'
            '${compact ? 'compact' : 'wide'}',
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        signal,
                        if (trailing != null) ...<Widget>[
                          const Spacer(),
                          trailing!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    child,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    signal,
                    const SizedBox(width: 11),
                    Expanded(child: child),
                    if (trailing != null) ...<Widget>[
                      const SizedBox(width: 10),
                      trailing!,
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _EventChoiceSignalPainter extends CustomPainter {
  const _EventChoiceSignalPainter({
    required this.kind,
    required this.accent,
    required this.surface,
    required this.route,
    required this.muted,
  });

  final EventChoiceSignalKind kind;
  final Color accent;
  final Color surface;
  final Color route;
  final bool muted;

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
        accent.withValues(alpha: muted ? 0.055 : 0.13),
        surface.withValues(alpha: 0.96),
      );
    final Paint frameLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.026
      ..color = accent.withValues(alpha: muted ? 0.32 : 0.62);
    canvas.drawRRect(frame, frameFill);
    canvas.drawRRect(frame, frameLine);

    final Paint orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.024
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        route,
        accent,
        0.42,
      )!.withValues(alpha: muted ? 0.25 : 0.48);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.35),
      math.pi * 0.12,
      math.pi * 0.48,
      false,
      orbit,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: unit * 0.35),
      math.pi * 1.08,
      math.pi * 0.43,
      false,
      orbit,
    );

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.052
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: muted ? 0.64 : 0.96);
    final Paint fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.028
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: muted ? 0.48 : 0.82);
    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: muted ? 0.66 : 0.96);

    switch (kind) {
      case EventChoiceSignalKind.frequency:
        _paintFrequency(canvas, size, fine, fill);
      case EventChoiceSignalKind.companion:
        _paintCompanion(canvas, size, fine, fill);
      case EventChoiceSignalKind.stabilize:
        _paintStabilize(canvas, size, stroke, fine, fill);
      case EventChoiceSignalKind.echo:
        _paintEcho(canvas, size, stroke, fine, fill);
      case EventChoiceSignalKind.survey:
        _paintSurvey(canvas, size, fine, fill);
      case EventChoiceSignalKind.resonance:
        _paintResonance(canvas, size, stroke, fine, fill);
      case EventChoiceSignalKind.chart:
        _paintChart(canvas, size, fine, fill);
      case EventChoiceSignalKind.compass:
        _paintCompass(canvas, size, stroke, fine, fill);
      case EventChoiceSignalKind.prism:
        _paintPrism(canvas, size, stroke, fine, fill);
      case EventChoiceSignalKind.unknown:
        _paintUnknown(canvas, size, fine, fill);
    }
  }

  Offset _point(Size size, double x, double y) {
    return Offset(size.width * x, size.height * y);
  }

  void _paintFrequency(Canvas canvas, Size size, Paint fine, Paint fill) {
    final Offset source = _point(size, 0.34, 0.64);
    canvas.drawCircle(source, size.shortestSide * 0.055, fill);
    for (final double radius in <double>[0.16, 0.28]) {
      canvas.drawArc(
        Rect.fromCircle(center: source, radius: size.shortestSide * radius),
        -math.pi * 0.48,
        math.pi * 0.55,
        false,
        fine,
      );
    }
    final Offset target = _point(size, 0.68, 0.31);
    canvas.drawCircle(target, size.shortestSide * 0.09, fine);
    canvas.drawCircle(target, size.shortestSide * 0.025, fill);
  }

  void _paintCompanion(Canvas canvas, Size size, Paint fine, Paint fill) {
    final Offset routeStart = _point(size, 0.28, 0.72);
    final Offset routeEnd = _point(size, 0.7, 0.3);
    canvas.drawLine(routeStart, routeEnd, fine);
    canvas.drawCircle(routeStart, size.shortestSide * 0.045, fill);
    canvas.drawOval(
      Rect.fromCenter(
        center: _point(size, 0.56, 0.57),
        width: size.shortestSide * 0.2,
        height: size.shortestSide * 0.17,
      ),
      fill,
    );
    for (final Offset toe in <Offset>[
      _point(size, 0.45, 0.43),
      _point(size, 0.55, 0.38),
      _point(size, 0.65, 0.43),
    ]) {
      canvas.drawCircle(toe, size.shortestSide * 0.045, fill);
    }
  }

  void _paintStabilize(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset center = size.center(Offset.zero);
    final Path core = Path()
      ..moveTo(size.width * 0.5, size.height * 0.28)
      ..lineTo(size.width * 0.7, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height * 0.72)
      ..lineTo(size.width * 0.3, size.height * 0.5)
      ..close();
    canvas.drawPath(core, stroke);
    canvas.drawCircle(center, size.shortestSide * 0.055, fill);
    for (final double radius in <double>[0.28, 0.36]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.shortestSide * radius),
        -math.pi * 0.2,
        math.pi * 0.4,
        false,
        fine,
      );
    }
  }

  void _paintEcho(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path wave = Path()
      ..moveTo(size.width * 0.24, size.height * 0.58)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.3,
        size.width * 0.46,
        size.height * 0.3,
        size.width * 0.53,
        size.height * 0.55,
      )
      ..cubicTo(
        size.width * 0.6,
        size.height * 0.77,
        size.width * 0.69,
        size.height * 0.7,
        size.width * 0.76,
        size.height * 0.45,
      );
    canvas.drawPath(wave, stroke);
    canvas.drawCircle(
      _point(size, 0.24, 0.58),
      size.shortestSide * 0.045,
      fill,
    );
    canvas.drawCircle(
      _point(size, 0.76, 0.45),
      size.shortestSide * 0.045,
      fill,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: _point(size, 0.52, 0.53),
        radius: size.shortestSide * 0.25,
      ),
      math.pi * 1.16,
      math.pi * 0.72,
      false,
      fine,
    );
  }

  void _paintSurvey(Canvas canvas, Size size, Paint fine, Paint fill) {
    final List<Offset> nodes = <Offset>[
      _point(size, 0.3, 0.68),
      _point(size, 0.5, 0.29),
      _point(size, 0.72, 0.65),
    ];
    final Path triangle = Path()
      ..moveTo(nodes[0].dx, nodes[0].dy)
      ..lineTo(nodes[1].dx, nodes[1].dy)
      ..lineTo(nodes[2].dx, nodes[2].dy)
      ..close();
    canvas.drawPath(triangle, fine);
    for (final Offset node in nodes) {
      canvas.drawCircle(node, size.shortestSide * 0.052, fill);
    }
    final Offset center = _point(size, 0.51, 0.53);
    canvas.drawCircle(center, size.shortestSide * 0.075, fine);
    canvas.drawCircle(center, size.shortestSide * 0.022, fill);
  }

  void _paintResonance(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset source = _point(size, 0.27, 0.65);
    final Offset fork = _point(size, 0.48, 0.51);
    final Offset upper = _point(size, 0.72, 0.3);
    final Offset lower = _point(size, 0.72, 0.68);
    canvas.drawLine(source, fork, stroke);
    canvas.drawLine(fork, upper, fine);
    canvas.drawLine(fork, lower, fine);
    canvas.drawCircle(source, size.shortestSide * 0.05, fill);
    canvas.drawCircle(upper, size.shortestSide * 0.055, fill);
    canvas.drawCircle(lower, size.shortestSide * 0.035, fill);
    canvas.drawArc(
      Rect.fromCircle(center: upper, radius: size.shortestSide * 0.13),
      -math.pi * 0.72,
      math.pi * 1.44,
      false,
      fine,
    );
  }

  void _paintChart(Canvas canvas, Size size, Paint fine, Paint fill) {
    final Rect chart = Rect.fromLTWH(
      size.width * 0.25,
      size.height * 0.27,
      size.width * 0.5,
      size.height * 0.46,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chart, Radius.circular(size.shortestSide * 0.07)),
      fine,
    );
    final Path route = Path()
      ..moveTo(size.width * 0.31, size.height * 0.64)
      ..quadraticBezierTo(
        size.width * 0.44,
        size.height * 0.34,
        size.width * 0.55,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height * 0.65,
        size.width * 0.7,
        size.height * 0.36,
      );
    canvas.drawPath(route, fine);
    for (final Offset node in <Offset>[
      _point(size, 0.31, 0.64),
      _point(size, 0.55, 0.5),
      _point(size, 0.7, 0.36),
    ]) {
      canvas.drawCircle(node, size.shortestSide * 0.035, fill);
    }
  }

  void _paintCompass(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Offset center = size.center(Offset.zero);
    canvas.drawCircle(center, size.shortestSide * 0.25, fine);
    final Path needle = Path()
      ..moveTo(size.width * 0.44, size.height * 0.58)
      ..lineTo(size.width * 0.62, size.height * 0.31)
      ..lineTo(size.width * 0.56, size.height * 0.59)
      ..close();
    canvas.drawPath(needle, stroke);
    canvas.drawCircle(center, size.shortestSide * 0.04, fill);
    canvas.drawCircle(_point(size, 0.7, 0.67), size.shortestSide * 0.045, fill);
  }

  void _paintUnknown(Canvas canvas, Size size, Paint fine, Paint fill) {
    final List<Offset> nodes = <Offset>[
      _point(size, 0.29, 0.63),
      _point(size, 0.43, 0.35),
      _point(size, 0.62, 0.48),
      _point(size, 0.73, 0.29),
      _point(size, 0.69, 0.7),
    ];
    final Path path = Path()..moveTo(nodes.first.dx, nodes.first.dy);
    for (final Offset node in nodes.skip(1)) {
      path.lineTo(node.dx, node.dy);
    }
    canvas.drawPath(path, fine);
    for (int index = 0; index < nodes.length; index += 1) {
      canvas.drawCircle(
        nodes[index],
        size.shortestSide * (index.isEven ? 0.04 : 0.026),
        fill,
      );
    }
  }

  void _paintPrism(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fine,
    Paint fill,
  ) {
    final Path prism = Path()
      ..moveTo(size.width * 0.5, size.height * 0.24)
      ..lineTo(size.width * 0.72, size.height * 0.7)
      ..lineTo(size.width * 0.28, size.height * 0.7)
      ..close();
    canvas.drawPath(prism, stroke);
    canvas.drawLine(_point(size, 0.22, 0.5), _point(size, 0.78, 0.5), fine);
    canvas.drawCircle(_point(size, 0.5, 0.5), size.shortestSide * 0.045, fill);
  }

  @override
  bool shouldRepaint(covariant _EventChoiceSignalPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.accent != accent ||
        oldDelegate.surface != surface ||
        oldDelegate.route != route ||
        oldDelegate.muted != muted;
  }
}
