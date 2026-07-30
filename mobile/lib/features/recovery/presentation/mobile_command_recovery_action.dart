import 'package:flutter/material.dart';

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
          ? 'Сохранённые действия требуют внимания'
          : count > 0
          ? 'Сохранённые действия: $count'
          : 'Сохранённые действия',
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
