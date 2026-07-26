import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/activity/data/activity_recognition_gateway.dart';
import 'package:walking_rpg_mobile/features/activity/data/device_time_zone_provider.dart';
import 'package:walking_rpg_mobile/features/activity/data/health_gateway.dart';
import 'package:walking_rpg_mobile/features/activity/data/platform_health_step_source.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';

void main() {
  test('iOS reads aggregate from local midnight with IANA timezone', () async {
    final _FakeHealthGateway health = _FakeHealthGateway(totalSteps: 6842);
    final PlatformHealthStepSource source = PlatformHealthStepSource(
      healthGateway: health,
      activityRecognitionGateway: _FakeActivityRecognitionGateway(),
      timeZoneProvider: const _FakeTimeZoneProvider('Europe/Berlin'),
      platform: HealthStepPlatform.ios,
      now: () => DateTime(2026, 7, 26, 12, 30),
    );

    final StepReading reading = await source.read();

    expect(reading.authoritativeTotal, 6842);
    expect(reading.localDateIso, '2026-07-26');
    expect(reading.timeZone, 'Europe/Berlin');
    expect(reading.syncCursor, 'health:2026-07-26:6842');
    expect(health.requestedStart, DateTime(2026, 7, 26));
    expect(health.requestedEnd, DateTime(2026, 7, 26, 12, 30));
    expect(health.includeManualEntries, isFalse);
    expect(health.configureCalls, 1);
    expect(health.authorizationRequests, 1);
  });

  test('null platform total is represented as zero steps', () async {
    final PlatformHealthStepSource source = PlatformHealthStepSource(
      healthGateway: _FakeHealthGateway(totalSteps: null),
      activityRecognitionGateway: _FakeActivityRecognitionGateway(),
      timeZoneProvider: const _FakeTimeZoneProvider('UTC'),
      platform: HealthStepPlatform.ios,
      now: () => DateTime(2026, 7, 26, 8),
    );

    final StepReading reading = await source.read();

    expect(reading.authoritativeTotal, 0);
    expect(reading.syncCursor, 'health:2026-07-26:0');
  });

  test(
    'Android reports provider update requirement before authorization',
    () async {
      final _FakeHealthGateway health = _FakeHealthGateway(
        availability: HealthConnectAvailability.providerUpdateRequired,
      );
      final PlatformHealthStepSource source = PlatformHealthStepSource(
        healthGateway: health,
        activityRecognitionGateway: _FakeActivityRecognitionGateway(),
        timeZoneProvider: const _FakeTimeZoneProvider('UTC'),
        platform: HealthStepPlatform.android,
      );

      await expectLater(
        source.read(),
        throwsA(
          isA<PlatformHealthStepException>().having(
            (PlatformHealthStepException error) => error.failure,
            'failure',
            PlatformHealthStepFailure.providerUpdateRequired,
          ),
        ),
      );
      expect(health.authorizationRequests, 0);
    },
  );

  test(
    'Android requests activity recognition before Health Connect access',
    () async {
      final _FakeHealthGateway health = _FakeHealthGateway(totalSteps: 100);
      final _FakeActivityRecognitionGateway recognition =
          _FakeActivityRecognitionGateway(
            checked: ActivityRecognitionPermissionState.denied,
            requested: ActivityRecognitionPermissionState.granted,
          );
      final PlatformHealthStepSource source = PlatformHealthStepSource(
        healthGateway: health,
        activityRecognitionGateway: recognition,
        timeZoneProvider: const _FakeTimeZoneProvider('Europe/Berlin'),
        platform: HealthStepPlatform.android,
        now: () => DateTime(2026, 7, 26, 9),
      );

      final StepReading reading = await source.read();

      expect(reading.authoritativeTotal, 100);
      expect(recognition.checkCalls, 1);
      expect(recognition.requestCalls, 1);
      expect(health.authorizationRequests, 1);
    },
  );

  test('Android permanent denial points user to settings', () async {
    final _FakeActivityRecognitionGateway recognition =
        _FakeActivityRecognitionGateway(
          checked: ActivityRecognitionPermissionState.permanentlyDenied,
        );
    final PlatformHealthStepSource source = PlatformHealthStepSource(
      healthGateway: _FakeHealthGateway(),
      activityRecognitionGateway: recognition,
      timeZoneProvider: const _FakeTimeZoneProvider('UTC'),
      platform: HealthStepPlatform.android,
    );

    await expectLater(
      source.read(),
      throwsA(
        isA<PlatformHealthStepException>().having(
          (PlatformHealthStepException error) => error.failure,
          'failure',
          PlatformHealthStepFailure.activityRecognitionSettingsRequired,
        ),
      ),
    );
    expect(recognition.requestCalls, 0);
  });

  test('health authorization denial is exposed as a stable failure', () async {
    final PlatformHealthStepSource source = PlatformHealthStepSource(
      healthGateway: _FakeHealthGateway(authorizationResult: false),
      activityRecognitionGateway: _FakeActivityRecognitionGateway(),
      timeZoneProvider: const _FakeTimeZoneProvider('UTC'),
      platform: HealthStepPlatform.ios,
    );

    await expectLater(
      source.read(),
      throwsA(
        isA<PlatformHealthStepException>().having(
          (PlatformHealthStepException error) => error.failure,
          'failure',
          PlatformHealthStepFailure.authorizationDenied,
        ),
      ),
    );
  });

  test(
    'locked iOS protected data gets a specific user-facing failure',
    () async {
      final PlatformHealthStepSource source = PlatformHealthStepSource(
        healthGateway: _FakeHealthGateway(
          readError: PlatformException(
            code: 'FlutterHealth',
            message: 'Protected health data is inaccessible',
          ),
        ),
        activityRecognitionGateway: _FakeActivityRecognitionGateway(),
        timeZoneProvider: const _FakeTimeZoneProvider('UTC'),
        platform: HealthStepPlatform.ios,
      );

      await expectLater(
        source.read(),
        throwsA(
          isA<PlatformHealthStepException>().having(
            (PlatformHealthStepException error) => error.failure,
            'failure',
            PlatformHealthStepFailure.protectedDataUnavailable,
          ),
        ),
      );
    },
  );
}

class _FakeHealthGateway implements HealthGateway {
  _FakeHealthGateway({
    this.availability = HealthConnectAvailability.available,
    this.authorizationResult = true,
    this.totalSteps = 0,
    this.readError,
  });

  final HealthConnectAvailability availability;
  final bool authorizationResult;
  final int? totalSteps;
  final Object? readError;

  int configureCalls = 0;
  int authorizationRequests = 0;
  DateTime? requestedStart;
  DateTime? requestedEnd;
  bool? includeManualEntries;

  @override
  Future<void> configure() async {
    configureCalls += 1;
  }

  @override
  Future<HealthConnectAvailability> getHealthConnectAvailability() async {
    return availability;
  }

  @override
  Future<int?> readTotalSteps({
    required DateTime start,
    required DateTime end,
    required bool includeManualEntries,
  }) async {
    requestedStart = start;
    requestedEnd = end;
    this.includeManualEntries = includeManualEntries;
    final Object? error = readError;
    if (error != null) {
      throw error;
    }
    return totalSteps;
  }

  @override
  Future<bool> requestStepReadPermission() async {
    authorizationRequests += 1;
    return authorizationResult;
  }
}

class _FakeActivityRecognitionGateway implements ActivityRecognitionGateway {
  _FakeActivityRecognitionGateway({
    this.checked = ActivityRecognitionPermissionState.granted,
    this.requested = ActivityRecognitionPermissionState.granted,
  });

  final ActivityRecognitionPermissionState checked;
  final ActivityRecognitionPermissionState requested;

  int checkCalls = 0;
  int requestCalls = 0;

  @override
  Future<ActivityRecognitionPermissionState> check() async {
    checkCalls += 1;
    return checked;
  }

  @override
  Future<ActivityRecognitionPermissionState> request() async {
    requestCalls += 1;
    return requested;
  }
}

class _FakeTimeZoneProvider implements DeviceTimeZoneProvider {
  const _FakeTimeZoneProvider(this.identifier);

  final String identifier;

  @override
  Future<String> getIdentifier() async => identifier;
}
