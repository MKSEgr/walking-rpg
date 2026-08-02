import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_recovery.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';
import 'package:walking_rpg_mobile/features/account/data/account_api_client.dart';
import 'package:walking_rpg_mobile/features/account/presentation/account_screen.dart';
import 'package:walking_rpg_mobile/features/activity/application/activity_sync_coordinator.dart';
import 'package:walking_rpg_mobile/features/activity/data/activity_api_client.dart';
import 'package:walking_rpg_mobile/features/activity/data/platform_health_step_source.dart';
import 'package:walking_rpg_mobile/features/activity/presentation/activity_sync_shell.dart';
import 'package:walking_rpg_mobile/features/auth/presentation/auth_expedition_screen.dart';
import 'package:walking_rpg_mobile/features/crafting/data/crafting_api_client.dart';
import 'package:walking_rpg_mobile/features/equipment/data/equipment_api_client.dart';
import 'package:walking_rpg_mobile/features/event/data/event_api_client.dart';
import 'package:walking_rpg_mobile/features/expedition/data/expedition_api_client.dart';
import 'package:walking_rpg_mobile/features/home/data/auth_home_transports.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';
import 'package:walking_rpg_mobile/features/onboarding/presentation/first_journey_gate.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_screen.dart';
import 'package:walking_rpg_mobile/features/validation/application/validation_evidence_controller.dart';
import 'package:walking_rpg_mobile/features/validation/presentation/validation_center_screen.dart';
import 'package:walking_rpg_mobile/features/validation/validation_center_policy.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.controller,
    required this.cache,
    required this.commandStore,
  });

  final AuthSessionController controller;
  final ReadSnapshotCache cache;
  final MobileCommandStore commandStore;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  NavigatorState? _rootNavigator;
  bool _authenticatedRoutesDismissScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleAuthStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
  }

  @override
  void didUpdateWidget(AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleAuthStateChanged);
      widget.controller.addListener(_handleAuthStateChanged);
      _authenticatedRoutesDismissScheduled = false;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleAuthStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        switch (widget.controller.state) {
          case AuthLifecycleState.initializing:
          case AuthLifecycleState.stoppingRuntime:
            return const _AuthProgressScreen();
          case AuthLifecycleState.unauthenticated:
          case AuthLifecycleState.reauthenticationRequired:
          case AuthLifecycleState.authenticating:
            return _LoginScreen(controller: widget.controller);
          case AuthLifecycleState.authenticated:
            final AuthIdentity? identity = widget.controller.identity;
            if (identity == null) {
              return const _AuthProgressScreen();
            }
            return AuthenticatedApplicationShell(
              key: ValueKey<String>(identity.ownerId),
              controller: widget.controller,
              identity: identity,
              cache: widget.cache,
              commandStore: widget.commandStore,
            );
        }
      },
    );
  }

  void _handleAuthStateChanged() {
    if (widget.controller.state == AuthLifecycleState.authenticated) {
      _authenticatedRoutesDismissScheduled = false;
      return;
    }
    if (_authenticatedRoutesDismissScheduled) {
      return;
    }
    _authenticatedRoutesDismissScheduled = true;
    final NavigatorState? navigator = _rootNavigator;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (navigator?.mounted ?? false) {
        navigator!.popUntil((Route<Object?> route) => route.isFirst);
      }
    });
  }
}

class AuthenticatedApplicationShell extends StatefulWidget {
  const AuthenticatedApplicationShell({
    super.key,
    required this.controller,
    required this.identity,
    required this.cache,
    required this.commandStore,
  });

  final AuthSessionController controller;
  final AuthIdentity identity;
  final ReadSnapshotCache cache;
  final MobileCommandStore commandStore;

  @override
  State<AuthenticatedApplicationShell> createState() =>
      _AuthenticatedApplicationShellState();
}

class _AuthenticatedApplicationShellState
    extends State<AuthenticatedApplicationShell> {
  late final HomeApiClient _homeClient;
  late final PlatformApiClient _platformClient;
  late final AccountApiClient _accountClient;
  late final MobileCommandRuntime _runtime;
  late final ActivitySyncCoordinator? _coordinator;
  late final FirstJourneyHomeLoader _homeLoader;
  late final FirstJourneyPlatformLoader _platformLoader;
  late final FirstJourneyActivitySynchronizer? _synchronizer;
  ValidationEvidenceController? _validationController;
  bool _validationMetadataFailed = false;
  bool _validationMetadataReady = !ValidationCenterPolicy.enabled;
  late final RuntimeStopper _runtimeStopper;
  StreamSubscription<void>? _commandChangesSubscription;
  int _recoveryCount = 0;
  bool _recoveryUnavailable = false;
  int _recoveryLoadGeneration = 0;
  int _authoritativeRefreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    final MobileAuthConfiguration configuration =
        widget.controller.configuration;
    final HomeTransport transport = configuration.mode == MobileAuthMode.oidc
        ? BearerHomeTransport(
            apiBaseUri: configuration.apiBaseUri,
            inner: const IoHomeTransport(),
            tokenProvider: widget.controller,
          )
        : DevelopmentHeaderHomeTransport(
            userId: configuration.developmentUserId!,
            deviceId: configuration.developmentDeviceId!,
          );

    _homeClient = HomeApiClient(
      baseUri: configuration.apiBaseUri,
      userId: widget.identity.ownerId,
      transport: transport,
      cache: widget.cache,
    );
    final ActivityApiClient activityClient = ActivityApiClient(
      baseUri: configuration.apiBaseUri,
      userId: widget.identity.ownerId,
      transport: transport,
      cache: widget.cache,
    );
    final ExpeditionApiClient expeditionClient = ExpeditionApiClient(
      baseUri: configuration.apiBaseUri,
      userId: widget.identity.ownerId,
      transport: transport,
      cache: widget.cache,
    );
    final EventApiClient eventClient = EventApiClient(
      baseUri: configuration.apiBaseUri,
      userId: widget.identity.ownerId,
      transport: transport,
      cache: widget.cache,
    );
    final CraftingApiClient craftingClient = CraftingApiClient(
      baseUri: configuration.apiBaseUri,
      userId: widget.identity.ownerId,
      transport: transport,
      cache: widget.cache,
    );
    final EquipmentApiClient equipmentClient = EquipmentApiClient(
      baseUri: configuration.apiBaseUri,
      userId: widget.identity.ownerId,
      transport: transport,
      cache: widget.cache,
    );
    _platformClient = PlatformApiClient(
      baseUri: configuration.apiBaseUri,
      userId: widget.identity.ownerId,
      transport: transport,
      cache: widget.cache,
    );
    _accountClient = AccountApiClient(
      baseUri: configuration.apiBaseUri,
      transport: transport,
    );
    _runtime = MobileCommandRuntime(
      ownerId: widget.identity.ownerId,
      store: widget.commandStore,
      activitySender: activityClient.sync,
      expeditionSender: expeditionClient.advance,
      eventSender: eventClient.resolve,
      eventResultAcknowledgementSender: eventClient.acknowledge,
      craftingSender: craftingClient.craft,
      equipmentSender: equipmentClient.change,
      platformSender: _platformClient.execute,
    );
    _coordinator = ActivitySyncCoordinator.fromEnvironmentIfSupported(
      sender: _runtime.syncActivity,
    );
    _homeLoader = () => _homeClient.fetchHome(DateTime.now());
    _platformLoader = _platformClient.fetchSnapshot;
    _synchronizer = _coordinator?.synchronize;
    if (ValidationCenterPolicy.enabled) {
      unawaited(_initializeValidationController(configuration));
    }
    _runtimeStopper = _runtime.close;
    widget.controller.registerRuntimeStopper(_runtimeStopper);
    _commandChangesSubscription = _runtime.changes.listen((void _) {
      unawaited(_refreshRecoveryStatus());
    });
    unawaited(_refreshRecoveryStatus());
  }

  @override
  void dispose() {
    widget.controller.unregisterRuntimeStopper(_runtimeStopper);
    _validationController?.dispose();
    unawaited(_commandChangesSubscription?.cancel());
    unawaited(_runtime.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_validationMetadataReady) {
      return const _ValidationMetadataProgressScreen();
    }
    if (_validationMetadataFailed) {
      return const _ValidationMetadataErrorScreen();
    }
    return FirstJourneyGate(
      homeLoader: _homeLoader,
      platformLoader: _platformLoader,
      commandRuntime: _runtime,
      authoritativeRefreshGeneration: _authoritativeRefreshGeneration,
      synchronizer: _synchronizer,
      onOpenAccount: _openAccount,
      onOpenRecovery: _openRecovery,
      recoveryCount: _recoveryCount,
      recoveryUnavailable: _recoveryUnavailable,
      childBuilder: (VoidCallback onResumeFirstJourney) {
        return ActivitySyncShell(
          synchronizer: _synchronizer,
          commandRuntime: _runtime,
          replayOnStart: false,
          authoritativeRefreshGeneration: _authoritativeRefreshGeneration,
          homeLoader: _homeLoader,
          platformLoader: _platformLoader,
          platformHomeLoader: _homeLoader,
          onOpenAccount: _openAccount,
          onOpenRecovery: _openRecovery,
          recoveryCount: _recoveryCount,
          recoveryUnavailable: _recoveryUnavailable,
          onResumeFirstJourney: onResumeFirstJourney,
        );
      },
    );
  }

  Future<void> _initializeValidationController(
    MobileAuthConfiguration configuration,
  ) async {
    final int sessionRevision = widget.controller.sessionRevision;
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String operatingSystemVersion = await _loadOperatingSystemVersion();
      ValidationCenterPolicy.validateRuntimePackage(
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );
      final Object? validationStepSource = _coordinator?.stepSource;
      final ValidationEvidenceController controller =
          ValidationEvidenceController(
            ownerId: widget.identity.ownerId,
            activeOwnerProvider: () => widget.controller.identity?.ownerId,
            sessionRevision: sessionRevision,
            activeSessionRevisionProvider: () =>
                widget.controller.sessionRevision,
            launch: createValidationLaunchMetadata(
              authenticationMode: configuration.mode.name,
              appVersion: packageInfo.version,
              buildNumber: packageInfo.buildNumber,
              operatingSystemVersion: operatingSystemVersion,
            ),
            stepReader: _coordinator?.stepSource.read,
            synchronizer: _coordinator?.synchronizeReading,
            homeLoader: _homeLoader,
            platformLoader: _platformLoader,
            includeManualEntries:
                validationStepSource is PlatformHealthStepSource &&
                validationStepSource.includeManualEntries,
          );
      if (!mounted ||
          widget.controller.state != AuthLifecycleState.authenticated ||
          widget.controller.identity?.ownerId != widget.identity.ownerId ||
          widget.controller.sessionRevision != sessionRevision) {
        controller.dispose();
        return;
      }
      setState(() {
        _validationController = controller;
        _validationMetadataReady = true;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _validationMetadataFailed = true;
        _validationMetadataReady = true;
      });
    }
  }

  Future<String> _loadOperatingSystemVersion() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      return (await deviceInfo.androidInfo).version.release;
    }
    if (Platform.isIOS) {
      return (await deviceInfo.iosInfo).systemVersion;
    }
    return Platform.operatingSystemVersion;
  }

  void _openAccount() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AccountScreen(
          controller: widget.controller,
          identity: widget.identity,
          apiClient: _accountClient,
          commandRuntime: _runtime,
          onOpenRecovery: _openRecovery,
          onOpenValidation: _validationController == null
              ? null
              : _openValidation,
          recoveryCount: _recoveryCount,
          recoveryUnavailable: _recoveryUnavailable,
        ),
      ),
    );
  }

  Future<void> _openValidation() async {
    final ValidationEvidenceController? controller = _validationController;
    if (controller == null || !mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ValidationCenterScreen(
          controller: controller,
          activeOwnerProvider: () => widget.controller.identity?.ownerId,
        ),
      ),
    );
  }

  Future<void> _openRecovery() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MobileCommandRecoveryScreen(
          runtime: _runtime,
          onServerStateChanged: _handleRecoveredServerState,
        ),
      ),
    );
    if (mounted) {
      await _refreshRecoveryStatus();
    }
  }

  void _handleRecoveredServerState() {
    if (!mounted) {
      return;
    }
    setState(() {
      _authoritativeRefreshGeneration += 1;
    });
  }

  Future<void> _refreshRecoveryStatus() async {
    final int generation = ++_recoveryLoadGeneration;
    try {
      final MobileCommandRecoverySnapshot snapshot = await _runtime
          .recoverySnapshot();
      if (!mounted || generation != _recoveryLoadGeneration) {
        return;
      }
      setState(() {
        _recoveryCount = snapshot.totalCount;
        _recoveryUnavailable = false;
      });
    } on Object {
      if (!mounted || generation != _recoveryLoadGeneration) {
        return;
      }
      setState(() {
        _recoveryUnavailable = true;
      });
    }
  }
}

class _ValidationMetadataProgressScreen extends StatelessWidget {
  const _ValidationMetadataProgressScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ValidationMetadataErrorScreen extends StatelessWidget {
  const _ValidationMetadataErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Validation Center не запущен: runtime app/build metadata '
              'недоступны или некорректны.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginScreen extends StatelessWidget {
  const _LoginScreen({required this.controller});

  final AuthSessionController controller;

  @override
  Widget build(BuildContext context) {
    final bool reauthentication =
        controller.state == AuthLifecycleState.reauthenticationRequired;
    final bool busy =
        controller.state == AuthLifecycleState.authenticating ||
        controller.isBusy;
    return AuthExpeditionScreen(
      reauthentication: reauthentication,
      busy: busy,
      message: controller.message,
      notice: controller.notice,
      onSignIn: controller.signIn,
    );
  }
}

class _AuthProgressScreen extends StatelessWidget {
  const _AuthProgressScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
