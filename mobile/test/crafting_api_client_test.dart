import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/crafting/data/crafting_api_client.dart';
import 'package:walking_rpg_mobile/features/crafting/domain/crafting_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

import 'support/in_memory_read_snapshot_cache.dart';

void main() {
  test('client posts crafting command and invalidates read cache', () async {
    final _FakeTransport transport = _FakeTransport(
      HomeTransportResponse(
        statusCode: 200,
        body: jsonEncode(_craftingResponse()),
      ),
    );
    final InMemoryReadSnapshotCache cache = InMemoryReadSnapshotCache();
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: 'today',
      payload: '{}',
      ttl: const Duration(days: 1),
    );
    final CraftingApiClient client = CraftingApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: transport,
      cache: cache,
    );

    final CraftingResult result = await client.craft(
      recipeId: 'resonance-compass-v1',
      idempotencyKey: 'craft-1',
    );

    expect(
      transport.requestedUri?.path,
      '/api/v1/crafting/recipes/resonance-compass-v1/craft',
    );
    expect(transport.requestedHeaders?.containsKey('X-User-Id'), isFalse);
    expect(transport.requestBody, <String, dynamic>{
      'idempotencyKey': 'craft-1',
    });
    expect(result.craftedItem.itemId, 'resonance-compass');
    expect(result.consumedIngredients, hasLength(2));
    expect(cache.invalidations, 1);
  });

  test('client exposes stable crafting error', () async {
    final CraftingApiClient client = CraftingApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakeTransport(
        HomeTransportResponse(
          statusCode: 409,
          body: jsonEncode(<String, dynamic>{
            'code': 'INSUFFICIENT_MATERIALS',
            'message': 'Недостаточно материалов',
          }),
        ),
      ),
    );

    await expectLater(
      client.craft(recipeId: 'resonance-compass-v1', idempotencyKey: 'craft-1'),
      throwsA(
        isA<CraftingApiException>()
            .having(
              (CraftingApiException error) => error.statusCode,
              'statusCode',
              409,
            )
            .having(
              (CraftingApiException error) => error.code,
              'code',
              'INSUFFICIENT_MATERIALS',
            ),
      ),
    );
  });
}

Map<String, dynamic> _craftingResponse() {
  return <String, dynamic>{
    'contentVersion': 'crafting-v1',
    'recipeId': 'resonance-compass-v1',
    'recipeVersion': '1',
    'recipeName': 'Собрать резонансный компас',
    'consumedIngredients': <Map<String, dynamic>>[
      <String, dynamic>{
        'itemId': 'echo-thread',
        'name': 'Нить эха',
        'quantityConsumed': 1,
        'quantityAfter': 0,
        'version': 2,
      },
      <String, dynamic>{
        'itemId': 'lumen-shard',
        'name': 'Люминовый осколок',
        'quantityConsumed': 2,
        'quantityAfter': 1,
        'version': 3,
      },
    ],
    'craftedItem': <String, dynamic>{
      'itemInstanceId': '11111111-2222-3333-4444-555555555555',
      'itemId': 'resonance-compass',
      'name': 'Резонансный компас',
      'description': 'Уникальный прибор.',
      'version': 1,
      'craftedAt': '2026-08-01T08:00:00Z',
    },
    'serverTime': '2026-08-01T08:00:00Z',
  };
}

class _FakeTransport implements HomeTransport {
  _FakeTransport(this.response);

  final HomeTransportResponse response;
  Uri? requestedUri;
  Map<String, String>? requestedHeaders;
  Map<String, dynamic>? requestBody;

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
    requestBody = jsonDecode(body) as Map<String, dynamic>;
    return response;
  }
}
