import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/cache/cached_snapshot_banner.dart';
import 'package:walking_rpg_mobile/features/crafting/data/crafting_api_client.dart';
import 'package:walking_rpg_mobile/features/crafting/domain/crafting_result.dart';
import 'package:walking_rpg_mobile/features/equipment/data/equipment_api_client.dart';
import 'package:walking_rpg_mobile/features/equipment/domain/equipment_result.dart';
import 'package:walking_rpg_mobile/features/event/data/event_api_client.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/expedition/data/expedition_api_client.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/widgets/progress_card.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_action.dart';

typedef HomeSnapshotLoader = Future<HomeSnapshot> Function();
typedef ExpeditionAdvancer =
    Future<ExpeditionAdvanceResult> Function({
      required String expeditionId,
      required int energyToSpend,
      required String idempotencyKey,
    });
typedef EventResolver =
    Future<EventResolutionResult> Function({
      required String eventId,
      required String choiceId,
      required String idempotencyKey,
    });
typedef EventResultAcknowledger =
    Future<EventResultAcknowledgement> Function({
      required String receiptId,
      required String idempotencyKey,
    });
typedef CraftingExecutor =
    Future<CraftingResult> Function({
      required String recipeId,
      required String idempotencyKey,
    });
typedef EquipmentExecutor =
    Future<EquipmentResult> Function({
      required String slotId,
      required String action,
      required String? itemInstanceId,
      required String idempotencyKey,
    });
typedef IdempotencyKeyFactory = String Function();

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.loader,
    this.advancer,
    this.eventResolver,
    this.eventResultAcknowledger,
    this.crafter,
    this.equipmentExecutor,
    this.idempotencyKeyFactory,
    this.onOpenAccount,
    this.onOpenRecovery,
    this.recoveryCount = 0,
    this.recoveryUnavailable = false,
    this.authoritativeRefreshGeneration = 0,
  });

  final HomeSnapshotLoader? loader;
  final ExpeditionAdvancer? advancer;
  final EventResolver? eventResolver;
  final EventResultAcknowledger? eventResultAcknowledger;
  final CraftingExecutor? crafter;
  final EquipmentExecutor? equipmentExecutor;
  final IdempotencyKeyFactory? idempotencyKeyFactory;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenRecovery;
  final int recoveryCount;
  final bool recoveryUnavailable;
  final int authoritativeRefreshGeneration;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeSnapshot> _snapshotFuture;
  bool _isAdvancing = false;
  bool _isResolving = false;
  bool _isAcknowledging = false;
  bool _isCrafting = false;
  bool _isChangingEquipment = false;

  bool get _isBusy =>
      _isAdvancing ||
      _isResolving ||
      _isAcknowledging ||
      _isCrafting ||
      _isChangingEquipment;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader ||
        oldWidget.authoritativeRefreshGeneration !=
            widget.authoritativeRefreshGeneration) {
      _snapshotFuture = _loadSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walking RPG'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Обновить',
            onPressed: _isBusy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
          MobileCommandRecoveryAction(
            key: const Key('home-command-recovery'),
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
        child: FutureBuilder<HomeSnapshot>(
          future: _snapshotFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<HomeSnapshot> asyncSnapshot,
              ) {
                if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (asyncSnapshot.hasError) {
                  return _HomeError(
                    error: asyncSnapshot.error!,
                    onRetry: _reload,
                    onOpenDemo: _openDemo,
                  );
                }
                final HomeSnapshot? snapshot = asyncSnapshot.data;
                if (snapshot == null) {
                  return _HomeError(
                    error: const FormatException('Backend не вернул состояние'),
                    onRetry: _reload,
                    onOpenDemo: _openDemo,
                  );
                }
                return _HomeBody(
                  snapshot: snapshot,
                  isAdvancing: _isAdvancing,
                  isResolving: _isResolving,
                  isAcknowledging: _isAcknowledging,
                  isCrafting: _isCrafting,
                  isChangingEquipment: _isChangingEquipment,
                  onAdvance: () => _advance(snapshot),
                  onResolve: (HomeEventChoice choice) =>
                      _resolveEvent(snapshot, choice),
                  onAcknowledgeEventResult: () =>
                      _acknowledgeEventResult(snapshot),
                  onCraft: (HomeCraftingRecipe recipe) =>
                      _craft(snapshot, recipe),
                  onEquip: (HomeInventoryItem item) => _equip(snapshot, item),
                  onUnequip: (HomeEquipmentSlot slot) =>
                      _unequip(snapshot, slot),
                  onRefresh: _reload,
                );
              },
        ),
      ),
    );
  }

  Future<HomeSnapshot> _loadSnapshot() {
    final HomeSnapshotLoader? loader = widget.loader;
    if (loader != null) {
      return loader();
    }
    return HomeApiClient.fromEnvironment().fetchHome(DateTime.now());
  }

  Future<void> _advance(HomeSnapshot snapshot) async {
    final int energyToSpend = snapshot.spendableEnergy;
    if (_isBusy || energyToSpend <= 0) {
      return;
    }

    setState(() {
      _isAdvancing = true;
    });
    try {
      final ExpeditionAdvancer advancer =
          widget.advancer ?? ExpeditionApiClient.fromEnvironment().advance;
      final String idempotencyKey = _nextKey(snapshot.expeditionId);
      final ExpeditionAdvanceResult result = await advancer(
        expeditionId: snapshot.expeditionId,
        energyToSpend: energyToSpend,
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) {
        return;
      }
      final String message = result.unlockedEvent == null
          ? 'Экспедиция продвинулась на ${result.energySpent} энергии'
          : 'Открыто событие: ${result.unlockedEvent!.title}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _snapshotFuture = _loadSnapshot();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось продвинуть экспедицию: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdvancing = false;
        });
      }
    }
  }

  Future<void> _resolveEvent(
    HomeSnapshot snapshot,
    HomeEventChoice choice,
  ) async {
    final HomeExpeditionEvent? event = snapshot.unlockedEvent;
    if (_isBusy ||
        snapshot.isCached ||
        snapshot.pendingEventResult != null ||
        event == null ||
        event.isResolved ||
        !choice.isAvailable) {
      return;
    }

    setState(() {
      _isResolving = true;
    });
    try {
      final EventResolver resolver =
          widget.eventResolver ?? EventApiClient.fromEnvironment().resolve;
      final EventResolutionResult result = await resolver(
        eventId: event.eventId,
        choiceId: choice.choiceId,
        idempotencyKey: _nextKey(event.eventId),
      );
      if (!mounted) {
        return;
      }
      final EventMaterialReward? material = result.material;
      final String materialText = material == null
          ? ''
          : ', +${material.quantityGained} ${material.name}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.outcomeTitle}: +${result.pilot.experienceGained} XP, '
            '+${result.pet.bondGained} связь$materialText',
          ),
        ),
      );
      setState(() {
        _snapshotFuture = _loadSnapshot();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось разрешить событие: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  Future<void> _acknowledgeEventResult(HomeSnapshot snapshot) async {
    final PendingEventResult? result = snapshot.pendingEventResult;
    if (_isBusy || snapshot.isCached || result == null) {
      return;
    }

    setState(() {
      _isAcknowledging = true;
    });
    try {
      final EventResultAcknowledger acknowledger =
          widget.eventResultAcknowledger ??
          ({required String receiptId, required String idempotencyKey}) =>
              EventApiClient.fromEnvironment().acknowledge(
                receiptId: receiptId,
              );
      await acknowledger(
        receiptId: result.receiptId,
        idempotencyKey: _nextKey('event-result-${result.receiptId}'),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshotFuture = _loadSnapshot();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось подтвердить результат события: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAcknowledging = false;
        });
      }
    }
  }

  Future<void> _craft(HomeSnapshot snapshot, HomeCraftingRecipe recipe) async {
    if (_isBusy ||
        snapshot.isCached ||
        snapshot.pendingEventResult != null ||
        !recipe.canCraft) {
      return;
    }

    setState(() {
      _isCrafting = true;
    });
    try {
      final CraftingExecutor crafter =
          widget.crafter ?? CraftingApiClient.fromEnvironment().craft;
      final CraftingResult result = await crafter(
        recipeId: recipe.recipeId,
        idempotencyKey: _nextKey(recipe.recipeId),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Создано: ${result.craftedItem.name}')),
      );
      setState(() {
        _snapshotFuture = _loadSnapshot();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать предмет: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCrafting = false;
        });
      }
    }
  }

  Future<void> _equip(HomeSnapshot snapshot, HomeInventoryItem item) async {
    final String? slotId = item.equippableSlotId;
    final String? itemInstanceId = item.itemInstanceId;
    if (slotId == null || itemInstanceId == null) {
      return;
    }
    await _changeEquipment(
      snapshot,
      slotId: slotId,
      action: 'EQUIP',
      itemInstanceId: itemInstanceId,
    );
  }

  Future<void> _unequip(HomeSnapshot snapshot, HomeEquipmentSlot slot) {
    return _changeEquipment(
      snapshot,
      slotId: slot.slotId,
      action: 'UNEQUIP',
      itemInstanceId: null,
    );
  }

  Future<void> _changeEquipment(
    HomeSnapshot snapshot, {
    required String slotId,
    required String action,
    required String? itemInstanceId,
  }) async {
    if (_isBusy || snapshot.isCached || snapshot.pendingEventResult != null) {
      return;
    }
    setState(() {
      _isChangingEquipment = true;
    });
    try {
      final EquipmentExecutor executor =
          widget.equipmentExecutor ??
          EquipmentApiClient.fromEnvironment().change;
      final EquipmentResult result = await executor(
        slotId: slotId,
        action: action,
        itemInstanceId: itemInstanceId,
        idempotencyKey: _nextKey('equipment-$slotId-${action.toLowerCase()}'),
      );
      if (!mounted) {
        return;
      }
      final String message = result.action == 'EQUIP'
          ? 'Экипировано: ${result.equippedItem!.name}'
          : 'Навигационный прибор снят';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _snapshotFuture = _loadSnapshot();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось изменить снаряжение: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChangingEquipment = false;
        });
      }
    }
  }

  String _nextKey(String sourceId) {
    return widget.idempotencyKeyFactory?.call() ??
        '$sourceId-${DateTime.now().microsecondsSinceEpoch}';
  }

  void _openDemo() {
    setState(() {
      _snapshotFuture = Future<HomeSnapshot>.value(HomeSnapshot.demo);
    });
  }

  void _reload() {
    if (_isBusy) {
      return;
    }
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.snapshot,
    required this.isAdvancing,
    required this.isResolving,
    required this.isAcknowledging,
    required this.isCrafting,
    required this.isChangingEquipment,
    required this.onAdvance,
    required this.onResolve,
    required this.onAcknowledgeEventResult,
    required this.onCraft,
    required this.onEquip,
    required this.onUnequip,
    required this.onRefresh,
  });

  final HomeSnapshot snapshot;
  final bool isAdvancing;
  final bool isResolving;
  final bool isAcknowledging;
  final bool isCrafting;
  final bool isChangingEquipment;
  final VoidCallback onAdvance;
  final ValueChanged<HomeEventChoice> onResolve;
  final VoidCallback onAcknowledgeEventResult;
  final ValueChanged<HomeCraftingRecipe> onCraft;
  final ValueChanged<HomeInventoryItem> onEquip;
  final ValueChanged<HomeEquipmentSlot> onUnequip;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final String lastSync = snapshot.lastActivitySyncAt == null
        ? 'Шаги ещё не синхронизированы'
        : 'Последняя синхронизация: ${snapshot.lastActivitySyncAt}';
    final String activitySubtitle =
        '${snapshot.dailyGoalPolicy.explanation}\n$lastSync';
    final HomeExpeditionEvent? event = snapshot.unlockedEvent;
    final PendingEventResult? pendingEventResult = snapshot.pendingEventResult;
    final bool eventReady = event?.status == 'READY';
    final bool completed = snapshot.expeditionStatus == 'COMPLETED';
    final int spendableEnergy = snapshot.spendableEnergy;
    final bool readOnly = snapshot.isCached;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (snapshot.cacheMetadata != null) ...<Widget>[
          CachedSnapshotBanner(metadata: snapshot.cacheMetadata!),
          const SizedBox(height: 12),
        ],
        Text(
          completed ? 'Экспедиция завершена' : 'Экспедиция ждёт твоих шагов',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Сначала прогулка. Решения и награды — после неё.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (pendingEventResult != null) ...<Widget>[
          const SizedBox(height: 16),
          _PendingEventResultCard(
            result: pendingEventResult,
            readOnly: readOnly,
            acknowledging: isAcknowledging,
            onAcknowledge: onAcknowledgeEventResult,
          ),
        ],
        const SizedBox(height: 20),
        ProgressCard(
          title: 'Сегодня: ${snapshot.dailySteps} / ${snapshot.dailyGoal}',
          subtitle: activitySubtitle,
          progress: snapshot.dailyProgress,
          icon: Icons.directions_walk,
        ),
        ProgressCard(
          title: snapshot.expeditionName,
          subtitle:
              '${snapshot.expeditionProgress} / ${snapshot.requiredEnergy} энергии'
              ' · ${snapshot.currentNodeName}',
          progress: snapshot.expeditionProgressValue,
          icon: Icons.explore_outlined,
        ),
        if (event != null) ...<Widget>[
          const SizedBox(height: 4),
          _EventCard(
            event: event,
            isResolving: isResolving,
            disabled:
                isResolving ||
                isAcknowledging ||
                readOnly ||
                pendingEventResult != null,
            onChoose: onResolve,
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: _CharacterCard(
                label: 'Пилот',
                name: snapshot.pilotName,
                level: snapshot.pilotLevel,
                detail:
                    'XP ${snapshot.pilotCurrentExperience} / ${snapshot.pilotNextLevelExperience}',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CharacterCard(
                label: 'Питомец',
                name: snapshot.petName,
                level: snapshot.petLevel,
                detail: 'Связь ${snapshot.petBond}',
                icon: Icons.pets_outlined,
              ),
            ),
          ],
        ),
        if (snapshot.equipment.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _EquipmentCard(
            slots: snapshot.equipment,
            readOnly: readOnly,
            busy:
                isAdvancing ||
                isResolving ||
                isAcknowledging ||
                isCrafting ||
                isChangingEquipment ||
                pendingEventResult != null,
            changing: isChangingEquipment,
            onUnequip: onUnequip,
          ),
        ],
        if (snapshot.inventory.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _InventoryCard(
            items: snapshot.inventory,
            readOnly: readOnly,
            busy:
                isAdvancing ||
                isResolving ||
                isAcknowledging ||
                isCrafting ||
                isChangingEquipment ||
                pendingEventResult != null,
            changing: isChangingEquipment,
            onEquip: onEquip,
          ),
        ],
        if (snapshot.craftingRecipes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _CraftingCard(
            recipes: snapshot.craftingRecipes,
            readOnly: readOnly,
            busy:
                isAdvancing ||
                isResolving ||
                isAcknowledging ||
                isCrafting ||
                isChangingEquipment ||
                pendingEventResult != null,
            crafting: isCrafting,
            onCraft: onCraft,
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed:
              readOnly ||
                  eventReady ||
                  completed ||
                  pendingEventResult != null ||
                  spendableEnergy <= 0 ||
                  isAdvancing ||
                  isResolving ||
                  isAcknowledging ||
                  isCrafting ||
                  isChangingEquipment
              ? null
              : onAdvance,
          icon: isAdvancing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.rocket_launch_outlined),
          label: Text(
            readOnly
                ? 'Изменения недоступны офлайн'
                : completed
                ? 'Экспедиция завершена'
                : pendingEventResult != null
                ? 'Сначала подтвердите результат'
                : eventReady
                ? 'Выберите решение события'
                : spendableEnergy > 0
                ? 'Потратить $spendableEnergy энергии'
                : 'Нужно накопить энергию',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed:
              isAdvancing ||
                  isResolving ||
                  isAcknowledging ||
                  isCrafting ||
                  isChangingEquipment
              ? null
              : onRefresh,
          icon: const Icon(Icons.sync),
          label: const Text('Обновить состояние'),
        ),
        const SizedBox(height: 12),
        Text(
          'Доступная энергия: ${snapshot.availableEnergy} '
          '· версия ${snapshot.economyVersion}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Экспедиция: версия ${snapshot.expeditionVersion} '
          '· ${snapshot.expeditionStatus}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Контент: ${snapshot.contentVersion}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PendingEventResultCard extends StatelessWidget {
  const _PendingEventResultCard({
    required this.result,
    required this.readOnly,
    required this.acknowledging,
    required this.onAcknowledge,
  });

  final PendingEventResult result;
  final bool readOnly;
  final bool acknowledging;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final EventMaterialReward? material = result.material;
    final EventNextNode? nextNode = result.nextNode;
    return Card(
      key: const Key('pending-event-result-card'),
      elevation: 3,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(
                radius: 28,
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                child: const Icon(Icons.emoji_events_outlined, size: 30),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'СОБЫТИЕ ЗАВЕРШЕНО',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.primary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              result.eventTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              result.choiceTitle,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Text(
              result.outcomeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(result.outcomeSummary),
            const SizedBox(height: 16),
            _RewardLine(
              icon: Icons.person_outline,
              text:
                  '+${result.pilot.experienceGained} XP · '
                  'всего ${result.pilot.currentExperience}',
            ),
            const SizedBox(height: 8),
            _RewardLine(
              icon: Icons.pets_outlined,
              text:
                  '+${result.pet.bondGained} связи · '
                  '${result.pet.name}: ${result.pet.bond}',
            ),
            if (material != null) ...<Widget>[
              const SizedBox(height: 8),
              _RewardLine(
                icon: Icons.inventory_2_outlined,
                text:
                    '+${material.quantityGained} ${material.name} · '
                    'всего ${material.quantityAfter}',
              ),
              const SizedBox(height: 4),
              Text(
                material.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (nextNode != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'Следующий узел: ${nextNode.name}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('pending-event-result-acknowledge'),
              onPressed: readOnly || acknowledging ? null : onAcknowledge,
              icon: acknowledging
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(
                readOnly
                    ? 'Подтверждение недоступно офлайн'
                    : acknowledging
                    ? 'Сохраняем продолжение...'
                    : nextNode == null
                    ? 'Завершить экспедицию'
                    : 'Продолжить к узлу «${nextNode.name}»',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardLine extends StatelessWidget {
  const _RewardLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.labelLarge),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isResolving,
    required this.disabled,
    required this.onChoose,
  });

  final HomeExpeditionEvent event;
  final bool isResolving;
  final bool disabled;
  final ValueChanged<HomeEventChoice> onChoose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.auto_awesome_outlined, size: 32),
            const SizedBox(height: 10),
            Text(
              event.isResolved ? 'Событие разрешено' : 'Событие открыто',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(event.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(event.summary),
            if (event.isResolved) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                event.selectedChoiceTitle ?? 'Выбор зафиксирован',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                event.outcomeTitle ?? 'Результат события',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(event.outcomeSummary ?? ''),
              if (event.materialReward != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  '+${event.materialReward!.quantityGained} '
                  '${event.materialReward!.itemName} '
                  '· всего ${event.materialReward!.quantityAfter}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ] else ...<Widget>[
              const SizedBox(height: 12),
              for (final HomeEventChoice choice in event.choices) ...<Widget>[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    key: Key('home-event-choice-${choice.choiceId}'),
                    onPressed: disabled || !choice.isAvailable
                        ? null
                        : () => onChoose(choice),
                    child: Column(
                      children: <Widget>[
                        Text(choice.title),
                        Text(
                          _rewardText(choice),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(choice.description),
                if (!choice.isAvailable &&
                    choice.requirement != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    choice.requirement!.description,
                    key: Key('home-choice-locked-${choice.choiceId}'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
              if (isResolving) const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  String _rewardText(HomeEventChoice choice) {
    final HomeMaterialRewardPreview? material = choice.materialReward;
    final String materialText = material == null
        ? ''
        : ' · +${material.quantity} ${material.itemName}';
    return '+${choice.pilotExperienceReward} XP · '
        '+${choice.petBondReward} связь$materialText';
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.slots,
    required this.readOnly,
    required this.busy,
    required this.changing,
    required this.onUnequip,
  });

  final List<HomeEquipmentSlot> slots;
  final bool readOnly;
  final bool busy;
  final bool changing;
  final ValueChanged<HomeEquipmentSlot> onUnequip;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('equipment-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.explore_outlined),
                const SizedBox(width: 8),
                Text(
                  'Снаряжение',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final HomeEquipmentSlot slot in slots) ...<Widget>[
              Text(slot.name, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(slot.description),
              const SizedBox(height: 8),
              if (slot.item == null)
                const Text('Слот свободен')
              else ...<Widget>[
                Text(
                  slot.item!.name,
                  key: Key('equipment-item-${slot.slotId}'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  key: Key('equipment-unequip-${slot.slotId}'),
                  onPressed: readOnly || busy ? null : () => onUnequip(slot),
                  icon: changing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.remove_circle_outline),
                  label: const Text('Снять'),
                ),
              ],
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.items,
    required this.readOnly,
    required this.busy,
    required this.changing,
    required this.onEquip,
  });

  final List<HomeInventoryItem> items;
  final bool readOnly;
  final bool busy;
  final bool changing;
  final ValueChanged<HomeInventoryItem> onEquip;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.inventory_2_outlined),
                const SizedBox(width: 8),
                Text(
                  'Инвентарь',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final HomeInventoryItem item in items) ...<Widget>[
              Text(
                item.isUnique
                    ? '${item.name} · уникальный предмет'
                    : '${item.name} × ${item.quantity}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 2),
              Text(item.description),
              if (item.isEquippable) ...<Widget>[
                const SizedBox(height: 6),
                FilledButton.tonalIcon(
                  key: Key('inventory-equip-${item.itemId}'),
                  onPressed: readOnly || busy || item.isEquipped
                      ? null
                      : () => onEquip(item),
                  icon: changing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.explore_outlined),
                  label: Text(item.isEquipped ? 'Экипировано' : 'Экипировать'),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _CraftingCard extends StatelessWidget {
  const _CraftingCard({
    required this.recipes,
    required this.readOnly,
    required this.busy,
    required this.crafting,
    required this.onCraft,
  });

  final List<HomeCraftingRecipe> recipes;
  final bool readOnly;
  final bool busy;
  final bool crafting;
  final ValueChanged<HomeCraftingRecipe> onCraft;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('crafting-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.handyman_outlined),
                const SizedBox(width: 8),
                Text(
                  'Мастерская',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int index = 0; index < recipes.length; index++) ...<Widget>[
              _CraftingRecipeView(
                recipe: recipes[index],
                readOnly: readOnly,
                busy: busy,
                crafting: crafting,
                onCraft: () => onCraft(recipes[index]),
              ),
              if (index + 1 < recipes.length) const Divider(height: 28),
            ],
          ],
        ),
      ),
    );
  }
}

class _CraftingRecipeView extends StatelessWidget {
  const _CraftingRecipeView({
    required this.recipe,
    required this.readOnly,
    required this.busy,
    required this.crafting,
    required this.onCraft,
  });

  final HomeCraftingRecipe recipe;
  final bool readOnly;
  final bool busy;
  final bool crafting;
  final VoidCallback onCraft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(recipe.name, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(recipe.description),
        const SizedBox(height: 10),
        for (final HomeCraftingIngredient ingredient
            in recipe.ingredients) ...<Widget>[
          Row(
            children: <Widget>[
              Icon(
                ingredient.isAvailable
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(ingredient.name)),
              Text(
                '${ingredient.availableQuantity} / '
                '${ingredient.requiredQuantity}',
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 6),
        Text(
          'Результат: ${recipe.result.name}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 2),
        Text(
          recipe.result.description,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          key: Key('craft-${recipe.recipeId}'),
          onPressed: readOnly || busy || !recipe.canCraft ? null : onCraft,
          icon: crafting && recipe.canCraft
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  recipe.isCrafted
                      ? Icons.check_circle_outline
                      : Icons.build_outlined,
                ),
          label: Text(
            readOnly
                ? 'Создание недоступно офлайн'
                : recipe.isCrafted
                ? 'Предмет уже создан'
                : recipe.canCraft
                ? 'Создать предмет'
                : 'Не хватает материалов',
          ),
        ),
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({
    required this.error,
    required this.onRetry,
    required this.onOpenDemo,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onOpenDemo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'Не удалось загрузить состояние',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
            TextButton(
              onPressed: onOpenDemo,
              child: const Text('Открыть демонстрационное состояние'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.label,
    required this.name,
    required this.level,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String name;
  final int level;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 32),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Уровень $level'),
            const SizedBox(height: 2),
            Text(detail),
          ],
        ),
      ),
    );
  }
}
