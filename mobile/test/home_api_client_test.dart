import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';

void main() {
  test('client sends user and local date and maps successful response',
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
    expect(transport.requestedUri?.queryParameters['localDate'], '2026-07-25');
    expect(transport.requestedHeaders?['X-User-Id'], 'user-1');
    expect(snapshot.dailySteps, 6842);
    expect(snapshot.availableEnergy, 68);
  });

  test('client exposes backend error message', () async {
    final HomeApiClient client = HomeApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      transport: _FakeHomeTransport(
        HomeTransportResponse(
          statusCode: 400,
          body: jsonEncode(<String, dynamic>{
            'message': 'Некорректная дата',
          }),
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
}

Map<String, dynamic> _homeResponse() {
  return <String, dynamic>{
    'localDate': '2026-07-25',
    'timeZone': 'Europe/Berlin',
    'dailySteps': 6842,
    'dailyGoal': 6000,
    'availableEnergy': 68,
    'activityStateVersion': 1,
    'economyVersion': 1,
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
      'name': 'Сигнал из туманного сектора',
      'currentNode': 'Внешний маяк',
      'progress': 0,
      'requiredEnergy': 30,
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
}
