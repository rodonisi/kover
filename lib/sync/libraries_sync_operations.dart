import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/database/app_database.dart';
import 'package:kover/mapping/dto/library_dto_mappings.dart';
import 'package:kover/mapping/dto/sidenav_dto_mappings.dart';

class LibrariesSyncOperations {
  final Openapi _client;
  const LibrariesSyncOperations(this._client);

  /// Fetch all libraries
  Future<Iterable<LibrariesCompanion>> getLibraries() async {
    final res = await _client.apiLibraryLibrariesGet();

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load libraries: ${res.error}');
    }

    return res.body!.map((dto) => dto.toLibrariesCompanion());
  }

  Future<Iterable<SidenavCompanion>> getSidenav() async {
    final res = await _client.apiStreamSidenavGet();

    if (!res.isSuccessful || res.body == null) {
      throw Exception('Failed to load sidenav: ${res.error}');
    }

    return res.body!.map((dto) => dto.toSidenavCompanion());
  }
}
