enum Format {
  image,
  archive,
  epub,
  pdf,
  unknown
  ;

  factory Format.fromDtoFormat(int value) {
    return switch (value) {
      0 => .image,
      1 => Format.archive,
      3 => Format.epub,
      4 => Format.pdf,
      _ => Format.unknown,
    };
  }
}
