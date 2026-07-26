class StepReading {
  StepReading({
    required this.authoritativeTotal,
    required DateTime localDate,
    required String timeZone,
    this.syncCursor,
  }) : localDate = DateTime(localDate.year, localDate.month, localDate.day),
       timeZone = _requireText(timeZone, 'timeZone') {
    if (authoritativeTotal < 0) {
      throw ArgumentError.value(
        authoritativeTotal,
        'authoritativeTotal',
        'Значение не может быть отрицательным',
      );
    }
  }

  factory StepReading.fromJson(Map<String, Object?> json) {
    final Object? authoritativeTotal = json['authoritativeTotal'];
    final Object? localDate = json['localDate'];
    final Object? timeZone = json['timeZone'];
    final Object? syncCursor = json['syncCursor'];
    if (authoritativeTotal is! int) {
      throw const FormatException(
        'authoritativeTotal должен быть целым числом',
      );
    }
    if (localDate is! String || localDate.trim().isEmpty) {
      throw const FormatException('localDate должен быть непустой строкой');
    }
    if (timeZone is! String || timeZone.trim().isEmpty) {
      throw const FormatException('timeZone должен быть непустой строкой');
    }
    if (syncCursor != null && syncCursor is! String) {
      throw const FormatException('syncCursor должен быть строкой или null');
    }

    final DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(localDate);
    } on FormatException {
      throw const FormatException('localDate содержит некорректную дату');
    }
    return StepReading(
      authoritativeTotal: authoritativeTotal,
      localDate: parsedDate,
      timeZone: timeZone,
      syncCursor: syncCursor as String?,
    );
  }

  final int authoritativeTotal;
  final DateTime localDate;
  final String timeZone;
  final String? syncCursor;

  String get localDateIso {
    final String year = localDate.year.toString().padLeft(4, '0');
    final String month = localDate.month.toString().padLeft(2, '0');
    final String day = localDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'authoritativeTotal': authoritativeTotal,
      'localDate': localDateIso,
      'timeZone': timeZone,
      'syncCursor': syncCursor,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StepReading &&
            authoritativeTotal == other.authoritativeTotal &&
            localDate == other.localDate &&
            timeZone == other.timeZone &&
            syncCursor == other.syncCursor;
  }

  @override
  int get hashCode =>
      Object.hash(authoritativeTotal, localDate, timeZone, syncCursor);

  static String _requireText(String value, String field) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'Значение обязательно');
    }
    return normalized;
  }
}
