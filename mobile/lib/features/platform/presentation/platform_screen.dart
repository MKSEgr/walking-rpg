import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/cache/cached_snapshot_banner.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/localization/current_content_localizations.dart';
import 'package:walking_rpg_mobile/core/localization/current_event_localizations.dart';
import 'package:walking_rpg_mobile/core/localization/current_platform_content_localizations.dart';
import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_chrome_insets.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/character_cosmetics.dart';
import 'package:walking_rpg_mobile/design_system/companion_bond_signal.dart';
import 'package:walking_rpg_mobile/design_system/companion_growth.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/event_choice_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_event_scene.dart';
import 'package:walking_rpg_mobile/design_system/expedition_node_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_progress_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_read_state.dart';
import 'package:walking_rpg_mobile/design_system/expedition_route_trail.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/first_journey_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/pilot_motion.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/profile_cosmetic_art.dart';
import 'package:walking_rpg_mobile/design_system/progression_sigil.dart';
import 'package:walking_rpg_mobile/design_system/quest_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/season_reward_seal.dart';
import 'package:walking_rpg_mobile/design_system/squad_formation_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/design_system/weekly_route_signal.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_action.dart';

const String _sandboxPurchaseCommand = 'BUY_COSMETIC';
const double _platformBaseBottomReserve = 46;

enum _PlatformAppAction { refresh, account }

double _platformTextScale(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(16) / 16;
}

bool _usesCompactPlatformChrome(
  BuildContext context,
  BoxConstraints constraints,
) {
  return constraints.maxWidth < 360 ||
      (constraints.maxWidth < 430 && _platformTextScale(context) > 1.3);
}

bool _usesCompactPlatformSection(
  BuildContext context,
  BoxConstraints constraints,
) {
  return constraints.maxWidth < 300 ||
      (constraints.maxWidth < 400 && _platformTextScale(context) > 1.3);
}

PlatformPet? _petPreviewForCosmetic(
  PlatformSnapshot snapshot,
  String cosmeticId,
) {
  if (cosmeticId != CharacterCosmeticIds.sparkHalo) {
    return null;
  }
  for (final PlatformPet pet in snapshot.userState.pets) {
    if (pet.petId == 'spark-v1') {
      return pet;
    }
  }
  return null;
}

String? _profileCosmeticIdFor(PlatformSnapshot snapshot) {
  final String? equippedProfile =
      snapshot.userState.equippedCosmetics['PROFILE'];
  if (equippedProfile != null) {
    return equippedProfile;
  }
  for (final PlatformCosmetic cosmetic in snapshot.content.cosmetics) {
    if (cosmetic.slot == 'PROFILE' &&
        snapshot.userState.equippedCosmeticIds.contains(cosmetic.cosmeticId)) {
      return cosmetic.cosmeticId;
    }
  }
  return null;
}

typedef PlatformSnapshotLoader = Future<PlatformSnapshot> Function();
typedef PlatformHomeLoader = Future<HomeSnapshot> Function();
typedef PlatformCommandExecutor =
    Future<PlatformCommandResult> Function({
      required String commandType,
      required Map<String, Object?> payload,
      required String idempotencyKey,
    });
typedef PlatformIdempotencyKeyFactory = String Function(String commandType);

class PlatformScreen extends StatefulWidget {
  const PlatformScreen({
    super.key,
    this.loader,
    this.homeLoader,
    this.commandExecutor,
    this.idempotencyKeyFactory,
    this.onServerStateChanged,
    this.onResumeFirstJourney,
    this.onOpenAccount,
    this.onOpenRecovery,
    this.recoveryCount = 0,
    this.recoveryUnavailable = false,
    this.recordExperimentExposures = true,
    this.authoritativeRefreshGeneration = 0,
    this.sandboxPaymentsSupported = !kReleaseMode,
  });

  final PlatformSnapshotLoader? loader;
  final PlatformHomeLoader? homeLoader;
  final PlatformCommandExecutor? commandExecutor;
  final PlatformIdempotencyKeyFactory? idempotencyKeyFactory;
  final VoidCallback? onServerStateChanged;
  final VoidCallback? onResumeFirstJourney;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenRecovery;
  final int recoveryCount;
  final bool recoveryUnavailable;
  final bool recordExperimentExposures;
  final int authoritativeRefreshGeneration;
  final bool sandboxPaymentsSupported;

  @override
  State<PlatformScreen> createState() => _PlatformScreenState();
}

class _PlatformScreenState extends State<PlatformScreen> {
  final TextEditingController _squadNameController = TextEditingController();
  final TextEditingController _squadIdController = TextEditingController();
  final Set<String> _scheduledExposures = <String>{};

  late Future<_PlatformViewData> _dataFuture;
  String? _busyCommand;
  bool _sandboxPaymentsAvailable = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _squadNameController.addListener(_handleSquadInputChanged);
    _squadIdController.addListener(_handleSquadInputChanged);
    _dataFuture = _loadData();
  }

  @override
  void didUpdateWidget(PlatformScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader ||
        oldWidget.homeLoader != widget.homeLoader ||
        oldWidget.sandboxPaymentsSupported != widget.sandboxPaymentsSupported ||
        oldWidget.authoritativeRefreshGeneration !=
            widget.authoritativeRefreshGeneration) {
      _dataFuture = _loadData();
    }
  }

  @override
  void dispose() {
    _squadNameController.removeListener(_handleSquadInputChanged);
    _squadIdController.removeListener(_handleSquadInputChanged);
    _squadNameController.dispose();
    _squadIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compactChrome = _usesCompactPlatformChrome(
          context,
          constraints,
        );
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              compactChrome
                  ? context.l10n.platformCompactTitle
                  : context.l10n.platformTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: <Widget>[
              if (!compactChrome)
                IconButton(
                  tooltip: context.l10n.homeRefreshTooltip,
                  onPressed: _busyCommand == null ? _reload : null,
                  icon: const Icon(Icons.refresh),
                ),
              MobileCommandRecoveryAction(
                key: const Key('platform-command-recovery'),
                onPressed: widget.onOpenRecovery,
                count: widget.recoveryCount,
                unavailable: widget.recoveryUnavailable,
              ),
              if (compactChrome)
                _PlatformAppActionsMenu(
                  refreshEnabled: _busyCommand == null,
                  onRefresh: _reload,
                  onOpenAccount: widget.onOpenAccount,
                )
              else
                IconButton(
                  tooltip: context.l10n.accountTooltip,
                  onPressed: widget.onOpenAccount,
                  icon: const Icon(Icons.account_circle_outlined),
                ),
            ],
          ),
          body: ExpeditionBackdrop(
            child: SafeArea(
              child: FutureBuilder<_PlatformViewData>(
                future: _dataFuture,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<_PlatformViewData> snapshot,
                    ) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ExpeditionReadState.loading(
                          key: const Key('platform-loading-state'),
                          title: context.l10n.platformLoadingTitle,
                          message: context.l10n.platformLoadingMessage,
                        );
                      }
                      if (snapshot.hasError) {
                        return _PlatformError(onRetry: _reload);
                      }
                      final _PlatformViewData? data = snapshot.data;
                      if (data == null) {
                        return _PlatformError(onRetry: _reload);
                      }
                      return _PlatformBody(
                        data: data,
                        busyCommand: _busyCommand,
                        squadNameController: _squadNameController,
                        squadIdController: _squadIdController,
                        onCommand: _executeCommand,
                        onRefresh: _reload,
                        onResumeFirstJourney: widget.onResumeFirstJourney,
                        sandboxPaymentsAvailable: _sandboxPaymentsAvailable,
                      );
                    },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<_PlatformViewData> _loadData() async {
    final int generation = ++_loadGeneration;
    _sandboxPaymentsAvailable = false;
    final PlatformSnapshotLoader platformLoader =
        widget.loader ?? PlatformApiClient.fromEnvironment().fetchSnapshot;
    final PlatformHomeLoader homeLoader =
        widget.homeLoader ??
        () => HomeApiClient.fromEnvironment().fetchHome(DateTime.now());

    final Future<PlatformSnapshot> platformFuture = platformLoader();
    int? availableEnergy;
    int? economyVersion;
    HomeSnapshot? homeSnapshot;
    try {
      final HomeSnapshot home = await homeLoader();
      homeSnapshot = home;
      availableEnergy = home.isCached ? null : home.availableEnergy;
      economyVersion = home.isCached ? null : home.economyVersion;
    } on Object {
      availableEnergy = null;
      economyVersion = null;
    }
    final PlatformSnapshot platform = await platformFuture;
    if (generation == _loadGeneration) {
      _sandboxPaymentsAvailable = _canUseSandboxPayments(platform);
    }
    _scheduleExperimentExposures(platform);
    return _PlatformViewData(
      platform: platform,
      availableEnergy: availableEnergy,
      economyVersion: economyVersion,
      home: homeSnapshot,
    );
  }

  Future<void> _executeCommand(
    String commandType,
    Map<String, Object?> payload,
  ) async {
    final String normalizedCommandType = commandType.trim().toUpperCase();
    if (_busyCommand != null ||
        (normalizedCommandType == _sandboxPurchaseCommand &&
            !_sandboxPaymentsAvailable)) {
      return;
    }
    final PlatformCommandExecutor executor =
        widget.commandExecutor ?? PlatformApiClient.fromEnvironment().execute;
    setState(() {
      _busyCommand = commandType;
    });
    try {
      final PlatformCommandResult result = await executor(
        commandType: commandType,
        payload: payload,
        idempotencyKey: _nextKey(commandType),
      );
      int? availableEnergy;
      int? economyVersion;
      HomeSnapshot? homeSnapshot;
      try {
        final PlatformHomeLoader homeLoader =
            widget.homeLoader ??
            () => HomeApiClient.fromEnvironment().fetchHome(DateTime.now());
        final HomeSnapshot home = await homeLoader();
        homeSnapshot = home;
        availableEnergy = home.isCached ? null : home.availableEnergy;
        economyVersion = home.isCached ? null : home.economyVersion;
      } on Object {
        availableEnergy = null;
        economyVersion = null;
      }
      if (!mounted) {
        return;
      }
      _loadGeneration += 1;
      _sandboxPaymentsAvailable = _canUseSandboxPayments(result.snapshot);
      if (commandType == 'CREATE_SQUAD') {
        _squadNameController.clear();
      } else if (commandType == 'JOIN_SQUAD') {
        _squadIdController.clear();
      }
      setState(() {
        _dataFuture = Future<_PlatformViewData>.value(
          _PlatformViewData(
            platform: result.snapshot,
            availableEnergy: availableEnergy,
            economyVersion: economyVersion,
            home: homeSnapshot,
          ),
        );
      });
      widget.onServerStateChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.currentPlatformCommandMessage(
              result.commandType,
              result.message,
            ),
          ),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.platformCommandFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyCommand = null;
        });
      }
    }
  }

  void _scheduleExperimentExposures(PlatformSnapshot snapshot) {
    if (snapshot.isCached ||
        !widget.recordExperimentExposures ||
        widget.commandExecutor == null) {
      return;
    }
    for (final MapEntry<String, String> assignment
        in snapshot.userState.experimentAssignments.entries) {
      final String exposureKey =
          '${snapshot.contentVersion}:${assignment.key}:${assignment.value}';
      if (!_scheduledExposures.add(exposureKey)) {
        continue;
      }
      unawaited(_recordExposure(assignment.key, assignment.value, exposureKey));
    }
  }

  void _handleSquadInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _recordExposure(
    String experimentId,
    String variant,
    String exposureKey,
  ) async {
    final PlatformCommandExecutor? executor = widget.commandExecutor;
    if (executor == null) {
      return;
    }
    try {
      await executor(
        commandType: 'RECORD_EXPERIMENT_EXPOSURE',
        payload: <String, Object?>{
          'experimentId': experimentId,
          'variant': variant,
        },
        idempotencyKey: 'exposure-$exposureKey',
      );
    } on Object {
      _scheduledExposures.remove(exposureKey);
    }
  }

  String _nextKey(String commandType) {
    return widget.idempotencyKeyFactory?.call(commandType) ??
        '${commandType.toLowerCase()}-'
            '${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }

  bool _canUseSandboxPayments(PlatformSnapshot snapshot) {
    return widget.sandboxPaymentsSupported &&
        !snapshot.isCached &&
        snapshot.remoteConfig.sandboxPaymentsEnabled;
  }

  void _reload() {
    if (_busyCommand != null) {
      return;
    }
    setState(() {
      _dataFuture = _loadData();
    });
  }
}

class _PlatformViewData {
  const _PlatformViewData({
    required this.platform,
    required this.availableEnergy,
    required this.economyVersion,
    required this.home,
  });

  final PlatformSnapshot platform;
  final int? availableEnergy;
  final int? economyVersion;
  final HomeSnapshot? home;
}

class _PlatformAppActionsMenu extends StatelessWidget {
  const _PlatformAppActionsMenu({
    required this.refreshEnabled,
    required this.onRefresh,
    required this.onOpenAccount,
  });

  final bool refreshEnabled;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PlatformAppAction>(
      key: const Key('platform-more-actions'),
      tooltip: context.l10n.moreActionsTooltip,
      icon: const Icon(Icons.more_vert),
      onSelected: (_PlatformAppAction action) {
        switch (action) {
          case _PlatformAppAction.refresh:
            onRefresh();
            break;
          case _PlatformAppAction.account:
            onOpenAccount?.call();
            break;
        }
      },
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<_PlatformAppAction>>[
            PopupMenuItem<_PlatformAppAction>(
              key: const Key('platform-menu-refresh'),
              value: _PlatformAppAction.refresh,
              enabled: refreshEnabled,
              child: _PlatformMenuLabel(
                icon: Icons.refresh,
                label: context.l10n.platformRefreshJournal,
              ),
            ),
            PopupMenuItem<_PlatformAppAction>(
              key: const Key('platform-menu-account'),
              value: _PlatformAppAction.account,
              enabled: onOpenAccount != null,
              child: _PlatformMenuLabel(
                icon: Icons.account_circle_outlined,
                label: context.l10n.accountTooltip,
              ),
            ),
          ],
    );
  }
}

class _PlatformMenuLabel extends StatelessWidget {
  const _PlatformMenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 21),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _PlatformBody extends StatelessWidget {
  const _PlatformBody({
    required this.data,
    required this.busyCommand,
    required this.squadNameController,
    required this.squadIdController,
    required this.onCommand,
    required this.onRefresh,
    required this.onResumeFirstJourney,
    required this.sandboxPaymentsAvailable,
  });

  final _PlatformViewData data;
  final String? busyCommand;
  final TextEditingController squadNameController;
  final TextEditingController squadIdController;
  final void Function(String, Map<String, Object?>) onCommand;
  final VoidCallback onRefresh;
  final VoidCallback? onResumeFirstJourney;
  final bool sandboxPaymentsAvailable;

  bool get _busy => busyCommand != null;

  @override
  Widget build(BuildContext context) {
    final PlatformSnapshot snapshot = data.platform;
    final Set<String> equippedCosmeticIds =
        snapshot.userState.equippedCosmeticIds;
    final double bottomDockInset = NavigationChromeInsets.bottomDockInsetOf(
      context,
    );
    final bool readOnly = snapshot.isCached;
    final bool blocked = _busy || readOnly;
    final String energyCopy =
        snapshot.userState.experimentAssignments['home-energy-copy-v1'] ==
            'MOTIVATIONAL'
        ? context.l10n.platformEnergyMotivational
        : context.l10n.platformEnergyControl;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        key: const Key('platform-screen-list'),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          _platformBaseBottomReserve + bottomDockInset,
        ),
        children: <Widget>[
          if (snapshot.cacheMetadata != null) ...<Widget>[
            CachedSnapshotBanner(metadata: snapshot.cacheMetadata!),
            const SizedBox(height: 12),
          ],
          _JournalHero(data: data, equippedCosmeticIds: equippedCosmeticIds),
          const SizedBox(height: 12),
          if (data.home case final HomeSnapshot home) ...<Widget>[
            if (home.completionRecap
                case final HomeExpeditionCompletionRecap recap) ...<Widget>[
              _JourneyCompletionRecapCard(snapshot: home, recap: recap),
              const SizedBox(height: 12),
            ],
            _JourneyDecisionLogCard(snapshot: home),
            if (home.journeyChronicle
                case final HomeJourneyChronicle chronicle) ...<Widget>[
              const SizedBox(height: 12),
              _JourneyChronicleCard(chronicle: chronicle),
            ],
            if (home.recentJourneyRecaps.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _JourneyArchiveCard(recaps: home.recentJourneyRecaps),
            ],
            const SizedBox(height: 12),
          ],
          _OnboardingCard(snapshot: snapshot, onResume: onResumeFirstJourney),
          const SizedBox(height: 12),
          _WeeklyRouteCard(
            snapshot: snapshot,
            availableEnergy: readOnly ? null : data.availableEnergy,
            economyVersion: readOnly ? null : data.economyVersion,
            energyCopy: energyCopy,
            busy: blocked,
            onAdvance: (int energy) => onCommand(
              'ADVANCE_WEEKLY_ROUTE',
              <String, Object?>{'energyToSpend': energy},
            ),
            onClaimSeasonReward: (int level) => onCommand(
              'CLAIM_SEASON_REWARD',
              <String, Object?>{'level': level},
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle(
            title: context.l10n.platformPetsTitle,
            subtitle: context.l10n.platformPetsSubtitle,
            icon: Icons.pets_outlined,
          ),
          if (snapshot.evolvableCompanionCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Semantics(
              key: const Key('platform-evolvable-companions'),
              container: true,
              label: context.l10n.platformCompanionsReadyToEvolve(
                snapshot.evolvableCompanionCount,
              ),
              excludeSemantics: true,
              child: Text(
                context.l10n.platformCompanionsReadyToEvolve(
                  snapshot.evolvableCompanionCount,
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
          for (final PlatformPet pet in snapshot.userState.pets) ...<Widget>[
            _PetCard(
              pet: pet,
              equippedCosmeticIds: equippedCosmeticIds,
              busy: blocked,
              onSelect: () => onCommand('SELECT_PET', <String, Object?>{
                'petId': pet.petId,
              }),
              onEvolve: () => onCommand('EVOLVE_PET', <String, Object?>{
                'petId': pet.petId,
              }),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          _SectionTitle(
            title: context.l10n.platformSkillsTitle,
            subtitle: context.l10n.platformSkillsSubtitle,
            icon: Icons.hub_outlined,
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (BuildContext context) {
              final int unlocked = snapshot.unlockedCatalogSkillCount;
              final int remaining = snapshot.remainingCatalogSkillCount;
              final String progress = context.l10n
                  .platformSkillsCollectionProgress(
                    unlocked,
                    snapshot.content.skills.length,
                  );
              final String guidance = remaining == 0
                  ? context.l10n.platformSkillsCollectionComplete
                  : context.l10n.platformSkillsCollectionRemaining(remaining);
              return Semantics(
                key: const Key('platform-skills-collection-summary'),
                container: true,
                explicitChildNodes: true,
                label: context.l10n.platformSkillsCollectionSemantics(
                  progress,
                  guidance,
                ),
                excludeSemantics: true,
                child: Text(
                  '$progress · $guidance',
                  key: const Key('platform-skills-collection-guidance'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              );
            },
          ),
          if (snapshot.unlockableCatalogSkillCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Semantics(
              key: const Key('platform-unlockable-skills'),
              container: true,
              label: context.l10n.platformSkillsAvailableToUnlock(
                snapshot.unlockableCatalogSkillCount,
              ),
              excludeSemantics: true,
              child: Text(
                context.l10n.platformSkillsAvailableToUnlock(
                  snapshot.unlockableCatalogSkillCount,
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final PlatformSkill skill
              in snapshot.content.skills) ...<Widget>[
            _SkillCard(
              skill: skill,
              seasonXp: snapshot.userState.seasonXp,
              unlocked: snapshot.userState.unlockedSkills.contains(
                skill.skillId,
              ),
              busy: blocked,
              onUnlock: () => onCommand('UNLOCK_SKILL', <String, Object?>{
                'skillId': skill.skillId,
              }),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          _SectionTitle(
            title: context.l10n.platformQuestsTitle,
            subtitle: context.l10n.platformQuestSummary(
              snapshot.userState.totalAcceptedSteps,
              snapshot.userState.resolvedEventCount,
            ),
            icon: Icons.assignment_outlined,
          ),
          if (snapshot.claimableQuestRewardCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Semantics(
              key: const Key('platform-claimable-quest-rewards'),
              container: true,
              label: context.l10n.platformQuestRewardsAvailable(
                snapshot.claimableQuestRewardCount,
              ),
              excludeSemantics: true,
              child: Text(
                context.l10n.platformQuestRewardsAvailable(
                  snapshot.claimableQuestRewardCount,
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
          for (final PlatformQuest quest
              in snapshot.userState.quests) ...<Widget>[
            _QuestCard(
              quest: quest,
              rewardFirst:
                  snapshot.userState.experimentAssignments['quest-order-v1'] ==
                  'REWARD_FIRST',
              busy: blocked,
              onClaim: () => onCommand('CLAIM_QUEST', <String, Object?>{
                'questId': quest.questId,
              }),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          _SquadCard(
            squad: snapshot.userState.squad,
            nameController: squadNameController,
            idController: squadIdController,
            busy: blocked,
            onCreate: () => onCommand('CREATE_SQUAD', <String, Object?>{
              'name': squadNameController.text.trim(),
            }),
            onJoin: () => onCommand('JOIN_SQUAD', <String, Object?>{
              'squadId': squadIdController.text.trim(),
            }),
            onLeave: () => onCommand('LEAVE_SQUAD', const <String, Object?>{}),
          ),
          const SizedBox(height: 12),
          _SectionTitle(
            title: context.l10n.platformCosmeticsTitle,
            subtitle: sandboxPaymentsAvailable
                ? context.l10n.platformSandboxPurchasesAvailable
                : context.l10n.platformPurchasesUnavailable,
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (BuildContext context) {
              final int owned = snapshot.ownedCatalogCosmeticCount;
              final int remaining = snapshot.remainingCatalogCosmeticCount;
              final String progress = context.l10n
                  .platformCosmeticsCollectionProgress(
                    owned,
                    snapshot.content.cosmetics.length,
                  );
              final String guidance = remaining == 0
                  ? context.l10n.platformCosmeticsCollectionComplete
                  : context.l10n.platformCosmeticsCollectionRemaining(
                      remaining,
                    );
              return Semantics(
                key: const Key('platform-cosmetics-collection-summary'),
                container: true,
                explicitChildNodes: true,
                label: context.l10n.platformCosmeticsCollectionSemantics(
                  progress,
                  guidance,
                ),
                excludeSemantics: true,
                child: Text(
                  '$progress · $guidance',
                  key: const Key('platform-cosmetics-collection-guidance'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              );
            },
          ),
          if (snapshot.equippableCatalogCosmeticCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Semantics(
              key: const Key('platform-equippable-cosmetics'),
              container: true,
              label: context.l10n.platformCosmeticsAvailableToEquip(
                snapshot.equippableCatalogCosmeticCount,
              ),
              excludeSemantics: true,
              child: Text(
                context.l10n.platformCosmeticsAvailableToEquip(
                  snapshot.equippableCatalogCosmeticCount,
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final PlatformCosmetic cosmetic
              in snapshot.content.cosmetics) ...<Widget>[
            _CosmeticCard(
              cosmetic: cosmetic,
              previewPet: _petPreviewForCosmetic(snapshot, cosmetic.cosmeticId),
              owned: snapshot.userState.ownedCosmetics.contains(
                cosmetic.cosmeticId,
              ),
              active: equippedCosmeticIds.contains(cosmetic.cosmeticId),
              paymentsEnabled: sandboxPaymentsAvailable,
              busy: blocked,
              onBuy: () => onCommand('BUY_COSMETIC', <String, Object?>{
                'cosmeticId': cosmetic.cosmeticId,
              }),
              onEquip: () => onCommand('EQUIP_COSMETIC', <String, Object?>{
                'cosmeticId': cosmetic.cosmeticId,
              }),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          _AchievementsCard(snapshot: snapshot),
          const SizedBox(height: 12),
          _ExperimentsCard(snapshot: snapshot),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _busy ? null : onRefresh,
            icon: const Icon(Icons.sync),
            label: Text(context.l10n.platformRefreshJournal),
          ),
          const SizedBox(height: 12),
          Text(
            key: const Key('platform-journal-footer'),
            context.l10n.platformJournalFooter(
              snapshot.contentVersion,
              snapshot.remoteConfig.seasonId,
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _JourneyCompletionRecapCard extends StatelessWidget {
  const _JourneyCompletionRecapCard({
    required this.snapshot,
    required this.recap,
  });

  final HomeSnapshot snapshot;
  final HomeExpeditionCompletionRecap recap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<String> rewardLabels = _journeyRecapRewardLabels(context, recap);
    final String rewardSummary = rewardLabels.isEmpty
        ? context.l10n.platformNoRewardsSummary
        : context.l10n.platformRewardsSummary(rewardLabels.join('; '));
    final String finalDecisionSummary = _journeyFinalDecisionSemantic(
      context,
      recap.finalDecision,
    );
    final String completionTime = _journeyCompletionTimeLabel(
      context,
      recap.finalDecision,
    );
    final String duration = _journeyDurationLabel(
      context,
      recap.durationSeconds,
    );
    return Semantics(
      key: const Key('platform-journey-completion-recap'),
      container: true,
      label: context.l10n.platformJourneyCompletedSemantics(
        recap.journeyNumber,
        recap.decisionCount,
        completionTime.isEmpty ? '' : '$completionTime. ',
        duration.isEmpty ? '' : '$duration. ',
        finalDecisionSummary,
        rewardSummary,
      ),
      child: ExcludeSemantics(
        child: ExpeditionPanel(
          tone: ExpeditionPanelTone.lumen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: ExpeditionBadge(
                  label: context.l10n.platformJourneyCompletedBadge(
                    recap.journeyNumber,
                    snapshot.isCached
                        ? context.l10n.platformSavedResultSuffix
                        : '',
                  ),
                  icon: Icons.flag_outlined,
                  tone: ExpeditionPanelTone.lumen,
                  allowWrap: true,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.platformJourneySummaryTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.platformDecisionsAcceptedCount(
                  recap.decisionCount,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (completionTime.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  completionTime,
                  key: const Key('platform-journey-completion-time'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (duration.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  duration,
                  key: const Key('platform-journey-completion-duration'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (recap.finalDecision
                  case final HomeJourneyFinalDecision decision) ...<Widget>[
                const SizedBox(height: 12),
                _JourneyFinalDecisionSummary(
                  key: const Key('platform-journey-completion-final'),
                  decision: decision,
                ),
              ],
              const SizedBox(height: 14),
              if (rewardLabels.isEmpty)
                Text(
                  context.l10n.platformNoJourneyRewards,
                  style: theme.textTheme.bodyMedium,
                )
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    if (recap.pilotExperienceRewards.isEmpty &&
                        recap.pilotExperienceGained > 0)
                      _JourneyRewardChip(
                        icon: Icons.star_outline,
                        label: context.l10n.platformPilotXpReward(
                          recap.pilotExperienceGained,
                        ),
                      ),
                    for (final HomeJourneyPilotExperienceReward reward
                        in recap.pilotExperienceRewards)
                      _JourneyRewardChip(
                        icon: Icons.star_outline,
                        label: context.l10n.platformNamedPilotXpReward(
                          reward.pilotName,
                          reward.experienceGained,
                        ),
                      ),
                    if (recap.petBondRewards.isEmpty && recap.petBondGained > 0)
                      _JourneyRewardChip(
                        icon: Icons.favorite_border,
                        label: context.l10n.platformCompanionBondReward(
                          recap.petBondGained,
                        ),
                      ),
                    for (final HomeJourneyPetBondReward reward
                        in recap.petBondRewards)
                      _JourneyRewardChip(
                        icon: Icons.favorite_border,
                        label: context.l10n.platformNamedCompanionBondReward(
                          reward.petName,
                          reward.bondGained,
                        ),
                      ),
                    for (final HomeJourneyMaterialReward material
                        in recap.materials)
                      _JourneyRewardChip(
                        icon: Icons.inventory_2_outlined,
                        label: context.l10n.platformMaterialReward(
                          material.quantity,
                          material.itemName,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyFinalDecisionSummary extends StatelessWidget {
  const _JourneyFinalDecisionSummary({super.key, required this.decision});

  final HomeJourneyFinalDecision decision;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.platformFinalRouteTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              decision.eventTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${decision.choiceTitle} → ${decision.outcomeTitle}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 3),
            Text(
              decision.outcomeSummary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyChronicleCard extends StatelessWidget {
  const _JourneyChronicleCard({required this.chronicle});

  final HomeJourneyChronicle chronicle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String duration = chronicle.totalDurationSeconds == null
        ? ''
        : context.l10n.platformJourneyChronicleDuration(
            _journeyDurationValueLabel(
              context,
              chronicle.totalDurationSeconds!,
            ),
          );
    final String longestDuration = chronicle.longestDurationSeconds == null
        ? ''
        : chronicle.longestJourneyNumber == null
        ? context.l10n.platformJourneyChronicleLongestDuration(
            _journeyDurationValueLabel(
              context,
              chronicle.longestDurationSeconds!,
            ),
          )
        : context.l10n.platformJourneyChronicleLongestJourneyDuration(
            chronicle.longestJourneyNumber!,
            _journeyDurationValueLabel(
              context,
              chronicle.longestDurationSeconds!,
            ),
          );
    final String shortestDuration = chronicle.shortestDurationSeconds == null
        ? ''
        : chronicle.shortestJourneyNumber == null
        ? context.l10n.platformJourneyChronicleShortestDuration(
            _journeyDurationValueLabel(
              context,
              chronicle.shortestDurationSeconds!,
            ),
          )
        : context.l10n.platformJourneyChronicleShortestJourneyDuration(
            chronicle.shortestJourneyNumber!,
            _journeyDurationValueLabel(
              context,
              chronicle.shortestDurationSeconds!,
            ),
          );
    final String shortestCompletedAt =
        chronicle.shortestJourneyCompletedAt == null
        ? ''
        : _journeyChronicleShortestTimeLabel(
            context,
            chronicle.shortestJourneyCompletedAt!,
          );
    final String recordCompletedAt = chronicle.longestJourneyCompletedAt == null
        ? ''
        : _journeyChronicleRecordTimeLabel(
            context,
            chronicle.longestJourneyCompletedAt!,
          );
    final String averageDuration = chronicle.averageDurationSeconds == null
        ? ''
        : context.l10n.platformJourneyChronicleAverageDuration(
            _journeyDurationValueLabel(
              context,
              chronicle.averageDurationSeconds!,
            ),
          );
    final String experienceSummary = chronicle.pilotExperienceRewards.isEmpty
        ? context.l10n.platformPilotXpReward(chronicle.pilotExperienceGained)
        : chronicle.pilotExperienceRewards
              .map(
                (HomeJourneyPilotExperienceReward reward) =>
                    context.l10n.platformNamedPilotXpSemantic(
                      reward.pilotName,
                      reward.experienceGained,
                    ),
              )
              .join('; ');
    final String bondSummary = chronicle.petBondRewards.isEmpty
        ? context.l10n.platformCompanionBondReward(chronicle.petBondGained)
        : chronicle.petBondRewards
              .map(
                (HomeJourneyPetBondReward reward) =>
                    context.l10n.platformNamedCompanionBondSemantic(
                      reward.petName,
                      reward.bondGained,
                    ),
              )
              .join('; ');
    final List<String> materialRewards = chronicle.materials
        .map(
          (HomeJourneyMaterialReward material) => context.l10n
              .platformMaterialReward(material.quantity, material.itemName),
        )
        .toList(growable: false);
    final String materialSummary = materialRewards.isEmpty
        ? ''
        : '; ${materialRewards.join('; ')}';
    final List<String> decisionLabels = chronicle.decisionOutcomes
        .map(
          (HomeJourneyDecisionOutcome outcome) =>
              context.l10n.platformJourneyChronicleDecisionSemantic(
                outcome.eventTitle,
                outcome.choiceTitle,
                outcome.outcomeTitle,
                outcome.decisionCount,
              ),
        )
        .toList(growable: false);
    final String decisionSummary = decisionLabels.isEmpty
        ? ''
        : context.l10n.platformJourneyChronicleDecisionsSemantics(
            decisionLabels.join('; '),
          );
    final List<String> finaleLabels = chronicle.finaleOutcomes
        .map(
          (HomeJourneyFinaleOutcome outcome) =>
              context.l10n.platformJourneyChronicleFinaleSemantic(
                outcome.eventTitle,
                outcome.choiceTitle,
                outcome.outcomeTitle,
                outcome.journeyCount,
              ),
        )
        .toList(growable: false);
    final String finaleSummary = finaleLabels.isEmpty
        ? ''
        : context.l10n.platformJourneyChronicleFinalesSemantics(
            finaleLabels.join('; '),
          );
    return Semantics(
      key: const Key('platform-journey-chronicle'),
      container: true,
      label: context.l10n.platformJourneyChronicleSemantics(
        chronicle.completedJourneyCount,
        chronicle.decisionCount,
        duration.isEmpty ? '' : '$duration. ',
        shortestDuration.isEmpty ? '' : '$shortestDuration. ',
        shortestCompletedAt.isEmpty ? '' : '$shortestCompletedAt. ',
        longestDuration.isEmpty ? '' : '$longestDuration. ',
        recordCompletedAt.isEmpty ? '' : '$recordCompletedAt. ',
        averageDuration.isEmpty ? '' : '$averageDuration. ',
        experienceSummary,
        bondSummary,
        materialSummary,
        decisionSummary,
        finaleSummary,
      ),
      child: ExcludeSemantics(
        child: ExpeditionPanel(
          tone: ExpeditionPanelTone.resonance,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: ExpeditionBadge(
                  label: context.l10n.platformJourneyChronicleBadge(
                    chronicle.completedJourneyCount,
                  ),
                  icon: Icons.auto_stories_outlined,
                  tone: ExpeditionPanelTone.resonance,
                  allowWrap: true,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.platformJourneyChronicleTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.platformJourneyChronicleSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  _JourneyRewardChip(
                    icon: Icons.alt_route,
                    label: context.l10n.platformDecisionsChip(
                      chronicle.decisionCount,
                    ),
                  ),
                  if (duration.isNotEmpty)
                    _JourneyRewardChip(
                      key: const Key('platform-journey-chronicle-duration'),
                      icon: Icons.timer_outlined,
                      label: duration,
                    ),
                  if (shortestDuration.isNotEmpty)
                    _JourneyRewardChip(
                      key: const Key(
                        'platform-journey-chronicle-shortest-duration',
                      ),
                      icon: Icons.speed_outlined,
                      label: shortestDuration,
                    ),
                  if (shortestCompletedAt.isNotEmpty)
                    _JourneyRewardChip(
                      key: const Key(
                        'platform-journey-chronicle-shortest-completed-at',
                      ),
                      icon: Icons.event_outlined,
                      label: shortestCompletedAt,
                    ),
                  if (longestDuration.isNotEmpty)
                    _JourneyRewardChip(
                      key: const Key(
                        'platform-journey-chronicle-longest-duration',
                      ),
                      icon: Icons.emoji_events_outlined,
                      label: longestDuration,
                    ),
                  if (recordCompletedAt.isNotEmpty)
                    _JourneyRewardChip(
                      key: const Key(
                        'platform-journey-chronicle-record-completed-at',
                      ),
                      icon: Icons.event_available_outlined,
                      label: recordCompletedAt,
                    ),
                  if (averageDuration.isNotEmpty)
                    _JourneyRewardChip(
                      key: const Key(
                        'platform-journey-chronicle-average-duration',
                      ),
                      icon: Icons.av_timer_outlined,
                      label: averageDuration,
                    ),
                  if (chronicle.pilotExperienceRewards.isEmpty)
                    _JourneyRewardChip(
                      icon: Icons.star_outline,
                      label: context.l10n.platformPilotXpReward(
                        chronicle.pilotExperienceGained,
                      ),
                    ),
                  for (final HomeJourneyPilotExperienceReward reward
                      in chronicle.pilotExperienceRewards)
                    _JourneyRewardChip(
                      icon: Icons.star_outline,
                      label: context.l10n.platformNamedPilotXpReward(
                        reward.pilotName,
                        reward.experienceGained,
                      ),
                    ),
                  if (chronicle.petBondRewards.isEmpty)
                    _JourneyRewardChip(
                      icon: Icons.favorite_border,
                      label: context.l10n.platformCompanionBondReward(
                        chronicle.petBondGained,
                      ),
                    ),
                  for (final HomeJourneyPetBondReward reward
                      in chronicle.petBondRewards)
                    _JourneyRewardChip(
                      icon: Icons.favorite_border,
                      label: context.l10n.platformNamedCompanionBondReward(
                        reward.petName,
                        reward.bondGained,
                      ),
                    ),
                  for (final HomeJourneyMaterialReward material
                      in chronicle.materials)
                    _JourneyRewardChip(
                      icon: Icons.inventory_2_outlined,
                      label: context.l10n.platformMaterialReward(
                        material.quantity,
                        material.itemName,
                      ),
                    ),
                ],
              ),
              if (chronicle.decisionOutcomes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  context.l10n.platformJourneyChronicleDecisionsTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    for (final HomeJourneyDecisionOutcome outcome
                        in chronicle.decisionOutcomes)
                      _JourneyRewardChip(
                        icon: Icons.alt_route,
                        label: context.l10n
                            .platformJourneyChronicleDecisionChip(
                              outcome.choiceTitle,
                              outcome.outcomeTitle,
                              outcome.decisionCount,
                            ),
                      ),
                  ],
                ),
              ],
              if (chronicle.finaleOutcomes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  context.l10n.platformJourneyChronicleFinalesTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    for (final HomeJourneyFinaleOutcome outcome
                        in chronicle.finaleOutcomes)
                      _JourneyRewardChip(
                        icon: Icons.flag_outlined,
                        label: context.l10n.platformJourneyChronicleFinaleChip(
                          outcome.choiceTitle,
                          outcome.outcomeTitle,
                          outcome.journeyCount,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyArchiveCard extends StatelessWidget {
  const _JourneyArchiveCard({required this.recaps});

  final List<HomeExpeditionCompletionRecap> recaps;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return ExpeditionPanel(
      key: const Key('platform-journey-archive'),
      tone: ExpeditionPanelTone.neutral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: ExpeditionBadge(
              label: context.l10n.platformJourneyArchiveBadge(recaps.length),
              icon: Icons.history,
              tone: ExpeditionPanelTone.neutral,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.platformJourneyArchiveTitle,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.platformJourneyArchiveSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (int index = 0; index < recaps.length; index += 1) ...<Widget>[
            _JourneyArchiveEntry(recap: recaps[index]),
            if (index < recaps.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _JourneyArchiveEntry extends StatelessWidget {
  const _JourneyArchiveEntry({required this.recap});

  final HomeExpeditionCompletionRecap recap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<String> rewardLabels = _journeyRecapRewardLabels(context, recap);
    final String rewardSummary = rewardLabels.isEmpty
        ? context.l10n.platformNoRewardsSummary
        : context.l10n.platformRewardsSummary(rewardLabels.join('; '));
    final String finalDecisionSummary = _journeyFinalDecisionSemantic(
      context,
      recap.finalDecision,
    );
    final String completionTime = _journeyCompletionTimeLabel(
      context,
      recap.finalDecision,
    );
    final String duration = _journeyDurationLabel(
      context,
      recap.durationSeconds,
    );
    final Widget summary = Semantics(
      key: Key('platform-journey-archive-${recap.journeyNumber}'),
      container: true,
      label: context.l10n.platformJourneyArchiveEntrySemantics(
        recap.journeyNumber,
        recap.decisionCount,
        completionTime.isEmpty ? '' : '$completionTime. ',
        duration.isEmpty ? '' : '$duration. ',
        finalDecisionSummary,
        rewardSummary,
      ),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.platformJourneyNumber(recap.journeyNumber),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.platformDecisionsAcceptedCount(
                    recap.decisionCount,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (completionTime.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    completionTime,
                    key: Key(
                      'platform-journey-archive-${recap.journeyNumber}-time',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (duration.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    duration,
                    key: Key(
                      'platform-journey-archive-${recap.journeyNumber}-duration',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (recap.finalDecision
                    case final HomeJourneyFinalDecision decision) ...<Widget>[
                  const SizedBox(height: 10),
                  _JourneyFinalDecisionSummary(
                    key: Key(
                      'platform-journey-archive-${recap.journeyNumber}-final',
                    ),
                    decision: decision,
                  ),
                ],
                const SizedBox(height: 10),
                if (rewardLabels.isEmpty)
                  Text(
                    context.l10n.platformNoRewardsSummary,
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      if (recap.pilotExperienceRewards.isEmpty &&
                          recap.pilotExperienceGained > 0)
                        _JourneyRewardChip(
                          icon: Icons.star_outline,
                          label: context.l10n.platformPilotXpReward(
                            recap.pilotExperienceGained,
                          ),
                        ),
                      for (final HomeJourneyPilotExperienceReward reward
                          in recap.pilotExperienceRewards)
                        _JourneyRewardChip(
                          icon: Icons.star_outline,
                          label: context.l10n.platformNamedPilotXpReward(
                            reward.pilotName,
                            reward.experienceGained,
                          ),
                        ),
                      if (recap.petBondRewards.isEmpty &&
                          recap.petBondGained > 0)
                        _JourneyRewardChip(
                          icon: Icons.favorite_border,
                          label: context.l10n.platformCompanionBondReward(
                            recap.petBondGained,
                          ),
                        ),
                      for (final HomeJourneyPetBondReward reward
                          in recap.petBondRewards)
                        _JourneyRewardChip(
                          icon: Icons.favorite_border,
                          label: context.l10n.platformNamedCompanionBondReward(
                            reward.petName,
                            reward.bondGained,
                          ),
                        ),
                      for (final HomeJourneyMaterialReward material
                          in recap.materials)
                        _JourneyRewardChip(
                          icon: Icons.inventory_2_outlined,
                          label: context.l10n.platformMaterialReward(
                            material.quantity,
                            material.itemName,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        summary,
        if (recap.decisions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          _JourneyArchiveDecisionHistory(
            key: Key('platform-journey-archive-${recap.journeyNumber}-history'),
            journeyNumber: recap.journeyNumber,
            decisions: recap.decisions,
          ),
        ],
      ],
    );
  }
}

class _JourneyArchiveDecisionHistory extends StatefulWidget {
  const _JourneyArchiveDecisionHistory({
    super.key,
    required this.journeyNumber,
    required this.decisions,
  });

  final int journeyNumber;
  final List<HomeExpeditionDecisionLogEntry> decisions;

  @override
  State<_JourneyArchiveDecisionHistory> createState() =>
      _JourneyArchiveDecisionHistoryState();
}

class _JourneyArchiveDecisionHistoryState
    extends State<_JourneyArchiveDecisionHistory> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final String keyPrefix =
        'platform-journey-archive-${widget.journeyNumber}-history';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          key: Key('$keyPrefix-toggle-semantics'),
          container: true,
          button: true,
          label: _expanded
              ? context.l10n.platformHideJourneyDecisionsSemantics(
                  widget.journeyNumber,
                )
              : context.l10n.platformShowJourneyDecisionsSemantics(
                  widget.journeyNumber,
                  widget.decisions.length,
                ),
          onTap: _toggle,
          child: ExcludeSemantics(
            child: OutlinedButton.icon(
              key: Key('$keyPrefix-toggle'),
              onPressed: _toggle,
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _expanded
                    ? context.l10n.platformHideJourneyDecisions
                    : context.l10n.platformShowJourneyDecisions(
                        widget.decisions.length,
                      ),
              ),
            ),
          ),
        ),
        if (_expanded) ...<Widget>[
          const SizedBox(height: 10),
          for (
            int index = 0;
            index < widget.decisions.length;
            index += 1
          ) ...<Widget>[
            _JourneyDecisionEntry(
              entry: widget.decisions[index],
              index: index,
              total: widget.decisions.length,
            ),
            if (index < widget.decisions.length - 1) const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

String _journeyFinalDecisionSemantic(
  BuildContext context,
  HomeJourneyFinalDecision? decision,
) {
  if (decision == null) {
    return '';
  }
  return '${context.l10n.platformFinalDecisionSemantics(decision.eventTitle, decision.choiceTitle, decision.outcomeTitle, decision.outcomeSummary)} ';
}

String _journeyCompletionTimeLabel(
  BuildContext context,
  HomeJourneyFinalDecision? decision,
) {
  if (decision == null) {
    return '';
  }
  final ({String date, String time}) local = _journeyLocalDateTime(
    context,
    decision.resolvedAt,
  );
  return context.l10n.platformJourneyCompletedAt(local.date, local.time);
}

String _journeyChronicleRecordTimeLabel(
  BuildContext context,
  String resolvedAt,
) {
  final ({String date, String time}) local = _journeyLocalDateTime(
    context,
    resolvedAt,
  );
  return context.l10n.platformJourneyChronicleRecordCompletedAt(
    local.date,
    local.time,
  );
}

String _journeyChronicleShortestTimeLabel(
  BuildContext context,
  String resolvedAt,
) {
  final ({String date, String time}) local = _journeyLocalDateTime(
    context,
    resolvedAt,
  );
  return context.l10n.platformJourneyChronicleShortestCompletedAt(
    local.date,
    local.time,
  );
}

String _journeyDecisionTimeLabel(
  BuildContext context,
  HomeExpeditionDecisionLogEntry decision,
) {
  final ({String date, String time}) local = _journeyLocalDateTime(
    context,
    decision.resolvedAt,
  );
  return context.l10n.platformJourneyDecisionResolvedAt(local.date, local.time);
}

String _journeyStartedTimeLabel(BuildContext context, String startedAt) {
  final ({String date, String time}) local = _journeyLocalDateTime(
    context,
    startedAt,
  );
  return context.l10n.platformJourneyStartedAt(local.date, local.time);
}

String _journeyPhaseLabel(BuildContext context, String status) {
  return switch (status) {
    'IN_PROGRESS' => context.l10n.platformJourneyPhaseInProgress,
    'EVENT_READY' => context.l10n.platformJourneyPhaseDecisionAvailable,
    'COMPLETED' => context.l10n.platformJourneyPhaseCompleted,
    _ => throw StateError('Unsupported expedition status: $status'),
  };
}

String _journeyDurationLabel(BuildContext context, int? durationSeconds) {
  if (durationSeconds == null) {
    return '';
  }
  return context.l10n.platformJourneyDuration(
    _journeyDurationValueLabel(context, durationSeconds),
  );
}

String _journeyDurationValueLabel(BuildContext context, int durationSeconds) {
  final int totalMinutes = durationSeconds ~/ Duration.secondsPerMinute;
  if (durationSeconds < Duration.secondsPerMinute) {
    return context.l10n.platformJourneyDurationUnderMinute;
  }
  if (totalMinutes < Duration.minutesPerHour) {
    return context.l10n.platformJourneyDurationMinutes(totalMinutes);
  }
  return context.l10n.platformJourneyDurationHoursMinutes(
    totalMinutes ~/ Duration.minutesPerHour,
    totalMinutes % Duration.minutesPerHour,
  );
}

({String date, String time}) _journeyLocalDateTime(
  BuildContext context,
  String resolvedAt,
) {
  final DateTime local = DateTime.parse(resolvedAt).toLocal();
  final MaterialLocalizations materialL10n = MaterialLocalizations.of(context);
  final String date = materialL10n.formatMediumDate(local);
  final String time = materialL10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return (date: date, time: time);
}

List<String> _journeyRecapRewardLabels(
  BuildContext context,
  HomeExpeditionCompletionRecap recap,
) {
  return <String>[
    if (recap.pilotExperienceRewards.isEmpty && recap.pilotExperienceGained > 0)
      context.l10n.platformPilotXpReward(recap.pilotExperienceGained),
    for (final HomeJourneyPilotExperienceReward reward
        in recap.pilotExperienceRewards)
      context.l10n.platformNamedPilotXpSemantic(
        reward.pilotName,
        reward.experienceGained,
      ),
    if (recap.petBondRewards.isEmpty && recap.petBondGained > 0)
      context.l10n.platformCompanionBondReward(recap.petBondGained),
    for (final HomeJourneyPetBondReward reward in recap.petBondRewards)
      context.l10n.platformNamedCompanionBondSemantic(
        reward.petName,
        reward.bondGained,
      ),
    for (final HomeJourneyMaterialReward material in recap.materials)
      context.l10n.platformMaterialReward(material.quantity, material.itemName),
  ];
}

String _readyEventChoiceRewardLabel(
  BuildContext context,
  HomeEventChoice choice,
) {
  final HomeMaterialRewardPreview? material = choice.materialReward;
  final String materialText = switch (material) {
    final HomeMaterialRewardPreview reward =>
      context.l10n.homeMaterialRewardSuffix(
        reward.quantity,
        context.l10n.currentItemName(reward.itemId, reward.itemName),
      ),
    null => '',
  };
  return context.l10n.platformJourneyReadyChoiceRewards(
    context.l10n.homeChoiceReward(
      choice.pilotExperienceReward,
      choice.petBondReward,
      materialText,
    ),
  );
}

typedef _ReadyEventChoiceLabel = ({
  String choiceId,
  String descriptionLabel,
  String? requirementLabel,
  String rewardLabel,
  String titleLabel,
});

class _JourneyDecisionLogCard extends StatelessWidget {
  const _JourneyDecisionLogCard({required this.snapshot});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<HomeExpeditionDecisionLogEntry> decisions = snapshot.decisionLog;
    final HomeExpeditionDecisionLogEntry? lastDecision =
        snapshot.lastAcceptedJourneyDecision;
    final List<ExpeditionRouteTrailNode> routeTrailNodes = snapshot.routeTrail
        .map(
          (HomeExpeditionRouteNode node) => ExpeditionRouteTrailNode(
            nodeId: node.nodeId,
            nodeName: context.l10n.currentNodeName(node.nodeId, node.nodeName),
            state: node.state,
            decision: node.decision == null
                ? null
                : ExpeditionRouteTrailDecision(
                    choiceId: node.decision!.choiceId,
                    choiceTitle: node.decision!.choiceTitle,
                    outcomeTitle: node.decision!.outcomeTitle,
                  ),
          ),
        )
        .toList(growable: false);
    final String? startedAt = switch (snapshot.journeyStartedAt) {
      final String value => _journeyStartedTimeLabel(context, value),
      null => null,
    };
    final String expedition = context.l10n.platformJourneyExpedition(
      context.l10n.currentExpeditionName(
        snapshot.expeditionId,
        snapshot.expeditionName,
      ),
    );
    final String pilotName = context.l10n.currentPilotName(
      snapshot.pilotId,
      snapshot.pilotName,
    );
    final String pilot = context.l10n.platformJourneyPilot(pilotName);
    final String? pilotPortraitLabel = snapshot.pilotId == 'navigator-v1'
        ? context.l10n.pilotPortraitSemantics(pilotName)
        : null;
    final String? pilotProgression = snapshot.hasPilotExperienceProgress
        ? context.l10n.platformJourneyPilotProgression(
            snapshot.pilotLevel,
            snapshot.pilotCurrentExperience,
            snapshot.pilotNextLevelExperience,
            snapshot.remainingPilotExperience,
          )
        : null;
    final String activeCompanion = context.l10n.platformJourneyActiveCompanion(
      context.l10n.currentPetName(snapshot.petId, snapshot.petName),
    );
    final String companionProgression = context.l10n
        .platformJourneyCompanionProgression(
          snapshot.petLevel,
          snapshot.petBond,
        );
    final String? petSpecies = snapshot.petSpecies;
    final int? petEvolutionStage = snapshot.petEvolutionStage;
    final String? companionForm =
        petSpecies == null || petEvolutionStage == null
        ? null
        : context.l10n.platformJourneyCompanionForm(
            context.l10n.currentPetSpecies(snapshot.petId, petSpecies),
            context.l10n.companionFormLabel(petEvolutionStage),
          );
    final String? companionPortraitLabel =
        snapshot.petId == null ||
            petSpecies == null ||
            petEvolutionStage == null
        ? null
        : context.l10n.companionPortraitDescription(
            name: context.l10n.currentPetName(snapshot.petId, snapshot.petName),
            species: context.l10n.currentPetSpecies(snapshot.petId, petSpecies),
            stage: petEvolutionStage,
            active: true,
            hasSparkHalo: false,
          );
    final String phase = _journeyPhaseLabel(context, snapshot.expeditionStatus);
    final String currentNodeName = context.l10n.currentNodeName(
      snapshot.currentNodeId,
      snapshot.currentNodeName,
    );
    final String currentPosition = context.l10n.platformJourneyCurrentPosition(
      currentNodeName,
    );
    final String energyProgress = context.l10n.platformJourneyEnergyProgress(
      snapshot.expeditionProgress,
      snapshot.requiredEnergy,
    );
    final HomeExpeditionEvent? readyEvent = switch (snapshot.unlockedEvent) {
      final HomeExpeditionEvent event when event.status == 'READY' => event,
      _ => null,
    };
    final String? readyEventTitle = switch (readyEvent) {
      final HomeExpeditionEvent event => context.l10n.currentEventTitle(
        event.eventId,
        event.title,
      ),
      null => null,
    };
    final String? readyEventSummary = switch (readyEvent) {
      final HomeExpeditionEvent event => context.l10n.currentEventSummary(
        event.eventId,
        event.summary,
      ),
      null => null,
    };
    final String? readyEventLabel = switch (readyEventTitle) {
      final String title => context.l10n.platformJourneyReadyEvent(title),
      null => null,
    };
    final String? readyEventSummaryLabel = switch (readyEventSummary) {
      final String summary => context.l10n.platformJourneyReadyEventSummary(
        summary,
      ),
      null => null,
    };
    final String? readyEventChoiceCountLabel = switch (readyEvent) {
      final HomeExpeditionEvent event when event.availableChoiceCount > 0 =>
        context.l10n.homeEventChoicesAvailable(event.availableChoiceCount),
      _ => null,
    };
    final List<_ReadyEventChoiceLabel> readyEventChoiceLabels =
        switch (readyEvent) {
          final HomeExpeditionEvent event => <_ReadyEventChoiceLabel>[
            for (final HomeEventChoice choice in event.availableChoices)
              (
                choiceId: choice.choiceId,
                titleLabel: context.l10n.platformJourneyReadyChoice(
                  context.l10n.currentEventChoiceTitle(
                    event.eventId,
                    choice.choiceId,
                    choice.title,
                  ),
                ),
                descriptionLabel: context.l10n
                    .platformJourneyReadyChoiceDescription(
                      context.l10n.currentEventChoiceDescription(
                        event.eventId,
                        choice.choiceId,
                        choice.description,
                      ),
                    ),
                requirementLabel: switch (choice.requirement) {
                  final HomeChoiceRequirement requirement =>
                    context.l10n.platformJourneyReadyChoiceRequirement(
                      context.l10n.currentEventRequirementDescription(
                        event.eventId,
                        choice.choiceId,
                        requirement.description,
                      ),
                    ),
                  null => null,
                },
                rewardLabel: _readyEventChoiceRewardLabel(context, choice),
              ),
          ],
          null => const <_ReadyEventChoiceLabel>[],
        };
    return ExpeditionPanel(
      key: const Key('platform-journey-decision-log'),
      tone: ExpeditionPanelTone.resonance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: ExpeditionBadge(
              key: const Key('platform-journey-decision-journey'),
              label: context.l10n.platformJourneyLabel(
                snapshot.expeditionJourneyNumber,
                snapshot.isCached ? context.l10n.platformSavedEntrySuffix : '',
              ),
              icon: Icons.alt_route,
              tone: ExpeditionPanelTone.resonance,
              allowWrap: true,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                context.l10n.platformDecisionLogTitle,
                style: theme.textTheme.titleLarge,
              ),
              if (decisions.isNotEmpty)
                ExcludeSemantics(
                  child: Text(
                    key: const Key('platform-current-journey-decision-count'),
                    context.l10n.platformDecisionsAcceptedCount(
                      snapshot.acceptedJourneyDecisionCount,
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.platformDecisionLogSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (pilotPortraitLabel != null ||
              companionPortraitLabel != null) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                if (pilotPortraitLabel != null)
                  Semantics(
                    key: const Key('platform-current-journey-pilot-portrait'),
                    container: true,
                    image: true,
                    label: pilotPortraitLabel,
                    child: ExcludeSemantics(
                      child: PilotPortrait(
                        name: pilotName,
                        highlighted: true,
                        size: 72,
                      ),
                    ),
                  ),
                if (companionPortraitLabel != null)
                  Semantics(
                    key: const Key(
                      'platform-current-journey-companion-portrait',
                    ),
                    container: true,
                    image: true,
                    label: companionPortraitLabel,
                    child: ExcludeSemantics(
                      child: CompanionPortrait(
                        petId: snapshot.petId!,
                        name: context.l10n.currentPetName(
                          snapshot.petId,
                          snapshot.petName,
                        ),
                        species: context.l10n.currentPetSpecies(
                          snapshot.petId,
                          petSpecies!,
                        ),
                        evolutionStage: petEvolutionStage!,
                        active: true,
                        size: 72,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Semantics(
            key: const Key('platform-current-journey-expedition'),
            container: true,
            label: expedition,
            child: ExcludeSemantics(
              child: Text(
                expedition,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            key: const Key('platform-current-journey-pilot'),
            container: true,
            label: pilot,
            child: ExcludeSemantics(
              child: Text(
                pilot,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (pilotProgression != null)
            Semantics(
              key: const Key('platform-current-journey-pilot-progression'),
              container: true,
              label: pilotProgression,
              child: ExcludeSemantics(
                child: Text(
                  pilotProgression,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          if (pilotProgression != null) const SizedBox(height: 6),
          Semantics(
            key: const Key('platform-current-journey-active-companion'),
            container: true,
            label: activeCompanion,
            child: ExcludeSemantics(
              child: Text(
                activeCompanion,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            key: const Key('platform-current-journey-companion-progression'),
            container: true,
            label: companionProgression,
            child: ExcludeSemantics(
              child: Text(
                companionProgression,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (companionForm != null)
            Semantics(
              key: const Key('platform-current-journey-companion-form'),
              container: true,
              label: companionForm,
              child: ExcludeSemantics(
                child: Text(
                  companionForm,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          if (companionForm != null) const SizedBox(height: 6),
          Semantics(
            key: const Key('platform-current-journey-phase'),
            container: true,
            label: phase,
            child: ExcludeSemantics(
              child: Text(
                phase,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            key: const Key('platform-current-journey-position'),
            container: true,
            label: currentPosition,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ExpeditionNodeSignal(
                    key: const Key('platform-current-journey-node-landmark'),
                    nodeId: snapshot.currentNodeId,
                    nodeName: currentNodeName,
                    completed: snapshot.expeditionStatus == 'COMPLETED',
                    markSize: 38,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentPosition,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            key: const Key('platform-current-journey-energy-progress'),
            container: true,
            label: energyProgress,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    energyProgress,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ExpeditionProgressSignal(
                    key: const Key(
                      'platform-current-journey-expedition-progress-signal',
                    ),
                    expeditionId: snapshot.expeditionId,
                    progress: snapshot.expeditionProgress,
                    target: snapshot.requiredEnergy,
                    height: 72,
                  ),
                ],
              ),
            ),
          ),
          if (routeTrailNodes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    context.l10n.expeditionRouteTrailTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    key: const Key('platform-current-journey-route-node-count'),
                    context.l10n.homeDiscoveredRouteNodes(
                      snapshot.discoveredRouteNodeCount,
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ExpeditionRouteTrail(
              key: const Key('platform-current-journey-route-trail'),
              nodes: routeTrailNodes,
            ),
          ],
          if (readyEvent != null &&
              readyEventTitle != null &&
              readyEventLabel != null &&
              readyEventSummaryLabel != null) ...<Widget>[
            const SizedBox(height: 8),
            Semantics(
              key: const Key('platform-current-journey-ready-event'),
              container: true,
              label: <String>[
                '$readyEventLabel. $readyEventSummaryLabel',
                if (readyEventChoiceCountLabel != null)
                  readyEventChoiceCountLabel,
                for (final choice in readyEventChoiceLabels) ...<String>[
                  choice.titleLabel,
                  choice.descriptionLabel,
                  if (choice.requirementLabel != null) choice.requirementLabel!,
                  choice.rewardLabel,
                ],
              ].join('\n'),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ExpeditionEventScene(
                      key: const Key(
                        'platform-current-journey-ready-event-scene',
                      ),
                      eventId: readyEvent.eventId,
                      eventTitle: readyEventTitle,
                      fallbackSemanticLabel: context.l10n.eventFallbackScene(
                        readyEventTitle,
                      ),
                      maxHeight: 144,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      readyEventLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      readyEventSummaryLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (readyEventChoiceCountLabel != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        key: const Key(
                          'platform-current-journey-ready-event-choice-count',
                        ),
                        readyEventChoiceCountLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    for (final choice in readyEventChoiceLabels) ...<Widget>[
                      const SizedBox(height: 8),
                      EventChoiceSignalLayout(
                        key: Key(
                          'platform-current-journey-ready-event-choice-'
                          '${choice.choiceId}-signal',
                        ),
                        eventId: readyEvent.eventId,
                        choiceId: choice.choiceId,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              key: Key(
                                'platform-current-journey-ready-event-choice-'
                                '${choice.choiceId}',
                              ),
                              choice.titleLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              key: Key(
                                'platform-current-journey-ready-event-choice-'
                                '${choice.choiceId}-description',
                              ),
                              choice.descriptionLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            if (choice.requirementLabel != null) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                key: Key(
                                  'platform-current-journey-ready-event-'
                                  'choice-${choice.choiceId}-requirement',
                                ),
                                choice.requirementLabel!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.tertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              key: Key(
                                'platform-current-journey-ready-event-choice-'
                                '${choice.choiceId}-rewards',
                              ),
                              choice.rewardLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (startedAt != null) ...<Widget>[
            const SizedBox(height: 6),
            Semantics(
              key: const Key('platform-current-journey-started-at'),
              container: true,
              label: startedAt,
              child: ExcludeSemantics(
                child: Text(
                  startedAt,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          if (lastDecision != null) ...<Widget>[
            const SizedBox(height: 12),
            _LatestJourneyDecisionSummary(entry: lastDecision),
          ],
          const SizedBox(height: 16),
          if (decisions.isEmpty)
            Semantics(
              key: const Key('platform-journey-decision-empty'),
              container: true,
              label: context.l10n.platformNoDecisions(
                snapshot.expeditionJourneyNumber,
              ),
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.56,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.explore_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(context.l10n.platformFirstDecisionHint),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            for (
              int index = 0;
              index < decisions.length;
              index += 1
            ) ...<Widget>[
              _JourneyDecisionEntry(
                entry: decisions[index],
                index: index,
                total: decisions.length,
              ),
              if (index < decisions.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _LatestJourneyDecisionSummary extends StatelessWidget {
  const _LatestJourneyDecisionSummary({required this.entry});

  final HomeExpeditionDecisionLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<String> rewardLabels = _journeyDecisionRewardLabels(
      context,
      entry,
    );
    final List<String> visibleRewardLabels = _journeyDecisionRewardLabels(
      context,
      entry,
      semantic: false,
    );
    final String resolvedAt = _journeyDecisionTimeLabel(context, entry);
    return Semantics(
      key: const Key('platform-current-journey-latest-decision'),
      container: true,
      label: context.l10n.platformLatestDecisionSemantics(
        entry.eventTitle,
        entry.choiceTitle,
        entry.outcomeTitle,
        entry.outcomeSummary,
        resolvedAt,
        rewardLabels.isEmpty
            ? ''
            : context.l10n.platformRewardsSuffix(rewardLabels.join('; ')),
      ),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.secondaryContainer.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.platformLatestDecisionTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.platformLatestDecisionChoice(entry.choiceTitle),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.platformLatestDecisionOutcome(
                    entry.eventTitle,
                    entry.outcomeTitle,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.platformLatestDecisionSummary(
                    entry.outcomeSummary,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  resolvedAt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (visibleRewardLabels.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.platformLatestDecisionRewards(
                      visibleRewardLabels.join('; '),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyDecisionEntry extends StatelessWidget {
  const _JourneyDecisionEntry({
    required this.entry,
    required this.index,
    required this.total,
  });

  final HomeExpeditionDecisionLogEntry entry;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<String> rewardLabels = _journeyDecisionRewardLabels(
      context,
      entry,
    );
    final String resolvedAt = _journeyDecisionTimeLabel(context, entry);
    return Semantics(
      key: Key('platform-journey-decision-${entry.eventId}'),
      container: true,
      label: context.l10n.platformDecisionEntrySemantics(
        index + 1,
        total,
        entry.eventTitle,
        entry.choiceTitle,
        entry.outcomeTitle,
        entry.outcomeSummary,
        '$resolvedAt.',
        rewardLabels.isEmpty
            ? ''
            : context.l10n.platformRewardsSuffix(rewardLabels.join('; ')),
      ),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.secondary),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.eventTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.subdirectory_arrow_right,
                            size: 18,
                            color: colors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.choiceTitle,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.outcomeTitle,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry.outcomeSummary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        resolvedAt,
                        key: Key(
                          'platform-journey-decision-${entry.eventId}-time',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (rewardLabels.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: <Widget>[
                            if (entry.pilotExperienceGained > 0)
                              _JourneyRewardChip(
                                icon: Icons.star_outline,
                                label: context.l10n.platformPilotXpReward(
                                  entry.pilotExperienceGained,
                                ),
                              ),
                            if (entry.petBondGained > 0)
                              _JourneyRewardChip(
                                icon: Icons.favorite_border,
                                label: switch (entry.petName) {
                                  final String petName =>
                                    context.l10n
                                        .platformNamedCompanionBondReward(
                                          petName,
                                          entry.petBondGained,
                                        ),
                                  null =>
                                    context.l10n.platformCompanionBondReward(
                                      entry.petBondGained,
                                    ),
                                },
                              ),
                            if (entry.materialReward
                                case final HomeJourneyMaterialReward material)
                              _JourneyRewardChip(
                                icon: Icons.inventory_2_outlined,
                                label: context.l10n.platformMaterialReward(
                                  material.quantity,
                                  material.itemName,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _journeyDecisionRewardLabels(
  BuildContext context,
  HomeExpeditionDecisionLogEntry entry, {
  bool semantic = true,
}) {
  return <String>[
    if (entry.pilotExperienceGained > 0)
      context.l10n.platformPilotXpReward(entry.pilotExperienceGained),
    if (entry.petBondGained > 0)
      switch (entry.petName) {
        final String petName =>
          semantic
              ? context.l10n.platformNamedCompanionBondSemantic(
                  petName,
                  entry.petBondGained,
                )
              : context.l10n.platformNamedCompanionBondReward(
                  petName,
                  entry.petBondGained,
                ),
        null => context.l10n.platformCompanionBondReward(entry.petBondGained),
      },
    if (entry.materialReward case final HomeJourneyMaterialReward material)
      context.l10n.platformMaterialReward(material.quantity, material.itemName),
  ];
}

class _JourneyRewardChip extends StatelessWidget {
  const _JourneyRewardChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 16, color: colors.secondary),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: colors.outlineVariant),
      backgroundColor: colors.secondaryContainer.withValues(alpha: 0.42),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: colors.onSecondaryContainer,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _JournalHero extends StatelessWidget {
  const _JournalHero({required this.data, required this.equippedCosmeticIds});

  final _PlatformViewData data;
  final Set<String> equippedCosmeticIds;

  @override
  Widget build(BuildContext context) {
    final PlatformSnapshot snapshot = data.platform;
    final PlatformPet activePet = snapshot.activePet;
    final String activePetName = context.l10n.currentPetName(
      activePet.petId,
      activePet.name,
    );
    final String activePetSpecies = context.l10n.currentPetSpecies(
      activePet.petId,
      activePet.species,
    );
    final String pilotName = context.l10n.currentPilotName(
      'navigator-v1',
      'Navigator',
    );
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final List<String> equippedCosmeticNames = snapshot.content.cosmetics
        .where(
          (PlatformCosmetic cosmetic) =>
              equippedCosmeticIds.contains(cosmetic.cosmeticId),
        )
        .map(
          (PlatformCosmetic cosmetic) => context.l10n
              .currentPlatformCosmeticName(cosmetic.cosmeticId, cosmetic.name),
        )
        .toList(growable: false);
    final Widget crewPortraits = ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PilotPortrait(
            key: const Key('platform-hero-pilot-portrait'),
            name: pilotName,
            size: 64,
            highlighted: true,
            equippedCosmeticIds: equippedCosmeticIds,
          ),
          const SizedBox(width: 10),
          CompanionPortrait(
            key: const Key('platform-hero-pet-portrait'),
            petId: activePet.petId,
            name: activePetName,
            species: activePetSpecies,
            evolutionStage: activePet.evolutionStage,
            active: true,
            size: 64,
            equippedCosmeticIds: equippedCosmeticIds,
          ),
        ],
      ),
    );
    final Widget crewCopy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.platformCrewTitle(activePetName),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          equippedCosmeticNames.isEmpty
              ? context.l10n.platformNoActiveCosmetics
              : context.l10n.platformEquippedCosmetics(
                  equippedCosmeticNames.join(' · '),
                ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );

    return ExpeditionPanel(
      key: const Key('platform-journal-hero'),
      tone: ExpeditionPanelTone.resonance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ExpeditionBadge(
                    label: context.l10n.platformPilotJournalBadge,
                    icon: Icons.route_outlined,
                    tone: ExpeditionPanelTone.resonance,
                    allowWrap: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.public, color: palette.resonance, size: 22),
            ],
          ),
          const SizedBox(height: 18),
          ProfileCosmeticFrame(
            key: const Key('platform-profile-cosmetic-frame'),
            cosmeticId: _profileCosmeticIdFor(snapshot),
            child: ChapterVista(
              key: const Key('platform-chapter-vista'),
              semanticLabel: context.l10n.platformChapterVistaSemantics,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.currentPlatformSeasonName(
              snapshot.content.season.seasonId,
              snapshot.content.season.name,
            ),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.platformChapterState(
              snapshot.content.chapterNodes,
              snapshot.stateVersion,
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ExpeditionBadge(
                label: context.l10n.platformCompanionLevelShort(
                  activePetName,
                  activePet.level,
                ),
                icon: Icons.pets_outlined,
              ),
              ExpeditionBadge(
                label: context.l10n.companionFormLabel(
                  activePet.evolutionStage,
                ),
                icon: Icons.auto_awesome_outlined,
                tone: ExpeditionPanelTone.resonance,
                allowWrap: true,
              ),
              ExpeditionBadge(
                label: '${snapshot.userState.seasonXp} XP',
                icon: Icons.auto_awesome_outlined,
                tone: ExpeditionPanelTone.resonance,
              ),
              ExpeditionBadge(
                label: data.availableEnergy == null
                    ? 'ENERGY —'
                    : '${data.availableEnergy} ENERGY',
                icon: Icons.bolt,
                tone: ExpeditionPanelTone.energy,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            key: const Key('platform-journal-crew'),
            container: true,
            label: context.l10n.platformCrewSemantics(
              activePetName,
              equippedCosmeticNames.isEmpty
                  ? context.l10n.platformNoActiveCosmetics
                  : context.l10n.platformEquippedCosmetics(
                      equippedCosmeticNames.join(', '),
                    ),
            ),
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  if (_usesCompactPlatformSection(context, constraints)) {
                    return Column(
                      key: const Key('platform-journal-crew-compact'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        crewPortraits,
                        const SizedBox(height: 12),
                        crewCopy,
                      ],
                    );
                  }
                  return Row(
                    key: const Key('platform-journal-crew-wide'),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      crewPortraits,
                      const SizedBox(width: 16),
                      Expanded(child: crewCopy),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.snapshot, required this.onResume});

  final PlatformSnapshot snapshot;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final List<String> steps = snapshot.content.onboardingSteps;
    final Set<String> completed = snapshot.userState.completedOnboardingSteps;
    final int completedCount = snapshot.completedCatalogOnboardingStepCount;
    final int remainingCount = snapshot.remainingCatalogOnboardingStepCount;
    final String guidance = remainingCount == 0
        ? context.l10n.platformOnboardingJourneyComplete
        : context.l10n.platformOnboardingStagesRemaining(remainingCount);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget icon = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.all(11),
        child: Icon(Icons.flag_outlined),
      ),
    );
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          snapshot.userState.onboardingComplete
              ? context.l10n.platformPathOpen
              : context.l10n.platformPathBeginning,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 3),
        ExcludeSemantics(
          child: Text(
            guidance,
            key: const Key('platform-onboarding-guidance'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          snapshot.userState.onboardingComplete
              ? context.l10n.platformPathOpenDescription
              : context.l10n.platformPathBeginningDescription,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
    final Widget progressBadge = ExpeditionBadge(
      label: '$completedCount/${steps.length}',
      icon: Icons.alt_route,
    );
    return ExpeditionPanel(
      tone: ExpeditionPanelTone.lumen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (_usesCompactPlatformSection(context, constraints)) {
                return Column(
                  key: const Key('platform-onboarding-compact'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[icon, const Spacer(), progressBadge],
                    ),
                    const SizedBox(height: 12),
                    details,
                  ],
                );
              }
              return Row(
                key: const Key('platform-onboarding-wide'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  progressBadge,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FirstJourneyRouteSignal(
            steps: steps,
            completedSteps: completed,
            semanticGuidance: guidance,
          ),
          const SizedBox(height: 14),
          for (final String step in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Semantics(
                key: Key('platform-onboarding-step-$step'),
                container: true,
                label: context.l10n.platformOnboardingStepSemantics(
                  context.l10n.currentPlatformOnboardingStep(step, step),
                  completed.contains(step)
                      ? context.l10n.platformCompletedStatus
                      : context.l10n.platformIncompleteStatus,
                ),
                child: ExcludeSemantics(
                  child: Row(
                    children: <Widget>[
                      Icon(
                        completed.contains(step)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: completed.contains(step)
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.currentPlatformOnboardingStep(
                            step,
                            step,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!snapshot.userState.onboardingComplete) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('platform-resume-first-journey'),
                onPressed: onResume,
                icon: const Icon(Icons.route_outlined),
                label: Text(
                  context.l10n.platformResumeFirstJourney,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeklyRouteCard extends StatelessWidget {
  const _WeeklyRouteCard({
    required this.snapshot,
    required this.availableEnergy,
    required this.economyVersion,
    required this.energyCopy,
    required this.busy,
    required this.onAdvance,
    required this.onClaimSeasonReward,
  });

  final PlatformSnapshot snapshot;
  final int? availableEnergy;
  final int? economyVersion;
  final String energyCopy;
  final bool busy;
  final ValueChanged<int> onAdvance;
  final ValueChanged<int> onClaimSeasonReward;

  @override
  Widget build(BuildContext context) {
    final int remaining = snapshot.weeklyRouteRemaining;
    final int spendable = availableEnergy == null
        ? 0
        : _minimum(remaining, availableEnergy!);
    final List<int>? unclaimedRewardLevels =
        snapshot.unclaimedSeasonRewardLevels;
    final int? nextRewardLevel = snapshot.nextSeasonRewardLevel;
    final int? remainingSeasonXp = snapshot.remainingSeasonXpToNextReward;
    int? rewardLevel;
    if (unclaimedRewardLevels != null) {
      rewardLevel = unclaimedRewardLevels.isEmpty
          ? null
          : unclaimedRewardLevels.first;
    } else {
      for (int level = 1; level <= snapshot.claimableSeasonLevel; level += 1) {
        if (!snapshot.userState.achievements.contains('season-reward-$level')) {
          rewardLevel = level;
          break;
        }
      }
    }
    final String seasonName = context.l10n.currentPlatformSeasonName(
      snapshot.content.season.seasonId,
      snapshot.content.season.name,
    );
    final String? seasonRewardGuidance =
        nextRewardLevel != null && remainingSeasonXp != null
        ? context.l10n.platformSeasonRewardRemainingXp(
            nextRewardLevel,
            remainingSeasonXp,
          )
        : null;
    final int unclaimedRewardCount = unclaimedRewardLevels?.length ?? 0;
    final String? claimableRewardsGuidance = unclaimedRewardCount == 0
        ? null
        : context.l10n.platformSeasonRewardsAvailable(unclaimedRewardCount);

    final ColorScheme colors = Theme.of(context).colorScheme;
    return ExpeditionPanel(
      tone: ExpeditionPanelTone.energy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget badge = ExpeditionBadge(
                label: context.l10n.platformWeeklyRouteTitle,
                icon: Icons.route_outlined,
                tone: ExpeditionPanelTone.energy,
                allowWrap: true,
              );
              final Widget level = Text(
                context.l10n.platformSeasonLevel(
                  snapshot.userState.seasonLevel,
                ),
                style: Theme.of(context).textTheme.labelLarge,
              );
              if (_usesCompactPlatformSection(context, constraints)) {
                return Column(
                  key: const Key('platform-weekly-heading-compact'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[badge, const SizedBox(height: 8), level],
                );
              }
              return Row(
                key: const Key('platform-weekly-heading-wide'),
                children: <Widget>[badge, const Spacer(), level],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    seasonName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${snapshot.userState.seasonXp} XP · '
                    '${context.l10n.platformEnergyRemaining(remaining)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (seasonRewardGuidance != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Semantics(
                      container: true,
                      label: seasonRewardGuidance,
                      excludeSemantics: true,
                      child: Text(
                        seasonRewardGuidance,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  if (claimableRewardsGuidance != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Semantics(
                      container: true,
                      label: claimableRewardsGuidance,
                      excludeSemantics: true,
                      child: Text(
                        claimableRewardsGuidance,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(energyCopy),
                  const SizedBox(height: 4),
                  Text(
                    availableEnergy == null
                        ? context.l10n.platformEnergyBalanceUnavailable
                        : context.l10n.platformEnergyAvailable(
                            availableEnergy!,
                            economyVersion == null
                                ? ''
                                : context.l10n.platformEconomyVersionSuffix(
                                    economyVersion!,
                                  ),
                          ),
                  ),
                ],
              );
              final Widget routeSignal = WeeklyRouteSignal(
                routeId: snapshot.content.weeklyRoute.routeId,
                seasonName: seasonName,
                progress: snapshot.userState.weeklyRouteProgress,
                target: snapshot.userState.weeklyRouteRequiredEnergy,
                size: 120,
              );
              if (_usesCompactPlatformSection(context, constraints)) {
                return Column(
                  key: const Key('platform-weekly-route-compact'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(child: routeSignal),
                    const SizedBox(height: 16),
                    summary,
                  ],
                );
              }
              return Row(
                key: const Key('platform-weekly-route-wide'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  routeSignal,
                  const SizedBox(width: 18),
                  Expanded(child: summary),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                key: const Key('platform-advance-weekly'),
                onPressed:
                    busy ||
                        !snapshot.remoteConfig.weeklyRouteEnabled ||
                        spendable <= 0
                    ? null
                    : () => onAdvance(spendable),
                icon: const Icon(Icons.route_outlined),
                label: Text(
                  remaining == 0
                      ? context.l10n.platformWeeklyRouteCompleted
                      : context.l10n.platformSpendEnergy(spendable),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                ),
              ),
              if (rewardLevel != null)
                OutlinedButton.icon(
                  key: Key('platform-claim-season-$rewardLevel'),
                  onPressed: busy
                      ? null
                      : () => onClaimSeasonReward(rewardLevel!),
                  icon: SeasonRewardSeal(
                    seasonId: snapshot.content.season.seasonId,
                    level: rewardLevel,
                    totalLevels: snapshot.content.season.levels,
                  ),
                  label: Text(
                    context.l10n.platformSeasonRewardLevel(rewardLevel),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.pet,
    required this.equippedCosmeticIds,
    required this.busy,
    required this.onSelect,
    required this.onEvolve,
  });

  final PlatformPet pet;
  final Set<String> equippedCosmeticIds;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onEvolve;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String petName = context.l10n.currentPetName(pet.petId, pet.name);
    final String petSpecies = context.l10n.currentPetSpecies(
      pet.petId,
      pet.species,
    );
    final String petTrait = context.l10n.journeyPetTrait(pet.petId, pet.trait);
    final String evolutionStage = context.l10n.companionStageName(
      pet.evolutionStage,
    );
    final bool showsRemainingBond = !pet.isFullyEvolved && !pet.canEvolve;
    final String evolutionGuidance = pet.isFullyEvolved
        ? '$evolutionStage — ${context.l10n.platformPetFullyEvolved}'
        : pet.canEvolve
        ? context.l10n.platformPetReadyToEvolve
        : context.l10n.platformPetBondRemaining(pet.remainingEvolutionBond);
    final Widget portrait = CompanionPortrait(
      key: Key('platform-pet-portrait-${pet.petId}'),
      petId: pet.petId,
      name: petName,
      species: petSpecies,
      evolutionStage: pet.evolutionStage,
      active: pet.active,
      size: 78,
      equippedCosmeticIds: equippedCosmeticIds,
    );
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.platformPetLevelSemantics(petName, pet.level),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        Text(
          '$petSpecies · $petTrait',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            if (pet.active)
              ExpeditionBadge(
                label: context.l10n.platformInSquadBadge,
                icon: Icons.check_circle_outline,
              ),
            ExpeditionBadge(
              label: context.l10n.companionFormLabel(pet.evolutionStage),
              icon: Icons.auto_awesome_outlined,
              tone: pet.evolutionStage > 0
                  ? ExpeditionPanelTone.resonance
                  : ExpeditionPanelTone.neutral,
            ),
          ],
        ),
      ],
    );
    return ExpeditionPanel(
      tone: pet.active
          ? ExpeditionPanelTone.lumen
          : ExpeditionPanelTone.neutral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (_usesCompactPlatformSection(context, constraints)) {
                return Column(
                  key: Key('platform-pet-compact-${pet.petId}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    portrait,
                    const SizedBox(height: 12),
                    details,
                  ],
                );
              }
              return Row(
                key: Key('platform-pet-wide-${pet.petId}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  portrait,
                  const SizedBox(width: 16),
                  Expanded(child: details),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          CompanionGrowthTrack(
            key: Key('platform-pet-growth-${pet.petId}'),
            currentStage: pet.evolutionStage,
          ),
          const SizedBox(height: 16),
          CompanionBondSignal(
            petId: pet.petId,
            petName: petName,
            bond: pet.bond,
            evolutionBond: pet.evolutionBond,
            remainingBond: pet.remainingEvolutionBond,
            canEvolve: pet.canEvolve,
            fullyEvolved: pet.isFullyEvolved,
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            excluding: showsRemainingBond,
            child: Text(
              evolutionGuidance,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!pet.active)
                OutlinedButton.icon(
                  key: Key('platform-select-pet-${pet.petId}'),
                  onPressed: busy ? null : onSelect,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    context.l10n.platformSelectCompanion,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ExpeditionBadge(
                  label: context.l10n.platformActiveCompanion,
                  icon: Icons.pets,
                ),
              if (!pet.isFullyEvolved)
                FilledButton.tonalIcon(
                  key: Key('platform-evolve-pet-${pet.petId}'),
                  onPressed: busy || !pet.canEvolve ? null : onEvolve,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    pet.canEvolve
                        ? context.l10n.platformEvolveCompanion
                        : context.l10n.platformNeedMoreBond,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.skill,
    required this.seasonXp,
    required this.unlocked,
    required this.busy,
    required this.onUnlock,
  });

  final PlatformSkill skill;
  final int seasonXp;
  final bool unlocked;
  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final int remainingSeasonXp = skill.remainingSeasonXp(seasonXp);
    final bool available = remainingSeasonXp == 0;
    final String skillName = context.l10n.currentPlatformSkillName(
      skill.skillId,
      skill.name,
    );
    final String skillDescription = context.l10n
        .currentPlatformSkillDescription(skill.skillId, skill.description);
    final String experienceGuidance = !unlocked && !available
        ? context.l10n.platformSkillRemainingXp(remainingSeasonXp)
        : context.l10n.platformSkillRequiredXp(skill.requiredSeasonXp);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (_usesCompactPlatformSection(context, constraints)) {
          return ExpeditionPanel(
            key: Key('platform-skill-compact-${skill.skillId}'),
            tone: unlocked
                ? ExpeditionPanelTone.lumen
                : ExpeditionPanelTone.neutral,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ProgressionSigil(
                      identity: skill.skillId,
                      active: unlocked,
                      size: 56,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        skillName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(skillDescription),
                const SizedBox(height: 4),
                Text(experienceGuidance),
                const SizedBox(height: 12),
                if (unlocked)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ExpeditionBadge(
                      label: context.l10n.platformSkillUnlocked,
                      icon: Icons.lock_open,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    key: Key('platform-unlock-skill-${skill.skillId}'),
                    onPressed: busy || !available ? null : onUnlock,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(
                      available
                          ? context.l10n.platformUnlockSkill
                          : context.l10n.platformSkillUnavailable,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        }
        return ExpeditionPanel(
          key: Key('platform-skill-wide-${skill.skillId}'),
          tone: unlocked
              ? ExpeditionPanelTone.lumen
              : ExpeditionPanelTone.neutral,
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            leading: ProgressionSigil(
              identity: skill.skillId,
              active: unlocked,
              size: 52,
            ),
            title: Text(skillName),
            subtitle: Text('$skillDescription\n$experienceGuidance'),
            isThreeLine: true,
            trailing: unlocked
                ? Icon(
                    Icons.lock_open,
                    semanticLabel: context.l10n.platformSkillUnlocked,
                  )
                : IconButton(
                    key: Key('platform-unlock-skill-${skill.skillId}'),
                    tooltip: available
                        ? context.l10n.platformUnlockSkill
                        : context.l10n.platformSkillUnavailable,
                    onPressed: busy || !available ? null : onUnlock,
                    icon: const Icon(Icons.lock_outline),
                  ),
          ),
        );
      },
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.rewardFirst,
    required this.busy,
    required this.onClaim,
  });

  final PlatformQuest quest;
  final bool rewardFirst;
  final bool busy;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final String questName = context.l10n.currentPlatformQuestName(
      quest.questId,
      quest.name,
    );
    final Widget progress = QuestRouteProgress(
      questId: quest.questId,
      questName: questName,
      metric: quest.metric,
      progress: quest.progress,
      target: quest.target,
      remaining: quest.remainingProgress,
      ready: quest.ready,
      claimed: quest.claimed,
    );
    final Widget reward = Text(
      context.l10n.platformQuestReward(
        quest.seasonXpReward,
        quest.petBondReward,
      ),
    );
    final ExpeditionBadge status = ExpeditionBadge(
      label: quest.claimed
          ? context.l10n.platformQuestReceived
          : quest.ready
          ? context.l10n.platformQuestReady
          : context.l10n.platformQuestInProgress,
      icon: quest.claimed
          ? Icons.check_circle_outline
          : Icons.assignment_outlined,
      tone: quest.ready && !quest.claimed
          ? ExpeditionPanelTone.energy
          : ExpeditionPanelTone.neutral,
    );

    return ExpeditionPanel(
      tone: quest.ready && !quest.claimed
          ? ExpeditionPanelTone.energy
          : ExpeditionPanelTone.neutral,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = _usesCompactPlatformSection(
            context,
            constraints,
          );
          final Widget signal = QuestRouteSignal(
            questId: quest.questId,
            metric: quest.metric,
            ready: quest.ready,
            claimed: quest.claimed,
            size: compact ? 64 : 72,
          );
          final Widget action = FilledButton.tonal(
            key: Key('platform-claim-quest-${quest.questId}'),
            onPressed: busy || !quest.ready || quest.claimed ? null : onClaim,
            child: Text(
              quest.claimed
                  ? context.l10n.platformQuestReceived
                  : quest.ready
                  ? context.l10n.platformClaimQuestReward
                  : context.l10n.platformQuestWorking,
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
          );
          return Column(
            key: Key(
              'platform-quest-${compact ? 'compact' : 'wide'}-'
              '${quest.questId}',
            ),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (compact) ...<Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    signal,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: status,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(questName, style: Theme.of(context).textTheme.titleMedium),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    signal,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        questName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    status,
                  ],
                ),
              const SizedBox(height: 12),
              if (rewardFirst) reward else progress,
              const SizedBox(height: 8),
              if (rewardFirst) progress else reward,
              const SizedBox(height: 12),
              if (compact)
                SizedBox(width: double.infinity, child: action)
              else
                Align(alignment: Alignment.centerRight, child: action),
            ],
          );
        },
      ),
    );
  }
}

class _SquadCard extends StatelessWidget {
  const _SquadCard({
    required this.squad,
    required this.nameController,
    required this.idController,
    required this.busy,
    required this.onCreate,
    required this.onJoin,
    required this.onLeave,
  });

  final PlatformSquad? squad;
  final TextEditingController nameController;
  final TextEditingController idController;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final PlatformSquad? current = squad;
    if (current != null) {
      final int memberCount = current.memberUserIds.length;
      return ExpeditionPanel(
        tone: ExpeditionPanelTone.resonance,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExpeditionSectionTitle(
              title: context.l10n.platformSquadTitle,
              subtitle: context.l10n.platformSquadSubtitle,
              icon: Icons.groups_outlined,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = _usesCompactPlatformSection(
                  context,
                  constraints,
                );
                final Widget formation = SquadFormationSignal(
                  connected: true,
                  memberCount: memberCount,
                  size: compact ? 104 : 120,
                );
                final Widget summary = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      key: const Key('platform-squad-summary'),
                      container: true,
                      label: context.l10n.platformSquadSemantics(
                        current.name,
                        memberCount,
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              current.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ExpeditionBadge(
                              label: context.l10n.platformSquadMembers(
                                memberCount,
                              ),
                              icon: Icons.group_outlined,
                              tone: ExpeditionPanelTone.resonance,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      context.l10n.platformSquadId(current.squadId),
                    ),
                  ],
                );
                final Widget action = OutlinedButton.icon(
                  key: const Key('platform-leave-squad'),
                  onPressed: busy ? null : onLeave,
                  icon: const Icon(Icons.logout),
                  label: Text(
                    context.l10n.platformLeaveSquad,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                  ),
                );

                if (compact) {
                  return Column(
                    key: const Key('platform-squad-connected-compact'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(child: formation),
                      const SizedBox(height: 14),
                      summary,
                      const SizedBox(height: 14),
                      SizedBox(width: double.infinity, child: action),
                    ],
                  );
                }
                return Column(
                  key: const Key('platform-squad-connected-wide'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        formation,
                        const SizedBox(width: 18),
                        Expanded(child: summary),
                      ],
                    ),
                    const SizedBox(height: 14),
                    action,
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    return ExpeditionPanel(
      tone: ExpeditionPanelTone.resonance,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = _usesCompactPlatformSection(
            context,
            constraints,
          );
          const Widget formation = SquadFormationSignal(
            connected: false,
            memberCount: 0,
            size: 104,
          );
          final Widget introduction = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.platformFreeChannel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              Text(
                context.l10n.platformFreeChannelDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
          final Widget createAction = FilledButton.tonalIcon(
            key: const Key('platform-create-squad'),
            onPressed: busy || nameController.text.trim().isEmpty
                ? null
                : onCreate,
            icon: const Icon(Icons.group_add_outlined),
            label: Text(
              context.l10n.platformCreateSquad,
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
          );
          final Widget joinAction = OutlinedButton.icon(
            key: const Key('platform-join-squad'),
            onPressed: busy || idController.text.trim().isEmpty ? null : onJoin,
            icon: const Icon(Icons.login),
            label: Text(
              context.l10n.platformJoinSquad,
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ExpeditionSectionTitle(
                title: context.l10n.platformSquadTitle,
                subtitle: context.l10n.platformSquadEmptySubtitle,
                icon: Icons.groups_outlined,
              ),
              const SizedBox(height: 14),
              if (compact)
                Column(
                  key: const Key('platform-squad-empty-compact'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Center(child: formation),
                    const SizedBox(height: 12),
                    introduction,
                  ],
                )
              else
                Row(
                  key: const Key('platform-squad-empty-wide'),
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    formation,
                    const SizedBox(width: 18),
                    Expanded(child: introduction),
                  ],
                ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('platform-squad-name'),
                controller: nameController,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: context.l10n.platformNewSquadNameLabel,
                ),
              ),
              const SizedBox(height: 8),
              if (compact)
                SizedBox(width: double.infinity, child: createAction)
              else
                Align(alignment: Alignment.centerLeft, child: createAction),
              const Divider(height: 28),
              TextField(
                key: const Key('platform-squad-id'),
                controller: idController,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: context.l10n.platformExistingSquadIdLabel,
                ),
              ),
              const SizedBox(height: 8),
              if (compact)
                SizedBox(width: double.infinity, child: joinAction)
              else
                Align(alignment: Alignment.centerLeft, child: joinAction),
            ],
          );
        },
      ),
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.cosmetic,
    required this.previewPet,
    required this.owned,
    required this.active,
    required this.paymentsEnabled,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
  });

  final PlatformCosmetic cosmetic;
  final PlatformPet? previewPet;
  final bool owned;
  final bool active;
  final bool paymentsEnabled;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final String cosmeticName = context.l10n.currentPlatformCosmeticName(
      cosmetic.cosmeticId,
      cosmetic.name,
    );
    final String slotLabel = switch (cosmetic.slot) {
      'PILOT' => context.l10n.platformCosmeticPilotSlot,
      'PET' => context.l10n.platformCosmeticPetSlot,
      'PROFILE' => context.l10n.platformCosmeticProfileSlot,
      _ => cosmetic.slot,
    };
    final String subtitle = paymentsEnabled
        ? '$slotLabel · '
              '${cosmetic.sandboxPrice == 0 ? context.l10n.platformCosmeticBasePrice : context.l10n.platformCosmeticSandboxPrice(cosmetic.sandboxPrice)}'
        : slotLabel;
    final Widget? action = active
        ? Chip(
            key: Key('platform-equipped-cosmetic-${cosmetic.cosmeticId}'),
            label: Text(context.l10n.platformCosmeticEquipped),
          )
        : owned
        ? FilledButton.tonal(
            key: Key('platform-equip-cosmetic-${cosmetic.cosmeticId}'),
            onPressed: busy ? null : onEquip,
            child: Text(context.l10n.platformEquipCosmetic),
          )
        : paymentsEnabled
        ? FilledButton.tonal(
            key: Key('platform-buy-cosmetic-${cosmetic.cosmeticId}'),
            onPressed: busy ? null : onBuy,
            child: Text(context.l10n.platformBuyCosmetic),
          )
        : null;
    final Widget icon = switch (cosmetic.cosmeticId) {
      CharacterCosmeticIds.pilotScarf => ExcludeSemantics(
        child: PilotMotionPortrait(
          key: Key('platform-cosmetic-preview-${cosmetic.cosmeticId}'),
          pilotId: PilotMotionPortrait.navigatorPilotId,
          name: context.l10n.currentPilotName('navigator-v1', 'Navigator'),
          size: 52,
          equippedCosmeticIds: <String>{cosmetic.cosmeticId},
        ),
      ),
      CharacterCosmeticIds.sparkHalo when previewPet != null =>
        ExcludeSemantics(
          child: CompanionPortrait(
            key: Key('platform-cosmetic-preview-${cosmetic.cosmeticId}'),
            petId: previewPet!.petId,
            name: context.l10n.currentPetName(
              previewPet!.petId,
              previewPet!.name,
            ),
            species: context.l10n.currentPetSpecies(
              previewPet!.petId,
              previewPet!.species,
            ),
            evolutionStage: previewPet!.evolutionStage,
            size: 52,
            equippedCosmeticIds: <String>{cosmetic.cosmeticId},
          ),
        ),
      _ when cosmetic.slot == 'PROFILE' => ProfileCosmeticPreview(
        key: Key('platform-cosmetic-preview-${cosmetic.cosmeticId}'),
        cosmeticId: cosmetic.cosmeticId,
      ),
      _ => CircleAvatar(
        key: Key('platform-cosmetic-preview-${cosmetic.cosmeticId}'),
        backgroundColor: context.walkingRpgPalette.resonance.withValues(
          alpha: 0.14,
        ),
        child: Icon(
          Icons.auto_awesome_outlined,
          color: context.walkingRpgPalette.resonance,
        ),
      ),
    };
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (_usesCompactPlatformSection(context, constraints)) {
          return ExpeditionPanel(
            key: Key('platform-cosmetic-compact-${cosmetic.cosmeticId}'),
            tone: active
                ? ExpeditionPanelTone.resonance
                : ExpeditionPanelTone.neutral,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    icon,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cosmeticName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(subtitle),
                if (action != null) ...<Widget>[
                  const SizedBox(height: 12),
                  if (active)
                    Align(alignment: Alignment.centerLeft, child: action)
                  else
                    SizedBox(width: double.infinity, child: action),
                ],
              ],
            ),
          );
        }
        return ExpeditionPanel(
          key: Key('platform-cosmetic-wide-${cosmetic.cosmeticId}'),
          tone: active
              ? ExpeditionPanelTone.resonance
              : ExpeditionPanelTone.neutral,
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            leading: icon,
            title: Text(cosmeticName),
            subtitle: Text(subtitle),
            trailing: action,
          ),
        );
      },
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.snapshot});

  final PlatformSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final Set<String> unlocked = snapshot.userState.achievements;
    final int unlockedCount = snapshot.unlockedCatalogAchievementCount;
    final int remainingCount = snapshot.remainingCatalogAchievementCount;
    final String progress = context.l10n.platformAchievementsProgress(
      unlockedCount,
      snapshot.content.achievements.length,
    );
    final String guidance = remainingCount == 0
        ? context.l10n.platformAchievementsCollectionComplete
        : context.l10n.platformAchievementsRemaining(remainingCount);
    return ExpeditionPanel(
      tone: ExpeditionPanelTone.resonance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            key: const Key('platform-achievements-summary'),
            container: true,
            label: context.l10n.platformAchievementsSemantics(
              progress,
              guidance,
            ),
            child: ExcludeSemantics(
              child: ExpeditionSectionTitle(
                title: context.l10n.platformAchievementsTitle,
                subtitle: '$progress · $guidance',
                icon: Icons.emoji_events_outlined,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = _usesCompactPlatformSection(
                context,
                constraints,
              );
              final double tileWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: snapshot.content.achievements
                    .map(
                      (PlatformAchievement achievement) => SizedBox(
                        width: tileWidth,
                        child: _AchievementTile(
                          achievement: achievement,
                          unlocked: unlocked.contains(
                            achievement.achievementId,
                          ),
                          horizontal: compact,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
    required this.horizontal,
  });

  final PlatformAchievement achievement;
  final bool unlocked;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final String achievementName = context.l10n.currentPlatformAchievementName(
      achievement.achievementId,
      achievement.name,
    );
    final String achievementStatus = unlocked
        ? context.l10n.platformAchievementUnlocked
        : context.l10n.platformAchievementLocked;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Color accent = unlocked ? palette.resonance : colors.onSurfaceVariant;
    final Widget copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          achievementName,
          textAlign: horizontal ? TextAlign.start : TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              unlocked ? Icons.check_circle_outline : Icons.lock_outline,
              size: 15,
              color: accent,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                achievementStatus,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: accent),
              ),
            ),
          ],
        ),
      ],
    );

    return Semantics(
      key: Key('platform-achievement-${achievement.achievementId}'),
      container: true,
      label: context.l10n.platformAchievementSemantics(
        achievementName,
        achievementStatus.toLowerCase(),
      ),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: unlocked ? 0.1 : 0.045),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unlocked
                  ? accent.withValues(alpha: 0.5)
                  : palette.panelBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: horizontal
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      ProgressionSigil(
                        identity: achievement.achievementId,
                        active: unlocked,
                        size: 52,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: copy),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ProgressionSigil(
                        identity: achievement.achievementId,
                        active: unlocked,
                        size: 54,
                      ),
                      const SizedBox(height: 9),
                      copy,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ExperimentsCard extends StatelessWidget {
  const _ExperimentsCard({required this.snapshot});

  final PlatformSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ExpeditionPanel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.tune_outlined),
        title: Text(context.l10n.platformExperimentsTitle),
        subtitle: Text(context.l10n.platformExperimentsSubtitle),
        children: <Widget>[
          ...snapshot.content.experiments.map(
            (PlatformExperiment experiment) => ListTile(
              title: Text(
                context.l10n.currentPlatformExperimentDescription(
                  experiment.experimentId,
                  experiment.description,
                ),
              ),
              subtitle: Text(
                snapshot.userState.experimentAssignments[experiment
                        .experimentId] ??
                    context.l10n.platformExperimentUnassigned,
              ),
            ),
          ),
          ListTile(
            title: Text(context.l10n.platformBackgroundSyncTitle),
            subtitle: Text(
              snapshot.remoteConfig.backgroundHealthSyncEnabled
                  ? context.l10n.platformEnabledByConfig
                  : context.l10n.platformDisabledByConfig,
            ),
          ),
          ListTile(
            title: Text(context.l10n.platformActivityCommandRetentionTitle),
            subtitle: Text(
              context.l10n.platformRetentionDays(
                snapshot.remoteConfig.activityRetentionDays,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExpeditionSectionTitle(
        title: title,
        subtitle: subtitle,
        icon: icon,
      ),
    );
  }
}

class _PlatformError extends StatelessWidget {
  const _PlatformError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ExpeditionReadState.failure(
      key: const Key('platform-error-state'),
      title: context.l10n.platformLoadFailureTitle,
      message: context.l10n.platformLoadFailureMessage,
      details: null,
      primaryActionKey: const Key('platform-error-retry'),
      primaryActionLabel: context.l10n.retryButton,
      onPrimaryAction: onRetry,
    );
  }
}

int _minimum(int left, int right) => left < right ? left : right;
