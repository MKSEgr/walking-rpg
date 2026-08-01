import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/validation/domain/device_validation_evidence.dart';

void main() {
  test('encodes deterministic evidence with a verifiable checksum', () {
    final DeviceValidationEvidenceSnapshot snapshot = _snapshot();

    final String first = DeviceValidationEvidenceCodec.encode(
      snapshot,
      exportedAtUtc: DateTime.utc(2026, 7, 31, 18, 5),
    );
    final String second = DeviceValidationEvidenceCodec.encode(
      snapshot,
      exportedAtUtc: DateTime.utc(2026, 7, 31, 18, 5),
    );

    expect(first, second);
    expect(DeviceValidationEvidenceCodec.verify(first), isTrue);
    expect(
      utf8.encode(first).length,
      lessThanOrEqualTo(DeviceValidationEvidenceCodec.maxEncodedBytes),
    );
    final Map<String, dynamic> decoded =
        jsonDecode(first) as Map<String, dynamic>;
    expect(
      decoded['schemaVersion'],
      DeviceValidationEvidenceCodec.schemaVersion,
    );
    expect(
      decoded['redactionPolicy'],
      DeviceValidationEvidenceCodec.redactionPolicy,
    );
    final Map<String, dynamic> checksum =
        decoded['checksum'] as Map<String, dynamic>;
    expect(checksum['algorithm'], 'SHA-256');
    expect(checksum['value'], isA<String>());
    expect(first, isNot(contains('owner-1')));
    expect(first, isNot(contains('syncCursor')));
  });

  test('checksum verification rejects a changed observation', () {
    final String encoded = DeviceValidationEvidenceCodec.encode(
      _snapshot(),
      exportedAtUtc: DateTime.utc(2026, 7, 31, 18, 5),
    );
    final String changed = encoded.replaceFirst(
      '"authoritativeTotal":6842',
      '"authoritativeTotal":6843',
    );

    expect(DeviceValidationEvidenceCodec.verify(changed), isFalse);
  });

  test('redaction rejects sensitive keys and values', () {
    const List<String> forbiddenKeys = <String>[
      'accessToken',
      'access_token',
      'refresh-token',
      'authorizationHeader',
      'rawOwnerId',
      'display_name',
      'sync_cursor',
      'idempotency-key',
      'apiEndpoint',
      'errorMessage',
      'accessTokenValue',
      'owner_id_hash',
      'sync_cursor_value',
      'idempotency_keys',
      'api_endpoints',
      'request_body',
      'response_body',
      'stack_trace',
      'exception_message',
      'commandId',
      'diagnosticId',
      'crashId',
      'accountId',
      'oidcSubject',
      'sourceId',
      'recordId',
    ];
    for (final String key in forbiddenKeys) {
      expect(
        () => DeviceValidationEvidenceCodec.validateNoSensitiveData(
          <String, Object?>{key: 'opaque-secret'},
        ),
        throwsA(isA<FormatException>()),
        reason: key,
      );
    }

    const List<String> forbiddenValues = <String>[
      'Bearer opaque-secret',
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature',
      'https://production.example/api',
      'file:///Users/tester/private.json',
      '/tmp/private.json',
      r'C:\Temp\private.json',
      r'..\private.json',
      'logs/private.json',
      'identity.internal.example',
      '127.0.0.1:8080',
      '[2001:db8::1]:8080',
      '2001:db8::1',
      'safe\u200btext',
    ];
    for (final String value in forbiddenValues) {
      expect(
        () => DeviceValidationEvidenceCodec.validateNoSensitiveData(
          <String, Object?>{'safeText': value},
        ),
        throwsA(isA<FormatException>()),
        reason: value,
      );
    }
    expect(
      () => DeviceValidationEvidenceCodec.validateNoSensitiveData(
        <String, Object?>{'timeZone': 'Europe/Berlin'},
      ),
      returnsNormally,
    );
    expect(
      () => DeviceValidationEvidenceCodec.validateNoSensitiveData(
        <String, Object?>{'timeZone': '/Users/private'},
      ),
      throwsA(isA<FormatException>()),
    );
    for (final String pathLikeTimeZone in <String>[
      'logs/private.json',
      'Europe/private',
      'Europe/../../private',
    ]) {
      expect(
        () => EvidenceHealthObservation(
          status: EvidenceObservationStatus.succeeded,
          providerState: EvidenceProviderState.available,
          permissionState: EvidencePermissionState.requestSucceeded,
          authoritativeTotal: 10,
          localDate: '2026-07-31',
          timeZone: pathLikeTimeZone,
          includeManualEntries: false,
          durationMs: 1,
        ),
        throwsA(isA<FormatException>()),
        reason: pathLikeTimeZone,
      );
    }
    expect(
      () => EvidenceHealthObservation(
        status: EvidenceObservationStatus.succeeded,
        providerState: EvidenceProviderState.available,
        permissionState: EvidencePermissionState.requestSucceeded,
        authoritativeTotal: 10,
        localDate: '2026-07-31',
        timeZone: 'GB-Eire',
        includeManualEntries: false,
        durationMs: 1,
      ),
      returnsNormally,
    );
  });

  test('recomputed checksum cannot authorize invalid schema values', () {
    final String encoded = DeviceValidationEvidenceCodec.encode(
      _snapshot(),
      exportedAtUtc: DateTime.utc(2026, 7, 31, 18, 5),
    );

    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> sync =
              payload['latestSync'] as Map<String, dynamic>;
          sync['riskStatus'] = 'owner@identity.internal.example';
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> health =
              payload['latestHealth'] as Map<String, dynamic>;
          health
            ..['status'] = 'failed'
            ..['providerState'] = 'unknown'
            ..['permissionState'] = 'unknown'
            ..['authoritativeTotal'] = null
            ..['localDate'] = null
            ..['timeZone'] = null
            ..['errorCategory'] = 'unexpected_failure';
          final List<dynamic> journal = payload['journal'] as List<dynamic>;
          final Map<String, dynamic> read = journal[2] as Map<String, dynamic>;
          read
            ..['outcome'] = 'failed'
            ..['errorCategory'] = 'unexpected_failure';
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> launch =
              payload['launch'] as Map<String, dynamic>;
          launch['operatingSystemVersion'] = ' Android 16 ';
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> health =
              payload['latestHealth'] as Map<String, dynamic>;
          health
            ..['status'] = 'blocked'
            ..['providerState'] = 'unavailable'
            ..['permissionState'] = 'unknown'
            ..['authoritativeTotal'] = null
            ..['localDate'] = null
            ..['timeZone'] = null
            ..['durationMs'] = 50
            ..['errorCategory'] = 'provider_unavailable';
          final List<dynamic> journal = payload['journal'] as List<dynamic>;
          journal.insert(3, <String, Object?>{
            'sequence': 4,
            'scenario': 'provider',
            'outcome': 'blocked',
            'startedAtUtc': '2026-07-31T18:04:00Z',
            'durationMs': 50,
            'errorCategory': 'provider_unavailable',
          });
          for (int index = 4; index < journal.length; index += 1) {
            (journal[index] as Map<String, dynamic>)['sequence'] = index + 1;
          }
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> sync =
              payload['latestSync'] as Map<String, dynamic>;
          sync
            ..['acceptedTotal'] = 101
            ..['acceptedDelta'] = 1
            ..['energyGranted'] = 1;
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> checkpoint =
              payload['authoritativeCheckpoint'] as Map<String, dynamic>;
          checkpoint
            ..['completedMilestones'] = <String>['welcome']
            ..['firstJourneyStage'] = 'activity';
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> checkpoint =
              payload['authoritativeCheckpoint'] as Map<String, dynamic>;
          checkpoint['resolvedEventCount'] = 1;
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final List<dynamic> journal = payload['journal'] as List<dynamic>;
          journal.add(<String, Object?>{
            'sequence': 6,
            'scenario': 'read',
            'outcome': 'failed',
            'startedAtUtc': '2026-07-31T18:04:05Z',
            'durationMs': 120,
            'errorCategory': 'health_read_failed',
          });
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          payload
            ..['latestHealth'] = null
            ..['latestSync'] = null
            ..['authoritativeCheckpoint'] = null
            ..['journal'] = <Object?>[
              <String, Object?>{
                'sequence': 1,
                'scenario': 'read',
                'outcome': 'blocked',
                'startedAtUtc': '2026-07-31T18:04:00Z',
                'durationMs': 0,
                'errorCategory': 'journal_limit_reached',
              },
            ];
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          payload
            ..['latestSync'] = null
            ..['authoritativeCheckpoint'] = null
            ..['journal'] = <Object?>[
              <String, Object?>{
                'sequence': 1,
                'scenario': 'read',
                'outcome': 'passed',
                'startedAtUtc': '2026-07-31T18:04:00Z',
                'durationMs': 120,
                'errorCategory': null,
              },
            ];
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final List<dynamic> journal = payload['journal'] as List<dynamic>;
          (journal.last as Map<String, dynamic>)['startedAtUtc'] =
              '2026-07-31T18:03:59Z';
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final List<dynamic> journal = payload['journal'] as List<dynamic>;
          journal.addAll(<Object?>[
            <String, Object?>{
              'sequence': 6,
              'scenario': 'checkpoint',
              'outcome': 'blocked',
              'startedAtUtc': '2026-07-31T18:04:00Z',
              'durationMs': 0,
              'errorCategory': 'journal_limit_reached',
            },
            <String, Object?>{
              'sequence': 7,
              'scenario': 'sync',
              'outcome': 'passed',
              'startedAtUtc': '2026-07-31T18:04:00Z',
              'durationMs': 240,
              'errorCategory': null,
            },
          ]);
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> health =
              payload['latestHealth'] as Map<String, dynamic>;
          health
            ..['status'] = 'failed'
            ..['providerState'] = 'available'
            ..['permissionState'] = 'denied'
            ..['authoritativeTotal'] = null
            ..['localDate'] = null
            ..['timeZone'] = null
            ..['errorCategory'] = 'health_read_failed';
          final List<dynamic> journal = payload['journal'] as List<dynamic>;
          final Map<String, dynamic> read = journal[2] as Map<String, dynamic>;
          read
            ..['outcome'] = 'failed'
            ..['errorCategory'] = 'health_read_failed';
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> sync =
              payload['latestSync'] as Map<String, dynamic>;
          sync
            ..['acceptedDelta'] = 0
            ..['energyGranted'] = 0;
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          payload['exportedAtUtc'] = '2026-07-31T18:04:00Z';
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> checkpoint =
              payload['authoritativeCheckpoint'] as Map<String, dynamic>;
          checkpoint
            ..['firstJourneyStage'] = 'complete'
            ..['firstJourneyComplete'] = true;
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> launch =
              payload['launch'] as Map<String, dynamic>;
          launch['platform'] = 'ios';
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> health =
              payload['latestHealth'] as Map<String, dynamic>;
          health['providerState'] = 'unavailable';
          health['permissionState'] = 'denied';
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          payload['journal'] = <Object?>[];
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> health =
              payload['latestHealth'] as Map<String, dynamic>;
          health['durationMs'] = -1;
        }),
      ),
      isFalse,
    );
    expect(
      DeviceValidationEvidenceCodec.verify(
        _mutateAndResign(encoded, (Map<String, dynamic> payload) {
          final Map<String, dynamic> launch =
              payload['launch'] as Map<String, dynamic>;
          launch['buildMode'] = 'release';
        }),
      ),
      isFalse,
    );
  });

  test('verification requires the canonical compact schema order', () {
    final String encoded = DeviceValidationEvidenceCodec.encode(
      _snapshot(),
      exportedAtUtc: DateTime.utc(2026, 7, 31, 18, 5),
    );
    final Object? decoded = jsonDecode(encoded);

    expect(
      DeviceValidationEvidenceCodec.verify(
        const JsonEncoder.withIndent('  ').convert(decoded),
      ),
      isFalse,
    );
  });

  test('journal must remain contiguous and bounded', () {
    final List<EvidenceJournalEntry> entries =
        List<EvidenceJournalEntry>.generate(
          DeviceValidationEvidenceCodec.maxJournalEntries + 1,
          (int index) => EvidenceJournalEntry(
            sequence: index + 1,
            scenario: EvidenceScenario.read,
            outcome: EvidenceOutcome.passed,
            startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
            durationMs: 1,
          ),
        );

    expect(
      () => DeviceValidationEvidenceSnapshot(
        launch: _launch(),
        updatedAtUtc: DateTime.utc(2026, 7, 31, 18, 5),
        journal: entries,
      ),
      throwsA(isA<EvidenceLimitException>()),
    );
  });

  test('reserves entry 64 for a terminal marker and rejects a gap', () {
    final List<EvidenceJournalEntry> normalEntries =
        List<EvidenceJournalEntry>.generate(
          DeviceValidationEvidenceCodec.maxJournalEntries - 1,
          (int index) => EvidenceJournalEntry(
            sequence: index + 1,
            scenario: EvidenceScenario.checkpoint,
            outcome: EvidenceOutcome.failed,
            startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
            durationMs: 1,
            errorCategory: EvidenceErrorCategory.unexpectedFailure,
          ),
        );
    final List<EvidenceJournalEntry> entries = <EvidenceJournalEntry>[
      ...normalEntries,
      EvidenceJournalEntry(
        sequence: DeviceValidationEvidenceCodec.maxJournalEntries,
        scenario: EvidenceScenario.checkpoint,
        outcome: EvidenceOutcome.blocked,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 0,
        errorCategory: EvidenceErrorCategory.journalLimitReached,
      ),
    ];
    final DeviceValidationEvidenceSnapshot snapshot =
        DeviceValidationEvidenceSnapshot(
          launch: _launch(),
          updatedAtUtc: DateTime.utc(2026, 7, 31, 18, 5),
          journal: entries,
        );
    final String encoded = DeviceValidationEvidenceCodec.encode(
      snapshot,
      exportedAtUtc: DateTime.utc(2026, 7, 31, 18, 6),
    );

    expect(DeviceValidationEvidenceCodec.verify(encoded), isTrue);
    expect(
      () => DeviceValidationEvidenceSnapshot(
        launch: _launch(),
        updatedAtUtc: DateTime.utc(2026, 7, 31, 18, 5),
        journal: List<EvidenceJournalEntry>.generate(
          DeviceValidationEvidenceCodec.maxJournalEntries,
          (int index) => EvidenceJournalEntry(
            sequence: index + 1,
            scenario: EvidenceScenario.checkpoint,
            outcome: EvidenceOutcome.failed,
            startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
            durationMs: 1,
            errorCategory: EvidenceErrorCategory.unexpectedFailure,
          ),
        ),
      ),
      throwsA(isA<EvidenceLimitException>()),
    );
    expect(
      () => DeviceValidationEvidenceSnapshot(
        launch: _launch(),
        updatedAtUtc: DateTime.utc(2026, 7, 31, 18, 5),
        journal: <EvidenceJournalEntry>[
          entries.first,
          EvidenceJournalEntry(
            sequence: 3,
            scenario: EvidenceScenario.checkpoint,
            outcome: EvidenceOutcome.failed,
            startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
            durationMs: 1,
            errorCategory: EvidenceErrorCategory.unexpectedFailure,
          ),
        ],
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('verification is total for malformed text', () {
    expect(
      DeviceValidationEvidenceCodec.verify(String.fromCharCode(0xD800)),
      isFalse,
    );
  });

  test('launch metadata requires exact source commit', () {
    expect(
      () => EvidenceLaunchMetadata(
        startedAtUtc: DateTime.utc(2026, 7, 31),
        platform: 'android',
        operatingSystemVersion: 'Android 16',
        appVersion: '0.1.0',
        buildNumber: '46',
        sourceGitSha: 'unknown',
        buildMode: 'debug',
        authenticationMode: 'oidc',
        healthSource: EvidenceHealthSource.healthConnect,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('accepts expedition energy above one hundred', () {
    final AuthoritativeJourneyFacts facts = AuthoritativeJourneyFacts(
      homeActivityStateVersion: 3,
      homeEconomyVersion: 4,
      platformStateVersion: 7,
      contentVersion: 'chapter-1-v1',
      dailySteps: 15000,
      dailyGoal: 6500,
      availableEnergy: 130,
      currentNodeId: 'outer-beacon',
      expeditionStatus: 'IN_PROGRESS',
      expeditionProgress: 130,
      hasPendingEventResult: false,
      lastActivitySyncPresent: true,
      totalAcceptedSteps: 15000,
      hasSuccessfulActivitySync: true,
      resolvedEventCount: 0,
      completedMilestones: const <String>[
        'welcome',
        'health-permission',
        'first-sync',
        'pet-selection',
      ],
      firstJourneyStage: 'expedition',
      firstJourneyComplete: false,
      homeServerTime: '2026-07-31T18:04:08Z',
      platformServerTime: '2026-07-31T18:04:09Z',
      durationMs: 180,
    );

    expect(facts.expeditionProgress, 130);
  });
}

DeviceValidationEvidenceSnapshot _snapshot() {
  return DeviceValidationEvidenceSnapshot(
    launch: _launch(),
    updatedAtUtc: DateTime.utc(2026, 7, 31, 18, 4, 9),
    latestHealth: EvidenceHealthObservation(
      status: EvidenceObservationStatus.succeeded,
      providerState: EvidenceProviderState.available,
      permissionState: EvidencePermissionState.requestSucceeded,
      authoritativeTotal: 6842,
      localDate: '2026-07-31',
      timeZone: 'Europe/Berlin',
      includeManualEntries: false,
      durationMs: 120,
    ),
    latestSync: EvidenceSyncObservation.succeeded(
      acceptedTotal: 6842,
      acceptedDelta: 842,
      energyGranted: 8,
      energyBalanceAfter: 38,
      economyVersion: 4,
      stateVersion: 3,
      riskStatus: 'ACCEPTED',
      serverTime: '2026-07-31T18:04:08Z',
      durationMs: 240,
    ),
    authoritativeCheckpoint: AuthoritativeJourneyFacts(
      homeActivityStateVersion: 3,
      homeEconomyVersion: 4,
      platformStateVersion: 7,
      contentVersion: 'chapter-1-v1',
      dailySteps: 6842,
      dailyGoal: 6500,
      availableEnergy: 38,
      currentNodeId: 'outer-beacon',
      expeditionStatus: 'IN_PROGRESS',
      expeditionProgress: 0,
      hasPendingEventResult: false,
      lastActivitySyncPresent: true,
      totalAcceptedSteps: 6842,
      hasSuccessfulActivitySync: true,
      resolvedEventCount: 0,
      completedMilestones: const <String>[
        'welcome',
        'health-permission',
        'first-sync',
      ],
      firstJourneyStage: 'pet',
      firstJourneyComplete: false,
      homeServerTime: '2026-07-31T18:04:08Z',
      platformServerTime: '2026-07-31T18:04:09Z',
      durationMs: 180,
    ),
    journal: <EvidenceJournalEntry>[
      EvidenceJournalEntry(
        sequence: 1,
        scenario: EvidenceScenario.provider,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 0,
      ),
      EvidenceJournalEntry(
        sequence: 2,
        scenario: EvidenceScenario.permission,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 0,
      ),
      EvidenceJournalEntry(
        sequence: 3,
        scenario: EvidenceScenario.read,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 120,
      ),
      EvidenceJournalEntry(
        sequence: 4,
        scenario: EvidenceScenario.sync,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 240,
      ),
      EvidenceJournalEntry(
        sequence: 5,
        scenario: EvidenceScenario.checkpoint,
        outcome: EvidenceOutcome.passed,
        startedAtUtc: DateTime.utc(2026, 7, 31, 18, 4),
        durationMs: 180,
      ),
    ],
  );
}

EvidenceLaunchMetadata _launch() {
  return EvidenceLaunchMetadata(
    startedAtUtc: DateTime.utc(2026, 7, 31, 18),
    platform: 'android',
    operatingSystemVersion: 'Android 16',
    appVersion: '0.1.0',
    buildNumber: '46',
    sourceGitSha: '0123456789abcdef0123456789abcdef01234567',
    buildMode: 'debug',
    authenticationMode: 'oidc',
    healthSource: EvidenceHealthSource.healthConnect,
  );
}

String _mutateAndResign(
  String encoded,
  void Function(Map<String, dynamic> payload) mutate,
) {
  final Map<String, dynamic> envelope =
      jsonDecode(encoded) as Map<String, dynamic>;
  envelope.remove('checksum');
  mutate(envelope);
  final String checksum = sha256
      .convert(utf8.encode(jsonEncode(envelope)))
      .toString();
  envelope['checksum'] = <String, Object?>{
    'algorithm': 'SHA-256',
    'value': checksum,
  };
  return jsonEncode(envelope);
}
