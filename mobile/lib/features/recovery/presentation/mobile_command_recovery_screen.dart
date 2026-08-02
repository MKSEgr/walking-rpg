import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_recovery.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

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
        title: const Text('Сохранённые действия'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Обновить список',
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
          const SnackBar(
            content: Text(
              'Не удалось повторить сохранённые действия. '
              'Записи не удалены.',
            ),
          ),
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
            return AlertDialog(
              title: const Text('Убрать отклонённую запись?'),
              content: const Text(
                'Команда уже не повторяется и не блокирует очередь. '
                'Удалится только локальная диагностическая запись; '
                'состояние на сервере не изменится.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  key: const Key('command-recovery-dismiss-confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Убрать запись'),
                ),
              ],
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
          const SnackBar(
            content: Text(
              'Действие снова ожидает отправки и не может быть удалено.',
            ),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось убрать запись. Локальные данные сохранены.',
            ),
          ),
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
        return 'Критичные действия проверены. '
            'Служебная отправка продолжается.';
      }
      return 'Действий для повторной отправки нет.';
    }
    final List<String> parts = <String>[
      if (report.succeeded > 0) 'отправлено: ${report.succeeded}',
      if (report.pendingAfter > 0) 'ожидают сети: ${report.pendingAfter}',
      if (report.permanentFailures > 0)
        'отклонено: ${report.permanentFailures}',
    ];
    return 'Проверка очереди · ${parts.join(' · ')}';
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
                          ? 'Повторяем сохранённые действия...'
                          : 'Повторить ожидающие действия',
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const ExpeditionSectionTitle(
                  title: 'Журнал очереди',
                  subtitle: 'Только локально сохранённые команды этого пилота',
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
                      const Expanded(
                        child: Text(
                          'Ожидающие действия нельзя удалить: ответ мог '
                          'потеряться уже после выполнения на сервере. Повтор '
                          'всегда использует исходную команду.',
                        ),
                      ),
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
      label:
          'Контур восстановления. Ожидают отправки: '
          '${snapshot.pendingCount}. Отклонены: ${snapshot.failedCount}.',
      child: ExpeditionPanel(
        tone: tone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'КОНТУР ВОССТАНОВЛЕНИЯ',
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
              'Локальная очередь',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Команды сохраняются до отправки и остаются привязаны к '
              'текущему владельцу сессии.',
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
                  label: 'Ожидают отправки',
                  count: snapshot.pendingCount,
                  icon: Icons.schedule_send_outlined,
                  accent: palette.energy,
                  onAccent: palette.onEnergy,
                ),
                _RecoveryCountBadge(
                  key: const Key('command-recovery-failed-count'),
                  label: 'Отклонены',
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
                      _commandLabel(item),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      failed
                          ? 'Отклонено и больше не отправляется'
                          : item.attemptCount == 0
                          ? 'Сохранено перед первой отправкой'
                          : _pendingStatus(item.failureCategory),
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
            'Попыток: ${item.attemptCount} · '
            'создано ${_formatTimestamp(item.createdAt)}',
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
              label: const Text('Убрать диагностическую запись'),
            ),
          ],
        ],
      ),
    );
  }

  static String _commandLabel(MobileCommandRecoveryItem item) {
    if (item.lane == MobileCommandLane.telemetry) {
      return 'Служебная телеметрия';
    }
    return switch (item.type) {
      MobileCommandType.activitySync => 'Синхронизация шагов',
      MobileCommandType.expeditionAdvance => 'Продвижение экспедиции',
      MobileCommandType.eventResolution => 'Выбор в событии',
      MobileCommandType.eventResultAcknowledgement =>
        'Подтверждение результата события',
      MobileCommandType.crafting => 'Создание предмета',
      MobileCommandType.equipment => 'Изменение снаряжения',
      MobileCommandType.platformCommand => 'Изменение путевого журнала',
    };
  }

  static String _pendingStatus(MobileCommandFailureCategory? failureCategory) {
    return switch (failureCategory) {
      MobileCommandFailureCategory.rateLimited =>
        'Сервер попросил повторить позже',
      MobileCommandFailureCategory.serverUnavailable =>
        'Сервер временно недоступен',
      MobileCommandFailureCategory.connectionOrResponse =>
        'Ожидает восстановления соединения',
      MobileCommandFailureCategory.rejected =>
        'Ожидает безопасной повторной проверки',
      MobileCommandFailureCategory.invalidCommand =>
        'Требует проверки сохранённых данных',
      null => 'Ожидает повторной отправки',
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
      MobileCommandLane.activity => 'Шаги',
      MobileCommandLane.gameplay => 'Игра',
      MobileCommandLane.telemetry => 'Сервис',
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
        child: const ExpeditionPanel(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(key: Key('command-recovery-loading')),
              SizedBox(width: 16),
              Flexible(child: Text('Читаем локальную очередь...')),
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
                    'Все действия отправлены',
                    key: const Key('command-recovery-empty'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Локальная очередь пуста. Игровое состояние читается с '
                    'сервера.',
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
                    'Не удалось прочитать сохранённые действия',
                    key: const Key('command-recovery-store-error'),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: colors.error),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Очередь не была очищена или перезаписана. Повтори чтение; '
                    'если ошибка останется, передай её в поддержку.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: retrying ? null : onRetryRead,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить чтение'),
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
