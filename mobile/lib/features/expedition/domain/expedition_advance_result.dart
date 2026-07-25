class ExpeditionAdvanceResult {
  const ExpeditionAdvanceResult({
    required this.contentVersion,
    required this.expeditionId,
    required this.expeditionName,
    required this.energySpent,
    required this.energyBalanceAfter,
    required this.economyVersion,
    required this.progressAfter,
    required this.requiredEnergy,
    required this.expeditionVersion,
    required this.status,
    required this.currentNodeId,
    required this.currentNodeName,
    required this.unlockedEvent,
    required this.serverTime,
  });

  factory ExpeditionAdvanceResult.fromJson(Map<String, dynamic> json) {
    final Object? eventJson = json['unlockedEvent'];
    return ExpeditionAdvanceResult(
      contentVersion: _readString(json, 'contentVersion'),
      expeditionId: _readString(json, 'expeditionId'),
      expeditionName: _readString(json, 'expeditionName'),
      energySpent: _readInt(json, 'energySpent'),
      energyBalanceAfter: _readInt(json, 'energyBalanceAfter'),
      economyVersion: _readInt(json, 'economyVersion'),
      progressAfter: _readInt(json, 'progressAfter'),
      requiredEnergy: _readInt(json, 'requiredEnergy'),
      expeditionVersion: _readInt(json, 'expeditionVersion'),
      status: _readString(json, 'status'),
      currentNodeId: _readString(json, 'currentNodeId'),
      currentNodeName: _readString(json, 'currentNodeName'),
      unlockedEvent: eventJson == null
          ? null
          : ExpeditionEventResult.fromJson(_asMap(eventJson, 'unlockedEvent')),
      serverTime: _readString(json, 'serverTime'),
    );
  }

  final String contentVersion;
  final String expeditionId;
  final String expeditionName;
  final int energySpent;
  final int energyBalanceAfter;
  final int economyVersion;
  final int progressAfter;
  final int requiredEnergy;
  final int expeditionVersion;
  final String status;
  final String currentNodeId;
  final String currentNodeName;
  final ExpeditionEventResult? unlockedEvent;
  final String serverTime;
}

class ExpeditionEventResult {
  const ExpeditionEventResult({
    required this.eventId,
    required this.title,
    required this.summary,
    required this.status,
  });

  factory ExpeditionEventResult.fromJson(Map<String, dynamic> json) {
    return ExpeditionEventResult(
      eventId: _readString(json, 'eventId'),
      title: _readString(json, 'title'),
      summary: _readString(json, 'summary'),
      status: _readString(json, 'status'),
    );
  }

  final String eventId;
  final String title;
  final String summary;
  final String status;
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

String _readString(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$field должен быть непустой строкой');
}

Map<String, dynamic> _asMap(Object value, String field) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('$field должен быть JSON-объектом');
}
