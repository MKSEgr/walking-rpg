import 'package:flutter/material.dart';
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
  });

  final ActivitySynchronizer? synchronizer;
  final ActivityHomeBuilder? homeBuilder;

  @override
  State<ActivitySyncShell> createState() => _ActivitySyncShellState();
}

class _ActivitySyncShellState extends State<ActivitySyncShell> {
  ActivitySynchronizer? _synchronizer;
  String? _buttonLabel;
  int _homeGeneration = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _configureSynchronizer();
  }

  @override
  void didUpdateWidget(ActivitySyncShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.synchronizer != widget.synchronizer) {
      _configureSynchronizer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget home = _buildHome();
    if (_synchronizer == null || _buttonLabel == null) {
      return home;
    }

    return Stack(
      children: <Widget>[
        home,
        Positioned(
          right: 16,
          bottom: 20,
          child: SafeArea(
            child: FloatingActionButton.extended(
              key: const Key('activity-sync-button'),
              onPressed: _isSyncing ? null : _sync,
              icon: _isSyncing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                _isSyncing ? 'Синхронизация шагов...' : _buttonLabel!,
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
    return builder == null ? HomeScreen(key: key) : builder(key);
  }

  void _configureSynchronizer() {
    final ActivitySynchronizer? injected = widget.synchronizer;
    if (injected != null) {
      _synchronizer = injected;
      _buttonLabel = 'Синхронизировать шаги';
      return;
    }
    if (!AppEnvironment.enableDemoActivitySync) {
      _synchronizer = null;
      _buttonLabel = null;
      return;
    }
    final ActivitySyncCoordinator coordinator =
        ActivitySyncCoordinator.fromEnvironment();
    _synchronizer = coordinator.synchronize;
    _buttonLabel = 'Синхронизировать тестовые шаги';
  }

  Future<void> _sync() async {
    final ActivitySynchronizer? synchronizer = _synchronizer;
    if (_isSyncing || synchronizer == null) {
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
