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
    if (!hasIllustratedPilot) return 'assets/events/signal_source.webp';
    if (!hasIllustratedPet) return 'assets/scenes/home_pilot_v2.webp';
    return switch (petId) {
      'spark-v1' => 'assets/scenes/home_crew_spark_v2.webp',
      'moss-v1' => 'assets/scenes/home_crew_moss_v2.webp',
      'rune-v1' => 'assets/scenes/home_crew_rune_v2.webp',
      _ => 'assets/scenes/home_pilot_v2.webp',
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Fit the entire square composition: a short viewport must not crop
        // the pilot's hood, feet or a companion's tail out of the scene.
        final double side = math.min(constraints.maxWidth, height);
        return Center(
          child: Semantics(
            key: const Key('home-expedition-vista'),
            container: true,
            explicitChildNodes: true,
            label: semanticLabel,
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox.square(
                  dimension: side,
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
                          left: side * 0.18,
                          top: side * 0.06,
                          width: side * 0.34,
                          height: side * 0.83,
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
                          left: side * 0.48,
                          top: side * 0.44,
                          width: side * 0.40,
                          height: side * 0.45,
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
                          right: side * 0.12,
                          bottom: side * 0.09,
                          child: CompanionPortrait(
                            key: const Key('home-active-companion-portrait'),
                            petId: petId!,
                            name: petName!,
                            species: petSpecies!,
                            evolutionStage: petEvolutionStage!,
                            active: true,
                            size: side * 0.32,
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
