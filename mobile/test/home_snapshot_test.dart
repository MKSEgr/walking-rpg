import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';

void main() {
  test('demo snapshot starts without rewarded activity', () {
    const HomeSnapshot snapshot = HomeSnapshot.demo;

    expect(snapshot.dailySteps, 0);
    expect(snapshot.availableEnergy, 0);
    expect(snapshot.dailyProgress, 0);
    expect(snapshot.expeditionProgressValue, 0);
  });

  test('production response is mapped into a home snapshot', () {
    final HomeSnapshot snapshot = HomeSnapshot.fromJson(
      <String, dynamic>{
        'localDate': '2026-07-25',
        'timeZone': 'Europe/Berlin',
        'dailySteps': 6842,
        'dailyGoal': 6000,
        'availableEnergy': 68,
        'activityStateVersion': 1,
        'economyVersion': 2,
        'lastActivitySyncAt': '2026-07-25T11:55:00Z',
        'serverTime': '2026-07-25T12:00:00Z',
        'contentVersion': 'starter-v1',
        'pilot': <String, dynamic>{
          'name': 'Навигатор',
          'level': 1,
          'currentExperience': 20,
          'nextLevelExperience': 100,
          'specialization': 'Не выбрана',
        },
        'pet': <String, dynamic>{
          'name': 'Искра',
          'species': 'Люмин',
          'level': 1,
          'bond': 10,
          'trait': 'Чуткий разведчик',
        },
        'expedition': <String, dynamic>{
          'name': 'Сигнал из туманного сектора',
          'currentNode': 'Внешний маяк',
          'progress': 0,
          'requiredEnergy': 30,
        },
      },
    );

    expect(snapshot.dailySteps, 6842);
    expect(snapshot.availableEnergy, 68);
    expect(snapshot.activityStateVersion, 1);
    expect(snapshot.economyVersion, 2);
    expect(snapshot.timeZone, 'Europe/Berlin');
    expect(snapshot.pilotName, 'Навигатор');
    expect(snapshot.petName, 'Искра');
    expect(snapshot.expeditionName, 'Сигнал из туманного сектора');
  });

  test('invalid nested response is rejected', () {
    expect(
      () => HomeSnapshot.fromJson(<String, dynamic>{'pilot': 'invalid'}),
      throwsFormatException,
    );
  });
}
