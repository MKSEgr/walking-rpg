import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';

class PlatformCommandResult {
  const PlatformCommandResult({
    required this.commandType,
    required this.idempotencyKey,
    required this.message,
    required this.stateVersion,
    required this.snapshot,
    required this.serverTime,
  });

  factory PlatformCommandResult.fromJson(Map<String, dynamic> json) {
    return PlatformCommandResult(
      commandType: _readString(json, 'commandType'),
      idempotencyKey: _readString(json, 'idempotencyKey'),
      message: _readString(json, 'message'),
      stateVersion: _readInt(json, 'stateVersion'),
      snapshot: PlatformSnapshot.fromJson(_readMap(json, 'snapshot')),
      serverTime: _readString(json, 'serverTime'),
    );
  }

  final String commandType;
  final String idempotencyKey;
  final String message;
  final int stateVersion;
  final PlatformSnapshot snapshot;
  final String serverTime;
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is! Map<Object?, Object?>) {
    throw FormatException('$field должен быть JSON-объектом');
  }
  return value.map<String, dynamic>((Object? key, Object? item) {
    if (key is! String) {
      throw FormatException('Ключи $field должны быть строками');
    }
    return MapEntry<String, dynamic>(key, item);
  });
}

String _readString(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field должен быть непустой строкой');
  }
  return value;
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
