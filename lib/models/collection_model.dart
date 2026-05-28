import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kover/database/app_database.dart';

part 'collection_model.freezed.dart';
part 'collection_model.g.dart';

@freezed
sealed class CollectionModel with _$CollectionModel {
  const factory CollectionModel({
    required int id,
    required String title,
    required String? summary,
  }) = _CollectionModel;

  factory CollectionModel.fromJson(Map<String, dynamic> json) =>
      _$CollectionModelFromJson(json);

  factory CollectionModel.fromDatabaseModel(Collection collection) {
    return CollectionModel(
      id: collection.id,
      title: collection.title,
      summary: collection.summary,
    );
  }
}
