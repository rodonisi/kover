sealed class DataConstants {
  /// Chapter min number denoting a single chapter volume, aka a book
  static const double singleVolumeChapterMinNumber = -100000;

  /// Number of days since last reading activity for a series to appear on deck
  static const int onDeckProgressDays = 30;

  /// Number of days since a chapter was added for a series to appear on deck
  static const int onDeckUpdateDays = 7;

  /// The key used to store server settings in the database
  static const String serverSettingsKey = 'server_settings';
}
