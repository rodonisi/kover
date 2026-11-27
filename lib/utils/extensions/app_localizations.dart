import 'package:kover/generated/l10n/app_localizations.dart';

extension AppLocalizationsAnnotationExtension on AppLocalizations {
  String annotationLocation({
    required int pageNumber,
    String? chapterTitle,
  }) {
    final displayPage = pageNumber + 1;
    return switch (chapterTitle) {
      final chapter? when chapter.isNotEmpty => annotationPageChapterLocation(
        displayPage,
        chapter,
      ),
      _ => annotationPageLocation(displayPage),
    };
  }
}
