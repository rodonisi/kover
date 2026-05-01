import 'package:kover/api/openapi.swagger.dart';

enum Format {
  image,
  archive,
  epub,
  pdf,
  unknown
  ;

  factory Format.fromDtoFormat(MangaFormat value) {
    return switch (value) {
      .image => .image,
      .archive => .archive,
      .epub => .epub,
      .pdf => .pdf,
      _ => .unknown,
    };
  }
}
