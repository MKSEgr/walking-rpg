import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';

abstract interface class AuthSessionStore {
  Future<AuthSessionStoreState> read();

  /// Publishes a new interactive session and returns its unique generation.
  Future<String> write(AuthSession session);

  /// Persists rotated tokens only for the expected active generation.
  Future<void> writeRefreshedSession(
    AuthSession session, {
    required String sessionGeneration,
  });

  Future<void> clearSession({
    required String ownerId,
    bool cleanupRequired = false,
  });

  Future<void> clear();
}

final class AuthSessionStoreState {
  const AuthSessionStoreState({
    this.session,
    this.sessionGeneration,
    this.lastOwnerId,
    this.cleanupRequired = false,
  }) : assert(
         session == null || sessionGeneration != null,
         'An active session requires a generation',
       );

  final AuthSession? session;
  final String? sessionGeneration;
  final String? lastOwnerId;
  final bool cleanupRequired;
}

abstract interface class AuthSecureStorage {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String? value});

  Future<void> delete({required String key});
}

final class FlutterAuthSecureStorage implements AuthSecureStorage {
  FlutterAuthSecureStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String? value}) {
    return _storage.write(key: key, value: value);
  }
}

final class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({
    AuthSecureStorage? storage,
    this.storageKey = 'walking_rpg_oidc_session_v1',
    this.ownerStateKey = 'walking_rpg_oidc_owner_state_v1',
  }) : _storage = storage ?? FlutterAuthSecureStorage();

  final AuthSecureStorage _storage;
  final String storageKey;
  final String ownerStateKey;

  Future<void> _operationTail = Future<void>.value();

  @override
  Future<AuthSessionStoreState> read() {
    return _serialize<AuthSessionStoreState>(_readUnlocked);
  }

  Future<AuthSessionStoreState> _readUnlocked() async {
    _OwnerState? ownerState;
    try {
      ownerState = await _readOwnerState();
    } on Object catch (error, stackTrace) {
      await _deleteBestEffort(ownerStateKey);
      final String? recoveredOwnerId =
          await _invalidateSessionAfterOwnerStateCorruptionUnlocked();
      Error.throwWithStackTrace(
        AuthSessionStoreException(
          'Состояние владельца сессии повреждено. Сессия была отозвана.',
          cause: error,
          lastOwnerId: recoveredOwnerId,
          cleanupRequired: recoveredOwnerId != null,
        ),
        stackTrace,
      );
    }

    if (ownerState?.sessionInvalidated ?? false) {
      await _deleteBestEffort(storageKey);
      return AuthSessionStoreState(
        lastOwnerId: ownerState!.ownerId,
        cleanupRequired: ownerState.cleanupRequired,
      );
    }

    final String? encoded = await _storage.read(key: storageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      if (ownerState != null) {
        await _writeOwnerStateBestEffort(
          _OwnerState.invalidated(
            ownerId: ownerState.ownerId,
            cleanupRequired: ownerState.cleanupRequired,
          ),
        );
      }
      return AuthSessionStoreState(
        lastOwnerId: ownerState?.ownerId,
        cleanupRequired: ownerState?.cleanupRequired ?? false,
      );
    }

    try {
      final _StoredSession stored = _decodeSession(encoded);
      if (ownerState == null ||
          ownerState.sessionGeneration == null ||
          ownerState.ownerId != stored.session.identity.ownerId ||
          ownerState.sessionGeneration != stored.sessionGeneration) {
        final String ownerId =
            ownerState?.ownerId ?? stored.session.identity.ownerId;
        await _writeOwnerStateBestEffort(
          _OwnerState.invalidated(ownerId: ownerId, cleanupRequired: true),
        );
        await _deleteBestEffort(storageKey);
        throw AuthSessionStoreException(
          'Маркер владельца не соответствует сохранённой сессии. '
          'Сессия была отозвана.',
          lastOwnerId: ownerId,
          cleanupRequired: true,
        );
      }
      return AuthSessionStoreState(
        session: stored.session,
        sessionGeneration: stored.sessionGeneration,
        lastOwnerId: ownerState.ownerId,
        cleanupRequired: ownerState.cleanupRequired,
      );
    } on AuthSessionStoreException {
      rethrow;
    } on Object catch (error, stackTrace) {
      final String? ownerId = ownerState?.ownerId;
      if (ownerId != null) {
        await _writeOwnerStateBestEffort(
          _OwnerState.invalidated(ownerId: ownerId, cleanupRequired: true),
        );
      }
      await _deleteBestEffort(storageKey);
      Error.throwWithStackTrace(
        AuthSessionStoreException(
          'Сохранённая сессия повреждена и была удалена',
          cause: error,
          lastOwnerId: ownerId,
          cleanupRequired: ownerId != null,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<String> write(AuthSession session) {
    return _serialize<String>(() async {
      final String generation = _newSessionGeneration();
      final _OwnerState active = _OwnerState.active(
        ownerId: session.identity.ownerId,
        sessionGeneration: generation,
      );

      // The marker is published first. If the process stops before the token
      // envelope is written, restore fails closed instead of accepting an
      // unpartitioned token set.
      await _writeOwnerState(active);
      try {
        await _writeSession(
          _StoredSession(session: session, sessionGeneration: generation),
        );
      } on Object catch (error, stackTrace) {
        await _writeOwnerStateBestEffort(
          _OwnerState.invalidated(
            ownerId: session.identity.ownerId,
            cleanupRequired: false,
          ),
        );
        await _deleteBestEffort(storageKey);
        Error.throwWithStackTrace(error, stackTrace);
      }
      return generation;
    });
  }

  @override
  Future<void> writeRefreshedSession(
    AuthSession session, {
    required String sessionGeneration,
  }) {
    return _serialize<void>(() async {
      final String expectedGeneration = _requireSessionGeneration(
        sessionGeneration,
      );
      final _OwnerState? ownerState = await _readOwnerState();
      if (ownerState == null ||
          ownerState.sessionInvalidated ||
          ownerState.ownerId != session.identity.ownerId ||
          ownerState.sessionGeneration != expectedGeneration) {
        throw AuthSessionStoreException(
          'Обновлённая сессия не относится к активному поколению',
          lastOwnerId: ownerState?.ownerId,
        );
      }

      final String? encoded = await _storage.read(key: storageKey);
      if (encoded == null || encoded.trim().isEmpty) {
        throw AuthSessionStoreException(
          'Активная сессия отсутствует во время сохранения refresh',
          lastOwnerId: ownerState.ownerId,
        );
      }
      final _StoredSession current;
      try {
        current = _decodeSession(encoded);
      } on Object catch (error) {
        throw AuthSessionStoreException(
          'Активная сессия повреждена во время сохранения refresh',
          cause: error,
          lastOwnerId: ownerState.ownerId,
        );
      }
      if (current.sessionGeneration != expectedGeneration ||
          current.session.identity.ownerId != session.identity.ownerId) {
        throw AuthSessionStoreException(
          'Refresh не может заменить другое поколение сессии',
          lastOwnerId: ownerState.ownerId,
        );
      }

      // All session mutations use the same queue. Together with the generation
      // check this prevents stale refreshes from overwriting a logout or a
      // later sign-in, including the same-account ABA case.
      await _writeSession(
        _StoredSession(session: session, sessionGeneration: expectedGeneration),
      );
    });
  }

  @override
  Future<void> clearSession({
    required String ownerId,
    bool cleanupRequired = false,
  }) {
    return _serialize<void>(
      () => _clearSessionUnlocked(
        ownerId: ownerId,
        cleanupRequired: cleanupRequired,
      ),
    );
  }

  Future<void> _clearSessionUnlocked({
    required String ownerId,
    required bool cleanupRequired,
  }) async {
    final String normalizedOwnerId = _requireOwnerId(ownerId);
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _writeOwnerState(
        _OwnerState.invalidated(
          ownerId: normalizedOwnerId,
          cleanupRequired: cleanupRequired,
        ),
      );
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }

    // Token deletion is fail-closed and independent. A rejected marker write
    // must not leave a restorable token envelope behind.
    try {
      await _storage.delete(key: storageKey);
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }

  @override
  Future<void> clear() {
    return _serialize<void>(_clearUnlocked);
  }

  Future<void> _clearUnlocked() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _storage.delete(key: storageKey);
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      await _storage.delete(key: ownerStateKey);
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace);
    }
  }

  Future<String?> _invalidateSessionAfterOwnerStateCorruptionUnlocked() async {
    String? recoveredOwnerId;
    try {
      final String? encoded = await _storage.read(key: storageKey);
      if (encoded != null && encoded.trim().isNotEmpty) {
        try {
          recoveredOwnerId = _decodeSession(encoded).session.identity.ownerId;
        } on Object {
          // A malformed token envelope cannot provide a trustworthy owner.
        }
      }
      if (recoveredOwnerId != null) {
        try {
          await _clearSessionUnlocked(
            ownerId: recoveredOwnerId,
            cleanupRequired: true,
          );
          return recoveredOwnerId;
        } on Object {
          // Fall through to best-effort token deletion. The parsing error
          // remains the primary diagnostic returned to the controller.
        }
      }
    } on Object {
      // Secure-storage read errors are handled by deleting the active token
      // when possible and failing closed.
    }
    await _deleteBestEffort(storageKey);
    return recoveredOwnerId;
  }

  Future<_OwnerState?> _readOwnerState() async {
    final String? encoded = await _storage.read(key: ownerStateKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }
    final Object? decoded = jsonDecode(encoded);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Owner state должен быть JSON-объектом');
    }
    final Map<String, Object?> json = _stringMap(decoded);
    if (json['version'] != 2) {
      throw FormatException(
        'Неподдерживаемая версия owner state: ${json['version']}',
      );
    }
    final Object? rawCleanupRequired = json['cleanupRequired'];
    final Object? rawSessionInvalidated = json['sessionInvalidated'];
    if (rawCleanupRequired is! bool || rawSessionInvalidated is! bool) {
      throw const FormatException('Некорректные флаги owner state');
    }
    final String? sessionGeneration = _readOptionalText(
      json,
      'sessionGeneration',
    );
    if (rawSessionInvalidated == (sessionGeneration != null)) {
      throw const FormatException(
        'Некорректная связь invalidated и session generation',
      );
    }
    return _OwnerState(
      ownerId: _requireOwnerId(_readText(json, 'ownerId')),
      cleanupRequired: rawCleanupRequired,
      sessionInvalidated: rawSessionInvalidated,
      sessionGeneration: sessionGeneration,
    );
  }

  Future<void> _writeOwnerState(_OwnerState state) {
    return _storage.write(
      key: ownerStateKey,
      value: jsonEncode(<String, Object?>{
        'version': 2,
        'ownerId': state.ownerId,
        'sessionInvalidated': state.sessionInvalidated,
        'cleanupRequired': state.cleanupRequired,
        'sessionGeneration': state.sessionGeneration,
      }),
    );
  }

  Future<void> _writeOwnerStateBestEffort(_OwnerState state) async {
    try {
      await _writeOwnerState(state);
    } on Object {
      // The operation already fails closed by deleting the token envelope.
    }
  }

  Future<void> _writeSession(_StoredSession stored) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(<String, Object?>{
        'version': 2,
        'sessionGeneration': stored.sessionGeneration,
        'session': stored.session.toJson(),
      }),
    );
  }

  _StoredSession _decodeSession(String encoded) {
    final Object? decoded = jsonDecode(encoded);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Session envelope должен быть объектом');
    }
    final Map<String, Object?> json = _stringMap(decoded);
    if (json['version'] != 2) {
      throw FormatException(
        'Неподдерживаемая версия session store: ${json['version']}',
      );
    }
    final Object? rawSession = json['session'];
    if (rawSession is! Map<Object?, Object?>) {
      throw const FormatException('Поле session должно быть объектом');
    }
    return _StoredSession(
      session: AuthSession.fromJson(_stringMap(rawSession)),
      sessionGeneration: _requireSessionGeneration(
        _readText(json, 'sessionGeneration'),
      ),
    );
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final Completer<T> result = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> _deleteBestEffort(String key) async {
    try {
      await _storage.delete(key: key);
    } on Object {
      // The original storage or parsing error remains the primary diagnostic.
    }
  }

  static String _newSessionGeneration() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(
      24,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Map<String, Object?> _stringMap(Map<Object?, Object?> source) {
    return source.map<String, Object?>((Object? key, Object? value) {
      if (key is! String) {
        throw const FormatException('Ключи session JSON должны быть строками');
      }
      return MapEntry<String, Object?>(key, value);
    });
  }

  static String _readText(Map<String, Object?> json, String field) {
    final Object? value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field должен быть непустой строкой');
    }
    return value.trim();
  }

  static String? _readOptionalText(Map<String, Object?> json, String field) {
    final Object? value = json[field];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field должен быть строкой или null');
    }
    return value.trim();
  }

  static String _requireOwnerId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'ownerId', 'Значение обязательно');
    }
    return normalized;
  }

  static String _requireSessionGeneration(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        'sessionGeneration',
        'Значение обязательно',
      );
    }
    return normalized;
  }
}

final class _StoredSession {
  const _StoredSession({
    required this.session,
    required this.sessionGeneration,
  });

  final AuthSession session;
  final String sessionGeneration;
}

final class _OwnerState {
  const _OwnerState({
    required this.ownerId,
    required this.sessionInvalidated,
    required this.cleanupRequired,
    required this.sessionGeneration,
  });

  factory _OwnerState.active({
    required String ownerId,
    required String sessionGeneration,
  }) {
    return _OwnerState(
      ownerId: ownerId,
      sessionInvalidated: false,
      cleanupRequired: false,
      sessionGeneration: sessionGeneration,
    );
  }

  factory _OwnerState.invalidated({
    required String ownerId,
    required bool cleanupRequired,
  }) {
    return _OwnerState(
      ownerId: ownerId,
      sessionInvalidated: true,
      cleanupRequired: cleanupRequired,
      sessionGeneration: null,
    );
  }

  final String ownerId;
  final bool sessionInvalidated;
  final bool cleanupRequired;
  final String? sessionGeneration;
}

final class AuthSessionStoreException implements Exception {
  const AuthSessionStoreException(
    this.message, {
    this.cause,
    this.lastOwnerId,
    this.cleanupRequired = false,
  });

  final String message;
  final Object? cause;
  final String? lastOwnerId;
  final bool cleanupRequired;

  @override
  String toString() => message;
}
