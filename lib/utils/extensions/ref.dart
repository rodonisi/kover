import 'package:flutter_riverpod/flutter_riverpod.dart';

extension RefExtension on Ref {
  /// Keep the provider alive for the duration of the [operation] function.
  T withKeepAlive<T>(T Function() operation) {
    final link = keepAlive();
    try {
      return operation();
    } finally {
      link.close();
    }
  }
}
