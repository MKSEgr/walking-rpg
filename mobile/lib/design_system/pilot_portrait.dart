import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/illustrated_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

class PilotPortrait extends StatelessWidget {
  const PilotPortrait({
    super.key,
    required this.name,
    this.size = 72,
    this.highlighted = false,
  });

  static const String assetPath = 'assets/characters/pilot_navigator.webp';

  final String name;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    return Semantics(
      image: true,
      label: 'Пилот $name',
      child: RepaintBoundary(
        child: ExpeditionIllustratedPortrait(
          assetPath: assetPath,
          imageKey: const Key('pilot-portrait-image'),
          size: size,
          accent: colors.primary,
          border: palette.panelBorder,
          shadow: palette.shadow,
          highlighted: highlighted,
        ),
      ),
    );
  }
}
