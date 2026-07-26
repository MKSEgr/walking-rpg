import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/activity/application/activity_sync_coordinator.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';

typedef ActivitySynchronizer = Future<ActivitySyncResult> Function();
typedef ActivityHomeBuilder = Widget Function(Key key);

class ActivitySyncShell extends StatefulWidget {
  const ActivitySyncShell({
    super.key,
    this.synchronizer,
    this.homeBuilder,
    this.commandRuntime,
  });

  final ActivitySynchronizer? synchronizer;
  final ActivityHomeBuilder? homeBuilder;
  final MobileCommandRuntime? commandRuntime;

  @override
  State<ActivitySyncShell> createState() => _ActivitySyncShellState();
}

class _ActivitySyncShellState extends State<ActivitySyncShell> {
  ActivitySynchronizer? _synchronizer;
  MobileCommandRuntime? _commandRuntime;
  MobileCommandRuntime? _scheduledRuntime;
  String? _buttonLabel;
  int _homeGeneration = 0;
  bool _isSyncing = false;
  bool _isRecovering = false;

  @override
  void initState() {
    super.initState();
    _configureSynchronizer();
  }

  @override
  void didUpdateWidget(ActivitySyncShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.synchronizer != widget.synchronizer ||
        oldWidget.commandRuntime != widget.commandRuntime) {
      _configureSynchronizer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget home = _buildHome();
    if (_synchronizer == null || _buttonLabel == null) {
      return home;
    }

    final bool busy = _isSyncing || _isRecovering;
    return Stack(
      children: <Widget>[
        home,
        Positioned(
          right: 16,
          bottom: 20,
          child: SafeArea(
            child: FloatingActionButton.extended(
              key: const Key('activity-sync-button'),
              onPressed: busy ? null : _sync,
              icon: busy
                  ? const SizedBox.square(
                      key: Key('command-recovery-progress'),
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                _isRecovering
                    ? 'Восстановление команд...'
                    : _isSyncing
                    ? 'Синхронизация шагов...'
                    : _buttonLabel!,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHome() {
    final Key key = ValueKey<int>(_homeGeneration);
    final ActivityHomeBuilder? builder = widget.homeBuilder;
    if (builder != null) {
      return builder(key);
    }
    final MobileCommandRuntime? runtime = _commandRuntime;
    return HomeScreen(
      key: key,
      advancer: runtime?.advance,
      eventResolver: runtime?.resolve,
    );
  }

  void _configureSynchronizer() {
    final ActivitySynchronizer? injected = widget.synchronizer;
    if (injected != null) {
      _commandRuntime = widget.commandRuntime;
      _synchronizer = injected;
      _buttonLabel = 'Синхронизировать шаги';
      _scheduleReplay();
      return;
    }

    final MobileCommandRuntime runtime =
        widget.commandRuntime ?? MobileCommandRuntime.fromEnvironment();
    final ActivitySyncCoordinator? coordinator =
        ActivitySyncCoordinator.fromEnvironmentIfSupported(
          sender: runtime.syncActivity,
        );
    if (coordinator == null) {
      _commandRuntime = widget.commandRuntime;
      _synchronizer = null;
      _buttonLabel = null;
      _scheduleReplay();
      return;
    }

    _commandRuntime = runtime;
    _synchronizer = coordinator.synchronize;
    _buttonLabel = AppEnvironment.enableDemoActivitySync
        ? 'Синхронизировать тестовые шаги'
        : 'Синхронизировать шаги';
    _scheduleReplay();
  }

  void _scheduleReplay() {
    final MobileCommandRuntime? runtime = _commandRuntime;
    if (runtime == null || identical(_scheduledRuntime, runtime)) {
      return;
    }
    _scheduledRuntime = runtime;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted && identical(_commandRuntime, runtime)) {
        _replayPending(runtime);
      }
    });
  }

  Future<void> _replayPending(MobileCommandRuntime runtime) async {
    if (_isRecovering) {
      return;
    }
    setState(() {
      _isRecovering = true;
    });
    try {
      final MobileCommandReplayReport report = await runtime.replayPending();
      if (!mounted) {
        return;
      }
      if (report.changedServerState) {
        setState(() {
          _homeGeneration += 1;
        });
      }
      if (report.hasMessages) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_replayMessage(report))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось восстановить отложенные команды: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecovering = false;
        });
      }
    }
  }

  String _replayMessage(MobileCommandReplayReport report) {
    final List<String> parts = <String>[];
    if (report.succeeded > 0) {
      parts.add('восстановлено: ${report.succeeded}');
    }
    if (report.retryableFailures > 0) {
      parts.add('ждут повторной отправки: ${report.pendingAfter}');
    }
    if (report.permanentFailures > 0) {
      parts.add('отклонено сервером: ${report.permanentFailures}');
    }
    return 'Отложенные команды · ${parts.join(' · ')}';
  }

  Future<void> _sync() async {
    final ActivitySynchronizer? synchronizer = _synchronizer;
    if (_isSyncing || _isRecovering || synchronizer == null) {
      return;
    }

    setState(() {
      _isSyncing = true;
    });
    try {
      final ActivitySyncResult result = await synchronizer();
      if (!mounted) {
        return;
      }
      final String energyMessage = result.energyGranted > 0
          ? '+${result.energyGranted} ENERGY'
          : 'новой энергии нет';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Принято ${result.acceptedTotal} шагов · $energyMessage',
          ),
        ),
      );
      setState(() {
        _homeGeneration += 1;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось синхронизировать шаги: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
}
