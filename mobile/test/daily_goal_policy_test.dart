import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/home/domain/daily_goal_policy.dart';

void main() {
  test('adaptive policy maps transparent calculation metadata', () {
    final DailyGoalPolicy policy = DailyGoalPolicy.fromJson(<String, dynamic>{
      'policyVersion': 'adaptive-median-v1',
      'source': 'ADAPTIVE',
      'baselineSteps': 3000,
      'sampleDays': 3,
      'lookbackDays': 7,
      'minimumSampleDays': 3,
      'defaultGoal': 6000,
      'growthPercent': 5,
      'roundingStep': 250,
      'minimumGoal': 2000,
      'maximumGoal': 12000,
    });

    expect(policy.isAdaptive, isTrue);
    expect(policy.baselineSteps, 3000);
    expect(policy.explanation, 'Личная цель: медиана 3000 шагов за 3 дня +5%');
  });

  test('fractional even median stays transparent', () {
    final DailyGoalPolicy policy = DailyGoalPolicy.fromJson(<String, dynamic>{
      'policyVersion': 'adaptive-median-v1',
      'source': 'ADAPTIVE',
      'baselineSteps': 2750.5,
      'sampleDays': 4,
      'lookbackDays': 7,
      'minimumSampleDays': 3,
      'defaultGoal': 6000,
      'growthPercent': 5,
      'roundingStep': 250,
      'minimumGoal': 2000,
      'maximumGoal': 12000,
    });

    expect(
      policy.explanation,
      'Личная цель: медиана 2750.5 шагов за 4 дня +5%',
    );
  });

  test('default policy explains history collection', () {
    final DailyGoalPolicy policy = DailyGoalPolicy.fromJson(<String, dynamic>{
      'policyVersion': 'adaptive-median-v1',
      'source': 'DEFAULT',
      'baselineSteps': null,
      'sampleDays': 2,
      'lookbackDays': 7,
      'minimumSampleDays': 3,
      'defaultGoal': 6000,
      'growthPercent': 5,
      'roundingStep': 250,
      'minimumGoal': 2000,
      'maximumGoal': 12000,
    });

    expect(policy.isDefault, isTrue);
    expect(
      policy.explanation,
      'Стартовая личная цель: собрано 2 из 3 активных дней',
    );
  });

  test('adaptive policy without baseline is rejected', () {
    expect(
      () => DailyGoalPolicy.fromJson(<String, dynamic>{
        'policyVersion': 'adaptive-median-v1',
        'source': 'ADAPTIVE',
        'baselineSteps': null,
        'sampleDays': 3,
        'lookbackDays': 7,
        'minimumSampleDays': 3,
        'defaultGoal': 6000,
        'growthPercent': 5,
        'roundingStep': 250,
        'minimumGoal': 2000,
        'maximumGoal': 12000,
      }),
      throwsFormatException,
    );
  });
}
