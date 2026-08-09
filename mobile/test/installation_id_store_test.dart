import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/auth/installation_id_store.dart';

void main() {
  test('creates one installation ID and coalesces concurrent reads', () async {
    final _MemoryInstallationIdStorage storage = _MemoryInstallationIdStorage();
    final SecureInstallationIdStore store = SecureInstallationIdStore(
      storage: storage,
      generator: () => '0123456789abcdef0123456789abcdef',
    );

    final List<String> values = await Future.wait(<Future<String>>[
      store.installationId(),
      store.installationId(),
      store.installationId(),
    ]);

    expect(values.toSet(), <String>{'0123456789abcdef0123456789abcdef'});
    expect(storage.writeCount, 1);
  });

  test('restores the same device-scoped value across app restart', () async {
    final _MemoryInstallationIdStorage storage = _MemoryInstallationIdStorage();
    final SecureInstallationIdStore first = SecureInstallationIdStore(
      storage: storage,
      generator: () => '0123456789abcdef0123456789abcdef',
    );
    expect(await first.installationId(), '0123456789abcdef0123456789abcdef');

    final SecureInstallationIdStore afterRestart = SecureInstallationIdStore(
      storage: storage,
      generator: () => 'fedcba9876543210fedcba9876543210',
    );

    expect(
      await afterRestart.installationId(),
      '0123456789abcdef0123456789abcdef',
    );
    expect(storage.writeCount, 1);
  });

  test('replaces a malformed stored value before returning it', () async {
    final _MemoryInstallationIdStorage storage = _MemoryInstallationIdStorage(
      value: 'legacy-device-id',
    );
    final SecureInstallationIdStore store = SecureInstallationIdStore(
      storage: storage,
      generator: () => 'fedcba9876543210fedcba9876543210',
    );

    expect(await store.installationId(), 'fedcba9876543210fedcba9876543210');
    expect(storage.value, 'fedcba9876543210fedcba9876543210');
  });

  test('never publishes an ID that secure storage did not persist', () async {
    final _MemoryInstallationIdStorage storage = _MemoryInstallationIdStorage(
      writeError: StateError('unavailable'),
    );
    final SecureInstallationIdStore store = SecureInstallationIdStore(
      storage: storage,
      generator: () => '0123456789abcdef0123456789abcdef',
    );

    await expectLater(store.installationId(), throwsA(isA<StateError>()));
  });
}

final class _MemoryInstallationIdStorage implements InstallationIdStorage {
  _MemoryInstallationIdStorage({this.value, this.writeError});

  String? value;
  final Object? writeError;
  int writeCount = 0;

  @override
  Future<String?> read({required String key}) async => value;

  @override
  Future<void> write({required String key, required String value}) async {
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
    writeCount += 1;
    this.value = value;
  }
}
