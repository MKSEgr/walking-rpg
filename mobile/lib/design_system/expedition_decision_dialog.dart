import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

/// A trust-boundary dialog for decisions that remove local or server data.
///
/// The caller keeps ownership of the operation and navigation result. This
/// component only presents the decision, keeps both actions reachable under
/// enlarged text and visually distinguishes irreversible confirmation.
class ExpeditionDecisionDialog extends StatelessWidget {
  const ExpeditionDecisionDialog({
    super.key,
    required this.badgeLabel,
    required this.title,
    required this.message,
    required this.icon,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.confirmButtonKey,
    this.content,
    this.tone = ExpeditionPanelTone.neutral,
    this.destructive = false,
  });

  final String badgeLabel;
  final String title;
  final String message;
  final IconData icon;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final VoidCallback onCancel;
  final Key? confirmButtonKey;
  final Widget? content;
  final ExpeditionPanelTone tone;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Color accent = destructive
        ? colors.error
        : switch (tone) {
            ExpeditionPanelTone.neutral => colors.primary,
            ExpeditionPanelTone.lumen => colors.primary,
            ExpeditionPanelTone.energy => palette.energy,
            ExpeditionPanelTone.resonance => palette.resonance,
          };

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: ExpeditionPanel(
            tone: tone,
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              key: const Key('expedition-decision-scroll'),
              padding: const EdgeInsets.all(20),
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
                      accentColor: accent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.48),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Icon(icon, color: accent, size: 30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    key: const Key('expedition-decision-heading'),
                    container: true,
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (content != null) ...<Widget>[
                    const SizedBox(height: 18),
                    content!,
                  ],
                  const SizedBox(height: 22),
                  OutlinedButton(
                    key: const Key('expedition-decision-cancel'),
                    onPressed: onCancel,
                    child: Text(context.l10n.commonCancel),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: confirmButtonKey,
                    style: destructive
                        ? FilledButton.styleFrom(
                            backgroundColor: colors.error,
                            foregroundColor: colors.onError,
                          )
                        : null,
                    onPressed: onConfirm,
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
