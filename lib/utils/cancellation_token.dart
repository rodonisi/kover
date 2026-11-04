import 'dart:async';

class CancellationException implements Exception {
  @override
  String toString() => 'Operation was cancelled.';
}

class CancellationToken {
  final _completer = Completer<void>();
  bool get isCancelled => _completer.isCompleted;
  Future<void> get onCancel => _completer.future;

  void throwIfCancelled() {
    if (isCancelled) {
      throw CancellationException();
    }
  }

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
