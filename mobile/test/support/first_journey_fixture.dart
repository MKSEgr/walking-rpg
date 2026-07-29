import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';

const HomeExpeditionEvent firstJourneyEvent = HomeExpeditionEvent(
  eventId: 'signal-source-v1',
  title: 'Источник сигнала',
  summary: 'Маяк отвечает импульсом.',
  status: 'READY',
  choices: <HomeEventChoice>[
    HomeEventChoice(
      choiceId: 'analyze-signal',
      title: 'Проанализировать сигнал',
      description: 'Пилот сопоставит частоты маяка.',
      pilotExperienceReward: 40,
      petBondReward: 5,
    ),
    HomeEventChoice(
      choiceId: 'trust-companion',
      title: 'Довериться питомцу',
      description: 'Питомец найдёт безопасный путь.',
      pilotExperienceReward: 20,
      petBondReward: 15,
    ),
  ],
);

HomeSnapshot firstJourneyHome({
  bool synced = false,
  int energy = 0,
  bool eventReady = false,
  bool firstEventResolved = false,
  String petName = 'Искра',
  int petBond = 10,
  CachedReadMetadata? cacheMetadata,
}) {
  return HomeSnapshot(
    localDate: '2026-07-29',
    timeZone: 'Europe/Berlin',
    dailySteps: synced ? 3000 : 0,
    dailyGoal: 6000,
    availableEnergy: energy,
    activityStateVersion: synced ? 1 : 0,
    economyVersion: synced ? 1 : 0,
    lastActivitySyncAt: synced ? '2026-07-29T08:00:00Z' : null,
    serverTime: '2026-07-29T08:00:00Z',
    contentVersion: 'starter-v2',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: firstEventResolved ? 'lumen-gate' : 'outer-beacon',
    currentNodeName: firstEventResolved ? 'Люминовые ворота' : 'Внешний маяк',
    expeditionProgress: eventReady ? 30 : 0,
    requiredEnergy: firstEventResolved ? 45 : 30,
    expeditionStatus: eventReady ? 'EVENT_READY' : 'IN_PROGRESS',
    expeditionVersion: eventReady || firstEventResolved ? 1 : 0,
    unlockedEvent: eventReady ? firstJourneyEvent : null,
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: firstEventResolved ? 60 : 20,
    pilotNextLevelExperience: 100,
    petName: petName,
    petLevel: 1,
    petBond: petBond,
    cacheMetadata: cacheMetadata,
  );
}

const ActivitySyncResult firstJourneyActivityResult = ActivitySyncResult(
  acceptedTotal: 3000,
  acceptedDelta: 3000,
  energyGranted: 30,
  energyBalanceAfter: 30,
  economyVersion: 1,
  riskStatus: 'ACCEPTED',
  stateVersion: 1,
  serverTime: '2026-07-29T08:00:00Z',
);

const ExpeditionAdvanceResult firstJourneyAdvanceResult =
    ExpeditionAdvanceResult(
      contentVersion: 'starter-v2',
      expeditionId: 'starter-expedition-v1',
      expeditionName: 'Сигнал из туманного сектора',
      energySpent: 30,
      energyBalanceAfter: 0,
      economyVersion: 2,
      progressAfter: 30,
      requiredEnergy: 30,
      expeditionVersion: 1,
      status: 'EVENT_READY',
      currentNodeId: 'outer-beacon',
      currentNodeName: 'Внешний маяк',
      unlockedEvent: ExpeditionEventResult(
        eventId: 'signal-source-v1',
        title: 'Источник сигнала',
        summary: 'Маяк отвечает импульсом.',
        status: 'READY',
      ),
      serverTime: '2026-07-29T08:01:00Z',
    );

EventResolutionResult firstJourneyResolutionResult({
  String petId = 'spark-v1',
  String petName = 'Искра',
}) {
  return EventResolutionResult(
    contentVersion: 'starter-v2',
    expeditionId: 'starter-expedition-v1',
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 2,
    eventId: 'signal-source-v1',
    eventTitle: 'Источник сигнала',
    status: 'RESOLVED',
    choiceId: 'analyze-signal',
    choiceTitle: 'Проанализировать сигнал',
    outcomeTitle: 'Частота найдена',
    outcomeSummary: 'Маяк открыл путь к следующему узлу.',
    pilot: const EventPilotReward(
      pilotId: 'navigator-v1',
      name: 'Навигатор',
      level: 1,
      experienceGained: 40,
      currentExperience: 60,
      nextLevelExperience: 100,
      version: 1,
    ),
    pet: EventPetReward(
      petId: petId,
      name: petName,
      level: 1,
      bondGained: 5,
      bond: 15,
      version: 1,
    ),
    serverTime: '2026-07-29T08:02:00Z',
  );
}
