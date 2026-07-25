abstract interface class HomeTransport {
  Future<HomeTransportResponse> get({
    required Uri uri,
    required Map<String, String> headers,
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
