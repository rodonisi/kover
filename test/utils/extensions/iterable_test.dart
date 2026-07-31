import 'package:flutter_test/flutter_test.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/utils/extensions/iterable.dart';

void main() {
  group('chunked', () {
    test('when empty iterable, then return empty list', () {
      final iterable = <int>[];
      final result = iterable.chunked(3);
      expect(result, isEmpty);
    });

    test(
      'when smaller than chunk size, then returns whole list in first chunk',
      () {
        final iterable = [1, 2];
        final expected = [
          [1, 2],
        ];
        final result = iterable.chunked(3);
        expect(const DeepCollectionEquality().equals(result, expected), isTrue);
      },
    );

    test('when bigger than chunk size, then should return split list', () {
      final iterable = [1, 2, 3, 4];
      final expected = [
        [1, 2],
        [3, 4],
      ];
      final result = iterable.chunked(2);
      expect(const DeepCollectionEquality().equals(result, expected), isTrue);
    });

    test(
      'when length is not divisible by chunk size, then no elements are lost',
      () {
        final iterable = [1, 2, 3, 4, 5];
        final expected = [
          [1, 2],
          [3, 4],
          [5],
        ];
        final result = iterable.chunked(2);
        expect(const DeepCollectionEquality().equals(result, expected), isTrue);
      },
    );
  });
}
