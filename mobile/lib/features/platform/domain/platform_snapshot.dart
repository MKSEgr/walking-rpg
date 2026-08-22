import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';

const Set<String> _supportedCosmeticSlots = <String>{'PILOT', 'PET', 'PROFILE'};

class PlatformSnapshot {
  PlatformSnapshot({
    required this.contentVersion,
    required this.stateVersion,
    required this.userState,
    required this.content,
    required this.remoteConfig,
    required this.serverTime,
    this.cacheMetadata,
  }) {
    if (stateVersion < 0) {
      throw ArgumentError.value(
        stateVersion,
        'stateVersion',
        'Версия состояния не может быть отрицательной',
      );
    }
    _validateEquippedCosmetics(userState, content);
  }

  factory PlatformSnapshot.fromJson(
    Map<String, dynamic> json, {
    CachedReadMetadata? cacheMetadata,
  }) {
    final PlatformContent content = PlatformContent.fromJson(
      _readMap(json, 'content'),
    );
    final String contentVersion = _readString(json, 'contentVersion');
    if (content.contentVersion != null &&
        content.contentVersion != contentVersion) {
      throw const FormatException(
        'contentVersion не совпадает с content.contentVersion',
      );
    }

    final int stateVersion = _readInt(json, 'stateVersion');
    if (stateVersion < 0) {
      throw const FormatException('stateVersion не может быть отрицательной');
    }

    return PlatformSnapshot(
      contentVersion: contentVersion,
      stateVersion: stateVersion,
      userState: PlatformUserState.fromJson(_readMap(json, 'userState')),
      content: content,
      remoteConfig: PlatformRemoteConfig.fromJson(
        _readMap(json, 'remoteConfig'),
      ),
      serverTime: _readString(json, 'serverTime'),
      cacheMetadata: cacheMetadata,
    );
  }

  final String contentVersion;
  final int stateVersion;
  final PlatformUserState userState;
  final PlatformContent content;
  final PlatformRemoteConfig remoteConfig;
  final String serverTime;
  final CachedReadMetadata? cacheMetadata;

  bool get isCached => cacheMetadata != null;

  int get unlockedCatalogAchievementCount {
    final Set<String> catalogIds = content.achievements
        .map((PlatformAchievement achievement) => achievement.achievementId)
        .toSet();
    return userState.achievements.intersection(catalogIds).length;
  }

  int get remainingCatalogAchievementCount {
    return content.achievements.length - unlockedCatalogAchievementCount;
  }

  int get ownedCatalogCosmeticCount {
    final Set<String> catalogIds = content.cosmetics
        .map((PlatformCosmetic cosmetic) => cosmetic.cosmeticId)
        .toSet();
    return userState.ownedCosmetics.intersection(catalogIds).length;
  }

  int get remainingCatalogCosmeticCount {
    return content.cosmetics.length - ownedCatalogCosmeticCount;
  }

  int get completedCatalogOnboardingStepCount {
    return content.onboardingSteps
        .where(userState.completedOnboardingSteps.contains)
        .length;
  }

  int get remainingCatalogOnboardingStepCount {
    return content.onboardingSteps.length - completedCatalogOnboardingStepCount;
  }

  int get weeklyRouteRemaining {
    final int remaining =
        userState.weeklyRouteRequiredEnergy - userState.weeklyRouteProgress;
    return remaining < 0 ? 0 : remaining;
  }

  double get weeklyRouteProgressValue {
    final int required = userState.weeklyRouteRequiredEnergy;
    if (required <= 0) {
      return 0;
    }
    return (userState.weeklyRouteProgress / required)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double get onboardingProgressValue {
    if (content.onboardingSteps.isEmpty) {
      return 1;
    }
    return (userState.completedOnboardingSteps.length /
            content.onboardingSteps.length)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  PlatformPet get activePet {
    return userState.pets.firstWhere(
      (PlatformPet pet) => pet.petId == userState.activePetId,
    );
  }

  int get claimableSeasonLevel {
    final int earnedLevel =
        userState.seasonXp ~/ (content.season.xpPerLevel ?? 100);
    return earnedLevel < content.season.levels
        ? earnedLevel
        : content.season.levels;
  }

  List<int>? get unclaimedSeasonRewardLevels {
    if (content.season.xpPerLevel == null) {
      return null;
    }
    return List<int>.unmodifiable(<int>[
      for (int level = 1; level <= claimableSeasonLevel; level += 1)
        if (!userState.achievements.contains('season-reward-$level')) level,
    ]);
  }

  int? get unclaimedSeasonRewardCount => unclaimedSeasonRewardLevels?.length;

  int? get nextSeasonRewardLevel {
    final int? xpPerLevel = content.season.xpPerLevel;
    if (xpPerLevel == null) {
      return null;
    }
    final int nextLevel = userState.seasonXp ~/ xpPerLevel + 1;
    return nextLevel <= content.season.levels ? nextLevel : null;
  }

  int? get remainingSeasonXpToNextReward {
    final int? xpPerLevel = content.season.xpPerLevel;
    final int? nextLevel = nextSeasonRewardLevel;
    if (xpPerLevel == null || nextLevel == null) {
      return null;
    }
    return nextLevel * xpPerLevel - userState.seasonXp;
  }
}

class PlatformUserState {
  PlatformUserState({
    required this.activePetId,
    required List<PlatformPet> pets,
    required Set<String> completedOnboardingSteps,
    required this.onboardingComplete,
    required Set<String> unlockedSkills,
    required List<PlatformQuest> quests,
    required Set<String> claimedQuests,
    required Set<String> achievements,
    required this.seasonXp,
    required this.seasonLevel,
    required this.weeklyRouteProgress,
    required this.weeklyRouteRequiredEnergy,
    required this.squad,
    required Set<String> ownedCosmetics,
    required this.activeCosmeticId,
    Map<String, String>? equippedCosmetics,
    required Map<String, String> experimentAssignments,
    required this.resolvedEventCount,
    required this.totalAcceptedSteps,
    required this.hasSuccessfulActivitySync,
  }) : pets = List<PlatformPet>.unmodifiable(pets),
       completedOnboardingSteps = Set<String>.unmodifiable(
         completedOnboardingSteps,
       ),
       unlockedSkills = Set<String>.unmodifiable(unlockedSkills),
       quests = List<PlatformQuest>.unmodifiable(quests),
       claimedQuests = Set<String>.unmodifiable(claimedQuests),
       achievements = Set<String>.unmodifiable(achievements),
       ownedCosmetics = Set<String>.unmodifiable(ownedCosmetics),
       equippedCosmetics = Map<String, String>.unmodifiable(
         equippedCosmetics ?? const <String, String>{},
       ),
       equippedCosmeticIds = Set<String>.unmodifiable(
         equippedCosmetics?.values ??
             (activeCosmeticId == null
                 ? const <String>[]
                 : <String>[activeCosmeticId]),
       ),
       experimentAssignments = Map<String, String>.unmodifiable(
         experimentAssignments,
       ) {
    if (seasonXp < 0 ||
        seasonLevel <= 0 ||
        weeklyRouteProgress < 0 ||
        weeklyRouteRequiredEnergy <= 0 ||
        resolvedEventCount < 0 ||
        totalAcceptedSteps < 0) {
      throw const FormatException(
        'Platform userState содержит отрицательный progress',
      );
    }
    final List<PlatformPet> activePets = this.pets
        .where((PlatformPet pet) => pet.active)
        .toList(growable: false);
    if (!this.pets.any((PlatformPet pet) => pet.petId == activePetId)) {
      throw const FormatException('activePetId отсутствует в pets');
    }
    if (activePets.length != 1 || activePets.single.petId != activePetId) {
      throw const FormatException(
        'activePetId не согласован с active-флагом питомцев',
      );
    }
    if (activeCosmeticId != null &&
        !this.ownedCosmetics.contains(activeCosmeticId)) {
      throw const FormatException(
        'activeCosmeticId отсутствует в ownedCosmetics',
      );
    }
    if (this.equippedCosmetics.keys.any((String slot) => slot.trim().isEmpty)) {
      throw const FormatException('equippedCosmetics содержит пустой slot');
    }
    if (!this.ownedCosmetics.containsAll(equippedCosmeticIds)) {
      throw const FormatException(
        'equippedCosmetics содержит косметику не из ownedCosmetics',
      );
    }
  }

  factory PlatformUserState.fromJson(Map<String, dynamic> json) {
    final List<PlatformPet> pets = _readList(json, 'pets')
        .map((Object? value) => PlatformPet.fromJson(_asMap(value, 'pets[]')))
        .toList(growable: false);
    final List<PlatformQuest> quests = _readList(json, 'quests')
        .map(
          (Object? value) => PlatformQuest.fromJson(_asMap(value, 'quests[]')),
        )
        .toList(growable: false);
    final Object? rawSquad = json['squad'];
    final int totalAcceptedSteps = _readInt(json, 'totalAcceptedSteps');
    final bool hasSuccessfulActivitySync =
        json.containsKey('hasSuccessfulActivitySync')
        ? _readBool(json, 'hasSuccessfulActivitySync')
        : totalAcceptedSteps > 0;

    return PlatformUserState(
      activePetId: _readString(json, 'activePetId'),
      pets: pets,
      completedOnboardingSteps: _readStringSet(
        json,
        'completedOnboardingSteps',
      ),
      onboardingComplete: _readBool(json, 'onboardingComplete'),
      unlockedSkills: _readStringSet(json, 'unlockedSkills'),
      quests: quests,
      claimedQuests: _readStringSet(json, 'claimedQuests'),
      achievements: _readStringSet(json, 'achievements'),
      seasonXp: _readInt(json, 'seasonXp'),
      seasonLevel: _readInt(json, 'seasonLevel'),
      weeklyRouteProgress: _readInt(json, 'weeklyRouteProgress'),
      weeklyRouteRequiredEnergy: _readInt(json, 'weeklyRouteRequiredEnergy'),
      squad: rawSquad == null
          ? null
          : PlatformSquad.fromJson(_asMap(rawSquad, 'squad')),
      ownedCosmetics: _readStringSet(json, 'ownedCosmetics'),
      activeCosmeticId: _readNullableString(json, 'activeCosmeticId'),
      equippedCosmetics: json.containsKey('equippedCosmetics')
          ? _readStringMap(json, 'equippedCosmetics')
          : null,
      experimentAssignments: _readStringMap(json, 'experimentAssignments'),
      resolvedEventCount: _readInt(json, 'resolvedEventCount'),
      totalAcceptedSteps: totalAcceptedSteps,
      hasSuccessfulActivitySync: hasSuccessfulActivitySync,
    );
  }

  final String activePetId;
  final List<PlatformPet> pets;
  final Set<String> completedOnboardingSteps;
  final bool onboardingComplete;
  final Set<String> unlockedSkills;
  final List<PlatformQuest> quests;
  final Set<String> claimedQuests;
  final Set<String> achievements;
  final int seasonXp;
  final int seasonLevel;
  final int weeklyRouteProgress;
  final int weeklyRouteRequiredEnergy;
  final PlatformSquad? squad;
  final Set<String> ownedCosmetics;
  final String? activeCosmeticId;
  final Map<String, String> equippedCosmetics;
  final Set<String> equippedCosmeticIds;
  final Map<String, String> experimentAssignments;
  final int resolvedEventCount;
  final int totalAcceptedSteps;
  final bool hasSuccessfulActivitySync;
}

class PlatformPet {
  const PlatformPet({
    required this.petId,
    required this.name,
    required this.species,
    required this.trait,
    required this.level,
    required this.bond,
    required this.evolutionStage,
    required this.evolutionBond,
    required this.maximumEvolutionStage,
    required this.active,
  });

  factory PlatformPet.fromJson(Map<String, dynamic> json) {
    final int level = _readInt(json, 'level');
    final int bond = _readInt(json, 'bond');
    final int evolutionStage = _readInt(json, 'evolutionStage');
    final int evolutionBond = _readInt(json, 'evolutionBond');
    final int maximumEvolutionStage = _readOptionalInt(
      json,
      'maximumEvolutionStage',
      1,
    );
    if (level <= 0 ||
        bond < 0 ||
        evolutionStage < 0 ||
        evolutionBond <= 0 ||
        maximumEvolutionStage <= 0 ||
        evolutionStage > maximumEvolutionStage) {
      throw const FormatException('Некорректный progress питомца');
    }
    return PlatformPet(
      petId: _readString(json, 'petId'),
      name: _readString(json, 'name'),
      species: _readString(json, 'species'),
      trait: _readOptionalString(
        json,
        'trait',
        'Спутник для исследования маршрутов.',
      ),
      level: level,
      bond: bond,
      evolutionStage: evolutionStage,
      evolutionBond: evolutionBond,
      maximumEvolutionStage: maximumEvolutionStage,
      active: _readBool(json, 'active'),
    );
  }

  final String petId;
  final String name;
  final String species;
  final String trait;
  final int level;
  final int bond;
  final int evolutionStage;
  final int evolutionBond;
  final int maximumEvolutionStage;
  final bool active;

  bool get canEvolve =>
      evolutionStage < maximumEvolutionStage && bond >= evolutionBond;

  bool get isFullyEvolved => evolutionStage >= maximumEvolutionStage;

  int get remainingEvolutionBond {
    if (isFullyEvolved || canEvolve) {
      return 0;
    }
    final int remaining = evolutionBond - bond;
    return remaining < 0 ? 0 : remaining;
  }
}

class PlatformQuest {
  const PlatformQuest({
    required this.questId,
    required this.name,
    required this.metric,
    required this.progress,
    required this.target,
    required this.ready,
    required this.claimed,
    required this.seasonXpReward,
    required this.petBondReward,
  });

  factory PlatformQuest.fromJson(Map<String, dynamic> json) {
    final int progress = _readInt(json, 'progress');
    final int target = _readInt(json, 'target');
    final int seasonXpReward = _readInt(json, 'seasonXpReward');
    final int petBondReward = _readInt(json, 'petBondReward');
    if (progress < 0 ||
        target <= 0 ||
        seasonXpReward < 0 ||
        petBondReward < 0) {
      throw const FormatException('Некорректный progress задания');
    }
    return PlatformQuest(
      questId: _readString(json, 'questId'),
      name: _readString(json, 'name'),
      metric: _readString(json, 'metric'),
      progress: progress,
      target: target,
      ready: _readBool(json, 'ready'),
      claimed: _readBool(json, 'claimed'),
      seasonXpReward: seasonXpReward,
      petBondReward: petBondReward,
    );
  }

  final String questId;
  final String name;
  final String metric;
  final int progress;
  final int target;
  final bool ready;
  final bool claimed;
  final int seasonXpReward;
  final int petBondReward;

  double get progressValue {
    if (target <= 0) {
      return 0;
    }
    return (progress / target).clamp(0.0, 1.0).toDouble();
  }

  int get remainingProgress {
    final int remaining = target - progress;
    return remaining < 0 ? 0 : remaining;
  }
}

class PlatformSquad {
  PlatformSquad({
    required this.squadId,
    required this.name,
    required this.ownerUserId,
    required List<String> memberUserIds,
  }) : memberUserIds = List<String>.unmodifiable(memberUserIds);

  factory PlatformSquad.fromJson(Map<String, dynamic> json) {
    return PlatformSquad(
      squadId: _readString(json, 'squadId'),
      name: _readString(json, 'name'),
      ownerUserId: _readString(json, 'ownerUserId'),
      memberUserIds: _readStringList(json, 'memberUserIds'),
    );
  }

  final String squadId;
  final String name;
  final String ownerUserId;
  final List<String> memberUserIds;
}

class PlatformContent {
  PlatformContent({
    required this.contentVersion,
    required this.chapterNodes,
    required List<String> onboardingSteps,
    required List<PlatformSkill> skills,
    required List<PlatformAchievement> achievements,
    required List<PlatformCosmetic> cosmetics,
    required List<PlatformExperiment> experiments,
    required this.season,
    required this.weeklyRoute,
    required this.catalogDigest,
  }) : onboardingSteps = List<String>.unmodifiable(onboardingSteps),
       skills = List<PlatformSkill>.unmodifiable(skills),
       achievements = List<PlatformAchievement>.unmodifiable(achievements),
       cosmetics = List<PlatformCosmetic>.unmodifiable(cosmetics),
       experiments = List<PlatformExperiment>.unmodifiable(experiments);

  factory PlatformContent.fromJson(Map<String, dynamic> json) {
    final int chapterNodes = _readInt(json, 'chapterNodes');
    if (chapterNodes <= 0) {
      throw const FormatException('chapterNodes должен быть положительным');
    }
    return PlatformContent(
      contentVersion: _readNullableString(json, 'contentVersion'),
      chapterNodes: chapterNodes,
      onboardingSteps: _readStringList(json, 'onboardingSteps'),
      skills: _readList(json, 'skills')
          .map(
            (Object? value) =>
                PlatformSkill.fromJson(_asMap(value, 'skills[]')),
          )
          .toList(growable: false),
      achievements: _readList(json, 'achievements')
          .map(
            (Object? value) =>
                PlatformAchievement.fromJson(_asMap(value, 'achievements[]')),
          )
          .toList(growable: false),
      cosmetics: _readList(json, 'cosmetics')
          .map(
            (Object? value) =>
                PlatformCosmetic.fromJson(_asMap(value, 'cosmetics[]')),
          )
          .toList(growable: false),
      experiments: _readList(json, 'experiments')
          .map(
            (Object? value) =>
                PlatformExperiment.fromJson(_asMap(value, 'experiments[]')),
          )
          .toList(growable: false),
      season: PlatformSeason.fromJson(_readMap(json, 'season')),
      weeklyRoute: PlatformWeeklyRoute.fromJson(_readMap(json, 'weeklyRoute')),
      catalogDigest: _readString(json, 'catalogDigest'),
    );
  }

  final String? contentVersion;
  final int chapterNodes;
  final List<String> onboardingSteps;
  final List<PlatformSkill> skills;
  final List<PlatformAchievement> achievements;
  final List<PlatformCosmetic> cosmetics;
  final List<PlatformExperiment> experiments;
  final PlatformSeason season;
  final PlatformWeeklyRoute weeklyRoute;
  final String catalogDigest;
}

class PlatformSkill {
  const PlatformSkill({
    required this.skillId,
    required this.name,
    required this.description,
    required this.requiredSeasonXp,
  });

  factory PlatformSkill.fromJson(Map<String, dynamic> json) {
    final int requiredSeasonXp = _readInt(json, 'requiredSeasonXp');
    if (requiredSeasonXp < 0) {
      throw const FormatException(
        'requiredSeasonXp навыка должен быть неотрицательным',
      );
    }
    return PlatformSkill(
      skillId: _readString(json, 'skillId'),
      name: _readString(json, 'name'),
      description: _readString(json, 'description'),
      requiredSeasonXp: requiredSeasonXp,
    );
  }

  final String skillId;
  final String name;
  final String description;
  final int requiredSeasonXp;

  int remainingSeasonXp(int seasonXp) {
    final int remaining = requiredSeasonXp - seasonXp;
    return remaining < 0 ? 0 : remaining;
  }
}

class PlatformAchievement {
  const PlatformAchievement({required this.achievementId, required this.name});

  factory PlatformAchievement.fromJson(Map<String, dynamic> json) {
    return PlatformAchievement(
      achievementId: _readString(json, 'achievementId'),
      name: _readString(json, 'name'),
    );
  }

  final String achievementId;
  final String name;
}

class PlatformCosmetic {
  const PlatformCosmetic({
    required this.cosmeticId,
    required this.name,
    required this.slot,
    required this.sandboxPrice,
  });

  factory PlatformCosmetic.fromJson(Map<String, dynamic> json) {
    return PlatformCosmetic(
      cosmeticId: _readString(json, 'cosmeticId'),
      name: _readString(json, 'name'),
      slot: _readString(json, 'slot'),
      sandboxPrice: _readInt(json, 'sandboxPrice'),
    );
  }

  final String cosmeticId;
  final String name;
  final String slot;
  final int sandboxPrice;
}

void _validateEquippedCosmetics(
  PlatformUserState userState,
  PlatformContent content,
) {
  final Map<String, PlatformCosmetic> cosmeticsById =
      <String, PlatformCosmetic>{
        for (final PlatformCosmetic cosmetic in content.cosmetics)
          cosmetic.cosmeticId: cosmetic,
      };

  for (final MapEntry<String, String> entry
      in userState.equippedCosmetics.entries) {
    if (!_supportedCosmeticSlots.contains(entry.key)) {
      throw FormatException(
        'equippedCosmetics содержит неподдерживаемый slot ${entry.key}',
      );
    }
    final PlatformCosmetic? cosmetic = cosmeticsById[entry.value];
    if (cosmetic == null) {
      throw FormatException(
        'equippedCosmetics содержит cosmeticId ${entry.value}, '
        'отсутствующий в content.cosmetics',
      );
    }
    if (cosmetic.slot != entry.key) {
      throw FormatException(
        'equippedCosmetics.${entry.key} не совпадает со slot '
        '${cosmetic.slot} для ${entry.value}',
      );
    }
  }
}

class PlatformExperiment {
  PlatformExperiment({
    required this.experimentId,
    required List<String> variants,
    required this.description,
  }) : variants = List<String>.unmodifiable(variants);

  factory PlatformExperiment.fromJson(Map<String, dynamic> json) {
    return PlatformExperiment(
      experimentId: _readString(json, 'experimentId'),
      variants: _readStringList(json, 'variants'),
      description: _readString(json, 'description'),
    );
  }

  final String experimentId;
  final List<String> variants;
  final String description;
}

class PlatformSeason {
  const PlatformSeason({
    required this.seasonId,
    required this.name,
    required this.levels,
    this.xpPerLevel,
  });

  factory PlatformSeason.fromJson(Map<String, dynamic> json) {
    final int levels = _readInt(json, 'levels');
    final int? xpPerLevel = json.containsKey('xpPerLevel')
        ? _readInt(json, 'xpPerLevel')
        : null;
    if (levels <= 0) {
      throw const FormatException('levels должен быть положительным');
    }
    if (xpPerLevel != null && xpPerLevel <= 0) {
      throw const FormatException('xpPerLevel должен быть положительным');
    }
    return PlatformSeason(
      seasonId: _readString(json, 'seasonId'),
      name: _readString(json, 'name'),
      levels: levels,
      xpPerLevel: xpPerLevel,
    );
  }

  final String seasonId;
  final String name;
  final int levels;
  final int? xpPerLevel;
}

class PlatformWeeklyRoute {
  const PlatformWeeklyRoute({
    required this.routeId,
    required this.requiredEnergy,
  });

  factory PlatformWeeklyRoute.fromJson(Map<String, dynamic> json) {
    final int requiredEnergy = _readInt(json, 'requiredEnergy');
    if (requiredEnergy <= 0) {
      throw const FormatException('requiredEnergy должен быть положительным');
    }
    return PlatformWeeklyRoute(
      routeId: _readString(json, 'routeId'),
      requiredEnergy: requiredEnergy,
    );
  }

  final String routeId;
  final int requiredEnergy;
}

class PlatformRemoteConfig {
  PlatformRemoteConfig({
    required Map<String, Object?> values,
    required this.backgroundHealthSyncEnabled,
    required this.activityRetentionDays,
    required this.seasonId,
    required this.weeklyRouteEnergy,
    required this.sandboxPaymentsEnabled,
    required this.weeklyRouteEnabled,
  }) : values = Map<String, Object?>.unmodifiable(values);

  factory PlatformRemoteConfig.fromJson(Map<String, dynamic> json) {
    return PlatformRemoteConfig(
      values: Map<String, Object?>.from(json),
      backgroundHealthSyncEnabled: _readOptionalBool(
        json,
        'backgroundHealthSyncEnabled',
        false,
      ),
      activityRetentionDays: _readOptionalInt(
        json,
        'activityRetentionDays',
        30,
      ),
      seasonId: _readOptionalString(json, 'seasonId', 'season-1'),
      weeklyRouteEnergy: _readOptionalInt(json, 'weeklyRouteEnergy', 120),
      sandboxPaymentsEnabled: _readOptionalBool(
        json,
        'sandboxPaymentsEnabled',
        false,
      ),
      weeklyRouteEnabled: _readOptionalBool(json, 'weeklyRouteEnabled', true),
    );
  }

  final Map<String, Object?> values;
  final bool backgroundHealthSyncEnabled;
  final int activityRetentionDays;
  final String seasonId;
  final int weeklyRouteEnergy;
  final bool sandboxPaymentsEnabled;
  final bool weeklyRouteEnabled;
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, String field) {
  return _asMap(json[field], field);
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('$field должен быть JSON-объектом');
  }
  return value.map<String, dynamic>((Object? key, Object? item) {
    if (key is! String) {
      throw FormatException('Ключи $field должны быть строками');
    }
    return MapEntry<String, dynamic>(key, item);
  });
}

List<Object?> _readList(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is! List<dynamic>) {
    throw FormatException('$field должен быть JSON-массивом');
  }
  return List<Object?>.from(value);
}

List<String> _readStringList(Map<String, dynamic> json, String field) {
  return _readList(json, field)
      .map<String>((Object? value) {
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('$field должен содержать непустые строки');
        }
        return value;
      })
      .toList(growable: false);
}

Set<String> _readStringSet(Map<String, dynamic> json, String field) {
  return _readStringList(json, field).toSet();
}

Map<String, String> _readStringMap(Map<String, dynamic> json, String field) {
  final Map<String, dynamic> value = _readMap(json, field);
  return value.map<String, String>((String key, Object? item) {
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('$field.$key должен быть непустой строкой');
    }
    return MapEntry<String, String>(key, item);
  });
}

String _readString(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field должен быть непустой строкой');
  }
  return value;
}

String? _readNullableString(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field должен быть непустой строкой или null');
  }
  return value;
}

int _readInt(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is int) {
    return value;
  }
  if (value is num && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$field должен быть целым числом');
}

bool _readBool(Map<String, dynamic> json, String field) {
  final Object? value = json[field];
  if (value is bool) {
    return value;
  }
  throw FormatException('$field должен быть boolean');
}

String _readOptionalString(
  Map<String, dynamic> json,
  String field,
  String fallback,
) {
  final Object? value = json[field];
  if (value == null) {
    return fallback;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('$field должен быть непустой строкой');
}

int _readOptionalInt(Map<String, dynamic> json, String field, int fallback) {
  if (!json.containsKey(field)) {
    return fallback;
  }
  return _readInt(json, field);
}

bool _readOptionalBool(Map<String, dynamic> json, String field, bool fallback) {
  if (!json.containsKey(field)) {
    return fallback;
  }
  return _readBool(json, field);
}
