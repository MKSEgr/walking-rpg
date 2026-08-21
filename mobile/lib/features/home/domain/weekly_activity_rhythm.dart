class WeeklyActivityRhythm {
  const WeeklyActivityRhythm({
    required this.activeDays,
    required this.windowDays,
    required this.targetActiveDays,
    required this.targetReached,
    this.days = const <WeeklyActivityDay>[],
  });

  factory WeeklyActivityRhythm.fromJson(
    Map<String, dynamic> json, {
    required String homeLocalDate,
  }) {
    final int activeDays = _readInt(json, 'activeDays');
    final int windowDays = _readInt(json, 'windowDays');
    final int targetActiveDays = _readInt(json, 'targetActiveDays');
    final bool targetReached = _readBool(json, 'targetReached');
    final bool hasDays = json.containsKey('days');
    final Object? daysJson = json['days'];

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
    final List<WeeklyActivityDay> days;
    if (!hasDays) {
      days = const <WeeklyActivityDay>[];
    } else {
      if (daysJson is! List<dynamic>) {
        throw const FormatException('days должен быть массивом');
      }
      days = daysJson.map(WeeklyActivityDay.fromJson).toList(growable: false);
      if (days.length != windowDays) {
        throw const FormatException('days должен полностью покрывать окно');
      }
      for (int index = 1; index < days.length; index += 1) {
        if (days[index].date !=
            days[index - 1].date.add(const Duration(days: 1))) {
          throw const FormatException('days должен быть последовательным');
        }
      }
      final DateTime homeDate = _parseLocalDate(homeLocalDate, 'localDate');
      if (days.last.date != homeDate) {
        throw const FormatException(
          'последний день ритма должен совпадать с localDate',
        );
      }
      final int countedActiveDays = days
          .where((WeeklyActivityDay day) => day.active)
          .length;
      if (countedActiveDays != activeDays) {
        throw const FormatException('activeDays должен соответствовать days');
      }
    }

    return WeeklyActivityRhythm(
      activeDays: activeDays,
      windowDays: windowDays,
      targetActiveDays: targetActiveDays,
      targetReached: targetReached,
      days: days,
    );
  }

  final int activeDays;
  final int windowDays;
  final int targetActiveDays;
  final bool targetReached;
  final List<WeeklyActivityDay> days;

  int get remainingActiveDays {
    final int remaining = targetActiveDays - activeDays;
    return remaining < 0 ? 0 : remaining;
  }

  double get progress =>
      (activeDays / targetActiveDays).clamp(0.0, 1.0).toDouble();
}

class WeeklyActivityDay {
  const WeeklyActivityDay({required this.localDate, required this.active});

  factory WeeklyActivityDay.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('элемент days должен быть объектом');
    }
    final String localDate = _readString(json, 'localDate');
    _parseLocalDate(localDate, 'days.localDate');
    return WeeklyActivityDay(
      localDate: localDate,
      active: _readBool(json, 'active'),
    );
  }

  final String localDate;
  final bool active;

  DateTime get date => _parseLocalDate(localDate, 'days.localDate');
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

String _readString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key должен быть непустой строкой');
  }
  return value;
}

DateTime _parseLocalDate(String value, String field) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('$field должен быть датой ISO-8601');
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null || _formatLocalDate(parsed) != value) {
    throw FormatException('$field должен быть корректной датой');
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _formatLocalDate(DateTime date) {
  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
