class DailyGoalPolicy {
  const DailyGoalPolicy({
    required this.policyVersion,
    required this.source,
    required this.baselineSteps,
    required this.sampleDays,
    required this.lookbackDays,
    required this.minimumSampleDays,
    required this.defaultGoal,
    required this.growthPercent,
    required this.roundingStep,
    required this.minimumGoal,
    required this.maximumGoal,
  });

  const DailyGoalPolicy.legacy()
    : policyVersion = 'legacy',
      source = 'LEGACY',
      baselineSteps = null,
      sampleDays = 0,
      lookbackDays = 0,
      minimumSampleDays = 0,
      defaultGoal = 0,
      growthPercent = 0,
      roundingStep = 0,
      minimumGoal = 0,
      maximumGoal = 0;

  factory DailyGoalPolicy.fromJson(Map<String, dynamic> json) {
    final String source = _readString(json, 'source');
    if (source != 'DEFAULT' && source != 'ADAPTIVE') {
      throw const FormatException(
        'source daily goal должен быть DEFAULT или ADAPTIVE',
      );
    }

    final num? baselineSteps = _readNullableNum(json, 'baselineSteps');
    final int sampleDays = _readInt(json, 'sampleDays');
    final int lookbackDays = _readInt(json, 'lookbackDays');
    final int minimumSampleDays = _readInt(json, 'minimumSampleDays');
    final int defaultGoal = _readInt(json, 'defaultGoal');
    final int growthPercent = _readInt(json, 'growthPercent');
    final int roundingStep = _readInt(json, 'roundingStep');
    final int minimumGoal = _readInt(json, 'minimumGoal');
    final int maximumGoal = _readInt(json, 'maximumGoal');

    if (sampleDays < 0 || lookbackDays <= 0 || minimumSampleDays <= 0) {
      throw const FormatException('Параметры истории daily goal некорректны');
    }
    if (minimumSampleDays > lookbackDays || sampleDays > lookbackDays) {
      throw const FormatException('Количество дней daily goal некорректно');
    }
    if (growthPercent < 0 || growthPercent > 100 || roundingStep <= 0) {
      throw const FormatException('Параметры расчёта daily goal некорректны');
    }
    if (minimumGoal <= 0 || maximumGoal < minimumGoal) {
      throw const FormatException('Диапазон daily goal некорректен');
    }
    if (defaultGoal < minimumGoal || defaultGoal > maximumGoal) {
      throw const FormatException('defaultGoal находится вне диапазона');
    }
    if (minimumGoal % roundingStep != 0 ||
        maximumGoal % roundingStep != 0 ||
        defaultGoal % roundingStep != 0) {
      throw const FormatException(
        'Границы и defaultGoal должны быть кратны roundingStep',
      );
    }
    if (baselineSteps != null &&
        baselineSteps * 2 != (baselineSteps * 2).roundToDouble()) {
      throw const FormatException(
        'baselineSteps должен быть целым или оканчиваться на .5',
      );
    }
    if (source == 'DEFAULT') {
      if (baselineSteps != null || sampleDays >= minimumSampleDays) {
        throw const FormatException(
          'DEFAULT daily goal имеет неверную историю',
        );
      }
    }
    if (source == 'ADAPTIVE') {
      if (baselineSteps == null ||
          baselineSteps <= 0 ||
          sampleDays < minimumSampleDays) {
        throw const FormatException('ADAPTIVE daily goal требует baseline');
      }
    }

    return DailyGoalPolicy(
      policyVersion: _readString(json, 'policyVersion'),
      source: source,
      baselineSteps: baselineSteps,
      sampleDays: sampleDays,
      lookbackDays: lookbackDays,
      minimumSampleDays: minimumSampleDays,
      defaultGoal: defaultGoal,
      growthPercent: growthPercent,
      roundingStep: roundingStep,
      minimumGoal: minimumGoal,
      maximumGoal: maximumGoal,
    );
  }

  final String policyVersion;
  final String source;
  final num? baselineSteps;
  final int sampleDays;
  final int lookbackDays;
  final int minimumSampleDays;
  final int defaultGoal;
  final int growthPercent;
  final int roundingStep;
  final int minimumGoal;
  final int maximumGoal;

  bool get isAdaptive => source == 'ADAPTIVE';
  bool get isDefault => source == 'DEFAULT';
  bool get isLegacy => source == 'LEGACY';

  void validateGoal(int goal) {
    if (goal <= 0) {
      throw const FormatException('dailyGoal должна быть положительной');
    }
    if (isLegacy) {
      return;
    }
    if (goal < minimumGoal || goal > maximumGoal || goal % roundingStep != 0) {
      throw const FormatException('dailyGoal не соответствует dailyGoalPolicy');
    }
    if (isDefault && goal != defaultGoal) {
      throw const FormatException(
        'DEFAULT dailyGoal не совпадает с defaultGoal',
      );
    }
  }

  String get explanation {
    final num? baseline = baselineSteps;
    if (isAdaptive && baseline != null) {
      return 'Личная цель: медиана ${_formatSteps(baseline)} шагов '
          'за $sampleDays ${_dayWord(sampleDays)} +$growthPercent%';
    }
    if (isDefault) {
      return 'Стартовая личная цель: собрано '
          '$sampleDays из $minimumSampleDays активных дней';
    }
    return 'Личная цель';
  }

  static String _dayWord(int value) {
    final int lastTwo = value % 100;
    if (lastTwo >= 11 && lastTwo <= 14) {
      return 'дней';
    }
    final int last = value % 10;
    if (last == 1) {
      return 'день';
    }
    if (last >= 2 && last <= 4) {
      return 'дня';
    }
    return 'дней';
  }

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

  static num? _readNullableNum(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value == null) {
      return null;
    }
    if (value is num && value.isFinite) {
      return value;
    }
    throw FormatException('$field должен быть конечным числом или null');
  }

  static String _formatSteps(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  static String _readString(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw FormatException('$field должен быть непустой строкой');
  }
}
