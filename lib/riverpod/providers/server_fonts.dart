import 'package:flutter/foundation.dart';
import 'package:kover/riverpod/repository/server_fonts_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_fonts.g.dart';

@riverpod
Stream<List<String>> serverFontFamilies(Ref ref) {
  final repository = ref.watch(serverFontsRepositoryProvider);
  return repository.watchServerFontFamilies().distinct(listEquals);
}
