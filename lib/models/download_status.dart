import 'package:freezed_annotation/freezed_annotation.dart';

part 'download_status.freezed.dart';

@freezed
sealed class DownloadStatus with _$DownloadStatus {
  factory queued() = DownloadStatusInQueue;
  factory downloading({required double progress}) = DownloadStatusDownloading;
  factory downloaded() = DownloadStatusDownloaded;
}
