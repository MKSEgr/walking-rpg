import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';

Map<String, dynamic> platformSnapshotJson({
  int stateVersion = 3,
  List<String> completedOnboardingSteps = const <String>['welcome'],
  String activePetId = 'spark-v1',
  int seasonXp = 220,
  int weeklyRouteProgress = 40,
  int weeklyRouteRequiredEnergy = 100,
  Map<String, dynamic>? squad,
  List<String> ownedCosmetics = const <String>['pilot-scarf'],
  String? activeCosmeticId = 'pilot-scarf',
  List<String> achievements = const <String>['season-reward-1'],
}) {
  final bool onboardingComplete = completedOnboardingSteps.length == 4;
  return <String, dynamic>{
    'contentVersion': 'chapter-1-v1',
    'stateVersion': stateVersion,
    'userState': <String, dynamic>{
      'activePetId': activePetId,
      'pets': <Map<String, dynamic>>[
        <String, dynamic>{
          'petId': 'spark-v1',
          'name': 'Искра',
          'species': 'люмин',
          'level': 1,
          'bond': 50,
          'evolutionStage': 0,
          'evolutionBond': 50,
          'active': activePetId == 'spark-v1',
        },
        <String, dynamic>{
          'petId': 'moss-v1',
          'name': 'Мох',
          'species': 'терра',
          'level': 1,
          'bond': 12,
          'evolutionStage': 0,
          'evolutionBond': 45,
          'active': activePetId == 'moss-v1',
        },
        <String, dynamic>{
          'petId': 'rune-v1',
          'name': 'Руна',
          'species': 'эхо',
          'level': 1,
          'bond': 9,
          'evolutionStage': 0,
          'evolutionBond': 55,
          'active': activePetId == 'rune-v1',
        },
      ],
      'completedOnboardingSteps': completedOnboardingSteps,
      'onboardingComplete': onboardingComplete,
      'unlockedSkills': <String>['steady-step'],
      'quests': <Map<String, dynamic>>[
        <String, dynamic>{
          'questId': 'walk-3000',
          'name': 'Первый маршрут',
          'metric': 'TOTAL_ACCEPTED_STEPS',
          'progress': 3000,
          'target': 3000,
          'ready': true,
          'claimed': false,
          'seasonXpReward': 60,
          'petBondReward': 4,
        },
        <String, dynamic>{
          'questId': 'resolve-3',
          'name': 'Исследователь',
          'metric': 'RESOLVED_EVENTS',
          'progress': 2,
          'target': 3,
          'ready': false,
          'claimed': false,
          'seasonXpReward': 80,
          'petBondReward': 5,
        },
      ],
      'claimedQuests': <String>[],
      'achievements': achievements,
      'seasonXp': seasonXp,
      'seasonLevel': seasonXp ~/ 100 + 1,
      'weeklyRouteProgress': weeklyRouteProgress,
      'weeklyRouteRequiredEnergy': weeklyRouteRequiredEnergy,
      'squad': squad,
      'ownedCosmetics': ownedCosmetics,
      'activeCosmeticId': activeCosmeticId,
      'experimentAssignments': <String, String>{
        'home-energy-copy-v1': 'MOTIVATIONAL',
        'quest-order-v1': 'REWARD_FIRST',
      },
      'resolvedEventCount': 2,
      'totalAcceptedSteps': 6842,
    },
    'content': <String, dynamic>{
      'contentVersion': 'chapter-1-v1',
      'chapterNodes': 18,
      'onboardingSteps': <String>[
        'welcome',
        'health-permission',
        'first-sync',
        'first-expedition',
      ],
      'pets': const <Map<String, dynamic>>[],
      'skills': <Map<String, dynamic>>[
        <String, dynamic>{
          'skillId': 'steady-step',
          'name': 'Ровный шаг',
          'description': 'Стабилизирует серии активности.',
          'requiredSeasonXp': 0,
        },
        <String, dynamic>{
          'skillId': 'trail-memory',
          'name': 'Память маршрута',
          'description': 'Открывает сведения о пройденных узлах.',
          'requiredSeasonXp': 100,
        },
      ],
      'quests': const <Map<String, dynamic>>[],
      'achievements': <Map<String, dynamic>>[
        <String, dynamic>{
          'achievementId': 'onboarding-complete',
          'name': 'Путь открыт',
        },
        <String, dynamic>{
          'achievementId': 'season-level-3',
          'name': 'Третий уровень сезона',
        },
      ],
      'cosmetics': <Map<String, dynamic>>[
        <String, dynamic>{
          'cosmeticId': 'pilot-scarf',
          'name': 'Шарф навигатора',
          'slot': 'PILOT',
          'sandboxPrice': 0,
        },
        <String, dynamic>{
          'cosmeticId': 'spark-halo',
          'name': 'Ореол Искры',
          'slot': 'PET',
          'sandboxPrice': 199,
        },
      ],
      'experiments': <Map<String, dynamic>>[
        <String, dynamic>{
          'experimentId': 'home-energy-copy-v1',
          'variants': <String>['CONTROL', 'MOTIVATIONAL'],
          'description': 'Текст блока энергии',
        },
        <String, dynamic>{
          'experimentId': 'quest-order-v1',
          'variants': <String>['PROGRESS_FIRST', 'REWARD_FIRST'],
          'description': 'Порядок карточки задания',
        },
      ],
      'season': <String, dynamic>{
        'seasonId': 'season-1',
        'name': 'Сезон первого сигнала',
        'levels': 10,
      },
      'weeklyRoute': <String, dynamic>{
        'routeId': 'weekly-route-1',
        'requiredEnergy': 120,
      },
      'materials': <String>['lumen-shard'],
      'catalogDigest': 'fixture-digest',
    },
    'remoteConfig': <String, dynamic>{
      'backgroundHealthSyncEnabled': false,
      'activityRetentionDays': 30,
      'seasonId': 'signal-season-1',
      'weeklyRouteEnergy': weeklyRouteRequiredEnergy,
      'sandboxPaymentsEnabled': true,
      'weeklyRouteEnabled': true,
    },
    'serverTime': '2026-07-27T10:00:00Z',
  };
}

PlatformSnapshot platformSnapshot({
  int stateVersion = 3,
  List<String> completedOnboardingSteps = const <String>['welcome'],
  String activePetId = 'spark-v1',
  int seasonXp = 220,
  int weeklyRouteProgress = 40,
  Map<String, dynamic>? squad,
  List<String> ownedCosmetics = const <String>['pilot-scarf'],
  String? activeCosmeticId = 'pilot-scarf',
  List<String> achievements = const <String>['season-reward-1'],
}) {
  return PlatformSnapshot.fromJson(
    platformSnapshotJson(
      stateVersion: stateVersion,
      completedOnboardingSteps: completedOnboardingSteps,
      activePetId: activePetId,
      seasonXp: seasonXp,
      weeklyRouteProgress: weeklyRouteProgress,
      squad: squad,
      ownedCosmetics: ownedCosmetics,
      activeCosmeticId: activeCosmeticId,
      achievements: achievements,
    ),
  );
}

PlatformCommandResult platformCommandResult({
  required String commandType,
  required String idempotencyKey,
  required PlatformSnapshot snapshot,
  String message = 'Команда выполнена',
}) {
  return PlatformCommandResult(
    commandType: commandType,
    idempotencyKey: idempotencyKey,
    message: message,
    stateVersion: snapshot.stateVersion,
    snapshot: snapshot,
    serverTime: snapshot.serverTime,
  );
}
