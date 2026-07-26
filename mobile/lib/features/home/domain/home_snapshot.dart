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
  });

  factory HomeSnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> pilot = _readMap(json, 'pilot');
    final Map<String, dynamic> pet = _readMap(json, 'pet');
    final Map<String, dynamic> expedition = _readMap(json, 'expedition');
    final Object? eventJson = expedition['unlockedEvent'];

    return HomeSnapshot(
      localDate: _readString(json, 'localDate'),
      timeZone: _readNullableString(json, 'timeZone'),
      dailySteps: _readInt(json, 'dailySteps'),
      dailyGoal: _readInt(json, 'dailyGoal'),
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
          : HomeExpeditionEvent.fromJson(
              _asMap(eventJson, 'unlockedEvent'),
            ),
      pilotName: _readString(pilot, 'name'),
      pilotLevel: _readInt(pilot, 'level'),
      pilotCurrentExperience: _readInt(pilot, 'currentExperience'),
      pilotNextLevelExperience: _readInt(pilot, 'nextLevelExperience'),
      petName: _readString(pet, 'name'),
      petLevel: _readInt(pet, 'level'),
      petBond: _readInt(pet, 'bond'),
    );
  }

  final String localDate;
  final String? timeZone;
  final int dailySteps;
  final int dailyGoal;
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
    availableEnergy: 0,
    activityStateVersion: 0,
    economyVersion: 0,
    lastActivitySyncAt: null,
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'starter-v1',
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
    final Object? value = json[field];
    return _asMap(value, field);
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    String field,
  ) {
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
  });

  factory HomeExpeditionEvent.fromJson(Map<String, dynamic> json) {
    final Object? rawChoices = json['choices'];
    final List<HomeEventChoice> choices;
    if (rawChoices == null) {
      choices = const <HomeEventChoice>[];
    } else if (rawChoices is List<dynamic>) {
      choices = rawChoices
          .map(
            (Object? value) => HomeEventChoice.fromJson(
              _asMap(value, 'choices[]'),
            ),
          )
          .toList(growable: false);
    } else {
      throw const FormatException('choices должен быть JSON-массивом');
    }

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
      outcomeSummary: HomeSnapshot._readNullableString(
        json,
        'outcomeSummary',
      ),
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

  bool get isResolved => status == 'RESOLVED';
}

class HomeEventChoice {
  const HomeEventChoice({
    required this.choiceId,
    required this.title,
    required this.description,
    required this.pilotExperienceReward,
    required this.petBondReward,
  });

  factory HomeEventChoice.fromJson(Map<String, dynamic> json) {
    return HomeEventChoice(
      choiceId: HomeSnapshot._readString(json, 'choiceId'),
      title: HomeSnapshot._readString(json, 'title'),
      description: HomeSnapshot._readString(json, 'description'),
      pilotExperienceReward: HomeSnapshot._readInt(
        json,
        'pilotExperienceReward',
      ),
      petBondReward: HomeSnapshot._readInt(json, 'petBondReward'),
    );
  }

  final String choiceId;
  final String title;
  final String description;
  final int pilotExperienceReward;
  final int petBondReward;
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('$field должен быть JSON-объектом');
}
