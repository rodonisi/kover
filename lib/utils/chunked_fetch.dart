import 'package:kover/utils/extensions/iterable.dart';
import 'package:pool/pool.dart';

Future<void> chunkedFetch<T, R>({
  required Iterable<T> items,
  required Future<R> Function(T item) fetchCallback,
  required Future<void> Function(Iterable<R> items) upsertCallback,
  int chunkSize = 10,
  int poolSize = 5,
}) async {
  final pool = Pool(poolSize);

  for (final chunk in items.chunked(chunkSize)) {
    final batch = await Future.wait(
      chunk.map(
        (item) => pool.withResource(() => fetchCallback(item)),
      ),
    );
    await upsertCallback(batch);
  }
}
