extension IterableExtension<T> on Iterable<T> {
  Iterable<T> interleave(T separator) sync* {
    final it = iterator;
    if (!it.moveNext()) return;

    yield it.current;
    while (it.moveNext()) {
      yield separator;
      yield it.current;
    }
  }

  /// Splits the iterable into chunks of the given size.
  /// If the iterable's length is not divisible by the chunk size, the last
  /// chunk will contain  the remaining elements.
  /// If the iterable is empty, an empty iterable is returned.
  Iterable<Iterable<T>> chunked(int chuckSize) {
    final result = <Iterable<T>>[];
    for (var i = 0; i < length; i += chuckSize) {
      result.add(skip(i).take(chuckSize));
    }

    return result;
  }
}
