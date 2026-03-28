extension DateTimeExtension on DateTime {
  DateTime normalizeUtc() {
    if (isUtc) {
      return this;
    }

    return DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
      second,
    );
  }
}
