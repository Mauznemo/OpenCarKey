/// Bitmask-based feature flags
enum Feature {
  doorsLock(1 << 0),
  trunkOpen(1 << 1),
  engine(1 << 2),
  windows(1 << 3);

  const Feature(this.bit);
  final int bit;

  /// Convert from JSON string to Feature
  /// Example: Feature.fromJson('doorsLock') → Feature.doorsLock
  static Feature fromJson(String json) {
    return Feature.values.firstWhere(
      (f) => f.name == json,
      orElse: () => throw ArgumentError('Invalid feature name: $json'),
    );
  }

  /// Convert Feature to JSON string
  /// Example: Feature.doorsLock.toJson() → 'doorsLock'
  String toJson() => name;
}

/// Convert a bitmask integer to a Set of Feature values.
///
/// Example:
///   final features = featuresFromMask(5);
///   → {Feature.doorsLock, Feature.engine}
Set<Feature> featuresFromMask(int mask) {
  return Feature.values.where((f) => (mask & f.bit) != 0).toSet();
}

/// Convert a Set of Feature values to a bitmask.
///
/// Example:
///   final mask = featuresToMask({Feature.doorsLock, Feature.trunkOpen});
///   → 3
int featuresToMask(Set<Feature> features) {
  return features.fold(0, (acc, f) => acc | f.bit);
}

/// Check if a single feature exists in a bitmask.
///
/// Example:
///   hasFeature(mask, Feature.engine)
bool hasFeature(int mask, Feature feature) {
  return (mask & feature.bit) != 0;
}
