import 'dart:async';

final class AsyncLock {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) async {
    final Future<void> previous = _tail;
    final Completer<void> release = Completer<void>();
    _tail = release.future;

    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }
}
