import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:walking_rpg_mobile/core/cache/cached_snapshot_banner.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_chrome_insets.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_destination_visibility.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/companion_motion.dart';
import 'package:walking_rpg_mobile/design_system/companion_growth.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/crafting_assembly_signal.dart';
import 'package:walking_rpg_mobile/design_system/equipment_mount_signal.dart';
import 'package:walking_rpg_mobile/design_system/event_choice_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_event_scene.dart';
import 'package:walking_rpg_mobile/design_system/expedition_item_art.dart';
import 'package:walking_rpg_mobile/design_system/expedition_node_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_progress_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_read_state.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/progression_gain_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
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
typedef HomeImpressionRecorder =
    Future<Object?> Function({
      required String commandType,
      required Map<String, Object?> payload,
      required String idempotencyKey,
    });
typedef IdempotencyKeyFactory = String Function();

enum _HomeAppAction { refresh, account }

const double _homeStickyActionBaseBottom = 20;
const double _homeContentBaseBottomPadding = 138;
const double _homeContentWithSyncBaseBottomPadding = 218;

double _effectiveTextScale(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(16) / 16;
}

bool _usesCompactHomeChrome(BuildContext context, BoxConstraints constraints) {
  return constraints.maxWidth < 360 ||
      (constraints.maxWidth < 430 && _effectiveTextScale(context) > 1.3);
}

bool _usesCompactHomeSection(BuildContext context, BoxConstraints constraints) {
  return constraints.maxWidth < 320 ||
      (constraints.maxWidth < 400 && _effectiveTextScale(context) > 1.3);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.loader,
    this.advancer,
    this.eventResolver,
    this.eventResultAcknowledger,
    this.crafter,
    this.equipmentExecutor,
    this.impressionRecorder,
    this.idempotencyKeyFactory,
    this.onOpenAccount,
    this.onOpenRecovery,
    this.recoveryCount = 0,
    this.recoveryUnavailable = false,
    this.authoritativeRefreshGeneration = 0,
    this.activitySyncAction,
  });

  final HomeSnapshotLoader? loader;
  final ExpeditionAdvancer? advancer;
  final EventResolver? eventResolver;
  final EventResultAcknowledger? eventResultAcknowledger;
  final CraftingExecutor? crafter;
  final EquipmentExecutor? equipmentExecutor;
  final HomeImpressionRecorder? impressionRecorder;
  final IdempotencyKeyFactory? idempotencyKeyFactory;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenRecovery;
  final int recoveryCount;
  final bool recoveryUnavailable;
  final int authoritativeRefreshGeneration;
  final Widget? activitySyncAction;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Future<HomeSnapshot> _snapshotFuture;
  late AppLifecycleState _appLifecycleState;
  HomeSnapshot? _acceptedSnapshot;
  int _snapshotRequestGeneration = 0;
  bool _isDestinationVisible = false;
  bool _isRouteCurrent = false;
  bool _isAdvancing = false;
  bool _isResolving = false;
  bool _isAcknowledging = false;
  bool _isCrafting = false;
  bool _isChangingEquipment = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<State<StatefulWidget>> _routeChoiceViewportKey =
      GlobalKey<State<StatefulWidget>>(
        debugLabel: 'home-resonance-route-choice-viewport',
      );
  final GlobalKey<State<StatefulWidget>> _recipeViewportKey =
      GlobalKey<State<StatefulWidget>>(
        debugLabel: 'home-resonance-compass-recipe-viewport',
      );
  final GlobalKey<State<StatefulWidget>> _stickyActionOcclusionKey =
      GlobalKey<State<StatefulWidget>>(
        debugLabel: 'home-sticky-action-occlusion',
      );
  final Map<String, int> _attemptedCompassImpressionGenerations =
      <String, int>{};
  final Set<String> _scheduledCompassImpressions = <String>{};

  bool get _isBusy =>
      _isAdvancing ||
      _isResolving ||
      _isAcknowledging ||
      _isCrafting ||
      _isChangingEquipment;

  bool get _canPresentCompassImpressions =>
      _isDestinationVisible &&
      _isRouteCurrent &&
      _appLifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    _appLifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(
      _scheduleAcceptedCompassImpressionsAfterFrame,
    );
    _snapshotFuture = _startSnapshotLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool couldPresent = _canPresentCompassImpressions;
    _isDestinationVisible = NavigationDestinationVisibility.of(context);
    _isRouteCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (!couldPresent && _canPresentCompassImpressions) {
      _scheduleAcceptedCompassImpressionsAfterFrame();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool couldPresent = _canPresentCompassImpressions;
    _appLifecycleState = state;
    if (!couldPresent && _canPresentCompassImpressions) {
      _scheduleAcceptedCompassImpressionsAfterFrame();
    }
  }

  @override
  void didChangeMetrics() {
    _scheduleAcceptedCompassImpressionsAfterFrame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader ||
        oldWidget.authoritativeRefreshGeneration !=
            widget.authoritativeRefreshGeneration) {
      _snapshotFuture = _startSnapshotLoad();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compactChrome = _usesCompactHomeChrome(context, constraints);
        return Scaffold(
          appBar: AppBar(
            title: _HomeAppTitle(compact: compactChrome),
            actions: <Widget>[
              if (!compactChrome)
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
              if (compactChrome)
                _HomeAppActionsMenu(
                  refreshEnabled: !_isBusy,
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
          body: SafeArea(
            child: FutureBuilder<HomeSnapshot>(
              future: _snapshotFuture,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<HomeSnapshot> asyncSnapshot,
                  ) {
                    if (asyncSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return _HomeReadState(
                        activitySyncAction: widget.activitySyncAction,
                        child: const ExpeditionReadState.loading(
                          key: Key('home-loading-state'),
                          title: 'Сверяем маршрут',
                          message:
                              'Получаем шаги, ENERGY и актуальное состояние '
                              'экспедиции.',
                        ),
                      );
                    }
                    if (asyncSnapshot.hasError) {
                      return _HomeReadState(
                        activitySyncAction: widget.activitySyncAction,
                        child: _HomeError(
                          error: asyncSnapshot.error!,
                          onRetry: _reload,
                          onOpenDemo: _openDemo,
                        ),
                      );
                    }
                    final HomeSnapshot? snapshot = asyncSnapshot.data;
                    if (snapshot == null) {
                      return _HomeReadState(
                        activitySyncAction: widget.activitySyncAction,
                        child: _HomeError(
                          error: const FormatException(
                            'Backend не вернул состояние',
                          ),
                          onRetry: _reload,
                          onOpenDemo: _openDemo,
                        ),
                      );
                    }
                    return _HomeBody(
                      snapshot: snapshot,
                      scrollController: _scrollController,
                      routeChoiceViewportKey: _routeChoiceViewportKey,
                      recipeViewportKey: _recipeViewportKey,
                      stickyActionOcclusionKey: _stickyActionOcclusionKey,
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
                      onEquip: (HomeInventoryItem item) =>
                          _equip(snapshot, item),
                      onUnequip: (HomeEquipmentSlot slot) =>
                          _unequip(snapshot, slot),
                      onRefresh: _reload,
                      activitySyncAction: widget.activitySyncAction,
                    );
                  },
            ),
          ),
        );
      },
    );
  }

  Future<HomeSnapshot> _startSnapshotLoad() {
    final int requestGeneration = ++_snapshotRequestGeneration;
    _acceptedSnapshot = null;
    return _loadSnapshot(requestGeneration);
  }

  Future<HomeSnapshot> _loadSnapshot(int requestGeneration) async {
    final HomeSnapshotLoader? loader = widget.loader;
    final HomeSnapshot snapshot = loader != null
        ? await loader()
        : await HomeApiClient.fromEnvironment().fetchHome(DateTime.now());
    if (mounted && requestGeneration == _snapshotRequestGeneration) {
      _acceptedSnapshot = snapshot;
      _scheduleAcceptedCompassImpressionsAfterFrame(
        requestGeneration: requestGeneration,
      );
    }
    return snapshot;
  }

  void _scheduleAcceptedCompassImpressionsAfterFrame({int? requestGeneration}) {
    final HomeSnapshot? snapshot = _acceptedSnapshot;
    final int acceptedGeneration =
        requestGeneration ?? _snapshotRequestGeneration;
    if (snapshot == null || !_canPresentCompassImpressions) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted ||
          !_canPresentCompassImpressions ||
          acceptedGeneration != _snapshotRequestGeneration ||
          !identical(snapshot, _acceptedSnapshot)) {
        return;
      }
      _scheduleVisibleCompassImpressions(snapshot);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _scheduleVisibleCompassImpressions(HomeSnapshot snapshot) {
    if (!mounted || snapshot.isCached || widget.impressionRecorder == null) {
      return;
    }
    if (_isViewportTargetVisible(_recipeViewportKey)) {
      for (final HomeCraftingRecipe recipe in snapshot.craftingRecipes) {
        if (recipe.recipeId != 'resonance-compass-v1') {
          continue;
        }
        _scheduleCompassImpression(
          contentVersion: snapshot.contentVersion,
          impression: 'RECIPE_${recipe.status}',
          identity: 'recipe-${recipe.recipeId}-${recipe.recipeVersion}',
        );
      }
    }

    final HomeExpeditionEvent? event = snapshot.unlockedEvent;
    if (event == null ||
        event.eventId != 'mirror-delta-v1' ||
        !_isViewportTargetVisible(_routeChoiceViewportKey)) {
      return;
    }
    for (final HomeEventChoice choice in event.choices) {
      if (choice.choiceId != 'follow-resonance') {
        continue;
      }
      final String availability = choice.isAvailable ? 'AVAILABLE' : 'LOCKED';
      _scheduleCompassImpression(
        contentVersion: snapshot.contentVersion,
        impression: 'ROUTE_$availability',
        identity: 'route-${event.eventId}-${choice.choiceId}',
      );
    }
  }

  bool _isViewportTargetVisible(GlobalKey<State<StatefulWidget>> targetKey) {
    final RenderObject? targetObject = targetKey.currentContext
        ?.findRenderObject();
    if (targetObject is! RenderBox ||
        !targetObject.attached ||
        !targetObject.hasSize) {
      return false;
    }
    final RenderAbstractViewport? abstractViewport =
        RenderAbstractViewport.maybeOf(targetObject);
    final RenderBox? viewport = switch (abstractViewport) {
      final RenderBox renderBox => renderBox,
      _ => null,
    };
    if (viewport == null) {
      return false;
    }
    if (!viewport.attached || !viewport.hasSize) {
      return false;
    }
    final Rect targetBounds =
        targetObject.localToGlobal(Offset.zero) & targetObject.size;
    Rect viewportBounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    final RenderObject? stickyActionObject = _stickyActionOcclusionKey
        .currentContext
        ?.findRenderObject();
    if (stickyActionObject is RenderBox &&
        stickyActionObject.attached &&
        stickyActionObject.hasSize) {
      final Rect stickyActionBounds =
          stickyActionObject.localToGlobal(Offset.zero) &
          stickyActionObject.size;
      final Rect coveredBounds = stickyActionBounds.intersect(viewportBounds);
      if (coveredBounds.width > 0 && coveredBounds.height > 0) {
        // The sticky action is the highest full-width overlay. Clipping the
        // measurable viewport at its top also excludes the extended-body
        // navigation overlay painted below it.
        viewportBounds = Rect.fromLTRB(
          viewportBounds.left,
          viewportBounds.top,
          viewportBounds.right,
          coveredBounds.top,
        );
      }
    }
    final Rect intersection = targetBounds.intersect(viewportBounds);
    return intersection.width > 0 && intersection.height > 0;
  }

  void _scheduleCompassImpression({
    required String contentVersion,
    required String impression,
    required String identity,
  }) {
    final String idempotencyKey =
        'compass-impression-$contentVersion-$identity-$impression';
    final int attemptGeneration = _snapshotRequestGeneration;
    if (_scheduledCompassImpressions.contains(idempotencyKey) ||
        _attemptedCompassImpressionGenerations[idempotencyKey] ==
            attemptGeneration) {
      return;
    }
    _attemptedCompassImpressionGenerations[idempotencyKey] = attemptGeneration;
    _scheduledCompassImpressions.add(idempotencyKey);
    unawaited(
      _recordCompassImpression(
        contentVersion: contentVersion,
        impression: impression,
        idempotencyKey: idempotencyKey,
        attemptGeneration: attemptGeneration,
      ),
    );
  }

  Future<void> _recordCompassImpression({
    required String contentVersion,
    required String impression,
    required String idempotencyKey,
    required int attemptGeneration,
  }) async {
    final HomeImpressionRecorder? recorder = widget.impressionRecorder;
    if (recorder == null) {
      return;
    }
    try {
      await recorder(
        commandType: 'RECORD_COMPASS_IMPRESSION',
        payload: <String, Object?>{
          'impression': impression,
          'contentVersion': contentVersion,
        },
        idempotencyKey: idempotencyKey,
      );
    } on Object {
      _scheduledCompassImpressions.remove(idempotencyKey);
      if (mounted && attemptGeneration != _snapshotRequestGeneration) {
        _scheduleAcceptedCompassImpressionsAfterFrame();
      }
    }
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
        _snapshotFuture = _startSnapshotLoad();
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
        _snapshotFuture = _startSnapshotLoad();
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
        _snapshotFuture = _startSnapshotLoad();
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
        _snapshotFuture = _startSnapshotLoad();
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
        _snapshotFuture = _startSnapshotLoad();
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
      _snapshotRequestGeneration += 1;
      _acceptedSnapshot = null;
      _snapshotFuture = Future<HomeSnapshot>.value(HomeSnapshot.demo);
    });
  }

  void _reload() {
    if (_isBusy) {
      return;
    }
    setState(() {
      _snapshotFuture = _startSnapshotLoad();
    });
  }
}

class _HomeReadState extends StatelessWidget {
  const _HomeReadState({required this.child, required this.activitySyncAction});

  final Widget child;
  final Widget? activitySyncAction;

  @override
  Widget build(BuildContext context) {
    final Widget? action = activitySyncAction;
    final double bottomDockInset = NavigationChromeInsets.bottomDockInsetOf(
      context,
    );
    if (action == null) {
      return ExpeditionBackdrop(child: child);
    }

    return ExpeditionBackdrop(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: _homeContentBaseBottomPadding + bottomDockInset,
              ),
              child: child,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: _homeStickyActionBaseBottom + bottomDockInset,
            child: SafeArea(
              top: false,
              child: ExpeditionPanel(
                key: const Key('home-sticky-action-panel'),
                tone: ExpeditionPanelTone.lumen,
                padding: const EdgeInsets.all(10),
                child: action,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.snapshot,
    required this.scrollController,
    required this.routeChoiceViewportKey,
    required this.recipeViewportKey,
    required this.stickyActionOcclusionKey,
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
    required this.activitySyncAction,
  });

  final HomeSnapshot snapshot;
  final ScrollController scrollController;
  final GlobalKey<State<StatefulWidget>> routeChoiceViewportKey;
  final GlobalKey<State<StatefulWidget>> recipeViewportKey;
  final GlobalKey<State<StatefulWidget>> stickyActionOcclusionKey;
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
  final Widget? activitySyncAction;

  @override
  Widget build(BuildContext context) {
    final double bottomDockInset = NavigationChromeInsets.bottomDockInsetOf(
      context,
    );
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
    final bool busy =
        isAdvancing ||
        isResolving ||
        isAcknowledging ||
        isCrafting ||
        isChangingEquipment;
    final bool gameplayActionBlocked =
        busy || pendingEventResult != null || readOnly;
    final String actionLabel = readOnly
        ? 'Изменения недоступны офлайн'
        : completed
        ? 'Экспедиция завершена'
        : pendingEventResult != null
        ? 'Сначала подтвердите результат'
        : eventReady
        ? 'Выберите решение события'
        : spendableEnergy > 0
        ? 'Потратить $spendableEnergy энергии'
        : 'Нужно накопить энергию';
    final bool actionDisabled =
        readOnly ||
        eventReady ||
        completed ||
        pendingEventResult != null ||
        spendableEnergy <= 0 ||
        busy;

    return ExpeditionBackdrop(
      child: Stack(
        children: <Widget>[
          ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              (activitySyncAction == null
                      ? _homeContentBaseBottomPadding
                      : _homeContentWithSyncBaseBottomPadding) +
                  bottomDockInset,
            ),
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (snapshot.cacheMetadata != null) ...<Widget>[
                    CachedSnapshotBanner(metadata: snapshot.cacheMetadata!),
                    const SizedBox(height: 14),
                  ],
                  _ExpeditionHero(
                    snapshot: snapshot,
                    completed: completed,
                    activitySubtitle: activitySubtitle,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onRefresh,
                    icon: const Icon(Icons.sync),
                    label: const Text('Обновить состояние'),
                  ),
                  if (pendingEventResult != null) ...<Widget>[
                    const SizedBox(height: 20),
                    _PendingEventResultCard(
                      result: pendingEventResult,
                      readOnly: readOnly,
                      acknowledging: isAcknowledging,
                      onAcknowledge: onAcknowledgeEventResult,
                    ),
                  ],
                  if (event != null) ...<Widget>[
                    const SizedBox(height: 20),
                    _EventCard(
                      event: event,
                      routeChoiceViewportKey: routeChoiceViewportKey,
                      isResolving: isResolving,
                      disabled:
                          isResolving ||
                          isAcknowledging ||
                          readOnly ||
                          pendingEventResult != null,
                      onChoose: onResolve,
                    ),
                  ],
                  const SizedBox(height: 24),
                  const ExpeditionSectionTitle(
                    title: 'Команда экспедиции',
                    subtitle: 'Пилот задаёт путь, питомец усиливает решения.',
                    icon: Icons.group_outlined,
                  ),
                  const SizedBox(height: 12),
                  _ExpeditionTeam(snapshot: snapshot),
                  if (snapshot.equipment.isNotEmpty ||
                      snapshot.inventory.isNotEmpty ||
                      snapshot.craftingRecipes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 24),
                    const ExpeditionSectionTitle(
                      title: 'Полевой комплект',
                      subtitle: 'Снаряжение, находки и мастерская этой главы.',
                      icon: Icons.backpack_outlined,
                    ),
                  ],
                  if (snapshot.equipment.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    _EquipmentCard(
                      slots: snapshot.equipment,
                      readOnly: readOnly,
                      busy: gameplayActionBlocked,
                      changing: isChangingEquipment,
                      onUnequip: onUnequip,
                    ),
                  ],
                  if (snapshot.inventory.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    _InventoryCard(
                      items: snapshot.inventory,
                      readOnly: readOnly,
                      busy: gameplayActionBlocked,
                      changing: isChangingEquipment,
                      onEquip: onEquip,
                    ),
                  ],
                  if (snapshot.craftingRecipes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    _CraftingCard(
                      recipes: snapshot.craftingRecipes,
                      recipeViewportKey: recipeViewportKey,
                      readOnly: readOnly,
                      busy: gameplayActionBlocked,
                      crafting: isCrafting,
                      onCraft: onCraft,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _StateFooter(snapshot: snapshot),
                ],
              ),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: _homeStickyActionBaseBottom + bottomDockInset,
            child: SafeArea(
              top: false,
              child: SizedBox(
                key: stickyActionOcclusionKey,
                child: ExpeditionPanel(
                  key: const Key('home-sticky-action-panel'),
                  tone: eventReady || pendingEventResult != null
                      ? ExpeditionPanelTone.resonance
                      : ExpeditionPanelTone.energy,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (activitySyncAction != null) ...<Widget>[
                        activitySyncAction!,
                        const SizedBox(height: 8),
                      ],
                      FilledButton.icon(
                        onPressed: actionDisabled ? null : onAdvance,
                        icon: isAdvancing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.near_me_outlined),
                        label: Text(
                          actionLabel,
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAppTitle extends StatelessWidget {
  const _HomeAppTitle({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      label: 'Walking RPG',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!compact) ...<Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.radar, color: colors.primary, size: 20),
                ),
              ),
              const SizedBox(width: 10),
            ],
            const Flexible(
              child: Text(
                'Walking RPG',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAppActionsMenu extends StatelessWidget {
  const _HomeAppActionsMenu({
    required this.refreshEnabled,
    required this.onRefresh,
    required this.onOpenAccount,
  });

  final bool refreshEnabled;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_HomeAppAction>(
      key: const Key('home-more-actions'),
      tooltip: 'Ещё действия',
      icon: const Icon(Icons.more_vert),
      onSelected: (_HomeAppAction action) {
        switch (action) {
          case _HomeAppAction.refresh:
            onRefresh();
            break;
          case _HomeAppAction.account:
            onOpenAccount?.call();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_HomeAppAction>>[
        PopupMenuItem<_HomeAppAction>(
          key: const Key('home-menu-refresh'),
          value: _HomeAppAction.refresh,
          enabled: refreshEnabled,
          child: const _HomeMenuLabel(
            icon: Icons.refresh,
            label: 'Обновить состояние',
          ),
        ),
        PopupMenuItem<_HomeAppAction>(
          key: const Key('home-menu-account'),
          value: _HomeAppAction.account,
          enabled: onOpenAccount != null,
          child: const _HomeMenuLabel(
            icon: Icons.account_circle_outlined,
            label: 'Аккаунт',
          ),
        ),
      ],
    );
  }
}

class _HomeMenuLabel extends StatelessWidget {
  const _HomeMenuLabel({required this.icon, required this.label});

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

class _ExpeditionHero extends StatelessWidget {
  const _ExpeditionHero({
    required this.snapshot,
    required this.completed,
    required this.activitySubtitle,
  });

  final HomeSnapshot snapshot;
  final bool completed;
  final String activitySubtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final bool hasCompanionPortrait =
        snapshot.petId != null &&
        snapshot.petSpecies != null &&
        snapshot.petEvolutionStage != null;
    return ExpeditionPanel(
      tone: ExpeditionPanelTone.lumen,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChapterVista(
            key: const Key('home-expedition-vista'),
            semanticLabel:
                '${snapshot.expeditionName}, ${snapshot.currentNodeName}',
            progress: snapshot.expeditionProgressValue,
            height: 178,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ExpeditionNodeSignal(
                key: const Key('home-current-node-badge'),
                nodeId: snapshot.currentNodeId,
                nodeName: snapshot.currentNodeName,
                completed: completed,
              ),
              if (!hasCompanionPortrait)
                ExpeditionBadge(
                  key: const Key('home-active-companion-badge'),
                  label: '${snapshot.petName} · ур. ${snapshot.petLevel}',
                  icon: Icons.pets_outlined,
                  tone: ExpeditionPanelTone.resonance,
                ),
            ],
          ),
          if (hasCompanionPortrait) ...<Widget>[
            const SizedBox(height: 12),
            _ActiveCompanionCard(snapshot: snapshot),
          ],
          const SizedBox(height: 16),
          Text(
            completed ? 'Экспедиция завершена' : 'Экспедиция ждёт твоих шагов',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Сначала прогулка. Решения и награды — после неё.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          _DailyProgressSummary(
            snapshot: snapshot,
            activitySubtitle: activitySubtitle,
          ),
          const SizedBox(height: 22),
          Divider(color: context.walkingRpgPalette.panelBorder),
          const SizedBox(height: 2),
          _RouteEnergySummary(
            expeditionName: snapshot.expeditionName,
            availableEnergy: snapshot.availableEnergy,
          ),
          const SizedBox(height: 8),
          Text(
            '${snapshot.expeditionProgress} / ${snapshot.requiredEnergy} энергии'
            ' · ${snapshot.currentNodeName}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ExpeditionProgressSignal(
            expeditionId: snapshot.expeditionId,
            progress: snapshot.expeditionProgress,
            target: snapshot.requiredEnergy,
          ),
          const SizedBox(height: 10),
          Text(
            completed
                ? 'Маршрут пройден. Результат сохранён на сервере.'
                : 'До следующего узла: '
                      '${snapshot.remainingExpeditionEnergy} ENERGY',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: palette.energy),
          ),
        ],
      ),
    );
  }
}

class _DailyProgressSummary extends StatelessWidget {
  const _DailyProgressSummary({
    required this.snapshot,
    required this.activitySubtitle,
  });

  final HomeSnapshot snapshot;
  final String activitySubtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget ring = ExpeditionProgressRing(
      progress: snapshot.dailyProgress,
      value: '${(snapshot.dailyProgress * 100).round()}%',
      label: 'шаги',
      size: 108,
    );
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Сегодня: ${snapshot.dailySteps} / ${snapshot.dailyGoal}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          activitySubtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (_usesCompactHomeSection(context, constraints)) {
          return Column(
            key: const Key('home-daily-progress-compact'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(child: ring),
              const SizedBox(height: 16),
              details,
            ],
          );
        }
        return Row(
          key: const Key('home-daily-progress-wide'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ring,
            const SizedBox(width: 18),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class _RouteEnergySummary extends StatelessWidget {
  const _RouteEnergySummary({
    required this.expeditionName,
    required this.availableEnergy,
  });

  final String expeditionName;
  final int availableEnergy;

  @override
  Widget build(BuildContext context) {
    final Widget title = Text(
      expeditionName,
      style: Theme.of(context).textTheme.titleLarge,
    );
    final Widget energy = ExpeditionBadge(
      label: '$availableEnergy ENERGY',
      icon: Icons.bolt,
      tone: ExpeditionPanelTone.energy,
      allowWrap: true,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (_usesCompactHomeSection(context, constraints)) {
          return Column(
            key: const Key('home-route-energy-compact'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[title, const SizedBox(height: 10), energy],
          );
        }
        return Row(
          key: const Key('home-route-energy-wide'),
          children: <Widget>[
            Expanded(child: title),
            const SizedBox(width: 10),
            energy,
          ],
        );
      },
    );
  }
}

class _ExpeditionTeam extends StatelessWidget {
  const _ExpeditionTeam({required this.snapshot});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final bool hasCompanionPortrait =
        snapshot.petId != null &&
        snapshot.petSpecies != null &&
        snapshot.petEvolutionStage != null;
    final Widget pilot = _CharacterCard(
      key: const Key('home-pilot-card'),
      label: 'Пилот',
      name: snapshot.pilotName,
      level: snapshot.pilotLevel,
      detail:
          'XP ${snapshot.pilotCurrentExperience} / '
          '${snapshot.pilotNextLevelExperience}',
      icon: Icons.person_outline,
      portrait: ExcludeSemantics(
        child: PilotPortrait(name: snapshot.pilotName, size: 72),
      ),
    );
    final Widget pet = _CharacterCard(
      key: const Key('home-pet-card'),
      label: 'Питомец',
      name: snapshot.petName,
      level: snapshot.petLevel,
      detail: snapshot.petEvolutionStage == null
          ? 'Связь ${snapshot.petBond}'
          : 'Связь ${snapshot.petBond} · '
                '${CompanionGrowth.stageName(snapshot.petEvolutionStage!)}',
      icon: Icons.pets_outlined,
      portrait: hasCompanionPortrait
          ? ExcludeSemantics(
              child: CompanionPortrait(
                key: const Key('home-team-companion-portrait'),
                petId: snapshot.petId!,
                name: snapshot.petName,
                species: snapshot.petSpecies!,
                evolutionStage: snapshot.petEvolutionStage!,
                active: true,
                size: 72,
              ),
            )
          : null,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (_usesCompactHomeSection(context, constraints)) {
          return Column(
            key: const Key('home-expedition-team-compact'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[pilot, const SizedBox(height: 12), pet],
          );
        }
        return Row(
          key: const Key('home-expedition-team-wide'),
          children: <Widget>[
            Expanded(child: pilot),
            const SizedBox(width: 12),
            Expanded(child: pet),
          ],
        );
      },
    );
  }
}

class _ActiveCompanionCard extends StatelessWidget {
  const _ActiveCompanionCard({required this.snapshot});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final String petId = snapshot.petId!;
    final String species = snapshot.petSpecies!;
    final int evolutionStage = snapshot.petEvolutionStage!;

    final Widget portrait = CompanionMotionPortrait(
      key: const Key('home-active-companion-portrait'),
      petId: petId,
      name: snapshot.petName,
      species: species,
      evolutionStage: evolutionStage,
      active: true,
      size: 78,
    );
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'АКТИВНЫЙ СПУТНИК',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palette.resonance,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            ExpeditionBadge(
              label: '${snapshot.petName} · ур. ${snapshot.petLevel}',
              icon: Icons.pets_outlined,
              tone: ExpeditionPanelTone.resonance,
            ),
            ExpeditionBadge(
              label: CompanionGrowth.formLabel(evolutionStage),
              icon: Icons.auto_awesome_outlined,
              tone: evolutionStage > 0
                  ? ExpeditionPanelTone.resonance
                  : ExpeditionPanelTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$species · связь ${snapshot.petBond}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );

    return DecoratedBox(
      key: const Key('home-active-companion-badge'),
      decoration: BoxDecoration(
        color: palette.resonance.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.resonance.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth < 280) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      portrait,
                      const SizedBox(height: 12),
                      details,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    portrait,
                    const SizedBox(width: 14),
                    Expanded(child: details),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            CompanionGrowthTrack(
              key: const Key('home-companion-growth'),
              currentStage: evolutionStage,
            ),
          ],
        ),
      ),
    );
  }
}

class _StateFooter extends StatelessWidget {
  const _StateFooter({required this.snapshot});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ExpeditionPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        children: <Widget>[
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Контент: ${snapshot.contentVersion}',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
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
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final EventMaterialReward? material = result.material;
    final EventNextNode? nextNode = result.nextNode;
    return ExpeditionPanel(
      key: const Key('pending-event-result-card'),
      tone: ExpeditionPanelTone.resonance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ExpeditionEventScene(
            eventId: result.eventId,
            eventTitle: result.eventTitle,
            fallbackSemanticLabel:
                'Сцена завершённого события «${result.eventTitle}»',
          ),
          const SizedBox(height: 16),
          Text(
            'СОБЫТИЕ ЗАВЕРШЕНО',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: palette.resonance,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.eventTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          EventChoiceSignalLayout(
            eventId: result.eventId,
            choiceId: result.choiceId,
            child: Text(
              result.choiceTitle,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.outcomeTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(result.outcomeSummary),
          const SizedBox(height: 16),
          ProgressionGainSignalLayout(
            kind: ProgressionGainKind.pilotExperience,
            subjectId: result.pilot.pilotId,
            child: Text(
              '+${result.pilot.experienceGained} XP · '
              'всего ${result.pilot.currentExperience}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 8),
          ProgressionGainSignalLayout(
            kind: ProgressionGainKind.petBond,
            subjectId: result.pet.petId,
            child: Text(
              '+${result.pet.bondGained} связи · '
              '${result.pet.name}: ${result.pet.bond}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          if (material != null) ...<Widget>[
            const SizedBox(height: 8),
            _RewardLine(
              leading: ExpeditionItemEmblem(
                itemId: material.itemId,
                size: 44,
                highlighted: true,
              ),
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
              'СЛЕДУЮЩИЙ УЗЕЛ',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.resonance,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ExpeditionNodeSignal(
                nodeId: nextNode.nodeId,
                nodeName: nextNode.name,
                completed: false,
                role: ExpeditionNodeSignalRole.next,
                markSize: 46,
              ),
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
    );
  }
}

class _RewardLine extends StatelessWidget {
  const _RewardLine({required this.leading, required this.text});

  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        leading,
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
    required this.routeChoiceViewportKey,
    required this.isResolving,
    required this.disabled,
    required this.onChoose,
  });

  final HomeExpeditionEvent event;
  final GlobalKey<State<StatefulWidget>> routeChoiceViewportKey;
  final bool isResolving;
  final bool disabled;
  final ValueChanged<HomeEventChoice> onChoose;

  @override
  Widget build(BuildContext context) {
    return ExpeditionPanel(
      tone: ExpeditionPanelTone.resonance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExpeditionBadge(
            label: event.isResolved ? 'Событие разрешено' : 'Событие открыто',
            icon: Icons.auto_awesome_outlined,
            tone: ExpeditionPanelTone.resonance,
          ),
          const SizedBox(height: 12),
          ExpeditionEventScene(
            eventId: event.eventId,
            eventTitle: event.title,
            fallbackSemanticLabel: 'Сцена события «${event.title}»',
          ),
          const SizedBox(height: 14),
          Text(event.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(event.summary),
          if (event.isResolved) ...<Widget>[
            const SizedBox(height: 12),
            if (event.selectedChoiceId != null)
              EventChoiceSignalLayout(
                eventId: event.eventId,
                choiceId: event.selectedChoiceId!,
                child: Text(
                  event.selectedChoiceTitle ?? 'Выбор зафиксирован',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              )
            else
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
              _RewardLine(
                leading: ExpeditionItemEmblem(
                  itemId: event.materialReward!.itemId,
                  size: 44,
                  highlighted: true,
                ),
                text:
                    '+${event.materialReward!.quantityGained} '
                    '${event.materialReward!.itemName} '
                    '· всего ${event.materialReward!.quantityAfter}',
              ),
            ],
          ] else ...<Widget>[
            const SizedBox(height: 12),
            for (final HomeEventChoice choice in event.choices) ...<Widget>[
              SizedBox(
                key: choice.choiceId == 'follow-resonance'
                    ? routeChoiceViewportKey
                    : null,
                width: double.infinity,
                child: FilledButton.tonal(
                  key: Key('home-event-choice-${choice.choiceId}'),
                  onPressed: disabled || !choice.isAvailable
                      ? null
                      : () => onChoose(choice),
                  child: _EventChoiceLabel(
                    eventId: event.eventId,
                    choice: choice,
                    rewardText: _rewardText(choice),
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
            ],
            if (isResolving) const Center(child: CircularProgressIndicator()),
          ],
        ],
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

class _EventChoiceLabel extends StatelessWidget {
  const _EventChoiceLabel({
    required this.eventId,
    required this.choice,
    required this.rewardText,
  });

  final String eventId;
  final HomeEventChoice choice;
  final String rewardText;

  @override
  Widget build(BuildContext context) {
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(choice.title),
        Text(rewardText, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    final HomeMaterialRewardPreview? material = choice.materialReward;
    return EventChoiceSignalLayout(
      eventId: eventId,
      choiceId: choice.choiceId,
      muted: !choice.isAvailable,
      trailing: material == null
          ? null
          : ExpeditionItemEmblem(itemId: material.itemId, size: 42),
      child: copy,
    );
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
    return ExpeditionPanel(
      key: const Key('equipment-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ExpeditionSectionTitle(
            title: 'Снаряжение',
            subtitle: 'Активные инструменты навигации.',
            icon: Icons.explore_outlined,
          ),
          const SizedBox(height: 12),
          for (final HomeEquipmentSlot slot in slots) ...<Widget>[
            Text(slot.name, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(slot.description),
            const SizedBox(height: 8),
            EquipmentMountSignal(
              slotId: slot.slotId,
              status: slot.status,
              itemId: slot.item?.itemId,
            ),
            const SizedBox(height: 10),
            if (slot.item == null)
              const Text('Слот свободен')
            else
              _IllustratedItemIdentity(
                layoutKey: 'equipment-item-layout-${slot.slotId}',
                itemId: slot.item!.itemId,
                title: slot.item!.name,
                titleKey: Key('equipment-item-${slot.slotId}'),
                description: slot.item!.description,
                highlighted: true,
                footer: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
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
                ),
              ),
            const SizedBox(height: 6),
          ],
        ],
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
    return ExpeditionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ExpeditionSectionTitle(
            title: 'Инвентарь',
            subtitle: 'Материалы и уникальные находки.',
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 12),
          for (final HomeInventoryItem item in items) ...<Widget>[
            _IllustratedItemIdentity(
              layoutKey: 'inventory-item-layout-${item.itemId}',
              itemId: item.itemId,
              title: item.isUnique
                  ? '${item.name} · уникальный предмет'
                  : '${item.name} × ${item.quantity}',
              description: item.description,
              highlighted: item.isUnique || item.isEquipped,
              footer: item.isEquippable
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        key: Key('inventory-equip-${item.itemId}'),
                        onPressed: readOnly || busy || item.isEquipped
                            ? null
                            : () => onEquip(item),
                        icon: changing
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.explore_outlined),
                        label: Text(
                          item.isEquipped ? 'Экипировано' : 'Экипировать',
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _CraftingCard extends StatelessWidget {
  const _CraftingCard({
    required this.recipes,
    required this.recipeViewportKey,
    required this.readOnly,
    required this.busy,
    required this.crafting,
    required this.onCraft,
  });

  final List<HomeCraftingRecipe> recipes;
  final GlobalKey<State<StatefulWidget>> recipeViewportKey;
  final bool readOnly;
  final bool busy;
  final bool crafting;
  final ValueChanged<HomeCraftingRecipe> onCraft;

  @override
  Widget build(BuildContext context) {
    return ExpeditionPanel(
      key: const Key('crafting-card'),
      tone: ExpeditionPanelTone.energy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ExpeditionSectionTitle(
            title: 'Мастерская',
            subtitle: 'Преобразуй находки в инструменты маршрута.',
            icon: Icons.handyman_outlined,
          ),
          const SizedBox(height: 12),
          for (int index = 0; index < recipes.length; index++) ...<Widget>[
            KeyedSubtree(
              key: Key('home-recipe-viewport-${recipes[index].recipeId}'),
              child: _CraftingRecipeView(
                key: recipes[index].recipeId == 'resonance-compass-v1'
                    ? recipeViewportKey
                    : null,
                recipe: recipes[index],
                readOnly: readOnly,
                busy: busy,
                crafting: crafting,
                onCraft: () => onCraft(recipes[index]),
              ),
            ),
            if (index + 1 < recipes.length) const Divider(height: 28),
          ],
        ],
      ),
    );
  }
}

class _CraftingRecipeView extends StatelessWidget {
  const _CraftingRecipeView({
    super.key,
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
        _IllustratedItemIdentity(
          layoutKey: 'crafting-result-layout-${recipe.result.itemId}',
          itemId: recipe.result.itemId,
          title: recipe.name,
          description: recipe.description,
          highlighted: recipe.canCraft || recipe.isCrafted,
        ),
        const SizedBox(height: 12),
        CraftingAssemblySignal(
          recipeId: recipe.recipeId,
          status: recipe.status,
          ingredientAvailability: recipe.ingredients
              .map(
                (HomeCraftingIngredient ingredient) => ingredient.isAvailable,
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 14),
        for (final HomeCraftingIngredient ingredient
            in recipe.ingredients) ...<Widget>[
          Semantics(
            container: true,
            label:
                '${ingredient.name}, ${ingredient.availableQuantity} из '
                '${ingredient.requiredQuantity}, '
                '${ingredient.isAvailable ? 'материала достаточно' : 'материала не хватает'}',
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  ExpeditionItemEmblem(itemId: ingredient.itemId, size: 38),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ingredient.name)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Icon(
                        ingredient.isAvailable
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      Text(
                        '${ingredient.availableQuantity} / '
                        '${ingredient.requiredQuantity}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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

class _IllustratedItemIdentity extends StatelessWidget {
  const _IllustratedItemIdentity({
    required this.layoutKey,
    required this.itemId,
    required this.title,
    required this.description,
    this.titleKey,
    this.highlighted = false,
    this.footer,
  });

  final String layoutKey;
  final String itemId;
  final String title;
  final String description;
  final Key? titleKey;
  final bool highlighted;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          key: titleKey,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 3),
        Text(description),
        if (footer != null) ...<Widget>[const SizedBox(height: 8), footer!],
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 300;
        final Widget art = ExpeditionItemEmblem(
          itemId: itemId,
          size: compact ? 64 : 72,
          highlighted: highlighted,
        );
        return KeyedSubtree(
          key: Key('$layoutKey-${compact ? 'compact' : 'wide'}'),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[art, const SizedBox(height: 10), details],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    art,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
        );
      },
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
    return ExpeditionReadState.failure(
      key: const Key('home-error-state'),
      title: 'Не удалось загрузить состояние',
      message:
          'Актуальный маршрут не принят. Повтори запрос или открой локальное '
          'демонстрационное состояние — оно не меняет серверные данные.',
      details: error.toString(),
      primaryActionKey: const Key('home-error-retry'),
      primaryActionLabel: 'Повторить',
      onPrimaryAction: onRetry,
      secondaryActionKey: const Key('home-error-demo'),
      secondaryActionLabel: 'Открыть демонстрационное состояние',
      onSecondaryAction: onOpenDemo,
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    super.key,
    required this.label,
    required this.name,
    required this.level,
    required this.detail,
    required this.icon,
    this.portrait,
  });

  final String label;
  final String name;
  final int level;
  final String detail;
  final IconData icon;
  final Widget? portrait;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ExpeditionPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          portrait ??
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, size: 24, color: colors.primary),
                ),
              ),
          const SizedBox(height: 14),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text('Уровень $level'),
          const SizedBox(height: 2),
          Text(
            detail,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
