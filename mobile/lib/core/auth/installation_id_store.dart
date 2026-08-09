import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class InstallationIdProvider {
  Future<String> installationId();
}

abstract interface class InstallationIdStorage {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});
}

final class FlutterInstallationIdStorage implements InstallationIdStorage {
  FlutterInstallationIdStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

typedef InstallationIdGenerator = String Function();

/// Owns a random, device-scoped identifier for this app installation.
///
/// The value intentionally lives outside the owner-scoped session, cache and
/// command outbox. Logout and account deletion do not rotate it. A missing or
/// malformed secure-storage value does. Some platforms retain Keychain data
/// across reinstall, so backend correctness never depends on reinstall causing
/// rotation. The backend never receives this unsigned value directly: Auth0
/// copies it into a signed access-token claim.
final class SecureInstallationIdStore implements InstallationIdProvider {
  SecureInstallationIdStore({
    InstallationIdStorage? storage,
    InstallationIdGenerator? generator,
    this.storageKey = 'step_beyond_installation_id_v1',
  }) : _storage = storage ?? FlutterInstallationIdStorage(),
       _generator = generator ?? _generateInstallationId;

  static final RegExp _validValue = RegExp(r'^[0-9a-f]{32}$');

  final InstallationIdStorage _storage;
  final InstallationIdGenerator _generator;
  final String storageKey;

  Future<String>? _initialization;

  @override
  Future<String> installationId() {
    return _initialization ??= _readOrCreate();
  }

  Future<String> _readOrCreate() async {
    final String? stored = await _storage.read(key: storageKey);
    if (stored != null && _validValue.hasMatch(stored)) {
      return stored;
    }

    final String generated = _generator();
    if (!_validValue.hasMatch(generated)) {
      throw StateError('Генератор вернул некорректный installation ID');
    }
    await _storage.write(key: storageKey, value: generated);
    return generated;
  }
}

String _generateInstallationId() {
  final Random random = Random.secure();
  return List<int>.generate(
    16,
    (_) => random.nextInt(256),
    growable: false,
  ).map((int value) => value.toRadixString(16).padLeft(2, '0')).join();
}
