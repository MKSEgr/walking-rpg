import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/home/domain/daily_goal_policy.dart';

class HomeSnapshot {
  const HomeSnapshot({
    required this.localDate,
    required this.timeZone,
    required this.dailySteps,
    required this.dailyGoal,
    required this.availableEnergy,
    required this.activityStateVersion,
    required this.economyVersion,
    required this.lastActivitySyncAt,
    required this.serverTime,
    required this.contentVersion,
    required this.expeditionId,
    required this.expeditionName,
    required this.currentNodeId,
    required this.currentNodeName,
    required this.expeditionProgress,
    required this.requiredEnergy,
    required this.expeditionStatus,
    required this.expeditionVersion,
    required this.unlockedEvent,
    required this.pilotName,
    required this.pilotLevel,
    required this.petName,
    required this.petLevel,
    this.pilotId,
    this.petId,
    this.petSpecies,
    this.petEvolutionStage,
    this.expeditionJourneyNumber = 1,
    this.routeTrail = const <HomeExpeditionRouteNode>[],
    this.decisionLog = const <HomeExpeditionDecisionLogEntry>[],
    this.completionRecap,
    this.recentJourneyRecaps = const <HomeExpeditionCompletionRecap>[],
    this.journeyChronicle,
    this.pilotCurrentExperience = 0,
    this.pilotNextLevelExperience = 0,
    this.petBond = 0,
    this.dailyGoalPolicy = const DailyGoalPolicy.legacy(),
    this.inventory = const <HomeInventoryItem>[],
    this.equipment = const <HomeEquipmentSlot>[],
    this.craftingRecipes = const <HomeCraftingRecipe>[],
    this.itemUpgrades = const <HomeItemUpgrade>[],
    this.pendingEventResult,
    this.cacheMetadata,
  });

  factory HomeSnapshot.fromJson(
    Map<String, dynamic> json, {
    CachedReadMetadata? cacheMetadata,
  }) {
    final int dailyGoal = _readInt(json, 'dailyGoal');
    final Object? dailyGoalPolicyJson = json['dailyGoalPolicy'];
    final DailyGoalPolicy dailyGoalPolicy = dailyGoalPolicyJson == null
        ? const DailyGoalPolicy.legacy()
        : DailyGoalPolicy.fromJson(
            _asMap(dailyGoalPolicyJson, 'dailyGoalPolicy'),
          );
    dailyGoalPolicy.validateGoal(dailyGoal);
    final Map<String, dynamic> pilot = _readMap(json, 'pilot');
    final Map<String, dynamic> pet = _readMap(json, 'pet');
    final int? petEvolutionStage = _readOptionalInt(pet, 'evolutionStage');
    if (petEvolutionStage != null && petEvolutionStage < 0) {
      throw const FormatException(
        'evolutionStage должен быть неотрицательным целым числом',
      );
    }
    final Map<String, dynamic> expedition = _readMap(json, 'expedition');
    final int expeditionJourneyNumber = expedition['journeyNumber'] == null
        ? 1
        : _readInt(expedition, 'journeyNumber');
    if (expeditionJourneyNumber <= 0) {
      throw const FormatException('journeyNumber должен быть положительным');
    }
    final String expeditionStatus = _readString(expedition, 'status');
    final Object? completionRecapJson = expedition['completionRecap'];
    final HomeExpeditionCompletionRecap? completionRecap =
        completionRecapJson == null
        ? null
        : HomeExpeditionCompletionRecap.fromJson(
            _asMap(completionRecapJson, 'completionRecap'),
          );
    if (completionRecap != null && expeditionStatus != 'COMPLETED') {
      throw const FormatException(
        'completionRecap допустим только для завершённого похода',
      );
    }
    if (completionRecap != null &&
        completionRecap.journeyNumber != expeditionJourneyNumber) {
      throw const FormatException(
        'completionRecap должен относиться к текущему походу',
      );
    }
    final List<HomeExpeditionCompletionRecap> recentJourneyRecaps =
        _readRecentJourneyRecaps(expedition['recentJourneyRecaps']);
    int previousJourneyNumber = expeditionJourneyNumber;
    for (final HomeExpeditionCompletionRecap recap in recentJourneyRecaps) {
      if (recap.journeyNumber >= previousJourneyNumber) {
        throw const FormatException(
          'recentJourneyRecaps должны содержать прошлые походы '
          'в убывающем порядке',
        );
      }
      previousJourneyNumber = recap.journeyNumber;
    }
    final Object? journeyChronicleJson = expedition['journeyChronicle'];
    final HomeJourneyChronicle? journeyChronicle = journeyChronicleJson == null
        ? null
        : HomeJourneyChronicle.fromJson(
            _asMap(journeyChronicleJson, 'journeyChronicle'),
          );
    final Object? eventJson = expedition['unlockedEvent'];
    final Object? pendingEventResultJson = json['pendingEventResult'];

    return HomeSnapshot(
      localDate: _readString(json, 'localDate'),
      timeZone: _readNullableString(json, 'timeZone'),
      dailySteps: _readInt(json, 'dailySteps'),
      dailyGoal: dailyGoal,
      dailyGoalPolicy: dailyGoalPolicy,
      availableEnergy: _readInt(json, 'availableEnergy'),
      activityStateVersion: _readInt(json, 'activityStateVersion'),
      economyVersion: _readInt(json, 'economyVersion'),
      lastActivitySyncAt: _readNullableString(json, 'lastActivitySyncAt'),
      serverTime: _readString(json, 'serverTime'),
      contentVersion: _readString(json, 'contentVersion'),
      expeditionId: _readString(expedition, 'expeditionId'),
      expeditionName: _readString(expedition, 'name'),
      currentNodeId: _readString(expedition, 'currentNodeId'),
      currentNodeName: _readString(expedition, 'currentNode'),
      expeditionProgress: _readInt(expedition, 'progress'),
      requiredEnergy: _readInt(expedition, 'requiredEnergy'),
      expeditionStatus: expeditionStatus,
      expeditionVersion: _readInt(expedition, 'version'),
      expeditionJourneyNumber: expeditionJourneyNumber,
      routeTrail: _readRouteTrail(expedition['routeTrail']),
      decisionLog: _readDecisionLog(expedition['decisionLog']),
      completionRecap: completionRecap,
      recentJourneyRecaps: recentJourneyRecaps,
      journeyChronicle: journeyChronicle,
      unlockedEvent: eventJson == null
          ? null
          : HomeExpeditionEvent.fromJson(_asMap(eventJson, 'unlockedEvent')),
      pilotId: _readOptionalString(pilot, 'pilotId'),
      pilotName: _readString(pilot, 'name'),
      pilotLevel: _readInt(pilot, 'level'),
      pilotCurrentExperience: _readInt(pilot, 'currentExperience'),
      pilotNextLevelExperience: _readInt(pilot, 'nextLevelExperience'),
      petId: _readOptionalString(pet, 'petId'),
      petName: _readString(pet, 'name'),
      petSpecies: _readOptionalString(pet, 'species'),
      petLevel: _readInt(pet, 'level'),
      petBond: _readInt(pet, 'bond'),
      petEvolutionStage: petEvolutionStage,
      inventory: _readInventory(json['inventory']),
      equipment: _readEquipment(json['equipment']),
      craftingRecipes: _readCraftingRecipes(json['craftingRecipes']),
      itemUpgrades: _readItemUpgrades(json['itemUpgrades']),
      pendingEventResult: pendingEventResultJson == null
          ? null
          : PendingEventResult.fromJson(
              _asMap(pendingEventResultJson, 'pendingEventResult'),
            ),
      cacheMetadata: cacheMetadata,
    );
  }

  final String localDate;
  final String? timeZone;
  final int dailySteps;
  final int dailyGoal;
  final DailyGoalPolicy dailyGoalPolicy;
  final int availableEnergy;
  final int activityStateVersion;
  final int economyVersion;
  final String? lastActivitySyncAt;
  final String serverTime;
  final String contentVersion;
  final String expeditionId;
  final String expeditionName;
  final String currentNodeId;
  final String currentNodeName;
  final int expeditionProgress;
  final int requiredEnergy;
  final String expeditionStatus;
  final int expeditionVersion;
  final int expeditionJourneyNumber;
  final List<HomeExpeditionRouteNode> routeTrail;
  final List<HomeExpeditionDecisionLogEntry> decisionLog;
  final HomeExpeditionCompletionRecap? completionRecap;
  final List<HomeExpeditionCompletionRecap> recentJourneyRecaps;
  final HomeJourneyChronicle? journeyChronicle;
  final HomeExpeditionEvent? unlockedEvent;
  final String? pilotId;
  final String pilotName;
  final int pilotLevel;
  final int pilotCurrentExperience;
  final int pilotNextLevelExperience;
  final String? petId;
  final String petName;
  final String? petSpecies;
  final int petLevel;
  final int petBond;
  final int? petEvolutionStage;
  final List<HomeInventoryItem> inventory;
  final List<HomeEquipmentSlot> equipment;
  final List<HomeCraftingRecipe> craftingRecipes;
  final List<HomeItemUpgrade> itemUpgrades;
  final PendingEventResult? pendingEventResult;
  final CachedReadMetadata? cacheMetadata;

  bool get isCached => cacheMetadata != null;

  int get remainingExpeditionEnergy {
    final int remaining = requiredEnergy - expeditionProgress;
    return remaining < 0 ? 0 : remaining;
  }

  int get spendableEnergy {
    if (expeditionStatus != 'IN_PROGRESS') {
      return 0;
    }
    return availableEnergy < remainingExpeditionEnergy
        ? availableEnergy
        : remainingExpeditionEnergy;
  }

  double get dailyProgress {
    if (dailyGoal <= 0) {
      return 0;
    }
    return (dailySteps / dailyGoal).clamp(0.0, 1.0).toDouble();
  }

  double get expeditionProgressValue {
    if (requiredEnergy <= 0) {
      return 0;
    }
    return (expeditionProgress / requiredEnergy).clamp(0.0, 1.0).toDouble();
  }

  static const HomeSnapshot demo = HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'UTC',
    dailySteps: 0,
    dailyGoal: 6000,
    dailyGoalPolicy: DailyGoalPolicy(
      policyVersion: 'adaptive-median-v1',
      source: 'DEFAULT',
      baselineSteps: null,
      sampleDays: 0,
      lookbackDays: 7,
      minimumSampleDays: 3,
      defaultGoal: 6000,
      growthPercent: 5,
      roundingStep: 250,
      minimumGoal: 2000,
      maximumGoal: 12000,
    ),
    availableEnergy: 0,
    activityStateVersion: 0,
    economyVersion: 0,
    lastActivitySyncAt: null,
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v2',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    expeditionProgress: 0,
    requiredEnergy: 30,
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 0,
    unlockedEvent: null,
    pilotId: 'navigator-v1',
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 20,
    pilotNextLevelExperience: 100,
    petId: 'spark-v1',
    petName: 'Искра',
    petSpecies: 'Люмин',
    petLevel: 1,
    petBond: 10,
    petEvolutionStage: 0,
    routeTrail: <HomeExpeditionRouteNode>[
      HomeExpeditionRouteNode(
        nodeId: 'outer-beacon',
        nodeName: 'Внешний маяк',
        state: 'CURRENT',
      ),
    ],
  );

  static List<HomeExpeditionRouteNode> _readRouteTrail(Object? raw) {
    if (raw == null) {
      return const <HomeExpeditionRouteNode>[];
    }
    if (raw is! List<dynamic>) {
      throw const FormatException('routeTrail должен быть JSON-массивом');
    }
    return raw
        .map(
          (Object? value) =>
              HomeExpeditionRouteNode.fromJson(_asMap(value, 'routeTrail[]')),
        )
        .toList(growable: false);
  }

  static List<HomeExpeditionDecisionLogEntry> _readDecisionLog(Object? raw) {
    if (raw == null) {
      return const <HomeExpeditionDecisionLogEntry>[];
    }
    if (raw is! List<dynamic>) {
      throw const FormatException('decisionLog должен быть JSON-массивом');
    }
    return raw
        .map(
          (Object? value) => HomeExpeditionDecisionLogEntry.fromJson(
            _asMap(value, 'decisionLog[]'),
          ),
        )
        .toList(growable: false);
  }

  static List<HomeExpeditionCompletionRecap> _readRecentJourneyRecaps(
    Object? raw,
  ) {
    if (raw == null) {
      return const <HomeExpeditionCompletionRecap>[];
    }
    if (raw is! List<dynamic>) {
      throw const FormatException(
        'recentJourneyRecaps должен быть JSON-массивом',
      );
    }
    return raw
        .map(
          (Object? value) => HomeExpeditionCompletionRecap.fromJson(
            _asMap(value, 'recentJourneyRecaps[]'),
          ),
        )
        .toList(growable: false);
  }

  static List<HomeInventoryItem> _readInventory(Object? raw) {
    if (raw == null) {
      return const <HomeInventoryItem>[];
    }
    if (raw is! List<dynamic>) {
      throw const FormatException('inventory должен быть JSON-массивом');
    }
    return raw
        .map(
          (Object? value) =>
              HomeInventoryItem.fromJson(_asMap(value, 'inventory[]')),
        )
        .toList(growable: false);
  }

  static List<HomeCraftingRecipe> _readCraftingRecipes(Object? raw) {
    if (raw == null) {
      return const <HomeCraftingRecipe>[];
    }
    if (raw is! List<dynamic>) {
      throw const FormatException('craftingRecipes должен быть JSON-массивом');
    }
    return raw
        .map(
          (Object? value) =>
              HomeCraftingRecipe.fromJson(_asMap(value, 'craftingRecipes[]')),
        )
        .toList(growable: false);
  }

  static List<HomeItemUpgrade> _readItemUpgrades(Object? raw) {
    if (raw == null) {
      return const <HomeItemUpgrade>[];
    }
    if (raw is! List<dynamic>) {
      throw const FormatException('itemUpgrades должен быть JSON-массивом');
    }
    return raw
        .map(
          (Object? value) =>
              HomeItemUpgrade.fromJson(_asMap(value, 'itemUpgrades[]')),
        )
        .toList(growable: false);
  }

  static List<HomeEquipmentSlot> _readEquipment(Object? raw) {
    if (raw == null) {
      return const <HomeEquipmentSlot>[];
    }
    if (raw is! List<dynamic>) {
      throw const FormatException('equipment должен быть JSON-массивом');
    }
    return raw
        .map(
          (Object? value) =>
              HomeEquipmentSlot.fromJson(_asMap(value, 'equipment[]')),
        )
        .toList(growable: false);
  }

  static int _readInt(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value is int) {
      return value;
    }
    if (value is num && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw FormatException('$field должен быть целым числом');
  }

  static int? _readOptionalInt(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field)) {
      return null;
    }
    return _readInt(json, field);
  }

  static Map<String, dynamic> _readMap(
    Map<String, dynamic> json,
    String field,
  ) {
    return _asMap(json[field], field);
  }

  static String? _readNullableString(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw FormatException('$field должен быть строкой или null');
  }

  static String? _readOptionalString(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field)) {
      return null;
    }
    return _readString(json, field);
  }

  static String _readString(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('$field должен быть непустой строкой');
  }
}

class HomeExpeditionRouteNode {
  const HomeExpeditionRouteNode({
    required this.nodeId,
    required this.nodeName,
    required this.state,
    this.decision,
  });

  factory HomeExpeditionRouteNode.fromJson(Map<String, dynamic> json) {
    final String state = HomeSnapshot._readString(json, 'state');
    if (!const <String>{'VISITED', 'CURRENT', 'COMPLETED'}.contains(state)) {
      throw FormatException('Неизвестное состояние routeTrail: $state');
    }
    final Object? decisionJson = json['decision'];
    return HomeExpeditionRouteNode(
      nodeId: HomeSnapshot._readString(json, 'nodeId'),
      nodeName: HomeSnapshot._readString(json, 'nodeName'),
      state: state,
      decision: decisionJson == null
          ? null
          : HomeExpeditionRouteDecision.fromJson(
              _asMap(decisionJson, 'routeTrail[].decision'),
            ),
    );
  }

  final String nodeId;
  final String nodeName;
  final String state;
  final HomeExpeditionRouteDecision? decision;

  bool get isVisited => state == 'VISITED';
  bool get isCurrent => state == 'CURRENT';
  bool get isCompleted => state == 'COMPLETED';
}

class HomeExpeditionRouteDecision {
  const HomeExpeditionRouteDecision({
    required this.choiceId,
    required this.choiceTitle,
    required this.outcomeTitle,
  });

  factory HomeExpeditionRouteDecision.fromJson(Map<String, dynamic> json) {
    return HomeExpeditionRouteDecision(
      choiceId: HomeSnapshot._readString(json, 'choiceId'),
      choiceTitle: HomeSnapshot._readString(json, 'choiceTitle'),
      outcomeTitle: HomeSnapshot._readString(json, 'outcomeTitle'),
    );
  }

  final String choiceId;
  final String choiceTitle;
  final String outcomeTitle;
}

class HomeExpeditionDecisionLogEntry {
  const HomeExpeditionDecisionLogEntry({
    required this.eventId,
    required this.eventTitle,
    required this.choiceId,
    required this.choiceTitle,
    required this.outcomeTitle,
    required this.outcomeSummary,
    required this.resolvedAt,
    this.pilotExperienceGained = 0,
    this.petId,
    this.petName,
    this.petBondGained = 0,
    this.materialReward,
  });

  factory HomeExpeditionDecisionLogEntry.fromJson(
    Map<String, dynamic> json, {
    String field = 'decisionLog[]',
  }) {
    final String resolvedAt = HomeSnapshot._readString(json, 'resolvedAt');
    if (DateTime.tryParse(resolvedAt) == null) {
      throw FormatException('$field.resolvedAt должен быть ISO-8601 датой');
    }
    final int pilotExperienceGained = json['pilotExperienceGained'] == null
        ? 0
        : HomeSnapshot._readInt(json, 'pilotExperienceGained');
    final int petBondGained = json['petBondGained'] == null
        ? 0
        : HomeSnapshot._readInt(json, 'petBondGained');
    if (pilotExperienceGained < 0 || petBondGained < 0) {
      throw const FormatException(
        'Награда решения не может быть отрицательной',
      );
    }
    final String? petId = HomeSnapshot._readNullableString(json, 'petId');
    final String? petName = HomeSnapshot._readNullableString(json, 'petName');
    if ((petId == null) != (petName == null) ||
        (petBondGained > 0 && petName == null)) {
      throw const FormatException('Награда связи должна указывать питомца');
    }
    final Object? materialJson = json['materialReward'];
    return HomeExpeditionDecisionLogEntry(
      eventId: HomeSnapshot._readString(json, 'eventId'),
      eventTitle: HomeSnapshot._readString(json, 'eventTitle'),
      choiceId: HomeSnapshot._readString(json, 'choiceId'),
      choiceTitle: HomeSnapshot._readString(json, 'choiceTitle'),
      outcomeTitle: HomeSnapshot._readString(json, 'outcomeTitle'),
      outcomeSummary: HomeSnapshot._readString(json, 'outcomeSummary'),
      resolvedAt: resolvedAt,
      pilotExperienceGained: pilotExperienceGained,
      petId: petId,
      petName: petName,
      petBondGained: petBondGained,
      materialReward: materialJson == null
          ? null
          : HomeJourneyMaterialReward.fromJson(
              _asMap(materialJson, '$field.materialReward'),
            ),
    );
  }

  final String eventId;
  final String eventTitle;
  final String choiceId;
  final String choiceTitle;
  final String outcomeTitle;
  final String outcomeSummary;
  final String resolvedAt;
  final int pilotExperienceGained;
  final String? petId;
  final String? petName;
  final int petBondGained;
  final HomeJourneyMaterialReward? materialReward;

  bool get hasRewards =>
      pilotExperienceGained > 0 || petBondGained > 0 || materialReward != null;
}

class HomeJourneyChronicle {
  const HomeJourneyChronicle({
    required this.completedJourneyCount,
    required this.decisionCount,
    required this.pilotExperienceGained,
    required this.petBondGained,
    this.totalDurationSeconds,
    this.longestDurationSeconds,
    this.longestJourneyNumber,
    this.averageDurationSeconds,
    this.pilotExperienceRewards = const <HomeJourneyPilotExperienceReward>[],
    this.petBondRewards = const <HomeJourneyPetBondReward>[],
    this.materials = const <HomeJourneyMaterialReward>[],
    this.decisionOutcomes = const <HomeJourneyDecisionOutcome>[],
    this.finaleOutcomes = const <HomeJourneyFinaleOutcome>[],
  });

  factory HomeJourneyChronicle.fromJson(Map<String, dynamic> json) {
    final int completedJourneyCount = HomeSnapshot._readInt(
      json,
      'completedJourneyCount',
    );
    final int decisionCount = HomeSnapshot._readInt(json, 'decisionCount');
    final int pilotExperienceGained = HomeSnapshot._readInt(
      json,
      'pilotExperienceGained',
    );
    final int petBondGained = HomeSnapshot._readInt(json, 'petBondGained');
    final int? totalDurationSeconds = HomeSnapshot._readOptionalInt(
      json,
      'totalDurationSeconds',
    );
    final int? longestDurationSeconds = HomeSnapshot._readOptionalInt(
      json,
      'longestDurationSeconds',
    );
    final int? longestJourneyNumber = HomeSnapshot._readOptionalInt(
      json,
      'longestJourneyNumber',
    );
    final int? averageDurationSeconds = HomeSnapshot._readOptionalInt(
      json,
      'averageDurationSeconds',
    );
    if (completedJourneyCount <= 0 ||
        decisionCount < 0 ||
        (totalDurationSeconds != null && totalDurationSeconds < 0) ||
        (longestDurationSeconds != null &&
            (totalDurationSeconds == null ||
                longestDurationSeconds < 0 ||
                longestDurationSeconds > totalDurationSeconds)) ||
        (longestJourneyNumber != null &&
            (longestDurationSeconds == null ||
                longestJourneyNumber <= 0 ||
                longestJourneyNumber > completedJourneyCount)) ||
        (averageDurationSeconds != null &&
            (totalDurationSeconds == null ||
                averageDurationSeconds < 0 ||
                averageDurationSeconds !=
                    totalDurationSeconds ~/ completedJourneyCount)) ||
        pilotExperienceGained < 0 ||
        petBondGained < 0) {
      throw const FormatException(
        'Летопись походов содержит недопустимое значение',
      );
    }
    final Object? pilotExperienceRewardsJson = json['pilotExperienceRewards'];
    final List<HomeJourneyPilotExperienceReward> pilotExperienceRewards;
    if (pilotExperienceRewardsJson == null) {
      pilotExperienceRewards = const <HomeJourneyPilotExperienceReward>[];
    } else {
      if (pilotExperienceRewardsJson is! List<dynamic>) {
        throw const FormatException(
          'journeyChronicle.pilotExperienceRewards должен быть JSON-массивом',
        );
      }
      pilotExperienceRewards = pilotExperienceRewardsJson
          .map(
            (Object? value) => HomeJourneyPilotExperienceReward.fromJson(
              _asMap(value, 'journeyChronicle.pilotExperienceRewards[]'),
            ),
          )
          .toList(growable: false);
      final Set<String> pilotIdentities = <String>{};
      int experienceTotal = 0;
      for (final HomeJourneyPilotExperienceReward reward
          in pilotExperienceRewards) {
        final String identity = '${reward.pilotId}\u0000${reward.pilotName}';
        if (!pilotIdentities.add(identity)) {
          throw const FormatException(
            'journeyChronicle.pilotExperienceRewards содержит повтор',
          );
        }
        experienceTotal += reward.experienceGained;
      }
      if (experienceTotal != pilotExperienceGained) {
        throw const FormatException(
          'journeyChronicle.pilotExperienceRewards не совпадает с общим итогом',
        );
      }
    }
    final Object? petBondRewardsJson = json['petBondRewards'];
    final List<HomeJourneyPetBondReward> petBondRewards;
    if (petBondRewardsJson == null) {
      petBondRewards = const <HomeJourneyPetBondReward>[];
    } else {
      if (petBondRewardsJson is! List<dynamic>) {
        throw const FormatException(
          'journeyChronicle.petBondRewards должен быть JSON-массивом',
        );
      }
      petBondRewards = petBondRewardsJson
          .map(
            (Object? value) => HomeJourneyPetBondReward.fromJson(
              _asMap(value, 'journeyChronicle.petBondRewards[]'),
            ),
          )
          .toList(growable: false);
      final Set<String> petIdentities = <String>{};
      int bondTotal = 0;
      for (final HomeJourneyPetBondReward reward in petBondRewards) {
        final String identity = '${reward.petId}\u0000${reward.petName}';
        if (!petIdentities.add(identity)) {
          throw const FormatException(
            'journeyChronicle.petBondRewards содержит повтор',
          );
        }
        bondTotal += reward.bondGained;
      }
      if (bondTotal != petBondGained) {
        throw const FormatException(
          'journeyChronicle.petBondRewards не совпадает с общим итогом',
        );
      }
    }
    final Object? materialsJson = json['materials'];
    final List<HomeJourneyMaterialReward> materials;
    if (materialsJson == null) {
      materials = const <HomeJourneyMaterialReward>[];
    } else {
      if (materialsJson is! List<dynamic>) {
        throw const FormatException(
          'journeyChronicle.materials должен быть JSON-массивом',
        );
      }
      materials = materialsJson
          .map(
            (Object? value) => HomeJourneyMaterialReward.fromJson(
              _asMap(value, 'journeyChronicle.materials[]'),
            ),
          )
          .toList(growable: false);
      final Set<String> materialIdentities = <String>{};
      for (final HomeJourneyMaterialReward material in materials) {
        final String identity = '${material.itemId}\u0000${material.itemName}';
        if (!materialIdentities.add(identity)) {
          throw const FormatException(
            'journeyChronicle.materials содержит повтор',
          );
        }
      }
    }
    final Object? decisionOutcomesJson = json['decisionOutcomes'];
    final List<HomeJourneyDecisionOutcome> decisionOutcomes;
    if (decisionOutcomesJson == null) {
      decisionOutcomes = const <HomeJourneyDecisionOutcome>[];
    } else {
      if (decisionOutcomesJson is! List<dynamic>) {
        throw const FormatException(
          'journeyChronicle.decisionOutcomes должен быть JSON-массивом',
        );
      }
      decisionOutcomes = decisionOutcomesJson
          .map(
            (Object? value) => HomeJourneyDecisionOutcome.fromJson(
              _asMap(value, 'journeyChronicle.decisionOutcomes[]'),
            ),
          )
          .toList(growable: false);
      final Set<String> decisionIdentities = <String>{};
      int breakdownDecisionCount = 0;
      for (final HomeJourneyDecisionOutcome outcome in decisionOutcomes) {
        final String identity = <String>[
          outcome.eventId,
          outcome.eventTitle,
          outcome.choiceId,
          outcome.choiceTitle,
          outcome.outcomeTitle,
        ].join('\u0000');
        if (!decisionIdentities.add(identity)) {
          throw const FormatException(
            'journeyChronicle.decisionOutcomes содержит повтор',
          );
        }
        breakdownDecisionCount += outcome.decisionCount;
      }
      if (breakdownDecisionCount != decisionCount) {
        throw const FormatException(
          'journeyChronicle.decisionOutcomes не совпадает с числом решений',
        );
      }
    }
    final Object? finaleOutcomesJson = json['finaleOutcomes'];
    final List<HomeJourneyFinaleOutcome> finaleOutcomes;
    if (finaleOutcomesJson == null) {
      finaleOutcomes = const <HomeJourneyFinaleOutcome>[];
    } else {
      if (finaleOutcomesJson is! List<dynamic>) {
        throw const FormatException(
          'journeyChronicle.finaleOutcomes должен быть JSON-массивом',
        );
      }
      finaleOutcomes = finaleOutcomesJson
          .map(
            (Object? value) => HomeJourneyFinaleOutcome.fromJson(
              _asMap(value, 'journeyChronicle.finaleOutcomes[]'),
            ),
          )
          .toList(growable: false);
      final Set<String> finaleIdentities = <String>{};
      int finaleJourneyCount = 0;
      for (final HomeJourneyFinaleOutcome outcome in finaleOutcomes) {
        final String identity = <String>[
          outcome.eventId,
          outcome.eventTitle,
          outcome.choiceId,
          outcome.choiceTitle,
          outcome.outcomeTitle,
        ].join('\u0000');
        if (!finaleIdentities.add(identity)) {
          throw const FormatException(
            'journeyChronicle.finaleOutcomes содержит повтор',
          );
        }
        finaleJourneyCount += outcome.journeyCount;
      }
      if (finaleJourneyCount != completedJourneyCount) {
        throw const FormatException(
          'journeyChronicle.finaleOutcomes не совпадает с числом походов',
        );
      }
    }
    return HomeJourneyChronicle(
      completedJourneyCount: completedJourneyCount,
      decisionCount: decisionCount,
      totalDurationSeconds: totalDurationSeconds,
      longestDurationSeconds: longestDurationSeconds,
      longestJourneyNumber: longestJourneyNumber,
      averageDurationSeconds: averageDurationSeconds,
      pilotExperienceGained: pilotExperienceGained,
      petBondGained: petBondGained,
      pilotExperienceRewards: pilotExperienceRewards,
      petBondRewards: petBondRewards,
      materials: materials,
      decisionOutcomes: decisionOutcomes,
      finaleOutcomes: finaleOutcomes,
    );
  }

  final int completedJourneyCount;
  final int decisionCount;
  final int? totalDurationSeconds;
  final int? longestDurationSeconds;
  final int? longestJourneyNumber;
  final int? averageDurationSeconds;
  final int pilotExperienceGained;
  final int petBondGained;
  final List<HomeJourneyPilotExperienceReward> pilotExperienceRewards;
  final List<HomeJourneyPetBondReward> petBondRewards;
  final List<HomeJourneyMaterialReward> materials;
  final List<HomeJourneyDecisionOutcome> decisionOutcomes;
  final List<HomeJourneyFinaleOutcome> finaleOutcomes;
}

class HomeExpeditionCompletionRecap {
  const HomeExpeditionCompletionRecap({
    required this.journeyNumber,
    required this.decisionCount,
    required this.pilotExperienceGained,
    required this.petBondGained,
    required this.materials,
    this.finalDecision,
    this.durationSeconds,
    this.decisions = const <HomeExpeditionDecisionLogEntry>[],
    this.pilotExperienceRewards = const <HomeJourneyPilotExperienceReward>[],
    this.petBondRewards = const <HomeJourneyPetBondReward>[],
  });

  factory HomeExpeditionCompletionRecap.fromJson(Map<String, dynamic> json) {
    final int journeyNumber = HomeSnapshot._readInt(json, 'journeyNumber');
    final int decisionCount = HomeSnapshot._readInt(json, 'decisionCount');
    final int pilotExperienceGained = HomeSnapshot._readInt(
      json,
      'pilotExperienceGained',
    );
    final int petBondGained = HomeSnapshot._readInt(json, 'petBondGained');
    if (journeyNumber <= 0 ||
        decisionCount < 0 ||
        pilotExperienceGained < 0 ||
        petBondGained < 0) {
      throw const FormatException(
        'Итог завершённого похода содержит отрицательное значение',
      );
    }
    final Object? finalDecisionJson = json['finalDecision'];
    final HomeJourneyFinalDecision? finalDecision = finalDecisionJson == null
        ? null
        : HomeJourneyFinalDecision.fromJson(
            _asMap(finalDecisionJson, 'completionRecap.finalDecision'),
          );
    if (finalDecision != null && decisionCount == 0) {
      throw const FormatException(
        'finalDecision требует хотя бы одного решения',
      );
    }
    final int? durationSeconds = HomeSnapshot._readOptionalInt(
      json,
      'durationSeconds',
    );
    if (durationSeconds != null &&
        (durationSeconds < 0 || finalDecision == null)) {
      throw const FormatException(
        'completionRecap.durationSeconds требует финальное решение и не может быть отрицательным',
      );
    }
    final Object? decisionsJson = json['decisions'];
    final List<HomeExpeditionDecisionLogEntry> decisions;
    if (decisionsJson == null) {
      decisions = const <HomeExpeditionDecisionLogEntry>[];
    } else {
      if (decisionsJson is! List<dynamic>) {
        throw const FormatException(
          'completionRecap.decisions должен быть JSON-массивом',
        );
      }
      decisions = decisionsJson
          .map(
            (Object? value) => HomeExpeditionDecisionLogEntry.fromJson(
              _asMap(value, 'completionRecap.decisions[]'),
              field: 'completionRecap.decisions[]',
            ),
          )
          .toList(growable: false);
      if (decisions.length != decisionCount) {
        throw const FormatException(
          'completionRecap.decisions не совпадает с decisionCount',
        );
      }
      if (decisions.isNotEmpty &&
          !_matchesFinalDecision(decisions.last, finalDecision)) {
        throw const FormatException(
          'completionRecap.decisions не совпадает с finalDecision',
        );
      }
    }
    final Object? pilotExperienceRewardsJson = json['pilotExperienceRewards'];
    final List<HomeJourneyPilotExperienceReward> pilotExperienceRewards;
    if (pilotExperienceRewardsJson == null) {
      pilotExperienceRewards = const <HomeJourneyPilotExperienceReward>[];
    } else {
      if (pilotExperienceRewardsJson is! List<dynamic>) {
        throw const FormatException(
          'completionRecap.pilotExperienceRewards должен быть JSON-массивом',
        );
      }
      pilotExperienceRewards = pilotExperienceRewardsJson
          .map(
            (Object? value) => HomeJourneyPilotExperienceReward.fromJson(
              _asMap(value, 'completionRecap.pilotExperienceRewards[]'),
            ),
          )
          .toList(growable: false);
      final Set<String> pilotIdentities = <String>{};
      int experienceTotal = 0;
      for (final HomeJourneyPilotExperienceReward reward
          in pilotExperienceRewards) {
        final String identity = '${reward.pilotId}\u0000${reward.pilotName}';
        if (!pilotIdentities.add(identity)) {
          throw const FormatException(
            'completionRecap.pilotExperienceRewards содержит повтор',
          );
        }
        experienceTotal += reward.experienceGained;
      }
      if (experienceTotal != pilotExperienceGained) {
        throw const FormatException(
          'completionRecap.pilotExperienceRewards не совпадает с общим итогом',
        );
      }
    }
    final Object? petBondRewardsJson = json['petBondRewards'];
    final List<HomeJourneyPetBondReward> petBondRewards;
    if (petBondRewardsJson == null) {
      petBondRewards = const <HomeJourneyPetBondReward>[];
    } else {
      if (petBondRewardsJson is! List<dynamic>) {
        throw const FormatException(
          'completionRecap.petBondRewards должен быть JSON-массивом',
        );
      }
      petBondRewards = petBondRewardsJson
          .map(
            (Object? value) => HomeJourneyPetBondReward.fromJson(
              _asMap(value, 'completionRecap.petBondRewards[]'),
            ),
          )
          .toList(growable: false);
      final Set<String> petIdentities = <String>{};
      int bondTotal = 0;
      for (final HomeJourneyPetBondReward reward in petBondRewards) {
        final String identity = '${reward.petId}\u0000${reward.petName}';
        if (!petIdentities.add(identity)) {
          throw const FormatException(
            'completionRecap.petBondRewards содержит повтор',
          );
        }
        bondTotal += reward.bondGained;
      }
      if (bondTotal != petBondGained) {
        throw const FormatException(
          'completionRecap.petBondRewards не совпадает с общим итогом',
        );
      }
    }
    final Object? materialsJson = json['materials'];
    if (materialsJson is! List<dynamic>) {
      throw const FormatException(
        'completionRecap.materials должен быть JSON-массивом',
      );
    }
    final List<HomeJourneyMaterialReward> materials = materialsJson
        .map(
          (Object? value) => HomeJourneyMaterialReward.fromJson(
            _asMap(value, 'completionRecap.materials[]'),
          ),
        )
        .toList(growable: false);
    final Set<String> identities = <String>{};
    for (final HomeJourneyMaterialReward material in materials) {
      final String identity = '${material.itemId}\u0000${material.itemName}';
      if (!identities.add(identity)) {
        throw const FormatException(
          'completionRecap.materials содержит повтор',
        );
      }
    }
    return HomeExpeditionCompletionRecap(
      journeyNumber: journeyNumber,
      decisionCount: decisionCount,
      finalDecision: finalDecision,
      durationSeconds: durationSeconds,
      decisions: decisions,
      pilotExperienceGained: pilotExperienceGained,
      pilotExperienceRewards: pilotExperienceRewards,
      petBondGained: petBondGained,
      petBondRewards: petBondRewards,
      materials: materials,
    );
  }

  final int journeyNumber;
  final int decisionCount;
  final HomeJourneyFinalDecision? finalDecision;
  final int? durationSeconds;
  final List<HomeExpeditionDecisionLogEntry> decisions;
  final int pilotExperienceGained;
  final List<HomeJourneyPilotExperienceReward> pilotExperienceRewards;
  final int petBondGained;
  final List<HomeJourneyPetBondReward> petBondRewards;
  final List<HomeJourneyMaterialReward> materials;

  bool get hasRewards =>
      pilotExperienceGained > 0 || petBondGained > 0 || materials.isNotEmpty;

  static bool _matchesFinalDecision(
    HomeExpeditionDecisionLogEntry decision,
    HomeJourneyFinalDecision? finalDecision,
  ) {
    return finalDecision != null &&
        decision.eventId == finalDecision.eventId &&
        decision.eventTitle == finalDecision.eventTitle &&
        decision.choiceId == finalDecision.choiceId &&
        decision.choiceTitle == finalDecision.choiceTitle &&
        decision.outcomeTitle == finalDecision.outcomeTitle &&
        decision.outcomeSummary == finalDecision.outcomeSummary &&
        decision.resolvedAt == finalDecision.resolvedAt;
  }
}

class HomeJourneyFinalDecision {
  const HomeJourneyFinalDecision({
    required this.eventId,
    required this.eventTitle,
    required this.choiceId,
    required this.choiceTitle,
    required this.outcomeTitle,
    required this.outcomeSummary,
    required this.resolvedAt,
  });

  factory HomeJourneyFinalDecision.fromJson(Map<String, dynamic> json) {
    final String resolvedAt = HomeSnapshot._readString(json, 'resolvedAt');
    if (DateTime.tryParse(resolvedAt) == null) {
      throw const FormatException(
        'finalDecision.resolvedAt должен быть ISO-8601 датой',
      );
    }
    return HomeJourneyFinalDecision(
      eventId: HomeSnapshot._readString(json, 'eventId'),
      eventTitle: HomeSnapshot._readString(json, 'eventTitle'),
      choiceId: HomeSnapshot._readString(json, 'choiceId'),
      choiceTitle: HomeSnapshot._readString(json, 'choiceTitle'),
      outcomeTitle: HomeSnapshot._readString(json, 'outcomeTitle'),
      outcomeSummary: HomeSnapshot._readString(json, 'outcomeSummary'),
      resolvedAt: resolvedAt,
    );
  }

  final String eventId;
  final String eventTitle;
  final String choiceId;
  final String choiceTitle;
  final String outcomeTitle;
  final String outcomeSummary;
  final String resolvedAt;
}

class HomeJourneyFinaleOutcome {
  const HomeJourneyFinaleOutcome({
    required this.eventId,
    required this.eventTitle,
    required this.choiceId,
    required this.choiceTitle,
    required this.outcomeTitle,
    required this.journeyCount,
  });

  factory HomeJourneyFinaleOutcome.fromJson(Map<String, dynamic> json) {
    final int journeyCount = HomeSnapshot._readInt(json, 'journeyCount');
    if (journeyCount <= 0) {
      throw const FormatException(
        'Количество походов с финалом должно быть положительным',
      );
    }
    return HomeJourneyFinaleOutcome(
      eventId: HomeSnapshot._readString(json, 'eventId'),
      eventTitle: HomeSnapshot._readString(json, 'eventTitle'),
      choiceId: HomeSnapshot._readString(json, 'choiceId'),
      choiceTitle: HomeSnapshot._readString(json, 'choiceTitle'),
      outcomeTitle: HomeSnapshot._readString(json, 'outcomeTitle'),
      journeyCount: journeyCount,
    );
  }

  final String eventId;
  final String eventTitle;
  final String choiceId;
  final String choiceTitle;
  final String outcomeTitle;
  final int journeyCount;
}

class HomeJourneyDecisionOutcome {
  const HomeJourneyDecisionOutcome({
    required this.eventId,
    required this.eventTitle,
    required this.choiceId,
    required this.choiceTitle,
    required this.outcomeTitle,
    required this.decisionCount,
  });

  factory HomeJourneyDecisionOutcome.fromJson(Map<String, dynamic> json) {
    final int decisionCount = HomeSnapshot._readInt(json, 'decisionCount');
    if (decisionCount <= 0) {
      throw const FormatException(
        'Количество решений с исходом должно быть положительным',
      );
    }
    return HomeJourneyDecisionOutcome(
      eventId: HomeSnapshot._readString(json, 'eventId'),
      eventTitle: HomeSnapshot._readString(json, 'eventTitle'),
      choiceId: HomeSnapshot._readString(json, 'choiceId'),
      choiceTitle: HomeSnapshot._readString(json, 'choiceTitle'),
      outcomeTitle: HomeSnapshot._readString(json, 'outcomeTitle'),
      decisionCount: decisionCount,
    );
  }

  final String eventId;
  final String eventTitle;
  final String choiceId;
  final String choiceTitle;
  final String outcomeTitle;
  final int decisionCount;
}

class HomeJourneyPilotExperienceReward {
  const HomeJourneyPilotExperienceReward({
    required this.pilotId,
    required this.pilotName,
    required this.experienceGained,
  });

  factory HomeJourneyPilotExperienceReward.fromJson(Map<String, dynamic> json) {
    final int experienceGained = HomeSnapshot._readInt(
      json,
      'experienceGained',
    );
    if (experienceGained <= 0) {
      throw const FormatException(
        'Количество опыта пилота должно быть положительным',
      );
    }
    return HomeJourneyPilotExperienceReward(
      pilotId: HomeSnapshot._readString(json, 'pilotId'),
      pilotName: HomeSnapshot._readString(json, 'pilotName'),
      experienceGained: experienceGained,
    );
  }

  final String pilotId;
  final String pilotName;
  final int experienceGained;
}

class HomeJourneyPetBondReward {
  const HomeJourneyPetBondReward({
    required this.petId,
    required this.petName,
    required this.bondGained,
  });

  factory HomeJourneyPetBondReward.fromJson(Map<String, dynamic> json) {
    final int bondGained = HomeSnapshot._readInt(json, 'bondGained');
    if (bondGained <= 0) {
      throw const FormatException(
        'Количество связи питомца должно быть положительным',
      );
    }
    return HomeJourneyPetBondReward(
      petId: HomeSnapshot._readString(json, 'petId'),
      petName: HomeSnapshot._readString(json, 'petName'),
      bondGained: bondGained,
    );
  }

  final String petId;
  final String petName;
  final int bondGained;
}

class HomeJourneyMaterialReward {
  const HomeJourneyMaterialReward({
    required this.itemId,
    required this.itemName,
    required this.quantity,
  });

  factory HomeJourneyMaterialReward.fromJson(Map<String, dynamic> json) {
    final int quantity = HomeSnapshot._readInt(json, 'quantity');
    if (quantity <= 0) {
      throw const FormatException(
        'Количество material reward должно быть положительным',
      );
    }
    return HomeJourneyMaterialReward(
      itemId: HomeSnapshot._readString(json, 'itemId'),
      itemName: HomeSnapshot._readString(json, 'itemName'),
      quantity: quantity,
    );
  }

  final String itemId;
  final String itemName;
  final int quantity;
}

class HomeExpeditionEvent {
  const HomeExpeditionEvent({
    required this.eventId,
    required this.title,
    required this.summary,
    required this.status,
    this.choices = const <HomeEventChoice>[],
    this.selectedChoiceId,
    this.selectedChoiceTitle,
    this.outcomeTitle,
    this.outcomeSummary,
    this.materialReward,
  });

  factory HomeExpeditionEvent.fromJson(Map<String, dynamic> json) {
    final List<HomeEventChoice> availableChoices = _readChoices(
      json['choices'],
      'choices',
    );
    final List<HomeEventChoice> lockedChoices = _readChoices(
      json['lockedChoices'],
      'lockedChoices',
    );
    final Object? materialJson = json['materialReward'];

    return HomeExpeditionEvent(
      eventId: HomeSnapshot._readString(json, 'eventId'),
      title: HomeSnapshot._readString(json, 'title'),
      summary: HomeSnapshot._readString(json, 'summary'),
      status: HomeSnapshot._readString(json, 'status'),
      choices: <HomeEventChoice>[...availableChoices, ...lockedChoices],
      selectedChoiceId: HomeSnapshot._readNullableString(
        json,
        'selectedChoiceId',
      ),
      selectedChoiceTitle: HomeSnapshot._readNullableString(
        json,
        'selectedChoiceTitle',
      ),
      outcomeTitle: HomeSnapshot._readNullableString(json, 'outcomeTitle'),
      outcomeSummary: HomeSnapshot._readNullableString(json, 'outcomeSummary'),
      materialReward: materialJson == null
          ? null
          : HomeMaterialReward.fromJson(_asMap(materialJson, 'materialReward')),
    );
  }

  final String eventId;
  final String title;
  final String summary;
  final String status;
  final List<HomeEventChoice> choices;
  final String? selectedChoiceId;
  final String? selectedChoiceTitle;
  final String? outcomeTitle;
  final String? outcomeSummary;
  final HomeMaterialReward? materialReward;

  bool get isResolved => status == 'RESOLVED';

  static List<HomeEventChoice> _readChoices(Object? raw, String field) {
    if (raw == null) {
      return const <HomeEventChoice>[];
    }
    if (raw is! List<dynamic>) {
      throw FormatException('$field должен быть JSON-массивом');
    }
    return raw
        .map(
          (Object? value) =>
              HomeEventChoice.fromJson(_asMap(value, '$field[]')),
        )
        .toList(growable: false);
  }
}

class HomeEventChoice {
  const HomeEventChoice({
    required this.choiceId,
    required this.title,
    required this.description,
    required this.pilotExperienceReward,
    required this.petBondReward,
    this.materialReward,
    this.availability = 'AVAILABLE',
    this.requirement,
  });

  factory HomeEventChoice.fromJson(Map<String, dynamic> json) {
    final Object? materialJson = json['materialReward'];
    final String availability = json['availability'] == null
        ? 'AVAILABLE'
        : HomeSnapshot._readString(json, 'availability');
    if (availability != 'AVAILABLE' && availability != 'LOCKED') {
      throw FormatException('Неизвестная доступность choice: $availability');
    }
    final Object? requirementJson = json['requirement'];
    return HomeEventChoice(
      choiceId: HomeSnapshot._readString(json, 'choiceId'),
      title: HomeSnapshot._readString(json, 'title'),
      description: HomeSnapshot._readString(json, 'description'),
      pilotExperienceReward: HomeSnapshot._readInt(
        json,
        'pilotExperienceReward',
      ),
      petBondReward: HomeSnapshot._readInt(json, 'petBondReward'),
      materialReward: materialJson == null
          ? null
          : HomeMaterialRewardPreview.fromJson(
              _asMap(materialJson, 'materialReward'),
            ),
      availability: availability,
      requirement: requirementJson == null
          ? null
          : HomeChoiceRequirement.fromJson(
              _asMap(requirementJson, 'choice.requirement'),
            ),
    );
  }

  final String choiceId;
  final String title;
  final String description;
  final int pilotExperienceReward;
  final int petBondReward;
  final HomeMaterialRewardPreview? materialReward;
  final String availability;
  final HomeChoiceRequirement? requirement;

  bool get isAvailable => availability == 'AVAILABLE';
}

class HomeChoiceRequirement {
  const HomeChoiceRequirement({
    required this.type,
    required this.slotId,
    required this.slotName,
    required this.itemId,
    required this.itemName,
    required this.description,
    this.minimumUpgradeLevel = 1,
    this.minimumEvolutionStage = 0,
  });

  factory HomeChoiceRequirement.fromJson(Map<String, dynamic> json) {
    final int minimumUpgradeLevel = json['minimumUpgradeLevel'] == null
        ? 1
        : HomeSnapshot._readInt(json, 'minimumUpgradeLevel');
    if (minimumUpgradeLevel <= 0) {
      throw const FormatException(
        'minimumUpgradeLevel должен быть положительным',
      );
    }
    final int minimumEvolutionStage = json['minimumEvolutionStage'] == null
        ? 0
        : HomeSnapshot._readInt(json, 'minimumEvolutionStage');
    if (minimumEvolutionStage < 0) {
      throw const FormatException(
        'minimumEvolutionStage не может быть отрицательной',
      );
    }
    return HomeChoiceRequirement(
      type: HomeSnapshot._readString(json, 'type'),
      slotId: HomeSnapshot._readString(json, 'slotId'),
      slotName: HomeSnapshot._readString(json, 'slotName'),
      itemId: HomeSnapshot._readString(json, 'itemId'),
      itemName: HomeSnapshot._readString(json, 'itemName'),
      description: HomeSnapshot._readString(json, 'description'),
      minimumUpgradeLevel: minimumUpgradeLevel,
      minimumEvolutionStage: minimumEvolutionStage,
    );
  }

  final String type;
  final String slotId;
  final String slotName;
  final String itemId;
  final String itemName;
  final String description;
  final int minimumUpgradeLevel;
  final int minimumEvolutionStage;
}

class HomeMaterialRewardPreview {
  const HomeMaterialRewardPreview({
    required this.itemId,
    required this.itemName,
    required this.quantity,
  });

  factory HomeMaterialRewardPreview.fromJson(Map<String, dynamic> json) {
    return HomeMaterialRewardPreview(
      itemId: HomeSnapshot._readString(json, 'itemId'),
      itemName: HomeSnapshot._readString(json, 'itemName'),
      quantity: HomeSnapshot._readInt(json, 'quantity'),
    );
  }

  final String itemId;
  final String itemName;
  final int quantity;
}

class HomeMaterialReward {
  const HomeMaterialReward({
    required this.itemId,
    required this.itemName,
    required this.description,
    required this.quantityGained,
    required this.quantityAfter,
    required this.version,
  });

  factory HomeMaterialReward.fromJson(Map<String, dynamic> json) {
    return HomeMaterialReward(
      itemId: HomeSnapshot._readString(json, 'itemId'),
      itemName: HomeSnapshot._readString(json, 'itemName'),
      description: HomeSnapshot._readString(json, 'description'),
      quantityGained: HomeSnapshot._readInt(json, 'quantityGained'),
      quantityAfter: HomeSnapshot._readInt(json, 'quantityAfter'),
      version: HomeSnapshot._readInt(json, 'version'),
    );
  }

  final String itemId;
  final String itemName;
  final String description;
  final int quantityGained;
  final int quantityAfter;
  final int version;
}

class HomeInventoryItem {
  const HomeInventoryItem({
    required this.itemId,
    required this.name,
    required this.description,
    required this.quantity,
    required this.version,
    this.kind = 'MATERIAL',
    this.itemInstanceId,
    this.equippableSlotId,
    this.equippedSlotId,
    this.rarity,
  });

  factory HomeInventoryItem.fromJson(Map<String, dynamic> json) {
    return HomeInventoryItem(
      itemId: HomeSnapshot._readString(json, 'itemId'),
      name: HomeSnapshot._readString(json, 'name'),
      description: HomeSnapshot._readString(json, 'description'),
      quantity: HomeSnapshot._readInt(json, 'quantity'),
      version: HomeSnapshot._readInt(json, 'version'),
      kind: json['kind'] == null
          ? 'MATERIAL'
          : HomeSnapshot._readString(json, 'kind'),
      itemInstanceId: HomeSnapshot._readNullableString(json, 'itemInstanceId'),
      equippableSlotId: HomeSnapshot._readNullableString(
        json,
        'equippableSlotId',
      ),
      equippedSlotId: HomeSnapshot._readNullableString(json, 'equippedSlotId'),
      rarity: HomeSnapshot._readNullableString(json, 'rarity'),
    );
  }

  final String itemId;
  final String name;
  final String description;
  final int quantity;
  final int version;
  final String kind;
  final String? itemInstanceId;
  final String? equippableSlotId;
  final String? equippedSlotId;
  final String? rarity;

  bool get isUnique => kind == 'UNIQUE';
  bool get isEquippable => itemInstanceId != null && equippableSlotId != null;
  bool get isEquipped => equippedSlotId != null;
}

class HomeItemUpgrade {
  const HomeItemUpgrade({
    required this.upgradeId,
    required this.upgradeVersion,
    required this.name,
    required this.description,
    required this.status,
    required this.targetItemId,
    required this.targetItemName,
    required this.requiredLevel,
    required this.resultingLevel,
    required this.initialRarity,
    required this.resultingRarity,
    required this.ingredients,
  });

  factory HomeItemUpgrade.fromJson(Map<String, dynamic> json) {
    final String status = HomeSnapshot._readString(json, 'status');
    if (status != 'LOCKED' &&
        status != 'MISSING_MATERIALS' &&
        status != 'READY' &&
        status != 'COMPLETED') {
      throw FormatException('Неизвестный item upgrade status: $status');
    }
    final Object? rawIngredients = json['ingredients'];
    if (rawIngredients is! List<dynamic> || rawIngredients.isEmpty) {
      throw const FormatException(
        'item upgrade ingredients должен быть непустым массивом',
      );
    }
    return HomeItemUpgrade(
      upgradeId: HomeSnapshot._readString(json, 'upgradeId'),
      upgradeVersion: HomeSnapshot._readString(json, 'upgradeVersion'),
      name: HomeSnapshot._readString(json, 'name'),
      description: HomeSnapshot._readString(json, 'description'),
      status: status,
      targetItemId: HomeSnapshot._readString(json, 'targetItemId'),
      targetItemName: HomeSnapshot._readString(json, 'targetItemName'),
      requiredLevel: HomeSnapshot._readInt(json, 'requiredLevel'),
      resultingLevel: HomeSnapshot._readInt(json, 'resultingLevel'),
      initialRarity: HomeSnapshot._readString(json, 'initialRarity'),
      resultingRarity: HomeSnapshot._readString(json, 'resultingRarity'),
      ingredients: rawIngredients
          .map(
            (Object? value) => HomeItemUpgradeIngredient.fromJson(
              _asMap(value, 'itemUpgrades[].ingredients[]'),
            ),
          )
          .toList(growable: false),
    );
  }

  final String upgradeId;
  final String upgradeVersion;
  final String name;
  final String description;
  final String status;
  final String targetItemId;
  final String targetItemName;
  final int requiredLevel;
  final int resultingLevel;
  final String initialRarity;
  final String resultingRarity;
  final List<HomeItemUpgradeIngredient> ingredients;

  bool get canApply => status == 'READY';
  bool get isCompleted => status == 'COMPLETED';
  bool get isLocked => status == 'LOCKED';
}

class HomeItemUpgradeIngredient {
  const HomeItemUpgradeIngredient({
    required this.itemId,
    required this.name,
    required this.requiredQuantity,
    required this.availableQuantity,
  });

  factory HomeItemUpgradeIngredient.fromJson(Map<String, dynamic> json) {
    return HomeItemUpgradeIngredient(
      itemId: HomeSnapshot._readString(json, 'itemId'),
      name: HomeSnapshot._readString(json, 'name'),
      requiredQuantity: HomeSnapshot._readInt(json, 'requiredQuantity'),
      availableQuantity: HomeSnapshot._readInt(json, 'availableQuantity'),
    );
  }

  final String itemId;
  final String name;
  final int requiredQuantity;
  final int availableQuantity;

  bool get isAvailable => availableQuantity >= requiredQuantity;
}

class HomeEquipmentSlot {
  const HomeEquipmentSlot({
    required this.slotId,
    required this.name,
    required this.description,
    required this.status,
    required this.version,
    this.item,
  });

  factory HomeEquipmentSlot.fromJson(Map<String, dynamic> json) {
    final String status = HomeSnapshot._readString(json, 'status');
    if (status != 'EMPTY' && status != 'EQUIPPED') {
      throw FormatException('Неизвестный equipment status: $status');
    }
    final Object? itemJson = json['item'];
    final HomeEquipmentItem? item = itemJson == null
        ? null
        : HomeEquipmentItem.fromJson(_asMap(itemJson, 'equipment[].item'));
    if ((status == 'EQUIPPED') != (item != null)) {
      throw const FormatException(
        'Equipment status и item должны быть согласованы',
      );
    }
    return HomeEquipmentSlot(
      slotId: HomeSnapshot._readString(json, 'slotId'),
      name: HomeSnapshot._readString(json, 'name'),
      description: HomeSnapshot._readString(json, 'description'),
      status: status,
      version: HomeSnapshot._readInt(json, 'version'),
      item: item,
    );
  }

  final String slotId;
  final String name;
  final String description;
  final String status;
  final int version;
  final HomeEquipmentItem? item;

  bool get isEquipped => status == 'EQUIPPED';
}

class HomeEquipmentItem {
  const HomeEquipmentItem({
    required this.itemInstanceId,
    required this.itemId,
    required this.name,
    required this.description,
  });

  factory HomeEquipmentItem.fromJson(Map<String, dynamic> json) {
    return HomeEquipmentItem(
      itemInstanceId: HomeSnapshot._readString(json, 'itemInstanceId'),
      itemId: HomeSnapshot._readString(json, 'itemId'),
      name: HomeSnapshot._readString(json, 'name'),
      description: HomeSnapshot._readString(json, 'description'),
    );
  }

  final String itemInstanceId;
  final String itemId;
  final String name;
  final String description;
}

class HomeCraftingRecipe {
  const HomeCraftingRecipe({
    required this.recipeId,
    required this.recipeVersion,
    required this.name,
    required this.description,
    required this.status,
    required this.ingredients,
    required this.result,
  });

  factory HomeCraftingRecipe.fromJson(Map<String, dynamic> json) {
    final Object? rawIngredients = json['ingredients'];
    if (rawIngredients is! List<dynamic> || rawIngredients.isEmpty) {
      throw const FormatException(
        'crafting recipe ingredients должен быть непустым массивом',
      );
    }
    final String status = HomeSnapshot._readString(json, 'status');
    if (status != 'READY' &&
        status != 'MISSING_MATERIALS' &&
        status != 'CRAFTED') {
      throw FormatException('Неизвестный crafting status: $status');
    }
    return HomeCraftingRecipe(
      recipeId: HomeSnapshot._readString(json, 'recipeId'),
      recipeVersion: HomeSnapshot._readString(json, 'recipeVersion'),
      name: HomeSnapshot._readString(json, 'name'),
      description: HomeSnapshot._readString(json, 'description'),
      status: status,
      ingredients: rawIngredients
          .map(
            (Object? value) => HomeCraftingIngredient.fromJson(
              _asMap(value, 'craftingRecipes[].ingredients[]'),
            ),
          )
          .toList(growable: false),
      result: HomeCraftingResultPreview.fromJson(
        _asMap(json['result'], 'craftingRecipes[].result'),
      ),
    );
  }

  final String recipeId;
  final String recipeVersion;
  final String name;
  final String description;
  final String status;
  final List<HomeCraftingIngredient> ingredients;
  final HomeCraftingResultPreview result;

  bool get canCraft => status == 'READY';
  bool get isCrafted => status == 'CRAFTED';
}

class HomeCraftingIngredient {
  const HomeCraftingIngredient({
    required this.itemId,
    required this.name,
    required this.requiredQuantity,
    required this.availableQuantity,
  });

  factory HomeCraftingIngredient.fromJson(Map<String, dynamic> json) {
    return HomeCraftingIngredient(
      itemId: HomeSnapshot._readString(json, 'itemId'),
      name: HomeSnapshot._readString(json, 'name'),
      requiredQuantity: HomeSnapshot._readInt(json, 'requiredQuantity'),
      availableQuantity: HomeSnapshot._readInt(json, 'availableQuantity'),
    );
  }

  final String itemId;
  final String name;
  final int requiredQuantity;
  final int availableQuantity;

  bool get isAvailable => availableQuantity >= requiredQuantity;
}

class HomeCraftingResultPreview {
  const HomeCraftingResultPreview({
    required this.itemId,
    required this.name,
    required this.description,
    required this.kind,
  });

  factory HomeCraftingResultPreview.fromJson(Map<String, dynamic> json) {
    return HomeCraftingResultPreview(
      itemId: HomeSnapshot._readString(json, 'itemId'),
      name: HomeSnapshot._readString(json, 'name'),
      description: HomeSnapshot._readString(json, 'description'),
      kind: HomeSnapshot._readString(json, 'kind'),
    );
  }

  final String itemId;
  final String name;
  final String description;
  final String kind;
}

class PendingEventResult {
  const PendingEventResult({
    required this.receiptId,
    required this.eventId,
    required this.eventTitle,
    required this.choiceId,
    required this.choiceTitle,
    required this.outcomeTitle,
    required this.outcomeSummary,
    required this.pilot,
    required this.pet,
    required this.resolvedAt,
    this.material,
    this.nextNode,
  });

  factory PendingEventResult.fromJson(Map<String, dynamic> json) {
    final Object? materialJson = json['material'];
    final Object? nextNodeJson = json['nextNode'];
    return PendingEventResult(
      receiptId: HomeSnapshot._readString(json, 'receiptId'),
      eventId: HomeSnapshot._readString(json, 'eventId'),
      eventTitle: HomeSnapshot._readString(json, 'eventTitle'),
      choiceId: HomeSnapshot._readString(json, 'choiceId'),
      choiceTitle: HomeSnapshot._readString(json, 'choiceTitle'),
      outcomeTitle: HomeSnapshot._readString(json, 'outcomeTitle'),
      outcomeSummary: HomeSnapshot._readString(json, 'outcomeSummary'),
      pilot: EventPilotReward.fromJson(HomeSnapshot._readMap(json, 'pilot')),
      pet: EventPetReward.fromJson(HomeSnapshot._readMap(json, 'pet')),
      material: materialJson == null
          ? null
          : EventMaterialReward.fromJson(
              _asMap(materialJson, 'pendingEventResult.material'),
            ),
      nextNode: nextNodeJson == null
          ? null
          : EventNextNode.fromJson(
              _asMap(nextNodeJson, 'pendingEventResult.nextNode'),
            ),
      resolvedAt: HomeSnapshot._readString(json, 'resolvedAt'),
    );
  }

  final String receiptId;
  final String eventId;
  final String eventTitle;
  final String choiceId;
  final String choiceTitle;
  final String outcomeTitle;
  final String outcomeSummary;
  final EventPilotReward pilot;
  final EventPetReward pet;
  final EventMaterialReward? material;
  final EventNextNode? nextNode;
  final String resolvedAt;
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('$field должен быть JSON-объектом');
}
