import 'package:flutter_web_plugins/url_strategy.dart';

class TestPlatformLocation implements PlatformLocation {
  @override
  String pathname = '';

  @override
  String search = '';

  @override
  String hash = '';

  @override
  Object? get state => null;

  String baseHref = '';

  @override
  void addPopStateListener(EventListener fn) {
    throw UnimplementedError();
  }

  @override
  void removePopStateListener(EventListener fn) {
    throw UnimplementedError();
  }

  @override
  void pushState(Object? state, String title, String url) {}

  @override
  void replaceState(Object? state, String title, String url) {}

  @override
  void go(int count) {
    throw UnimplementedError();
  }

  @override
  String getBaseHref() => baseHref;
}