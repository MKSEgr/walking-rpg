import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppLocale {
  russian('ru'),
  english('en');

  const AppLocale(this.languageCode);

  final String languageCode;

  Locale get locale => Locale.fromSubtags(languageCode: languageCode);

  static AppLocale? fromLanguageCode(String? languageCode) {
    final String normalized = languageCode?.trim().toLowerCase() ?? '';
    for (final AppLocale locale in values) {
      if (locale.languageCode == normalized) {
        return locale;
      }
    }
    return null;
  }
}

abstract interface class AppLocaleStore {
  Future<String?> read();

  Future<void> write(String languageCode);
}

final class SecureAppLocaleStore implements AppLocaleStore {
  SecureAppLocaleStore({
    FlutterSecureStorage? storage,
    this.storageKey = 'step_beyond_locale_v1',
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<void> write(String languageCode) {
    return _storage.write(key: storageKey, value: languageCode);
  }
}

/// Owns the explicit, device-scoped presentation locale.
///
/// This preference intentionally sits outside auth/session and owner-local
/// state. It is available before sign-in, survives sign-out and owner changes,
/// and is never sent to the backend or inferred from identity, health or
/// location data.
final class AppLocaleController extends ChangeNotifier {
  AppLocaleController({AppLocaleStore? store})
    : _store = store ?? SecureAppLocaleStore();

  final AppLocaleStore _store;

  AppLocale _selected = AppLocale.russian;
  bool _initialized = false;
  bool _requiresExplicitChoice = true;
  Future<void>? _initialization;
  Future<void> _operationTail = Future<void>.value();

  AppLocale get selected => _selected;

  Locale get locale => _selected.locale;

  bool get initialized => _initialized;

  bool get requiresExplicitChoice => _requiresExplicitChoice;

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    AppLocale? restored;
    try {
      restored = AppLocale.fromLanguageCode(await _store.read());
    } on Object {
      // A storage failure follows the same safe migration path as a missing or
      // invalid legacy value: Russian is first, but the user must confirm it.
    }
    _selected = restored ?? AppLocale.russian;
    _requiresExplicitChoice = restored == null;
    _initialized = true;
    notifyListeners();
  }

  Future<void> select(AppLocale locale) {
    final Completer<void> completer = Completer<void>();
    _operationTail = _operationTail.then((_) async {
      try {
        await _store.write(locale.languageCode);
        _selected = locale;
        _requiresExplicitChoice = false;
        notifyListeners();
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
