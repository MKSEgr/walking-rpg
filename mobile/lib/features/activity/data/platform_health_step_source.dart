import 'dart:io';

import 'package:flutter/services.dart';
import 'package:walking_rpg_mobile/features/activity/data/activity_recognition_gateway.dart';
import 'package:walking_rpg_mobile/features/activity/data/device_time_zone_provider.dart';
import 'package:walking_rpg_mobile/features/activity/data/health_gateway.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_source.dart';

class PlatformHealthStepSource implements StepSource {
  PlatformHealthStepSource({
    required HealthGateway healthGateway,
    required ActivityRecognitionGateway activityRecognitionGateway,
    required DeviceTimeZoneProvider timeZoneProvider,
    required HealthStepPlatform platform,
    DateTime Function()? now,
    this.includeManualEntries = false,
  }) : _healthGateway = healthGateway,
       _activityRecognitionGateway = activityRecognitionGateway,
       _timeZoneProvider = timeZoneProvider,
       _platform = platform,
       _now = now ?? DateTime.now;

  static PlatformHealthStepSource? systemIfSupported() {
    final HealthStepPlatform platform;
    final ActivityRecognitionGateway activityRecognitionGateway;
    if (Platform.isAndroid) {
      platform = HealthStepPlatform.android;
      activityRecognitionGateway =
          const PermissionHandlerActivityRecognitionGateway();
    } else if (Platform.isIOS) {
      platform = HealthStepPlatform.ios;
      activityRecognitionGateway = const NoopActivityRecognitionGateway();
    } else {
      return null;
    }

    return PlatformHealthStepSource(
      healthGateway: HealthPluginGateway(),
      activityRecognitionGateway: activityRecognitionGateway,
      timeZoneProvider: const FlutterDeviceTimeZoneProvider(),
      platform: platform,
    );
  }

  final HealthGateway _healthGateway;
  final ActivityRecognitionGateway _activityRecognitionGateway;
  final DeviceTimeZoneProvider _timeZoneProvider;
  final HealthStepPlatform _platform;
  final DateTime Function() _now;
  final bool includeManualEntries;

  bool _configured = false;

  @override
  Future<StepReading> read() async {
    try {
      await _prepareProvider();
      await _requestActivityRecognitionIfNeeded();

      final bool authorized = await _healthGateway.requestStepReadPermission();
      if (!authorized) {
        throw const PlatformHealthStepException(
          PlatformHealthStepFailure.authorizationDenied,
          'Доступ к шагам не предоставлен',
        );
      }

      final DateTime current = _now().toLocal();
      final DateTime localDate = DateTime(
        current.year,
        current.month,
        current.day,
      );
      final String timeZone = await _timeZoneProvider.getIdentifier();
      final int total =
          await _healthGateway.readTotalSteps(
            start: localDate,
            end: current,
            includeManualEntries: includeManualEntries,
          ) ??
          0;

      return StepReading(
        authoritativeTotal: total,
        localDate: localDate,
        timeZone: timeZone,
        syncCursor: 'health:${_formatDate(localDate)}:$total',
      );
    } on PlatformHealthStepException {
      rethrow;
    } on DeviceTimeZoneException catch (error) {
      throw PlatformHealthStepException(
        PlatformHealthStepFailure.timeZoneUnavailable,
        error.message,
        cause: error,
      );
    } on PlatformException catch (error) {
      final String details = '${error.code} ${error.message} ${error.details}';
      if (details.toLowerCase().contains(
        'protected health data is inaccessible',
      )) {
        throw PlatformHealthStepException(
          PlatformHealthStepFailure.protectedDataUnavailable,
          'Данные Apple Health недоступны, пока устройство заблокировано',
          cause: error,
        );
      }
      throw PlatformHealthStepException(
        PlatformHealthStepFailure.readFailed,
        'Не удалось прочитать шаги из системного хранилища здоровья',
        cause: error,
      );
    } catch (error) {
      throw PlatformHealthStepException(
        PlatformHealthStepFailure.readFailed,
        'Не удалось прочитать шаги из системного хранилища здоровья',
        cause: error,
      );
    }
  }

  Future<void> _prepareProvider() async {
    if (_platform == HealthStepPlatform.unsupported) {
      throw const PlatformHealthStepException(
        PlatformHealthStepFailure.unsupportedPlatform,
        'Платформа не поддерживает Apple Health или Health Connect',
      );
    }
    if (!_configured) {
      await _healthGateway.configure();
      _configured = true;
    }
    if (_platform == HealthStepPlatform.ios) {
      return;
    }

    final HealthConnectAvailability availability = await _healthGateway
        .getHealthConnectAvailability();
    switch (availability) {
      case HealthConnectAvailability.available:
        return;
      case HealthConnectAvailability.providerUpdateRequired:
        throw const PlatformHealthStepException(
          PlatformHealthStepFailure.providerUpdateRequired,
          'Health Connect нужно установить или обновить',
        );
      case HealthConnectAvailability.unavailable:
        throw const PlatformHealthStepException(
          PlatformHealthStepFailure.providerUnavailable,
          'Health Connect недоступен на этом устройстве',
        );
    }
  }

  Future<void> _requestActivityRecognitionIfNeeded() async {
    if (_platform != HealthStepPlatform.android) {
      return;
    }

    final ActivityRecognitionPermissionState current =
        await _activityRecognitionGateway.check();
    if (current == ActivityRecognitionPermissionState.granted) {
      return;
    }
    if (current == ActivityRecognitionPermissionState.permanentlyDenied) {
      throw const PlatformHealthStepException(
        PlatformHealthStepFailure.activityRecognitionSettingsRequired,
        'Разрешение на физическую активность нужно включить в настройках Android',
      );
    }
    if (current == ActivityRecognitionPermissionState.restricted) {
      throw const PlatformHealthStepException(
        PlatformHealthStepFailure.activityRecognitionRestricted,
        'Доступ к физической активности ограничен системой',
      );
    }

    final ActivityRecognitionPermissionState requested =
        await _activityRecognitionGateway.request();
    switch (requested) {
      case ActivityRecognitionPermissionState.granted:
        return;
      case ActivityRecognitionPermissionState.permanentlyDenied:
        throw const PlatformHealthStepException(
          PlatformHealthStepFailure.activityRecognitionSettingsRequired,
          'Разрешение на физическую активность нужно включить в настройках Android',
        );
      case ActivityRecognitionPermissionState.restricted:
        throw const PlatformHealthStepException(
          PlatformHealthStepFailure.activityRecognitionRestricted,
          'Доступ к физической активности ограничен системой',
        );
      case ActivityRecognitionPermissionState.denied:
        throw const PlatformHealthStepException(
          PlatformHealthStepFailure.activityRecognitionDenied,
          'Android не предоставил доступ к физической активности',
        );
    }
  }

  static String _formatDate(DateTime value) {
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

enum HealthStepPlatform { ios, android, unsupported }

enum PlatformHealthStepFailure {
  unsupportedPlatform,
  providerUpdateRequired,
  providerUnavailable,
  activityRecognitionDenied,
  activityRecognitionSettingsRequired,
  activityRecognitionRestricted,
  authorizationDenied,
  protectedDataUnavailable,
  timeZoneUnavailable,
  readFailed,
}

class PlatformHealthStepException implements Exception {
  const PlatformHealthStepException(this.failure, this.message, {this.cause});

  final PlatformHealthStepFailure failure;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
