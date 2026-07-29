import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/account/data/account_api_client.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

void main() {
  test(
    'exports a pretty JSON document from the authenticated endpoint',
    () async {
      final _FakeAccountTransport transport = _FakeAccountTransport(
        getResponse: const HomeTransportResponse(
          statusCode: 200,
          body: '{"exportedAt":"2026-07-29T05:00:00Z","user":[]}',
        ),
      );
      final AccountApiClient client = AccountApiClient(
        baseUri: Uri.parse('https://api.example'),
        transport: transport,
      );

      final String document = await client.exportAccount();

      expect(jsonDecode(document), <String, Object?>{
        'exportedAt': '2026-07-29T05:00:00Z',
        'user': <Object?>[],
      });
      expect(document, contains('\n  "exportedAt"'));
      expect(transport.lastUri?.path, '/api/v1/account/export');
      expect(transport.lastHeaders?['Accept'], 'application/json');
    },
  );

  test('sends an idempotent confirmed account deletion request', () async {
    final _FakeAccountTransport transport = _FakeAccountTransport(
      postResponse: const HomeTransportResponse(
        statusCode: 200,
        body: '''
          {
            "receiptId": "11111111-1111-1111-1111-111111111111",
            "status": "COMPLETED",
            "requestedAt": "2026-07-29T05:00:00Z",
            "completedAt": "2026-07-29T05:00:00Z",
            "replayed": false
          }
        ''',
      ),
    );
    final AccountApiClient client = AccountApiClient(
      baseUri: Uri.parse('https://api.example'),
      transport: transport,
    );

    final receipt = await client.requestDeletion(
      idempotencyKey: 'delete-request-1',
    );

    expect(receipt.status, 'COMPLETED');
    expect(receipt.replayed, isFalse);
    expect(transport.lastUri?.path, '/api/v1/account/deletion-requests');
    expect(transport.lastHeaders?['Idempotency-Key'], 'delete-request-1');
    expect(jsonDecode(transport.lastBody!), <String, Object?>{
      'confirmation': 'DELETE',
    });
  });

  test('classifies temporary backend failures as retryable', () async {
    final AccountApiClient client = AccountApiClient(
      baseUri: Uri.parse('https://api.example'),
      transport: _FakeAccountTransport(
        postResponse: const HomeTransportResponse(
          statusCode: 503,
          body: '''
            {
              "code": "SERVICE_UNAVAILABLE",
              "message": "maintenance",
              "details": {}
            }
          ''',
        ),
      ),
    );

    await expectLater(
      client.requestDeletion(idempotencyKey: 'delete-request-2'),
      throwsA(
        isA<AccountApiException>()
            .having(
              (AccountApiException error) => error.statusCode,
              'status',
              503,
            )
            .having(
              (AccountApiException error) => error.retryable,
              'retryable',
              true,
            ),
      ),
    );
  });
}

final class _FakeAccountTransport implements HomeTransport {
  _FakeAccountTransport({this.getResponse, this.postResponse});

  final HomeTransportResponse? getResponse;
  final HomeTransportResponse? postResponse;
  Uri? lastUri;
  Map<String, String>? lastHeaders;
  String? lastBody;

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    lastUri = uri;
    lastHeaders = Map<String, String>.of(headers);
    return getResponse ?? (throw StateError('GET response is not configured'));
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    lastUri = uri;
    lastHeaders = Map<String, String>.of(headers);
    lastBody = body;
    return postResponse ??
        (throw StateError('POST response is not configured'));
  }
}
