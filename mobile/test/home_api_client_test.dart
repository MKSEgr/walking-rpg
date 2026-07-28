import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';

import 'support/in_memory_read_snapshot_cache.dart';

void main() {
  test(
    'client sends user and local date and maps successful response',
    () async {
      final _FakeHomeTransport transport = _FakeHomeTransport(
        HomeTransportResponse(
          statusCode: 200,
          body: jsonEncode(_homeResponse()),
        ),
      );
      final HomeApiClient client = HomeApiClient(
        baseUri: Uri.parse('http://localhost:8080'),
        userId: 'user-1',
        transport: transport,
      );

      final HomeSnapshot snapshot = await client.fetchHome(
        DateTime(2026, 7, 25),
      );

      expect(transport.requestedUri?.path, '/api/v1/home');
      expect(
        transport.requestedUri?.queryParameters['localDate'],
        '2026-07-25',
      );
      expect(transport.requestedHeaders?['X-User-Id'], 'user-1');
      expect(snapshot.dailySteps, 6842);
      expect(snapshot.dailyGoal, 3250);
      expect(snapshot.dailyGoalPolicy.source, 'ADAPTIVE');
      expect(snapshot.availableEnergy, 38);
      expect(snapshot.expeditionStatus, 'EVENT_READY');
      expect(snapshot.unlockedEvent?.eventId, 'signal-source-v1');
    },
  );

  test('client exposes backend error message', () async {
    final HomeApiClient client = HomeApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakeHomeTransport(
        HomeTransportResponse(
          statusCode: 400,
          body: jsonEncode(<String, dynamic>{'message': 'Некорректная дата'}),
        ),
      ),
    );

    await expectLater(
      client.fetchHome(DateTime(2026, 7, 25)),
      throwsA(
        isA<HomeApiException>().having(
          (HomeApiException error) => error.message,
          'message',
          'Некорректная дата',
        ),
      ),
    );
  });

  test(
    'falls back to a validated cached snapshot on transport failure',
    () async {
      final DateTime cachedAt = DateTime.utc(2026, 7, 25, 10);
      final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache(
        clock: () => cachedAt,
      );
      await cache.write(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.home,
        variant: '2026-07-25',
        payload: jsonEncode(_homeResponse()),
        ttl: const Duration(hours: 36),
      );
      final HomeApiClient client = HomeApiClient(
        baseUri: Uri.parse('http://localhost:8080'),
        userId: 'user-1',
        transport: const _ThrowingHomeTransport(),
        cache: cache,
      );

      final HomeSnapshot snapshot = await client.fetchHome(
        DateTime(2026, 7, 25),
      );

      expect(snapshot.isCached, isTrue);
      expect(snapshot.cacheMetadata?.cachedAt, cachedAt);
      expect(snapshot.cacheMetadata?.reason, 'Нет соединения с сервером');
      expect(snapshot.dailySteps, 6842);
    },
  );

  test('does not hide terminal authorization errors behind cache', () async {
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache(
      clock: () => DateTime.utc(2026, 7, 25, 10),
    );
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: '2026-07-25',
      payload: jsonEncode(_homeResponse()),
      ttl: const Duration(hours: 36),
    );
    final HomeApiClient client = HomeApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakeHomeTransport(
        const HomeTransportResponse(statusCode: 401, body: '<html>denied'),
      ),
      cache: cache,
    );

    await expectLater(
      client.fetchHome(DateTime(2026, 7, 25)),
      throwsA(
        isA<HomeApiException>().having(
          (HomeApiException error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });

  test('uses cache for malformed retryable server response', () async {
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache(
      clock: () => DateTime.utc(2026, 7, 25, 10),
    );
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: '2026-07-25',
      payload: jsonEncode(_homeResponse()),
      ttl: const Duration(hours: 36),
    );
    final HomeApiClient client = HomeApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakeHomeTransport(
        const HomeTransportResponse(statusCode: 503, body: '<html>down'),
      ),
      cache: cache,
    );

    final HomeSnapshot snapshot = await client.fetchHome(DateTime(2026, 7, 25));

    expect(snapshot.isCached, isTrue);
    expect(snapshot.cacheMetadata?.reason, 'Backend временно недоступен');
  });

  test('does not mask an unexpected client error with cache', () async {
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache(
      clock: () => DateTime.utc(2026, 7, 25, 10),
    );
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: '2026-07-25',
      payload: jsonEncode(_homeResponse()),
      ttl: const Duration(hours: 36),
    );
    final HomeApiClient client = HomeApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: const _BuggyHomeTransport(),
      cache: cache,
    );

    await expectLater(
      client.fetchHome(DateTime(2026, 7, 25)),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          'unexpected test bug',
        ),
      ),
    );
  });
}

Map<String, dynamic> _homeResponse() {
  return <String, dynamic>{
    'localDate': '2026-07-25',
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
    'lastActivitySyncAt': '2026-07-25T11:55:00Z',
    'serverTime': '2026-07-25T12:00:00Z',
    'contentVersion': 'starter-v1',
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

class _FakeHomeTransport implements HomeTransport {
  _FakeHomeTransport(this.response);

  final HomeTransportResponse response;
  Uri? requestedUri;
  Map<String, String>? requestedHeaders;

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    requestedUri = uri;
    requestedHeaders = Map<String, String>.from(headers);
    return response;
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

class _BuggyHomeTransport implements HomeTransport {
  const _BuggyHomeTransport();

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    throw StateError('unexpected test bug');
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

class _ThrowingHomeTransport implements HomeTransport {
  const _ThrowingHomeTransport();

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    throw const HomeNetworkException('Нет соединения с сервером');
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
