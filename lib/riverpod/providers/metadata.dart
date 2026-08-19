import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/models/enums/publication_status.dart';
import 'package:kover/models/series_model.dart';
import 'package:kover/riverpod/providers/chapter.dart';
import 'package:kover/riverpod/providers/series.dart';
import 'package:kover/riverpod/providers/volume.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'metadata.freezed.dart';
part 'metadata.g.dart';

abstract interface class MetadataViewModel {
  String? get summary;
  int? get releaseYear;
  PublicationStatus get publicationStatus;
  List<GenreModel> get genres;
  List<TagModel> get tags;
  List<PersonModel> get writers;
  List<PersonModel> get coverArtists;
  List<PersonModel> get publishers;
  List<PersonModel> get characters;
  List<PersonModel> get pencillers;
  List<PersonModel> get inkers;
  List<PersonModel> get imprints;
  List<PersonModel> get colorists;
  List<PersonModel> get letterers;
  List<PersonModel> get editors;
  List<PersonModel> get translators;
  List<PersonModel> get teams;
  List<PersonModel> get locations;
}

@freezed
sealed class MetadataId with _$MetadataId {
  const factory MetadataId.series({required int seriesId}) = _SeriesId;
  const factory MetadataId.volume({required int volumeId}) = _VolumeId;
  const factory MetadataId.chapter({required int chapterId}) = _ChapterId;
}

@riverpod
Future<MetadataViewModel?> metadata(
  Ref ref, {
  required MetadataId metadataId,
}) async {
  return await metadataId.when(
    series: (seriesId) async {
      return await ref.watch(seriesMetadataProvider(seriesId: seriesId).future);
    },
    volume: (volumeId) async {
      final volume = await ref.watch(volumeProvider(volumeId: volumeId).future);

      if (volume.chapters.isNotEmpty) {
        return null;
      }

      final firstChapter = await ref.watch(
        chapterMetadataProvider(chapterId: volume.chapters.first.id).future,
      );

      return firstChapter;
    },
    chapter: (chapterId) async {
      return await ref.watch(
        chapterMetadataProvider(chapterId: chapterId).future,
      );
    },
  );
}
