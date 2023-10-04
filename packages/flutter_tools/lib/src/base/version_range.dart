import 'package:meta/meta.dart' show immutable;

@immutable
class VersionRange {
  const VersionRange(
    this.versionMin,
    this.versionMax,
  );

  final String? versionMin;
  final String? versionMax;

  @override
  bool operator ==(Object other) =>
      other is VersionRange &&
      other.versionMin == versionMin &&
      other.versionMax == versionMax;

  @override
  int get hashCode => Object.hash(versionMin, versionMax);
}
