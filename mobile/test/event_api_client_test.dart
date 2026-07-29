import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/event/data/event_api_client.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

import 'support/in_memory_read_snapshot_cache.dart';

void main() {
  test('client sends event choice and maps persistent rewards', () async {
    final _FakeTransport transport = _FakeTransport(
      HomeTransportResponse(statusCode: 200, body: jsonEncode(_response())),
    );
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache();
    await _seedReadCache(cache);
    final EventApiClient client = EventApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: transport,
      cache: cache,
    );

    final EventResolutionResult result = await client.resolve(
      eventId: 'echo-vault-v1',
      choiceId: 'stabilize-core',
      idempotencyKey: 'resolve-1',
    );

    expect(
      transport.requestedUri?.path,
      '/api/v1/events/echo-vault-v1/resolve',
    );
    expect(transport.requestedHeaders?.containsKey('X-User-Id'), isFalse);
    expect(transport.decodedBody?['choiceId'], 'stabilize-core');
    expect(transport.decodedBody?['idempotencyKey'], 'resolve-1');
    expect(
      transport.requestedHeaders?[EventApiClient.clientCapabilitiesHeader],
      EventApiClient.durableHandoffCapability,
    );
    expect(result.status, 'RESOLVED');
    expect(result.receiptId, '22222222-2222-2222-2222-222222222222');
    expect(result.handoffRequired, isTrue);
    expect(result.pilot.currentExperience, 90);
    expect(result.pet.bond, 23);
    expect(result.material?.itemId, 'lumen-shard');
    expect(result.material?.quantityAfter, 2);
    expect(result.nextNode?.nodeId, 'ash-orbit');
    expect(cache.invalidations, 1);
    expect(await _readHome(cache), isNull);
    expect(await _readPlatform(cache), isNull);
  });

  test('client accepts a legacy event response without handoff fields', () {
    final Map<String, dynamic> legacy = _response()
      ..remove('receiptId')
      ..remove('handoffRequired')
      ..remove('nextNode');

    final EventResolutionResult result = EventResolutionResult.fromJson(legacy);

    expect(result.receiptId, isNull);
    expect(result.handoffRequired, isFalse);
    expect(result.nextNode, isNull);
  });

  test('durable handoff response requires a receipt', () {
    final Map<String, dynamic> invalid = _response()..remove('receiptId');

    expect(
      () => EventResolutionResult.fromJson(invalid),
      throwsFormatException,
    );
  });

  test('client acknowledges a durable event result receipt', () async {
    final _FakeTransport transport = _FakeTransport(
      HomeTransportResponse(
        statusCode: 200,
        body: jsonEncode(<String, dynamic>{
          'receiptId': '22222222-2222-2222-2222-222222222222',
          'eventId': 'echo-vault-v1',
          'status': 'ACKNOWLEDGED',
          'acknowledgedAt': '2026-07-26T06:05:00Z',
          'serverTime': '2026-07-26T06:05:00Z',
        }),
      ),
    );
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache();
    await _seedReadCache(cache);
    final EventApiClient client = EventApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: transport,
      cache: cache,
    );

    final EventResultAcknowledgement result = await client.acknowledge(
      receiptId: '22222222-2222-2222-2222-222222222222',
    );

    expect(
      transport.requestedUri?.path,
      '/api/v1/event-results/'
      '22222222-2222-2222-2222-222222222222/acknowledge',
    );
    expect(transport.requestedHeaders?['Content-Type'], isNull);
    expect(transport.requestedBody, isEmpty);
    expect(transport.decodedBody, isNull);
    expect(result.eventId, 'echo-vault-v1');
    expect(result.status, 'ACKNOWLEDGED');
    expect(result.acknowledgedAt, '2026-07-26T06:05:00Z');
    expect(cache.invalidations, 1);
    expect(await _readHome(cache), isNull);
    expect(await _readPlatform(cache), isNull);
  });

  test('client exposes backend event error', () async {
    final EventApiClient client = EventApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakeTransport(
        HomeTransportResponse(
          statusCode: 409,
          body: jsonEncode(<String, dynamic>{
            'code': 'EVENT_STATE_CONFLICT',
            'message': 'Событие уже разрешено',
          }),
        ),
      ),
    );

    await expectLater(
      client.resolve(
        eventId: 'signal-source-v1',
        choiceId: 'analyze-signal',
        idempotencyKey: 'resolve-2',
      ),
      throwsA(
        isA<EventApiException>()
            .having(
              (EventApiException error) => error.code,
              'code',
              'EVENT_STATE_CONFLICT',
            )
            .having(
              (EventApiException error) => error.message,
              'message',
              'Событие уже разрешено',
            ),
      ),
    );
  });
}

Future<void> _seedReadCache(InMemoryReadSnapshotCache cache) async {
  await cache.write(
    ownerId: 'user-1',
    resource: ReadSnapshotResource.home,
    variant: 'today',
    payload: '{}',
    ttl: const Duration(days: 1),
  );
  await cache.write(
    ownerId: 'user-1',
    resource: ReadSnapshotResource.platform,
    variant: 'current',
    payload: '{}',
    ttl: const Duration(days: 1),
  );
}

Future<ReadSnapshotCacheEntry?> _readHome(InMemoryReadSnapshotCache cache) {
  return cache.read(
    ownerId: 'user-1',
    resource: ReadSnapshotResource.home,
    variant: 'today',
  );
}

Future<ReadSnapshotCacheEntry?> _readPlatform(InMemoryReadSnapshotCache cache) {
  return cache.read(
    ownerId: 'user-1',
    resource: ReadSnapshotResource.platform,
    variant: 'current',
  );
}

Map<String, dynamic> _response() {
  return <String, dynamic>{
    'receiptId': '22222222-2222-2222-2222-222222222222',
    'handoffRequired': true,
    'contentVersion': 'chapter-1-v1',
    'expeditionId': 'starter-expedition-v1',
    'expeditionStatus': 'IN_PROGRESS',
    'expeditionVersion': 4,
    'eventId': 'echo-vault-v1',
    'eventTitle': 'Хранилище эха',
    'status': 'RESOLVED',
    'choiceId': 'stabilize-core',
    'choiceTitle': 'Стабилизировать ядро',
    'outcomeTitle': 'Стабильный резонанс',
    'outcomeSummary': 'Ядро перестало разрушаться.',
    'pilot': <String, dynamic>{
      'pilotId': 'navigator-v1',
      'name': 'Навигатор',
      'level': 1,
      'experienceGained': 30,
      'currentExperience': 90,
      'nextLevelExperience': 100,
      'version': 2,
    },
    'pet': <String, dynamic>{
      'petId': 'spark-v1',
      'name': 'Искра',
      'level': 1,
      'bondGained': 8,
      'bond': 23,
      'version': 2,
    },
    'material': <String, dynamic>{
      'itemId': 'lumen-shard',
      'name': 'Люминовый осколок',
      'description': 'Стабильный фрагмент светового ядра.',
      'quantityGained': 2,
      'quantityAfter': 2,
      'version': 1,
    },
    'nextNode': <String, dynamic>{
      'nodeId': 'ash-orbit',
      'name': 'Пепельная орбита',
    },
    'serverTime': '2026-07-26T06:00:00Z',
  };
}

class _FakeTransport implements HomeTransport {
  _FakeTransport(this.response);

  final HomeTransportResponse response;
  Uri? requestedUri;
  Map<String, String>? requestedHeaders;
  String? requestedBody;
  Map<String, dynamic>? decodedBody;

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    requestedUri = uri;
    requestedHeaders = Map<String, String>.from(headers);
    requestedBody = body;
    decodedBody = body.isEmpty
        ? null
        : jsonDecode(body) as Map<String, dynamic>;
    return response;
  }
}
