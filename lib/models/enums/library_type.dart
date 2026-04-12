enum LibraryType {
  unknown,
  book,
  comic,
  comicLegacy,
  image,
  lightNovel,
  manga
  ;

  factory LibraryType.fromDtoType(int type) => switch (type) {
    0 => .manga,
    1 => .comic,
    2 => .book,
    3 => .image,
    4 => .lightNovel,
    5 => .comicLegacy,
    _ => .unknown,
  };
}
