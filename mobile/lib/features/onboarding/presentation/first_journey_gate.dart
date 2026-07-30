import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';
import 'package:walking_rpg_mobile/features/onboarding/presentation/first_journey_screen.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_action.dart';

typedef FirstJourneyHomeLoader = Future<HomeSnapshot> Function();
typedef FirstJourneyPlatformLoader = Future<PlatformSnapshot> Function();
typedef FirstJourneyActivitySynchronizer =
    Future<ActivitySyncResult> Function();
typedef FirstJourneyChildBuilder = Widget Function(VoidCallback onResume);

class FirstJourneyGate extends StatefulWidget {
  const FirstJourneyGate({
    super.key,
    required this.homeLoader,
    required this.platformLoader,
    required this.commandRuntime,
    required this.childBuilder,
    this.synchronizer,
    this.onOpenAccount,
    this.onOpenRecovery,
    this.recoveryCount = 0,
    this.recoveryUnavailable = false,
    this.authoritativeRefreshGeneration = 0,
  });

  final FirstJourneyHomeLoader homeLoader;
  final FirstJourneyPlatformLoader platformLoader;
  final MobileCommandRuntime commandRuntime;
  final FirstJourneyChildBuilder childBuilder;
  final FirstJourneyActivitySynchronizer? synchronizer;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenRecovery;
  final int recoveryCount;
  final bool recoveryUnavailable;
  final int authoritativeRefreshGeneration;

  @override
  State<FirstJourneyGate> createState() => _FirstJourneyGateState();
}

class _FirstJourneyGateState extends State<FirstJourneyGate> {
  late Future<FirstJourneyProgress> _progressFuture;
  final Set<String> _attemptedBackfills = <String>{};
  FirstJourneyProgress? _lastProgress;

  bool _showMainExperience = false;
  bool _busy = false;
  ActivitySyncResult? _activityReward;
  EventResolutionResult? _eventReward;
  String? _errorMessage;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _progressFuture = _prepareProgress();
  }

  @override
  void didUpdateWidget(FirstJourneyGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandRuntime != widget.commandRuntime) {
      _attemptedBackfills.clear();
      _lastProgress = null;
      _progressFuture = _prepareProgress();
      return;
    }
    if (oldWidget.homeLoader != widget.homeLoader ||
        oldWidget.platformLoader != widget.platformLoader ||
        oldWidget.authoritativeRefreshGeneration !=
            widget.authoritativeRefreshGeneration) {
      _attemptedBackfills.clear();
      _activityReward = null;
      _eventReward = null;
      _errorMessage = null;
      _notice = null;
      if (!_showMainExperience && _lastProgress?.complete != true) {
        _progressFuture = _loadProgress();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showMainExperience) {
      return widget.childBuilder(_resume);
    }
    return FutureBuilder<FirstJourneyProgress>(
      future: _progressFuture,
      builder:
          (BuildContext context, AsyncSnapshot<FirstJourneyProgress> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _FirstJourneyLoading();
            }
            if (snapshot.error is _FirstJourneyPreparationAbandoned) {
              return const _FirstJourneyLoading();
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _FirstJourneyLoadError(
                error: snapshot.error,
                onRetry: _reload,
                onContinueLater: _continueLater,
                onOpenAccount: widget.onOpenAccount,
                onOpenRecovery: widget.onOpenRecovery,
                recoveryCount: widget.recoveryCount,
                recoveryUnavailable: widget.recoveryUnavailable,
              );
            }
            final FirstJourneyProgress progress = snapshot.data!;
            _lastProgress = progress;
            _scheduleFactBackfill(progress);
            if (progress.complete &&
                _eventReward == null &&
                _activityReward == null) {
              return widget.childBuilder(_resume);
            }
            return FirstJourneyScreen(
              progress: progress,
              busy: _busy,
              activityReward: _activityReward,
              eventReward: _eventReward,
              errorMessage: _errorMessage,
              notice: _notice,
              onWelcome: () => _completeWelcome(progress),
              onSync: () => _syncActivity(progress),
              onSelectPet: (String petId) => _selectPet(progress, petId),
              onAdvance: () => _advance(progress),
              onResolve: (HomeEventChoice choice) => _resolve(progress, choice),
              onContinueAfterActivity: _continueAfterActivityReward,
              onFinish: () {
                unawaited(_finish());
              },
              onContinueLater: _continueLater,
              onOpenAccount: widget.onOpenAccount,
              onOpenRecovery: widget.onOpenRecovery,
              recoveryCount: widget.recoveryCount,
              recoveryUnavailable: widget.recoveryUnavailable,
            );
          },
    );
  }

  Future<FirstJourneyProgress> _prepareProgress() async {
    final MobileCommandRuntime runtime = widget.commandRuntime;
    late final MobileCommandReplayReport report;
    try {
      report = await runtime.replayPendingOnStart();
    } on Object {
      if (!mounted ||
          !identical(widget.commandRuntime, runtime) ||
          runtime.isClosed) {
        throw const _FirstJourneyPreparationAbandoned();
      }
      if (!runtime.claimStartupReplayOutcome()) {
        return _loadProgress();
      }
      rethrow;
    }
    if (!mounted ||
        !identical(widget.commandRuntime, runtime) ||
        runtime.isClosed) {
      throw const _FirstJourneyPreparationAbandoned();
    }
    if (!runtime.claimStartupReplayOutcome()) {
      return _loadProgress();
    }
    _notice = null;
    if (report.retryableFailures > 0) {
      _notice =
          'Часть сохранённых действий ждёт соединения. '
          'Открой «Сохранённые действия» для безопасного повтора.';
    } else if (report.permanentFailures > 0) {
      _notice =
          'Одно из ранее сохранённых действий отклонено сервером. '
          'Проверь текущее состояние.';
    }
    return _loadProgress();
  }

  Future<FirstJourneyProgress> _loadProgress() async {
    final List<Object> values = await Future.wait<Object>(<Future<Object>>[
      widget.homeLoader(),
      widget.platformLoader(),
    ]);
    return FirstJourneyProgress(
      home: values[0] as HomeSnapshot,
      platform: values[1] as PlatformSnapshot,
    );
  }

  void _scheduleFactBackfill(FirstJourneyProgress progress) {
    if (_busy || progress.readOnly) {
      return;
    }
    final List<String> pending = progress.pendingFactMilestones
        .where((String step) => _attemptedBackfills.add(step))
        .toList(growable: false);
    if (pending.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        unawaited(_backfill(pending));
      }
    });
  }

  Future<void> _backfill(List<String> steps) async {
    for (final String step in steps) {
      try {
        await _recordMilestone(step);
      } on Object {
        if (mounted) {
          setState(() {
            _notice =
                'Игровой прогресс восстановлен. Служебная отметка '
                'синхронизируется при следующем подключении.';
          });
        }
        return;
      }
    }
    if (mounted) {
      _reloadProgressWithoutReplay();
    }
  }

  Future<void> _completeWelcome(FirstJourneyProgress progress) {
    return _runAction(() async {
      await _recordMilestone(FirstJourneyProgress.welcomeStep);
      _triggerHaptic(HapticFeedback.selectionClick());
      await _refreshProgress();
    });
  }

  Future<void> _syncActivity(FirstJourneyProgress progress) {
    return _runAction(() async {
      final FirstJourneyActivitySynchronizer? synchronizer =
          widget.synchronizer;
      if (synchronizer == null) {
        throw StateError(
          'Источник шагов недоступен на этом устройстве или в этой сборке.',
        );
      }
      final ActivitySyncResult result = await synchronizer();
      if (!mounted) {
        return;
      }
      setState(() {
        _activityReward = result;
      });
      await _recordMilestone(FirstJourneyProgress.healthPermissionStep);
      await _recordMilestone(FirstJourneyProgress.firstSyncStep);
      _triggerHaptic(HapticFeedback.mediumImpact());
      await _refreshProgress();
    });
  }

  Future<void> _selectPet(FirstJourneyProgress progress, String petId) {
    return _runAction(() async {
      await widget.commandRuntime.executePlatform(
        commandType: 'SELECT_PET',
        payload: <String, Object?>{'petId': petId},
        idempotencyKey:
            'first-journey-select-${progress.platform.stateVersion}-$petId-v1',
      );
      _triggerHaptic(HapticFeedback.selectionClick());
      await _refreshProgress();
    });
  }

  Future<void> _advance(FirstJourneyProgress progress) {
    return _runAction(() async {
      final HomeSnapshot home = progress.home;
      final int energy = home.spendableEnergy;
      if (energy <= 0) {
        throw StateError('Сначала синхронизируй новые шаги.');
      }
      final result = await widget.commandRuntime.advance(
        expeditionId: home.expeditionId,
        energyToSpend: energy,
        idempotencyKey:
            'first-journey-advance-${home.expeditionVersion}-$energy',
      );
      if (result.unlockedEvent != null) {
        await _recordMilestone(FirstJourneyProgress.firstExpeditionStep);
        _triggerHaptic(HapticFeedback.mediumImpact());
      } else {
        _triggerHaptic(HapticFeedback.selectionClick());
      }
      await _refreshProgress();
    });
  }

  Future<void> _resolve(FirstJourneyProgress progress, HomeEventChoice choice) {
    return _runAction(() async {
      final HomeExpeditionEvent? event = progress.home.unlockedEvent;
      if (event == null) {
        throw StateError('Событие ещё не загружено.');
      }
      final EventResolutionResult result = await widget.commandRuntime.resolve(
        eventId: event.eventId,
        choiceId: choice.choiceId,
        idempotencyKey:
            'first-journey-event-${event.eventId}-${choice.choiceId}-v1',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _eventReward = result;
      });
      await _recordMilestone(FirstJourneyProgress.firstEventStep);
      _triggerHaptic(HapticFeedback.heavyImpact());
      await _refreshProgress();
    });
  }

  void _triggerHaptic(Future<void> feedback) {
    unawaited(feedback.catchError((Object _) {}));
  }

  Future<void> _recordMilestone(String step) {
    return widget.commandRuntime
        .executePlatform(
          commandType: 'COMPLETE_ONBOARDING_STEP',
          payload: <String, Object?>{'stepId': step},
          idempotencyKey: 'first-journey-milestone-$step-v1',
        )
        .then<void>((_) {});
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refreshProgress() async {
    final FirstJourneyProgress progress = await _loadProgress();
    if (!mounted) {
      return;
    }
    setState(() {
      _progressFuture = Future<FirstJourneyProgress>.value(progress);
    });
  }

  void _continueAfterActivityReward() {
    if (_busy) {
      return;
    }
    setState(() {
      _activityReward = null;
      _errorMessage = null;
    });
  }

  Future<void> _finish() async {
    if (_busy) {
      return;
    }
    final EventResolutionResult? result = _eventReward;
    if (result == null) {
      setState(() {
        _activityReward = null;
        _showMainExperience = true;
        _errorMessage = null;
      });
      return;
    }
    if (!result.handoffRequired) {
      setState(() {
        _eventReward = null;
        _activityReward = null;
        _showMainExperience = true;
        _errorMessage = null;
      });
      return;
    }
    final String? receiptId = result.receiptId;
    if (receiptId == null || receiptId.isEmpty) {
      setState(() {
        _errorMessage =
            'Backend подтвердил durable handoff без result receipt.';
      });
      return;
    }
    await _runAction(() async {
      await widget.commandRuntime.acknowledgeEventResult(
        receiptId: receiptId,
        idempotencyKey: 'first-journey-event-result-$receiptId-ack-v1',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _eventReward = null;
        _activityReward = null;
        _showMainExperience = true;
        _errorMessage = null;
      });
    });
  }

  void _continueLater() {
    if (_busy) {
      return;
    }
    setState(() {
      _showMainExperience = true;
      _errorMessage = null;
    });
  }

  void _resume() {
    setState(() {
      _attemptedBackfills.clear();
      _lastProgress = null;
      _showMainExperience = false;
      _activityReward = null;
      _eventReward = null;
      _errorMessage = null;
      _progressFuture = _loadProgress();
    });
  }

  void _reload() {
    if (_busy) {
      return;
    }
    setState(() {
      _attemptedBackfills.clear();
      _lastProgress = null;
      _errorMessage = null;
      _progressFuture = _loadProgress();
    });
  }

  void _reloadProgressWithoutReplay() {
    setState(() {
      _lastProgress = null;
      _errorMessage = null;
      _progressFuture = _loadProgress();
    });
  }

  String _friendlyError(Object error) {
    final String text = error.toString().replaceFirst(
      RegExp(r'^(Exception|StateError):\s*'),
      '',
    );
    return text.isEmpty ? 'Не удалось выполнить действие.' : text;
  }
}

final class _FirstJourneyPreparationAbandoned implements Exception {
  const _FirstJourneyPreparationAbandoned();
}

class _FirstJourneyLoading extends StatelessWidget {
  const _FirstJourneyLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Восстанавливаем маршрут...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstJourneyLoadError extends StatelessWidget {
  const _FirstJourneyLoadError({
    required this.error,
    required this.onRetry,
    required this.onContinueLater,
    this.onOpenAccount,
    this.onOpenRecovery,
    this.recoveryCount = 0,
    this.recoveryUnavailable = false,
  });

  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onContinueLater;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenRecovery;
  final int recoveryCount;
  final bool recoveryUnavailable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Первый путь'),
        actions: <Widget>[
          MobileCommandRecoveryAction(
            key: const Key('first-journey-load-recovery'),
            onPressed: onOpenRecovery,
            count: recoveryCount,
            unavailable: recoveryUnavailable,
          ),
          IconButton(
            tooltip: 'Аккаунт',
            onPressed: onOpenAccount,
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.cloud_off_outlined, size: 48),
                      const SizedBox(height: 14),
                      Text(
                        'Не удалось восстановить первый путь',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error?.toString() ?? 'Состояние недоступно.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        key: const Key('first-journey-retry'),
                        onPressed: onRetry,
                        child: const Text('Повторить'),
                      ),
                      TextButton(
                        onPressed: onContinueLater,
                        child: const Text('Открыть игру'),
                      ),
                    ],
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
