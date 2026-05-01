import 'package:kover/api/openapi.swagger.dart' as api;

enum LibraryType {
  unknown,
  book,
  comic,
  comicLegacy,
  image,
  lightNovel,
  manga
  ;

  factory LibraryType.fromDtoType(api.LibraryType type) => switch (type) {
    .manga => .manga,
    .comic => .comic,
    .book => .book,
    .image => .image,
    .lightnovel => .lightNovel,
    .comicvine => .comicLegacy,
    _ => .unknown,
  };
}
