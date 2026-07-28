abstract interface class AuthAccessTokenProvider {
  Future<String> accessToken();

  Future<String> refreshAfterUnauthorized(String rejectedAccessToken);

  void rejectSession(String reason, {String? rejectedAccessToken});
}
