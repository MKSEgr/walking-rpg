abstract final class AppEnvironment {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String mobileAuthMode = String.fromEnvironment(
    'MOBILE_AUTH_MODE',
    defaultValue: 'oidc',
  );

  static const String nativeOidcRedirectScheme = 'com.walkingrpg.app';

  static const String oidcIssuer = String.fromEnvironment('OIDC_ISSUER');

  static const String oidcClientId = String.fromEnvironment('OIDC_CLIENT_ID');

  static const String oidcRedirectUri = String.fromEnvironment(
    'OIDC_REDIRECT_URI',
    defaultValue: 'com.walkingrpg.app:/oauthredirect',
  );

  static const String oidcPostLogoutRedirectUri = String.fromEnvironment(
    'OIDC_POST_LOGOUT_REDIRECT_URI',
    defaultValue: 'com.walkingrpg.app:/logout',
  );

  static const String oidcScopes = String.fromEnvironment(
    'OIDC_SCOPES',
    defaultValue: 'openid profile offline_access walking-rpg.user',
  );

  static const bool oidcAllowInsecureConnections = bool.fromEnvironment(
    'OIDC_ALLOW_INSECURE_CONNECTIONS',
    defaultValue: false,
  );

  static const int authRefreshSkewSeconds = int.fromEnvironment(
    'AUTH_REFRESH_SKEW_SECONDS',
    defaultValue: 60,
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

  static const bool enableValidationCenter = bool.fromEnvironment(
    'ENABLE_VALIDATION_CENTER',
    defaultValue: false,
  );

  static const String validationSourceGitSha = String.fromEnvironment(
    'VALIDATION_SOURCE_GIT_SHA',
  );
}
