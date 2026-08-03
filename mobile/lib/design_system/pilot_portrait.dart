import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/character_cosmetics.dart';
import 'package:walking_rpg_mobile/design_system/illustrated_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

class PilotPortrait extends StatelessWidget {
  const PilotPortrait({
    super.key,
    required this.name,
    this.size = 72,
    this.highlighted = false,
    this.equippedCosmeticIds = const <String>{},
  });

  static const String assetPath = 'assets/characters/pilot_navigator.webp';
  static const String scarfAssetPath =
      'assets/characters/pilot_navigator_scarf.webp';

  final String name;
  final double size;
  final bool highlighted;
  final Set<String> equippedCosmeticIds;

  bool get hasNavigatorScarf {
    return equippedCosmeticIds.contains(CharacterCosmeticIds.pilotScarf);
  }

  String get illustrationAsset {
    return hasNavigatorScarf ? scarfAssetPath : assetPath;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final String cosmeticLabel = hasNavigatorScarf ? ', Шарф навигатора' : '';
    return Semantics(
      image: true,
      label: 'Пилот $name$cosmeticLabel',
      child: RepaintBoundary(
        child: ExpeditionIllustratedPortrait(
          assetPath: illustrationAsset,
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
