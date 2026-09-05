import 'dart:async';

import 'package:kover/utils/extensions/iterable.dart';

/// Executes an operation on a list of items in chunks of a specified size.
FutureOr<void> chunkedOperation<T>({
  required Iterable<T> items,
  required FutureOr<void> Function(Iterable<T> chunk) operation,
  int chunkSize = 100,
}) async {
  for (final chunk in items.chunked(chunkSize)) {
    await operation(chunk);
  }
}
