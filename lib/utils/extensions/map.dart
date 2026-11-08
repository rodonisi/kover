extension MapExtensions on Map {
  /// Adds all entries from [other] to this map, preserving the order of
  /// insertion.
  void addAllOrdered(Map other) {
    for (final entry in other.entries) {
      remove(entry.key);
      this[entry.key] = entry.value;
    }
  }
}
