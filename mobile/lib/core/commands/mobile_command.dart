enum MobileCommandLane {
  activity('ACTIVITY'),
  gameplay('GAMEPLAY');

  const MobileCommandLane(this.wireName);

  final String wireName;
}

enum MobileCommandType {
  activitySync('ACTIVITY_SYNC', MobileCommandLane.activity),
  expeditionAdvance('EXPEDITION_ADVANCE', MobileCommandLane.gameplay),
  eventResolution('EVENT_RESOLUTION', MobileCommandLane.gameplay),
  eventResultAcknowledgement(
    'EVENT_RESULT_ACKNOWLEDGEMENT',
    MobileCommandLane.gameplay,
  ),
  platformCommand('PLATFORM_COMMAND', MobileCommandLane.gameplay);

  const MobileCommandType(this.wireName, this.lane);

  final String wireName;
  final MobileCommandLane lane;

  static MobileCommandType fromWireName(String value) {
    return MobileCommandType.values.firstWhere(
      (MobileCommandType type) => type.wireName == value,
      orElse: () =>
          throw FormatException('Неизвестный тип mobile-команды: $value'),
    );
  }
}

enum MobileCommandState {
  pending('PENDING'),
  failed('FAILED');

  const MobileCommandState(this.wireName);

  final String wireName;

  static MobileCommandState fromWireName(String value) {
    return MobileCommandState.values.firstWhere(
      (MobileCommandState state) => state.wireName == value,
      orElse: () =>
          throw FormatException('Неизвестное состояние mobile-команды: $value'),
    );
  }
}

final class MobileCommand {
  MobileCommand({
    required String commandId,
    required String ownerId,
    required this.type,
    required String idempotencyKey,
    required String fingerprint,
    required Map<String, Object?> payload,
    required this.state,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastAttemptAt,
    this.lastError,
  }) : commandId = _requireText(commandId, 'commandId'),
       ownerId = _requireText(ownerId, 'ownerId'),
       idempotencyKey = _requireText(idempotencyKey, 'idempotencyKey'),
       fingerprint = _requireText(fingerprint, 'fingerprint'),
       payload = Map<String, Object?>.unmodifiable(payload) {
    if (attemptCount < 0) {
      throw ArgumentError.value(
        attemptCount,
        'attemptCount',
        'Значение не может быть отрицательным',
      );
    }
  }

  factory MobileCommand.pending({
    required String ownerId,
    required MobileCommandType type,
    required String idempotencyKey,
    required String fingerprint,
    required Map<String, Object?> payload,
    required DateTime now,
  }) {
    final String normalizedKey = _requireText(idempotencyKey, 'idempotencyKey');
    final DateTime timestamp = now.toUtc();
    return MobileCommand(
      commandId: '${type.wireName}:$normalizedKey',
      ownerId: ownerId,
      type: type,
      idempotencyKey: normalizedKey,
      fingerprint: fingerprint,
      payload: payload,
      state: MobileCommandState.pending,
      attemptCount: 0,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory MobileCommand.fromJson(Map<String, Object?> json) {
    return MobileCommand(
      commandId: _readString(json, 'commandId'),
      ownerId: _readString(json, 'ownerId'),
      type: MobileCommandType.fromWireName(_readString(json, 'type')),
      idempotencyKey: _readString(json, 'idempotencyKey'),
      fingerprint: _readString(json, 'fingerprint'),
      payload: _readMap(json, 'payload'),
      state: MobileCommandState.fromWireName(_readString(json, 'state')),
      attemptCount: _readInt(json, 'attemptCount'),
      createdAt: _readDateTime(json, 'createdAt'),
      updatedAt: _readDateTime(json, 'updatedAt'),
      lastAttemptAt: _readNullableDateTime(json, 'lastAttemptAt'),
      lastError: _readNullableString(json, 'lastError'),
    );
  }

  final String commandId;
  final String ownerId;
  final MobileCommandType type;
  final String idempotencyKey;
  final String fingerprint;
  final Map<String, Object?> payload;
  final MobileCommandState state;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAttemptAt;
  final String? lastError;

  MobileCommandLane get lane => type.lane;

  MobileCommand withAttemptFailure({
    required DateTime now,
    required Object error,
    required bool terminal,
  }) {
    final DateTime timestamp = now.toUtc();
    return MobileCommand(
      commandId: commandId,
      ownerId: ownerId,
      type: type,
      idempotencyKey: idempotencyKey,
      fingerprint: fingerprint,
      payload: payload,
      state: terminal ? MobileCommandState.failed : MobileCommandState.pending,
      attemptCount: attemptCount + 1,
      createdAt: createdAt,
      updatedAt: timestamp,
      lastAttemptAt: timestamp,
      lastError: _truncateError(error.toString()),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'commandId': commandId,
      'ownerId': ownerId,
      'type': type.wireName,
      'idempotencyKey': idempotencyKey,
      'fingerprint': fingerprint,
      'payload': payload,
      'state': state.wireName,
      'attemptCount': attemptCount,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toUtc().toIso8601String(),
      'lastError': lastError,
    };
  }

  static String _truncateError(String value) {
    const int maxLength = 1000;
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }

  static String _requireText(String value, String field) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'Значение обязательно');
    }
    return normalized;
  }

  static String _readString(Map<String, Object?> json, String field) {
    final Object? value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Поле $field должно быть непустой строкой');
    }
    return value;
  }

  static String? _readNullableString(Map<String, Object?> json, String field) {
    final Object? value = json[field];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('Поле $field должно быть строкой или null');
    }
    return value;
  }

  static int _readInt(Map<String, Object?> json, String field) {
    final Object? value = json[field];
    if (value is! int) {
      throw FormatException('Поле $field должно быть целым числом');
    }
    return value;
  }

  static DateTime _readDateTime(Map<String, Object?> json, String field) {
    final String value = _readString(json, field);
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      throw FormatException('Поле $field содержит некорректную дату');
    }
  }

  static DateTime? _readNullableDateTime(
    Map<String, Object?> json,
    String field,
  ) {
    final Object? value = json[field];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('Поле $field должно быть датой или null');
    }
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      throw FormatException('Поле $field содержит некорректную дату');
    }
  }

  static Map<String, Object?> _readMap(
    Map<String, Object?> json,
    String field,
  ) {
    final Object? value = json[field];
    if (value is! Map<Object?, Object?>) {
      throw FormatException('Поле $field должно быть JSON-объектом');
    }
    return value.map<String, Object?>((Object? key, Object? item) {
      if (key is! String) {
        throw FormatException('Ключи поля $field должны быть строками');
      }
      return MapEntry<String, Object?>(key, item);
    });
  }
}
