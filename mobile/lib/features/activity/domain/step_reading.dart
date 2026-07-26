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
