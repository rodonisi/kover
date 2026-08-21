import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:html/dom.dart';
import 'package:kover/models/font_face.dart';
import 'package:kover/utils/converters/document_fragment_converter.dart';

part 'page_content.freezed.dart';
part 'page_content.g.dart';

@freezed
sealed class PageContent with _$PageContent {
  const PageContent._();

  const factory PageContent({
    @DocumentFragmentConverter() required DocumentFragment root,
    required Map<String, Map<String, String>> styles,
    required List<FontFace> fonts,
  }) = _PageContent;

  factory PageContent.fromJson(Map<String, dynamic> json) =>
      _$PageContentFromJson(json);
}
