// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

@immutable
class Version implements Comparable<Version> {
  factory Version(int major, int? minor, int? patch, {String? text}) {
    if (text == null) {
      text = '$major';
      if (minor != null) {
        text = '$text.$minor';
      }
      if (patch != null) {
        text = '$text.$patch';
      }
    }

    return Version._(major, minor ?? 0, patch ?? 0, text);
  }

  const Version.withText(this.major, this.minor, this.patch, this._text);

  Version._(this.major, this.minor, this.patch, this._text) {
    if (major < 0) {
      throw ArgumentError('Major version must be non-negative.');
    }
    if (minor < 0) {
      throw ArgumentError('Minor version must be non-negative.');
    }
    if (patch < 0) {
      throw ArgumentError('Patch version must be non-negative.');
    }
  }

  static Version? parse(String? text) {
    final Match? match = versionPattern.firstMatch(text ?? '');
    if (match == null) {
      return null;
    }

    try {
      final int major = int.parse(match[1] ?? '0');
      final int minor = int.parse(match[3] ?? '0');
      final int patch = int.parse(match[5] ?? '0');
      return Version._(major, minor, patch, text ?? '');
    } on FormatException {
      return null;
    }
  }

  static Version? primary(List<Version> versions) {
    Version? primary;
    for (final Version version in versions) {
      if (primary == null || (version > primary)) {
        primary = version;
      }
    }
    return primary;
  }

  final int major;

  final int minor;

  final int patch;

  final String _text;

  static final RegExp versionPattern =
      RegExp(r'^(\d+)(\.(\d+)(\.(\d+))?)?');

  @override
  bool operator ==(Object other) {
    return other is Version
        && other.major == major
        && other.minor == minor
        && other.patch == patch;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);

  bool operator <(Version other) => compareTo(other) < 0;
  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
  bool operator >=(Version other) => compareTo(other) >= 0;

  @override
  int compareTo(Version other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => _text;
}

bool isWithinVersionRange(
  String targetVersion, {
  required String min,
  required String max,
  bool inclusiveMax = true,
  bool inclusiveMin = true,
}) {
  final Version? parsedTargetVersion = Version.parse(targetVersion);
  final Version? minVersion = Version.parse(min);
  final Version? maxVersion = Version.parse(max);

  final bool withinMin = minVersion != null &&
      parsedTargetVersion != null &&
      (inclusiveMin
      ? parsedTargetVersion >= minVersion
      : parsedTargetVersion > minVersion);

  final bool withinMax = maxVersion != null &&
      parsedTargetVersion != null &&
      (inclusiveMax
          ? parsedTargetVersion <= maxVersion
          : parsedTargetVersion < maxVersion);
  return withinMin && withinMax;
}