import 'package:flutter_test/flutter_test.dart';
import 'package:kover/models/semantic_version.dart';
import 'package:kover/utils/constants/kavita_version.dart';

void main() {
  group('kavitaSemanticVersion', () {
    test('returns SemanticVersion for a full version', () {
      expect(
        kavitaSemanticVersion('0.9.1.4'),
        equals(SemanticVersion(major: 0, minor: 9, patch: 1)),
      );
    });

    test('returns SemanticVersion for a semantic version', () {
      expect(
        kavitaSemanticVersion('0.9.1'),
        equals(SemanticVersion(major: 0, minor: 9, patch: 1)),
      );
    });

    test('ignores a leading v prefix', () {
      expect(
        kavitaSemanticVersion('v0.9.1.0'),
        equals(SemanticVersion(major: 0, minor: 9, patch: 1)),
      );
    });

    test('returns null for null input', () {
      expect(kavitaSemanticVersion(null), isNull);
    });

    test('returns null when a part is not a number', () {
      expect(kavitaSemanticVersion('0.x.1.0'), isNull);
    });

    test('returns null for a single part version', () {
      expect(kavitaSemanticVersion('0'), isNull);
    });
  });

  group('isSupportedKavitaVersion', () {
    final supportedKavitaVersion = '0.9.1';

    test('matches the supported version', () {
      expect(
        isSupportedKavitaVersion(
          supportedKavitaVersion,
          supportedKavitaVersion: supportedKavitaVersion,
        ),
        isTrue,
      );
    });

    test('matches a different build', () {
      expect(
        isSupportedKavitaVersion(
          '0.9.1.4',
          supportedKavitaVersion: supportedKavitaVersion,
        ),
        isTrue,
      );
    });

    test('does not match a different patch', () {
      expect(
        isSupportedKavitaVersion(
          '0.9.5.0',
          supportedKavitaVersion: supportedKavitaVersion,
        ),
        isFalse,
      );
    });

    test('does not match a different minor', () {
      expect(
        isSupportedKavitaVersion(
          '0.10.0.0',
          supportedKavitaVersion: supportedKavitaVersion,
        ),
        isFalse,
      );
    });

    test('does not match a different major', () {
      expect(
        isSupportedKavitaVersion(
          '1.0.0.0',
          supportedKavitaVersion: supportedKavitaVersion,
        ),
        isFalse,
      );
    });

    test('treats null as supported', () {
      expect(
        isSupportedKavitaVersion(
          null,
          supportedKavitaVersion: supportedKavitaVersion,
        ),
        isTrue,
      );
    });

    test('treats an unparseable version as supported', () {
      expect(
        isSupportedKavitaVersion(
          'not-a-version',
          supportedKavitaVersion: supportedKavitaVersion,
        ),
        isTrue,
      );
    });
  });
}
