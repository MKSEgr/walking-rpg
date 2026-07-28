import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';

import 'support/in_memory_read_snapshot_cache.dart';
import 'support/platform_fixture.dart';

void main() {
  test('fetches platform snapshot with authenticated user header', () async {
    final _FakePlatformTransport transport = _FakePlatformTransport(
      getResponse: HomeTransportResponse(
        statusCode: 200,
        body: jsonEncode(platformSnapshotJson()),
      ),
    );
    final PlatformApiClient client = PlatformApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: transport,
    );

    final PlatformSnapshot snapshot = await client.fetchSnapshot();

    expect(transport.requestedMethod, 'GET');
    expect(transport.requestedUri?.path, '/api/v1/platform');
    expect(transport.requestedHeaders?['X-User-Id'], 'user-1');
    expect(snapshot.contentVersion, 'chapter-1-v1');
  });

  test(
    'sends platform command contract and maps authoritative result',
    () async {
      final PlatformSnapshot updated = platformSnapshot(
        stateVersion: 4,
        completedOnboardingSteps: const <String>[
          'welcome',
          'health-permission',
        ],
      );
      final _FakePlatformTransport transport = _FakePlatformTransport(
        postResponse: HomeTransportResponse(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'commandType': 'COMPLETE_ONBOARDING_STEP',
            'idempotencyKey': 'onboarding-1',
            'message': 'Шаг onboarding завершён',
            'stateVersion': 4,
            'snapshot': platformSnapshotJson(
              stateVersion: 4,
              completedOnboardingSteps: const <String>[
                'welcome',
                'health-permission',
              ],
            ),
            'serverTime': updated.serverTime,
          }),
        ),
      );
      final PlatformApiClient client = PlatformApiClient(
        baseUri: Uri.parse('https://example.test/api'),
        userId: 'user-1',
        transport: transport,
      );

      final PlatformCommandResult result = await client.execute(
        commandType: 'complete_onboarding_step',
        payload: const <String, Object?>{'stepId': 'health-permission'},
        idempotencyKey: 'onboarding-1',
      );

      expect(transport.requestedMethod, 'POST');
      expect(transport.requestedUri?.path, '/api/v1/platform/commands');
      expect(transport.requestedHeaders?['Content-Type'], 'application/json');
      final Map<String, dynamic> request =
          jsonDecode(transport.requestedBody!) as Map<String, dynamic>;
      expect(request['commandType'], 'COMPLETE_ONBOARDING_STEP');
      expect(request['idempotencyKey'], 'onboarding-1');
      expect(request['payload'], <String, dynamic>{
        'stepId': 'health-permission',
      });
      expect(result.stateVersion, 4);
      expect(
        result.snapshot.userState.completedOnboardingSteps,
        contains('health-permission'),
      );
    },
  );

  test('exposes stable backend error code and details', () async {
    final PlatformApiClient client = PlatformApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakePlatformTransport(
        postResponse: HomeTransportResponse(
          statusCode: 409,
          body: jsonEncode(<String, dynamic>{
            'code': 'PLATFORM_STATE_CONFLICT',
            'message': 'Недостаточно сезонного опыта',
            'details': <String, dynamic>{
              'currentSeasonXp': 20,
              'requiredSeasonXp': 100,
            },
          }),
        ),
      ),
    );

    await expectLater(
      client.execute(
        commandType: 'UNLOCK_SKILL',
        payload: const <String, Object?>{'skillId': 'trail-memory'},
        idempotencyKey: 'skill-1',
      ),
      throwsA(
        isA<PlatformApiException>()
            .having(
              (PlatformApiException error) => error.statusCode,
              'statusCode',
              409,
            )
            .having(
              (PlatformApiException error) => error.code,
              'code',
              'PLATFORM_STATE_CONFLICT',
            )
            .having(
              (PlatformApiException error) => error.details['requiredSeasonXp'],
              'requiredSeasonXp',
              100,
            ),
      ),
    );
  });

  test('falls back to cached platform snapshot on retryable failure', () async {
    final DateTime cachedAt = DateTime.utc(2026, 7, 27, 9);
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache(
      clock: () => cachedAt,
    );
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.platform,
      variant: PlatformApiClient.cacheVariant,
      payload: jsonEncode(platformSnapshotJson()),
      ttl: const Duration(days: 7),
    );
    final PlatformApiClient client = PlatformApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: const _ThrowingPlatformTransport(),
      cache: cache,
    );

    final PlatformSnapshot snapshot = await client.fetchSnapshot();

    expect(snapshot.isCached, isTrue);
    expect(snapshot.cacheMetadata?.cachedAt, cachedAt);
    expect(snapshot.cacheMetadata?.reason, 'Нет соединения с сервером');
  });

  test('does not use platform cache for terminal 403 response', () async {
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache(
      clock: () => DateTime.utc(2026, 7, 27, 9),
    );
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.platform,
      variant: PlatformApiClient.cacheVariant,
      payload: jsonEncode(platformSnapshotJson()),
      ttl: const Duration(days: 7),
    );
    final PlatformApiClient client = PlatformApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakePlatformTransport(
        getResponse: HomeTransportResponse(
          statusCode: 403,
          body: jsonEncode(<String, Object?>{
            'code': 'FORBIDDEN',
            'message': 'Доступ запрещён',
          }),
        ),
      ),
      cache: cache,
    );

    await expectLater(
      client.fetchSnapshot(),
      throwsA(
        isA<PlatformApiException>().having(
          (PlatformApiException error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test(
    'command stores authoritative platform snapshot and invalidates home',
    () async {
      final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache(
        clock: () => DateTime.utc(2026, 7, 27, 9),
      );
      await cache.write(
        ownerId: 'command-cache-user',
        resource: ReadSnapshotResource.home,
        variant: '2026-07-27',
        payload: '{}',
        ttl: const Duration(days: 1),
      );
      await cache.write(
        ownerId: 'command-cache-user',
        resource: ReadSnapshotResource.platform,
        variant: PlatformApiClient.cacheVariant,
        payload: jsonEncode(platformSnapshotJson(stateVersion: 2)),
        ttl: PlatformApiClient.cacheTtl,
      );
      final _FakePlatformTransport transport = _FakePlatformTransport(
        postResponse: HomeTransportResponse(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'commandType': 'SELECT_PET',
            'idempotencyKey': 'pet-1',
            'message': 'Питомец выбран',
            'stateVersion': 3,
            'snapshot': platformSnapshotJson(stateVersion: 3),
            'serverTime': '2026-07-27T09:00:00Z',
          }),
        ),
      );
      final PlatformApiClient client = PlatformApiClient(
        baseUri: Uri.parse('http://localhost:8080'),
        userId: 'command-cache-user',
        transport: transport,
        cache: cache,
      );

      await client.execute(
        commandType: 'SELECT_PET',
        payload: const <String, Object?>{'petId': 'spark'},
        idempotencyKey: 'pet-1',
      );

      expect(
        await cache.read(
          ownerId: 'command-cache-user',
          resource: ReadSnapshotResource.home,
          variant: '2026-07-27',
        ),
        isNull,
      );
      final ReadSnapshotCacheEntry? platformEntry = await cache.read(
        ownerId: 'command-cache-user',
        resource: ReadSnapshotResource.platform,
        variant: PlatformApiClient.cacheVariant,
      );
      expect(platformEntry, isNotNull);
      expect(
        (jsonDecode(platformEntry!.payload)
            as Map<String, dynamic>)['stateVersion'],
        3,
      );
    },
  );

  test(
    'does not mask an unexpected platform client error with cache',
    () async {
      final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache(
        clock: () => DateTime.utc(2026, 7, 27, 9),
      );
      await cache.write(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.platform,
        variant: PlatformApiClient.cacheVariant,
        payload: jsonEncode(platformSnapshotJson()),
        ttl: const Duration(days: 7),
      );
      final PlatformApiClient client = PlatformApiClient(
        baseUri: Uri.parse('http://localhost:8080'),
        userId: 'user-1',
        transport: const _BuggyPlatformTransport(),
        cache: cache,
      );

      await expectLater(
        client.fetchSnapshot(),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            'unexpected test bug',
          ),
        ),
      );
    },
  );
}

class _BuggyPlatformTransport implements HomeTransport {
  const _BuggyPlatformTransport();

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

class _ThrowingPlatformTransport implements HomeTransport {
  const _ThrowingPlatformTransport();

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

class _FakePlatformTransport implements HomeTransport {
  _FakePlatformTransport({this.getResponse, this.postResponse});

  final HomeTransportResponse? getResponse;
  final HomeTransportResponse? postResponse;
  String? requestedMethod;
  Uri? requestedUri;
  Map<String, String>? requestedHeaders;
  String? requestedBody;

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    requestedMethod = 'GET';
    requestedUri = uri;
    requestedHeaders = Map<String, String>.from(headers);
    return getResponse ??
        (throw StateError('GET response не настроен для теста'));
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    requestedMethod = 'POST';
    requestedUri = uri;
    requestedHeaders = Map<String, String>.from(headers);
    requestedBody = body;
    return postResponse ??
        (throw StateError('POST response не настроен для теста'));
  }
}
