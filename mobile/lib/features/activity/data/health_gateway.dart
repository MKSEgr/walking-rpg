import 'package:health/health.dart';

abstract interface class HealthGateway {
  Future<void> configure();

  Future<HealthConnectAvailability> getHealthConnectAvailability();

  Future<bool> requestStepReadPermission();

  Future<int?> readTotalSteps({
    required DateTime start,
    required DateTime end,
    required bool includeManualEntries,
  });
}

enum HealthConnectAvailability {
  available,
  providerUpdateRequired,
  unavailable,
}

class HealthPluginGateway implements HealthGateway {
  HealthPluginGateway({Health? health}) : _health = health ?? Health();

  static const List<HealthDataType> _stepTypes = <HealthDataType>[
    HealthDataType.STEPS,
  ];
  static const List<HealthDataAccess> _readPermissions = <HealthDataAccess>[
    HealthDataAccess.READ,
  ];

  final Health _health;

  @override
  Future<void> configure() => _health.configure();

  @override
  Future<HealthConnectAvailability> getHealthConnectAvailability() async {
    final HealthConnectSdkStatus? status = await _health
        .getHealthConnectSdkStatus();
    return switch (status) {
      HealthConnectSdkStatus.sdkAvailable =>
        HealthConnectAvailability.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        HealthConnectAvailability.providerUpdateRequired,
      _ => HealthConnectAvailability.unavailable,
    };
  }

  @override
  Future<bool> requestStepReadPermission() {
    return _health.requestAuthorization(
      _stepTypes,
      permissions: _readPermissions,
    );
  }

  @override
  Future<int?> readTotalSteps({
    required DateTime start,
    required DateTime end,
    required bool includeManualEntries,
  }) {
    return _health.getTotalStepsInInterval(
      start,
      end,
      includeManualEntry: includeManualEntries,
    );
  }
}
