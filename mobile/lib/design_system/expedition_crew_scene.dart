import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';

/// Cinematic key art selected from the accepted crew identity.
/// The illustrated beacon is atmospheric; route state stays in the caller's HUD.
class ExpeditionCrewScene extends StatelessWidget {
  const ExpeditionCrewScene({
    super.key,
    required this.semanticLabel,
    required this.pilotName,
    required this.height,
    this.pilotId,
    this.petId,
    this.petName,
    this.petSpecies,
    this.petEvolutionStage,
  }) : assert(height > 0);

  static const double aspectRatio = 2 / 3;
  static const Rect subjectBounds = Rect.fromLTRB(0.27, 0.235, 0.80, 0.70);

  final String semanticLabel;
  final String? pilotId;
  final String pilotName;
  final double height;
  final String? petId;
  final String? petName;
  final String? petSpecies;
  final int? petEvolutionStage;

  // Legacy snapshots used the universal Navigator before exposing pilotId.
  bool get hasIllustratedPilot => pilotId == null || pilotId == 'navigator-v1';

  bool get hasPetIdentity =>
      petId != null &&
      petName != null &&
      petSpecies != null &&
      petEvolutionStage != null;

  bool get hasIllustratedPet =>
      hasIllustratedPilot &&
      hasPetIdentity &&
      const <String>{'spark-v1', 'moss-v1', 'rune-v1'}.contains(petId);

  String get sceneAsset {
    if (!hasIllustratedPilot) return 'assets/scenes/home_frontier_v3.webp';
    if (!hasIllustratedPet) return 'assets/scenes/home_pilot_v3.webp';
    return switch (petId) {
      'spark-v1' => 'assets/scenes/home_crew_spark_v3.webp',
      'moss-v1' => 'assets/scenes/home_crew_moss_v3.webp',
      'rune-v1' => 'assets/scenes/home_crew_rune_v3.webp',
      _ => 'assets/scenes/home_pilot_v3.webp',
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The stage supplies tight portrait constraints after measuring its HUD.
        // Standalone uses still fit the complete artwork inside the given height.
        final double artHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : math.min(height, constraints.maxWidth / aspectRatio);
        final double artWidth = artHeight * aspectRatio;
        return Center(
          child: Semantics(
            key: const Key('home-expedition-vista'),
            container: true,
            explicitChildNodes: true,
            label: semanticLabel,
            child: RepaintBoundary(
              child: ClipRect(
                child: SizedBox(
                  width: artWidth,
                  height: artHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.asset(
                        sceneAsset,
                        key: ValueKey<String>(sceneAsset),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        excludeFromSemantics: true,
                      ),
                      if (hasIllustratedPilot)
                        Positioned(
                          left: artWidth * 0.27,
                          top: artHeight * 0.235,
                          width: artWidth * 0.27,
                          height: artHeight * 0.465,
                          child: Semantics(
                            key: const Key('home-pilot-illustration'),
                            image: true,
                            label: context.l10n.pilotPortraitSemantics(
                              pilotName,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      if (hasIllustratedPet)
                        Positioned(
                          left: artWidth * 0.50,
                          top: artHeight * 0.43,
                          width: artWidth * 0.30,
                          height: artHeight * 0.27,
                          child: Semantics(
                            key: const Key('home-active-companion-portrait'),
                            image: true,
                            label: context.l10n.companionPortraitDescription(
                              name: petName!,
                              species: petSpecies!,
                              stage: petEvolutionStage!,
                              active: true,
                              hasSparkHalo: false,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        )
                      else if (hasPetIdentity)
                        Positioned(
                          left: artWidth * 0.54,
                          top: artHeight * 0.51,
                          child: CompanionPortrait(
                            key: const Key('home-active-companion-portrait'),
                            petId: petId!,
                            name: petName!,
                            species: petSpecies!,
                            evolutionStage: petEvolutionStage!,
                            active: true,
                            size: artWidth * 0.26,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
