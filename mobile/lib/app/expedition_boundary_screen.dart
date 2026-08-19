import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

enum _ExpeditionBoundaryKind { loading, blocked }

/// Full-screen presentation for application lifecycle boundaries that do not
/// yet own an authoritative game snapshot.
///
/// The screen is intentionally action-free. Its callers keep lifecycle and
/// recovery decisions, while this surface only explains an indeterminate
/// launch operation or a fail-closed boundary.
class ExpeditionBoundaryScreen extends StatelessWidget {
  const ExpeditionBoundaryScreen.loading({
    super.key,
    required this.badgeLabel,
    required this.title,
    required this.message,
    required this.icon,
    this.tone = ExpeditionPanelTone.lumen,
  }) : _kind = _ExpeditionBoundaryKind.loading,
       details = null;

  const ExpeditionBoundaryScreen.blocked({
    super.key,
    required this.badgeLabel,
    required this.title,
    required this.message,
    required this.icon,
    this.details,
    this.tone = ExpeditionPanelTone.neutral,
  }) : _kind = _ExpeditionBoundaryKind.blocked;

  final _ExpeditionBoundaryKind _kind;
  final String badgeLabel;
  final String title;
  final String message;
  final IconData icon;
  final String? details;
  final ExpeditionPanelTone tone;

  bool get _loading => _kind == _ExpeditionBoundaryKind.loading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: ExpeditionBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    liveRegion: true,
                    label: '$badgeLabel. $title. $message',
                    child: ExpeditionPanel(
                      tone: tone,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ExpeditionBadge(
                              label: badgeLabel,
                              icon: icon,
                              tone: tone,
                              allowWrap: true,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Align(
                            child: _BoundarySignal(
                              loading: _loading,
                              icon: icon,
                              tone: tone,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            key: const Key('expedition-boundary-heading'),
                            container: true,
                            header: true,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          if (details case final String details
                              when details.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 16),
                            DecoratedBox(
                              key: const Key('expedition-boundary-details'),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest
                                    .withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.outlineVariant.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  details,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoundarySignal extends StatelessWidget {
  const _BoundarySignal({
    required this.loading,
    required this.icon,
    required this.tone,
  });

  final bool loading;
  final IconData icon;
  final ExpeditionPanelTone tone;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Color accent = loading
        ? switch (tone) {
            ExpeditionPanelTone.neutral => colors.primary,
            ExpeditionPanelTone.lumen => colors.primary,
            ExpeditionPanelTone.energy => palette.energy,
            ExpeditionPanelTone.resonance => palette.resonance,
          }
        : colors.error;
    return Semantics(
      label: loading
          ? context.l10n.boundaryLoadingSemantics
          : context.l10n.boundaryBlockedSemantics,
      child: SizedBox.square(
        dimension: 76,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (loading)
              CircularProgressIndicator(
                strokeWidth: 3,
                color: accent,
                backgroundColor: colors.surfaceContainerHighest,
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.52)),
                ),
              ),
            Center(child: Icon(icon, color: accent, size: 31)),
          ],
        ),
      ),
    );
  }
}
