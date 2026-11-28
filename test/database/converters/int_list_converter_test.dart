import 'package:flutter_test/flutter_test.dart';
import 'package:kover/database/converters/int_list_converter.dart';

void main() {
  const converter = IntListConverter();

  test('round trips integer lists', () {
    const values = [1, 2, 3];

    expect(converter.fromSql(converter.toSql(values)), values);
  });

  test('round trips an empty list', () {
    expect(converter.fromSql(converter.toSql([])), isEmpty);
  });

  test('converts decimal JSON numbers to integers', () {
    expect(converter.fromSql('[1.9, -2.1]'), [1, -2]);
  });

  test('rejects malformed JSON', () {
    expect(() => converter.fromSql('['), throwsFormatException);
  });

  test('rejects non-array JSON', () {
    expect(
      () => converter.fromSql('{"value": 1}'),
      throwsFormatException,
    );
  });

  test('rejects non-numeric elements', () {
    expect(
      () => converter.fromSql('[1, "2"]'),
      throwsFormatException,
    );
  });
}
