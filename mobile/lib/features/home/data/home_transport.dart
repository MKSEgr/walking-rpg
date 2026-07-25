abstract interface class HomeTransport {
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
  });

  Future<HomeTransportResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  });
}

class HomeTransportResponse {
  const HomeTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}
