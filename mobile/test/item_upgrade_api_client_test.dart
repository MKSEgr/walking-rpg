import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/item_upgrade/data/item_upgrade_api_client.dart';
import 'package:walking_rpg_mobile/features/item_upgrade/domain/item_upgrade_result.dart';

import 'support/in_memory_read_snapshot_cache.dart';

void main() {
  test('client posts item upgrade and invalidates read cache', () async {
    final _FakeTransport transport = _FakeTransport(
      HomeTransportResponse(
        statusCode: 200,
        body: jsonEncode(_upgradeResponse()),
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
    final ItemUpgradeApiClient client = ItemUpgradeApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: transport,
      cache: cache,
    );

    final ItemUpgradeResult result = await client.apply(
      upgradeId: 'prism-sextant-calibration-v1',
      idempotencyKey: 'upgrade-1',
    );

    expect(
      transport.requestedUri?.path,
      '/api/v1/item-upgrades/prism-sextant-calibration-v1/apply',
    );
    expect(transport.requestedHeaders?.containsKey('X-User-Id'), isFalse);
    expect(transport.requestBody, <String, dynamic>{
      'idempotencyKey': 'upgrade-1',
    });
    expect(result.upgradedItem.itemId, 'prism-sextant');
    expect(result.upgradedItem.upgradeLevel, 2);
    expect(result.upgradedItem.rarity, 'RARE');
    expect(result.consumedIngredients, hasLength(3));
    expect(cache.invalidations, 1);
  });

  test('client exposes stable item upgrade error', () async {
    final ItemUpgradeApiClient client = ItemUpgradeApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakeTransport(
        HomeTransportResponse(
          statusCode: 409,
          body: jsonEncode(<String, dynamic>{
            'code': 'ITEM_UPGRADE_STATE_CONFLICT',
            'message': 'Улучшение недоступно',
          }),
        ),
      ),
    );

    await expectLater(
      client.apply(
        upgradeId: 'prism-sextant-calibration-v1',
        idempotencyKey: 'upgrade-1',
      ),
      throwsA(
        isA<ItemUpgradeApiException>()
            .having(
              (ItemUpgradeApiException error) => error.statusCode,
              'statusCode',
              409,
            )
            .having(
              (ItemUpgradeApiException error) => error.code,
              'code',
              'ITEM_UPGRADE_STATE_CONFLICT',
            ),
      ),
    );
  });
}

Map<String, dynamic> _upgradeResponse() {
  return <String, dynamic>{
    'contentVersion': 'item-upgrade-v1',
    'upgradeId': 'prism-sextant-calibration-v1',
    'upgradeVersion': '1',
    'upgradeName': 'Откалибровать призматический секстант',
    'consumedIngredients': <Map<String, dynamic>>[
      <String, dynamic>{
        'itemId': 'echo-thread',
        'name': 'Нить эха',
        'quantityConsumed': 2,
        'quantityAfter': 0,
        'version': 2,
      },
      <String, dynamic>{
        'itemId': 'ion-bloom',
        'name': 'Ионный цветок',
        'quantityConsumed': 1,
        'quantityAfter': 0,
        'version': 2,
      },
      <String, dynamic>{
        'itemId': 'prism-dust',
        'name': 'Призматическая пыль',
        'quantityConsumed': 1,
        'quantityAfter': 0,
        'version': 2,
      },
    ],
    'upgradedItem': <String, dynamic>{
      'itemInstanceId': '11111111-2222-3333-4444-555555555555',
      'itemId': 'prism-sextant',
      'name': 'Призматический секстант',
      'description': 'Уникальный прибор.',
      'previousLevel': 1,
      'upgradeLevel': 2,
      'rarity': 'RARE',
      'upgradedAt': '2026-08-15T08:00:00Z',
    },
    'serverTime': '2026-08-15T08:00:00Z',
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
