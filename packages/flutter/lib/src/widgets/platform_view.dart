// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '_html_element_view_io.dart' if (dart.library.js_util) '_html_element_view_web.dart';
import 'basic.dart';
import 'debug.dart';
import 'focus_manager.dart';
import 'focus_scope.dart';
import 'framework.dart';

// Examples can assume:
// PlatformViewController createFooWebView(PlatformViewCreationParams params) { return (null as dynamic) as PlatformViewController; }
// Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{};
// late PlatformViewController _controller;

class AndroidView extends StatefulWidget {
  const AndroidView({
    super.key,
    required this.viewType,
    this.onPlatformViewCreated,
    this.hitTestBehavior = PlatformViewHitTestBehavior.opaque,
    this.layoutDirection,
    this.gestureRecognizers,
    this.creationParams,
    this.creationParamsCodec,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(creationParams == null || creationParamsCodec != null);

  final String viewType;

  final PlatformViewCreatedCallback? onPlatformViewCreated;

  final PlatformViewHitTestBehavior hitTestBehavior;

  final TextDirection? layoutDirection;

  // We use OneSequenceGestureRecognizers as they support gesture arena teams.
  // TODO(amirh): get a list of GestureRecognizers here.
  // https://github.com/flutter/flutter/issues/20953
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  final dynamic creationParams;

  final MessageCodec<dynamic>? creationParamsCodec;

  final Clip clipBehavior;

  @override
  State<AndroidView> createState() => _AndroidViewState();
}

abstract class _DarwinView extends StatefulWidget {
  const _DarwinView({
    super.key,
    required this.viewType,
    this.onPlatformViewCreated,
    this.hitTestBehavior = PlatformViewHitTestBehavior.opaque,
    this.layoutDirection,
    this.creationParams,
    this.creationParamsCodec,
    this.gestureRecognizers,
  }) : assert(creationParams == null || creationParamsCodec != null);

  // TODO(amirh): reference the iOS API doc once available.
  final String viewType;

  final PlatformViewCreatedCallback? onPlatformViewCreated;

  final PlatformViewHitTestBehavior hitTestBehavior;

  final TextDirection? layoutDirection;

  final dynamic creationParams;

  final MessageCodec<dynamic>? creationParamsCodec;

  // We use OneSequenceGestureRecognizers as they support gesture arena teams.
  // TODO(amirh): get a list of GestureRecognizers here.
  // https://github.com/flutter/flutter/issues/20953
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;
}

// TODO(amirh): describe the embedding mechanism.
// TODO(ychris): remove the documentation for conic path not supported once https://github.com/flutter/flutter/issues/35062 is resolved.
class UiKitView extends _DarwinView {
  const UiKitView({
    super.key,
    required super.viewType,
    super.onPlatformViewCreated,
    super.hitTestBehavior = PlatformViewHitTestBehavior.opaque,
    super.layoutDirection,
    super.creationParams,
    super.creationParamsCodec,
    super.gestureRecognizers,
  }) : assert(creationParams == null || creationParamsCodec != null);

  @override
  State<UiKitView> createState() => _UiKitViewState();
}

class AppKitView extends _DarwinView {
  const AppKitView({
    super.key,
    required super.viewType,
    super.onPlatformViewCreated,
    super.hitTestBehavior = PlatformViewHitTestBehavior.opaque,
    super.layoutDirection,
    super.creationParams,
    super.creationParamsCodec,
    super.gestureRecognizers,
  });

  @override
  State<AppKitView> createState() => _AppKitViewState();
}

typedef ElementCreatedCallback = void Function(Object element);

class HtmlElementView extends StatelessWidget {
  const HtmlElementView({
    super.key,
    required this.viewType,
    this.onPlatformViewCreated,
    this.creationParams,
  });

  factory HtmlElementView.fromTagName({
    Key? key,
    required String tagName,
    bool isVisible = true,
    ElementCreatedCallback? onElementCreated,
  }) =>
      HtmlElementViewImpl.createFromTagName(
        key: key,
        tagName: tagName,
        isVisible: isVisible,
        onElementCreated: onElementCreated,
      );

  final String viewType;

  final PlatformViewCreatedCallback? onPlatformViewCreated;

  final Object? creationParams;

  @override
  Widget build(BuildContext context) => buildImpl(context);
}

class _AndroidViewState extends State<AndroidView> {
  int? _id;
  late AndroidViewController _controller;
  TextDirection? _layoutDirection;
  bool _initialized = false;
  FocusNode? _focusNode;

  static final Set<Factory<OneSequenceGestureRecognizer>> _emptyRecognizersSet =
    <Factory<OneSequenceGestureRecognizer>>{};

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: _onFocusChange,
      child: _AndroidPlatformView(
        controller: _controller,
        hitTestBehavior: widget.hitTestBehavior,
        gestureRecognizers: widget.gestureRecognizers ?? _emptyRecognizersSet,
        clipBehavior: widget.clipBehavior,
      ),
    );
  }

  void _initializeOnce() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _createNewAndroidView();
    _focusNode = FocusNode(debugLabel: 'AndroidView(id: $_id)');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TextDirection newLayoutDirection = _findLayoutDirection();
    final bool didChangeLayoutDirection = _layoutDirection != newLayoutDirection;
    _layoutDirection = newLayoutDirection;

    _initializeOnce();
    if (didChangeLayoutDirection) {
      // The native view will update asynchronously, in the meantime we don't want
      // to block the framework. (so this is intentionally not awaiting).
      _controller.setLayoutDirection(_layoutDirection!);
    }
  }

  @override
  void didUpdateWidget(AndroidView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final TextDirection newLayoutDirection = _findLayoutDirection();
    final bool didChangeLayoutDirection = _layoutDirection != newLayoutDirection;
    _layoutDirection = newLayoutDirection;

    if (widget.viewType != oldWidget.viewType) {
      _controller.disposePostFrame();
      _createNewAndroidView();
      return;
    }

    if (didChangeLayoutDirection) {
      _controller.setLayoutDirection(_layoutDirection!);
    }
  }

  TextDirection _findLayoutDirection() {
    assert(widget.layoutDirection != null || debugCheckHasDirectionality(context));
    return widget.layoutDirection ?? Directionality.of(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode?.dispose();
    _focusNode = null;
    super.dispose();
  }

  void _createNewAndroidView() {
    _id = platformViewsRegistry.getNextPlatformViewId();
    _controller = PlatformViewsService.initAndroidView(
      id: _id!,
      viewType: widget.viewType,
      layoutDirection: _layoutDirection!,
      creationParams: widget.creationParams,
      creationParamsCodec: widget.creationParamsCodec,
      onFocus: () {
        _focusNode!.requestFocus();
      },
    );
    if (widget.onPlatformViewCreated != null) {
      _controller.addOnPlatformViewCreatedListener(widget.onPlatformViewCreated!);
    }
  }

  void _onFocusChange(bool isFocused) {
    if (!_controller.isCreated) {
      return;
    }
    if (!isFocused) {
      _controller.clearFocus().catchError((dynamic e) {
        if (e is MissingPluginException) {
          // We land the framework part of Android platform views keyboard
          // support before the engine part. There will be a commit range where
          // clearFocus isn't implemented in the engine. When that happens we
          // just swallow the error here. Once the engine part is rolled to the
          // framework I'll remove this.
          // TODO(amirh): remove this once the engine's clearFocus is rolled.
          return;
        }
      });
      return;
    }
    SystemChannels.textInput.invokeMethod<void>(
      'TextInput.setPlatformViewClient',
      <String, dynamic>{'platformViewId': _id},
    ).catchError((dynamic e) {
      if (e is MissingPluginException) {
        // We land the framework part of Android platform views keyboard
        // support before the engine part. There will be a commit range where
        // setPlatformViewClient isn't implemented in the engine. When that
        // happens we just swallow the error here. Once the engine part is
        // rolled to the framework I'll remove this.
        // TODO(amirh): remove this once the engine's clearFocus is rolled.
        return;
      }
    });
  }
}

abstract class _DarwinViewState<PlatformViewT extends _DarwinView, ControllerT extends DarwinPlatformViewController, RenderT extends RenderDarwinPlatformView<ControllerT>, ViewT extends _DarwinPlatformView<ControllerT, RenderT>> extends State<PlatformViewT> {
  ControllerT? _controller;
  TextDirection? _layoutDirection;
  bool _initialized = false;

  @visibleForTesting
  FocusNode? focusNode;

  static final Set<Factory<OneSequenceGestureRecognizer>> _emptyRecognizersSet =
    <Factory<OneSequenceGestureRecognizer>>{};

  @override
  Widget build(BuildContext context) {
    final ControllerT? controller = _controller;
    if (controller == null) {
      return const SizedBox.expand();
    }
    return Focus(
      focusNode: focusNode,
      onFocusChange: (bool isFocused) => _onFocusChange(isFocused, controller),
      child: childPlatformView()
    );
  }

  ViewT childPlatformView();

  void _initializeOnce() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _createNewUiKitView();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TextDirection newLayoutDirection = _findLayoutDirection();
    final bool didChangeLayoutDirection = _layoutDirection != newLayoutDirection;
    _layoutDirection = newLayoutDirection;

    _initializeOnce();
    if (didChangeLayoutDirection) {
      // The native view will update asynchronously, in the meantime we don't want
      // to block the framework. (so this is intentionally not awaiting).
      _controller?.setLayoutDirection(_layoutDirection!);
    }
  }

  @override
  void didUpdateWidget(PlatformViewT oldWidget) {
    super.didUpdateWidget(oldWidget);

    final TextDirection newLayoutDirection = _findLayoutDirection();
    final bool didChangeLayoutDirection = _layoutDirection != newLayoutDirection;
    _layoutDirection = newLayoutDirection;

    if (widget.viewType != oldWidget.viewType) {
      _controller?.dispose();
      _controller = null;
      focusNode?.dispose();
      focusNode = null;
      _createNewUiKitView();
      return;
    }

    if (didChangeLayoutDirection) {
      _controller?.setLayoutDirection(_layoutDirection!);
    }
  }

  TextDirection _findLayoutDirection() {
    assert(widget.layoutDirection != null || debugCheckHasDirectionality(context));
    return widget.layoutDirection ?? Directionality.of(context);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    focusNode?.dispose();
    focusNode = null;
    super.dispose();
  }

  Future<void> _createNewUiKitView() async {
    final int id = platformViewsRegistry.getNextPlatformViewId();
    final ControllerT controller = await createNewViewController(
      id
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    widget.onPlatformViewCreated?.call(id);
    setState(() {
      _controller = controller;
      focusNode = FocusNode(debugLabel: 'UiKitView(id: $id)');
    });
  }

  Future<ControllerT> createNewViewController(int id);

  void _onFocusChange(bool isFocused, ControllerT controller) {
    if (!isFocused) {
      // Unlike Android, we do not need to send "clearFocus" channel message
      // to the engine, because focusing on another view will automatically
      // cancel the focus on the previously focused platform view.
      return;
    }
    SystemChannels.textInput.invokeMethod<void>(
      'TextInput.setPlatformViewClient',
      <String, dynamic>{'platformViewId': controller.id},
    );
  }
}

class _UiKitViewState extends _DarwinViewState<UiKitView, UiKitViewController, RenderUiKitView, _UiKitPlatformView> {
  @override
  Future<UiKitViewController> createNewViewController(int id) async {
    return PlatformViewsService.initUiKitView(
      id: id,
      viewType: widget.viewType,
      layoutDirection: _layoutDirection!,
      creationParams: widget.creationParams,
      creationParamsCodec: widget.creationParamsCodec,
      onFocus: () {
        focusNode?.requestFocus();
      }
    );
  }

  @override
  _UiKitPlatformView childPlatformView() {
    return _UiKitPlatformView(
        controller: _controller!,
        hitTestBehavior: widget.hitTestBehavior,
        gestureRecognizers: widget.gestureRecognizers ?? _DarwinViewState._emptyRecognizersSet,
      );
  }
}

class _AppKitViewState extends _DarwinViewState<AppKitView, AppKitViewController, RenderAppKitView, _AppKitPlatformView> {
  @override
  Future<AppKitViewController> createNewViewController(int id) async {
    return PlatformViewsService.initAppKitView(
      id: id,
      viewType: widget.viewType,
      layoutDirection: _layoutDirection!,
      creationParams: widget.creationParams,
      creationParamsCodec: widget.creationParamsCodec,
      onFocus: () {
        focusNode?.requestFocus();
      }
    );
  }

  @override
  _AppKitPlatformView childPlatformView() {
    return _AppKitPlatformView(
        controller: _controller!,
        hitTestBehavior: widget.hitTestBehavior,
        gestureRecognizers: widget.gestureRecognizers ?? _DarwinViewState._emptyRecognizersSet,
      );
  }
}

class _AndroidPlatformView extends LeafRenderObjectWidget {
  const _AndroidPlatformView({
    required this.controller,
    required this.hitTestBehavior,
    required this.gestureRecognizers,
    this.clipBehavior = Clip.hardEdge,
  });

  final AndroidViewController controller;
  final PlatformViewHitTestBehavior hitTestBehavior;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;
  final Clip clipBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAndroidView(
        viewController: controller,
        hitTestBehavior: hitTestBehavior,
        gestureRecognizers: gestureRecognizers,
        clipBehavior: clipBehavior,
      );

  @override
  void updateRenderObject(BuildContext context, RenderAndroidView renderObject) {
    renderObject.controller = controller;
    renderObject.hitTestBehavior = hitTestBehavior;
    renderObject.updateGestureRecognizers(gestureRecognizers);
    renderObject.clipBehavior = clipBehavior;
  }
}

abstract class _DarwinPlatformView<TController extends DarwinPlatformViewController, TRender extends RenderDarwinPlatformView<TController>> extends LeafRenderObjectWidget {
  const _DarwinPlatformView({
    required this.controller,
    required this.hitTestBehavior,
    required this.gestureRecognizers,
  });

  final TController controller;
  final PlatformViewHitTestBehavior hitTestBehavior;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  @mustCallSuper
  void updateRenderObject(BuildContext context, TRender renderObject) {
    renderObject
      ..viewController = controller
      ..hitTestBehavior = hitTestBehavior
      ..updateGestureRecognizers(gestureRecognizers);
  }
}

class _UiKitPlatformView extends _DarwinPlatformView<UiKitViewController, RenderUiKitView> {
  const _UiKitPlatformView({required super.controller, required super.hitTestBehavior, required super.gestureRecognizers});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderUiKitView(
      viewController: controller,
      hitTestBehavior: hitTestBehavior,
      gestureRecognizers: gestureRecognizers,
    );
  }
}

class _AppKitPlatformView extends _DarwinPlatformView<AppKitViewController, RenderAppKitView> {
  const _AppKitPlatformView({required super.controller, required super.hitTestBehavior, required super.gestureRecognizers});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderAppKitView(
      viewController: controller,
      hitTestBehavior: hitTestBehavior,
      gestureRecognizers: gestureRecognizers,
    );
  }
}

class PlatformViewCreationParams {

  const PlatformViewCreationParams._({
    required this.id,
    required this.viewType,
    required this.onPlatformViewCreated,
    required this.onFocusChanged,
  });

  final int id;

  final String viewType;

  final PlatformViewCreatedCallback onPlatformViewCreated;

  final ValueChanged<bool> onFocusChanged;
}

typedef PlatformViewSurfaceFactory = Widget Function(BuildContext context, PlatformViewController controller);

typedef CreatePlatformViewCallback = PlatformViewController Function(PlatformViewCreationParams params);

class PlatformViewLink extends StatefulWidget {
  const PlatformViewLink({
    super.key,
    required PlatformViewSurfaceFactory surfaceFactory,
    required CreatePlatformViewCallback onCreatePlatformView,
    required this.viewType,
    }) : _surfaceFactory = surfaceFactory,
         _onCreatePlatformView = onCreatePlatformView;


  final PlatformViewSurfaceFactory _surfaceFactory;
  final CreatePlatformViewCallback _onCreatePlatformView;

  final String viewType;

  @override
  State<StatefulWidget> createState() => _PlatformViewLinkState();
}

class _PlatformViewLinkState extends State<PlatformViewLink> {
  int? _id;
  PlatformViewController? _controller;
  bool _platformViewCreated = false;
  Widget? _surface;
  FocusNode? _focusNode;

  @override
  Widget build(BuildContext context) {
    final PlatformViewController? controller = _controller;
    if (controller == null) {
      return const SizedBox.expand();
    }
    if (!_platformViewCreated) {
      // Depending on the implementation, the first non-empty size can be used
      // to size the platform view.
      return _PlatformViewPlaceHolder(onLayout: (Size size, Offset position) {
        if (controller.awaitingCreation && !size.isEmpty) {
          controller.create(size: size, position: position);
        }
      });
    }
    _surface ??= widget._surfaceFactory(context, controller);
    return Focus(
      focusNode: _focusNode,
      onFocusChange: _handleFrameworkFocusChanged,
      child: _surface!,
    );
  }

  @override
  void initState() {
    _focusNode = FocusNode(debugLabel: 'PlatformView(id: $_id)');
    _initialize();
    super.initState();
  }

  @override
  void didUpdateWidget(PlatformViewLink oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.viewType != oldWidget.viewType) {
      _controller?.disposePostFrame();
      // The _surface has to be recreated as its controller is disposed.
      // Setting _surface to null will trigger its creation in build().
      _surface = null;
      _initialize();
    }
  }

  void _initialize() {
    _id = platformViewsRegistry.getNextPlatformViewId();
    _controller = widget._onCreatePlatformView(
      PlatformViewCreationParams._(
        id: _id!,
        viewType: widget.viewType,
        onPlatformViewCreated: _onPlatformViewCreated,
        onFocusChanged: _handlePlatformFocusChanged,
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    if (mounted) {
      setState(() {
        _platformViewCreated = true;
      });
    }
  }

  void _handleFrameworkFocusChanged(bool isFocused) {
    if (!isFocused) {
      _controller?.clearFocus();
    }
    SystemChannels.textInput.invokeMethod<void>(
      'TextInput.setPlatformViewClient',
      <String, dynamic>{'platformViewId': _id},
    );
  }

  void _handlePlatformFocusChanged(bool isFocused) {
    if (isFocused) {
      _focusNode!.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _focusNode?.dispose();
    _focusNode = null;
    super.dispose();
  }
}

// TODO(amirh): Link to the embedder's system compositor documentation once available.
class PlatformViewSurface extends LeafRenderObjectWidget {

  const PlatformViewSurface({
    super.key,
    required this.controller,
    required this.hitTestBehavior,
    required this.gestureRecognizers,
  });

  final PlatformViewController controller;

  // We use OneSequenceGestureRecognizers as they support gesture arena teams.
  // TODO(amirh): get a list of GestureRecognizers here.
  // https://github.com/flutter/flutter/issues/20953
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  final PlatformViewHitTestBehavior hitTestBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return PlatformViewRenderBox(controller: controller, gestureRecognizers: gestureRecognizers, hitTestBehavior: hitTestBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, PlatformViewRenderBox renderObject) {
    renderObject
      ..controller = controller
      ..hitTestBehavior = hitTestBehavior
      ..updateGestureRecognizers(gestureRecognizers);
  }
}

class AndroidViewSurface extends StatefulWidget {
  const AndroidViewSurface({
    super.key,
    required this.controller,
    required this.hitTestBehavior,
    required this.gestureRecognizers,
  });

  final AndroidViewController controller;

  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  final PlatformViewHitTestBehavior hitTestBehavior;

  @override
  State<StatefulWidget> createState() {
    return _AndroidViewSurfaceState();
  }
}

class _AndroidViewSurfaceState extends State<AndroidViewSurface> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.isCreated) {
      // Schedule a rebuild once creation is complete and the final display
      // type is known.
      widget.controller.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
    }
  }

  @override
  void dispose() {
    widget.controller.removeOnPlatformViewCreatedListener(_onPlatformViewCreated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.requiresViewComposition) {
      return _PlatformLayerBasedAndroidViewSurface(
        controller: widget.controller,
        hitTestBehavior: widget.hitTestBehavior,
        gestureRecognizers: widget.gestureRecognizers,
      );
    } else {
      return _TextureBasedAndroidViewSurface(
        controller: widget.controller,
        hitTestBehavior: widget.hitTestBehavior,
        gestureRecognizers: widget.gestureRecognizers,
      );
    }
  }

  void _onPlatformViewCreated(int _) {
    // Trigger a re-build based on the current controller state.
    setState(() {});
  }
}

// Displays an Android platform view via GL texture.
class _TextureBasedAndroidViewSurface extends PlatformViewSurface {
  const _TextureBasedAndroidViewSurface({
    required AndroidViewController super.controller,
    required super.hitTestBehavior,
    required super.gestureRecognizers,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    final AndroidViewController viewController = controller as AndroidViewController;
    // Use GL texture based composition.
    // App should use GL texture unless they require to embed a SurfaceView.
    final RenderAndroidView renderBox = RenderAndroidView(
      viewController: viewController,
      gestureRecognizers: gestureRecognizers,
      hitTestBehavior: hitTestBehavior,
    );
    viewController.pointTransformer =
        (Offset position) => renderBox.globalToLocal(position);
    return renderBox;
  }
}

class _PlatformLayerBasedAndroidViewSurface extends PlatformViewSurface {
  const _PlatformLayerBasedAndroidViewSurface({
    required AndroidViewController super.controller,
    required super.hitTestBehavior,
    required super.gestureRecognizers,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    final AndroidViewController viewController = controller as AndroidViewController;
    final PlatformViewRenderBox renderBox =
        super.createRenderObject(context) as PlatformViewRenderBox;
    viewController.pointTransformer =
        (Offset position) => renderBox.globalToLocal(position);
    return renderBox;
  }
}

typedef _OnLayoutCallback = void Function(Size size, Offset position);

class _PlatformViewPlaceholderBox extends RenderConstrainedBox {
  _PlatformViewPlaceholderBox({
    required this.onLayout,
  }) : super(additionalConstraints: const BoxConstraints.tightFor(
      width: double.infinity,
      height: double.infinity,
    ));

  _OnLayoutCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    // A call to `localToGlobal` requires waiting for a frame to render first.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      onLayout(size, localToGlobal(Offset.zero));
    });
  }
}

class _PlatformViewPlaceHolder extends SingleChildRenderObjectWidget {
  const _PlatformViewPlaceHolder({
    required this.onLayout,
  });

  final _OnLayoutCallback onLayout;

  @override
  _PlatformViewPlaceholderBox createRenderObject(BuildContext context) {
    return _PlatformViewPlaceholderBox(onLayout: onLayout);
  }

  @override
  void updateRenderObject(BuildContext context, _PlatformViewPlaceholderBox renderObject) {
    renderObject.onLayout = onLayout;
  }
}

extension on PlatformViewController {
  void disposePostFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      dispose();
    });
  }
}