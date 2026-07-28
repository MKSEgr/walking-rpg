import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:walking_rpg_mobile/core/auth/auth_access_token_provider.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_store.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';
import 'package:walking_rpg_mobile/core/auth/owner_local_state_cleaner.dart';

enum AuthLifecycleState {
  initializing,
  unauthenticated,
  authenticating,
  authenticated,
  stoppingRuntime,
  reauthenticationRequired,
}

typedef AuthClock = DateTime Function();
typedef RuntimeStopper = Future<void> Function();

final class AuthSessionController extends ChangeNotifier
    implements AuthAccessTokenProvider {
  AuthSessionController({
    required this.configuration,
    required AuthSessionStore sessionStore,
    required OidcAuthorizationClient oidcClient,
    required LocalStateCleaner localStateCleaner,
    AuthClock? clock,
  }) : _sessionStore = sessionStore,
       _oidcClient = oidcClient,
       _localStateCleaner = localStateCleaner,
       _clock = clock ?? DateTime.now;

  final MobileAuthConfiguration configuration;
  final AuthSessionStore _sessionStore;
  final OidcAuthorizationClient _oidcClient;
  final LocalStateCleaner _localStateCleaner;
  final AuthClock _clock;

  AuthLifecycleState _state = AuthLifecycleState.initializing;
  AuthSession? _session;
  AuthIdentity? _identity;
  String? _message;
  String? _previousOwnerId;
  RuntimeStopper? _runtimeStopper;
  Future<AuthSession>? _refreshFuture;
  int? _refreshGeneration;
  String? _sessionGeneration;
  int _generation = 0;
  bool _initialized = false;
  bool _cleanupRequired = false;

  AuthLifecycleState get state => _state;

  AuthIdentity? get identity => _identity;

  String? get message => _message;

  bool get isDevelopment => configuration.mode == MobileAuthMode.development;

  bool get isBusy =>
      _state == AuthLifecycleState.authenticating ||
      _state == AuthLifecycleState.stoppingRuntime;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (configuration.mode == MobileAuthMode.development) {
      _identity = AuthIdentity.development(configuration.developmentUserId!);
      _previousOwnerId = _identity!.ownerId;
      _state = AuthLifecycleState.authenticated;
      notifyListeners();
      return;
    }

    try {
      final AuthSessionStoreState stored = await _sessionStore.read();
      _previousOwnerId = stored.lastOwnerId;
      _cleanupRequired = stored.cleanupRequired;
      final AuthSession? restored = stored.session;
      if (restored == null) {
        _state = _previousOwnerId == null
            ? AuthLifecycleState.unauthenticated
            : AuthLifecycleState.reauthenticationRequired;
        if (_cleanupRequired) {
          _message =
              'Предыдущий выход завершился не полностью. '
              'Локальные данные будут очищены при следующем входе.';
        }
        notifyListeners();
        return;
      }

      final OidcConfiguration oidc = configuration.oidc!;
      final AuthSession validated;
      try {
        validated = restored.validated(configuration: oidc);
      } on Object catch (error) {
        _previousOwnerId = restored.identity.ownerId;
        await _sessionStore.clearSession(ownerId: _previousOwnerId!);
        _message = 'Сохранённая сессия недействительна: $error';
        _state = AuthLifecycleState.reauthenticationRequired;
        notifyListeners();
        return;
      }

      final String? previousOwner = _previousOwnerId;
      if (previousOwner != null &&
          (_cleanupRequired || previousOwner != validated.identity.ownerId)) {
        await _localStateCleaner.clear(previousOwner);
      }
      _session = validated;
      _sessionGeneration = stored.sessionGeneration!;
      _identity = validated.identity;
      _previousOwnerId = validated.identity.ownerId;
      _cleanupRequired = false;
      _state = AuthLifecycleState.authenticated;
      _message = null;
      notifyListeners();
    } on AuthSessionStoreException catch (error) {
      _previousOwnerId = error.lastOwnerId ?? _previousOwnerId;
      _message = error.message;
      _state = _previousOwnerId == null
          ? AuthLifecycleState.unauthenticated
          : AuthLifecycleState.reauthenticationRequired;
      notifyListeners();
    } on Object catch (error) {
      _message = 'Не удалось восстановить сессию: $error';
      _state = _previousOwnerId == null
          ? AuthLifecycleState.unauthenticated
          : AuthLifecycleState.reauthenticationRequired;
      notifyListeners();
    }
  }

  Future<void> signIn() async {
    if (configuration.mode != MobileAuthMode.oidc ||
        isBusy ||
        (_state != AuthLifecycleState.unauthenticated &&
            _state != AuthLifecycleState.reauthenticationRequired)) {
      return;
    }
    final AuthLifecycleState fallbackState = _previousOwnerId == null
        ? AuthLifecycleState.unauthenticated
        : AuthLifecycleState.reauthenticationRequired;
    _state = AuthLifecycleState.authenticating;
    _message = null;
    notifyListeners();

    try {
      final OidcConfiguration oidc = configuration.oidc!;
      final OidcTokenResponseData response = await _oidcClient.authorize(oidc);
      final AuthSession newSession = AuthSession.fromResponse(
        configuration: oidc,
        response: response,
      );
      final String? previousOwner = _previousOwnerId;
      if (previousOwner != null &&
          (_cleanupRequired || previousOwner != newSession.identity.ownerId)) {
        await _localStateCleaner.clear(previousOwner);
      }
      final String sessionGeneration = await _sessionStore.write(newSession);
      _generation += 1;
      _session = newSession;
      _sessionGeneration = sessionGeneration;
      _identity = newSession.identity;
      _previousOwnerId = newSession.identity.ownerId;
      _cleanupRequired = false;
      _state = AuthLifecycleState.authenticated;
      _message = null;
      notifyListeners();
    } on AuthUserCancelledException {
      _state = fallbackState;
      _message = null;
      notifyListeners();
    } on Object catch (error) {
      _state = fallbackState;
      _message = 'Не удалось войти: $error';
      notifyListeners();
    }
  }

  @override
  Future<String> accessToken() async {
    final AuthSession session = _requireOidcSession();
    if (!session.tokens.expiresWithin(
      _clock().toUtc(),
      configuration.refreshSkew,
    )) {
      return session.tokens.accessToken;
    }
    return (await _refresh(session)).tokens.accessToken;
  }

  @override
  Future<String> refreshAfterUnauthorized(String rejectedAccessToken) async {
    final AuthSession session = _requireOidcSession();
    if (session.tokens.accessToken != rejectedAccessToken) {
      return session.tokens.accessToken;
    }
    return (await _refresh(session)).tokens.accessToken;
  }

  @override
  void rejectSession(String reason) {
    if (configuration.mode != MobileAuthMode.oidc ||
        _state == AuthLifecycleState.stoppingRuntime ||
        _state == AuthLifecycleState.reauthenticationRequired ||
        _state == AuthLifecycleState.unauthenticated) {
      return;
    }
    _generation += 1;
    _sessionGeneration = null;
    _previousOwnerId = _identity?.ownerId ?? _previousOwnerId;
    _message = reason;
    _state = AuthLifecycleState.stoppingRuntime;
    final RuntimeStopper? stopper = _runtimeStopper;
    _runtimeStopper = null;
    notifyListeners();
    unawaited(_finishReauthentication(stopper));
  }

  Future<void> logout() async {
    if (configuration.mode == MobileAuthMode.development || isBusy) {
      return;
    }
    final AuthSession? session = _session;
    final String? ownerId = _identity?.ownerId ?? _previousOwnerId;
    final RuntimeStopper? stopper = _runtimeStopper;
    _runtimeStopper = null;
    _generation += 1;
    _sessionGeneration = null;
    _state = AuthLifecycleState.stoppingRuntime;
    _message = null;
    notifyListeners();

    Object? cleanupError;

    // Persist both invalidation and the pending cleanup obligation before
    // waiting for runtime/network work. A process death after the logout
    // gesture must neither restore tokens nor forget the explicit data purge.
    try {
      if (ownerId == null) {
        await _sessionStore.clear();
      } else {
        await _sessionStore.clearSession(
          ownerId: ownerId,
          cleanupRequired: true,
        );
      }
    } on Object catch (error) {
      cleanupError = error;
      try {
        await _sessionStore.clear();
      } on Object {
        // Continue with local cleanup; the original persistence error is kept.
      }
      if (ownerId != null) {
        try {
          await _sessionStore.clearSession(
            ownerId: ownerId,
            cleanupRequired: true,
          );
        } on Object {
          // No stronger durable fallback remains.
        }
      }
    }

    try {
      await stopper?.call();
    } on Object catch (error) {
      cleanupError ??= error;
    }
    if (ownerId != null) {
      try {
        await _localStateCleaner.clear(ownerId);
      } on Object catch (error) {
        cleanupError ??= error;
      }
    }

    try {
      if (ownerId == null || cleanupError == null) {
        await _sessionStore.clear();
      } else {
        await _sessionStore.clearSession(
          ownerId: ownerId,
          cleanupRequired: true,
        );
      }
    } on Object catch (error) {
      cleanupError ??= error;
      if (ownerId != null) {
        try {
          await _sessionStore.clearSession(
            ownerId: ownerId,
            cleanupRequired: true,
          );
        } on Object {
          // The primary storage error is already retained.
        }
      }
    }

    final OidcConfiguration? oidc = configuration.oidc;
    final String? idToken = session?.tokens.idToken;
    if (oidc != null && idToken != null) {
      try {
        await _oidcClient.endSession(oidc, idToken: idToken);
      } on Object {
        // Local logout remains authoritative when provider logout is unavailable.
      }
    }

    _session = null;
    _sessionGeneration = null;
    _identity = null;
    _cleanupRequired = cleanupError != null && ownerId != null;
    _previousOwnerId = cleanupError == null ? null : ownerId;
    _state = AuthLifecycleState.unauthenticated;
    _message = cleanupError == null
        ? null
        : 'Сессия завершена, но часть локальных данных не удалось очистить';
    notifyListeners();
  }

  void registerRuntimeStopper(RuntimeStopper stopper) {
    _runtimeStopper = stopper;
  }

  void unregisterRuntimeStopper(RuntimeStopper stopper) {
    if (identical(_runtimeStopper, stopper)) {
      _runtimeStopper = null;
    }
  }

  Future<AuthSession> _refresh(AuthSession session) {
    final int generation = _generation;
    final String? sessionGeneration = _sessionGeneration;
    if (sessionGeneration == null) {
      throw const AuthReauthenticationRequiredException();
    }
    final Future<AuthSession>? active = _refreshFuture;
    if (active != null && _refreshGeneration == generation) {
      return active;
    }
    late final Future<AuthSession> started;
    started =
        _performRefresh(
          session,
          generation: generation,
          sessionGeneration: sessionGeneration,
        ).whenComplete(() {
          if (identical(_refreshFuture, started)) {
            _refreshFuture = null;
            _refreshGeneration = null;
          }
        });
    _refreshFuture = started;
    _refreshGeneration = generation;
    return started;
  }

  Future<AuthSession> _performRefresh(
    AuthSession session, {
    required int generation,
    required String sessionGeneration,
  }) async {
    final String? refreshToken = session.tokens.refreshToken;
    if (refreshToken == null) {
      _rejectIfCurrent(
        session,
        generation: generation,
        sessionGeneration: sessionGeneration,
        reason: 'Сессия истекла. Требуется повторный вход.',
      );
      throw const AuthReauthenticationRequiredException();
    }
    try {
      final OidcConfiguration oidc = configuration.oidc!;
      final OidcTokenResponseData response = await _oidcClient.refresh(
        oidc,
        refreshToken: refreshToken,
      );
      final AuthSession refreshed = session.refreshed(
        configuration: oidc,
        response: response,
      );
      if (!_isCurrentSession(
        session,
        generation: generation,
        sessionGeneration: sessionGeneration,
      )) {
        throw const AuthReauthenticationRequiredException();
      }
      try {
        await _sessionStore.writeRefreshedSession(
          refreshed,
          sessionGeneration: sessionGeneration,
        );
      } on AuthSessionStoreException catch (error) {
        if (!_isCurrentSession(
          session,
          generation: generation,
          sessionGeneration: sessionGeneration,
        )) {
          throw const AuthReauthenticationRequiredException();
        }
        throw AuthRefreshUnavailableException(error);
      }
      if (!_isCurrentSession(
        session,
        generation: generation,
        sessionGeneration: sessionGeneration,
      )) {
        throw const AuthReauthenticationRequiredException();
      }
      _session = refreshed;
      _identity = refreshed.identity;
      notifyListeners();
      return refreshed;
    } on AuthInvalidGrantException {
      _rejectIfCurrent(
        session,
        generation: generation,
        sessionGeneration: sessionGeneration,
        reason: 'Сессия отозвана. Войдите снова.',
      );
      throw const AuthReauthenticationRequiredException();
    } on AuthTokenException {
      _rejectIfCurrent(
        session,
        generation: generation,
        sessionGeneration: sessionGeneration,
        reason: 'Identity provider вернул некорректную сессию.',
      );
      throw const AuthReauthenticationRequiredException();
    } on AuthProviderException catch (error) {
      if (!error.retryable) {
        _rejectIfCurrent(
          session,
          generation: generation,
          sessionGeneration: sessionGeneration,
          reason: 'Настройки OIDC больше не принимаются сервером.',
        );
        throw const AuthReauthenticationRequiredException();
      }
      if (!_isCurrentSession(
        session,
        generation: generation,
        sessionGeneration: sessionGeneration,
      )) {
        throw const AuthReauthenticationRequiredException();
      }
      throw AuthRefreshUnavailableException(error);
    }
  }

  bool _isCurrentSession(
    AuthSession session, {
    required int generation,
    required String sessionGeneration,
  }) {
    return generation == _generation &&
        _state == AuthLifecycleState.authenticated &&
        _sessionGeneration == sessionGeneration &&
        identical(_session, session);
  }

  void _rejectIfCurrent(
    AuthSession session, {
    required int generation,
    required String sessionGeneration,
    required String reason,
  }) {
    if (_isCurrentSession(
      session,
      generation: generation,
      sessionGeneration: sessionGeneration,
    )) {
      rejectSession(reason);
    }
  }

  Future<void> _finishReauthentication(RuntimeStopper? stopper) async {
    final String? ownerId = _identity?.ownerId ?? _previousOwnerId;
    Object? stopError;

    // Make reauthentication durable before waiting for the admitted command
    // that observed the 401 to unwind. Refresh persistence never reactivates
    // this marker.
    try {
      if (ownerId == null) {
        await _sessionStore.clear();
      } else {
        await _sessionStore.clearSession(ownerId: ownerId);
      }
    } on Object catch (error) {
      stopError = error;
      try {
        await _sessionStore.clear();
      } on Object {
        // Preserve the original invalidation error.
      }
      if (ownerId != null) {
        try {
          await _sessionStore.clearSession(ownerId: ownerId);
        } on Object {
          // No stronger durable fallback remains.
        }
      }
    }

    try {
      await stopper?.call();
    } on Object catch (error) {
      stopError ??= error;
    }
    _session = null;
    _sessionGeneration = null;
    _identity = null;
    _cleanupRequired = false;
    _previousOwnerId = ownerId;
    _state = AuthLifecycleState.reauthenticationRequired;
    if (stopError != null) {
      _message =
          '${_message ?? 'Требуется повторный вход.'} '
          'Не удалось корректно остановить предыдущую сессию.';
    }
    notifyListeners();
  }

  AuthSession _requireOidcSession() {
    final AuthSession? session = _session;
    if (configuration.mode != MobileAuthMode.oidc ||
        _state != AuthLifecycleState.authenticated ||
        session == null) {
      throw const AuthReauthenticationRequiredException();
    }
    return session;
  }
}

final class AuthRefreshUnavailableException implements Exception {
  const AuthRefreshUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'Не удалось временно обновить сессию';
}

final class AuthReauthenticationRequiredException implements Exception {
  const AuthReauthenticationRequiredException();

  @override
  String toString() => 'Требуется повторный вход';
}
