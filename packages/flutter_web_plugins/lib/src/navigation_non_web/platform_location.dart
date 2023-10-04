import 'url_strategy.dart';

typedef EventListener = dynamic Function(Object event);

abstract interface class PlatformLocation {
  void addPopStateListener(EventListener fn);

  void removePopStateListener(EventListener fn);

  String get pathname;

  String get search;

  String get hash;

  Object? get state;

  void pushState(Object? state, String title, String url);

  void replaceState(Object? state, String title, String url);

  void go(int count);

  String? getBaseHref();
}

class BrowserPlatformLocation implements PlatformLocation {
  @override
  void addPopStateListener(EventListener fn) {
    // No-op.
  }

  @override
  void removePopStateListener(EventListener fn) {
    // No-op.
  }

  @override
  String get pathname => '';

  @override
  String get search => '';

  @override
  String get hash => '';

  @override
  Object? get state => null;

  @override
  void pushState(Object? state, String title, String url) {
    // No-op.
  }

  @override
  void replaceState(Object? state, String title, String url) {
    // No-op.
  }

  @override
  void go(int count) {
    // No-op.
  }

  @override
  String? getBaseHref() => null;
}
