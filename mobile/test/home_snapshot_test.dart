import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';

void main() {
  test('demo snapshot starts with starter progression', () {
    const HomeSnapshot snapshot = HomeSnapshot.demo;

    expect(snapshot.dailySteps, 0);
    expect(snapshot.availableEnergy, 0);
    expect(snapshot.dailyProgress, 0);
    expect(snapshot.expeditionProgressValue, 0);
    expect(snapshot.spendableEnergy, 0);
    expect(snapshot.unlockedEvent, isNull);
    expect(snapshot.pilotCurrentExperience, 20);
    expect(snapshot.pilotNextLevelExperience, 100);
    expect(snapshot.petBond, 10);
  });

  test('production response maps ready event choices and progression', () {
    final HomeSnapshot snapshot = HomeSnapshot.fromJson(_readyHomeResponse());

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
    expect(snapshot.unlockedEvent?.choices, hasLength(2));
    expect(snapshot.unlockedEvent?.choices.first.choiceId, 'analyze-signal');
    expect(snapshot.pilotCurrentExperience, 20);
    expect(snapshot.petBond, 10);
  });

  test('resolved event maps selected outcome and persistent rewards', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    final Map<String, dynamic> pilot =
        response['pilot'] as Map<String, dynamic>;
    final Map<String, dynamic> pet = response['pet'] as Map<String, dynamic>;
    final Map<String, dynamic> expedition =
        response['expedition'] as Map<String, dynamic>;
    final Map<String, dynamic> event =
        expedition['unlockedEvent'] as Map<String, dynamic>;

    pilot['currentExperience'] = 60;
    pet['bond'] = 15;
    expedition['status'] = 'COMPLETED';
    expedition['version'] = 2;
    event['status'] = 'RESOLVED';
    event['selectedChoiceId'] = 'analyze-signal';
    event['selectedChoiceTitle'] = 'Проанализировать сигнал';
    event['outcomeTitle'] = 'Карта импульсов';
    event['outcomeSummary'] = 'Навигатор выделил безопасный ритм доступа.';

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);

    expect(snapshot.expeditionStatus, 'COMPLETED');
    expect(snapshot.unlockedEvent?.isResolved, isTrue);
    expect(snapshot.unlockedEvent?.selectedChoiceId, 'analyze-signal');
    expect(snapshot.unlockedEvent?.outcomeTitle, 'Карта импульсов');
    expect(snapshot.pilotCurrentExperience, 60);
    expect(snapshot.petBond, 15);
  });

  test('partial expedition exposes spendable energy capped by remaining', () {
    final Map<String, dynamic> response = _readyHomeResponse();
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

Map<String, dynamic> _readyHomeResponse() {
  return <String, dynamic>{
    'localDate': '2026-07-26',
    'timeZone': 'Europe/Berlin',
    'dailySteps': 6842,
    'dailyGoal': 6000,
    'availableEnergy': 38,
    'activityStateVersion': 1,
    'economyVersion': 2,
    'lastActivitySyncAt': '2026-07-26T05:55:00Z',
    'serverTime': '2026-07-26T06:00:00Z',
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
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{
            'choiceId': 'analyze-signal',
            'title': 'Проанализировать сигнал',
            'description': 'Пилот сопоставит частоты маяка.',
            'pilotExperienceReward': 40,
            'petBondReward': 5,
          },
          <String, dynamic>{
            'choiceId': 'trust-spark',
            'title': 'Довериться Искре',
            'description': 'Питомец найдёт путь по свету.',
            'pilotExperienceReward': 20,
            'petBondReward': 15,
          },
        ],
        'selectedChoiceId': null,
        'selectedChoiceTitle': null,
        'outcomeTitle': null,
        'outcomeSummary': null,
      },
    },
  };
}
