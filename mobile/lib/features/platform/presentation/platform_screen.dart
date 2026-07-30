import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/cache/cached_snapshot_banner.dart';
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

  @override
  State<PlatformScreen> createState() => _PlatformScreenState();
}

class _PlatformScreenState extends State<PlatformScreen> {
  final TextEditingController _squadNameController = TextEditingController();
  final TextEditingController _squadIdController = TextEditingController();
  final Set<String> _scheduledExposures = <String>{};

  late Future<_PlatformViewData> _dataFuture;
  String? _busyCommand;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Путевой журнал'),
        actions: <Widget>[
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
          IconButton(
            tooltip: 'Аккаунт',
            onPressed: widget.onOpenAccount,
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_PlatformViewData>(
          future: _dataFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<_PlatformViewData> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                );
              },
        ),
      ),
    );
  }

  Future<_PlatformViewData> _loadData() async {
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
    if (_busyCommand != null) {
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

class _PlatformBody extends StatelessWidget {
  const _PlatformBody({
    required this.data,
    required this.busyCommand,
    required this.squadNameController,
    required this.squadIdController,
    required this.onCommand,
    required this.onRefresh,
    required this.onResumeFirstJourney,
  });

  final _PlatformViewData data;
  final String? busyCommand;
  final TextEditingController squadNameController;
  final TextEditingController squadIdController;
  final void Function(String, Map<String, Object?>) onCommand;
  final VoidCallback onRefresh;
  final VoidCallback? onResumeFirstJourney;

  bool get _busy => busyCommand != null;

  @override
  Widget build(BuildContext context) {
    final PlatformSnapshot snapshot = data.platform;
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
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (snapshot.cacheMetadata != null) ...<Widget>[
            CachedSnapshotBanner(metadata: snapshot.cacheMetadata!),
            const SizedBox(height: 12),
          ],
          Text(
            snapshot.content.season.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Глава из ${snapshot.content.chapterNodes} узлов · '
            'состояние ${snapshot.stateVersion}',
          ),
          const SizedBox(height: 16),
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
          ),
          ...snapshot.userState.pets.map(
            (PlatformPet pet) => _PetCard(
              pet: pet,
              busy: blocked,
              onSelect: () => onCommand('SELECT_PET', <String, Object?>{
                'petId': pet.petId,
              }),
              onEvolve: () => onCommand('EVOLVE_PET', <String, Object?>{
                'petId': pet.petId,
              }),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionTitle(
            title: 'Навыки пилота',
            subtitle: 'Навыки открываются за сезонный опыт.',
          ),
          ...snapshot.content.skills.map(
            (PlatformSkill skill) => _SkillCard(
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
          ),
          const SizedBox(height: 12),
          _SectionTitle(
            title: 'Задания',
            subtitle:
                '${snapshot.userState.totalAcceptedSteps} шагов · '
                '${snapshot.userState.resolvedEventCount} событий',
          ),
          ...snapshot.userState.quests.map(
            (PlatformQuest quest) => _QuestCard(
              quest: quest,
              rewardFirst:
                  snapshot.userState.experimentAssignments['quest-order-v1'] ==
                  'REWARD_FIRST',
              busy: blocked,
              onClaim: () => onCommand('CLAIM_QUEST', <String, Object?>{
                'questId': quest.questId,
              }),
            ),
          ),
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
            subtitle: snapshot.remoteConfig.sandboxPaymentsEnabled
                ? 'Покупки работают через sandbox-провайдер.'
                : 'Sandbox-покупки отключены конфигурацией.',
          ),
          ...snapshot.content.cosmetics.map(
            (PlatformCosmetic cosmetic) => _CosmeticCard(
              cosmetic: cosmetic,
              owned: snapshot.userState.ownedCosmetics.contains(
                cosmetic.cosmeticId,
              ),
              active:
                  snapshot.userState.activeCosmeticId == cosmetic.cosmeticId,
              paymentsEnabled: snapshot.remoteConfig.sandboxPaymentsEnabled,
              busy: blocked,
              onBuy: () => onCommand('BUY_COSMETIC', <String, Object?>{
                'cosmeticId': cosmetic.cosmeticId,
              }),
              onEquip: () => onCommand('EQUIP_COSMETIC', <String, Object?>{
                'cosmeticId': cosmetic.cosmeticId,
              }),
            ),
          ),
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

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.snapshot, required this.onResume});

  final PlatformSnapshot snapshot;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final List<String> steps = snapshot.content.onboardingSteps;
    final Set<String> completed = snapshot.userState.completedOnboardingSteps;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.flag_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snapshot.userState.onboardingComplete
                        ? 'Путь открыт'
                        : 'Начало пути',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${completed.length}/${steps.length}'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: snapshot.onboardingProgressValue),
            const SizedBox(height: 12),
            ...steps.map(
              (String step) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  completed.contains(step)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_onboardingNames[step] ?? step),
              ),
            ),
            if (!snapshot.userState.onboardingComplete) ...<Widget>[
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('platform-resume-first-journey'),
                onPressed: onResume,
                icon: const Icon(Icons.route_outlined),
                label: const Text('Продолжить первый путь'),
              ),
            ],
          ],
        ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              snapshot.content.season.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Уровень ${snapshot.userState.seasonLevel} · '
              '${snapshot.userState.seasonXp} XP',
            ),
            const SizedBox(height: 12),
            Text(
              'Недельный маршрут: '
              '${snapshot.userState.weeklyRouteProgress} / '
              '${snapshot.userState.weeklyRouteRequiredEnergy}',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: snapshot.weeklyRouteProgressValue),
            const SizedBox(height: 8),
            Text(energyCopy),
            const SizedBox(height: 4),
            Text(
              availableEnergy == null
                  ? 'Баланс ENERGY сейчас недоступен'
                  : 'Доступно $availableEnergy ENERGY'
                        '${economyVersion == null ? '' : ' · версия $economyVersion'}',
            ),
            const SizedBox(height: 12),
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
                  ),
                ),
                if (rewardLevel != null)
                  OutlinedButton.icon(
                    key: Key('platform-claim-season-$rewardLevel'),
                    onPressed: busy
                        ? null
                        : () => onClaimSeasonReward(rewardLevel!),
                    icon: const Icon(Icons.card_giftcard_outlined),
                    label: Text('Награда уровня $rewardLevel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.pet,
    required this.busy,
    required this.onSelect,
    required this.onEvolve,
  });

  final PlatformPet pet;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onEvolve;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.pets_outlined)),
        title: Text('${pet.name} · уровень ${pet.level}'),
        subtitle: Text(
          '${pet.species} · связь ${pet.bond}/${pet.evolutionBond}'
          '${pet.evolutionStage > 0 ? ' · эволюция ${pet.evolutionStage}' : ''}',
        ),
        trailing: Wrap(
          spacing: 6,
          children: <Widget>[
            if (!pet.active)
              IconButton(
                key: Key('platform-select-pet-${pet.petId}'),
                tooltip: 'Сделать активным',
                onPressed: busy ? null : onSelect,
                icon: const Icon(Icons.check_circle_outline),
              )
            else
              const Icon(Icons.check_circle),
            if (pet.evolutionStage == 0)
              IconButton(
                key: Key('platform-evolve-pet-${pet.petId}'),
                tooltip: pet.canEvolve
                    ? 'Эволюционировать'
                    : 'Недостаточно связи',
                onPressed: busy || !pet.canEvolve ? null : onEvolve,
                icon: const Icon(Icons.auto_awesome_outlined),
              ),
          ],
        ),
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
    return Card(
      child: ListTile(
        title: Text(skill.name),
        subtitle: Text(
          '${skill.description}\nНужно ${skill.requiredSeasonXp} сезонного XP',
        ),
        isThreeLine: true,
        trailing: unlocked
            ? const Icon(Icons.lock_open)
            : IconButton(
                key: Key('platform-unlock-skill-${skill.skillId}'),
                tooltip: available ? 'Открыть навык' : 'Навык пока недоступен',
                onPressed: busy || !available ? null : onUnlock,
                icon: const Icon(Icons.lock_outline),
              ),
      ),
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
    final Widget progress = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${quest.progress} / ${quest.target}'),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: quest.progressValue),
      ],
    );
    final Widget reward = Text(
      '+${quest.seasonXpReward} сезонного XP · '
      '+${quest.petBondReward} связи',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(quest.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (rewardFirst) reward else progress,
            const SizedBox(height: 8),
            if (rewardFirst) progress else reward,
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: Key('platform-claim-quest-${quest.questId}'),
                onPressed: busy || !quest.ready || quest.claimed
                    ? null
                    : onClaim,
                child: Text(
                  quest.claimed
                      ? 'Получено'
                      : quest.ready
                      ? 'Забрать награду'
                      : 'В процессе',
                ),
              ),
            ),
          ],
        ),
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Отряд', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(current.name),
              Text('Участников: ${current.memberUserIds.length}'),
              SelectableText('ID: ${current.squadId}'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('platform-leave-squad'),
                onPressed: busy ? null : onLeave,
                icon: const Icon(Icons.logout),
                label: const Text('Покинуть отряд'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Отряд', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              key: const Key('platform-squad-name'),
              controller: nameController,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Название нового отряда',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const Key('platform-create-squad'),
              onPressed: busy || nameController.text.trim().isEmpty
                  ? null
                  : onCreate,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Создать отряд'),
            ),
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
            OutlinedButton.icon(
              key: const Key('platform-join-squad'),
              onPressed: busy || idController.text.trim().isEmpty
                  ? null
                  : onJoin,
              icon: const Icon(Icons.login),
              label: const Text('Вступить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.cosmetic,
    required this.owned,
    required this.active,
    required this.paymentsEnabled,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
  });

  final PlatformCosmetic cosmetic;
  final bool owned;
  final bool active;
  final bool paymentsEnabled;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.auto_awesome_outlined)),
        title: Text(cosmetic.name),
        subtitle: Text(
          '${cosmetic.slot} · '
          '${cosmetic.sandboxPrice == 0 ? 'базовая' : '${cosmetic.sandboxPrice} sandbox-кредитов'}',
        ),
        trailing: active
            ? const Chip(label: Text('Активно'))
            : owned
            ? FilledButton.tonal(
                key: Key('platform-equip-cosmetic-${cosmetic.cosmeticId}'),
                onPressed: busy ? null : onEquip,
                child: const Text('Надеть'),
              )
            : FilledButton.tonal(
                key: Key('platform-buy-cosmetic-${cosmetic.cosmeticId}'),
                onPressed: busy || !paymentsEnabled ? null : onBuy,
                child: const Text('Купить'),
              ),
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.snapshot});

  final PlatformSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final Set<String> unlocked = snapshot.userState.achievements;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Достижения', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.content.achievements
                  .map(
                    (PlatformAchievement achievement) => Chip(
                      avatar: Icon(
                        unlocked.contains(achievement.achievementId)
                            ? Icons.emoji_events
                            : Icons.lock_outline,
                        size: 18,
                      ),
                      label: Text(achievement.name),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
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
    return Card(
      child: ExpansionTile(
        title: const Text('Эксперименты и конфигурация'),
        subtitle: const Text('Диагностика назначенных вариантов'),
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
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(subtitle),
        ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Не удалось загрузить путевой журнал',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
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
