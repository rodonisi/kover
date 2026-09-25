import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:kover/utils/locale_tag.dart';
import 'package:kover/utils/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'general_settings.freezed.dart';
part 'general_settings.g.dart';

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
sealed class GeneralSettingsState with _$GeneralSettingsState {
  const GeneralSettingsState._();

  const factory GeneralSettingsState({
    @Default(false) bool sendDiagnostics,
    @Default(null) String? localeString,
    @Default(null) TextDirection? textDirection,
    @Default(<NavbarDestinations>[.home, .wantToRead])
    List<NavbarDestinations> navbarDestinations,
  }) = _GeneralSettingsState;

  factory GeneralSettingsState.fromJson(Map<String, Object?> json) =>
      _$GeneralSettingsStateFromJson(json);

  /// [localeString] holds a full locale tag, e.g. `en`, `pt-BR`.
  ///
  /// Null when unset or when the stored tag cannot be parsed, which leaves the
  /// locale to the platform.
  Locale? get locale {
    final tag = localeString;
    if (tag == null || tag.isEmpty) {
      return null;
    }

    return parseLocale(tag);
  }
}

@riverpod
@JsonPersist()
class GeneralSettings extends _$GeneralSettings {
  @override
  Future<GeneralSettingsState> build() async {
    await persist(
      ref.watch(storageProvider.future),
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    ).future;

    return state.value ?? const GeneralSettingsState();
  }

  Future<void> setSendDiagnostics(bool value) async {
    final current = await future;
    log.info('set send diagnostics', attributes: {'value': value});
    state = AsyncData(current.copyWith(sendDiagnostics: value));
  }

  Future<void> setLocale(Locale? value) async {
    final current = await future;
    log.info(
      'set locale',
      attributes: {'value': value?.toLanguageTag()},
    );
    state = AsyncData(current.copyWith(localeString: value?.toLanguageTag()));
  }

  Future<void> setTextDirection(TextDirection? value) async {
    final current = await future;
    log.info(
      'set text direction',
      attributes: {'value': value?.toString() ?? 'null'},
    );
    state = AsyncData(current.copyWith(textDirection: value));
  }

  Future<void> setNavbarDestinations(List<NavbarDestinations> value) async {
    final current = await future;
    log.info(
      'set navbar destinations',
      attributes: {'value': value.map((e) => e.name)},
    );
    state = AsyncData(current.copyWith(navbarDestinations: value));
  }

  Future<void> resetNavbarDestinations() async {
    final current = await future;
    log.info('reset navbar destinations');
    state = AsyncData(
      current.copyWith(
        navbarDestinations: const <NavbarDestinations>[.home, .wantToRead],
      ),
    );
  }
}
