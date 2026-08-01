import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/app/auth_gate.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_store.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';
import 'package:walking_rpg_mobile/core/auth/owner_local_state_cleaner.dart';
import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/commands/file_mobile_command_store.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/validation/validation_center_policy.dart';

class WalkingRpgApp extends StatefulWidget {
  const WalkingRpgApp({super.key});

  @override
  State<WalkingRpgApp> createState() => _WalkingRpgAppState();
}

class _WalkingRpgAppState extends State<WalkingRpgApp> {
  AuthSessionController? _controller;
  ReadSnapshotCache? _cache;
  MobileCommandStore? _commandStore;
  Object? _configurationError;

  @override
  void initState() {
    super.initState();
    try {
      ValidationCenterPolicy.validateEnvironment();
      final MobileAuthConfiguration configuration =
          MobileAuthConfiguration.fromEnvironment();
      final ReadSnapshotCache cache = FileReadSnapshotCache.fromEnvironment();
      final MobileCommandStore commandStore =
          FileMobileCommandStore.fromEnvironment();
      final AuthSessionController controller = AuthSessionController(
        configuration: configuration,
        sessionStore: SecureAuthSessionStore(),
        oidcClient: const FlutterAppAuthOidcClient(),
        localStateCleaner: OwnerLocalStateCleaner(
          cache: cache,
          commandStore: commandStore,
        ),
      );
      _cache = cache;
      _commandStore = commandStore;
      _controller = controller;
      unawaited(controller.initialize());
    } on Object catch (error) {
      _configurationError = error;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthSessionController? controller = _controller;
    final ReadSnapshotCache? cache = _cache;
    final MobileCommandStore? commandStore = _commandStore;
    return MaterialApp(
      title: 'Walking RPG',
      debugShowCheckedModeBanner: false,
      theme: WalkingRpgTheme.light(),
      darkTheme: WalkingRpgTheme.dark(),
      themeMode: ThemeMode.system,
      home: controller == null || cache == null || commandStore == null
          ? _ConfigurationErrorScreen(error: _configurationError)
          : AuthGate(
              controller: controller,
              cache: cache,
              commandStore: commandStore,
            ),
    );
  }
}

class _ConfigurationErrorScreen extends StatelessWidget {
  const _ConfigurationErrorScreen({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.security_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Аутентификация не настроена',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        kReleaseMode
                            ? 'Проверьте настройки входа и повторите запуск.'
                            : error?.toString() ??
                                  'Проверьте OIDC-параметры приложения.',
                        textAlign: TextAlign.center,
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
