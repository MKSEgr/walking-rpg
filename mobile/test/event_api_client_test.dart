import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/event/data/event_api_client.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

void main() {
  test('client sends event choice and maps persistent rewards', () async {
    final _FakeTransport transport = _FakeTransport(
      HomeTransportResponse(statusCode: 200, body: jsonEncode(_response())),
    );
    final EventApiClient client = EventApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: transport,
    );

    final EventResolutionResult result = await client.resolve(
      eventId: 'signal-source-v1',
      choiceId: 'analyze-signal',
      idempotencyKey: 'resolve-1',
    );

    expect(
      transport.requestedUri?.path,
      '/api/v1/events/signal-source-v1/resolve',
    );
    expect(transport.requestedHeaders?['X-User-Id'], 'user-1');
    expect(transport.decodedBody?['choiceId'], 'analyze-signal');
    expect(transport.decodedBody?['idempotencyKey'], 'resolve-1');
    expect(result.status, 'RESOLVED');
    expect(result.pilot.currentExperience, 60);
    expect(result.pet.bond, 15);
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

Map<String, dynamic> _response() {
  return <String, dynamic>{
    'contentVersion': 'starter-v1',
    'expeditionId': 'starter-expedition-v1',
    'expeditionStatus': 'COMPLETED',
    'expeditionVersion': 2,
    'eventId': 'signal-source-v1',
    'eventTitle': 'Источник сигнала',
    'status': 'RESOLVED',
    'choiceId': 'analyze-signal',
    'choiceTitle': 'Проанализировать сигнал',
    'outcomeTitle': 'Карта импульсов',
    'outcomeSummary': 'Навигатор выделил безопасный ритм доступа.',
    'pilot': <String, dynamic>{
      'pilotId': 'navigator-v1',
      'name': 'Навигатор',
      'level': 1,
      'experienceGained': 40,
      'currentExperience': 60,
      'nextLevelExperience': 100,
      'version': 1,
    },
    'pet': <String, dynamic>{
      'petId': 'spark-v1',
      'name': 'Искра',
      'level': 1,
      'bondGained': 5,
      'bond': 15,
      'version': 1,
    },
    'serverTime': '2026-07-26T06:00:00Z',
  };
}

class _FakeTransport implements HomeTransport {
  _FakeTransport(this.response);

  final HomeTransportResponse response;
  Uri? requestedUri;
  Map<String, String>? requestedHeaders;
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
    decodedBody = jsonDecode(body) as Map<String, dynamic>;
    return response;
  }
}
