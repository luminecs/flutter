import 'package:flutter/foundation.dart';

@immutable
class IconData {
  const IconData(
    this.codePoint, {
    this.fontFamily,
    this.fontPackage,
    this.matchTextDirection = false,
    this.fontFamilyFallback,
  });

  final int codePoint;

  final String? fontFamily;

  final String? fontPackage;

  final bool matchTextDirection;

  final List<String>? fontFamilyFallback;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is IconData &&
        other.codePoint == codePoint &&
        other.fontFamily == fontFamily &&
        other.fontPackage == fontPackage &&
        other.matchTextDirection == matchTextDirection &&
        listEquals(other.fontFamilyFallback, fontFamilyFallback);
  }

  @override
  int get hashCode {
    return Object.hash(
      codePoint,
      fontFamily,
      fontPackage,
      matchTextDirection,
      Object.hashAll(fontFamilyFallback ?? const <String?>[]),
    );
  }

  @override
  String toString() =>
      'IconData(U+${codePoint.toRadixString(16).toUpperCase().padLeft(5, '0')})';
}

class IconDataProperty extends DiagnosticsProperty<IconData> {
  IconDataProperty(
    String super.name,
    super.value, {
    super.ifNull,
    super.showName,
    super.style,
    super.level,
  });

  @override
  Map<String, Object?> toJsonMap(DiagnosticsSerializationDelegate delegate) {
    final Map<String, Object?> json = super.toJsonMap(delegate);
    if (value != null) {
      json['valueProperties'] = <String, Object>{
        'codePoint': value!.codePoint,
      };
    }
    return json;
  }
}

class _StaticIconProvider {
  const _StaticIconProvider();
}

const Object staticIconProvider = _StaticIconProvider();
