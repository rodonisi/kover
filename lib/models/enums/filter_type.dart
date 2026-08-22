import 'package:kover/api/openapi.enums.swagger.dart';

enum FilterType {
  unknown,
  series,
  readingList,
  person,
  annotation;

  factory fromDtoFilterType(FilterEntityType value) {
    return switch (value) {
      .series => .series,
      .readinglist => .readingList,
      .person => .person,
      .annotation => .annotation,
      _ => .unknown,
    };
  }
}
