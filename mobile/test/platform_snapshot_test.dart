import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';

import 'support/platform_fixture.dart';

void main() {
  test('maps authoritative platform snapshot and computed progress', () {
    final PlatformSnapshot snapshot = platformSnapshot();

    expect(snapshot.contentVersion, 'chapter-1-v1');
    expect(snapshot.content.chapterNodes, 18);
    expect(snapshot.userState.pets, hasLength(3));
    expect(snapshot.activePet.petId, 'spark-v1');
    expect(snapshot.activePet.canEvolve, isTrue);
    expect(snapshot.evolvableCompanionCount, 1);
    expect(snapshot.activePet.maximumEvolutionStage, 1);
    expect(snapshot.activePet.isFullyEvolved, isFalse);
    expect(snapshot.activePet.remainingEvolutionBond, 0);
    final PlatformPet moss = snapshot.userState.pets.singleWhere(
      (PlatformPet pet) => pet.petId == 'moss-v1',
    );
    expect(moss.remainingEvolutionBond, 33);
    final Map<String, dynamic> multipleEvolvableJson = platformSnapshotJson();
    final Map<String, dynamic> multipleEvolvableState =
        multipleEvolvableJson['userState']! as Map<String, dynamic>;
    final List<dynamic> multipleEvolvablePets =
        multipleEvolvableState['pets']! as List<dynamic>;
    (multipleEvolvablePets[1] as Map<String, dynamic>)['bond'] = 45;
    final PlatformSnapshot multipleEvolvable = PlatformSnapshot.fromJson(
      multipleEvolvableJson,
    );
    expect(multipleEvolvable.evolvableCompanionCount, 2);

    final Map<String, dynamic> zeroEvolvableJson = platformSnapshotJson();
    final Map<String, dynamic> zeroEvolvableState =
        zeroEvolvableJson['userState']! as Map<String, dynamic>;
    final List<dynamic> zeroEvolvablePets =
        zeroEvolvableState['pets']! as List<dynamic>;
    (zeroEvolvablePets[0] as Map<String, dynamic>)['evolutionStage'] = 1;
    final PlatformSnapshot zeroEvolvable = PlatformSnapshot.fromJson(
      zeroEvolvableJson,
    );
    expect(zeroEvolvable.evolvableCompanionCount, 0);
    expect(snapshot.weeklyRouteRemaining, 60);
    expect(snapshot.unlockedCatalogAchievementCount, 0);
    expect(snapshot.remainingCatalogAchievementCount, 2);
    expect(snapshot.unlockedCatalogSkillCount, 1);
    expect(snapshot.remainingCatalogSkillCount, 1);
    expect(snapshot.unlockableCatalogSkillCount, 1);
    final PlatformSnapshot completeSkills = platformSnapshot(
      unlockedSkills: const <String>[
        'steady-step',
        'trail-memory',
        'retired-skill',
      ],
    );
    expect(completeSkills.unlockedCatalogSkillCount, 2);
    expect(completeSkills.remainingCatalogSkillCount, 0);
    expect(completeSkills.unlockableCatalogSkillCount, 0);
    final Map<String, dynamic> multipleUnlockableJson = platformSnapshotJson();
    final Map<String, dynamic> multipleUnlockableContent =
        multipleUnlockableJson['content']! as Map<String, dynamic>;
    final List<dynamic> multipleUnlockableSkills =
        multipleUnlockableContent['skills']! as List<dynamic>;
    multipleUnlockableSkills.add(<String, dynamic>{
      'skillId': 'echo-navigation',
      'name': 'Эхо-навигация',
      'description': 'Усиливает чтение маршрута.',
      'requiredSeasonXp': 200,
    });
    final PlatformSnapshot multipleUnlockable = PlatformSnapshot.fromJson(
      multipleUnlockableJson,
    );
    expect(multipleUnlockable.unlockableCatalogSkillCount, 2);
    expect(snapshot.ownedCatalogCosmeticCount, 1);
    expect(snapshot.remainingCatalogCosmeticCount, 1);
    final PlatformSnapshot completeCosmetics = platformSnapshot(
      ownedCosmetics: const <String>[
        'pilot-scarf',
        'spark-halo',
        'retired-cosmetic',
      ],
    );
    expect(completeCosmetics.ownedCatalogCosmeticCount, 2);
    expect(completeCosmetics.remainingCatalogCosmeticCount, 0);
    expect(snapshot.completedCatalogOnboardingStepCount, 1);
    expect(snapshot.remainingCatalogOnboardingStepCount, 5);
    expect(snapshot.claimableQuestRewardCount, 1);

    final Map<String, dynamic> multipleClaimableJson = platformSnapshotJson();
    final Map<String, dynamic> multipleClaimableState =
        multipleClaimableJson['userState']! as Map<String, dynamic>;
    final List<dynamic> multipleClaimableQuests =
        multipleClaimableState['quests']! as List<dynamic>;
    (multipleClaimableQuests[1] as Map<String, dynamic>)['ready'] = true;
    final PlatformSnapshot multipleClaimable = PlatformSnapshot.fromJson(
      multipleClaimableJson,
    );
    expect(multipleClaimable.claimableQuestRewardCount, 2);

    final Map<String, dynamic> zeroClaimableJson = platformSnapshotJson();
    final Map<String, dynamic> zeroClaimableState =
        zeroClaimableJson['userState']! as Map<String, dynamic>;
    final List<dynamic> zeroClaimableQuests =
        zeroClaimableState['quests']! as List<dynamic>;
    (zeroClaimableQuests[0] as Map<String, dynamic>)['claimed'] = true;
    final PlatformSnapshot zeroClaimable = PlatformSnapshot.fromJson(
      zeroClaimableJson,
    );
    expect(zeroClaimable.claimableQuestRewardCount, 0);

    final PlatformSnapshot completeCollection = platformSnapshot(
      achievements: const <String>[
        'onboarding-complete',
        'season-level-3',
        'season-reward-1',
      ],
    );
    expect(completeCollection.unlockedCatalogAchievementCount, 2);
    expect(completeCollection.remainingCatalogAchievementCount, 0);
    final PlatformSnapshot completedJourney = platformSnapshot(
      completedOnboardingSteps: const <String>[
        'welcome',
        'health-permission',
        'first-sync',
        'pet-selection',
        'first-expedition',
        'first-event',
        'retired-step',
      ],
    );
    expect(completedJourney.completedCatalogOnboardingStepCount, 6);
    expect(completedJourney.remainingCatalogOnboardingStepCount, 0);
    expect(snapshot.weeklyRouteProgressValue, 0.4);
    expect(snapshot.onboardingProgressValue, closeTo(1 / 6, 0.0001));
    expect(snapshot.content.season.xpPerLevel, 100);
    expect(snapshot.claimableSeasonLevel, 2);
    expect(snapshot.unclaimedSeasonRewardLevels, <int>[2]);
    expect(snapshot.unclaimedSeasonRewardCount, 1);
    expect(snapshot.nextSeasonRewardLevel, 3);
    expect(snapshot.remainingSeasonXpToNextReward, 80);
    expect(snapshot.remoteConfig.sandboxPaymentsEnabled, isTrue);
    expect(snapshot.userState.hasSuccessfulActivitySync, isTrue);
    final PlatformQuest completedQuest = snapshot.userState.quests.singleWhere(
      (PlatformQuest quest) => quest.questId == 'walk-3000',
    );
    final PlatformQuest activeQuest = snapshot.userState.quests.singleWhere(
      (PlatformQuest quest) => quest.questId == 'resolve-3',
    );
    expect(completedQuest.remainingProgress, 0);
    expect(activeQuest.remainingProgress, 1);
    final PlatformSkill trailMemory = snapshot.content.skills.singleWhere(
      (PlatformSkill skill) => skill.skillId == 'trail-memory',
    );
    expect(trailMemory.remainingSeasonXp(40), 60);
    expect(trailMemory.remainingSeasonXp(snapshot.userState.seasonXp), 0);
    expect(snapshot.userState.equippedCosmetics, const <String, String>{
      'PILOT': 'pilot-scarf',
    });
    expect(snapshot.userState.equippedCosmeticIds, const <String>{
      'pilot-scarf',
    });
  });

  test('rejects a negative server skill XP requirement', () {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> content = Map<String, dynamic>.from(
      json['content']! as Map<String, dynamic>,
    );
    final List<dynamic> skills = List<dynamic>.from(content['skills']! as List);
    skills[1] = <String, dynamic>{
      ...Map<String, dynamic>.from(skills[1] as Map),
      'requiredSeasonXp': -1,
    };
    content['skills'] = skills;
    json['content'] = content;

    expect(
      () => PlatformSnapshot.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('maps the additive adult evolution contract', () {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState = Map<String, dynamic>.from(
      json['userState']! as Map<String, dynamic>,
    );
    final List<dynamic> pets = List<dynamic>.from(userState['pets']! as List);
    pets[0] = <String, dynamic>{
      ...Map<String, dynamic>.from(pets[0] as Map),
      'name': 'Искра-проводник',
      'level': 2,
      'bond': 140,
      'evolutionStage': 1,
      'evolutionBond': 140,
      'maximumEvolutionStage': 2,
    };
    userState['pets'] = pets;
    json['userState'] = userState;

    final PlatformPet pet = PlatformSnapshot.fromJson(json).activePet;

    expect(pet.evolutionStage, 1);
    expect(pet.maximumEvolutionStage, 2);
    expect(pet.canEvolve, isTrue);
    expect(pet.isFullyEvolved, isFalse);
    expect(pet.remainingEvolutionBond, 0);
  });

  test('rejects an evolution stage above the server maximum', () {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState = Map<String, dynamic>.from(
      json['userState']! as Map<String, dynamic>,
    );
    final List<dynamic> pets = List<dynamic>.from(userState['pets']! as List);
    pets[0] = <String, dynamic>{
      ...Map<String, dynamic>.from(pets[0] as Map),
      'evolutionStage': 2,
      'maximumEvolutionStage': 1,
    };
    userState['pets'] = pets;
    json['userState'] = userState;

    expect(
      () => PlatformSnapshot.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('maps a persisted adult pet after content rollback', () {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState = Map<String, dynamic>.from(
      json['userState']! as Map<String, dynamic>,
    );
    final List<dynamic> pets = List<dynamic>.from(userState['pets']! as List);
    pets[0] = <String, dynamic>{
      ...Map<String, dynamic>.from(pets[0] as Map),
      'level': 3,
      'bond': 160,
      'evolutionStage': 2,
      'maximumEvolutionStage': 2,
    };
    userState['pets'] = pets;
    json['userState'] = userState;

    final PlatformPet pet = PlatformSnapshot.fromJson(json).activePet;

    expect(pet.evolutionStage, 2);
    expect(pet.maximumEvolutionStage, 2);
    expect(pet.canEvolve, isFalse);
    expect(pet.isFullyEvolved, isTrue);
    expect(pet.remainingEvolutionBond, 0);
  });

  test('maps independent server-owned cosmetic slots', () {
    final PlatformSnapshot snapshot = platformSnapshot(
      ownedCosmetics: const <String>['pilot-scarf', 'spark-halo'],
      activeCosmeticId: 'spark-halo',
      equippedCosmetics: const <String, String>{
        'PILOT': 'pilot-scarf',
        'PET': 'spark-halo',
      },
    );

    expect(snapshot.userState.equippedCosmetics, const <String, String>{
      'PILOT': 'pilot-scarf',
      'PET': 'spark-halo',
    });
    expect(snapshot.userState.equippedCosmeticIds, const <String>{
      'pilot-scarf',
      'spark-halo',
    });
  });

  test('falls back to the legacy cosmetic pointer when slots are absent', () {
    final Map<String, dynamic> json = platformSnapshotJson(
      ownedCosmetics: const <String>['pilot-scarf', 'spark-halo'],
      activeCosmeticId: 'spark-halo',
    );
    final Map<String, dynamic> userState = Map<String, dynamic>.from(
      json['userState']! as Map<String, dynamic>,
    )..remove('equippedCosmetics');
    json['userState'] = userState;

    final PlatformSnapshot snapshot = PlatformSnapshot.fromJson(json);

    expect(snapshot.userState.equippedCosmetics, isEmpty);
    expect(snapshot.userState.equippedCosmeticIds, const <String>{
      'spark-halo',
    });
  });

  test('keeps an explicit empty cosmetic slot mapping authoritative', () {
    final PlatformSnapshot snapshot = platformSnapshot(
      equippedCosmetics: const <String, String>{},
    );

    expect(snapshot.userState.activeCosmeticId, 'pilot-scarf');
    expect(snapshot.userState.equippedCosmeticIds, isEmpty);
  });

  test('rejects equipped cosmetics that are not owned', () {
    expect(
      () => platformSnapshot(
        equippedCosmetics: const <String, String>{'PET': 'spark-halo'},
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects an unsupported equipped cosmetic slot', () {
    expect(
      () => platformSnapshot(
        equippedCosmetics: const <String, String>{'AURA': 'pilot-scarf'},
      ),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('неподдерживаемый slot AURA'),
        ),
      ),
    );
  });

  test('rejects an equipped cosmetic missing from the catalog', () {
    expect(
      () => platformSnapshot(
        ownedCosmetics: const <String>['pilot-scarf', 'future-scarf'],
        equippedCosmetics: const <String, String>{'PILOT': 'future-scarf'},
      ),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('future-scarf, отсутствующий в content.cosmetics'),
        ),
      ),
    );
  });

  test('rejects an equipped cosmetic assigned to the wrong slot', () {
    expect(
      () => platformSnapshot(
        ownedCosmetics: const <String>['pilot-scarf', 'spark-halo'],
        equippedCosmetics: const <String, String>{'PILOT': 'spark-halo'},
      ),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('PILOT не совпадает со slot PET для spark-halo'),
        ),
      ),
    );
  });

  test('falls back to lifetime steps for an older platform response', () {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState = Map<String, dynamic>.from(
      json['userState']! as Map<String, dynamic>,
    )..remove('hasSuccessfulActivitySync');
    json['userState'] = userState;

    final PlatformSnapshot snapshot = PlatformSnapshot.fromJson(json);

    expect(snapshot.userState.hasSuccessfulActivitySync, isTrue);
  });

  test('caps claimable season level by content definition', () {
    final PlatformSnapshot snapshot = platformSnapshot(seasonXp: 5000);

    expect(snapshot.claimableSeasonLevel, 10);
    expect(snapshot.nextSeasonRewardLevel, isNull);
    expect(snapshot.remainingSeasonXpToNextReward, isNull);
    expect(snapshot.unclaimedSeasonRewardLevels, <int>[
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
    ]);
  });

  test('counts only earned unclaimed season reward receipts', () {
    final PlatformSnapshot snapshot = platformSnapshot(
      seasonXp: 425,
      achievements: const <String>[
        'season-reward-1',
        'season-reward-3',
        'season-level-3',
        'season-reward-future',
      ],
    );

    expect(snapshot.unclaimedSeasonRewardLevels, <int>[2, 4]);
    expect(snapshot.unclaimedSeasonRewardCount, 2);
  });

  test('starts the next season reward threshold after an exact boundary', () {
    final PlatformSnapshot snapshot = platformSnapshot(seasonXp: 100);

    expect(snapshot.claimableSeasonLevel, 1);
    expect(snapshot.nextSeasonRewardLevel, 2);
    expect(snapshot.remainingSeasonXpToNextReward, 100);
  });

  test('uses the server-authored season reward cadence', () {
    final PlatformSnapshot snapshot = platformSnapshot(
      seasonXp: 225,
      seasonXpPerLevel: 75,
    );

    expect(snapshot.claimableSeasonLevel, 3);
    expect(snapshot.nextSeasonRewardLevel, 4);
    expect(snapshot.remainingSeasonXpToNextReward, 75);
  });

  test('keeps legacy season claims without inferring reward guidance', () {
    final PlatformSnapshot snapshot = platformSnapshot(
      seasonXp: 220,
      seasonXpPerLevel: null,
    );

    expect(snapshot.content.season.xpPerLevel, isNull);
    expect(snapshot.claimableSeasonLevel, 2);
    expect(snapshot.nextSeasonRewardLevel, isNull);
    expect(snapshot.remainingSeasonXpToNextReward, isNull);
    expect(snapshot.unclaimedSeasonRewardLevels, isNull);
    expect(snapshot.unclaimedSeasonRewardCount, isNull);
  });

  test('rejects a non-positive season XP threshold', () {
    final Map<String, dynamic> json = platformSnapshotJson(seasonXpPerLevel: 0);

    expect(
      () => PlatformSnapshot.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects content version mismatch', () {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> content = Map<String, dynamic>.from(
      json['content']! as Map<String, dynamic>,
    );
    content['contentVersion'] = 'chapter-other';
    json['content'] = content;

    expect(
      () => PlatformSnapshot.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects inconsistent active pet flags', () {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState = Map<String, dynamic>.from(
      json['userState']! as Map<String, dynamic>,
    );
    final List<dynamic> pets = List<dynamic>.from(
      userState['pets']! as List<dynamic>,
    );
    final Map<String, dynamic> first = Map<String, dynamic>.from(
      pets.first as Map<String, dynamic>,
    );
    first['active'] = false;
    pets[0] = first;
    userState['pets'] = pets;
    json['userState'] = userState;

    expect(
      () => PlatformSnapshot.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });
}
