import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navbar.freezed.dart';
part 'navbar.g.dart';

enum NavbarDestinations {
  home(0),
  allSeries(1),
  wantToRead(2),
  collections(3),
  readingLists(4);

  const NavbarDestinations(this.value);

  final int value;
}

@freezed
sealed class NavbarState with _$NavbarState {
  const factory NavbarState({
    @Default(<NavbarDestinations>[.home, .wantToRead])
    List<NavbarDestinations> destinations,
  }) = _NavbarState;

  factory NavbarState.fromJson(Map<String, dynamic> json) =>
      _$NavbarStateFromJson(json);
}

@riverpod
@JsonPersist()
class Navbar extends _$Navbar {
  @override
  Future<NavbarState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;
    return state.value ?? const NavbarState();
  }

  Future<void> setDestinations({
    required List<NavbarDestinations> destinations,
  }) async {
    final current = await future;
    state = AsyncData(
      current.copyWith(
        destinations: destinations,
      ),
    );
    log.info(
      'set navbar destinations',
      attributes: {'destinations': .string(destinations.toString())},
    );
  }

  Future<void> resetDestinations() async {
    state = const AsyncData(NavbarState());
    log.info('reset navbar destinations');
  }
}
