class CancellationException implements Exception {
  @override
  String toString() => 'Operation was cancelled.';
}

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void throwIfCancelled() {
    if (_isCancelled) {
      throw CancellationException();
    }
  }

  void cancel() {
    _isCancelled = true;
  }
}
