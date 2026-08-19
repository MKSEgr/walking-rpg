import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

abstract final class ExpeditionEventArtwork {
  static String? assetPathFor(String eventId) {
    return switch (eventId) {
      'signal-source-v1' => 'assets/events/signal_source.webp',
      'echo-vault-v1' => 'assets/events/echo_vault.webp',
      'mirror-delta-v1' => 'assets/events/mirror_delta.webp',
      'resonance-pocket-v1' => 'assets/events/resonance_pocket.webp',
      _ => null,
    };
  }

  static String? semanticDescriptionFor({
    required AppLocalizations l10n,
    required String eventId,
    required String eventTitle,
  }) {
    return assetPathFor(eventId) == null
        ? null
        : l10n.eventSceneDescription(eventId, eventTitle);
  }
}

/// Static event art selected only from the exact server-owned [eventId].
///
/// Unknown IDs retain a neutral code-native signal field. The illustration
/// never derives event availability, choice state, rewards or route access.
class ExpeditionEventScene extends StatelessWidget {
  const ExpeditionEventScene({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.fallbackSemanticLabel,
    this.maxHeight = 190,
  }) : assert(maxHeight > 0);

  final String eventId;
  final String eventTitle;
  final String fallbackSemanticLabel;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final String? assetPath = ExpeditionEventArtwork.assetPathFor(eventId);
    final String semanticLabel =
        ExpeditionEventArtwork.semanticDescriptionFor(
          l10n: context.l10n,
          eventId: eventId,
          eventTitle: eventTitle,
        ) ??
        fallbackSemanticLabel;
    final Color accent = switch (eventId) {
      'signal-source-v1' => colors.primary,
      'echo-vault-v1' => palette.energy,
      'mirror-delta-v1' || 'resonance-pocket-v1' => palette.resonance,
      _ => colors.onSurfaceVariant,
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double proportionalHeight = constraints.maxWidth * 9 / 16;
        final double height = math.min(maxHeight, proportionalHeight);
        return Semantics(
          image: true,
          label: semanticLabel,
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: SizedBox(
                width: double.infinity,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: assetPath == null
                        ? _UnknownEventScene(eventId: eventId)
                        : Image.asset(
                            assetPath,
                            key: Key('event-scene-$eventId'),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            excludeFromSemantics: true,
                          ),
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

class _UnknownEventScene extends StatelessWidget {
  const _UnknownEventScene({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    return DecoratedBox(
      key: Key('event-scene-fallback-$eventId'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.backdropTop,
            colors.surfaceContainerHigh,
            palette.backdropBottom,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            width: 132,
            height: 132,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.routeLine.withValues(alpha: 0.68),
                ),
              ),
            ),
          ),
          Positioned(
            width: 76,
            height: 76,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.54),
                ),
              ),
            ),
          ),
          Icon(
            Icons.auto_awesome_outlined,
            size: 34,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
