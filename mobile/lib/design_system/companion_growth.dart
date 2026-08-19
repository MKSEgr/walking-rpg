import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

abstract final class CompanionGrowth {
  static const int illustratedStageCount = 3;

  static int normalizedStage(int stage) => stage < 0 ? 0 : stage;

  static int illustratedStage(int stage) {
    return normalizedStage(stage).clamp(0, illustratedStageCount - 1).toInt();
  }

  static String stageName(AppLocalizations l10n, int stage) =>
      l10n.companionStageName(stage);

  static String formLabel(AppLocalizations l10n, int stage) =>
      l10n.companionFormLabel(stage);
}

class CompanionGrowthTrack extends StatelessWidget {
  const CompanionGrowthTrack({super.key, required this.currentStage});

  final int currentStage;

  @override
  Widget build(BuildContext context) {
    final int normalizedStage = CompanionGrowth.normalizedStage(currentStage);
    final String currentName = context.l10n.companionStageName(currentStage);
    final String semanticValue =
        normalizedStage < CompanionGrowth.illustratedStageCount
        ? context.l10n.companionGrowthKnownSemantics(
            currentName,
            normalizedStage + 1,
            CompanionGrowth.illustratedStageCount,
          )
        : context.l10n.companionGrowthLatestSemantics(currentName);

    return Semantics(
      container: true,
      label: context.l10n.companionGrowthSemantics(semanticValue),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List<Widget>.generate(
            CompanionGrowth.illustratedStageCount,
            (int stage) => Expanded(
              child: _CompanionGrowthStage(
                stage: stage,
                currentStage: normalizedStage,
              ),
            ),
            growable: false,
          ),
        ),
      ),
    );
  }
}

class _CompanionGrowthStage extends StatelessWidget {
  const _CompanionGrowthStage({
    required this.stage,
    required this.currentStage,
  });

  final int stage;
  final int currentStage;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final bool current = stage == currentStage;
    final bool reached = stage < currentStage;
    final Color markerColor = current
        ? palette.resonance
        : reached
        ? colors.primary
        : colors.onSurfaceVariant;
    final Color leftLineColor = stage > 0 && stage <= currentStage
        ? colors.primary.withValues(alpha: 0.62)
        : palette.panelBorder;
    final Color rightLineColor = stage < currentStage
        ? colors.primary.withValues(alpha: 0.62)
        : palette.panelBorder;

    return Column(
      key: Key('companion-growth-stage-$stage'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 2,
                color: stage == 0 ? Colors.transparent : leftLineColor,
              ),
            ),
            Container(
              key: current ? const Key('companion-growth-current') : null,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: markerColor.withValues(alpha: current ? 0.2 : 0.1),
                border: Border.all(
                  color: markerColor.withValues(alpha: current ? 0.9 : 0.48),
                  width: current ? 2 : 1.2,
                ),
              ),
              child: Icon(
                current
                    ? Icons.auto_awesome
                    : reached
                    ? Icons.check
                    : Icons.circle_outlined,
                size: current ? 16 : 14,
                color: markerColor,
              ),
            ),
            Expanded(
              child: Container(
                height: 2,
                color: stage == CompanionGrowth.illustratedStageCount - 1
                    ? Colors.transparent
                    : rightLineColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          context.l10n.companionStageName(stage),
          maxLines: 2,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: current ? palette.resonance : colors.onSurfaceVariant,
            fontWeight: current ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
