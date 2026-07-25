import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';

void main() {
  test('demo snapshot starts without rewarded activity', () {
    const snapshot = HomeSnapshot.demo;

    expect(snapshot.dailySteps, 0);
    expect(snapshot.availableEnergy, 0);
    expect(snapshot.dailyProgress, 0);
    expect(snapshot.expeditionProgressValue, 0);
  });
}
