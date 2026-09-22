import 'package:freezed_annotation/freezed_annotation.dart';

part 'semantic_version.freezed.dart';

@freezed
class SemanticVersion({
  required final int major,
  required final int minor,
  required final int patch,
}) with _$SemanticVersion;
