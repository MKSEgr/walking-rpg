import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/app/auth_gate.dart';
import 'package:walking_rpg_mobile/app/expedition_boundary_screen.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_store.dart';
import 'package:walking_rpg_mobile/core/auth/installation_id_store.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';
import 'package:walking_rpg_mobile/core/auth/owner_local_state_cleaner.dart';
import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/commands/file_mobile_command_store.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_controller.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_scope.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/validation/validation_center_policy.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

class WalkingRpgApp extends StatefulWidget {
  const WalkingRpgApp({super.key});

  @override
  State<WalkingRpgApp> createState() => _WalkingRpgAppState();
}

class _WalkingRpgAppState extends State<WalkingRpgApp> {
  late final AppLocaleController _localeController;
  AuthSessionController? _controller;
  ReadSnapshotCache? _cache;
  MobileCommandStore? _commandStore;

  @override
  void initState() {
    super.initState();
    _localeController = AppLocaleController();
    unawaited(_localeController.initialize());
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
        oidcClient: FlutterAppAuthOidcClient(
          installationIdProvider: SecureInstallationIdStore(),
          uiLocalesProvider: () => _localeController.selected.languageCode,
        ),
        localStateCleaner: OwnerLocalStateCleaner(
          cache: cache,
          commandStore: commandStore,
        ),
      );
      _cache = cache;
      _commandStore = commandStore;
      _controller = controller;
      unawaited(controller.initialize());
    } on Object {
      // Null runtime dependencies select the localized fail-closed screen.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthSessionController? controller = _controller;
    final ReadSnapshotCache? cache = _cache;
    final MobileCommandStore? commandStore = _commandStore;
    return AnimatedBuilder(
      animation: _localeController,
      builder: (BuildContext context, Widget? child) {
        final Widget destination;
        if (!_localeController.initialized) {
          destination = const _LocalePreferenceLoadingScreen();
        } else if (_localeController.requiresExplicitChoice) {
          destination = AppLocaleChoiceScreen(controller: _localeController);
        } else if (controller == null ||
            cache == null ||
            commandStore == null) {
          destination = const _ConfigurationErrorScreen();
        } else {
          destination = AuthGate(
            controller: controller,
            cache: cache,
            commandStore: commandStore,
          );
        }
        return MaterialApp(
          onGenerateTitle: (BuildContext context) => context.l10n.appName,
          debugShowCheckedModeBanner: false,
          theme: WalkingRpgTheme.light(),
          darkTheme: WalkingRpgTheme.dark(),
          themeMode: ThemeMode.system,
          locale: _localeController.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppLocaleScope(
            controller: _localeController,
            child: destination,
          ),
        );
      },
    );
  }
}

class _LocalePreferenceLoadingScreen extends StatelessWidget {
  const _LocalePreferenceLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return ExpeditionBoundaryScreen.loading(
      key: const Key('locale-preference-loading-screen'),
      badgeLabel: context.l10n.languageChoiceBadge,
      title: context.l10n.appName,
      message: context.l10n.languageSaving,
      icon: Icons.language,
    );
  }
}

class _ConfigurationErrorScreen extends StatelessWidget {
  const _ConfigurationErrorScreen();

  @override
  Widget build(BuildContext context) {
    return ExpeditionBoundaryScreen.blocked(
      key: const Key('configuration-error-screen'),
      badgeLabel: context.l10n.configurationBlockedBadge,
      title: context.l10n.configurationBlockedTitle,
      message: kReleaseMode
          ? context.l10n.configurationBlockedReleaseMessage
          : context.l10n.configurationBlockedDebugMessage,
      icon: Icons.security_outlined,
    );
  }
}
