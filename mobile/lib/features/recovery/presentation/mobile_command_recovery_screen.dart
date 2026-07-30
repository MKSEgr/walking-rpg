import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_recovery.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';

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
      body: SafeArea(
        child: FutureBuilder<MobileCommandRecoverySnapshot>(
          future: _snapshotFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<MobileCommandRecoverySnapshot> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      key: Key('command-recovery-loading'),
                    ),
                  );
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
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _RecoverySummary(snapshot: snapshot),
        const SizedBox(height: 12),
        if (snapshot.pendingCount > 0) ...<Widget>[
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
          const SizedBox(height: 12),
        ],
        for (final MobileCommandRecoveryItem item
            in snapshot.items) ...<Widget>[
          _RecoveryCommandCard(
            item: item,
            dismissing: dismissing.contains(item),
            onDismiss: () => onDismiss(item),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        Text(
          'Ожидающие действия нельзя удалить: ответ мог потеряться уже после '
          'выполнения на сервере. Повтор всегда использует исходную команду.',
          style: Theme.of(context).textTheme.bodySmall,
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
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const Icon(Icons.cloud_sync_outlined, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Локальная очередь',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ожидают отправки: ${snapshot.pendingCount} · '
                    'отклонены: ${snapshot.failedCount}',
                  ),
                ],
              ),
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
    return Card(
      color: failed ? colors.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  failed ? Icons.error_outline : Icons.schedule_send_outlined,
                  color: failed ? colors.onErrorContainer : colors.primary,
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
                      ),
                    ],
                  ),
                ),
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
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
    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }
}

class _RecoveryEmpty extends StatelessWidget {
  const _RecoveryEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                'Локальная очередь пуста. Игровое состояние читается с сервера.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.sync_problem_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Не удалось прочитать сохранённые действия',
                    key: const Key('command-recovery-store-error'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Очередь не была очищена или перезаписана. '
                    'Повтори чтение; если ошибка останется, передай её в поддержку.',
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
      ),
    );
  }
}
