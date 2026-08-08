import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_controller.dart';

void main() {
  test(
    'missing preference uses Russian and requires an explicit choice',
    () async {
      final _MemoryLocaleStore store = _MemoryLocaleStore();
      final AppLocaleController controller = AppLocaleController(store: store);
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.initialized, isTrue);
      expect(controller.selected, AppLocale.russian);
      expect(controller.requiresExplicitChoice, isTrue);
      expect(store.writes, isEmpty);
    },
  );

  test(
    'invalid or unreadable legacy value follows the same safe fallback',
    () async {
      for (final _MemoryLocaleStore store in <_MemoryLocaleStore>[
        _MemoryLocaleStore(value: 'de'),
        _MemoryLocaleStore(readError: StateError('storage unavailable')),
      ]) {
        final AppLocaleController controller = AppLocaleController(
          store: store,
        );
        await controller.initialize();

        expect(controller.selected, AppLocale.russian);
        expect(controller.requiresExplicitChoice, isTrue);
        controller.dispose();
      }
    },
  );

  test('explicit choice survives restart and remains reversible', () async {
    final _MemoryLocaleStore store = _MemoryLocaleStore();
    final AppLocaleController first = AppLocaleController(store: store);
    await first.initialize();
    await first.select(AppLocale.english);

    expect(store.value, 'en');
    expect(first.selected, AppLocale.english);
    expect(first.requiresExplicitChoice, isFalse);

    final AppLocaleController afterRestart = AppLocaleController(store: store);
    await afterRestart.initialize();
    expect(afterRestart.selected, AppLocale.english);
    expect(afterRestart.requiresExplicitChoice, isFalse);

    await afterRestart.select(AppLocale.russian);
    expect(store.value, 'ru');
    expect(afterRestart.selected, AppLocale.russian);

    first.dispose();
    afterRestart.dispose();
  });

  test('failed persistence does not publish an uncommitted locale', () async {
    final _MemoryLocaleStore store = _MemoryLocaleStore(
      value: 'ru',
      writeError: StateError('write rejected'),
    );
    final AppLocaleController controller = AppLocaleController(store: store);
    addTearDown(controller.dispose);
    await controller.initialize();

    await expectLater(
      controller.select(AppLocale.english),
      throwsA(isA<StateError>()),
    );

    expect(controller.selected, AppLocale.russian);
    expect(controller.requiresExplicitChoice, isFalse);
    expect(store.value, 'ru');
  });
}

final class _MemoryLocaleStore implements AppLocaleStore {
  _MemoryLocaleStore({this.value, this.readError, this.writeError});

  String? value;
  final Object? readError;
  final Object? writeError;
  final List<String> writes = <String>[];

  @override
  Future<String?> read() async {
    final Object? error = readError;
    if (error != null) {
      throw error;
    }
    return value;
  }

  @override
  Future<void> write(String languageCode) async {
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
    writes.add(languageCode);
    value = languageCode;
  }
}
