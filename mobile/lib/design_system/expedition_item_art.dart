import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

abstract final class ExpeditionItemArtwork {
  static String? assetPathFor(String itemId) {
    return switch (itemId) {
      'lumen-shard' => 'assets/items/lumen_shard.webp',
      'echo-thread' => 'assets/items/echo_thread.webp',
      'resonance-compass' => 'assets/items/resonance_compass.webp',
      _ => null,
    };
  }

  static IconData? codeNativeIconFor(String itemId) {
    return switch (itemId) {
      'prism-sextant' => Icons.change_history_outlined,
      _ => null,
    };
  }
}

/// Presentation-only item art selected from an exact server-owned [itemId].
///
/// The surrounding item name, quantity and state remain the accessible source.
/// Unknown IDs keep a code-native fallback instead of borrowing an illustration
/// from player-facing copy.
class ExpeditionItemEmblem extends StatelessWidget {
  const ExpeditionItemEmblem({
    super.key,
    required this.itemId,
    this.size = 64,
    this.highlighted = false,
  }) : assert(size > 0);

  final String itemId;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final String? assetPath = ExpeditionItemArtwork.assetPathFor(itemId);
    final IconData? codeNativeIcon = ExpeditionItemArtwork.codeNativeIconFor(
      itemId,
    );
    final Color accent = switch (itemId) {
      'lumen-shard' => colors.primary,
      'echo-thread' => palette.resonance,
      'resonance-compass' => palette.energy,
      'prism-sextant' => colors.primary,
      _ => colors.onSurfaceVariant,
    };
    final double radius = size * 0.25;

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: (highlighted ? accent : palette.panelBorder).withValues(
                  alpha: highlighted ? 0.82 : 0.72,
                ),
                width: highlighted ? 2 : 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: (highlighted ? accent : palette.shadow).withValues(
                    alpha: highlighted ? 0.22 : 0.34,
                  ),
                  blurRadius: highlighted ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - 1),
              child: assetPath == null
                  ? ColoredBox(
                      key: Key(
                        codeNativeIcon == null
                            ? 'item-art-fallback-$itemId'
                            : 'item-art-code-$itemId',
                      ),
                      color: colors.surfaceContainerHighest,
                      child: Icon(
                        codeNativeIcon ?? Icons.category_outlined,
                        size: size * 0.42,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : Image.asset(
                      assetPath,
                      key: Key('item-art-$itemId'),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
