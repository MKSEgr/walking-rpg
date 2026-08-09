import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';

enum MobileAuthMode {
  oidc,
  development;

  static MobileAuthMode parse(String value) {
    switch (value.trim().toLowerCase()) {
      case 'oidc':
        return MobileAuthMode.oidc;
      case 'development':
      case 'dev':
      case 'dev-header':
        return MobileAuthMode.development;
      default:
        throw const AuthConfigurationException(
          'MOBILE_AUTH_MODE должен быть oidc или development',
        );
    }
  }
}

final class MobileAuthConfiguration {
  const MobileAuthConfiguration({
    required this.mode,
    required this.apiBaseUri,
    required this.refreshSkew,
    this.oidc,
    this.developmentUserId,
    this.developmentDeviceId,
  });

  factory MobileAuthConfiguration.fromEnvironment() {
    final MobileAuthMode mode = MobileAuthMode.parse(
      AppEnvironment.mobileAuthMode,
    );
    final Uri apiBaseUri = _requireHttpUri(
      AppEnvironment.apiBaseUrl,
      field: 'API_BASE_URL',
      allowInsecure: !kReleaseMode,
    );
    const Duration refreshSkew = Duration(
      seconds: AppEnvironment.authRefreshSkewSeconds,
    );
    if (refreshSkew.isNegative) {
      throw const AuthConfigurationException(
        'AUTH_REFRESH_SKEW_SECONDS не может быть отрицательным',
      );
    }

    if (mode == MobileAuthMode.development) {
      if (kReleaseMode) {
        throw const AuthConfigurationException(
          'Development-аутентификация запрещена в production build',
        );
      }
      return MobileAuthConfiguration(
        mode: mode,
        apiBaseUri: apiBaseUri,
        refreshSkew: refreshSkew,
        developmentUserId: _requireText(
          AppEnvironment.demoUserId,
          'DEMO_USER_ID',
        ),
        developmentDeviceId: _requireText(
          AppEnvironment.demoDeviceId,
          'DEMO_DEVICE_ID',
        ),
      );
    }

    const bool allowInsecure =
        AppEnvironment.oidcAllowInsecureConnections && !kReleaseMode;
    final Uri issuer = _requireHttpUri(
      AppEnvironment.oidcIssuer,
      field: 'OIDC_ISSUER',
      allowInsecure: allowInsecure,
    );
    final Uri redirectUri = _requireRedirectUri(
      AppEnvironment.oidcRedirectUri,
      'OIDC_REDIRECT_URI',
      expectedScheme: AppEnvironment.nativeOidcRedirectScheme,
    );
    final Uri postLogoutRedirectUri = _requireRedirectUri(
      AppEnvironment.oidcPostLogoutRedirectUri,
      'OIDC_POST_LOGOUT_REDIRECT_URI',
      expectedScheme: AppEnvironment.nativeOidcRedirectScheme,
    );
    final List<String> scopes = AppEnvironment.oidcScopes
        .split(RegExp(r'[\s,]+'))
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (!scopes.contains('openid')) {
      throw const AuthConfigurationException(
        'OIDC_SCOPES должен содержать openid',
      );
    }

    return MobileAuthConfiguration(
      mode: mode,
      apiBaseUri: apiBaseUri,
      refreshSkew: refreshSkew,
      oidc: OidcConfiguration(
        issuer: issuer,
        clientId: _requireText(AppEnvironment.oidcClientId, 'OIDC_CLIENT_ID'),
        audience: _requireText(AppEnvironment.oidcAudience, 'OIDC_AUDIENCE'),
        redirectUri: redirectUri,
        postLogoutRedirectUri: postLogoutRedirectUri,
        scopes: scopes,
        allowInsecureConnections: allowInsecure,
      ),
    );
  }

  final MobileAuthMode mode;
  final Uri apiBaseUri;
  final Duration refreshSkew;
  final OidcConfiguration? oidc;
  final String? developmentUserId;
  final String? developmentDeviceId;
}

final class OidcConfiguration {
  const OidcConfiguration({
    required this.issuer,
    required this.clientId,
    required this.audience,
    required this.redirectUri,
    required this.postLogoutRedirectUri,
    required this.scopes,
    required this.allowInsecureConnections,
  });

  final Uri issuer;
  final String clientId;
  final String audience;
  final Uri redirectUri;
  final Uri postLogoutRedirectUri;
  final List<String> scopes;
  final bool allowInsecureConnections;
}

final class AuthIdentity {
  const AuthIdentity({
    required this.ownerId,
    required this.issuer,
    required this.subject,
    required this.displayName,
    required this.isDevelopment,
  });

  factory AuthIdentity.development(String userId) {
    final String normalized = _requireText(userId, 'userId');
    return AuthIdentity(
      ownerId: _partitionId('dev', 'development', normalized),
      issuer: 'development',
      subject: normalized,
      displayName: normalized,
      isDevelopment: true,
    );
  }

  factory AuthIdentity.fromTokens({
    required OidcConfiguration configuration,
    required String accessToken,
    String? idToken,
    String? fallbackDisplayName,
  }) {
    final Map<String, Object?> accessClaims = decodeJwtClaims(accessToken);
    final String expectedIssuer = canonicalIssuer(
      configuration.issuer.toString(),
    );
    final String issuer = canonicalIssuer(
      _requireClaimText(accessClaims, 'iss'),
    );
    if (issuer != expectedIssuer) {
      throw const AuthTokenException(
        'OIDC issuer не совпадает с настроенным issuer',
      );
    }
    final String subject = _requireClaimText(accessClaims, 'sub');

    Map<String, Object?> displayClaims = accessClaims;
    final String? normalizedIdToken = _optionalText(idToken);
    if (normalizedIdToken != null) {
      final Map<String, Object?> idClaims = decodeJwtClaims(normalizedIdToken);
      final String idIssuer = canonicalIssuer(
        _requireClaimText(idClaims, 'iss'),
      );
      final String idSubject = _requireClaimText(idClaims, 'sub');
      if (idIssuer != issuer || idSubject != subject) {
        throw const AuthTokenException(
          'ID token не соответствует identity из access token',
        );
      }
      displayClaims = idClaims;
    }

    final String displayName =
        _firstClaimText(displayClaims, const <String>[
          'preferred_username',
          'name',
          'email',
        ]) ??
        _firstClaimText(accessClaims, const <String>[
          'preferred_username',
          'name',
          'email',
        ]) ??
        _optionalText(fallbackDisplayName) ??
        subject;
    return AuthIdentity(
      ownerId: _partitionId('oidc', issuer, subject),
      issuer: issuer,
      subject: subject,
      displayName: displayName,
      isDevelopment: false,
    );
  }

  factory AuthIdentity.fromJson(Map<String, Object?> json) {
    final String issuer = canonicalIssuer(_readText(json, 'issuer'));
    final String subject = _readText(json, 'subject');
    final String ownerId = _readText(json, 'ownerId');
    final String expectedOwnerId = _partitionId('oidc', issuer, subject);
    if (ownerId != expectedOwnerId) {
      throw const FormatException('Некорректная локальная identity partition');
    }
    return AuthIdentity(
      ownerId: ownerId,
      issuer: issuer,
      subject: subject,
      displayName: _readText(json, 'displayName'),
      isDevelopment: false,
    );
  }

  final String ownerId;
  final String issuer;
  final String subject;
  final String displayName;
  final bool isDevelopment;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ownerId': ownerId,
      'issuer': issuer,
      'subject': subject,
      'displayName': displayName,
    };
  }
}

final class OidcTokenResponseData {
  const OidcTokenResponseData({
    required this.accessToken,
    required this.accessTokenExpiration,
    this.refreshToken,
    this.idToken,
    this.tokenType,
    this.scopes,
  });

  final String accessToken;
  final DateTime accessTokenExpiration;
  final String? refreshToken;
  final String? idToken;
  final String? tokenType;
  final List<String>? scopes;
}

final class AuthTokenSet {
  const AuthTokenSet({
    required this.accessToken,
    required this.accessTokenExpiration,
    required this.tokenType,
    required this.scopes,
    this.refreshToken,
    this.idToken,
  });

  factory AuthTokenSet.fromResponse(
    OidcTokenResponseData response, {
    required List<String> fallbackScopes,
  }) {
    final String tokenType = (response.tokenType ?? 'Bearer').trim();
    if (tokenType.toLowerCase() != 'bearer') {
      throw const AuthTokenException(
        'Поддерживается только Bearer access token',
      );
    }
    return AuthTokenSet(
      accessToken: _requireTokenText(response.accessToken, 'accessToken'),
      accessTokenExpiration: response.accessTokenExpiration.toUtc(),
      refreshToken: _optionalText(response.refreshToken),
      idToken: _optionalText(response.idToken),
      tokenType: 'Bearer',
      scopes: List<String>.unmodifiable(
        response.scopes == null || response.scopes!.isEmpty
            ? fallbackScopes
            : response.scopes!,
      ),
    );
  }

  factory AuthTokenSet.fromJson(Map<String, Object?> json) {
    final Object? rawScopes = json['scopes'];
    if (rawScopes is! List<Object?>) {
      throw const FormatException('scopes должен быть массивом');
    }
    final List<String> scopes = rawScopes
        .map<String>((Object? value) {
          if (value is! String || value.trim().isEmpty) {
            throw const FormatException(
              'scopes содержит некорректное значение',
            );
          }
          return value;
        })
        .toList(growable: false);
    final String tokenType = _readText(json, 'tokenType');
    if (tokenType.toLowerCase() != 'bearer') {
      throw const FormatException('Поддерживается только Bearer token');
    }
    return AuthTokenSet(
      accessToken: _readText(json, 'accessToken'),
      accessTokenExpiration: _readInstant(json, 'accessTokenExpiration'),
      refreshToken: _readOptionalText(json, 'refreshToken'),
      idToken: _readOptionalText(json, 'idToken'),
      tokenType: 'Bearer',
      scopes: List<String>.unmodifiable(scopes),
    );
  }

  final String accessToken;
  final DateTime accessTokenExpiration;
  final String? refreshToken;
  final String? idToken;
  final String tokenType;
  final List<String> scopes;

  bool expiresWithin(DateTime now, Duration skew) {
    return !accessTokenExpiration.isAfter(now.toUtc().add(skew));
  }

  AuthTokenSet refreshed(
    OidcTokenResponseData response, {
    required List<String> fallbackScopes,
  }) {
    return AuthTokenSet.fromResponse(
      OidcTokenResponseData(
        accessToken: response.accessToken,
        accessTokenExpiration: response.accessTokenExpiration,
        refreshToken: response.refreshToken ?? refreshToken,
        idToken: response.idToken ?? idToken,
        tokenType: response.tokenType ?? tokenType,
        scopes: response.scopes ?? scopes,
      ),
      fallbackScopes: fallbackScopes,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'accessToken': accessToken,
      'accessTokenExpiration': accessTokenExpiration.toUtc().toIso8601String(),
      'refreshToken': refreshToken,
      'idToken': idToken,
      'tokenType': tokenType,
      'scopes': scopes,
    };
  }
}

final class AuthSession {
  const AuthSession({required this.identity, required this.tokens});

  factory AuthSession.fromResponse({
    required OidcConfiguration configuration,
    required OidcTokenResponseData response,
  }) {
    final AuthTokenSet tokens = AuthTokenSet.fromResponse(
      response,
      fallbackScopes: configuration.scopes,
    );
    return AuthSession(
      identity: AuthIdentity.fromTokens(
        configuration: configuration,
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      ),
      tokens: tokens,
    );
  }

  factory AuthSession.fromJson(Map<String, Object?> json) {
    final Object? rawIdentity = json['identity'];
    final Object? rawTokens = json['tokens'];
    if (rawIdentity is! Map<Object?, Object?> ||
        rawTokens is! Map<Object?, Object?>) {
      throw const FormatException('Некорректный формат сохранённой сессии');
    }
    return AuthSession(
      identity: AuthIdentity.fromJson(_stringMap(rawIdentity)),
      tokens: AuthTokenSet.fromJson(_stringMap(rawTokens)),
    );
  }

  final AuthIdentity identity;
  final AuthTokenSet tokens;

  AuthSession validated({required OidcConfiguration configuration}) {
    final AuthIdentity validatedIdentity = AuthIdentity.fromTokens(
      configuration: configuration,
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
      fallbackDisplayName: identity.displayName,
    );
    if (validatedIdentity.ownerId != identity.ownerId) {
      throw const AuthTokenException(
        'Сохранённая identity не соответствует access token',
      );
    }
    return AuthSession(identity: validatedIdentity, tokens: tokens);
  }

  AuthSession refreshed({
    required OidcConfiguration configuration,
    required OidcTokenResponseData response,
  }) {
    final AuthTokenSet refreshedTokens = tokens.refreshed(
      response,
      fallbackScopes: configuration.scopes,
    );
    final AuthIdentity refreshedIdentity = AuthIdentity.fromTokens(
      configuration: configuration,
      accessToken: refreshedTokens.accessToken,
      idToken: refreshedTokens.idToken,
      fallbackDisplayName: identity.displayName,
    );
    if (refreshedIdentity.ownerId != identity.ownerId) {
      throw const AuthTokenException(
        'Refresh token вернул сессию другого пользователя',
      );
    }
    return AuthSession(identity: refreshedIdentity, tokens: refreshedTokens);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'identity': identity.toJson(),
      'tokens': tokens.toJson(),
    };
  }
}

Map<String, Object?> decodeJwtClaims(String token) {
  final List<String> parts = token.split('.');
  if (parts.length != 3) {
    throw const AuthTokenException('OIDC token не является JWT');
  }
  try {
    final String normalized = base64Url.normalize(parts[1]);
    final Object? decoded = jsonDecode(
      utf8.decode(base64Url.decode(normalized)),
    );
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('JWT payload должен быть объектом');
    }
    return _stringMap(decoded);
  } on FormatException catch (error) {
    throw AuthTokenException('Не удалось прочитать JWT claims: $error');
  }
}

DateTime? tokenExpirationFromJwt(String token) {
  try {
    final Object? value = decodeJwtClaims(token)['exp'];
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value is num && value == value.roundToDouble()) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * 1000,
        isUtc: true,
      );
    }
    return null;
  } on AuthTokenException {
    return null;
  }
}

String canonicalIssuer(String value) {
  if (value.trim().isEmpty) {
    throw const AuthTokenException('issuer обязателен');
  }
  final String exact = value;
  final Uri uri;
  try {
    uri = Uri.parse(exact);
  } on FormatException catch (error) {
    throw AuthTokenException('OIDC issuer содержит некорректный URI: $error');
  }
  if ((uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const AuthTokenException(
      'OIDC issuer должен быть абсолютным HTTP(S) URI без userInfo, query и fragment',
    );
  }
  // OpenID Connect requires an exact issuer identifier match. Whitespace
  // and a trailing slash are significant and must not be canonicalized.
  return exact;
}

Uri _requireHttpUri(
  String value, {
  required String field,
  required bool allowInsecure,
}) {
  final Uri uri;
  try {
    uri = Uri.parse(_requireText(value, field));
  } on FormatException {
    throw AuthConfigurationException('$field содержит некорректный URI');
  }
  if (uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.scheme != 'https' && !(allowInsecure && uri.scheme == 'http')) ||
      uri.hasFragment ||
      uri.hasQuery) {
    throw AuthConfigurationException(
      '$field должен быть абсолютным '
      '${allowInsecure ? 'HTTP(S)' : 'HTTPS'} URI без query и fragment',
    );
  }
  return uri;
}

Uri _requireRedirectUri(
  String value,
  String field, {
  required String expectedScheme,
}) {
  final Uri uri;
  try {
    uri = Uri.parse(_requireText(value, field));
  } on FormatException {
    throw AuthConfigurationException('$field содержит некорректный URI');
  }
  if (!uri.hasScheme ||
      uri.scheme == 'http' ||
      uri.scheme == 'https' ||
      uri.hasFragment) {
    throw AuthConfigurationException(
      '$field должен использовать зарегистрированную custom URI scheme',
    );
  }
  if (uri.scheme != expectedScheme) {
    throw AuthConfigurationException(
      '$field должен использовать native scheme $expectedScheme',
    );
  }
  return uri;
}

String _partitionId(String prefix, String issuer, String subject) {
  final Digest digest = sha256.convert(utf8.encode('$issuer|$subject'));
  return '$prefix-$digest';
}

String _requireClaimText(Map<String, Object?> claims, String name) {
  final Object? value = claims[name];
  if (value is! String || value.trim().isEmpty) {
    throw AuthTokenException('JWT claim $name обязателен');
  }
  // `iss` and `sub` are exact protocol identifiers. Trimming would collapse
  // distinct backend identities into the same local owner partition.
  return value;
}

String? _firstClaimText(Map<String, Object?> claims, List<String> names) {
  for (final String name in names) {
    final Object? value = claims[name];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

String _requireText(String value, String field) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    throw AuthConfigurationException('$field обязателен');
  }
  return normalized;
}

String _requireTokenText(String value, String field) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    throw AuthTokenException('$field обязателен');
  }
  return normalized;
}

String? _optionalText(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _readText(Map<String, Object?> json, String field) {
  final Object? value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field должен быть непустой строкой');
  }
  return value;
}

String? _readOptionalText(Map<String, Object?> json, String field) {
  final Object? value = json[field];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$field должен быть строкой или null');
  }
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _readInstant(Map<String, Object?> json, String field) {
  final String raw = _readText(json, field);
  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('$field содержит некорректный timestamp');
  }
  return parsed.toUtc();
}

Map<String, Object?> _stringMap(Map<Object?, Object?> source) {
  return source.map<String, Object?>((Object? key, Object? value) {
    if (key is! String) {
      throw const FormatException('Ключи JSON должны быть строками');
    }
    return MapEntry<String, Object?>(key, value);
  });
}

final class AuthConfigurationException implements Exception {
  const AuthConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class AuthTokenException implements Exception {
  const AuthTokenException(this.message);

  final String message;

  @override
  String toString() => message;
}
