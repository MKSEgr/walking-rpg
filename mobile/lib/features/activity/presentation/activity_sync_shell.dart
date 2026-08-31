import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/activity/application/activity_sync_coordinator.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/crew/presentation/crew_screen.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';
import 'package:walking_rpg_mobile/features/platform/presentation/platform_screen.dart';

typedef ActivitySynchronizer = Future<ActivitySyncResult> Function();
typedef ActivityHomeBuilder = Widget Function(Key key);

class ActivitySyncShell extends StatefulWidget {
  const ActivitySyncShell({
    super.key,
    this.synchronizer,
    this.homeBuilder,
    this.commandRuntime,
    this.homeLoader,
    this.platformLoader,
    this.platformHomeLoader,
    this.onOpenAccount,
    this.onOpenRecovery,
    this.recoveryCount = 0,
    this.recoveryUnavailable = false,
    this.onResumeFirstJourney,
    this.replayOnStart = false,
    this.authoritativeRefreshGeneration = 0,
  }) : assert(
         !replayOnStart || commandRuntime != null,
         'Startup replay requires a session-owned command runtime',
       );

  final ActivitySynchronizer? synchronizer;
  final ActivityHomeBuilder? homeBuilder;
  final MobileCommandRuntime? commandRuntime;
  final HomeSnapshotLoader? homeLoader;
  final PlatformSnapshotLoader? platformLoader;
  final PlatformHomeLoader? platformHomeLoader;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenRecovery;
  final int recoveryCount;
  final bool recoveryUnavailable;
  final VoidCallback? onResumeFirstJourney;
  final bool replayOnStart;
  final int authoritativeRefreshGeneration;

  @override
  State<ActivitySyncShell> createState() => _ActivitySyncShellState();
}

class _ActivitySyncShellState extends State<ActivitySyncShell> {
  ActivitySynchronizer? _synchronizer;
  MobileCommandRuntime? _commandRuntime;
  MobileCommandRuntime? _ownedCommandRuntime;
  MobileCommandRuntime? _scheduledRuntime;
  bool _demoActivitySync = false;
  int _homeGeneration = 0;
  int _crewGeneration = 0;
  int _platformGeneration = 0;
  bool _isSyncing = false;
  bool _isRecovering = false;
  int _selectedDestination = 0;

  @override
  void initState() {
    super.initState();
    _configureSynchronizer();
  }

  @override
  void didUpdateWidget(ActivitySyncShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authoritativeRefreshGeneration !=
            widget.authoritativeRefreshGeneration &&
        widget.homeBuilder != null) {
      _homeGeneration += 1;
      _crewGeneration += 1;
      _platformGeneration += 1;
    }
    if (oldWidget.synchronizer != widget.synchronizer ||
        oldWidget.homeBuilder != widget.homeBuilder ||
        oldWidget.commandRuntime != widget.commandRuntime ||
        oldWidget.replayOnStart != widget.replayOnStart) {
      if (!oldWidget.replayOnStart && widget.replayOnStart) {
        _scheduledRuntime = null;
      }
      _configureSynchronizer();
    }
  }

  @override
  void dispose() {
    _closeOwnedCommandRuntime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? activitySyncAction = _buildActivitySyncAction();
    final Widget home = _buildHome(activitySyncAction: activitySyncAction);
    if (activitySyncAction == null ||
        widget.homeBuilder == null ||
        _selectedDestination != 0) {
      return home;
    }

    return Stack(
      children: <Widget>[
        home,
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: ExpeditionPanel(
                  key: const Key('activity-sync-standalone-panel'),
                  tone: ExpeditionPanelTone.lumen,
                  padding: const EdgeInsets.all(8),
                  child: activitySyncAction,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHome({required Widget? activitySyncAction}) {
    final Key key = ValueKey<int>(_homeGeneration);
    final ActivityHomeBuilder? builder = widget.homeBuilder;
    if (builder != null) {
      return builder(key);
    }
    final MobileCommandRuntime? runtime = _commandRuntime;
    return MainNavigationShell(
      home: HomeScreen(
        key: ValueKey<String>('home-$_homeGeneration'),
        loader: widget.homeLoader,
        advancer: runtime?.advance,
        expeditionJourneyStarter: runtime?.beginNextJourney,
        eventResolver: runtime?.resolve,
        eventResultAcknowledger: runtime?.acknowledgeEventResult,
        crafter: runtime?.craft,
        itemUpgradeExecutor: runtime?.upgradeItem,
        equipmentExecutor: runtime?.changeEquipment,
        impressionRecorder: runtime?.executePlatform,
        onOpenAccount: widget.onOpenAccount,
        onOpenRecovery: widget.onOpenRecovery,
        recoveryCount: widget.recoveryCount,
        recoveryUnavailable: widget.recoveryUnavailable,
        authoritativeRefreshGeneration: widget.authoritativeRefreshGeneration,
        activitySyncAction: activitySyncAction,
      ),
      crew: CrewScreen(
        key: ValueKey<String>('crew-$_crewGeneration'),
        loader: widget.platformLoader,
        homeLoader: widget.platformHomeLoader,
        commandExecutor: runtime?.executePlatform,
        onServerStateChanged: _handleCrewStateChanged,
        onOpenAccount: widget.onOpenAccount,
        onOpenRecovery: widget.onOpenRecovery,
        recoveryCount: widget.recoveryCount,
        recoveryUnavailable: widget.recoveryUnavailable,
        authoritativeRefreshGeneration: widget.authoritativeRefreshGeneration,
      ),
      platform: PlatformScreen(
        key: ValueKey<String>('platform-$_platformGeneration'),
        loader: widget.platformLoader,
        homeLoader: widget.platformHomeLoader,
        commandExecutor: runtime?.executePlatform,
        onServerStateChanged: _handlePlatformStateChanged,
        onResumeFirstJourney: widget.onResumeFirstJourney,
        onOpenAccount: widget.onOpenAccount,
        onOpenRecovery: widget.onOpenRecovery,
        recoveryCount: widget.recoveryCount,
        recoveryUnavailable: widget.recoveryUnavailable,
        authoritativeRefreshGeneration: widget.authoritativeRefreshGeneration,
      ),
      onDestinationChanged: _handleDestinationChanged,
    );
  }

  Widget? _buildActivitySyncAction() {
    if (_synchronizer == null) {
      return null;
    }
    final bool busy = _isSyncing || _isRecovering;
    return _ActivitySyncAction(
      busy: busy,
      label: _isRecovering
          ? context.l10n.activityRecoveringCommands
          : _isSyncing
          ? context.l10n.activitySyncingSteps
          : _demoActivitySync
          ? context.l10n.activitySyncDemoSteps
          : context.l10n.activitySyncSteps,
      onPressed: _sync,
    );
  }

  void _configureSynchronizer() {
    final ActivitySynchronizer? injected = widget.synchronizer;
    if (widget.homeBuilder != null &&
        widget.commandRuntime == null &&
        injected == null) {
      _closeOwnedCommandRuntime();
      _commandRuntime = null;
      _synchronizer = null;
      _demoActivitySync = false;
      return;
    }
    if (injected != null) {
      _closeOwnedCommandRuntime();
      _commandRuntime = widget.commandRuntime;
      _synchronizer = injected;
      _demoActivitySync = false;
      _scheduleReplay();
      return;
    }

    final MobileCommandRuntime runtime;
    final MobileCommandRuntime? injectedRuntime = widget.commandRuntime;
    if (injectedRuntime != null) {
      _closeOwnedCommandRuntime();
      runtime = injectedRuntime;
    } else {
      runtime = _ownedCommandRuntime ??= MobileCommandRuntime.fromEnvironment();
    }
    final ActivitySyncCoordinator? coordinator =
        ActivitySyncCoordinator.fromEnvironmentIfSupported(
          sender: runtime.syncActivity,
        );
    if (coordinator == null) {
      _commandRuntime = runtime;
      _synchronizer = null;
      _demoActivitySync = false;
      _scheduleReplay();
      return;
    }

    _commandRuntime = runtime;
    _synchronizer = coordinator.synchronize;
    _demoActivitySync = AppEnvironment.enableDemoActivitySync;
    _scheduleReplay();
  }

  void _closeOwnedCommandRuntime() {
    final MobileCommandRuntime? runtime = _ownedCommandRuntime;
    if (runtime == null) {
      return;
    }
    _ownedCommandRuntime = null;
    if (identical(_commandRuntime, runtime)) {
      _commandRuntime = null;
    }
    if (identical(_scheduledRuntime, runtime)) {
      _scheduledRuntime = null;
    }
    unawaited(runtime.close());
  }

  void _scheduleReplay() {
    final MobileCommandRuntime? runtime = widget.commandRuntime;
    if (!widget.replayOnStart ||
        runtime == null ||
        !identical(_commandRuntime, runtime) ||
        identical(_scheduledRuntime, runtime)) {
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
      final MobileCommandReplayReport report = await runtime
          .replayPendingOnStart();
      if (!mounted ||
          !identical(_commandRuntime, runtime) ||
          !runtime.claimStartupReplayOutcome()) {
        return;
      }
      if (report.changedServerState) {
        setState(() {
          _homeGeneration += 1;
          _crewGeneration += 1;
          _platformGeneration += 1;
        });
      }
      if (report.hasMessages) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_replayMessage(report))));
      }
    } catch (error) {
      if (mounted &&
          identical(_commandRuntime, runtime) &&
          runtime.claimStartupReplayOutcome()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.activityStoreReadFailed)),
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
      parts.add(context.l10n.activityReplaySucceeded(report.succeeded));
    }
    if (report.retryableFailures > 0) {
      parts.add(context.l10n.activityReplayPending(report.pendingAfter));
    }
    if (report.failedAfter > 0) {
      parts.add(context.l10n.activityReplayFailed(report.failedAfter));
    }
    return context.l10n.activityReplaySummary(parts.join(' · '));
  }

  void _handleDestinationChanged(int index) {
    if (!mounted || _selectedDestination == index) {
      return;
    }
    setState(() {
      _selectedDestination = index;
    });
  }

  void _handlePlatformStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _homeGeneration += 1;
      _crewGeneration += 1;
    });
  }

  void _handleCrewStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _homeGeneration += 1;
      _platformGeneration += 1;
    });
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
          ? context.l10n.activityEnergyGranted(result.energyGranted)
          : context.l10n.activityNoNewEnergy;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.activitySyncAccepted(
              result.acceptedTotal,
              energyMessage,
            ),
          ),
        ),
      );
      setState(() {
        _homeGeneration += 1;
        _crewGeneration += 1;
        _platformGeneration += 1;
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.activitySyncFailed)),
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

class _ActivitySyncAction extends StatelessWidget {
  const _ActivitySyncAction({
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    return Semantics(
      key: const Key('activity-sync-status'),
      container: true,
      liveRegion: true,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('activity-sync-button'),
          onPressed: busy ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            foregroundColor: palette.energy,
            disabledForegroundColor: colors.onSurfaceVariant,
            backgroundColor: Color.alphaBlend(
              palette.energy.withValues(alpha: 0.07),
              colors.surfaceContainerHigh,
            ),
            disabledBackgroundColor: colors.surfaceContainerHigh.withValues(
              alpha: 0.74,
            ),
            side: BorderSide(
              color: busy
                  ? colors.outlineVariant
                  : palette.energy.withValues(alpha: 0.48),
            ),
          ),
          icon: busy
              ? SizedBox.square(
                  key: const Key('command-recovery-progress'),
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onSurfaceVariant,
                  ),
                )
              : const Icon(Icons.directions_walk_outlined),
          label: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
