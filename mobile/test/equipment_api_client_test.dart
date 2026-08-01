import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/features/equipment/data/equipment_api_client.dart';
import 'package:walking_rpg_mobile/features/equipment/domain/equipment_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

import 'support/in_memory_read_snapshot_cache.dart';

void main() {
  test('client posts equip command and invalidates read cache', () async {
    final _FakeTransport transport = _FakeTransport(
      HomeTransportResponse(
        statusCode: 200,
        body: jsonEncode(_equipmentResponse()),
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
    final EquipmentApiClient client = EquipmentApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: transport,
      cache: cache,
    );

    final EquipmentResult result = await client.change(
      slotId: 'NAVIGATION',
      action: 'EQUIP',
      itemInstanceId: '11111111-2222-3333-4444-555555555555',
      idempotencyKey: 'equip-1',
    );

    expect(
      transport.requestedUri?.path,
      '/api/v1/equipment/slots/NAVIGATION/equip',
    );
    expect(transport.requestedHeaders?.containsKey('X-User-Id'), isFalse);
    expect(transport.requestBody, <String, dynamic>{
      'itemInstanceId': '11111111-2222-3333-4444-555555555555',
      'idempotencyKey': 'equip-1',
    });
    expect(result.equippedItem?.itemId, 'resonance-compass');
    expect(cache.invalidations, 1);
  });

  test('client omits itemInstanceId for unequip', () async {
    final _FakeTransport transport = _FakeTransport(
      HomeTransportResponse(
        statusCode: 200,
        body: jsonEncode(<String, dynamic>{
          ..._equipmentResponse(),
          'action': 'UNEQUIP',
          'changed': true,
          'version': 2,
          'equippedItem': null,
        }),
      ),
    );
    final EquipmentApiClient client = EquipmentApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: transport,
    );

    await client.change(
      slotId: 'NAVIGATION',
      action: 'UNEQUIP',
      itemInstanceId: null,
      idempotencyKey: 'unequip-1',
    );

    expect(
      transport.requestedUri?.path,
      '/api/v1/equipment/slots/NAVIGATION/unequip',
    );
    expect(transport.requestBody, <String, dynamic>{
      'idempotencyKey': 'unequip-1',
    });
  });

  test('client exposes stable equipment error', () async {
    final EquipmentApiClient client = EquipmentApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakeTransport(
        HomeTransportResponse(
          statusCode: 409,
          body: jsonEncode(<String, dynamic>{
            'code': 'EQUIPMENT_ITEM_UNAVAILABLE',
            'message': 'Предмет недоступен',
          }),
        ),
      ),
    );

    await expectLater(
      client.change(
        slotId: 'NAVIGATION',
        action: 'EQUIP',
        itemInstanceId: '11111111-2222-3333-4444-555555555555',
        idempotencyKey: 'equip-1',
      ),
      throwsA(
        isA<EquipmentApiException>()
            .having(
              (EquipmentApiException error) => error.statusCode,
              'statusCode',
              409,
            )
            .having(
              (EquipmentApiException error) => error.code,
              'code',
              'EQUIPMENT_ITEM_UNAVAILABLE',
            ),
      ),
    );
  });
}

Map<String, dynamic> _equipmentResponse() {
  return <String, dynamic>{
    'contentVersion': 'equipment-v1',
    'slotId': 'NAVIGATION',
    'slotName': 'Навигационный прибор',
    'slotDescription': 'Один уникальный инструмент.',
    'action': 'EQUIP',
    'changed': true,
    'version': 1,
    'equippedItem': <String, dynamic>{
      'itemInstanceId': '11111111-2222-3333-4444-555555555555',
      'itemId': 'resonance-compass',
      'name': 'Резонансный компас',
      'description': 'Уникальный прибор.',
      'equippedAt': '2026-08-01T12:00:00Z',
    },
    'serverTime': '2026-08-01T12:00:00Z',
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
