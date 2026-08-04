import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

abstract final class CompanionGrowth {
  static const int illustratedStageCount = 3;

  static int normalizedStage(int stage) => stage < 0 ? 0 : stage;

  static int illustratedStage(int stage) {
    return normalizedStage(stage).clamp(0, illustratedStageCount - 1).toInt();
  }

  static String stageName(int stage) {
    return switch (normalizedStage(stage)) {
      0 => 'Малыш',
      1 => 'Юный',
      2 => 'Взрослый',
      final int value => 'Форма ${value + 1}',
    };
  }

  static String formLabel(int stage) {
    final int normalized = normalizedStage(stage);
    final String name = stageName(normalized);
    return normalized < illustratedStageCount
        ? '$name · форма ${normalized + 1}'
        : name;
  }
}

class CompanionGrowthTrack extends StatelessWidget {
  const CompanionGrowthTrack({super.key, required this.currentStage});

  final int currentStage;

  @override
  Widget build(BuildContext context) {
    final int normalizedStage = CompanionGrowth.normalizedStage(currentStage);
    final String currentName = CompanionGrowth.stageName(currentStage);
    final String semanticValue =
        normalizedStage < CompanionGrowth.illustratedStageCount
        ? '$currentName, этап ${normalizedStage + 1} из '
              '${CompanionGrowth.illustratedStageCount}'
        : '$currentName, показана последняя известная иллюстрация';

    return Semantics(
      container: true,
      label: 'Рост спутника: $semanticValue',
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
          CompanionGrowth.stageName(stage),
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
