class ExpeditionJourneyResult {
  const ExpeditionJourneyResult({
    required this.contentVersion,
    required this.expeditionId,
    required this.expeditionName,
    required this.journeyNumber,
    required this.progressAfter,
    required this.requiredEnergy,
    required this.expeditionVersion,
    required this.status,
    required this.currentNodeId,
    required this.currentNodeName,
    required this.serverTime,
  });

  factory ExpeditionJourneyResult.fromJson(Map<String, dynamic> json) {
    final int journeyNumber = _readInt(json, 'journeyNumber');
    if (journeyNumber < 2) {
      throw const FormatException(
        'journeyNumber нового похода должен быть не меньше 2',
      );
    }
    final int progressAfter = _readInt(json, 'progressAfter');
    final int requiredEnergy = _readInt(json, 'requiredEnergy');
    final String status = _readString(json, 'status');
    if (progressAfter != 0 || requiredEnergy <= 0 || status != 'IN_PROGRESS') {
      throw const FormatException(
        'Новый поход должен начинаться из пустого IN_PROGRESS состояния',
      );
    }
    return ExpeditionJourneyResult(
      contentVersion: _readString(json, 'contentVersion'),
      expeditionId: _readString(json, 'expeditionId'),
      expeditionName: _readString(json, 'expeditionName'),
      journeyNumber: journeyNumber,
      progressAfter: progressAfter,
      requiredEnergy: requiredEnergy,
      expeditionVersion: _readInt(json, 'expeditionVersion'),
      status: status,
      currentNodeId: _readString(json, 'currentNodeId'),
      currentNodeName: _readString(json, 'currentNodeName'),
      serverTime: _readString(json, 'serverTime'),
    );
  }

  final String contentVersion;
  final String expeditionId;
  final String expeditionName;
  final int journeyNumber;
  final int progressAfter;
  final int requiredEnergy;
  final int expeditionVersion;
  final String status;
  final String currentNodeId;
  final String currentNodeName;
  final String serverTime;
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
