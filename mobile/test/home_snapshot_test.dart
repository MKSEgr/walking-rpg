import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';

void main() {
  test('demo snapshot starts with starter progression', () {
    const HomeSnapshot snapshot = HomeSnapshot.demo;

    expect(snapshot.dailySteps, 0);
    expect(snapshot.availableEnergy, 0);
    expect(snapshot.dailyProgress, 0);
    expect(snapshot.dailyGoalPolicy.source, 'DEFAULT');
    expect(
      snapshot.dailyGoalPolicy.explanation,
      'Стартовая личная цель: собрано 0 из 3 активных дней',
    );
    expect(snapshot.expeditionProgressValue, 0);
    expect(snapshot.spendableEnergy, 0);
    expect(snapshot.unlockedEvent, isNull);
    expect(snapshot.pilotCurrentExperience, 20);
    expect(snapshot.pilotNextLevelExperience, 100);
    expect(snapshot.petId, 'spark-v1');
    expect(snapshot.petSpecies, 'Люмин');
    expect(snapshot.petBond, 10);
    expect(snapshot.petEvolutionStage, 0);
    expect(snapshot.inventory, isEmpty);
    expect(snapshot.craftingRecipes, isEmpty);
    expect(snapshot.itemUpgrades, isEmpty);
  });

  test('production response maps ready event choices and progression', () {
    final HomeSnapshot snapshot = HomeSnapshot.fromJson(_readyHomeResponse());

    expect(snapshot.dailySteps, 6842);
    expect(snapshot.dailyGoal, 3250);
    expect(snapshot.dailyGoalPolicy.source, 'ADAPTIVE');
    expect(snapshot.dailyGoalPolicy.baselineSteps, 3000);
    expect(snapshot.dailyGoalPolicy.sampleDays, 3);
    expect(snapshot.availableEnergy, 38);
    expect(snapshot.activityStateVersion, 1);
    expect(snapshot.economyVersion, 2);
    expect(snapshot.expeditionId, 'starter-expedition-v1');
    expect(snapshot.expeditionProgress, 30);
    expect(snapshot.expeditionVersion, 1);
    expect(snapshot.expeditionJourneyNumber, 2);
    expect(snapshot.expeditionStatus, 'EVENT_READY');
    expect(snapshot.spendableEnergy, 0);
    expect(snapshot.unlockedEvent?.title, 'Источник сигнала');
    expect(snapshot.unlockedEvent?.choices, hasLength(2));
    expect(snapshot.unlockedEvent?.choices.first.choiceId, 'analyze-signal');
    expect(snapshot.pilotCurrentExperience, 20);
    expect(snapshot.petId, 'spark-v1');
    expect(snapshot.petSpecies, 'Люмин');
    expect(snapshot.petBond, 10);
    expect(snapshot.petEvolutionStage, 0);
  });

  test('response without journey number defaults to the first journey', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    final Map<String, dynamic> expedition =
        response['expedition'] as Map<String, dynamic>;
    expedition.remove('journeyNumber');

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);

    expect(snapshot.expeditionJourneyNumber, 1);
  });

  test('response rejects a non-positive journey number', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    final Map<String, dynamic> expedition =
        response['expedition'] as Map<String, dynamic>;
    expedition['journeyNumber'] = 0;

    expect(() => HomeSnapshot.fromJson(response), throwsFormatException);
  });

  test('chapter v14 maps the secret observatory without client inference', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response['contentVersion'] = 'chapter-1-v14';
    final Map<String, dynamic> expedition =
        response['expedition'] as Map<String, dynamic>;
    expedition
      ..['currentNodeId'] = 'hidden-signal-observatory'
      ..['currentNode'] = 'Обсерватория скрытого сигнала'
      ..['progress'] = 90
      ..['requiredEnergy'] = 90
      ..['version'] = 53
      ..['unlockedEvent'] = <String, dynamic>{
        'eventId': 'hidden-signal-observatory-v1',
        'title': 'Координаты за хором',
        'summary': 'Скрытый хор складывается в карту неизвестного сектора.',
        'status': 'READY',
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{
            'choiceId': 'chart-hidden-sector',
            'title': 'Нанести скрытый сектор на карту',
            'description': 'Закрепить координаты для будущих экспедиций.',
            'pilotExperienceReward': 112,
            'petBondReward': 54,
            'materialReward': <String, dynamic>{
              'itemId': 'prism-dust',
              'itemName': 'Призматическая пыль',
              'quantity': 4,
            },
          },
          <String, dynamic>{
            'choiceId': 'preserve-echo-key',
            'title': 'Сохранить ключ эха',
            'description': 'Передать живой ритм сигнала питомцу.',
            'pilotExperienceReward': 86,
            'petBondReward': 76,
            'materialReward': <String, dynamic>{
              'itemId': 'echo-thread',
              'itemName': 'Нить эха',
              'quantity': 5,
            },
          },
        ],
      };

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);

    expect(snapshot.contentVersion, 'chapter-1-v14');
    expect(snapshot.currentNodeId, 'hidden-signal-observatory');
    expect(snapshot.requiredEnergy, 90);
    expect(snapshot.unlockedEvent?.eventId, 'hidden-signal-observatory-v1');
    expect(
      snapshot.unlockedEvent?.choices.map((choice) => choice.choiceId),
      <String>['chart-hidden-sector', 'preserve-echo-key'],
    );
  });

  test('chapter v15 maps the locked Trail Memory route generically', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response['contentVersion'] = 'chapter-1-v15';
    final Map<String, dynamic> expedition =
        response['expedition'] as Map<String, dynamic>;
    expedition
      ..['currentNodeId'] = 'hidden-signal-observatory'
      ..['currentNode'] = 'Обсерватория скрытого сигнала'
      ..['progress'] = 90
      ..['requiredEnergy'] = 90
      ..['version'] = 53
      ..['unlockedEvent'] = <String, dynamic>{
        'eventId': 'hidden-signal-observatory-v1',
        'title': 'Координаты за хором',
        'summary': 'Один забытый путь ещё можно восстановить.',
        'status': 'READY',
        'choices': <Map<String, dynamic>>[],
        'lockedChoices': <Map<String, dynamic>>[
          <String, dynamic>{
            'choiceId': 'reconstruct-forgotten-route',
            'title': 'Восстановить забытый маршрут',
            'description': 'Собрать исчезнувшие шаги в новый путь.',
            'pilotExperienceReward': 104,
            'petBondReward': 64,
            'materialReward': <String, dynamic>{
              'itemId': 'dawn-fragment',
              'itemName': 'Фрагмент рассвета',
              'quantity': 3,
            },
            'availability': 'LOCKED',
            'requirement': <String, dynamic>{
              'type': 'UNLOCKED_SKILL',
              'slotId': 'PILOT_SKILL',
              'slotName': 'Навык пилота',
              'itemId': 'trail-memory',
              'itemName': 'Память маршрута',
              'description':
                  'Откройте навык «Память маршрута», чтобы восстановить забытый путь обсерватории.',
            },
          },
        ],
      };

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);
    final HomeEventChoice route = snapshot.unlockedEvent!.choices.single;

    expect(snapshot.contentVersion, 'chapter-1-v15');
    expect(route.choiceId, 'reconstruct-forgotten-route');
    expect(route.isAvailable, isFalse);
    expect(route.requirement?.type, 'UNLOCKED_SKILL');
    expect(route.requirement?.itemId, 'trail-memory');
  });

  test('chapter v16 maps the locked Energy Discipline route generically', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response['contentVersion'] = 'chapter-1-v16';
    final Map<String, dynamic> expedition =
        response['expedition'] as Map<String, dynamic>;
    expedition
      ..['currentNodeId'] = 'memory-constellation'
      ..['currentNode'] = 'Созвездие памяти'
      ..['progress'] = 95
      ..['requiredEnergy'] = 95
      ..['version'] = 55
      ..['unlockedEvent'] = <String, dynamic>{
        'eventId': 'memory-constellation-v1',
        'title': 'Маршрут, который помнит шаги',
        'summary': 'Поток рассвета можно выровнять в новый меридиан.',
        'status': 'READY',
        'choices': <Map<String, dynamic>>[],
        'lockedChoices': <Map<String, dynamic>>[
          <String, dynamic>{
            'choiceId': 'stabilize-dawn-current',
            'title': 'Стабилизировать поток рассвета',
            'description': 'Выровнять импульсы созвездия в новый меридиан.',
            'pilotExperienceReward': 112,
            'petBondReward': 70,
            'materialReward': <String, dynamic>{
              'itemId': 'ion-bloom',
              'itemName': 'Ионный цветок',
              'quantity': 3,
            },
            'availability': 'LOCKED',
            'requirement': <String, dynamic>{
              'type': 'UNLOCKED_SKILL',
              'slotId': 'PILOT_SKILL',
              'slotName': 'Навык пилота',
              'itemId': 'energy-discipline',
              'itemName': 'Дисциплина энергии',
              'description':
                  'Откройте навык «Дисциплина энергии», чтобы стабилизировать поток рассвета.',
            },
          },
        ],
      };

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);
    final HomeEventChoice route = snapshot.unlockedEvent!.choices.single;

    expect(snapshot.contentVersion, 'chapter-1-v16');
    expect(route.choiceId, 'stabilize-dawn-current');
    expect(route.isAvailable, isFalse);
    expect(route.requirement?.type, 'UNLOCKED_SKILL');
    expect(route.requirement?.itemId, 'energy-discipline');
  });

  test('chapter v17 maps the locked Steady Step route generically', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response['contentVersion'] = 'chapter-1-v17';
    final Map<String, dynamic> expedition =
        response['expedition'] as Map<String, dynamic>;
    expedition
      ..['currentNodeId'] = 'dawn-meridian'
      ..['currentNode'] = 'Меридиан рассвета'
      ..['progress'] = 100
      ..['requiredEnergy'] = 100
      ..['version'] = 56
      ..['unlockedEvent'] = <String, dynamic>{
        'eventId': 'dawn-meridian-v1',
        'title': 'Ритм между шагами',
        'summary': 'Первый свет собрался в подвижный переход.',
        'status': 'READY',
        'choices': <Map<String, dynamic>>[],
        'lockedChoices': <Map<String, dynamic>>[
          <String, dynamic>{
            'choiceId': 'cross-first-light-causeway',
            'title': 'Перейти по первому свету',
            'description': 'Удержать ритм подвижного перехода.',
            'pilotExperienceReward': 118,
            'petBondReward': 76,
            'materialReward': <String, dynamic>{
              'itemId': 'prism-dust',
              'itemName': 'Призматическая пыль',
              'quantity': 4,
            },
            'availability': 'LOCKED',
            'requirement': <String, dynamic>{
              'type': 'UNLOCKED_SKILL',
              'slotId': 'PILOT_SKILL',
              'slotName': 'Навык пилота',
              'itemId': 'steady-step',
              'itemName': 'Ровный шаг',
              'description':
                  'Откройте навык «Ровный шаг», чтобы перейти по первому свету.',
            },
          },
        ],
      };

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);
    final HomeEventChoice route = snapshot.unlockedEvent!.choices.single;

    expect(snapshot.contentVersion, 'chapter-1-v17');
    expect(route.choiceId, 'cross-first-light-causeway');
    expect(route.isAvailable, isFalse);
    expect(route.requirement?.type, 'UNLOCKED_SKILL');
    expect(route.requirement?.itemId, 'steady-step');
  });

  test('legacy response keeps companion identity unknown', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    final Map<String, dynamic> pet = response['pet'] as Map<String, dynamic>;
    pet
      ..remove('petId')
      ..remove('evolutionStage');

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);

    expect(snapshot.petId, isNull);
    expect(snapshot.petSpecies, 'Люмин');
    expect(snapshot.petEvolutionStage, isNull);
  });

  test('negative companion evolution stage is rejected', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    final Map<String, dynamic> pet = response['pet'] as Map<String, dynamic>;
    pet['evolutionStage'] = -1;

    expect(() => HomeSnapshot.fromJson(response), throwsFormatException);
  });

  test('daily goal must match the server policy envelope', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response['dailyGoal'] = 3200;

    expect(() => HomeSnapshot.fromJson(response), throwsFormatException);
  });

  test('response without policy remains backward compatible', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response.remove('dailyGoalPolicy');

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);

    expect(snapshot.dailyGoalPolicy.source, 'LEGACY');
    expect(snapshot.dailyGoalPolicy.explanation, 'Личная цель');
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

  test('pending event result maps beside the next node and inventory', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response['contentVersion'] = 'chapter-1-v1';
    response['inventory'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'itemId': 'lumen-shard',
        'name': 'Люминовый осколок',
        'description': 'Стабильный фрагмент светового ядра.',
        'quantity': 2,
        'version': 1,
      },
    ];
    final Map<String, dynamic> expedition =
        response['expedition'] as Map<String, dynamic>;
    expedition
      ..['currentNodeId'] = 'ash-orbit'
      ..['currentNode'] = 'Пепельная орбита'
      ..['progress'] = 0
      ..['requiredEnergy'] = 55
      ..['status'] = 'IN_PROGRESS'
      ..['version'] = 4
      ..['unlockedEvent'] = null;
    response['pendingEventResult'] = <String, dynamic>{
      'receiptId': '22222222-2222-2222-2222-222222222222',
      'eventId': 'echo-vault-v1',
      'eventTitle': 'Хранилище эха',
      'choiceId': 'stabilize-core',
      'choiceTitle': 'Стабилизировать ядро',
      'outcomeTitle': 'Стабильный резонанс',
      'outcomeSummary': 'Ядро перестало разрушаться.',
      'pilot': <String, dynamic>{
        'pilotId': 'navigator-v1',
        'name': 'Навигатор',
        'level': 1,
        'experienceGained': 30,
        'currentExperience': 90,
        'nextLevelExperience': 100,
        'version': 2,
      },
      'pet': <String, dynamic>{
        'petId': 'spark-v1',
        'name': 'Искра',
        'level': 1,
        'bondGained': 8,
        'bond': 23,
        'version': 2,
      },
      'material': <String, dynamic>{
        'itemId': 'lumen-shard',
        'name': 'Люминовый осколок',
        'description': 'Стабильный фрагмент светового ядра.',
        'quantityGained': 2,
        'quantityAfter': 2,
        'version': 1,
      },
      'nextNode': <String, dynamic>{
        'nodeId': 'ash-orbit',
        'name': 'Пепельная орбита',
      },
      'resolvedAt': '2026-07-26T06:00:00Z',
    };

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);

    expect(snapshot.currentNodeId, 'ash-orbit');
    expect(snapshot.unlockedEvent, isNull);
    expect(snapshot.pendingEventResult?.eventId, 'echo-vault-v1');
    expect(snapshot.pendingEventResult?.material?.quantityAfter, 2);
    expect(snapshot.pendingEventResult?.nextNode?.nodeId, 'ash-orbit');
    expect(snapshot.inventory, hasLength(1));
    expect(snapshot.inventory.first.itemId, 'lumen-shard');
    expect(snapshot.inventory.first.quantity, 2);
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

  test('crafting recipe and unique inventory item are mapped additively', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response['inventory'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'itemId': 'resonance-compass',
        'name': 'Резонансный компас',
        'description': 'Уникальный прибор.',
        'quantity': 1,
        'version': 1,
        'kind': 'UNIQUE',
      },
    ];
    response['craftingRecipes'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'recipeId': 'resonance-compass-v1',
        'recipeVersion': '1',
        'name': 'Собрать резонансный компас',
        'description': 'Соединить материалы.',
        'status': 'CRAFTED',
        'ingredients': <Map<String, dynamic>>[
          <String, dynamic>{
            'itemId': 'lumen-shard',
            'name': 'Люминовый осколок',
            'requiredQuantity': 2,
            'availableQuantity': 1,
          },
          <String, dynamic>{
            'itemId': 'echo-thread',
            'name': 'Нить эха',
            'requiredQuantity': 1,
            'availableQuantity': 0,
          },
        ],
        'result': <String, dynamic>{
          'itemId': 'resonance-compass',
          'name': 'Резонансный компас',
          'description': 'Уникальный прибор.',
          'kind': 'UNIQUE',
        },
      },
    ];

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);

    expect(snapshot.inventory.single.isUnique, isTrue);
    expect(snapshot.craftingRecipes.single.isCrafted, isTrue);
    expect(snapshot.craftingRecipes.single.canCraft, isFalse);
    expect(snapshot.craftingRecipes.single.ingredients, hasLength(2));
  });

  test('item upgrade and unique rarity are mapped additively', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response['inventory'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'itemInstanceId': '33333333-3333-3333-3333-333333333333',
        'itemId': 'prism-sextant',
        'name': 'Призматический секстант',
        'description': 'Уникальный навигационный прибор.',
        'quantity': 1,
        'version': 1,
        'kind': 'UNIQUE',
        'rarity': 'UNCOMMON',
      },
    ];
    response['itemUpgrades'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'upgradeId': 'prism-sextant-calibration-v1',
        'upgradeVersion': '1',
        'name': 'Откалибровать призматический секстант',
        'description': 'Закрепить карту невидимого спектра.',
        'status': 'READY',
        'targetItemId': 'prism-sextant',
        'targetItemName': 'Призматический секстант',
        'requiredLevel': 1,
        'resultingLevel': 2,
        'initialRarity': 'UNCOMMON',
        'resultingRarity': 'RARE',
        'ingredients': <Map<String, dynamic>>[
          <String, dynamic>{
            'itemId': 'echo-thread',
            'name': 'Нить эха',
            'requiredQuantity': 2,
            'availableQuantity': 2,
          },
          <String, dynamic>{
            'itemId': 'ion-bloom',
            'name': 'Ионный цветок',
            'requiredQuantity': 1,
            'availableQuantity': 1,
          },
          <String, dynamic>{
            'itemId': 'prism-dust',
            'name': 'Призматическая пыль',
            'requiredQuantity': 1,
            'availableQuantity': 1,
          },
        ],
      },
    ];

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);

    expect(snapshot.inventory.single.rarity, 'UNCOMMON');
    expect(snapshot.itemUpgrades.single.canApply, isTrue);
    expect(snapshot.itemUpgrades.single.resultingLevel, 2);
    expect(snapshot.itemUpgrades.single.resultingRarity, 'RARE');
    expect(snapshot.itemUpgrades.single.ingredients, hasLength(3));
  });

  test('unknown item upgrade status is rejected', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response['itemUpgrades'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'upgradeId': 'prism-sextant-calibration-v1',
        'upgradeVersion': '1',
        'name': 'Откалибровать призматический секстант',
        'description': 'Закрепить карту невидимого спектра.',
        'status': 'FUTURE',
        'targetItemId': 'prism-sextant',
        'targetItemName': 'Призматический секстант',
        'requiredLevel': 1,
        'resultingLevel': 2,
        'initialRarity': 'UNCOMMON',
        'resultingRarity': 'RARE',
        'ingredients': <Map<String, dynamic>>[
          <String, dynamic>{
            'itemId': 'echo-thread',
            'name': 'Нить эха',
            'requiredQuantity': 2,
            'availableQuantity': 2,
          },
        ],
      },
    ];

    expect(() => HomeSnapshot.fromJson(response), throwsFormatException);
  });

  test('equipment and gated event choice are mapped additively', () {
    final Map<String, dynamic> response = _readyHomeResponse();
    response['contentVersion'] = 'chapter-1-v2';
    response['inventory'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'itemInstanceId': '33333333-3333-3333-3333-333333333333',
        'itemId': 'resonance-compass',
        'name': 'Резонансный компас',
        'description': 'Уникальный навигационный прибор.',
        'quantity': 1,
        'version': 1,
        'kind': 'UNIQUE',
        'equippableSlotId': 'NAVIGATION',
        'equippedSlotId': null,
      },
    ];
    response['equipment'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'slotId': 'NAVIGATION',
        'name': 'Навигационный прибор',
        'description': 'Инструмент, влияющий на доступные маршруты.',
        'status': 'EMPTY',
        'version': 0,
        'item': null,
      },
    ];
    final Map<String, dynamic> expedition =
        response['expedition'] as Map<String, dynamic>;
    final Map<String, dynamic> event =
        expedition['unlockedEvent'] as Map<String, dynamic>;
    event['lockedChoices'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'choiceId': 'follow-resonance',
        'title': 'Пойти по резонансу',
        'description': 'Настроить компас на скрытое отражение.',
        'pilotExperienceReward': 35,
        'petBondReward': 16,
        'availability': 'LOCKED',
        'requirement': <String, dynamic>{
          'type': 'EQUIPPED_ITEM',
          'slotId': 'NAVIGATION',
          'slotName': 'Навигационный прибор',
          'itemId': 'resonance-compass',
          'itemName': 'Резонансный компас',
          'minimumUpgradeLevel': 2,
          'description': 'Экипируйте компас, чтобы увидеть маршрут.',
        },
      },
    ];

    final HomeSnapshot snapshot = HomeSnapshot.fromJson(response);

    expect(snapshot.inventory.single.isEquippable, isTrue);
    expect(snapshot.inventory.single.isEquipped, isFalse);
    expect(snapshot.equipment.single.status, 'EMPTY');
    expect(snapshot.equipment.single.item, isNull);
    final HomeEventChoice gated = snapshot.unlockedEvent!.choices.last;
    expect(gated.isAvailable, isFalse);
    expect(gated.requirement?.itemId, 'resonance-compass');
    expect(gated.requirement?.slotId, 'NAVIGATION');
    expect(gated.requirement?.minimumUpgradeLevel, 2);
  });

  test('legacy choice requirement defaults to upgrade level one', () {
    final HomeChoiceRequirement requirement =
        HomeChoiceRequirement.fromJson(<String, dynamic>{
          'type': 'EQUIPPED_ITEM',
          'slotId': 'NAVIGATION',
          'slotName': 'Навигационный прибор',
          'itemId': 'resonance-compass',
          'itemName': 'Резонансный компас',
          'description': 'Экипируйте компас.',
        });

    expect(requirement.minimumUpgradeLevel, 1);
  });

  test('active pet choice requirement is mapped without client inference', () {
    final HomeChoiceRequirement requirement =
        HomeChoiceRequirement.fromJson(<String, dynamic>{
          'type': 'ACTIVE_PET',
          'slotId': 'ACTIVE_PET',
          'slotName': 'Активный питомец',
          'itemId': 'moss-v1',
          'itemName': 'Мох',
          'minimumUpgradeLevel': 1,
          'description':
              'Выберите Мха активным питомцем, чтобы укоренить маяк возврата.',
        });

    expect(requirement.type, 'ACTIVE_PET');
    expect(requirement.slotId, 'ACTIVE_PET');
    expect(requirement.itemId, 'moss-v1');
    expect(requirement.itemName, 'Мох');
    expect(requirement.minimumUpgradeLevel, 1);
    expect(requirement.minimumEvolutionStage, 0);
    expect(requirement.description, contains('Выберите Мха'));
  });

  test('adult pet requirement preserves authoritative evolution stage', () {
    final HomeChoiceRequirement requirement = HomeChoiceRequirement.fromJson(
      <String, dynamic>{
        'type': 'ACTIVE_PET',
        'slotId': 'ACTIVE_PET',
        'slotName': 'Активный питомец',
        'itemId': 'spark-v1',
        'itemName': 'Искра-звездочёт',
        'minimumUpgradeLevel': 1,
        'minimumEvolutionStage': 2,
        'description': 'Выберите взрослую Искру-звездочёта активным питомцем.',
      },
    );

    expect(requirement.minimumEvolutionStage, 2);
    expect(requirement.itemName, 'Искра-звездочёт');
  });

  test('pilot skill choice requirement is mapped without client inference', () {
    final HomeChoiceRequirement requirement = HomeChoiceRequirement.fromJson(
      <String, dynamic>{
        'type': 'UNLOCKED_SKILL',
        'slotId': 'PILOT_SKILL',
        'slotName': 'Навык пилота',
        'itemId': 'signal-reader',
        'itemName': 'Чтение сигналов',
        'minimumUpgradeLevel': 1,
        'minimumEvolutionStage': 0,
        'description':
            'Откройте навык «Чтение сигналов», чтобы расшифровать скрытый хор.',
      },
    );

    expect(requirement.type, 'UNLOCKED_SKILL');
    expect(requirement.slotId, 'PILOT_SKILL');
    expect(requirement.itemId, 'signal-reader');
    expect(requirement.itemName, 'Чтение сигналов');
    expect(requirement.minimumUpgradeLevel, 1);
    expect(requirement.minimumEvolutionStage, 0);
  });

  test('negative pet evolution requirement is rejected', () {
    expect(
      () => HomeChoiceRequirement.fromJson(<String, dynamic>{
        'type': 'ACTIVE_PET',
        'slotId': 'ACTIVE_PET',
        'slotName': 'Активный питомец',
        'itemId': 'spark-v1',
        'itemName': 'Искра',
        'minimumEvolutionStage': -1,
        'description': 'Недоступно.',
      }),
      throwsFormatException,
    );
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
    'dailyGoal': 3250,
    'dailyGoalPolicy': <String, dynamic>{
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
    },
    'availableEnergy': 38,
    'activityStateVersion': 1,
    'economyVersion': 2,
    'lastActivitySyncAt': '2026-07-26T05:55:00Z',
    'serverTime': '2026-07-26T06:00:00Z',
    'contentVersion': 'chapter-1-v1',
    'pilot': <String, dynamic>{
      'name': 'Навигатор',
      'level': 1,
      'currentExperience': 20,
      'nextLevelExperience': 100,
      'specialization': 'Не выбрана',
    },
    'pet': <String, dynamic>{
      'petId': 'spark-v1',
      'name': 'Искра',
      'species': 'Люмин',
      'level': 1,
      'bond': 10,
      'evolutionStage': 0,
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
      'journeyNumber': 2,
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
            'materialReward': null,
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
