import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/activity/data/platform_health_step_source.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/validation/application/validation_evidence_controller.dart';
import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';

import 'support/first_journey_fixture.dart';
import 'support/platform_fixture.dart';

void main() {
  test(
    'records read, sync and authoritative checkpoint without rereading',
    () async {
      final StepReading reading = StepReading(
        authoritativeTotal: 3000,
        localDate: DateTime(2026, 7, 31),
        timeZone: 'Europe/Berlin',
        syncCursor: 'private-cursor-never-exported',
      );
      int readCalls = 0;
      StepReading? synchronizedReading;
      int monotonic = 0;
      final ValidationEvidenceController controller =
          ValidationEvidenceController(
            ownerId: 'owner-1',
            activeOwnerProvider: () => 'owner-1',
            sessionRevision: 0,
            activeSessionRevisionProvider: () => 0,
            launch: _launch(),
            stepReader: () async {
              readCalls += 1;
              return reading;
            },
            synchronizer: (StepReading value) async {
              synchronizedReading = value;
              return firstJourneyActivityResult;
            },
            homeLoader: () async => firstJourneyHome(synced: true, energy: 30),
            platformLoader: () async => platformSnapshot(
              completedOnboardingSteps: const <String>[
                'welcome',
                'health-permission',
                'first-sync',
              ],
              resolvedEventCount: 0,
              totalAcceptedSteps: 3000,
            ),
            clock: () => DateTime.utc(2026, 7, 31, 18, 4),
            monotonicMillis: () {
              monotonic += 10;
              return monotonic;
            },
          );

      await controller.readHealth(activeOwnerId: 'owner-1');
      await controller.synchronize(activeOwnerId: 'owner-1');
      await controller.captureAuthoritativeCheckpoint(activeOwnerId: 'owner-1');

      expect(readCalls, 1);
      expect(identical(synchronizedReading, reading), isTrue);
      expect(
        controller.snapshot.journal
            .map((EvidenceJournalEntry entry) => entry.scenario)
            .toList(),
        <EvidenceScenario>[
          EvidenceScenario.provider,
          EvidenceScenario.permission,
          EvidenceScenario.read,
          EvidenceScenario.sync,
          EvidenceScenario.checkpoint,
        ],
      );
      expect(controller.snapshot.latestHealth?.authoritativeTotal, 3000);
      expect(controller.snapshot.latestSync?.energyGranted, 30);
      expect(
        controller.snapshot.authoritativeCheckpoint?.firstJourneyStage,
        'pet',
      );
      final String encoded = controller.encode(activeOwnerId: 'owner-1');
      expect(DeviceValidationEvidenceCodec.verify(encoded), isTrue);
      expect(encoded, isNot(contains('private-cursor-never-exported')));
      expect(encoded, isNot(contains('owner-1')));
    },
  );

  test(
    'normalizes permission failure without retaining raw exception text',
    () async {
      final ValidationEvidenceController controller =
          ValidationEvidenceController(
            ownerId: 'owner-1',
            activeOwnerProvider: () => 'owner-1',
            sessionRevision: 0,
            activeSessionRevisionProvider: () => 0,
            launch: _launch(),
            stepReader: () async => throw const PlatformHealthStepException(
              PlatformHealthStepFailure.authorizationDenied,
              'Bearer secret-token must never be exported',
            ),
            synchronizer: (_) async => firstJourneyActivityResult,
            homeLoader: () async => firstJourneyHome(),
            platformLoader: () async => platformSnapshot(),
            clock: () => DateTime.utc(2026, 7, 31, 18, 4),
            monotonicMillis: () => 0,
          );

      await expectLater(
        controller.readHealth(activeOwnerId: 'owner-1'),
        throwsA(
          isA<ValidationActionException>().having(
            (ValidationActionException error) => error.category,
            'category',
            EvidenceErrorCategory.permissionDenied,
          ),
        ),
      );

      final EvidenceHealthObservation health =
          controller.snapshot.latestHealth!;
      expect(health.permissionState, EvidencePermissionState.denied);
      expect(
        controller.snapshot.journal.last.scenario,
        EvidenceScenario.permission,
      );
      final String encoded = controller.encode(activeOwnerId: 'owner-1');
      expect(encoded, isNot(contains('secret-token')));
      expect(encoded, contains('permission_denied'));
    },
  );

  test('does not invent passed phases for an unknown Health failure', () async {
    final ValidationEvidenceController controller =
        ValidationEvidenceController(
          ownerId: 'owner-1',
          activeOwnerProvider: () => 'owner-1',
          sessionRevision: 0,
          activeSessionRevisionProvider: () => 0,
          launch: _launch(),
          stepReader: () async => throw StateError('private raw failure'),
          homeLoader: () async => firstJourneyHome(),
          platformLoader: () async => platformSnapshot(),
          clock: () => DateTime.utc(2026, 7, 31, 18, 4),
          monotonicMillis: () => 0,
        );
    addTearDown(controller.dispose);

    await expectLater(
      controller.readHealth(activeOwnerId: 'owner-1'),
      throwsA(
        isA<ValidationActionException>().having(
          (ValidationActionException error) => error.category,
          'category',
          EvidenceErrorCategory.unexpectedFailure,
        ),
      ),
    );

    expect(controller.snapshot.journal, hasLength(1));
    expect(controller.snapshot.journal.single.scenario, EvidenceScenario.read);
    final String encoded = controller.encode(activeOwnerId: 'owner-1');
    expect(DeviceValidationEvidenceCodec.verify(encoded), isTrue);
    expect(encoded, isNot(contains('private raw failure')));
  });

  test('rejects cached data as an authoritative checkpoint', () async {
    final CachedReadMetadata cached = CachedReadMetadata(
      cachedAt: DateTime.utc(2026, 7, 31, 17),
      reason: 'offline',
    );
    final ValidationEvidenceController controller =
        ValidationEvidenceController(
          ownerId: 'owner-1',
          activeOwnerProvider: () => 'owner-1',
          sessionRevision: 0,
          activeSessionRevisionProvider: () => 0,
          launch: _launch(),
          homeLoader: () async => firstJourneyHome(cacheMetadata: cached),
          platformLoader: () async => platformSnapshot(),
          clock: () => DateTime.utc(2026, 7, 31, 18, 4),
          monotonicMillis: () => 0,
        );

    await expectLater(
      controller.captureAuthoritativeCheckpoint(activeOwnerId: 'owner-1'),
      throwsA(
        isA<ValidationActionException>().having(
          (ValidationActionException error) => error.category,
          'category',
          EvidenceErrorCategory.cachedSnapshot,
        ),
      ),
    );

    expect(controller.snapshot.authoritativeCheckpoint, isNull);
    expect(controller.snapshot.journal.single.outcome, EvidenceOutcome.blocked);
  });

  test('rejects skew between authoritative content versions', () async {
    final Map<String, dynamic> platformJson = platformSnapshotJson();
    platformJson['contentVersion'] = 'chapter-2-v1';
    (platformJson['content'] as Map<String, dynamic>)['contentVersion'] =
        'chapter-2-v1';
    final ValidationEvidenceController controller =
        ValidationEvidenceController(
          ownerId: 'owner-1',
          activeOwnerProvider: () => 'owner-1',
          sessionRevision: 0,
          activeSessionRevisionProvider: () => 0,
          launch: _launch(),
          homeLoader: () async => firstJourneyHome(),
          platformLoader: () async => PlatformSnapshot.fromJson(platformJson),
          clock: () => DateTime.utc(2026, 7, 31, 18, 4),
          monotonicMillis: () => 0,
        );
    addTearDown(controller.dispose);

    await expectLater(
      controller.captureAuthoritativeCheckpoint(activeOwnerId: 'owner-1'),
      throwsA(
        isA<ValidationActionException>().having(
          (ValidationActionException error) => error.category,
          'category',
          EvidenceErrorCategory.invalidResponse,
        ),
      ),
    );

    expect(controller.snapshot.authoritativeCheckpoint, isNull);
    expect(controller.snapshot.journal.single.outcome, EvidenceOutcome.failed);
  });

  test(
    'normalizes invalid numeric sync facts as an invalid response',
    () async {
      final StepReading reading = StepReading(
        authoritativeTotal: 10,
        localDate: DateTime(2026, 7, 31),
        timeZone: 'UTC',
      );
      final ValidationEvidenceController controller =
          ValidationEvidenceController(
            ownerId: 'owner-1',
            activeOwnerProvider: () => 'owner-1',
            sessionRevision: 0,
            activeSessionRevisionProvider: () => 0,
            launch: _launch(),
            stepReader: () async => reading,
            synchronizer: (_) async => const ActivitySyncResult(
              acceptedTotal: -1,
              acceptedDelta: 0,
              energyGranted: 0,
              energyBalanceAfter: 0,
              economyVersion: 1,
              riskStatus: 'NO_NEW_ACTIVITY',
              stateVersion: 1,
              serverTime: '2026-07-31T18:04:00Z',
            ),
            homeLoader: () async => firstJourneyHome(),
            platformLoader: () async => platformSnapshot(),
            clock: () => DateTime.utc(2026, 7, 31, 18, 4),
            monotonicMillis: () => 0,
          );
      addTearDown(controller.dispose);

      await controller.readHealth(activeOwnerId: 'owner-1');
      await expectLater(
        controller.synchronize(activeOwnerId: 'owner-1'),
        throwsA(
          isA<ValidationActionException>().having(
            (ValidationActionException error) => error.category,
            'category',
            EvidenceErrorCategory.invalidResponse,
          ),
        ),
      );

      expect(
        controller.snapshot.latestSync?.errorCategory,
        EvidenceErrorCategory.invalidResponse,
      );
      expect(controller.snapshot.journal.last.outcome, EvidenceOutcome.failed);
    },
  );

  test(
    'owner change cannot read or export the previous launch journal',
    () async {
      final ValidationEvidenceController controller =
          ValidationEvidenceController(
            ownerId: 'owner-1',
            activeOwnerProvider: () => 'owner-1',
            sessionRevision: 0,
            activeSessionRevisionProvider: () => 0,
            launch: _launch(),
            homeLoader: () async => firstJourneyHome(),
            platformLoader: () async => platformSnapshot(),
          );

      expect(
        () => controller.encode(activeOwnerId: 'owner-2'),
        throwsA(isA<ValidationOwnerMismatchException>()),
      );
      await expectLater(
        controller.captureAuthoritativeCheckpoint(activeOwnerId: 'owner-2'),
        throwsA(isA<ValidationOwnerMismatchException>()),
      );
    },
  );

  test(
    'an action finishing after owner shell disposal records nothing',
    () async {
      final Completer<StepReading> pending = Completer<StepReading>();
      final ValidationEvidenceController controller =
          ValidationEvidenceController(
            ownerId: 'owner-1',
            activeOwnerProvider: () => 'owner-1',
            sessionRevision: 0,
            activeSessionRevisionProvider: () => 0,
            launch: _launch(),
            stepReader: () => pending.future,
            homeLoader: () async => firstJourneyHome(),
            platformLoader: () async => platformSnapshot(),
          );

      final Future<void> action = controller.readHealth(
        activeOwnerId: 'owner-1',
      );
      controller.dispose();
      pending.complete(
        StepReading(
          authoritativeTotal: 3000,
          localDate: DateTime(2026, 7, 31),
          timeZone: 'Europe/Berlin',
        ),
      );

      await expectLater(
        action,
        throwsA(isA<ValidationOwnerMismatchException>()),
      );
      expect(controller.snapshot.journal, isEmpty);
      expect(controller.snapshot.latestHealth, isNull);
    },
  );

  test(
    'an in-flight action rejects a new session for the same owner',
    () async {
      int activeSessionRevision = 0;
      final Completer<StepReading> pending = Completer<StepReading>();
      final ValidationEvidenceController controller =
          ValidationEvidenceController(
            ownerId: 'owner-1',
            activeOwnerProvider: () => 'owner-1',
            sessionRevision: 0,
            activeSessionRevisionProvider: () => activeSessionRevision,
            launch: _launch(),
            stepReader: () => pending.future,
            homeLoader: () async => firstJourneyHome(),
            platformLoader: () async => platformSnapshot(),
          );
      addTearDown(controller.dispose);

      final Future<void> action = controller.readHealth(
        activeOwnerId: 'owner-1',
      );
      activeSessionRevision = 1;
      pending.complete(
        StepReading(
          authoritativeTotal: 3000,
          localDate: DateTime(2026, 7, 31),
          timeZone: 'Europe/Berlin',
        ),
      );

      await expectLater(
        action,
        throwsA(isA<ValidationOwnerMismatchException>()),
      );
      expect(controller.snapshot.journal, isEmpty);
      expect(controller.snapshot.latestHealth, isNull);
    },
  );

  test(
    'wall-clock rollback during an action preserves causal evidence',
    () async {
      final List<DateTime> times = <DateTime>[
        DateTime.utc(2026, 7, 31, 18, 10),
        DateTime.utc(2026, 7, 31, 17),
        DateTime.utc(2026, 7, 31, 16),
      ];
      int clockIndex = 0;
      final Completer<StepReading> pending = Completer<StepReading>();
      final ValidationEvidenceController controller =
          ValidationEvidenceController(
            ownerId: 'owner-1',
            activeOwnerProvider: () => 'owner-1',
            sessionRevision: 0,
            activeSessionRevisionProvider: () => 0,
            launch: _launch(),
            stepReader: () => pending.future,
            homeLoader: () async => firstJourneyHome(),
            platformLoader: () async => platformSnapshot(),
            clock: () {
              if (clockIndex < times.length) {
                return times[clockIndex++];
              }
              return times.last;
            },
            monotonicMillis: () => 0,
          );
      addTearDown(controller.dispose);

      final Future<void> action = controller.readHealth(
        activeOwnerId: 'owner-1',
      );
      pending.complete(
        StepReading(
          authoritativeTotal: 3000,
          localDate: DateTime(2026, 7, 31),
          timeZone: 'Europe/Berlin',
        ),
      );
      await action;

      expect(
        controller.snapshot.updatedAtUtc,
        DateTime.utc(2026, 7, 31, 18, 10),
      );
      expect(
        DeviceValidationEvidenceCodec.verify(
          controller.encode(activeOwnerId: 'owner-1'),
        ),
        isTrue,
      );
    },
  );

  test('records and exposes an action blocked by the journal bound', () async {
    int readCalls = 0;
    int homeLoads = 0;
    final ValidationEvidenceController controller =
        ValidationEvidenceController(
          ownerId: 'owner-1',
          activeOwnerProvider: () => 'owner-1',
          sessionRevision: 0,
          activeSessionRevisionProvider: () => 0,
          launch: _launch(),
          stepReader: () async {
            readCalls += 1;
            return StepReading(
              authoritativeTotal: 3000,
              localDate: DateTime(2026, 7, 31),
              timeZone: 'Europe/Berlin',
            );
          },
          homeLoader: () async {
            homeLoads += 1;
            return firstJourneyHome();
          },
          platformLoader: () async => platformSnapshot(),
          clock: () => DateTime.utc(2026, 7, 31, 18, 4),
          monotonicMillis: () => 0,
        );
    addTearDown(controller.dispose);

    for (int index = 0; index < 62; index += 1) {
      await controller.captureAuthoritativeCheckpoint(activeOwnerId: 'owner-1');
    }
    expect(controller.snapshot.journal, hasLength(62));
    expect(homeLoads, 62);
    expect(controller.journalFull, isFalse);

    await expectLater(
      controller.readHealth(activeOwnerId: 'owner-1'),
      throwsA(
        isA<ValidationActionException>().having(
          (ValidationActionException error) => error.category,
          'category',
          EvidenceErrorCategory.journalLimitReached,
        ),
      ),
    );

    expect(readCalls, 0);
    expect(controller.journalFull, isTrue);
    expect(controller.snapshot.journal, hasLength(63));
    expect(controller.snapshot.journal.last.scenario, EvidenceScenario.read);
    expect(controller.snapshot.journal.last.outcome, EvidenceOutcome.blocked);
    expect(
      controller.snapshot.journal.last.errorCategory,
      EvidenceErrorCategory.journalLimitReached,
    );
    final List<EvidenceJournalEntry> terminalJournal =
        controller.snapshot.journal;
    await expectLater(
      controller.captureAuthoritativeCheckpoint(activeOwnerId: 'owner-1'),
      throwsA(
        isA<ValidationActionException>().having(
          (ValidationActionException error) => error.category,
          'category',
          EvidenceErrorCategory.journalLimitReached,
        ),
      ),
    );
    expect(identical(controller.snapshot.journal, terminalJournal), isTrue);
    expect(homeLoads, 62);
    expect(
      DeviceValidationEvidenceCodec.verify(
        controller.encode(activeOwnerId: 'owner-1'),
      ),
      isTrue,
    );
  });

  test('reserves the 64th journal slot for an overflow marker', () async {
    int homeLoads = 0;
    final ValidationEvidenceController controller =
        ValidationEvidenceController(
          ownerId: 'owner-1',
          activeOwnerProvider: () => 'owner-1',
          sessionRevision: 0,
          activeSessionRevisionProvider: () => 0,
          launch: _launch(),
          homeLoader: () async {
            homeLoads += 1;
            return firstJourneyHome();
          },
          platformLoader: () async => platformSnapshot(),
          clock: () => DateTime.utc(2026, 7, 31, 18, 4),
          monotonicMillis: () => 0,
        );
    addTearDown(controller.dispose);

    for (int index = 0; index < 63; index += 1) {
      await controller.captureAuthoritativeCheckpoint(activeOwnerId: 'owner-1');
    }
    await expectLater(
      controller.captureAuthoritativeCheckpoint(activeOwnerId: 'owner-1'),
      throwsA(
        isA<ValidationActionException>().having(
          (ValidationActionException error) => error.category,
          'category',
          EvidenceErrorCategory.journalLimitReached,
        ),
      ),
    );

    expect(homeLoads, 63);
    expect(controller.snapshot.journal, hasLength(64));
    expect(
      controller.snapshot.journal.last.errorCategory,
      EvidenceErrorCategory.journalLimitReached,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        controller.encode(activeOwnerId: 'owner-1'),
      ),
      isTrue,
    );
  });

  test('dispose erases already recorded owner-bound observations', () async {
    final ValidationEvidenceController controller =
        ValidationEvidenceController(
          ownerId: 'owner-1',
          activeOwnerProvider: () => 'owner-1',
          sessionRevision: 0,
          activeSessionRevisionProvider: () => 0,
          launch: _launch(),
          stepReader: () async => StepReading(
            authoritativeTotal: 3000,
            localDate: DateTime(2026, 7, 31),
            timeZone: 'Europe/Berlin',
          ),
          homeLoader: () async => firstJourneyHome(),
          platformLoader: () async => platformSnapshot(),
        );
    await controller.readHealth(activeOwnerId: 'owner-1');
    expect(controller.snapshot.latestHealth, isNotNull);

    controller.dispose();

    expect(controller.snapshot.latestHealth, isNull);
    expect(controller.snapshot.latestSync, isNull);
    expect(controller.snapshot.authoritativeCheckpoint, isNull);
    expect(controller.snapshot.journal, isEmpty);
    expect(
      () => controller.encode(activeOwnerId: 'owner-1'),
      throwsA(isA<ValidationOwnerMismatchException>()),
    );
  });
}

EvidenceLaunchMetadata _launch() {
  return EvidenceLaunchMetadata(
    startedAtUtc: DateTime.utc(2026, 7, 31, 18),
    platform: 'android',
    operatingSystemVersion: 'Android 16',
    appVersion: '0.1.0',
    buildNumber: '46',
    sourceGitSha: '0123456789abcdef0123456789abcdef01234567',
    buildMode: 'debug',
    authenticationMode: 'oidc',
    healthSource: EvidenceHealthSource.healthConnect,
  );
}
