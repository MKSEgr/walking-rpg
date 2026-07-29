import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';

import 'support/first_journey_fixture.dart';
import 'support/platform_fixture.dart';

void main() {
  test('moves through the canonical six-step first journey', () {
    final FirstJourneyProgress fresh = FirstJourneyProgress(
      home: firstJourneyHome(),
      platform: platformSnapshot(
        completedOnboardingSteps: const <String>[],
        resolvedEventCount: 0,
        totalAcceptedSteps: 0,
      ),
    );
    final FirstJourneyProgress activity = FirstJourneyProgress(
      home: firstJourneyHome(),
      platform: platformSnapshot(
        completedOnboardingSteps: const <String>['welcome'],
        resolvedEventCount: 0,
        totalAcceptedSteps: 0,
      ),
    );
    final FirstJourneyProgress pet = FirstJourneyProgress(
      home: firstJourneyHome(synced: true, energy: 30),
      platform: platformSnapshot(
        completedOnboardingSteps: const <String>[
          'welcome',
          'health-permission',
          'first-sync',
        ],
        resolvedEventCount: 0,
      ),
    );
    final FirstJourneyProgress expedition = FirstJourneyProgress(
      home: firstJourneyHome(synced: true, energy: 30),
      platform: platformSnapshot(
        completedOnboardingSteps: const <String>[
          'welcome',
          'health-permission',
          'first-sync',
          'pet-selection',
        ],
        resolvedEventCount: 0,
      ),
    );
    final FirstJourneyProgress event = FirstJourneyProgress(
      home: firstJourneyHome(synced: true, eventReady: true),
      platform: platformSnapshot(
        completedOnboardingSteps: const <String>[
          'welcome',
          'health-permission',
          'first-sync',
          'pet-selection',
          'first-expedition',
        ],
        resolvedEventCount: 0,
      ),
    );
    final FirstJourneyProgress complete = FirstJourneyProgress(
      home: firstJourneyHome(synced: true, firstEventResolved: true),
      platform: platformSnapshot(
        completedOnboardingSteps: FirstJourneyProgress.steps,
        resolvedEventCount: 1,
      ),
    );

    expect(fresh.stage, FirstJourneyStage.welcome);
    expect(fresh.completedCount, 0);
    expect(activity.stage, FirstJourneyStage.activity);
    expect(pet.stage, FirstJourneyStage.pet);
    expect(expedition.stage, FirstJourneyStage.expedition);
    expect(event.stage, FirstJourneyStage.event);
    expect(complete.stage, FirstJourneyStage.complete);
    expect(complete.progressValue, 1);
  });

  test(
    'recovers durable milestones from gameplay facts after interruption',
    () {
      final FirstJourneyProgress afterSync = FirstJourneyProgress(
        home: firstJourneyHome(synced: true, energy: 30),
        platform: platformSnapshot(
          completedOnboardingSteps: const <String>['welcome'],
          resolvedEventCount: 0,
        ),
      );
      final FirstJourneyProgress afterResolution = FirstJourneyProgress(
        home: firstJourneyHome(synced: true, firstEventResolved: true),
        platform: platformSnapshot(
          completedOnboardingSteps: const <String>['welcome', 'pet-selection'],
          resolvedEventCount: 1,
        ),
      );

      expect(afterSync.stage, FirstJourneyStage.pet);
      expect(afterSync.pendingFactMilestones, <String>[
        'health-permission',
        'first-sync',
      ]);
      expect(afterResolution.stage, FirstJourneyStage.complete);
      expect(afterResolution.pendingFactMilestones, <String>[
        'health-permission',
        'first-sync',
        'first-expedition',
        'first-event',
      ]);
    },
  );

  test('keeps cached recovery state read-only', () {
    final FirstJourneyProgress cached = FirstJourneyProgress(
      home: firstJourneyHome(
        synced: true,
        energy: 30,
        cacheMetadata: CachedReadMetadata(
          cachedAt: DateTime.utc(2026, 7, 29, 8),
          reason: 'Нет соединения с сервером',
        ),
      ),
      platform: platformSnapshot(
        completedOnboardingSteps: const <String>['welcome'],
        resolvedEventCount: 0,
      ),
    );

    expect(cached.stage, FirstJourneyStage.pet);
    expect(cached.readOnly, isTrue);
  });
}
