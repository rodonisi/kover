import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:html/dom.dart';
import 'package:kover/utils/converters/document_fragment_converter.dart';
import 'package:kover/utils/converters/uint8list_converter.dart';

part 'page_content.freezed.dart';
part 'page_content.g.dart';

@freezed
sealed class PageContent with _$PageContent {
  const PageContent._();

  const factory PageContent({
    @DocumentFragmentConverter() required DocumentFragment root,
    required Map<String, Map<String, String>> styles,
    @Uint8ListConverter() required Map<String, List<Uint8List>> fonts,
  }) = _PageContent;

  factory PageContent.fromJson(Map<String, dynamic> json) =>
      _$PageContentFromJson(json);
}
