import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Russian and English player-copy inventories stay complete', () {
    final Map<String, Object?> english = _readArb('lib/l10n/app_en.arb');
    final Map<String, Object?> russian = _readArb('lib/l10n/app_ru.arb');
    final Set<String> englishKeys = _messageKeys(english);
    final Set<String> russianKeys = _messageKeys(russian);

    expect(englishKeys, equals(russianKeys));
    expect(englishKeys.length, greaterThanOrEqualTo(270));

    for (final String key in englishKeys) {
      expect(
        (english[key]! as String).trim(),
        isNotEmpty,
        reason: 'English value for $key must not be empty',
      );
      expect(
        (russian[key]! as String).trim(),
        isNotEmpty,
        reason: 'Russian value for $key must not be empty',
      );

      final Object? metadata = english['@$key'];
      if (metadata is! Map<String, Object?>) {
        continue;
      }
      final Object? rawPlaceholders = metadata['placeholders'];
      if (rawPlaceholders is! Map<String, Object?>) {
        continue;
      }
      for (final String placeholder in rawPlaceholders.keys) {
        expect(
          _containsPlaceholder(english[key]! as String, placeholder),
          isTrue,
          reason: 'English $key must contain {$placeholder}',
        );
        expect(
          _containsPlaceholder(russian[key]! as String, placeholder),
          isTrue,
          reason: 'Russian $key must contain {$placeholder}',
        );
      }
    }
  });

  test('expedition shell keeps Russian player copy in ARB resources', () {
    const List<String> shellFiles = <String>[
      'lib/app/main_navigation_shell.dart',
      'lib/core/cache/cached_snapshot_banner.dart',
      'lib/design_system/companion_motion.dart',
      'lib/design_system/pilot_motion.dart',
      'lib/features/home/presentation/home_screen.dart',
      'lib/features/recovery/presentation/mobile_command_recovery_action.dart',
    ];

    for (final String path in shellFiles) {
      expect(
        RegExp(r'[А-Яа-яЁё]').hasMatch(File(path).readAsStringSync()),
        isFalse,
        reason: '$path must use generated localization resources',
      );
    }
  });
}

Map<String, Object?> _readArb(String path) {
  return (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>)
      .cast<String, Object?>();
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((String key) => !key.startsWith('@')).toSet();
}

bool _containsPlaceholder(String message, String placeholder) {
  return message.contains('{$placeholder}') ||
      message.contains('{$placeholder,');
}
