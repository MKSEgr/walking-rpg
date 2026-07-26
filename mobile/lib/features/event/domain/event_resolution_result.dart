class EventResolutionResult {
  const EventResolutionResult({
    required this.contentVersion,
    required this.expeditionId,
    required this.expeditionStatus,
    required this.expeditionVersion,
    required this.eventId,
    required this.eventTitle,
    required this.status,
    required this.choiceId,
    required this.choiceTitle,
    required this.outcomeTitle,
    required this.outcomeSummary,
    required this.pilot,
    required this.pet,
    required this.serverTime,
    this.material,
  });

  factory EventResolutionResult.fromJson(Map<String, dynamic> json) {
    final Object? materialJson = json['material'];
    return EventResolutionResult(
      contentVersion: _readString(json, 'contentVersion'),
      expeditionId: _readString(json, 'expeditionId'),
      expeditionStatus: _readString(json, 'expeditionStatus'),
      expeditionVersion: _readInt(json, 'expeditionVersion'),
      eventId: _readString(json, 'eventId'),
      eventTitle: _readString(json, 'eventTitle'),
      status: _readString(json, 'status'),
      choiceId: _readString(json, 'choiceId'),
      choiceTitle: _readString(json, 'choiceTitle'),
      outcomeTitle: _readString(json, 'outcomeTitle'),
      outcomeSummary: _readString(json, 'outcomeSummary'),
      pilot: EventPilotReward.fromJson(_readMap(json, 'pilot')),
      pet: EventPetReward.fromJson(_readMap(json, 'pet')),
      material: materialJson == null
          ? null
          : EventMaterialReward.fromJson(_asMap(materialJson, 'material')),
      serverTime: _readString(json, 'serverTime'),
    );
  }

  final String contentVersion;
  final String expeditionId;
  final String expeditionStatus;
  final int expeditionVersion;
  final String eventId;
  final String eventTitle;
  final String status;
  final String choiceId;
  final String choiceTitle;
  final String outcomeTitle;
  final String outcomeSummary;
  final EventPilotReward pilot;
  final EventPetReward pet;
  final EventMaterialReward? material;
  final String serverTime;
}

class EventPilotReward {
  const EventPilotReward({
    required this.pilotId,
    required this.name,
    required this.level,
    required this.experienceGained,
    required this.currentExperience,
    required this.nextLevelExperience,
    required this.version,
  });

  factory EventPilotReward.fromJson(Map<String, dynamic> json) {
    return EventPilotReward(
      pilotId: _readString(json, 'pilotId'),
      name: _readString(json, 'name'),
      level: _readInt(json, 'level'),
      experienceGained: _readInt(json, 'experienceGained'),
      currentExperience: _readInt(json, 'currentExperience'),
      nextLevelExperience: _readInt(json, 'nextLevelExperience'),
      version: _readInt(json, 'version'),
    );
  }

  final String pilotId;
  final String name;
  final int level;
  final int experienceGained;
  final int currentExperience;
  final int nextLevelExperience;
  final int version;
}

class EventPetReward {
  const EventPetReward({
    required this.petId,
    required this.name,
    required this.level,
    required this.bondGained,
    required this.bond,
    required this.version,
  });

  factory EventPetReward.fromJson(Map<String, dynamic> json) {
    return EventPetReward(
      petId: _readString(json, 'petId'),
      name: _readString(json, 'name'),
      level: _readInt(json, 'level'),
      bondGained: _readInt(json, 'bondGained'),
      bond: _readInt(json, 'bond'),
      version: _readInt(json, 'version'),
    );
  }

  final String petId;
  final String name;
  final int level;
  final int bondGained;
  final int bond;
  final int version;
}

class EventMaterialReward {
  const EventMaterialReward({
    required this.itemId,
    required this.name,
    required this.description,
    required this.quantityGained,
    required this.quantityAfter,
    required this.version,
  });

  factory EventMaterialReward.fromJson(Map<String, dynamic> json) {
    return EventMaterialReward(
      itemId: _readString(json, 'itemId'),
      name: _readString(json, 'name'),
      description: _readString(json, 'description'),
      quantityGained: _readInt(json, 'quantityGained'),
      quantityAfter: _readInt(json, 'quantityAfter'),
      version: _readInt(json, 'version'),
    );
  }

  final String itemId;
  final String name;
  final String description;
  final int quantityGained;
  final int quantityAfter;
  final int version;
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, String field) {
  return _asMap(json[field], field);
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('$field должен быть JSON-объектом');
}

String _readString(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$field должен быть непустой строкой');
}

int _readInt(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is int) {
    return value;
  }
  if (value is num && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$field должен быть целым числом');
}
