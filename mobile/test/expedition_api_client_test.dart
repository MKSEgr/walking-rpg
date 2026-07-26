import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/expedition/data/expedition_api_client.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

void main() {
  test('client posts advance command and maps event response', () async {
    final _FakeTransport transport = _FakeTransport(
      HomeTransportResponse(
        statusCode: 200,
        body: jsonEncode(_advanceResponse()),
      ),
    );
    final ExpeditionApiClient client = ExpeditionApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: transport,
    );

    final ExpeditionAdvanceResult result = await client.advance(
      expeditionId: 'starter-expedition-v1',
      energyToSpend: 30,
      idempotencyKey: 'advance-1',
    );

    expect(
      transport.requestedUri?.path,
      '/api/v1/expeditions/starter-expedition-v1/advance',
    );
    expect(transport.requestedHeaders?['X-User-Id'], 'user-1');
    expect(transport.requestBody?['energyToSpend'], 30);
    expect(transport.requestBody?['idempotencyKey'], 'advance-1');
    expect(result.energyBalanceAfter, 38);
    expect(result.status, 'EVENT_READY');
    expect(result.unlockedEvent?.eventId, 'signal-source-v1');
  });

  test('client exposes stable backend error', () async {
    final ExpeditionApiClient client = ExpeditionApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakeTransport(
        HomeTransportResponse(
          statusCode: 409,
          body: jsonEncode(<String, dynamic>{
            'code': 'INSUFFICIENT_ENERGY',
            'message': 'Недостаточно энергии для операции',
          }),
        ),
      ),
    );

    await expectLater(
      client.advance(
        expeditionId: 'starter-expedition-v1',
        energyToSpend: 30,
        idempotencyKey: 'advance-1',
      ),
      throwsA(
        isA<ExpeditionApiException>()
            .having(
              (ExpeditionApiException error) => error.code,
              'code',
              'INSUFFICIENT_ENERGY',
            )
            .having(
              (ExpeditionApiException error) => error.statusCode,
              'statusCode',
              409,
            ),
      ),
    );
  });
}

Map<String, dynamic> _advanceResponse() {
  return <String, dynamic>{
    'contentVersion': 'starter-v1',
    'expeditionId': 'starter-expedition-v1',
    'expeditionName': 'Сигнал из туманного сектора',
    'energySpent': 30,
    'energyBalanceAfter': 38,
    'economyVersion': 2,
    'progressAfter': 30,
    'requiredEnergy': 30,
    'expeditionVersion': 1,
    'status': 'EVENT_READY',
    'currentNodeId': 'outer-beacon',
    'currentNodeName': 'Внешний маяк',
    'unlockedEvent': <String, dynamic>{
      'eventId': 'signal-source-v1',
      'title': 'Источник сигнала',
      'summary': 'Маяк отвечает импульсом.',
      'status': 'READY',
    },
    'serverTime': '2026-07-25T12:00:00Z',
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
