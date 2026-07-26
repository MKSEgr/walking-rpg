import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_source.dart';

class DevelopmentStepSource implements StepSource {
  DevelopmentStepSource({
    required this.authoritativeTotal,
    required String timeZone,
    DateTime Function()? now,
  }) : timeZone = _requireText(timeZone, 'timeZone'),
       _now = now ?? DateTime.now {
    if (authoritativeTotal < 0) {
      throw ArgumentError.value(
        authoritativeTotal,
        'authoritativeTotal',
        'Значение не может быть отрицательным',
      );
    }
  }

  factory DevelopmentStepSource.fromEnvironment() {
    if (!AppEnvironment.enableDemoActivitySync) {
      throw StateError(
        'Development step source отключён. '
        'Передайте ENABLE_DEMO_ACTIVITY_SYNC=true.',
      );
    }
    return DevelopmentStepSource(
      authoritativeTotal: AppEnvironment.demoStepTotal,
      timeZone: AppEnvironment.activityTimeZone,
    );
  }

  final int authoritativeTotal;
  final String timeZone;
  final DateTime Function() _now;

  @override
  Future<StepReading> read() async {
    final DateTime current = _now();
    final StepReading reading = StepReading(
      authoritativeTotal: authoritativeTotal,
      localDate: current,
      timeZone: timeZone,
    );
    return StepReading(
      authoritativeTotal: reading.authoritativeTotal,
      localDate: reading.localDate,
      timeZone: reading.timeZone,
      syncCursor: 'demo:${reading.localDateIso}:$authoritativeTotal',
    );
  }

  static String _requireText(String value, String field) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'Значение обязательно');
    }
    return normalized;
  }
}
