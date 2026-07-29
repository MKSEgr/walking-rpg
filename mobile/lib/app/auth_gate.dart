import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';
import 'package:walking_rpg_mobile/features/account/data/account_api_client.dart';
import 'package:walking_rpg_mobile/features/account/presentation/account_screen.dart';
import 'package:walking_rpg_mobile/features/activity/application/activity_sync_coordinator.dart';
import 'package:walking_rpg_mobile/features/activity/data/activity_api_client.dart';
import 'package:walking_rpg_mobile/features/activity/presentation/activity_sync_shell.dart';
import 'package:walking_rpg_mobile/features/event/data/event_api_client.dart';
import 'package:walking_rpg_mobile/features/expedition/data/expedition_api_client.dart';
import 'package:walking_rpg_mobile/features/home/data/auth_home_transports.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';

class AuthGate extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        switch (controller.state) {
          case AuthLifecycleState.initializing:
          case AuthLifecycleState.stoppingRuntime:
            return const _AuthProgressScreen();
          case AuthLifecycleState.unauthenticated:
          case AuthLifecycleState.reauthenticationRequired:
          case AuthLifecycleState.authenticating:
            return _LoginScreen(controller: controller);
          case AuthLifecycleState.authenticated:
            final AuthIdentity? identity = controller.identity;
            if (identity == null) {
              return const _AuthProgressScreen();
            }
            return AuthenticatedApplicationShell(
              key: ValueKey<String>(identity.ownerId),
              controller: controller,
              identity: identity,
              cache: cache,
              commandStore: commandStore,
            );
        }
      },
    );
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
  late final RuntimeStopper _runtimeStopper;

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
      platformSender: _platformClient.execute,
    );
    _coordinator = ActivitySyncCoordinator.fromEnvironmentIfSupported(
      sender: _runtime.syncActivity,
    );
    _runtimeStopper = _runtime.close;
    widget.controller.registerRuntimeStopper(_runtimeStopper);
  }

  @override
  void dispose() {
    widget.controller.unregisterRuntimeStopper(_runtimeStopper);
    unawaited(_runtime.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ActivitySyncShell(
      synchronizer: _coordinator?.synchronize,
      commandRuntime: _runtime,
      homeLoader: () => _homeClient.fetchHome(DateTime.now()),
      platformLoader: _platformClient.fetchSnapshot,
      platformHomeLoader: () => _homeClient.fetchHome(DateTime.now()),
      onOpenAccount: _openAccount,
    );
  }

  void _openAccount() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AccountScreen(
          controller: widget.controller,
          identity: widget.identity,
          apiClient: _accountClient,
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Icon(Icons.directions_walk, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Walking RPG',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        reauthentication
                            ? 'Сессия завершена. Войдите снова, чтобы '
                                  'продолжить синхронизацию и игровые действия.'
                            : 'Войдите через корпоративную учётную запись.',
                        textAlign: TextAlign.center,
                      ),
                      if (controller.message != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          controller.message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (controller.notice != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          controller.notice!,
                          key: const Key('auth-notice'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('oidc-sign-in-button'),
                        onPressed: busy ? null : controller.signIn,
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(busy ? 'Открываем вход...' : 'Войти'),
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

class _AuthProgressScreen extends StatelessWidget {
  const _AuthProgressScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
