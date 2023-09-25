
import 'dart:async';
import 'dart:ui' as ui;

import 'platform_location.dart';

export 'platform_location.dart';

typedef PopStateListener = void Function(Object? state);

abstract class UrlStrategy {
  const UrlStrategy();

  ui.VoidCallback addPopStateListener(PopStateListener fn) {
    // No-op.
    return () {};
  }

  String getPath() => '';

  Object? getState() => null;

  String prepareExternalUrl(String internalUrl) => '';

  void pushState(Object? state, String title, String url) {
    // No-op.
  }

  void replaceState(Object? state, String title, String url) {
    // No-op.
  }

  Future<void> go(int count) async {
    // No-op.
  }
}

UrlStrategy? get urlStrategy => null;

void setUrlStrategy(UrlStrategy? strategy) {
  // No-op in non-web platforms.
}

void usePathUrlStrategy() {
  // No-op in non-web platforms.
}

class HashUrlStrategy extends UrlStrategy {
  const HashUrlStrategy([PlatformLocation? _]);
}

class PathUrlStrategy extends HashUrlStrategy {
  const PathUrlStrategy([PlatformLocation? _, bool __ = false,]);
}