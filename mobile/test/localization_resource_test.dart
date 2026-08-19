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
    expect(englishKeys.length, greaterThanOrEqualTo(680));

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

  test('localized game surfaces keep Russian player copy in ARB resources', () {
    const List<String> shellFiles = <String>[
      'lib/app/main_navigation_shell.dart',
      'lib/core/cache/cached_snapshot_banner.dart',
      'lib/core/localization/current_content_localizations.dart',
      'lib/core/localization/current_event_localizations.dart',
      'lib/core/localization/current_platform_content_localizations.dart',
      'lib/design_system/companion_bond_signal.dart',
      'lib/design_system/companion_motion.dart',
      'lib/design_system/pilot_motion.dart',
      'lib/design_system/quest_route_signal.dart',
      'lib/design_system/weekly_route_signal.dart',
      'lib/features/home/presentation/home_screen.dart',
      'lib/features/platform/presentation/platform_screen.dart',
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

  test('current content resolver never identifies copy by display text', () {
    final String source = File(
      'lib/core/localization/current_content_localizations.dart',
    ).readAsStringSync();

    expect(RegExp(r'fallback\s*==|==\s*fallback').hasMatch(source), isFalse);
    expect(source, contains("'starter-expedition-v1'"));
    expect(source, contains("'first-light-causeway'"));
    expect(source, contains("'prism-sextant-second-dawn-attunement-v1'"));
  });

  test('current event resolver uses stable event and choice identities', () {
    final String source = File(
      'lib/core/localization/current_event_localizations.dart',
    ).readAsStringSync();

    expect(RegExp(r'fallback\s*==|==\s*fallback').hasMatch(source), isFalse);
    expect(source, contains("'echo-vault-v1'"));
    expect(source, contains("'first-light-causeway-v1'"));
    expect(source, contains("'mirror-delta-v1::follow-resonance'"));
    expect(source, contains("'dawn-meridian-v1::cross-first-light-causeway'"));
  });

  test(
    'current Platform resolver uses stable catalog and command identities',
    () {
      final String source = File(
        'lib/core/localization/current_platform_content_localizations.dart',
      ).readAsStringSync();

      expect(RegExp(r'fallback\s*==|==\s*fallback').hasMatch(source), isFalse);
      expect(source, contains("'first-event'"));
      expect(source, contains("'signal-reader'"));
      expect(source, contains("'join-squad'"));
      expect(source, contains("'season-level-3'"));
      expect(source, contains("'dawn-frame'"));
      expect(source, contains("'signal-season-1'"));
      expect(source, contains("'quest-order-v1'"));
      expect(source, contains("'CLAIM_SEASON_REWARD'"));
    },
  );
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
