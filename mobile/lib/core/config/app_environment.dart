abstract final class AppEnvironment {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String demoUserId = String.fromEnvironment(
    'DEMO_USER_ID',
    defaultValue: 'demo-user-1',
  );
}
