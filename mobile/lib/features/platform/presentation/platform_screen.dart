import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/cache/cached_snapshot_banner.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_chrome_insets.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/character_cosmetics.dart';
import 'package:walking_rpg_mobile/design_system/companion_growth.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/expedition_read_state.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/progression_sigil.dart';
import 'package:walking_rpg_mobile/design_system/quest_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/squad_formation_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/design_system/weekly_route_signal.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_action.dart';

const Map<String, String> _onboardingNames = <String, String>{
  'welcome': 'Познакомиться с навигатором',
  'health-permission': 'Разрешить чтение активности',
  'first-sync': 'Синхронизировать первые шаги',
  'pet-selection': 'Выбрать питомца',
  'first-expedition': 'Начать первую экспедицию',
  'first-event': 'Принять первое решение',
};

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
              compactChrome ? 'Журнал' : 'Путевой журнал',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: <Widget>[
              if (!compactChrome)
                IconButton(
                  tooltip: 'Обновить',
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
                  tooltip: 'Аккаунт',
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
                        return const ExpeditionReadState.loading(
                          key: Key('platform-loading-state'),
                          title: 'Открываем путевой журнал',
                          message:
                              'Получаем сезон, спутников и принятые сервером '
                              'записи.',
                        );
                      }
                      if (snapshot.hasError) {
                        return _PlatformError(
                          error: snapshot.error!,
                          onRetry: _reload,
                        );
                      }
                      final _PlatformViewData? data = snapshot.data;
                      if (data == null) {
                        return _PlatformError(
                          error: const FormatException(
                            'Backend не вернул platform-состояние',
                          ),
                          onRetry: _reload,
                        );
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
    try {
      final HomeSnapshot home = await homeLoader();
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
      try {
        final PlatformHomeLoader homeLoader =
            widget.homeLoader ??
            () => HomeApiClient.fromEnvironment().fetchHome(DateTime.now());
        final HomeSnapshot home = await homeLoader();
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
          ),
        );
      });
      widget.onServerStateChanged?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_commandErrorMessage(error))));
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
  });

  final PlatformSnapshot platform;
  final int? availableEnergy;
  final int? economyVersion;
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
      tooltip: 'Ещё действия',
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
              child: const _PlatformMenuLabel(
                icon: Icons.refresh,
                label: 'Обновить журнал',
              ),
            ),
            PopupMenuItem<_PlatformAppAction>(
              key: const Key('platform-menu-account'),
              value: _PlatformAppAction.account,
              enabled: onOpenAccount != null,
              child: const _PlatformMenuLabel(
                icon: Icons.account_circle_outlined,
                label: 'Аккаунт',
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
        ? 'Энергия превращает прогулки в новые маршруты.'
        : 'ENERGY расходуется на экспедицию и недельный маршрут.';

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
          const _SectionTitle(
            title: 'Питомцы',
            subtitle: 'Выберите спутника и развивайте связь.',
            icon: Icons.pets_outlined,
          ),
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
          const _SectionTitle(
            title: 'Навыки пилота',
            subtitle: 'Навыки открываются за сезонный опыт.',
            icon: Icons.hub_outlined,
          ),
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
            title: 'Задания',
            subtitle:
                '${snapshot.userState.totalAcceptedSteps} шагов · '
                '${snapshot.userState.resolvedEventCount} событий',
            icon: Icons.assignment_outlined,
          ),
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
            title: 'Косметика',
            subtitle: sandboxPaymentsAvailable
                ? 'Покупки работают через sandbox-провайдер.'
                : 'Покупки сейчас недоступны.',
            icon: Icons.auto_awesome_outlined,
          ),
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
            label: const Text('Обновить журнал'),
          ),
          const SizedBox(height: 12),
          Text(
            key: const Key('platform-journal-footer'),
            'Контент ${snapshot.contentVersion} · '
            'конфигурация ${snapshot.remoteConfig.seasonId}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final List<String> equippedCosmeticNames = snapshot.content.cosmetics
        .where(
          (PlatformCosmetic cosmetic) =>
              equippedCosmeticIds.contains(cosmetic.cosmeticId),
        )
        .map((PlatformCosmetic cosmetic) => cosmetic.name)
        .toList(growable: false);
    final Widget crewPortraits = ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PilotPortrait(
            key: const Key('platform-hero-pilot-portrait'),
            name: 'Навигатор',
            size: 64,
            highlighted: true,
            equippedCosmeticIds: equippedCosmeticIds,
          ),
          const SizedBox(width: 10),
          CompanionPortrait(
            key: const Key('platform-hero-pet-portrait'),
            petId: activePet.petId,
            name: activePet.name,
            species: activePet.species,
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
          'Навигатор и ${activePet.name}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          equippedCosmeticNames.isEmpty
              ? 'Без активной косметики'
              : 'Экипировано: ${equippedCosmeticNames.join(' · ')}',
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
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ExpeditionBadge(
                    label: 'Журнал пилота',
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
          const ChapterVista(
            key: Key('platform-chapter-vista'),
            semanticLabel: 'Туманный сектор, визуальный образ первой главы',
          ),
          const SizedBox(height: 18),
          Text(
            snapshot.content.season.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Глава из ${snapshot.content.chapterNodes} узлов · '
            'состояние ${snapshot.stateVersion}',
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
                label: '${activePet.name} · ур. ${activePet.level}',
                icon: Icons.pets_outlined,
              ),
              ExpeditionBadge(
                label: CompanionGrowth.formLabel(activePet.evolutionStage),
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
            label:
                'Экипаж маршрута: пилот Навигатор и ${activePet.name}. '
                '${equippedCosmeticNames.isEmpty ? 'Без активной косметики' : 'Экипировано: ${equippedCosmeticNames.join(', ')}'}',
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
          snapshot.userState.onboardingComplete ? 'Путь открыт' : 'Начало пути',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 3),
        Text(
          snapshot.userState.onboardingComplete
              ? 'Все основные системы экспедиции доступны.'
              : 'Завершите маршрут знакомства с навигатором.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
    final Widget progressBadge = ExpeditionBadge(
      label: '${completed.length}/${steps.length}',
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
          LinearProgressIndicator(value: snapshot.onboardingProgressValue),
          const SizedBox(height: 14),
          for (final String step in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
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
                  Expanded(child: Text(_onboardingNames[step] ?? step)),
                ],
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
                label: const Text(
                  'Продолжить первый путь',
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
    final int claimableLevel = snapshot.claimableSeasonLevel;
    final Set<String> achievements = snapshot.userState.achievements;
    int? rewardLevel;
    for (int level = 1; level <= claimableLevel; level += 1) {
      if (!achievements.contains('season-reward-$level')) {
        rewardLevel = level;
        break;
      }
    }

    final ColorScheme colors = Theme.of(context).colorScheme;
    return ExpeditionPanel(
      tone: ExpeditionPanelTone.energy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const Widget badge = ExpeditionBadge(
                label: 'Недельный маршрут',
                icon: Icons.route_outlined,
                tone: ExpeditionPanelTone.energy,
                allowWrap: true,
              );
              final Widget level = Text(
                'Ур. ${snapshot.userState.seasonLevel}',
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
                    snapshot.content.season.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${snapshot.userState.seasonXp} XP · '
                    '$remaining ENERGY до финиша',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(energyCopy),
                  const SizedBox(height: 4),
                  Text(
                    availableEnergy == null
                        ? 'Баланс ENERGY сейчас недоступен'
                        : 'Доступно $availableEnergy ENERGY'
                              '${economyVersion == null ? '' : ' · версия $economyVersion'}',
                  ),
                ],
              );
              final Widget routeSignal = WeeklyRouteSignal(
                routeId: snapshot.content.weeklyRoute.routeId,
                seasonName: snapshot.content.season.name,
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
                      ? 'Маршрут завершён'
                      : 'Потратить $spendable ENERGY',
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
                  icon: const Icon(Icons.card_giftcard_outlined),
                  label: Text(
                    'Награда уровня $rewardLevel',
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
    final double bondProgress = (pet.bond / pet.evolutionBond)
        .clamp(0.0, 1.0)
        .toDouble();
    final Widget portrait = CompanionPortrait(
      key: Key('platform-pet-portrait-${pet.petId}'),
      petId: pet.petId,
      name: pet.name,
      species: pet.species,
      evolutionStage: pet.evolutionStage,
      active: pet.active,
      size: 78,
      equippedCosmeticIds: equippedCosmeticIds,
    );
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${pet.name} · уровень ${pet.level}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        Text(
          '${pet.species} · ${pet.trait}',
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
              const ExpeditionBadge(
                label: 'В отряде',
                icon: Icons.check_circle_outline,
              ),
            ExpeditionBadge(
              label: CompanionGrowth.formLabel(pet.evolutionStage),
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
          Row(
            children: <Widget>[
              Text('Связь', style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              Text(
                pet.evolutionStage > 0
                    ? '${pet.bond}'
                    : '${pet.bond}/${pet.evolutionBond}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: pet.canEvolve ? colors.primary : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: pet.evolutionStage > 0 ? 1 : bondProgress,
          ),
          const SizedBox(height: 8),
          Text(
            pet.evolutionStage > 0
                ? '${CompanionGrowth.stageName(pet.evolutionStage)} — '
                      'текущая серверная форма спутника.'
                : pet.canEvolve
                ? 'Связь готова к эволюции.'
                : 'Решения событий укрепляют связь со спутником.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
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
                  label: const Text(
                    'Взять в отряд',
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                const ExpeditionBadge(
                  label: 'Активный спутник',
                  icon: Icons.pets,
                ),
              if (pet.evolutionStage == 0)
                FilledButton.tonalIcon(
                  key: Key('platform-evolve-pet-${pet.petId}'),
                  onPressed: busy || !pet.canEvolve ? null : onEvolve,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    pet.canEvolve ? 'Эволюционировать' : 'Нужно больше связи',
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
    final bool available = seasonXp >= skill.requiredSeasonXp;
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
                        skill.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(skill.description),
                const SizedBox(height: 4),
                Text('Нужно ${skill.requiredSeasonXp} сезонного XP'),
                const SizedBox(height: 12),
                if (unlocked)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ExpeditionBadge(
                      label: 'Навык открыт',
                      icon: Icons.lock_open,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    key: Key('platform-unlock-skill-${skill.skillId}'),
                    onPressed: busy || !available ? null : onUnlock,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(
                      available ? 'Открыть навык' : 'Навык пока недоступен',
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
            title: Text(skill.name),
            subtitle: Text(
              '${skill.description}\n'
              'Нужно ${skill.requiredSeasonXp} сезонного XP',
            ),
            isThreeLine: true,
            trailing: unlocked
                ? const Icon(Icons.lock_open, semanticLabel: 'Навык открыт')
                : IconButton(
                    key: Key('platform-unlock-skill-${skill.skillId}'),
                    tooltip: available
                        ? 'Открыть навык'
                        : 'Навык пока недоступен',
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
    final Widget progress = QuestRouteProgress(
      questId: quest.questId,
      questName: quest.name,
      metric: quest.metric,
      progress: quest.progress,
      target: quest.target,
      ready: quest.ready,
      claimed: quest.claimed,
    );
    final Widget reward = Text(
      '+${quest.seasonXpReward} сезонного XP · '
      '+${quest.petBondReward} связи',
    );
    final ExpeditionBadge status = ExpeditionBadge(
      label: quest.claimed
          ? 'Получено'
          : quest.ready
          ? 'Готово'
          : 'В пути',
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
                  ? 'Получено'
                  : quest.ready
                  ? 'Забрать награду'
                  : 'В процессе',
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
                Text(
                  quest.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    signal,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        quest.name,
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
            const ExpeditionSectionTitle(
              title: 'Отряд',
              subtitle: 'Совместный маршрут и общий позывной.',
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
                      label:
                          'Отряд «${current.name}». '
                          'Участников: $memberCount',
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
                              label: 'Участников: $memberCount',
                              icon: Icons.group_outlined,
                              tone: ExpeditionPanelTone.resonance,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText('ID: ${current.squadId}'),
                  ],
                );
                final Widget action = OutlinedButton.icon(
                  key: const Key('platform-leave-squad'),
                  onPressed: busy ? null : onLeave,
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Покинуть отряд',
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
                'Свободный канал',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              Text(
                'Создайте позывной для нового отряда или настройтесь на '
                'существующий сигнал.',
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
            label: const Text(
              'Создать отряд',
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
          );
          final Widget joinAction = OutlinedButton.icon(
            key: const Key('platform-join-squad'),
            onPressed: busy || idController.text.trim().isEmpty ? null : onJoin,
            icon: const Icon(Icons.login),
            label: const Text(
              'Вступить',
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ExpeditionSectionTitle(
                title: 'Отряд',
                subtitle: 'Создайте группу или присоединитесь по ID.',
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
                decoration: const InputDecoration(
                  labelText: 'Название нового отряда',
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
                decoration: const InputDecoration(
                  labelText: 'ID существующего отряда',
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
    final String slotLabel = switch (cosmetic.slot) {
      'PILOT' => 'Пилот',
      'PET' => 'Спутник',
      'PROFILE' => 'Профиль',
      _ => cosmetic.slot,
    };
    final String subtitle = paymentsEnabled
        ? '$slotLabel · '
              '${cosmetic.sandboxPrice == 0 ? 'базовая' : '${cosmetic.sandboxPrice} sandbox-кредитов'}'
        : slotLabel;
    final Widget? action = active
        ? Chip(
            key: Key('platform-equipped-cosmetic-${cosmetic.cosmeticId}'),
            label: const Text('Экипировано'),
          )
        : owned
        ? FilledButton.tonal(
            key: Key('platform-equip-cosmetic-${cosmetic.cosmeticId}'),
            onPressed: busy ? null : onEquip,
            child: const Text('Надеть'),
          )
        : paymentsEnabled
        ? FilledButton.tonal(
            key: Key('platform-buy-cosmetic-${cosmetic.cosmeticId}'),
            onPressed: busy ? null : onBuy,
            child: const Text('Купить'),
          )
        : null;
    final Widget icon = switch (cosmetic.cosmeticId) {
      CharacterCosmeticIds.pilotScarf => ExcludeSemantics(
        child: PilotPortrait(
          key: Key('platform-cosmetic-preview-${cosmetic.cosmeticId}'),
          name: 'Навигатор',
          size: 52,
          equippedCosmeticIds: <String>{cosmetic.cosmeticId},
        ),
      ),
      CharacterCosmeticIds.sparkHalo when previewPet != null =>
        ExcludeSemantics(
          child: CompanionPortrait(
            key: Key('platform-cosmetic-preview-${cosmetic.cosmeticId}'),
            petId: previewPet!.petId,
            name: previewPet!.name,
            species: previewPet!.species,
            evolutionStage: previewPet!.evolutionStage,
            size: 52,
            equippedCosmeticIds: <String>{cosmetic.cosmeticId},
          ),
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
                        cosmetic.name,
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
            title: Text(cosmetic.name),
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
    return ExpeditionPanel(
      tone: ExpeditionPanelTone.resonance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExpeditionSectionTitle(
            title: 'Достижения',
            subtitle:
                '${unlocked.length} из '
                '${snapshot.content.achievements.length} открыто',
            icon: Icons.emoji_events_outlined,
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
          achievement.name,
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
                unlocked ? 'Открыто' : 'Закрыто',
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
      label:
          'Достижение «${achievement.name}»: '
          '${unlocked ? 'открыто' : 'закрыто'}',
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
        title: const Text('Эксперименты и конфигурация'),
        subtitle: const Text('Служебная диагностика · раскрывается вручную'),
        children: <Widget>[
          ...snapshot.content.experiments.map(
            (PlatformExperiment experiment) => ListTile(
              title: Text(experiment.description),
              subtitle: Text(
                snapshot.userState.experimentAssignments[experiment
                        .experimentId] ??
                    'не назначен',
              ),
            ),
          ),
          ListTile(
            title: const Text('Фоновая синхронизация'),
            subtitle: Text(
              snapshot.remoteConfig.backgroundHealthSyncEnabled
                  ? 'включена конфигурацией'
                  : 'выключена конфигурацией',
            ),
          ),
          ListTile(
            title: const Text('Хранение activity-команд'),
            subtitle: Text(
              '${snapshot.remoteConfig.activityRetentionDays} дней',
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
  const _PlatformError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ExpeditionReadState.failure(
      key: const Key('platform-error-state'),
      title: 'Не удалось загрузить путевой журнал',
      message:
          'Актуальные записи не приняты. До успешного повтора журнал не '
          'показывает и не выполняет серверные действия.',
      details: error.toString(),
      primaryActionKey: const Key('platform-error-retry'),
      primaryActionLabel: 'Повторить',
      onPrimaryAction: onRetry,
    );
  }
}

String _commandErrorMessage(Object error) {
  if (error is PlatformApiException) {
    return 'Не удалось выполнить действие: ${error.message}';
  }
  return 'Не удалось выполнить действие: $error';
}

int _minimum(int left, int right) => left < right ? left : right;
