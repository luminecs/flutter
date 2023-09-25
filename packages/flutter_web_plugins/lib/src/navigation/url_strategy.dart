import 'dart:ui_web' as ui_web;

import 'utils.dart';

export 'dart:ui_web'
    show
        BrowserPlatformLocation,
        EventListener,
        HashUrlStrategy,
        PlatformLocation,
        UrlStrategy,
        urlStrategy;

void setUrlStrategy(ui_web.UrlStrategy? strategy) {
  ui_web.urlStrategy = strategy;
}

void usePathUrlStrategy() {
  setUrlStrategy(PathUrlStrategy());
}

class PathUrlStrategy extends ui_web.HashUrlStrategy {
  PathUrlStrategy([
    super.platformLocation,
    this.includeHash = false,
  ])  : _platformLocation = platformLocation,
        _basePath = stripTrailingSlash(extractPathname(checkBaseHref(
          platformLocation.getBaseHref(),
        )));

  final ui_web.PlatformLocation _platformLocation;
  final String _basePath;

  final bool includeHash;

  @override
  String getPath() {
    final String? hash = includeHash ? _platformLocation.hash : null;
    final String path = _platformLocation.pathname + _platformLocation.search + (hash ?? '');
    if (_basePath.isNotEmpty && path.startsWith(_basePath)) {
      return ensureLeadingSlash(path.substring(_basePath.length));
    }
    return ensureLeadingSlash(path);
  }

  @override
  String prepareExternalUrl(String internalUrl) {
    if (internalUrl.isEmpty) {
      internalUrl = '/';
    }
    assert(
      internalUrl.startsWith('/'),
      "When using PathUrlStrategy, all route names must start with '/' because "
      "the browser's pathname always starts with '/'. "
      "Found route name: '$internalUrl'",
    );
    return '$_basePath$internalUrl';
  }
}