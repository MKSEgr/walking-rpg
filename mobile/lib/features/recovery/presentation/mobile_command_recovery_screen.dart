import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_recovery.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/expedition_decision_dialog.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

class MobileCommandRecoveryScreen extends StatefulWidget {
  const MobileCommandRecoveryScreen({
    super.key,
    required this.runtime,
    this.onServerStateChanged,
  });

  final MobileCommandRuntime runtime;
  final VoidCallback? onServerStateChanged;

  @override
  State<MobileCommandRecoveryScreen> createState() =>
      _MobileCommandRecoveryScreenState();
}

class _MobileCommandRecoveryScreenState
    extends State<MobileCommandRecoveryScreen> {
  late Future<MobileCommandRecoverySnapshot> _snapshotFuture;
  StreamSubscription<void>? _changesSubscription;
  bool _retrying = false;
  final Set<MobileCommandRecoveryItem> _dismissing =
      <MobileCommandRecoveryItem>{};

  @override
  void initState() {
    super.initState();
    _subscribe();
    _snapshotFuture = _readSnapshot();
  }

  @override
  void didUpdateWidget(MobileCommandRecoveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtime != widget.runtime) {
      unawaited(_changesSubscription?.cancel());
      _subscribe();
      _reload();
    }
  }

  @override
  void dispose() {
    unawaited(_changesSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.recoveryTitle),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.recoveryRefresh,
            onPressed: _retrying ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ExpeditionBackdrop(
        child: SafeArea(
          top: false,
          child: FutureBuilder<MobileCommandRecoverySnapshot>(
            future: _snapshotFuture,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<MobileCommandRecoverySnapshot> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _RecoveryLoading();
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return _RecoveryStoreError(
                      retrying: _retrying,
                      onRetryRead: _reload,
                    );
                  }
                  return _RecoveryBody(
                    snapshot: snapshot.data!,
                    retrying: _retrying,
                    dismissing: _dismissing,
                    onRetry: _retryPending,
                    onDismiss: _confirmDismiss,
                  );
                },
          ),
        ),
      ),
    );
  }

  void _subscribe() {
    _changesSubscription = widget.runtime.changes.listen((void _) {
      if (mounted) {
        _reload();
      }
    });
  }

  void _reload() {
    final Future<MobileCommandRecoverySnapshot> loading = _readSnapshot();
    if (!mounted) {
      return;
    }
    setState(() {
      _snapshotFuture = loading;
    });
  }

  Future<MobileCommandRecoverySnapshot> _readSnapshot() async {
    return widget.runtime.recoverySnapshot();
  }

  Future<void> _retryPending() async {
    if (_retrying) {
      return;
    }
    setState(() {
      _retrying = true;
    });
    final VoidCallback? onServerStateChanged = widget.onServerStateChanged;
    try {
      final MobileCommandReplayReport report = await widget.runtime
          .replayPending();
      if (report.changedServerState || report.permanentFailures > 0) {
        onServerStateChanged?.call();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_replayMessage(report))));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.recoveryRetryFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _retrying = false;
        });
        _reload();
      }
    }
  }

  Future<void> _confirmDismiss(MobileCommandRecoveryItem item) async {
    if (_dismissing.contains(item)) {
      return;
    }
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return ExpeditionDecisionDialog(
              key: const Key('command-recovery-dismiss-dialog'),
              badgeLabel: context.l10n.recoveryDismissBadge,
              title: context.l10n.recoveryDismissTitle,
              message: context.l10n.recoveryDismissMessage,
              icon: Icons.delete_sweep_outlined,
              confirmLabel: context.l10n.recoveryDismissAction,
              confirmButtonKey: const Key('command-recovery-dismiss-confirm'),
              destructive: true,
              onCancel: () => Navigator.of(context).pop(false),
              onConfirm: () => Navigator.of(context).pop(true),
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _dismissing.add(item);
    });
    try {
      await widget.runtime.dismissFailed(item: item);
    } on MobileCommandDismissalException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.recoveryDismissPending)),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.recoveryDismissFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _dismissing.remove(item);
        });
        _reload();
      }
    }
  }

  String _replayMessage(MobileCommandReplayReport report) {
    if (report.succeeded == 0 &&
        report.retryableFailures == 0 &&
        report.permanentFailures == 0) {
      if (report.pendingAfter > 0) {
        return context.l10n.recoveryCriticalChecked;
      }
      return context.l10n.recoveryNothingToRetry;
    }
    final List<String> parts = <String>[
      if (report.succeeded > 0)
        context.l10n.recoveryReplaySent(report.succeeded),
      if (report.pendingAfter > 0)
        context.l10n.recoveryReplayPending(report.pendingAfter),
      if (report.permanentFailures > 0)
        context.l10n.recoveryReplayRejected(report.permanentFailures),
    ];
    return context.l10n.recoveryReplaySummary(parts.join(' · '));
  }
}

class _RecoveryBody extends StatelessWidget {
  const _RecoveryBody({
    required this.snapshot,
    required this.retrying,
    required this.dismissing,
    required this.onRetry,
    required this.onDismiss,
  });

  final MobileCommandRecoverySnapshot snapshot;
  final bool retrying;
  final Set<MobileCommandRecoveryItem> dismissing;
  final VoidCallback onRetry;
  final ValueChanged<MobileCommandRecoveryItem> onDismiss;

  @override
  Widget build(BuildContext context) {
    if (snapshot.items.isEmpty) {
      return const _RecoveryEmpty();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _RecoverySummary(snapshot: snapshot),
                if (snapshot.pendingCount > 0) ...<Widget>[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const Key('command-recovery-retry'),
                    onPressed: retrying ? null : onRetry,
                    icon: retrying
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      retrying
                          ? context.l10n.recoveryRetrying
                          : context.l10n.recoveryRetryAction,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                ExpeditionSectionTitle(
                  title: context.l10n.recoveryJournalTitle,
                  subtitle: context.l10n.recoveryJournalSubtitle,
                  icon: Icons.receipt_long_outlined,
                ),
                const SizedBox(height: 12),
                for (final MobileCommandRecoveryItem item
                    in snapshot.items) ...<Widget>[
                  _RecoveryCommandCard(
                    item: item,
                    dismissing: dismissing.contains(item),
                    onDismiss: () => onDismiss(item),
                  ),
                  const SizedBox(height: 12),
                ],
                ExpeditionPanel(
                  key: const Key('command-recovery-safety-note'),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.shield_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(context.l10n.recoverySafetyNote)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecoverySummary extends StatelessWidget {
  const _RecoverySummary({required this.snapshot});

  final MobileCommandRecoverySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final ExpeditionPanelTone tone = snapshot.pendingCount > 0
        ? ExpeditionPanelTone.energy
        : ExpeditionPanelTone.neutral;
    return Semantics(
      key: const Key('command-recovery-summary'),
      container: true,
      excludeSemantics: true,
      label: context.l10n.recoverySummarySemantics(
        snapshot.pendingCount,
        snapshot.failedCount,
      ),
      child: ExpeditionPanel(
        tone: tone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.recoveryEyebrow,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: snapshot.pendingCount > 0
                    ? palette.energy
                    : colors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.recoveryQueueTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.recoveryQueueDescription,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _RecoveryCountBadge(
                  key: const Key('command-recovery-pending-count'),
                  label: context.l10n.recoveryPendingBadge,
                  count: snapshot.pendingCount,
                  icon: Icons.schedule_send_outlined,
                  accent: palette.energy,
                  onAccent: palette.onEnergy,
                ),
                _RecoveryCountBadge(
                  key: const Key('command-recovery-failed-count'),
                  label: context.l10n.recoveryFailedBadge,
                  count: snapshot.failedCount,
                  icon: Icons.error_outline,
                  accent: colors.error,
                  onAccent: colors.onError,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryCommandCard extends StatelessWidget {
  const _RecoveryCommandCard({
    required this.item,
    required this.dismissing,
    required this.onDismiss,
  });

  final MobileCommandRecoveryItem item;
  final bool dismissing;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bool failed = item.state == MobileCommandState.failed;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return _RecoveryCommandSurface(
      failed: failed,
      tone: item.lane == MobileCommandLane.telemetry
          ? ExpeditionPanelTone.neutral
          : ExpeditionPanelTone.energy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                failed ? Icons.error_outline : Icons.schedule_send_outlined,
                color: failed ? colors.error : colors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _commandLabel(context.l10n, item),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      failed
                          ? context.l10n.recoveryFailedStatus
                          : item.attemptCount == 0
                          ? context.l10n.recoveryStoredStatus
                          : _pendingStatus(context.l10n, item.failureCategory),
                      style: failed
                          ? TextStyle(color: colors.error)
                          : TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LaneChip(lane: item.lane),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.recoveryCommandMetadata(
              item.attemptCount,
              _formatTimestamp(item.createdAt),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (failed) ...<Widget>[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: colors.error),
              onPressed: dismissing ? null : onDismiss,
              icon: dismissing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(context.l10n.recoveryDismissDiagnostic),
            ),
          ],
        ],
      ),
    );
  }

  static String _commandLabel(
    AppLocalizations l10n,
    MobileCommandRecoveryItem item,
  ) {
    if (item.lane == MobileCommandLane.telemetry) {
      return l10n.recoveryTelemetryCommand;
    }
    return switch (item.type) {
      MobileCommandType.activitySync => l10n.recoveryActivitySyncCommand,
      MobileCommandType.expeditionAdvance =>
        l10n.recoveryExpeditionAdvanceCommand,
      MobileCommandType.expeditionJourneyStart =>
        l10n.recoveryJourneyStartCommand,
      MobileCommandType.eventResolution => l10n.recoveryEventResolutionCommand,
      MobileCommandType.eventResultAcknowledgement =>
        l10n.recoveryEventAcknowledgementCommand,
      MobileCommandType.crafting => l10n.recoveryCraftingCommand,
      MobileCommandType.equipment => l10n.recoveryEquipmentCommand,
      MobileCommandType.itemUpgrade => l10n.recoveryItemUpgradeCommand,
      MobileCommandType.platformCommand => l10n.recoveryPlatformCommand,
    };
  }

  static String _pendingStatus(
    AppLocalizations l10n,
    MobileCommandFailureCategory? failureCategory,
  ) {
    return switch (failureCategory) {
      MobileCommandFailureCategory.rateLimited =>
        l10n.recoveryStatusRateLimited,
      MobileCommandFailureCategory.serverUnavailable =>
        l10n.recoveryStatusServerUnavailable,
      MobileCommandFailureCategory.connectionOrResponse =>
        l10n.recoveryStatusConnection,
      MobileCommandFailureCategory.rejected => l10n.recoveryStatusRejected,
      MobileCommandFailureCategory.invalidCommand => l10n.recoveryStatusInvalid,
      null => l10n.recoveryStatusPending,
    };
  }

  static String _formatTimestamp(DateTime value) {
    final DateTime local = value.toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _LaneChip extends StatelessWidget {
  const _LaneChip({required this.lane});

  final MobileCommandLane lane;

  @override
  Widget build(BuildContext context) {
    final String label = switch (lane) {
      MobileCommandLane.activity => context.l10n.recoveryLaneActivity,
      MobileCommandLane.gameplay => context.l10n.recoveryLaneGameplay,
      MobileCommandLane.telemetry => context.l10n.recoveryLaneTelemetry,
    };
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Color accent = switch (lane) {
      MobileCommandLane.activity => colors.primary,
      MobileCommandLane.gameplay => palette.energy,
      MobileCommandLane.telemetry => colors.onSurfaceVariant,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: accent.withValues(alpha: 0.1),
      side: BorderSide(color: accent.withValues(alpha: 0.34)),
      labelStyle: TextStyle(color: accent, fontWeight: FontWeight.w700),
      label: Text(label),
    );
  }
}

class _RecoveryCountBadge extends StatelessWidget {
  const _RecoveryCountBadge({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.accent,
    required this.onAccent,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color accent;
  final Color onAccent;

  @override
  Widget build(BuildContext context) {
    final String displayCount = count > 99 ? '99+' : '$count';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 7, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 7),
            DecoratedBox(
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: SizedBox.square(
                dimension: 24,
                child: Center(
                  child: Text(
                    displayCount,
                    textScaler: TextScaler.noScaling,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: onAccent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryCommandSurface extends StatelessWidget {
  const _RecoveryCommandSurface({
    required this.failed,
    required this.tone,
    required this.child,
  });

  final bool failed;
  final ExpeditionPanelTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!failed) {
      return ExpeditionPanel(tone: tone, child: child);
    }
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.error.withValues(alpha: 0.55)),
        color: Color.alphaBlend(
          colors.error.withValues(alpha: 0.08),
          colors.surfaceContainerHigh.withValues(alpha: 0.96),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

class _RecoveryLoading extends StatelessWidget {
  const _RecoveryLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ExpeditionPanel(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(
                key: Key('command-recovery-loading'),
              ),
              const SizedBox(width: 16),
              Flexible(child: Text(context.l10n.recoveryLoading)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryEmpty extends StatelessWidget {
  const _RecoveryEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ExpeditionPanel(
              tone: ExpeditionPanelTone.lumen,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.cloud_done_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.recoveryEmptyTitle,
                    key: const Key('command-recovery-empty'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.recoveryEmptyMessage,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecoveryStoreError extends StatelessWidget {
  const _RecoveryStoreError({
    required this.retrying,
    required this.onRetryRead,
  });

  final bool retrying;
  final VoidCallback onRetryRead;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ExpeditionPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.sync_problem_outlined,
                    size: 48,
                    color: colors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.recoveryStoreErrorTitle,
                    key: const Key('command-recovery-store-error'),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: colors.error),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.recoveryStoreErrorMessage,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: retrying ? null : onRetryRead,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.recoveryStoreRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
