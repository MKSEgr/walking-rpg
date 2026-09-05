import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:walking_rpg_mobile/core/cache/cached_snapshot_banner.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/localization/current_content_localizations.dart';
import 'package:walking_rpg_mobile/core/localization/current_event_localizations.dart';
import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_chrome_insets.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_destination_visibility.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/companion_growth.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/crafting_assembly_signal.dart';
import 'package:walking_rpg_mobile/design_system/equipment_mount_signal.dart';
import 'package:walking_rpg_mobile/design_system/event_choice_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_crew_scene.dart';
import 'package:walking_rpg_mobile/design_system/expedition_event_scene.dart';
import 'package:walking_rpg_mobile/design_system/expedition_item_art.dart';
import 'package:walking_rpg_mobile/design_system/expedition_node_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_progress_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_read_state.dart';
import 'package:walking_rpg_mobile/design_system/expedition_route_trail.dart';
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
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_journey_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/domain/weekly_activity_rhythm.dart';
import 'package:walking_rpg_mobile/features/item_upgrade/data/item_upgrade_api_client.dart';
import 'package:walking_rpg_mobile/features/item_upgrade/domain/item_upgrade_result.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_action.dart';

typedef HomeSnapshotLoader = Future<HomeSnapshot> Function();
typedef ExpeditionAdvancer =
    Future<ExpeditionAdvanceResult> Function({
      required String expeditionId,
      required int energyToSpend,
      required String idempotencyKey,
    });
typedef ExpeditionJourneyStarter =
    Future<ExpeditionJourneyResult> Function({
      required String expeditionId,
      required int expectedJourneyNumber,
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
typedef ItemUpgradeExecutor =
    Future<ItemUpgradeResult> Function({
      required String upgradeId,
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
    this.expeditionJourneyStarter,
    this.eventResolver,
    this.eventResultAcknowledger,
    this.crafter,
    this.itemUpgradeExecutor,
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
  final ExpeditionJourneyStarter? expeditionJourneyStarter;
  final EventResolver? eventResolver;
  final EventResultAcknowledger? eventResultAcknowledger;
  final CraftingExecutor? crafter;
  final ItemUpgradeExecutor? itemUpgradeExecutor;
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
  bool _isBeginningJourney = false;
  bool _isResolving = false;
  bool _isAcknowledging = false;
  bool _isCrafting = false;
  bool _isUpgrading = false;
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
      _isBeginningJourney ||
      _isResolving ||
      _isAcknowledging ||
      _isCrafting ||
      _isUpgrading ||
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
                  tooltip: context.l10n.homeRefreshTooltip,
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
                  tooltip: context.l10n.accountTooltip,
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
                        child: ExpeditionReadState.loading(
                          key: const Key('home-loading-state'),
                          title: context.l10n.homeLoadingTitle,
                          message: context.l10n.homeLoadingMessage,
                        ),
                      );
                    }
                    if (asyncSnapshot.hasError) {
                      return _HomeReadState(
                        activitySyncAction: widget.activitySyncAction,
                        child: _HomeError(
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
                      isBeginningJourney: _isBeginningJourney,
                      isResolving: _isResolving,
                      isAcknowledging: _isAcknowledging,
                      isCrafting: _isCrafting,
                      isUpgrading: _isUpgrading,
                      isChangingEquipment: _isChangingEquipment,
                      onAdvance: () => _advance(snapshot),
                      onBeginNextJourney: () => _beginNextJourney(snapshot),
                      onResolve: (HomeEventChoice choice) =>
                          _resolveEvent(snapshot, choice),
                      onAcknowledgeEventResult: () =>
                          _acknowledgeEventResult(snapshot),
                      onCraft: (HomeCraftingRecipe recipe) =>
                          _craft(snapshot, recipe),
                      onUpgrade: (HomeItemUpgrade upgrade) =>
                          _upgrade(snapshot, upgrade),
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
          ? context.l10n.homeAdvanceSucceeded(result.energySpent)
          : context.l10n.homeEventUnlocked(
              context.l10n.currentEventTitle(
                result.unlockedEvent!.eventId,
                result.unlockedEvent!.title,
              ),
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _snapshotFuture = _startSnapshotLoad();
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.homeAdvanceFailed)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdvancing = false;
        });
      }
    }
  }

  Future<void> _beginNextJourney(HomeSnapshot snapshot) async {
    if (_isBusy ||
        snapshot.isCached ||
        snapshot.pendingEventResult != null ||
        snapshot.expeditionStatus != 'COMPLETED') {
      return;
    }

    setState(() {
      _isBeginningJourney = true;
    });
    try {
      final ExpeditionJourneyStarter starter =
          widget.expeditionJourneyStarter ??
          ExpeditionApiClient.fromEnvironment().beginNextJourney;
      final ExpeditionJourneyResult result = await starter(
        expeditionId: snapshot.expeditionId,
        expectedJourneyNumber: snapshot.expeditionJourneyNumber,
        idempotencyKey: _nextKey('journey-${snapshot.expeditionId}'),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.homeJourneyStarted(result.journeyNumber)),
        ),
      );
      setState(() {
        _snapshotFuture = _startSnapshotLoad();
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.homeJourneyStartFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBeginningJourney = false;
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
          : context.l10n.homeMaterialRewardSuffix(
              material.quantityGained,
              material.name,
            );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.homeEventResolutionReward(
              result.outcomeTitle,
              result.pilot.experienceGained,
              result.pet.bondGained,
              materialText,
            ),
          ),
        ),
      );
      setState(() {
        _snapshotFuture = _startSnapshotLoad();
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.homeEventResolveFailed)),
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
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.homeEventAcknowledgeFailed)),
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
        SnackBar(
          content: Text(
            context.l10n.homeCraftedItem(
              context.l10n.currentItemName(
                result.craftedItem.itemId,
                result.craftedItem.name,
              ),
            ),
          ),
        ),
      );
      setState(() {
        _snapshotFuture = _startSnapshotLoad();
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.homeCraftFailed)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCrafting = false;
        });
      }
    }
  }

  Future<void> _upgrade(HomeSnapshot snapshot, HomeItemUpgrade upgrade) async {
    if (_isBusy ||
        snapshot.isCached ||
        snapshot.pendingEventResult != null ||
        !upgrade.canApply) {
      return;
    }

    setState(() {
      _isUpgrading = true;
    });
    try {
      final ItemUpgradeExecutor executor =
          widget.itemUpgradeExecutor ??
          ItemUpgradeApiClient.fromEnvironment().apply;
      final ItemUpgradeResult result = await executor(
        upgradeId: upgrade.upgradeId,
        idempotencyKey: _nextKey(upgrade.upgradeId),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.homeItemUpgraded(
              context.l10n.currentItemName(
                result.upgradedItem.itemId,
                result.upgradedItem.name,
              ),
              result.upgradedItem.upgradeLevel,
              result.upgradedItem.rarity,
            ),
          ),
        ),
      );
      setState(() {
        _snapshotFuture = _startSnapshotLoad();
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.homeUpgradeFailed)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpgrading = false;
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
          ? context.l10n.homeEquippedItem(
              context.l10n.currentItemName(
                result.equippedItem!.itemId,
                result.equippedItem!.name,
              ),
            )
          : context.l10n.homeNavigationItemRemoved;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _snapshotFuture = _startSnapshotLoad();
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.homeEquipmentChangeFailed)),
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
    required this.isBeginningJourney,
    required this.isResolving,
    required this.isAcknowledging,
    required this.isCrafting,
    required this.isUpgrading,
    required this.isChangingEquipment,
    required this.onAdvance,
    required this.onBeginNextJourney,
    required this.onResolve,
    required this.onAcknowledgeEventResult,
    required this.onCraft,
    required this.onUpgrade,
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
  final bool isBeginningJourney;
  final bool isResolving;
  final bool isAcknowledging;
  final bool isCrafting;
  final bool isUpgrading;
  final bool isChangingEquipment;
  final VoidCallback onAdvance;
  final VoidCallback onBeginNextJourney;
  final ValueChanged<HomeEventChoice> onResolve;
  final VoidCallback onAcknowledgeEventResult;
  final ValueChanged<HomeCraftingRecipe> onCraft;
  final ValueChanged<HomeItemUpgrade> onUpgrade;
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
        ? context.l10n.homeNeverSynced
        : context.l10n.homeLastSync(snapshot.lastActivitySyncAt!);
    final num? baseline = snapshot.dailyGoalPolicy.baselineSteps;
    final String formattedBaseline = baseline == null
        ? ''
        : baseline == baseline.roundToDouble()
        ? baseline.toInt().toString()
        : baseline.toString();
    final String goalExplanation =
        snapshot.dailyGoalPolicy.isAdaptive && baseline != null
        ? context.l10n.homeAdaptiveGoalExplanation(
            formattedBaseline,
            snapshot.dailyGoalPolicy.sampleDays,
            snapshot.dailyGoalPolicy.growthPercent,
          )
        : snapshot.dailyGoalPolicy.isDefault
        ? context.l10n.homeDefaultGoalExplanation(
            snapshot.dailyGoalPolicy.sampleDays,
            snapshot.dailyGoalPolicy.minimumSampleDays,
          )
        : context.l10n.homeLegacyGoalExplanation;
    final String activitySubtitle = '$goalExplanation\n$lastSync';
    final HomeExpeditionEvent? event = snapshot.unlockedEvent;
    final PendingEventResult? pendingEventResult = snapshot.pendingEventResult;
    final bool eventReady = event?.status == 'READY';
    final bool completed = snapshot.expeditionStatus == 'COMPLETED';
    final int spendableEnergy = snapshot.spendableEnergy;
    final bool readOnly = snapshot.isCached;
    final bool busy =
        isAdvancing ||
        isBeginningJourney ||
        isResolving ||
        isAcknowledging ||
        isCrafting ||
        isUpgrading ||
        isChangingEquipment;
    final bool gameplayActionBlocked =
        busy || pendingEventResult != null || readOnly;
    final String actionLabel = readOnly
        ? context.l10n.homeOfflineChangesUnavailable
        : pendingEventResult != null
        ? context.l10n.homeConfirmResultFirst
        : completed
        ? context.l10n.homeStartJourneyAction(
            snapshot.expeditionJourneyNumber + 1,
          )
        : eventReady
        ? context.l10n.homeChooseEventDecision
        : spendableEnergy > 0
        ? context.l10n.homeSpendEnergyAction(spendableEnergy)
        : context.l10n.homeNeedEnergyAction;
    final bool actionDisabled =
        readOnly ||
        pendingEventResult != null ||
        busy ||
        (!completed && (eventReady || spendableEnergy <= 0));

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
                    scrollController: scrollController,
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
                  _ExpeditionDetails(
                    snapshot: snapshot,
                    completed: completed,
                    activitySubtitle: activitySubtitle,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onRefresh,
                    icon: const Icon(Icons.sync),
                    label: Text(context.l10n.homeRefreshState),
                  ),
                  const SizedBox(height: 24),
                  ExpeditionSectionTitle(
                    title: context.l10n.homeCrewTitle,
                    subtitle: context.l10n.homeCrewSubtitle,
                    icon: Icons.group_outlined,
                  ),
                  const SizedBox(height: 12),
                  _ExpeditionTeam(snapshot: snapshot),
                  if (snapshot.petId != null &&
                      snapshot.petSpecies != null &&
                      snapshot.petEvolutionStage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _ActiveCompanionCard(snapshot: snapshot),
                  ],
                  if (snapshot.equipment.isNotEmpty ||
                      snapshot.inventory.isNotEmpty ||
                      snapshot.craftingRecipes.isNotEmpty ||
                      snapshot.itemUpgrades.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 24),
                    ExpeditionSectionTitle(
                      title: context.l10n.homeFieldKitTitle,
                      subtitle: context.l10n.homeFieldKitSubtitle,
                      icon: Icons.backpack_outlined,
                    ),
                  ],
                  if (snapshot.equipment.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    _EquipmentCard(
                      slots: snapshot.equipment,
                      equippedSlotCount: snapshot.equippedEquipmentSlotCount,
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
                      equippableItemCount:
                          snapshot.equippableInventoryItemCount,
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
                      craftableRecipeCount: snapshot.craftableRecipeCount,
                      recipeViewportKey: recipeViewportKey,
                      readOnly: readOnly,
                      busy: gameplayActionBlocked,
                      crafting: isCrafting,
                      onCraft: onCraft,
                    ),
                  ],
                  if (snapshot.itemUpgrades.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    _ItemUpgradeCard(
                      upgrades: snapshot.itemUpgrades,
                      readyItemUpgradeCount: snapshot.readyItemUpgradeCount,
                      readOnly: readOnly,
                      busy: gameplayActionBlocked,
                      upgrading: isUpgrading,
                      onUpgrade: onUpgrade,
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
                        key: completed
                            ? const Key('home-begin-next-journey')
                            : const Key('home-advance-expedition'),
                        onPressed: actionDisabled
                            ? null
                            : completed
                            ? onBeginNextJourney
                            : onAdvance,
                        icon: isAdvancing || isBeginningJourney
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                completed
                                    ? Icons.replay_outlined
                                    : Icons.near_me_outlined,
                              ),
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
      label: context.l10n.homeAppName,
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
            Flexible(
              child: Text(
                context.l10n.homeAppName,
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
      tooltip: context.l10n.moreActionsTooltip,
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
          child: _HomeMenuLabel(
            icon: Icons.refresh,
            label: context.l10n.homeRefreshState,
          ),
        ),
        PopupMenuItem<_HomeAppAction>(
          key: const Key('home-menu-account'),
          value: _HomeAppAction.account,
          enabled: onOpenAccount != null,
          child: _HomeMenuLabel(
            icon: Icons.account_circle_outlined,
            label: context.l10n.accountTooltip,
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
    required this.scrollController,
  });

  final HomeSnapshot snapshot;
  final bool completed;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('home-expedition-hero'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ExpeditionVistaStage(
          snapshot: snapshot,
          scrollController: scrollController,
          expeditionName: context.l10n.currentExpeditionName(
            snapshot.expeditionId, snapshot.expeditionName,
          ),
          currentNodeName: context.l10n.currentNodeName(
            snapshot.currentNodeId, snapshot.currentNodeName,
          ),
          currentNodeId: snapshot.currentNodeId,
          journeyNumber: snapshot.expeditionJourneyNumber,
          progress: snapshot.expeditionProgressValue,
          completed: completed,
        ),
        const SizedBox(height: 12),
        ExpeditionPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: <Widget>[
                  Text(
                    context.l10n.homeSceneSteps(snapshot.dailySteps),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${snapshot.availableEnergy} ENERGY',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.walkingRpgPalette.energy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: snapshot.dailyProgress,
                minHeight: 3,
                borderRadius: BorderRadius.circular(4),
                semanticsLabel: context.l10n.homeTodayProgress(
                  snapshot.dailySteps, snapshot.dailyGoal,
                ),
              ),
            ],
          ),
        ),
        if (snapshot.petId == null ||
            snapshot.petSpecies == null ||
            snapshot.petEvolutionStage == null) ...<Widget>[
          const SizedBox(height: 12),
          ExpeditionBadge(
            key: const Key('home-active-companion-badge'),
            label: context.l10n.homeCompanionLevel(
              context.l10n.currentPetName(snapshot.petId, snapshot.petName),
              snapshot.petLevel,
            ),
            icon: Icons.pets_outlined,
            tone: ExpeditionPanelTone.resonance,
          ),
        ],
      ],
    );
  }
}

class _ExpeditionDetails extends StatelessWidget {
  const _ExpeditionDetails({
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
    final String expeditionName = context.l10n.currentExpeditionName(
      snapshot.expeditionId,
      snapshot.expeditionName,
    );
    final String currentNodeName = context.l10n.currentNodeName(
      snapshot.currentNodeId,
      snapshot.currentNodeName,
    );
    return ExpeditionPanel(
      key: const Key('home-expedition-details'),
      tone: ExpeditionPanelTone.lumen,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -82,
              right: -58,
              child: _ExpeditionGlowOrb(color: palette.resonance, size: 210),
            ),
            Positioned(
              bottom: -96,
              left: -70,
              child: _ExpeditionGlowOrb(color: palette.energy, size: 190),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    completed
                        ? context.l10n.homeJourneyCompleted(
                            snapshot.expeditionJourneyNumber,
                          )
                        : context.l10n.homeWaitingForSteps,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.homeWalkFirst,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
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
                    expeditionName: expeditionName,
                    availableEnergy: snapshot.availableEnergy,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.homeEnergyProgress(
                      snapshot.expeditionProgress,
                      snapshot.requiredEnergy,
                      currentNodeName,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.routeTrail.isNotEmpty) ...<Widget>[
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          context.l10n.expeditionRouteTrailTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        ExcludeSemantics(
                          child: Text(
                            key: const Key('home-discovered-route-node-count'),
                            context.l10n.homeDiscoveredRouteNodes(
                              snapshot.discoveredRouteNodeCount,
                            ),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ExpeditionRouteTrail(
                      nodes: snapshot.routeTrail
                          .map(
                            (
                              HomeExpeditionRouteNode node,
                            ) => ExpeditionRouteTrailNode(
                              nodeId: node.nodeId,
                              nodeName: context.l10n.currentNodeName(
                                node.nodeId,
                                node.nodeName,
                              ),
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
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ExpeditionProgressSignal(
                    expeditionId: snapshot.expeditionId,
                    progress: snapshot.expeditionProgress,
                    target: snapshot.requiredEnergy,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    completed
                        ? context.l10n.homeRouteCompleted
                        : context.l10n.homeEnergyToNextNode(
                            snapshot.remainingExpeditionEnergy,
                          ),
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: palette.energy),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpeditionVistaStage extends StatelessWidget {
  const _ExpeditionVistaStage({
    required this.snapshot,
    required this.scrollController,
    required this.expeditionName,
    required this.currentNodeName,
    required this.currentNodeId,
    required this.journeyNumber,
    required this.progress,
    required this.completed,
  });

  final String expeditionName;
  final HomeSnapshot snapshot;
  final ScrollController scrollController;
  final String currentNodeName;
  final String currentNodeId;
  final int journeyNumber;
  final double progress;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final double sceneHeight = MediaQuery.sizeOf(context).height < 740
        ? 290
        : 330;
    final Widget vista = ExpeditionCrewScene(
      key: const Key('home-crew-scene'),
      pilotName: context.l10n.currentPilotName(snapshot.pilotId, snapshot.pilotName),
      greetingLabel: context.l10n.homeGreetCrew,
      scrollController: scrollController,
      petId: snapshot.petId,
      petName: context.l10n.currentPetName(snapshot.petId, snapshot.petName),
      petSpecies: snapshot.petSpecies == null ? null : context.l10n.currentPetSpecies(
        snapshot.petId, snapshot.petSpecies!,
      ),
      petEvolutionStage: snapshot.petEvolutionStage,
      height: sceneHeight,
      background: ChapterVista(
        key: const Key('home-expedition-vista'),
        semanticLabel: '$expeditionName, $currentNodeName',
        progress: progress,
        height: sceneHeight,
        crewStage: true,
      ),
    );
    final Widget badges = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: <Widget>[
        ExpeditionBadge(
          key: const Key('home-expedition-journey-number'),
          label: context.l10n.homeJourneyNumber(journeyNumber),
          icon: Icons.route_outlined,
          tone: ExpeditionPanelTone.energy,
        ),
        ExpeditionNodeSignal(
          key: const Key('home-current-node-badge'),
          nodeId: currentNodeId,
          nodeName: currentNodeName,
          completed: completed,
        ),
      ],
    );
    final Widget routePlate = ExcludeSemantics(
      child: _ExpeditionRoutePlate(
        currentNodeName: currentNodeName,
        progress: progress,
        completed: completed,
      ),
    );

    return LayoutBuilder(
      key: const Key('home-expedition-visual-stage'),
      builder: (BuildContext context, BoxConstraints constraints) {
        if (_usesCompactHomeSection(context, constraints) ||
            _effectiveTextScale(context) > 1.5) {
          return Column(
            key: const Key('home-expedition-stage-compact'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              badges,
              const SizedBox(height: 10),
              vista,
              const SizedBox(height: 10),
              routePlate,
            ],
          );
        }
        return Column(
          key: const Key('home-expedition-stage-overlay'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            badges,
            const SizedBox(height: 10),
            vista,
            const SizedBox(height: 10),
            routePlate,
          ],
        );
      },
    );
  }
}

class _ExpeditionRoutePlate extends StatelessWidget {
  const _ExpeditionRoutePlate({
    required this.currentNodeName,
    required this.progress,
    required this.completed,
  });

  final String currentNodeName;
  final double progress;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.walkingRpgPalette.panelBorder.withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(
              completed ? Icons.flag_outlined : Icons.explore_outlined,
              size: 20,
              color: completed
                  ? context.walkingRpgPalette.resonance
                  : context.walkingRpgPalette.energy,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    currentNodeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.walkingRpgPalette.energy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpeditionGlowOrb extends StatelessWidget {
  const _ExpeditionGlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0),
            ],
          ),
        ),
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
    final String dailyProgressTitle = context.l10n.homeTodayProgress(
      snapshot.dailySteps,
      snapshot.dailyGoal,
    );
    final String dailyGoalFeedback = snapshot.dailyGoalReached
        ? context.l10n.homeDailyGoalReached
        : context.l10n.homeDailyGoalRemaining(snapshot.remainingDailySteps);
    final String? dailyGoalStability = snapshot.dailyGoalPolicy.isLegacy
        ? null
        : context.l10n.homeDailyGoalStability;
    final WeeklyActivityRhythm? weeklyRhythm = snapshot.weeklyActivityRhythm;
    final String? weeklyRhythmTitle = weeklyRhythm == null
        ? null
        : context.l10n.homeWeeklyRhythmProgress(
            weeklyRhythm.activeDays,
            weeklyRhythm.targetActiveDays,
          );
    final String? weeklyRhythmDetail = weeklyRhythm == null
        ? null
        : weeklyRhythm.targetReached
        ? context.l10n.homeWeeklyRhythmReached(weeklyRhythm.windowDays)
        : context.l10n.homeWeeklyRhythmRemaining(
            weeklyRhythm.remainingActiveDays,
            weeklyRhythm.windowDays,
          );
    final String? weeklyRhythmQualification = weeklyRhythm == null
        ? null
        : context.l10n.homeWeeklyRhythmQualification;
    final MaterialLocalizations materialLocalizations =
        MaterialLocalizations.of(context);
    final String? weeklyDateRange =
        weeklyRhythm == null || weeklyRhythm.days.isEmpty
        ? null
        : context.l10n.homeWeeklyRhythmDateRange(
            materialLocalizations.formatShortDate(weeklyRhythm.days.first.date),
            materialLocalizations.formatShortDate(weeklyRhythm.days.last.date),
          );
    final WeeklyActivityDay? weeklyToday = _findWeeklyToday(
      weeklyRhythm,
      snapshot.localDate,
    );
    final String? weeklyTodayStatus = weeklyToday == null
        ? null
        : weeklyToday.active
        ? context.l10n.homeWeeklyRhythmTodayActiveDay(
            materialLocalizations.formatShortDate(weeklyToday.date),
          )
        : context.l10n.homeWeeklyRhythmTodayRestDay(
            materialLocalizations.formatShortDate(weeklyToday.date),
          );
    final String? weeklyDaysSummary =
        weeklyRhythm == null || weeklyRhythm.days.isEmpty
        ? null
        : context.l10n.homeWeeklyRhythmDaysSummary(
            weeklyRhythm.days
                .map((WeeklyActivityDay day) {
                  final String date = materialLocalizations.formatShortDate(
                    day.date,
                  );
                  if (day.localDate == snapshot.localDate) {
                    return weeklyTodayStatus!;
                  }
                  return day.active
                      ? context.l10n.homeWeeklyRhythmActiveDay(date)
                      : context.l10n.homeWeeklyRhythmRestDay(date);
                })
                .join('; '),
          );
    final Widget ring = ExpeditionProgressRing(
      progress: snapshot.dailyProgress,
      value: '${(snapshot.dailyProgress * 100).round()}%',
      label: context.l10n.stepsLabel,
      size: 108,
    );
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          key: const Key('home-daily-goal-summary'),
          container: true,
          label: <String>[
            dailyProgressTitle,
            dailyGoalFeedback,
            if (dailyGoalStability != null) dailyGoalStability,
          ].join('. '),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  dailyProgressTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  dailyGoalFeedback,
                  key: const Key('home-daily-goal-feedback'),
                  style: snapshot.dailyGoalReached
                      ? Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: colors.primary)
                      : Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                ),
                if (dailyGoalStability != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    dailyGoalStability,
                    key: const Key('home-daily-goal-stability'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          activitySubtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (weeklyRhythm != null &&
            weeklyRhythmTitle != null &&
            weeklyRhythmDetail != null) ...<Widget>[
          const SizedBox(height: 14),
          Semantics(
            key: const Key('home-weekly-activity-rhythm'),
            container: true,
            label: <String>[
              weeklyRhythmTitle,
              weeklyRhythmDetail,
              if (weeklyRhythmQualification != null) weeklyRhythmQualification,
              if (weeklyDateRange != null) weeklyDateRange,
              if (weeklyDaysSummary != null) weeklyDaysSummary,
            ].join('. '),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    weeklyRhythmTitle,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      key: const Key('home-weekly-activity-rhythm-progress'),
                      value: weeklyRhythm.progress,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weeklyRhythmDetail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (weeklyRhythmQualification != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      weeklyRhythmQualification,
                      key: const Key('home-weekly-activity-qualification'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (weeklyDateRange != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      weeklyDateRange,
                      key: const Key('home-weekly-activity-date-range'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (weeklyTodayStatus != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      weeklyTodayStatus,
                      key: const Key('home-weekly-activity-today-status'),
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: colors.primary),
                    ),
                  ],
                  if (weeklyRhythm.days.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _WeeklyActivityDayTrail(
                      days: weeklyRhythm.days,
                      todayLocalDate: snapshot.localDate,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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

class _WeeklyActivityDayTrail extends StatelessWidget {
  const _WeeklyActivityDayTrail({
    required this.days,
    required this.todayLocalDate,
  });

  final List<WeeklyActivityDay> days;
  final String todayLocalDate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<String> narrowWeekdays = MaterialLocalizations.of(
      context,
    ).narrowWeekdays;

    return Wrap(
      key: const Key('home-weekly-activity-day-trail'),
      spacing: 4,
      runSpacing: 4,
      children: days
          .map((WeeklyActivityDay day) {
            final bool isToday = day.localDate == todayLocalDate;
            final Color foreground = day.active
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant;
            return Container(
              key: Key('home-weekly-activity-day-${day.localDate}'),
              width: 34,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              decoration: BoxDecoration(
                color: day.active
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: isToday
                    ? Border.all(color: colors.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    day.active ? Icons.directions_walk : Icons.bedtime_outlined,
                    color: foreground,
                    size: 15,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      narrowWeekdays[day.date.weekday % 7],
                      maxLines: 1,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

WeeklyActivityDay? _findWeeklyToday(
  WeeklyActivityRhythm? rhythm,
  String homeLocalDate,
) {
  if (rhythm == null) {
    return null;
  }
  for (final WeeklyActivityDay day in rhythm.days) {
    if (day.localDate == homeLocalDate) {
      return day;
    }
  }
  return null;
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
    final String pilotName = context.l10n.currentPilotName(
      snapshot.pilotId,
      snapshot.pilotName,
    );
    final String petName = context.l10n.currentPetName(
      snapshot.petId,
      snapshot.petName,
    );
    final String? petSpecies = snapshot.petSpecies == null
        ? null
        : context.l10n.currentPetSpecies(snapshot.petId, snapshot.petSpecies!);
    final bool hasCompanionPortrait =
        snapshot.petId != null &&
        petSpecies != null &&
        snapshot.petEvolutionStage != null;
    final bool hasPilotExperienceProgress = snapshot.hasPilotExperienceProgress;
    final Widget pilot = _CharacterCard(
      key: const Key('home-pilot-card'),
      label: context.l10n.homePilotLabel,
      name: pilotName,
      level: snapshot.pilotLevel,
      detail: hasPilotExperienceProgress
          ? context.l10n.homePilotExperienceProgress(
              snapshot.pilotCurrentExperience,
              snapshot.pilotNextLevelExperience,
              snapshot.remainingPilotExperience,
            )
          : 'XP ${snapshot.pilotCurrentExperience} / '
                '${snapshot.pilotNextLevelExperience}',
      progress: hasPilotExperienceProgress
          ? snapshot.pilotExperienceProgress
          : null,
      progressKey: const Key('home-pilot-experience-progress'),
      icon: Icons.person_outline,
      portrait: ExcludeSemantics(
        child: PilotPortrait(
          name: pilotName,
          size: 72,
        ),
      ),
    );
    final Widget pet = _CharacterCard(
      key: const Key('home-pet-card'),
      label: context.l10n.homePetLabel,
      name: petName,
      level: snapshot.petLevel,
      detail: snapshot.petEvolutionStage == null
          ? context.l10n.homePetBond(snapshot.petBond)
          : context.l10n.homePetBondStage(
              snapshot.petBond,
              context.l10n.companionStageName(snapshot.petEvolutionStage!),
            ),
      icon: Icons.pets_outlined,
      portrait: hasCompanionPortrait
          ? ExcludeSemantics(
              child: CompanionPortrait(
                key: const Key('home-team-companion-portrait'),
                petId: snapshot.petId!,
                name: petName,
                species: petSpecies,
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
    final String petName = context.l10n.currentPetName(petId, snapshot.petName);
    final String species = context.l10n.currentPetSpecies(
      petId,
      snapshot.petSpecies!,
    );
    final int evolutionStage = snapshot.petEvolutionStage!;

    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.homeActiveCompanion,
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
              label: context.l10n.homeCompanionLevel(
                petName,
                snapshot.petLevel,
              ),
              icon: Icons.pets_outlined,
              tone: ExpeditionPanelTone.resonance,
            ),
            ExpeditionBadge(
              label: context.l10n.companionFormLabel(evolutionStage),
              icon: Icons.auto_awesome_outlined,
              tone: evolutionStage > 0
                  ? ExpeditionPanelTone.resonance
                  : ExpeditionPanelTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.homeSpeciesBond(species, snapshot.petBond),
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
            details,
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
            context.l10n.homeAvailableEnergyState(
              snapshot.availableEnergy,
              snapshot.economyVersion,
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.homeExpeditionState(
              snapshot.expeditionVersion,
              snapshot.expeditionStatus,
            ),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.homeContentState(snapshot.contentVersion),
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
            fallbackSemanticLabel: context.l10n.eventCompletedScene(
              result.eventTitle,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.homeEventCompletedBadge,
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
              context.l10n.homePilotExperienceTotal(
                result.pilot.experienceGained,
                result.pilot.currentExperience,
              ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 8),
          ProgressionGainSignalLayout(
            kind: ProgressionGainKind.petBond,
            subjectId: result.pet.petId,
            child: Text(
              context.l10n.homePetBondTotal(
                result.pet.bondGained,
                result.pet.name,
                result.pet.bond,
              ),
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
              text: context.l10n.homeMaterialTotal(
                material.quantityGained,
                material.name,
                material.quantityAfter,
              ),
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
              context.l10n.eventNextNodeLabel,
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
                  ? context.l10n.homeAcknowledgeOffline
                  : acknowledging
                  ? context.l10n.homeSavingContinuation
                  : nextNode == null
                  ? context.l10n.homeFinishExpedition
                  : context.l10n.homeContinueToNode(nextNode.name),
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
    final String eventTitle = event.isResolved
        ? event.title
        : context.l10n.currentEventTitle(event.eventId, event.title);
    final String eventSummary = event.isResolved
        ? event.summary
        : context.l10n.currentEventSummary(event.eventId, event.summary);
    return ExpeditionPanel(
      tone: ExpeditionPanelTone.resonance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExpeditionBadge(
            label: event.isResolved
                ? context.l10n.homeEventResolvedStatus
                : context.l10n.homeEventOpenStatus,
            icon: Icons.auto_awesome_outlined,
            tone: ExpeditionPanelTone.resonance,
          ),
          const SizedBox(height: 12),
          ExpeditionEventScene(
            eventId: event.eventId,
            eventTitle: eventTitle,
            fallbackSemanticLabel: context.l10n.eventFallbackScene(eventTitle),
          ),
          const SizedBox(height: 14),
          Text(eventTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(eventSummary),
          if (event.isResolved) ...<Widget>[
            const SizedBox(height: 12),
            if (event.selectedChoiceId != null)
              EventChoiceSignalLayout(
                eventId: event.eventId,
                choiceId: event.selectedChoiceId!,
                child: Text(
                  event.selectedChoiceTitle ?? context.l10n.homeChoiceRecorded,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              )
            else
              Text(
                event.selectedChoiceTitle ?? context.l10n.homeChoiceRecorded,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            const SizedBox(height: 4),
            Text(
              event.outcomeTitle ?? context.l10n.homeEventResult,
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
                text: context.l10n.homeMaterialTotal(
                  event.materialReward!.quantityGained,
                  event.materialReward!.itemName,
                  event.materialReward!.quantityAfter,
                ),
              ),
            ],
          ] else ...<Widget>[
            const SizedBox(height: 12),
            if (event.availableChoiceCount > 0) ...<Widget>[
              Semantics(
                key: const Key('home-available-event-choices'),
                container: true,
                label: context.l10n.homeEventChoicesAvailable(
                  event.availableChoiceCount,
                ),
                excludeSemantics: true,
                child: Text(
                  context.l10n.homeEventChoicesAvailable(
                    event.availableChoiceCount,
                  ),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                    rewardText: _rewardText(context, choice),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.currentEventChoiceDescription(
                  event.eventId,
                  choice.choiceId,
                  choice.description,
                ),
              ),
              if (!choice.isAvailable &&
                  choice.requirement != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  context.l10n.currentEventRequirementDescription(
                    event.eventId,
                    choice.choiceId,
                    choice.requirement!.description,
                  ),
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

  String _rewardText(BuildContext context, HomeEventChoice choice) {
    final HomeMaterialRewardPreview? material = choice.materialReward;
    final String materialText = material == null
        ? ''
        : context.l10n.homeMaterialRewardSuffix(
            material.quantity,
            context.l10n.currentItemName(material.itemId, material.itemName),
          );
    return context.l10n.homeChoiceReward(
      choice.pilotExperienceReward,
      choice.petBondReward,
      materialText,
    );
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
    final String choiceTitle = context.l10n.currentEventChoiceTitle(
      eventId,
      choice.choiceId,
      choice.title,
    );
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(choiceTitle),
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
    required this.equippedSlotCount,
    required this.readOnly,
    required this.busy,
    required this.changing,
    required this.onUnequip,
  });

  final List<HomeEquipmentSlot> slots;
  final int equippedSlotCount;
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
          ExpeditionSectionTitle(
            title: context.l10n.homeEquipmentTitle,
            subtitle: context.l10n.homeEquipmentSubtitle,
            icon: Icons.explore_outlined,
          ),
          const SizedBox(height: 8),
          Semantics(
            key: const Key('home-equipped-slot-progress'),
            container: true,
            label: context.l10n.homeEquipmentSlotsEquipped(
              equippedSlotCount,
              slots.length,
            ),
            excludeSemantics: true,
            child: Text(
              context.l10n.homeEquipmentSlotsEquipped(
                equippedSlotCount,
                slots.length,
              ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 12),
          for (final HomeEquipmentSlot slot in slots) ...<Widget>[
            Text(
              context.l10n.currentEquipmentSlotName(slot.slotId, slot.name),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 2),
            Text(
              context.l10n.currentEquipmentSlotDescription(
                slot.slotId,
                slot.description,
              ),
            ),
            const SizedBox(height: 8),
            EquipmentMountSignal(
              slotId: slot.slotId,
              status: slot.status,
              itemId: slot.item?.itemId,
            ),
            const SizedBox(height: 10),
            if (slot.item == null)
              Text(context.l10n.homeEmptySlot)
            else
              _IllustratedItemIdentity(
                layoutKey: 'equipment-item-layout-${slot.slotId}',
                itemId: slot.item!.itemId,
                title: context.l10n.currentItemName(
                  slot.item!.itemId,
                  slot.item!.name,
                ),
                titleKey: Key('equipment-item-${slot.slotId}'),
                description: context.l10n.currentItemDescription(
                  slot.item!.itemId,
                  slot.item!.description,
                ),
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
                    label: Text(context.l10n.homeUnequip),
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
    required this.equippableItemCount,
    required this.readOnly,
    required this.busy,
    required this.changing,
    required this.onEquip,
  });

  final List<HomeInventoryItem> items;
  final int equippableItemCount;
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
          ExpeditionSectionTitle(
            title: context.l10n.homeInventoryTitle,
            subtitle: context.l10n.homeInventorySubtitle,
            icon: Icons.inventory_2_outlined,
          ),
          if (equippableItemCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Semantics(
              key: const Key('home-equippable-inventory-items'),
              container: true,
              label: context.l10n.homeInventoryItemsReadyToEquip(
                equippableItemCount,
              ),
              excludeSemantics: true,
              child: Text(
                context.l10n.homeInventoryItemsReadyToEquip(
                  equippableItemCount,
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final HomeInventoryItem item in items) ...<Widget>[
            _IllustratedItemIdentity(
              layoutKey: 'inventory-item-layout-${item.itemId}',
              itemId: item.itemId,
              title: item.isUnique
                  ? context.l10n.homeItemLevel(
                      context.l10n.currentItemName(item.itemId, item.name),
                      item.version,
                      item.rarity == null ? '' : ' · ${item.rarity}',
                    )
                  : context.l10n.homeItemQuantity(
                      context.l10n.currentItemName(item.itemId, item.name),
                      item.quantity,
                    ),
              description: context.l10n.currentItemDescription(
                item.itemId,
                item.description,
              ),
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
                          item.isEquipped
                              ? context.l10n.homeEquipped
                              : context.l10n.homeEquip,
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
    required this.craftableRecipeCount,
    required this.recipeViewportKey,
    required this.readOnly,
    required this.busy,
    required this.crafting,
    required this.onCraft,
  });

  final List<HomeCraftingRecipe> recipes;
  final int craftableRecipeCount;
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
          ExpeditionSectionTitle(
            title: context.l10n.homeCraftingTitle,
            subtitle: context.l10n.homeCraftingSubtitle,
            icon: Icons.handyman_outlined,
          ),
          if (craftableRecipeCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Semantics(
              key: const Key('home-craftable-recipes'),
              container: true,
              label: context.l10n.homeCraftingRecipesReady(
                craftableRecipeCount,
              ),
              excludeSemantics: true,
              child: Text(
                context.l10n.homeCraftingRecipesReady(craftableRecipeCount),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
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
    final String recipeName = context.l10n.currentRecipeName(
      recipe.recipeId,
      recipe.name,
    );
    final String recipeDescription = context.l10n.currentRecipeDescription(
      recipe.recipeId,
      recipe.description,
    );
    final String resultName = context.l10n.currentItemName(
      recipe.result.itemId,
      recipe.result.name,
    );
    final String resultDescription = context.l10n.currentItemDescription(
      recipe.result.itemId,
      recipe.result.description,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _IllustratedItemIdentity(
          layoutKey: 'crafting-result-layout-${recipe.result.itemId}',
          itemId: recipe.result.itemId,
          title: recipeName,
          description: recipeDescription,
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
            label: context.l10n.homeIngredientSemantics(
              context.l10n.currentItemName(ingredient.itemId, ingredient.name),
              ingredient.availableQuantity,
              ingredient.requiredQuantity,
              ingredient.isAvailable
                  ? context.l10n.homeEnoughMaterials
                  : context.l10n.homeMissingMaterials,
            ),
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  ExpeditionItemEmblem(itemId: ingredient.itemId, size: 38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.currentItemName(
                        ingredient.itemId,
                        ingredient.name,
                      ),
                    ),
                  ),
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
          context.l10n.homeCraftingResult(resultName),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 2),
        Text(resultDescription, style: Theme.of(context).textTheme.bodySmall),
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
                ? context.l10n.homeCraftUnavailableOffline
                : recipe.isCrafted
                ? context.l10n.homeItemAlreadyCrafted
                : recipe.canCraft
                ? context.l10n.homeCraftItem
                : context.l10n.homeMissingMaterials,
          ),
        ),
      ],
    );
  }
}

class _ItemUpgradeCard extends StatelessWidget {
  const _ItemUpgradeCard({
    required this.upgrades,
    required this.readyItemUpgradeCount,
    required this.readOnly,
    required this.busy,
    required this.upgrading,
    required this.onUpgrade,
  });

  final List<HomeItemUpgrade> upgrades;
  final int readyItemUpgradeCount;
  final bool readOnly;
  final bool busy;
  final bool upgrading;
  final ValueChanged<HomeItemUpgrade> onUpgrade;

  @override
  Widget build(BuildContext context) {
    return ExpeditionPanel(
      key: const Key('item-upgrade-card'),
      tone: ExpeditionPanelTone.resonance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExpeditionSectionTitle(
            title: context.l10n.homeEquipmentCalibrationTitle,
            subtitle: context.l10n.homeEquipmentCalibrationSubtitle,
            icon: Icons.auto_fix_high_outlined,
          ),
          if (readyItemUpgradeCount > 0) ...<Widget>[
            const SizedBox(height: 8),
            Semantics(
              key: const Key('home-ready-item-upgrades'),
              container: true,
              label: context.l10n.homeItemUpgradesReady(readyItemUpgradeCount),
              excludeSemantics: true,
              child: Text(
                context.l10n.homeItemUpgradesReady(readyItemUpgradeCount),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (int index = 0; index < upgrades.length; index++) ...<Widget>[
            _ItemUpgradeView(
              upgrade: upgrades[index],
              readOnly: readOnly,
              busy: busy,
              upgrading: upgrading,
              onUpgrade: () => onUpgrade(upgrades[index]),
            ),
            if (index + 1 < upgrades.length) const Divider(height: 28),
          ],
        ],
      ),
    );
  }
}

class _ItemUpgradeView extends StatelessWidget {
  const _ItemUpgradeView({
    required this.upgrade,
    required this.readOnly,
    required this.busy,
    required this.upgrading,
    required this.onUpgrade,
  });

  final HomeItemUpgrade upgrade;
  final bool readOnly;
  final bool busy;
  final bool upgrading;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final String upgradeName = context.l10n.currentUpgradeName(
      upgrade.upgradeId,
      upgrade.name,
    );
    final String upgradeDescription = context.l10n.currentUpgradeDescription(
      upgrade.upgradeId,
      upgrade.description,
    );
    final String actionLabel = readOnly
        ? context.l10n.homeUpgradeUnavailableOffline
        : upgrade.isCompleted
        ? context.l10n.homeUpgradeCompleted
        : upgrade.isLocked
        ? context.l10n.homeCraftItemFirst
        : upgrade.canApply
        ? context.l10n.homeUpgradeItem
        : context.l10n.homeMissingMaterials;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _IllustratedItemIdentity(
          layoutKey: 'item-upgrade-layout-${upgrade.upgradeId}',
          itemId: upgrade.targetItemId,
          title: upgradeName,
          description: upgradeDescription,
          highlighted: upgrade.canApply || upgrade.isCompleted,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Icon(Icons.tune_outlined, size: 20),
                Text(
                  context.l10n.homeLevelTransition(
                    upgrade.requiredLevel,
                    upgrade.resultingLevel,
                  ),
                ),
              ],
            ),
            Text('${upgrade.initialRarity} → ${upgrade.resultingRarity}'),
          ],
        ),
        const SizedBox(height: 12),
        for (final HomeItemUpgradeIngredient ingredient
            in upgrade.ingredients) ...<Widget>[
          Semantics(
            container: true,
            label: context.l10n.homeIngredientSemantics(
              context.l10n.currentItemName(ingredient.itemId, ingredient.name),
              ingredient.availableQuantity,
              ingredient.requiredQuantity,
              ingredient.isAvailable
                  ? context.l10n.homeEnoughMaterials
                  : context.l10n.homeMissingMaterials,
            ),
            child: ExcludeSemantics(
              child: Row(
                children: <Widget>[
                  ExpeditionItemEmblem(itemId: ingredient.itemId, size: 38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.currentItemName(
                        ingredient.itemId,
                        ingredient.name,
                      ),
                    ),
                  ),
                  Text(
                    '${ingredient.availableQuantity} / '
                    '${ingredient.requiredQuantity}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final VoidCallback? onPressed =
                readOnly || busy || !upgrade.canApply ? null : onUpgrade;
            if (constraints.maxWidth < 300) {
              return FilledButton.tonal(
                key: Key('item-upgrade-${upgrade.upgradeId}'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                onPressed: onPressed,
                child: Text(actionLabel, textAlign: TextAlign.center),
              );
            }
            return FilledButton.tonalIcon(
              key: Key('item-upgrade-${upgrade.upgradeId}'),
              onPressed: onPressed,
              icon: upgrading && upgrade.canApply
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      upgrade.isCompleted
                          ? Icons.check_circle_outline
                          : Icons.auto_fix_high_outlined,
                    ),
              label: Text(actionLabel),
            );
          },
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
  const _HomeError({required this.onRetry, required this.onOpenDemo});

  final VoidCallback onRetry;
  final VoidCallback onOpenDemo;

  @override
  Widget build(BuildContext context) {
    return ExpeditionReadState.failure(
      key: const Key('home-error-state'),
      title: context.l10n.homeLoadFailureTitle,
      message: context.l10n.homeLoadFailureMessage,
      details: null,
      primaryActionKey: const Key('home-error-retry'),
      primaryActionLabel: context.l10n.retryButton,
      onPrimaryAction: onRetry,
      secondaryActionKey: const Key('home-error-demo'),
      secondaryActionLabel: context.l10n.homeOpenDemo,
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
    this.progress,
    this.progressKey,
  });

  final String label;
  final String name;
  final int level;
  final String detail;
  final IconData icon;
  final Widget? portrait;
  final double? progress;
  final Key? progressKey;

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
          Text(context.l10n.homeLevel(level)),
          if (progress != null) ...<Widget>[
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  key: progressKey,
                  value: progress,
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ] else
            const SizedBox(height: 2),
          Semantics(
            container: true,
            label: detail,
            excludeSemantics: true,
            child: Text(
              detail,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
