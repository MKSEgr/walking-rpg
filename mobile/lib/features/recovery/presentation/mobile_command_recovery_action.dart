import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';

class MobileCommandRecoveryAction extends StatelessWidget {
  const MobileCommandRecoveryAction({
    super.key,
    required this.onPressed,
    required this.count,
    required this.unavailable,
  });

  final VoidCallback? onPressed;
  final int count;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final bool showBadge = unavailable || count > 0;
    final String badgeLabel = unavailable
        ? '!'
        : count > 99
        ? '99+'
        : '$count';
    return IconButton(
      tooltip: unavailable
          ? context.l10n.savedActionsAttentionTooltip
          : count > 0
          ? context.l10n.savedActionsCountTooltip(count)
          : context.l10n.savedActionsTooltip,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: showBadge,
        label: Text(badgeLabel),
        child: Icon(
          unavailable ? Icons.sync_problem_outlined : Icons.cloud_sync_outlined,
        ),
      ),
    );
  }
}
