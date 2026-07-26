class ActivitySyncResult {
  const ActivitySyncResult({
    required this.acceptedTotal,
    required this.acceptedDelta,
    required this.energyGranted,
    required this.energyBalanceAfter,
    required this.economyVersion,
    required this.riskStatus,
    required this.stateVersion,
    required this.serverTime,
  });

  factory ActivitySyncResult.fromJson(Map<String, dynamic> json) {
    return ActivitySyncResult(
      acceptedTotal: _readInt(json, 'acceptedTotal'),
      acceptedDelta: _readInt(json, 'acceptedDelta'),
      energyGranted: _readInt(json, 'energyGranted'),
      energyBalanceAfter: _readInt(json, 'energyBalanceAfter'),
      economyVersion: _readInt(json, 'economyVersion'),
      riskStatus: _readString(json, 'riskStatus'),
      stateVersion: _readInt(json, 'stateVersion'),
      serverTime: _readString(json, 'serverTime'),
    );
  }

  final int acceptedTotal;
  final int acceptedDelta;
  final int energyGranted;
  final int energyBalanceAfter;
  final int economyVersion;
  final String riskStatus;
  final int stateVersion;
  final String serverTime;

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

  static String _readString(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('$field должен быть непустой строкой');
  }
}
