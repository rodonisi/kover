import 'package:kover/models/enums/format.dart';

extension FormatExtensions on Format {
  /// Formats whose pages are single images.
  bool get isImage => this == .image || this == .archive;

  /// Formats that support page-based bookmarks.
  bool get supportsBookmarks => isImage;
}
