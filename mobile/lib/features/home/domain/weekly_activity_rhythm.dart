class WeeklyActivityRhythm {
  const WeeklyActivityRhythm({
    required this.activeDays,
    required this.windowDays,
    required this.targetActiveDays,
    required this.targetReached,
  });

  factory WeeklyActivityRhythm.fromJson(Map<String, dynamic> json) {
    final int activeDays = _readInt(json, 'activeDays');
    final int windowDays = _readInt(json, 'windowDays');
    final int targetActiveDays = _readInt(json, 'targetActiveDays');
    final bool targetReached = _readBool(json, 'targetReached');

    if (windowDays <= 0) {
      throw const FormatException('windowDays должен быть положительным');
    }
    if (targetActiveDays <= 0 || targetActiveDays > windowDays) {
      throw const FormatException('targetActiveDays должен входить в окно');
    }
    if (activeDays < 0 || activeDays > windowDays) {
      throw const FormatException('activeDays должен входить в окно');
    }
    if (targetReached != (activeDays >= targetActiveDays)) {
      throw const FormatException(
        'targetReached не соответствует количеству активных дней',
      );
    }

    return WeeklyActivityRhythm(
      activeDays: activeDays,
      windowDays: windowDays,
      targetActiveDays: targetActiveDays,
      targetReached: targetReached,
    );
  }

  final int activeDays;
  final int windowDays;
  final int targetActiveDays;
  final bool targetReached;

  int get remainingActiveDays {
    final int remaining = targetActiveDays - activeDays;
    return remaining < 0 ? 0 : remaining;
  }

  double get progress =>
      (activeDays / targetActiveDays).clamp(0.0, 1.0).toDouble();
}

int _readInt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! int) {
    throw FormatException('$key должен быть целым числом');
  }
  return value;
}

bool _readBool(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! bool) {
    throw FormatException('$key должен быть логическим значением');
  }
  return value;
}
