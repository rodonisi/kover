import 'package:kover/models/image_model.dart';
import 'package:kover/models/volume_model.dart';
import 'package:kover/riverpod/repository/volumes_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'volume.g.dart';

@riverpod
Stream<VolumeModel> volume(Ref ref, {required int volumeId}) {
  final repo = ref.watch(volumesRepositoryProvider);
  return repo.watchVolume(volumeId).distinct();
}

@riverpod
Future<List<VolumeModel>> searchVolumes(
  Ref ref,
  String query, {
  int? seriesId,
}) {
  final repo = ref.watch(volumesRepositoryProvider);
  return repo.searchVolumes(
    query,
    seriesId: seriesId,
  );
}

@riverpod
Stream<double> volumeProgress(Ref ref, {required int volumeId}) {
  final repo = ref.watch(volumesRepositoryProvider);
  final volume = repo.watchVolume(volumeId);
  final pagesRead = repo.watchPagesRead(volumeId: volumeId);

  return Rx.combineLatest2(volume, pagesRead, (v, n) => n / v.pages).distinct();
}

@riverpod
Stream<ImageModel?> volumeCover(Ref ref, {required int volumeId}) {
  final repo = ref.watch(volumesRepositoryProvider);
  return repo.watchVolumeCover(volumeId).distinct();
}
