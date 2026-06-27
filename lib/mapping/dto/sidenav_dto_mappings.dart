import 'package:drift/drift.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/models/enums/sidenav_stream_type.dart';

extension SidenavStreamDtoMappings on SideNavStreamDto {
  SidenavCompanion toSidenavCompanion() {
    return SidenavCompanion.insert(
      id: Value(id!),
      name: Value.absentIfNull(name),
      order: order!,
      visible: visible!,
      streamType: _toSidenavStreamType(),
      libraryId: Value.absentIfNull(libraryId),
    );
  }

  SidenavStreamType _toSidenavStreamType() {
    return switch (streamType) {
      .collections => .collections,
      .$library => .library,
      .readinglists => .readingLists,
      .bookmarks => .bookmarks,
      .smartfilter => .smartFilter,
      .externalsource => .externalSource,
      .allseries => .allSeries,
      .wanttoread => .wantToRead,
      .browsepeople => .browsePeople,
      _ => throw Exception('Unknown stream type: $streamType'),
    };
  }
}
