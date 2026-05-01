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
}
