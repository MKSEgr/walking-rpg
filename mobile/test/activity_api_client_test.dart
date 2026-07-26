import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/activity/data/activity_api_client.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

void main() {
  test(
    'client sends authoritative reading and maps successful response',
    () async {
      final _FakeTransport transport = _FakeTransport(
        HomeTransportResponse(
          statusCode: 200,
          body: jsonEncode(_successResponse()),
        ),
      );
      final ActivityApiClient client = ActivityApiClient(
        baseUri: Uri.parse('http://localhost:8080'),
        userId: 'user-1',
        deviceId: 'device-1',
        transport: transport,
      );

      final ActivitySyncResult result = await client.sync(
        reading: StepReading(
          authoritativeTotal: 6842,
          localDate: DateTime(2026, 7, 26),
          timeZone: 'Europe/Berlin',
          syncCursor: 'cursor-1',
        ),
        idempotencyKey: 'sync-1',
      );

      expect(transport.requestedUri?.path, '/api/v1/activity/sync');
      expect(transport.requestedHeaders?['X-User-Id'], 'user-1');
      expect(transport.requestedHeaders?['X-Device-Id'], 'device-1');
      expect(transport.decodedBody?['localDate'], '2026-07-26');
      expect(transport.decodedBody?['timeZone'], 'Europe/Berlin');
      expect(transport.decodedBody?['authoritativeTotal'], 6842);
      expect(transport.decodedBody?['syncCursor'], 'cursor-1');
      expect(transport.decodedBody?['idempotencyKey'], 'sync-1');
      expect(transport.decodedBody?['buckets'], isEmpty);
      expect(transport.decodedBody?['attestation'], isNull);
      expect(result.energyGranted, 68);
      expect(result.energyBalanceAfter, 68);
    },
  );

  test('client exposes stable backend error', () async {
    final ActivityApiClient client = ActivityApiClient(
      baseUri: Uri.parse('http://localhost:8080'),
      userId: 'user-1',
      deviceId: 'device-1',
      transport: _FakeTransport(
        HomeTransportResponse(
          statusCode: 409,
          body: jsonEncode(<String, dynamic>{
            'code': 'IDEMPOTENCY_CONFLICT',
            'message': 'Ключ уже использован',
          }),
        ),
      ),
    );

    await expectLater(
      client.sync(
        reading: StepReading(
          authoritativeTotal: 100,
          localDate: DateTime(2026, 7, 26),
          timeZone: 'UTC',
        ),
        idempotencyKey: 'sync-1',
      ),
      throwsA(
        isA<ActivityApiException>()
            .having(
              (ActivityApiException error) => error.code,
              'code',
              'IDEMPOTENCY_CONFLICT',
            )
            .having(
              (ActivityApiException error) => error.message,
              'message',
              'Ключ уже использован',
            ),
      ),
    );
  });
}

Map<String, dynamic> _successResponse() {
  return <String, dynamic>{
    'acceptedTotal': 6842,
    'acceptedDelta': 6842,
    'energyGranted': 68,
    'energyBalanceAfter': 68,
    'economyVersion': 1,
    'riskStatus': 'ACCEPTED',
    'stateVersion': 1,
    'serverTime': '2026-07-26T07:00:00Z',
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
