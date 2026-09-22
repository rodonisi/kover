import 'package:kover/models/semantic_version.dart';

/// The Kavita version the bundled OpenAPI client was generated against.
const String supportedKavitaVersion = '0.9.1';

/// Returns [SemanticVersion] for a Kavita [version], or `null` when it cannot
/// be parsed.
SemanticVersion? kavitaSemanticVersion(String? version) {
  if (version == null) {
    return null;
  }

  final parts = version.trim().replaceFirst(RegExp('^v'), '').split('.');
  if (parts.length < 3) {
    return null;
  }

  final major = int.tryParse(parts[0]);
  final minor = int.tryParse(parts[1]);
  final patch = int.tryParse(parts[2]);
  if (major == null || minor == null || patch == null) {
    return null;
  }

  return SemanticVersion(major: major, minor: minor, patch: patch);
}

/// Whether [version] shares the same [SemanticVersion] as
/// [supportedKavitaVersion].
///
/// Kavita releases versions by mainly bumping the minor component, which often
/// brings contract changes to the API. Returns `true` when either
/// [SemanticVersion] matches the supported version, or [version] is missing or
/// unparseable, so the warning is only shown for a confirmed mismatch.
bool isSupportedKavitaVersion(
  String? version, {
  String supportedKavitaVersion = supportedKavitaVersion,
}) {
  final actual = kavitaSemanticVersion(version);
  if (actual == null) {
    return true;
  }

  final supported = kavitaSemanticVersion(supportedKavitaVersion);

  return actual == supported;
}
