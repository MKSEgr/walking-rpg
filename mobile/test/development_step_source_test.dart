import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/activity/data/development_step_source.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';

void main() {
  test(
    'development source creates an explicit deterministic reading',
    () async {
      final DevelopmentStepSource source = DevelopmentStepSource(
        authoritativeTotal: 6842,
        timeZone: 'Europe/Berlin',
        now: () => DateTime(2026, 7, 26, 9, 30),
      );

      final StepReading reading = await source.read();

      expect(reading.authoritativeTotal, 6842);
      expect(reading.localDateIso, '2026-07-26');
      expect(reading.timeZone, 'Europe/Berlin');
      expect(reading.syncCursor, 'demo:2026-07-26:6842');
    },
  );

  test('negative development total is rejected', () {
    expect(
      () => DevelopmentStepSource(authoritativeTotal: -1, timeZone: 'UTC'),
      throwsArgumentError,
    );
  });
}
