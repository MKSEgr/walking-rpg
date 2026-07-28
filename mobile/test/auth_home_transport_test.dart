import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/auth/auth_access_token_provider.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/features/home/data/auth_home_transports.dart';
import 'package:walking_rpg_mobile/features/home/data/home_transport.dart';

void main() {
  test(
    'adds bearer, strips forged identity headers, and retries once',
    () async {
      final _RecordingTransport inner =
          _RecordingTransport(<HomeTransportResponse>[
            const HomeTransportResponse(statusCode: 401, body: 'expired'),
            const HomeTransportResponse(statusCode: 200, body: 'ok'),
          ]);
      final _FakeTokenProvider provider = _FakeTokenProvider();
      final BearerHomeTransport transport = BearerHomeTransport(
        apiBaseUri: Uri.parse('https://api.example/base'),
        inner: inner,
        tokenProvider: provider,
      );

      final HomeTransportResponse response = await transport.post(
        uri: Uri.parse('https://api.example/api/v1/activity/sync'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer forged',
          'X-User-Id': 'victim',
          'X-Device-Id': 'forged-device',
        },
        body: '{"idempotencyKey":"same-key"}',
      );

      expect(response.statusCode, 200);
      expect(inner.requests, hasLength(2));
      expect(inner.requests[0].headers['Authorization'], 'Bearer access-old');
      expect(inner.requests[1].headers['Authorization'], 'Bearer access-new');
      expect(inner.requests[0].headers.keys, isNot(contains('X-User-Id')));
      expect(inner.requests[0].headers.keys, isNot(contains('X-Device-Id')));
      expect(inner.requests[0].body, inner.requests[1].body);
      expect(provider.refreshCalls, 1);
    },
  );

  test('never sends bearer outside configured API origin', () async {
    final _RecordingTransport inner = _RecordingTransport(
      const <HomeTransportResponse>[
        HomeTransportResponse(statusCode: 200, body: 'ok'),
      ],
    );
    final _FakeTokenProvider provider = _FakeTokenProvider();
    final BearerHomeTransport transport = BearerHomeTransport(
      apiBaseUri: Uri.parse('https://api.example'),
      inner: inner,
      tokenProvider: provider,
    );

    await expectLater(
      transport.get(
        uri: Uri.parse('https://evil.example/api/v1/home'),
        headers: const <String, String>{},
      ),
      throwsA(isA<StateError>()),
    );

    expect(inner.requests, isEmpty);
    expect(provider.accessCalls, 0);
  });

  test('second unauthorized response invalidates the session', () async {
    final _RecordingTransport inner =
        _RecordingTransport(const <HomeTransportResponse>[
          HomeTransportResponse(statusCode: 401, body: 'expired'),
          HomeTransportResponse(statusCode: 401, body: 'still expired'),
        ]);
    final _FakeTokenProvider provider = _FakeTokenProvider();
    final BearerHomeTransport transport = BearerHomeTransport(
      apiBaseUri: Uri.parse('https://api.example'),
      inner: inner,
      tokenProvider: provider,
    );

    await expectLater(
      transport.get(
        uri: Uri.parse('https://api.example/api/v1/home'),
        headers: const <String, String>{},
      ),
      throwsA(isA<AuthReauthenticationRequiredException>()),
    );

    expect(provider.rejectionReason, isNotNull);
    expect(provider.rejectedAccessToken, 'access-new');
    expect(inner.requests, hasLength(2));
  });
}

final class _FakeTokenProvider implements AuthAccessTokenProvider {
  int accessCalls = 0;
  int refreshCalls = 0;
  String? rejectionReason;
  String? rejectedAccessToken;

  @override
  Future<String> accessToken() async {
    accessCalls += 1;
    return 'access-old';
  }

  @override
  void rejectSession(String reason, {String? rejectedAccessToken}) {
    rejectionReason = reason;
    this.rejectedAccessToken = rejectedAccessToken;
  }

  @override
  Future<String> refreshAfterUnauthorized(String rejectedAccessToken) async {
    refreshCalls += 1;
    expect(rejectedAccessToken, 'access-old');
    return 'access-new';
  }
}

final class _RecordingTransport implements HomeTransport {
  _RecordingTransport(List<HomeTransportResponse> responses)
    : _responses = <HomeTransportResponse>[...responses];

  final List<HomeTransportResponse> _responses;
  final List<_RecordedRequest> requests = <_RecordedRequest>[];

  @override
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    requests.add(
      _RecordedRequest(uri: uri, headers: Map<String, String>.from(headers)),
    );
    return _responses.removeAt(0);
  }

  @override
  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    requests.add(
      _RecordedRequest(
        uri: uri,
        headers: Map<String, String>.from(headers),
        body: body,
      ),
    );
    return _responses.removeAt(0);
  }
}

final class _RecordedRequest {
  const _RecordedRequest({required this.uri, required this.headers, this.body});

  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}
