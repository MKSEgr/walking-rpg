import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';

import 'support/in_memory_read_snapshot_cache.dart';
import 'support/platform_fixture.dart';

void main() {
  test('experiment exposure preserves home and newer platform cache', () async {
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache();
    await _seedHome(cache);
    await _seedPlatform(cache, stateVersion: 12);
    final PlatformApiClient client = PlatformApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'review-user-exposure',
      transport: _CommandTransport(
        HomeTransportResponse(
          statusCode: 200,
          body: jsonEncode(
            _commandResponse(
              commandType: 'RECORD_EXPERIMENT_EXPOSURE',
              idempotencyKey: 'exposure-chapter-1-v1',
              stateVersion: 4,
            ),
          ),
        ),
      ),
      cache: cache,
    );

    await client.execute(
      commandType: 'RECORD_EXPERIMENT_EXPOSURE',
      payload: const <String, Object?>{
        'experimentId': 'home-energy-copy-v1',
        'variant': 'CONTROL',
      },
      idempotencyKey: 'exposure-chapter-1-v1',
    );

    expect(cache.invalidations, 0);
    expect(await _readHome(cache, 'review-user-exposure'), isNotNull);
    expect(await _cachedPlatformVersion(cache, 'review-user-exposure'), 12);
  });

  test(
    'older replayed command snapshot is rejected after invalidation',
    () async {
      final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache();
      await _seedHome(cache, ownerId: 'review-user-old-command');
      await _seedPlatform(
        cache,
        ownerId: 'review-user-old-command',
        stateVersion: 12,
      );
      final PlatformApiClient client = PlatformApiClient(
        baseUri: Uri.parse('http://localhost:8080'),
        userId: 'review-user-old-command',
        transport: _CommandTransport(
          HomeTransportResponse(
            statusCode: 200,
            body: jsonEncode(
              _commandResponse(
                commandType: 'SELECT_PET',
                idempotencyKey: 'pet-replay-1',
                stateVersion: 4,
              ),
            ),
          ),
        ),
        cache: cache,
      );

      await client.execute(
        commandType: 'SELECT_PET',
        payload: const <String, Object?>{'petId': 'spark-v1'},
        idempotencyKey: 'pet-replay-1',
      );

      expect(cache.invalidations, 1);
      expect(await _readPlatform(cache, 'review-user-old-command'), isNull);
    },
  );

  test('platform high-water survives snapshot invalidation', () async {
    const String ownerId = 'review-user-high-water';
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache();
    await _seedPlatform(cache, ownerId: ownerId, stateVersion: 12);
    final PlatformApiClient observer = PlatformApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: ownerId,
      transport: const _RetryableGetTransport(),
      cache: cache,
    );

    final PlatformSnapshot observed = await observer.fetchSnapshot();
    expect(observed.stateVersion, 12);
    await invalidateReadSnapshotsBeforeMutation(cache, ownerId: ownerId);
    expect(await _readPlatform(cache, ownerId), isNull);

    final PlatformApiClient replay = PlatformApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: ownerId,
      transport: _CommandTransport(
        HomeTransportResponse(
          statusCode: 200,
          body: jsonEncode(
            _commandResponse(
              commandType: 'SELECT_PET',
              idempotencyKey: 'pet-old-after-invalidation',
              stateVersion: 4,
            ),
          ),
        ),
      ),
      cache: cache,
    );

    await replay.execute(
      commandType: 'SELECT_PET',
      payload: const <String, Object?>{'petId': 'spark-v1'},
      idempotencyKey: 'pet-old-after-invalidation',
    );

    expect(await _readPlatform(cache, ownerId), isNull);
  });

  test('command response without a trusted baseline is not cached', () async {
    const String ownerId = 'review-user-no-baseline';
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache();
    final PlatformApiClient client = PlatformApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: ownerId,
      transport: _CommandTransport(
        HomeTransportResponse(
          statusCode: 200,
          body: jsonEncode(
            _commandResponse(
              commandType: 'SELECT_PET',
              idempotencyKey: 'pet-unknown-history',
              stateVersion: 4,
            ),
          ),
        ),
      ),
      cache: cache,
    );

    await client.execute(
      commandType: 'SELECT_PET',
      payload: const <String, Object?>{'petId': 'spark-v1'},
      idempotencyKey: 'pet-unknown-history',
    );

    expect(await _readPlatform(cache, ownerId), isNull);
  });

  test('newer authoritative command snapshot is cached', () async {
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache();
    await _seedHome(cache, ownerId: 'review-user-new-command');
    await _seedPlatform(
      cache,
      ownerId: 'review-user-new-command',
      stateVersion: 3,
    );
    final PlatformApiClient client = PlatformApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'review-user-new-command',
      transport: _CommandTransport(
        HomeTransportResponse(
          statusCode: 200,
          body: jsonEncode(
            _commandResponse(
              commandType: 'SELECT_PET',
              idempotencyKey: 'pet-new-1',
              stateVersion: 4,
            ),
          ),
        ),
      ),
      cache: cache,
    );

    await client.execute(
      commandType: 'SELECT_PET',
      payload: const <String, Object?>{'petId': 'spark-v1'},
      idempotencyKey: 'pet-new-1',
    );

    expect(cache.invalidations, 1);
    expect(await _cachedPlatformVersion(cache, 'review-user-new-command'), 4);
  });

  test('in-flight home read cannot recreate cache after mutation', () async {
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache();
    final _PendingGetTransport transport = _PendingGetTransport();
    final HomeApiClient client = HomeApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'review-user-in-flight',
      transport: transport,
      cache: cache,
    );

    final Future<HomeSnapshot> pending = client.fetchHome(
      DateTime(2026, 7, 28),
    );
    await transport.started.future;
    await invalidateReadSnapshotsBeforeMutation(
      cache,
      ownerId: 'review-user-in-flight',
    );
    transport.response.complete(
      HomeTransportResponse(statusCode: 200, body: jsonEncode(_homeResponse())),
    );

    final HomeSnapshot snapshot = await pending;

    expect(snapshot.dailySteps, 6842);
    expect(await _readHome(cache, 'review-user-in-flight'), isNull);
  });
}

Future<void> _seedHome(
  InMemoryReadSnapshotCache cache, {
  String ownerId = 'review-user-exposure',
}) {
  return cache.write(
    ownerId: ownerId,
    resource: ReadSnapshotResource.home,
    variant: '2026-07-28',
    payload: jsonEncode(_homeResponse()),
    ttl: const Duration(hours: 36),
  );
}

Future<void> _seedPlatform(
  InMemoryReadSnapshotCache cache, {
  String ownerId = 'review-user-exposure',
  required int stateVersion,
}) {
  return cache.write(
    ownerId: ownerId,
    resource: ReadSnapshotResource.platform,
    variant: PlatformApiClient.cacheVariant,
    payload: jsonEncode(platformSnapshotJson(stateVersion: stateVersion)),
    ttl: PlatformApiClient.cacheTtl,
  );
}

Future<ReadSnapshotCacheEntry?> _readHome(
  InMemoryReadSnapshotCache cache,
  String ownerId,
) {
  return cache.read(
    ownerId: ownerId,
    resource: ReadSnapshotResource.home,
    variant: '2026-07-28',
  );
}

Future<ReadSnapshotCacheEntry?> _readPlatform(
  InMemoryReadSnapshotCache cache,
  String ownerId,
) {
  return cache.read(
    ownerId: ownerId,
    resource: ReadSnapshotResource.platform,
    variant: PlatformApiClient.cacheVariant,
  );
}

Future<int?> _cachedPlatformVersion(
  InMemoryReadSnapshotCache cache,
  String ownerId,
) async {
  final ReadSnapshotCacheEntry? entry = await _readPlatform(cache, ownerId);
  if (entry == null) {
    return null;
  }
  final Map<String, dynamic> json =
      jsonDecode(entry.payload) as Map<String, dynamic>;
  return json['stateVersion'] as int;
}

Map<String, dynamic> _commandResponse({
  required String commandType,
  required String idempotencyKey,
  required int stateVersion,
}) {
  return <String, dynamic>{
    'commandType': commandType,
    'idempotencyKey': idempotencyKey,
    'message': 'Команда выполнена',
    'stateVersion': stateVersion,
    'snapshot': platformSnapshotJson(stateVersion: stateVersion),
    'serverTime': '2026-07-28T05:00:00Z',
  };
}

Map<String, dynamic> _homeResponse() {
  return <String, dynamic>{
    'localDate': '2026-07-28',
    'timeZone': 'Europe/Berlin',
    'dailySteps': 6842,
    'dailyGoal': 3250,
    'dailyGoalPolicy': <String, dynamic>{
      'policyVersion': 'adaptive-median-v1',
      'source': 'ADAPTIVE',
      'baselineSteps': 3000,
      'sampleDays': 3,
      'lookbackDays': 7,
      'minimumSampleDays': 3,
      'defaultGoal': 6000,
      'growthPercent': 5,
      'roundingStep': 250,
      'minimumGoal': 2000,
      'maximumGoal': 12000,
    },
    'availableEnergy': 38,
    'activityStateVersion': 1,
    'economyVersion': 2,
    'lastActivitySyncAt': '2026-07-28T04:55:00Z',
    'serverTime': '2026-07-28T05:00:00Z',
    'contentVersion': 'chapter-1-v1',
    'pilot': <String, dynamic>{
      'name': 'Навигатор',
      'level': 1,
      'currentExperience': 20,
      'nextLevelExperience': 100,
      'specialization': 'Не выбрана',
    },
    'pet': <String, dynamic>{
      'name': 'Искра',
      'species': 'Люмин',
      'level': 1,
      'bond': 10,
      'trait': 'Чуткий разведчик',
    },
    'expedition': <String, dynamic>{
      'expeditionId': 'starter-expedition-v1',
      'name': 'Сигнал из туманного сектора',
      'currentNodeId': 'outer-beacon',
      'currentNode': 'Внешний маяк',
      'progress': 30,
      'requiredEnergy': 30,
      'status': 'EVENT_READY',
      'version': 1,
      'unlockedEvent': <String, dynamic>{
        'eventId': 'signal-source-v1',
        'title': 'Источник сигнала',
        'summary': 'Маяк отвечает импульсом.',
        'status': 'READY',
      },
    },
  };
}

final class _CommandTransport implements HomeTransport {
  _CommandTransport(this.response);

  final HomeTransportResponse response;

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
    return response;
  }
}

final class _RetryableGetTransport implements HomeTransport {
  const _RetryableGetTransport();

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    return const HomeTransportResponse(
      statusCode: 503,
      body: '{"message":"temporarily unavailable"}',
    );
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) {
    throw UnimplementedError();
  }
}

final class _PendingGetTransport implements HomeTransport {
  final Completer<void> started = Completer<void>();
  final Completer<HomeTransportResponse> response =
      Completer<HomeTransportResponse>();

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) {
    if (!started.isCompleted) {
      started.complete();
    }
    return response.future;
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) {
    throw UnimplementedError();
  }
}
