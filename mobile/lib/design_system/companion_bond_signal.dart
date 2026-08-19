import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum CompanionBondIdentity { spark, moss, rune, unknown }

enum CompanionBondStatus { growing, ready, evolved }

/// Presentation identities for accepted companion bond progress.
///
/// Only an exact stable pet ID selects a known mark. Names, species and traits
/// are deliberately ignored so future companions keep a neutral identity.
abstract final class CompanionBondSignalCatalog {
  static CompanionBondIdentity identityFor(String petId) {
    return switch (petId) {
      'spark-v1' => CompanionBondIdentity.spark,
      'moss-v1' => CompanionBondIdentity.moss,
      'rune-v1' => CompanionBondIdentity.rune,
      _ => CompanionBondIdentity.unknown,
    };
  }
}

/// Code-native field for one accepted companion bond snapshot.
///
/// Decorative nodes sample the visual trace; they are not bond thresholds.
/// Readiness and final-form state are passed from the owning server-backed model
/// rather than inferred by the painter.
class CompanionBondSignal extends StatelessWidget {
  const CompanionBondSignal({
    super.key,
    required this.petId,
    required this.petName,
    required this.bond,
    required this.evolutionBond,
    required this.canEvolve,
    required this.fullyEvolved,
  }) : assert(bond >= 0),
       assert(evolutionBond > 0);

  final String petId;
  final String petName;
  final int bond;
  final int evolutionBond;
  final bool canEvolve;
  final bool fullyEvolved;

  CompanionBondStatus get status {
    if (fullyEvolved) {
      return CompanionBondStatus.evolved;
    }
    if (canEvolve) {
      return CompanionBondStatus.ready;
    }
    return CompanionBondStatus.growing;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final CompanionBondIdentity identity =
        CompanionBondSignalCatalog.identityFor(petId);
    final CompanionBondStatus acceptedStatus = status;
    final double progress = acceptedStatus == CompanionBondStatus.growing
        ? (bond / evolutionBond).clamp(0.0, 1.0).toDouble()
        : 1;
    final Color accent = switch (identity) {
      CompanionBondIdentity.spark => palette.energy,
      CompanionBondIdentity.moss => colors.primary,
      CompanionBondIdentity.rune => palette.resonance,
      CompanionBondIdentity.unknown => colors.onSurfaceVariant,
    };
    final String amount = acceptedStatus == CompanionBondStatus.evolved
        ? '$bond'
        : '$bond/$evolutionBond';
    final String semantics = switch (acceptedStatus) {
      CompanionBondStatus.growing => context.l10n
          .platformCompanionBondGrowingSemantics(
            petName,
            bond,
            evolutionBond,
          ),
      CompanionBondStatus.ready => context.l10n
          .platformCompanionBondReadySemantics(
            petName,
            bond,
            evolutionBond,
          ),
      CompanionBondStatus.evolved => context.l10n
          .platformCompanionBondEvolvedSemantics(petName, bond),
    };

    return Semantics(
      key: Key(
        'companion-bond-signal-$petId-${identity.name}-'
        '${acceptedStatus.name}',
      ),
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  context.l10n.platformBondLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                Text(
                  amount,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: canEvolve ? colors.primary : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            RepaintBoundary(
              child: SizedBox(
                key: Key(
                  'companion-bond-field-$petId-${identity.name}-'
                  '${acceptedStatus.name}',
                ),
                height: 52,
                child: CustomPaint(
                  painter: _CompanionBondSignalPainter(
                    identity: identity,
                    status: acceptedStatus,
                    progress: progress,
                    accent: accent,
                    surface: colors.surfaceContainerHigh,
                    route: palette.routeLine,
                    outline: colors.outlineVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanionBondSignalPainter extends CustomPainter {
  const _CompanionBondSignalPainter({
    required this.identity,
    required this.status,
    required this.progress,
    required this.accent,
    required this.surface,
    required this.route,
    required this.outline,
  });

  final CompanionBondIdentity identity;
  final CompanionBondStatus status;
  final double progress;
  final Color accent;
  final Color surface;
  final Color route;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double unit = size.height;
    final RRect frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      Radius.circular(unit * 0.3),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.16),
            surface.withValues(alpha: 0.96),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.48),
    );

    final Offset identityCenter = Offset(unit * 0.52, unit * 0.5);
    canvas.drawCircle(
      identityCenter,
      unit * 0.3,
      Paint()..color = accent.withValues(alpha: 0.11),
    );
    _paintIdentity(canvas, identityCenter, unit);

    final double traceStart = unit * 0.98;
    final double traceEnd = size.width - unit * 0.42;
    if (traceEnd <= traceStart) {
      return;
    }
    final Path trace = Path()
      ..moveTo(traceStart, size.height * 0.64)
      ..cubicTo(
        traceStart + (traceEnd - traceStart) * 0.24,
        size.height * 0.29,
        traceStart + (traceEnd - traceStart) * 0.58,
        size.height * 0.76,
        traceEnd,
        size.height * 0.45,
      );
    final PathMetric metric = trace.computeMetrics().first;
    canvas.drawPath(
      trace,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2
        ..color = Color.lerp(route, outline, 0.35)!.withValues(alpha: 0.62),
    );
    if (progress > 0) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.8
          ..color = accent.withValues(alpha: 0.92),
      );
    }

    for (final double fraction in <double>[0, 0.25, 0.5, 0.75]) {
      final Offset? point = metric
          .getTangentForOffset(metric.length * fraction)
          ?.position;
      if (point == null) {
        continue;
      }
      final bool accepted = progress > 0 && fraction <= progress + 0.001;
      canvas.drawCircle(
        point,
        accepted ? 3.4 : 2.7,
        Paint()
          ..color = accepted ? accent : surface
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        accepted ? 3.4 : 2.7,
        Paint()
          ..color = accepted
              ? accent.withValues(alpha: 0.95)
              : outline.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    final Offset? terminal = metric
        .getTangentForOffset(metric.length)
        ?.position;
    if (terminal != null) {
      _paintTerminal(canvas, terminal, unit);
    }
  }

  void _paintIdentity(Canvas canvas, Offset center, double unit) {
    final Paint line = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.8;
    switch (identity) {
      case CompanionBondIdentity.spark:
        final Path spark = Path()
          ..moveTo(center.dx - unit * 0.13, center.dy + unit * 0.04)
          ..lineTo(center.dx - unit * 0.02, center.dy - unit * 0.17)
          ..lineTo(center.dx + unit * 0.02, center.dy - unit * 0.04)
          ..lineTo(center.dx + unit * 0.14, center.dy - unit * 0.08)
          ..lineTo(center.dx + unit * 0.04, center.dy + unit * 0.17)
          ..lineTo(center.dx, center.dy + unit * 0.05)
          ..close();
        canvas.drawPath(spark, line);
        break;
      case CompanionBondIdentity.moss:
        canvas
          ..drawLine(
            Offset(center.dx, center.dy + unit * 0.16),
            Offset(center.dx, center.dy - unit * 0.08),
            line,
          )
          ..drawArc(
            Rect.fromCenter(
              center: Offset(center.dx - unit * 0.07, center.dy - unit * 0.09),
              width: unit * 0.18,
              height: unit * 0.13,
            ),
            0.2,
            2.7,
            false,
            line,
          )
          ..drawArc(
            Rect.fromCenter(
              center: Offset(center.dx + unit * 0.07, center.dy - unit * 0.04),
              width: unit * 0.18,
              height: unit * 0.13,
            ),
            3.35,
            2.7,
            false,
            line,
          );
        break;
      case CompanionBondIdentity.rune:
        canvas
          ..drawArc(
            Rect.fromCircle(center: center, radius: unit * 0.13),
            -2.5,
            2.2,
            false,
            line,
          )
          ..drawArc(
            Rect.fromCircle(center: center, radius: unit * 0.08),
            0.5,
            2.2,
            false,
            line,
          )
          ..drawCircle(center, unit * 0.025, Paint()..color = accent);
        break;
      case CompanionBondIdentity.unknown:
        for (final Offset offset in <Offset>[
          Offset(-unit * 0.1, unit * 0.08),
          Offset(-unit * 0.02, -unit * 0.11),
          Offset(unit * 0.11, unit * 0.02),
        ]) {
          canvas.drawCircle(center + offset, unit * 0.026, line);
        }
        break;
    }
  }

  void _paintTerminal(Canvas canvas, Offset center, double unit) {
    final bool complete = status != CompanionBondStatus.growing;
    final Paint fill = Paint()
      ..color = complete
          ? accent.withValues(alpha: 0.2)
          : surface.withValues(alpha: 0.95);
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = complete ? 2 : 1.4
      ..color = complete
          ? accent.withValues(alpha: 0.95)
          : outline.withValues(alpha: 0.82);
    canvas
      ..drawCircle(center, unit * 0.16, fill)
      ..drawCircle(center, unit * 0.16, line);
    if (status == CompanionBondStatus.evolved) {
      canvas.drawCircle(center, unit * 0.085, line);
    } else if (status == CompanionBondStatus.ready) {
      final Path seal = Path()
        ..moveTo(center.dx, center.dy - unit * 0.08)
        ..lineTo(center.dx + unit * 0.075, center.dy)
        ..lineTo(center.dx, center.dy + unit * 0.08)
        ..lineTo(center.dx - unit * 0.075, center.dy)
        ..close();
      canvas.drawPath(seal, line);
    }
  }

  @override
  bool shouldRepaint(covariant _CompanionBondSignalPainter oldDelegate) {
    return identity != oldDelegate.identity ||
        status != oldDelegate.status ||
        progress != oldDelegate.progress ||
        accent != oldDelegate.accent ||
        surface != oldDelegate.surface ||
        route != oldDelegate.route ||
        outline != oldDelegate.outline;
  }
}
