abstract final class AppEnvironment {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String demoUserId = String.fromEnvironment(
    'DEMO_USER_ID',
    defaultValue: 'demo-user-1',
  );

  static const String demoDeviceId = String.fromEnvironment(
    'DEMO_DEVICE_ID',
    defaultValue: 'demo-device-1',
  );

  static const bool enableDemoActivitySync = bool.fromEnvironment(
    'ENABLE_DEMO_ACTIVITY_SYNC',
    defaultValue: false,
  );

  static const int demoStepTotal = int.fromEnvironment(
    'DEMO_STEP_TOTAL',
    defaultValue: 0,
  );

  static const String activityTimeZone = String.fromEnvironment(
    'ACTIVITY_TIME_ZONE',
    defaultValue: 'UTC',
  );
}
