import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'framework.dart';
import 'platform_view.dart';

extension HtmlElementViewImpl on HtmlElementView {
  static HtmlElementView createFromTagName({
    Key? key,
    required String tagName,
    bool isVisible = true,
    ElementCreatedCallback? onElementCreated,
  }) {
    return HtmlElementView(
      key: key,
      viewType: isVisible ? ui_web.PlatformViewRegistry.defaultVisibleViewType : ui_web.PlatformViewRegistry.defaultInvisibleViewType,
      onPlatformViewCreated: _createPlatformViewCallbackForElementCallback(onElementCreated),
      creationParams: <dynamic, dynamic>{'tagName': tagName},
    );
  }

  Widget buildImpl(BuildContext context) {
    return PlatformViewLink(
      viewType: viewType,
      onCreatePlatformView: _createController,
      surfaceFactory: (BuildContext context, PlatformViewController controller) {
        return PlatformViewSurface(
          controller: controller,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
    );
  }

  _HtmlElementViewController _createController(
    PlatformViewCreationParams params,
  ) {
    final _HtmlElementViewController controller = _HtmlElementViewController(
      params.id,
      viewType,
      creationParams,
    );
    controller._initialize().then((_) {
      params.onPlatformViewCreated(params.id);
      onPlatformViewCreated?.call(params.id);
    });
    return controller;
  }
}

PlatformViewCreatedCallback? _createPlatformViewCallbackForElementCallback(
  ElementCreatedCallback? onElementCreated,
) {
  if (onElementCreated == null) {
    return null;
  }
  return (int id) {
    onElementCreated(_platformViewsRegistry.getViewById(id));
  };
}

class _HtmlElementViewController extends PlatformViewController {
  _HtmlElementViewController(
    this.viewId,
    this.viewType,
    this.creationParams,
  );

  @override
  final int viewId;

  final String viewType;

  final dynamic creationParams;

  bool _initialized = false;

  Future<void> _initialize() async {
    final Map<String, dynamic> args = <String, dynamic>{
      'id': viewId,
      'viewType': viewType,
      'params': creationParams,
    };
    await SystemChannels.platform_views.invokeMethod<void>('create', args);
    _initialized = true;
  }

  @override
  Future<void> clearFocus() async {
    // Currently this does nothing on Flutter Web.
    // TODO(het): Implement this. See https://github.com/flutter/flutter/issues/39496
  }

  @override
  Future<void> dispatchPointerEvent(PointerEvent event) async {
    // We do not dispatch pointer events to HTML views because they may contain
    // cross-origin iframes, which only accept user-generated events.
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await SystemChannels.platform_views.invokeMethod<void>('dispose', viewId);
    }
  }
}

@visibleForTesting
ui_web.PlatformViewRegistry? debugOverridePlatformViewRegistry;
ui_web.PlatformViewRegistry get _platformViewsRegistry => debugOverridePlatformViewRegistry ?? ui_web.platformViewRegistry;