import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/activity/data/activity_api_client.dart';
import 'package:walking_rpg_mobile/features/activity/data/development_step_source.dart';
import 'package:walking_rpg_mobile/features/activity/data/platform_health_step_source.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_source.dart';

typedef ActivitySyncSender =
    Future<ActivitySyncResult> Function({
      required StepReading reading,
      required String idempotencyKey,
    });
typedef ActivityIdempotencyKeyFactory = String Function(StepReading reading);

class ActivitySyncCoordinator {
  ActivitySyncCoordinator({
    required this.stepSource,
    required this.sender,
    ActivityIdempotencyKeyFactory? idempotencyKeyFactory,
  }) : _idempotencyKeyFactory = idempotencyKeyFactory ?? _defaultIdempotencyKey;

  factory ActivitySyncCoordinator.fromEnvironment() {
    final ActivitySyncCoordinator? coordinator =
        ActivitySyncCoordinator.fromEnvironmentIfSupported();
    if (coordinator == null) {
      throw UnsupportedError(
        'Синхронизация системных шагов доступна только на Android и iOS',
      );
    }
    return coordinator;
  }

  static ActivitySyncCoordinator? fromEnvironmentIfSupported() {
    final StepSource? source;
    if (AppEnvironment.enableDemoActivitySync) {
      source = DevelopmentStepSource.fromEnvironment();
    } else {
      source = PlatformHealthStepSource.systemIfSupported();
    }
    if (source == null) {
      return null;
    }

    final ActivityApiClient client = ActivityApiClient.fromEnvironment();
    return ActivitySyncCoordinator(stepSource: source, sender: client.sync);
  }

  final StepSource stepSource;
  final ActivitySyncSender sender;
  final ActivityIdempotencyKeyFactory _idempotencyKeyFactory;

  StepReading? _pendingReading;
  String? _pendingKey;

  Future<ActivitySyncResult> synchronize() async {
    final StepReading reading = await stepSource.read();
    if (_pendingReading != reading || _pendingKey == null) {
      _pendingReading = reading;
      _pendingKey = _idempotencyKeyFactory(reading);
    }

    final ActivitySyncResult result = await sender(
      reading: reading,
      idempotencyKey: _pendingKey!,
    );
    _pendingReading = null;
    _pendingKey = null;
    return result;
  }

  static String _defaultIdempotencyKey(StepReading reading) {
    return 'activity-${reading.localDateIso}-${reading.authoritativeTotal}-'
        '${DateTime.now().microsecondsSinceEpoch}';
  }
}
