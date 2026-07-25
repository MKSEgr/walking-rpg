import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';

void main() {
  test('demo snapshot starts without rewarded activity', () {
    const HomeSnapshot snapshot = HomeSnapshot.demo;

    expect(snapshot.dailySteps, 0);
    expect(snapshot.availableEnergy, 0);
    expect(snapshot.dailyProgress, 0);
    expect(snapshot.expeditionProgressValue, 0);
    expect(snapshot.spendableEnergy, 0);
    expect(snapshot.unlockedEvent, isNull);
  });

  test('production response maps persistent expedition and event', () {
    final HomeSnapshot snapshot = HomeSnapshot.fromJson(_homeResponse());

    expect(snapshot.dailySteps, 6842);
    expect(snapshot.availableEnergy, 38);
    expect(snapshot.activityStateVersion, 1);
    expect(snapshot.economyVersion, 2);
    expect(snapshot.expeditionId, 'starter-expedition-v1');
    expect(snapshot.expeditionProgress, 30);
    expect(snapshot.expeditionVersion, 1);
    expect(snapshot.expeditionStatus, 'EVENT_READY');
    expect(snapshot.spendableEnergy, 0);
    expect(snapshot.unlockedEvent?.title, 'Источник сигнала');
  });

  test('partial expedition exposes spendable energy capped by remaining', () {
    final Map<String, dynamic> response = _homeResponse();
    response['availableEnergy'] = 68;
    final Map<String, dynamic> expedition =
        response['expedition'] as Map<String, dynamic>;
    expedition['progress'] = 20;
    expedition['status'] = 'IN_PROGRESS';
    expedition['version'] = 1;
    expedition['unlockedEvent'] = null;

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);

    expect(snapshot.remainingExpeditionEnergy, 10);
    expect(snapshot.spendableEnergy, 10);
  });

  test('invalid nested response is rejected', () {
    expect(
      () => HomeSnapshot.fromJson(<String, dynamic>{'pilot': 'invalid'}),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _homeResponse() {
  return <String, dynamic>{
    'localDate': '2026-07-25',
    'timeZone': 'Europe/Berlin',
    'dailySteps': 6842,
    'dailyGoal': 6000,
    'availableEnergy': 38,
    'activityStateVersion': 1,
    'economyVersion': 2,
    'lastActivitySyncAt': '2026-07-25T11:55:00Z',
    'serverTime': '2026-07-25T12:00:00Z',
    'contentVersion': 'starter-v1',
    'pilot': <String, dynamic>{'name': 'Навигатор', 'level': 1},
    'pet': <String, dynamic>{'name': 'Искра', 'level': 1},
    'expedition': <String, dynamic>{
      'expeditionId': 'starter-expedition-v1',
      'name': 'Сигнал из туманного сектора',
      'currentNodeId': 'outer-beacon',
      'currentNode': 'Внешний маяк',
      'progress': 30,
      'requiredEnergy': 30,
      'status': 'EVENT_READY',
      'version': 1,
      'unlockedEvent': <String, dynamic>{
        'eventId': 'signal-source-v1',
        'title': 'Источник сигнала',
        'summary': 'Маяк отвечает импульсом.',
        'status': 'READY',
      },
    },
  };
}
