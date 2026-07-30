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
    this.pilotCurrentExperience = 0,
    this.pilotNextLevelExperience = 0,
    this.petBond = 0,
    this.dailyGoalPolicy = const DailyGoalPolicy.legacy(),
    this.inventory = const <HomeInventoryItem>[],
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
    final Map<String, dynamic> expedition = _readMap(json, 'expedition');
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
      expeditionStatus: _readString(expedition, 'status'),
      expeditionVersion: _readInt(expedition, 'version'),
      unlockedEvent: eventJson == null
          ? null
          : HomeExpeditionEvent.fromJson(_asMap(eventJson, 'unlockedEvent')),
      pilotName: _readString(pilot, 'name'),
      pilotLevel: _readInt(pilot, 'level'),
      pilotCurrentExperience: _readInt(pilot, 'currentExperience'),
      pilotNextLevelExperience: _readInt(pilot, 'nextLevelExperience'),
      petName: _readString(pet, 'name'),
      petLevel: _readInt(pet, 'level'),
      petBond: _readInt(pet, 'bond'),
      inventory: _readInventory(json['inventory']),
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
  final HomeExpeditionEvent? unlockedEvent;
  final String pilotName;
  final int pilotLevel;
  final int pilotCurrentExperience;
  final int pilotNextLevelExperience;
  final String petName;
  final int petLevel;
  final int petBond;
  final List<HomeInventoryItem> inventory;
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
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    expeditionProgress: 0,
    requiredEnergy: 30,
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 0,
    unlockedEvent: null,
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 20,
    pilotNextLevelExperience: 100,
    petName: 'Искра',
    petLevel: 1,
    petBond: 10,
  );

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

  static String _readString(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('$field должен быть непустой строкой');
  }
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
    final Object? rawChoices = json['choices'];
    final List<HomeEventChoice> choices;
    if (rawChoices == null) {
      choices = const <HomeEventChoice>[];
    } else if (rawChoices is List<dynamic>) {
      choices = rawChoices
          .map(
            (Object? value) =>
                HomeEventChoice.fromJson(_asMap(value, 'choices[]')),
          )
          .toList(growable: false);
    } else {
      throw const FormatException('choices должен быть JSON-массивом');
    }
    final Object? materialJson = json['materialReward'];

    return HomeExpeditionEvent(
      eventId: HomeSnapshot._readString(json, 'eventId'),
      title: HomeSnapshot._readString(json, 'title'),
      summary: HomeSnapshot._readString(json, 'summary'),
      status: HomeSnapshot._readString(json, 'status'),
      choices: choices,
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
}

class HomeEventChoice {
  const HomeEventChoice({
    required this.choiceId,
    required this.title,
    required this.description,
    required this.pilotExperienceReward,
    required this.petBondReward,
    this.materialReward,
  });

  factory HomeEventChoice.fromJson(Map<String, dynamic> json) {
    final Object? materialJson = json['materialReward'];
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
    );
  }

  final String choiceId;
  final String title;
  final String description;
  final int pilotExperienceReward;
  final int petBondReward;
  final HomeMaterialRewardPreview? materialReward;
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
  });

  factory HomeInventoryItem.fromJson(Map<String, dynamic> json) {
    return HomeInventoryItem(
      itemId: HomeSnapshot._readString(json, 'itemId'),
      name: HomeSnapshot._readString(json, 'name'),
      description: HomeSnapshot._readString(json, 'description'),
      quantity: HomeSnapshot._readInt(json, 'quantity'),
      version: HomeSnapshot._readInt(json, 'version'),
    );
  }

  final String itemId;
  final String name;
  final String description;
  final int quantity;
  final int version;
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
