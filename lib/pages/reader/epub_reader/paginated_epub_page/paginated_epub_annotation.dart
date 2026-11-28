import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:material_ui/material_ui.dart';

part 'paginated_epub_annotation.freezed.dart';

@freezed
class PaginatedEpubAnnotation({
  required final int id,
  final int? serverId,
  required final String xpath,
  required final String endXpath,
  required final String selectedText,
  required final Color color,
}) with _$PaginatedEpubAnnotation;
