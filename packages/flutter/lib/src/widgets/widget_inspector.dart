import 'dart:async';
import 'dart:collection' show HashMap;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui
    show
        ClipOp,
        FlutterView,
        Image,
        ImageByteFormat,
        Paragraph,
        Picture,
        PictureRecorder,
        PointMode,
        SceneBuilder,
        Vertices;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta_meta.dart';

import 'app.dart';
import 'basic.dart';
import 'binding.dart';
import 'debug.dart';
import 'framework.dart';
import 'gesture_detector.dart';
import 'service_extensions.dart';
import 'view.dart';

typedef InspectorSelectButtonBuilder = Widget Function(
    BuildContext context, VoidCallback onPressed);

typedef RegisterServiceExtensionCallback = void Function({
  required String name,
  required ServiceExtensionCallback callback,
});

class _ProxyLayer extends Layer {
  _ProxyLayer(this._layer);

  final Layer _layer;

  @override
  void addToScene(ui.SceneBuilder builder) {
    _layer.addToScene(builder);
  }

  @override
  @protected
  bool findAnnotations<S extends Object>(
    AnnotationResult<S> result,
    Offset localPosition, {
    required bool onlyFirst,
  }) {
    return _layer.findAnnotations(result, localPosition, onlyFirst: onlyFirst);
  }
}

class _MulticastCanvas implements Canvas {
  _MulticastCanvas({
    required Canvas main,
    required Canvas screenshot,
  })  : _main = main,
        _screenshot = screenshot;

  final Canvas _main;
  final Canvas _screenshot;

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) {
    _main.clipPath(path, doAntiAlias: doAntiAlias);
    _screenshot.clipPath(path, doAntiAlias: doAntiAlias);
  }

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) {
    _main.clipRRect(rrect, doAntiAlias: doAntiAlias);
    _screenshot.clipRRect(rrect, doAntiAlias: doAntiAlias);
  }

  @override
  void clipRect(Rect rect,
      {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) {
    _main.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
    _screenshot.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }

  @override
  void drawArc(Rect rect, double startAngle, double sweepAngle, bool useCenter,
      Paint paint) {
    _main.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
    _screenshot.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  }

  @override
  void drawAtlas(ui.Image atlas, List<RSTransform> transforms, List<Rect> rects,
      List<Color>? colors, BlendMode? blendMode, Rect? cullRect, Paint paint) {
    _main.drawAtlas(
        atlas, transforms, rects, colors, blendMode, cullRect, paint);
    _screenshot.drawAtlas(
        atlas, transforms, rects, colors, blendMode, cullRect, paint);
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    _main.drawCircle(c, radius, paint);
    _screenshot.drawCircle(c, radius, paint);
  }

  @override
  void drawColor(Color color, BlendMode blendMode) {
    _main.drawColor(color, blendMode);
    _screenshot.drawColor(color, blendMode);
  }

  @override
  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    _main.drawDRRect(outer, inner, paint);
    _screenshot.drawDRRect(outer, inner, paint);
  }

  @override
  void drawImage(ui.Image image, Offset p, Paint paint) {
    _main.drawImage(image, p, paint);
    _screenshot.drawImage(image, p, paint);
  }

  @override
  void drawImageNine(ui.Image image, Rect center, Rect dst, Paint paint) {
    _main.drawImageNine(image, center, dst, paint);
    _screenshot.drawImageNine(image, center, dst, paint);
  }

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    _main.drawImageRect(image, src, dst, paint);
    _screenshot.drawImageRect(image, src, dst, paint);
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    _main.drawLine(p1, p2, paint);
    _screenshot.drawLine(p1, p2, paint);
  }

  @override
  void drawOval(Rect rect, Paint paint) {
    _main.drawOval(rect, paint);
    _screenshot.drawOval(rect, paint);
  }

  @override
  void drawPaint(Paint paint) {
    _main.drawPaint(paint);
    _screenshot.drawPaint(paint);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    _main.drawParagraph(paragraph, offset);
    _screenshot.drawParagraph(paragraph, offset);
  }

  @override
  void drawPath(Path path, Paint paint) {
    _main.drawPath(path, paint);
    _screenshot.drawPath(path, paint);
  }

  @override
  void drawPicture(ui.Picture picture) {
    _main.drawPicture(picture);
    _screenshot.drawPicture(picture);
  }

  @override
  void drawPoints(ui.PointMode pointMode, List<Offset> points, Paint paint) {
    _main.drawPoints(pointMode, points, paint);
    _screenshot.drawPoints(pointMode, points, paint);
  }

  @override
  void drawRRect(RRect rrect, Paint paint) {
    _main.drawRRect(rrect, paint);
    _screenshot.drawRRect(rrect, paint);
  }

  @override
  void drawRawAtlas(
      ui.Image atlas,
      Float32List rstTransforms,
      Float32List rects,
      Int32List? colors,
      BlendMode? blendMode,
      Rect? cullRect,
      Paint paint) {
    _main.drawRawAtlas(
        atlas, rstTransforms, rects, colors, blendMode, cullRect, paint);
    _screenshot.drawRawAtlas(
        atlas, rstTransforms, rects, colors, blendMode, cullRect, paint);
  }

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) {
    _main.drawRawPoints(pointMode, points, paint);
    _screenshot.drawRawPoints(pointMode, points, paint);
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    _main.drawRect(rect, paint);
    _screenshot.drawRect(rect, paint);
  }

  @override
  void drawShadow(
      Path path, Color color, double elevation, bool transparentOccluder) {
    _main.drawShadow(path, color, elevation, transparentOccluder);
    _screenshot.drawShadow(path, color, elevation, transparentOccluder);
  }

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) {
    _main.drawVertices(vertices, blendMode, paint);
    _screenshot.drawVertices(vertices, blendMode, paint);
  }

  @override
  int getSaveCount() {
    // The main canvas is used instead of the screenshot canvas as the main
    // canvas is guaranteed to be consistent with the canvas expected by the
    // normal paint pipeline so any logic depending on getSaveCount() will
    // behave the same as for the regular paint pipeline.
    return _main.getSaveCount();
  }

  @override
  void restore() {
    _main.restore();
    _screenshot.restore();
  }

  @override
  void rotate(double radians) {
    _main.rotate(radians);
    _screenshot.rotate(radians);
  }

  @override
  void save() {
    _main.save();
    _screenshot.save();
  }

  @override
  void saveLayer(Rect? bounds, Paint paint) {
    _main.saveLayer(bounds, paint);
    _screenshot.saveLayer(bounds, paint);
  }

  @override
  void scale(double sx, [double? sy]) {
    _main.scale(sx, sy);
    _screenshot.scale(sx, sy);
  }

  @override
  void skew(double sx, double sy) {
    _main.skew(sx, sy);
    _screenshot.skew(sx, sy);
  }

  @override
  void transform(Float64List matrix4) {
    _main.transform(matrix4);
    _screenshot.transform(matrix4);
  }

  @override
  void translate(double dx, double dy) {
    _main.translate(dx, dy);
    _screenshot.translate(dx, dy);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    super.noSuchMethod(invocation);
  }
}

Rect _calculateSubtreeBoundsHelper(RenderObject object, Matrix4 transform) {
  Rect bounds = MatrixUtils.transformRect(transform, object.semanticBounds);

  object.visitChildren((RenderObject child) {
    final Matrix4 childTransform = transform.clone();
    object.applyPaintTransform(child, childTransform);
    Rect childBounds = _calculateSubtreeBoundsHelper(child, childTransform);
    final Rect? paintClip = object.describeApproximatePaintClip(child);
    if (paintClip != null) {
      final Rect transformedPaintClip = MatrixUtils.transformRect(
        transform,
        paintClip,
      );
      childBounds = childBounds.intersect(transformedPaintClip);
    }

    if (childBounds.isFinite && !childBounds.isEmpty) {
      bounds =
          bounds.isEmpty ? childBounds : bounds.expandToInclude(childBounds);
    }
  });

  return bounds;
}

Rect _calculateSubtreeBounds(RenderObject object) {
  return _calculateSubtreeBoundsHelper(object, Matrix4.identity());
}

class _ScreenshotContainerLayer extends OffsetLayer {
  @override
  void addToScene(ui.SceneBuilder builder) {
    addChildrenToScene(builder);
  }
}

class _ScreenshotData {
  _ScreenshotData({
    required this.target,
  }) : containerLayer = _ScreenshotContainerLayer();

  final RenderObject target;

  final OffsetLayer containerLayer;

  bool foundTarget = false;

  bool includeInScreenshot = false;

  bool includeInRegularContext = true;

  Offset get screenshotOffset {
    assert(foundTarget);
    return containerLayer.offset;
  }

  set screenshotOffset(Offset offset) {
    containerLayer.offset = offset;
  }
}

class _ScreenshotPaintingContext extends PaintingContext {
  _ScreenshotPaintingContext({
    required ContainerLayer containerLayer,
    required Rect estimatedBounds,
    required _ScreenshotData screenshotData,
  })  : _data = screenshotData,
        super(containerLayer, estimatedBounds);

  final _ScreenshotData _data;

  // Recording state
  PictureLayer? _screenshotCurrentLayer;
  ui.PictureRecorder? _screenshotRecorder;
  Canvas? _screenshotCanvas;
  _MulticastCanvas? _multicastCanvas;

  @override
  Canvas get canvas {
    if (_data.includeInScreenshot) {
      if (_screenshotCanvas == null) {
        _startRecordingScreenshot();
      }
      assert(_screenshotCanvas != null);
      return _data.includeInRegularContext
          ? _multicastCanvas!
          : _screenshotCanvas!;
    } else {
      assert(_data.includeInRegularContext);
      return super.canvas;
    }
  }

  bool get _isScreenshotRecording {
    final bool hasScreenshotCanvas = _screenshotCanvas != null;
    assert(() {
      if (hasScreenshotCanvas) {
        assert(_screenshotCurrentLayer != null);
        assert(_screenshotRecorder != null);
        assert(_screenshotCanvas != null);
      } else {
        assert(_screenshotCurrentLayer == null);
        assert(_screenshotRecorder == null);
        assert(_screenshotCanvas == null);
      }
      return true;
    }());
    return hasScreenshotCanvas;
  }

  void _startRecordingScreenshot() {
    assert(_data.includeInScreenshot);
    assert(!_isScreenshotRecording);
    _screenshotCurrentLayer = PictureLayer(estimatedBounds);
    _screenshotRecorder = ui.PictureRecorder();
    _screenshotCanvas = Canvas(_screenshotRecorder!);
    _data.containerLayer.append(_screenshotCurrentLayer!);
    if (_data.includeInRegularContext) {
      _multicastCanvas = _MulticastCanvas(
        main: super.canvas,
        screenshot: _screenshotCanvas!,
      );
    } else {
      _multicastCanvas = null;
    }
  }

  @override
  void stopRecordingIfNeeded() {
    super.stopRecordingIfNeeded();
    _stopRecordingScreenshotIfNeeded();
  }

  void _stopRecordingScreenshotIfNeeded() {
    if (!_isScreenshotRecording) {
      return;
    }
    // There is no need to ever draw repaint rainbows as part of the screenshot.
    _screenshotCurrentLayer!.picture = _screenshotRecorder!.endRecording();
    _screenshotCurrentLayer = null;
    _screenshotRecorder = null;
    _multicastCanvas = null;
    _screenshotCanvas = null;
  }

  @override
  void appendLayer(Layer layer) {
    if (_data.includeInRegularContext) {
      super.appendLayer(layer);
      if (_data.includeInScreenshot) {
        assert(!_isScreenshotRecording);
        // We must use a proxy layer here as the layer is already attached to
        // the regular layer tree.
        _data.containerLayer.append(_ProxyLayer(layer));
      }
    } else {
      // Only record to the screenshot.
      assert(!_isScreenshotRecording);
      assert(_data.includeInScreenshot);
      layer.remove();
      _data.containerLayer.append(layer);
      return;
    }
  }

  @override
  PaintingContext createChildContext(ContainerLayer childLayer, Rect bounds) {
    if (_data.foundTarget) {
      // We have already found the screenshotTarget in the layer tree
      // so we can optimize and use a standard PaintingContext.
      return super.createChildContext(childLayer, bounds);
    } else {
      return _ScreenshotPaintingContext(
        containerLayer: childLayer,
        estimatedBounds: bounds,
        screenshotData: _data,
      );
    }
  }

  @override
  void paintChild(RenderObject child, Offset offset) {
    final bool isScreenshotTarget = identical(child, _data.target);
    if (isScreenshotTarget) {
      assert(!_data.includeInScreenshot);
      assert(!_data.foundTarget);
      _data.foundTarget = true;
      _data.screenshotOffset = offset;
      _data.includeInScreenshot = true;
    }
    super.paintChild(child, offset);
    if (isScreenshotTarget) {
      _stopRecordingScreenshotIfNeeded();
      _data.includeInScreenshot = false;
    }
  }

  static Future<ui.Image> toImage(
    RenderObject renderObject,
    Rect renderBounds, {
    double pixelRatio = 1.0,
    bool debugPaint = false,
  }) {
    RenderObject repaintBoundary = renderObject;
    while (!repaintBoundary.isRepaintBoundary) {
      repaintBoundary = repaintBoundary.parent!;
    }
    final _ScreenshotData data = _ScreenshotData(target: renderObject);
    final _ScreenshotPaintingContext context = _ScreenshotPaintingContext(
      containerLayer: repaintBoundary.debugLayer!,
      estimatedBounds: repaintBoundary.paintBounds,
      screenshotData: data,
    );

    if (identical(renderObject, repaintBoundary)) {
      // Painting the existing repaint boundary to the screenshot is sufficient.
      // We don't just take a direct screenshot of the repaint boundary as we
      // want to capture debugPaint information as well.
      data.containerLayer.append(_ProxyLayer(repaintBoundary.debugLayer!));
      data.foundTarget = true;
      final OffsetLayer offsetLayer =
          repaintBoundary.debugLayer! as OffsetLayer;
      data.screenshotOffset = offsetLayer.offset;
    } else {
      // Repaint everything under the repaint boundary.
      // We call debugInstrumentRepaintCompositedChild instead of paintChild as
      // we need to force everything under the repaint boundary to repaint.
      PaintingContext.debugInstrumentRepaintCompositedChild(
        repaintBoundary,
        customContext: context,
      );
    }

    // The check that debugPaintSizeEnabled is false exists to ensure we only
    // call debugPaint when it wasn't already called.
    if (debugPaint && !debugPaintSizeEnabled) {
      data.includeInRegularContext = false;
      // Existing recording may be to a canvas that draws to both the normal and
      // screenshot canvases.
      context.stopRecordingIfNeeded();
      assert(data.foundTarget);
      data.includeInScreenshot = true;

      debugPaintSizeEnabled = true;
      try {
        renderObject.debugPaint(context, data.screenshotOffset);
      } finally {
        debugPaintSizeEnabled = false;
        context.stopRecordingIfNeeded();
      }
    }

    // We must build the regular scene before we can build the screenshot
    // scene as building the screenshot scene assumes addToScene has already
    // been called successfully for all layers in the regular scene.
    repaintBoundary.debugLayer!.buildScene(ui.SceneBuilder());

    return data.containerLayer.toImage(renderBounds, pixelRatio: pixelRatio);
  }
}

class _DiagnosticsPathNode {
  _DiagnosticsPathNode({
    required this.node,
    required this.children,
    this.childIndex,
  });

  final DiagnosticsNode node;

  final List<DiagnosticsNode> children;

  final int? childIndex;
}

List<_DiagnosticsPathNode>? _followDiagnosticableChain(
  List<Diagnosticable> chain, {
  String? name,
  DiagnosticsTreeStyle? style,
}) {
  final List<_DiagnosticsPathNode> path = <_DiagnosticsPathNode>[];
  if (chain.isEmpty) {
    return path;
  }
  DiagnosticsNode diagnostic =
      chain.first.toDiagnosticsNode(name: name, style: style);
  for (int i = 1; i < chain.length; i += 1) {
    final Diagnosticable target = chain[i];
    bool foundMatch = false;
    final List<DiagnosticsNode> children = diagnostic.getChildren();
    for (int j = 0; j < children.length; j += 1) {
      final DiagnosticsNode child = children[j];
      if (child.value == target) {
        foundMatch = true;
        path.add(_DiagnosticsPathNode(
          node: diagnostic,
          children: children,
          childIndex: j,
        ));
        diagnostic = child;
        break;
      }
    }
    assert(foundMatch);
  }
  path.add(_DiagnosticsPathNode(
      node: diagnostic, children: diagnostic.getChildren()));
  return path;
}

typedef InspectorSelectionChangedCallback = void Function();

@visibleForTesting
class InspectorReferenceData {
  InspectorReferenceData(Object object, this.id) {
    // These types are not supported by [WeakReference].
    // See https://api.dart.dev/stable/3.0.2/dart-core/WeakReference-class.html
    if (object is String || object is num || object is bool) {
      _value = object;
      return;
    }

    _ref = WeakReference<Object>(object);
  }

  WeakReference<Object>? _ref;

  Object? _value;

  final String id;

  int count = 1;

  Object? get value {
    if (_ref != null) {
      return _ref!.target;
    }
    return _value;
  }
}

// Production implementation of [WidgetInspectorService].
class _WidgetInspectorService with WidgetInspectorService {
  _WidgetInspectorService() {
    selection.addListener(() {
      if (selectionChangedCallback != null) {
        selectionChangedCallback!();
      }
    });
  }
}

mixin WidgetInspectorService {
  final List<String?> _serializeRing = List<String?>.filled(20, null);
  int _serializeRingIndex = 0;

  static WidgetInspectorService get instance => _instance;
  static WidgetInspectorService _instance = _WidgetInspectorService();

  @visibleForTesting
  final ValueNotifier<bool> isSelectMode = ValueNotifier<bool>(true);

  @protected
  static set instance(WidgetInspectorService instance) {
    _instance = instance;
  }

  static bool _debugServiceExtensionsRegistered = false;

  final InspectorSelection selection = InspectorSelection();

  InspectorSelectionChangedCallback? selectionChangedCallback;

  final Map<String, Set<InspectorReferenceData>> _groups =
      <String, Set<InspectorReferenceData>>{};
  final Map<String, InspectorReferenceData> _idToReferenceData =
      <String, InspectorReferenceData>{};
  final WeakMap<Object, String> _objectToId = WeakMap<Object, String>();
  int _nextId = 0;

  List<String>? _pubRootDirectories;

  final HashMap<String, bool> _isLocalCreationCache = HashMap<String, bool>();

  bool _trackRebuildDirtyWidgets = false;
  bool _trackRepaintWidgets = false;

  @protected
  void registerServiceExtension({
    required String name,
    required ServiceExtensionCallback callback,
    required RegisterServiceExtensionCallback registerExtension,
  }) {
    registerExtension(
      name: 'inspector.$name',
      callback: callback,
    );
  }

  void _registerSignalServiceExtension({
    required String name,
    required FutureOr<Object?> Function() callback,
    required RegisterServiceExtensionCallback registerExtension,
  }) {
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        return <String, Object?>{'result': await callback()};
      },
      registerExtension: registerExtension,
    );
  }

  void _registerObjectGroupServiceExtension({
    required String name,
    required FutureOr<Object?> Function(String objectGroup) callback,
    required RegisterServiceExtensionCallback registerExtension,
  }) {
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        return <String, Object?>{
          'result': await callback(parameters['objectGroup']!)
        };
      },
      registerExtension: registerExtension,
    );
  }

  void _registerBoolServiceExtension({
    required String name,
    required AsyncValueGetter<bool> getter,
    required AsyncValueSetter<bool> setter,
    required RegisterServiceExtensionCallback registerExtension,
  }) {
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (parameters.containsKey('enabled')) {
          final bool value = parameters['enabled'] == 'true';
          await setter(value);
          _postExtensionStateChangedEvent(name, value);
        }
        return <String, dynamic>{'enabled': await getter() ? 'true' : 'false'};
      },
      registerExtension: registerExtension,
    );
  }

  void _postExtensionStateChangedEvent(String name, Object? value) {
    postEvent(
      'Flutter.ServiceExtensionStateChanged',
      <String, Object?>{
        'extension': 'ext.flutter.inspector.$name',
        'value': value,
      },
    );
  }

  void _registerServiceExtensionWithArg({
    required String name,
    required FutureOr<Object?> Function(String? objectId, String objectGroup)
        callback,
    required RegisterServiceExtensionCallback registerExtension,
  }) {
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        assert(parameters.containsKey('objectGroup'));
        return <String, Object?>{
          'result':
              await callback(parameters['arg'], parameters['objectGroup']!),
        };
      },
      registerExtension: registerExtension,
    );
  }

  void _registerServiceExtensionVarArgs({
    required String name,
    required FutureOr<Object?> Function(List<String> args) callback,
    required RegisterServiceExtensionCallback registerExtension,
  }) {
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        final List<String> args = <String>[];
        int index = 0;
        while (true) {
          final String name = 'arg$index';
          if (parameters.containsKey(name)) {
            args.add(parameters[name]!);
          } else {
            break;
          }
          index++;
        }
        // Verify that the only arguments other than perhaps 'isolateId' are
        // arguments we have already handled.
        assert(index == parameters.length ||
            (index == parameters.length - 1 &&
                parameters.containsKey('isolateId')));
        return <String, Object?>{'result': await callback(args)};
      },
      registerExtension: registerExtension,
    );
  }

  @protected
  Future<void> forceRebuild() {
    final WidgetsBinding binding = WidgetsBinding.instance;
    if (binding.rootElement != null) {
      binding.buildOwner!.reassemble(binding.rootElement!);
      return binding.endOfFrame;
    }
    return Future<void>.value();
  }

  static const String _consoleObjectGroup = 'console-group';

  int _errorsSinceReload = 0;

  void _reportStructuredError(FlutterErrorDetails details) {
    final Map<String, Object?> errorJson = _nodeToJson(
      details.toDiagnosticsNode(),
      InspectorSerializationDelegate(
        groupName: _consoleObjectGroup,
        subtreeDepth: 5,
        includeProperties: true,
        maxDescendantsTruncatableNode: 5,
        service: this,
      ),
    )!;

    errorJson['errorsSinceReload'] = _errorsSinceReload;
    if (_errorsSinceReload == 0) {
      errorJson['renderedErrorText'] = TextTreeRenderer(
        wrapWidthProperties: FlutterError.wrapWidth,
        maxDescendentsTruncatableNode: 5,
      )
          .render(details.toDiagnosticsNode(style: DiagnosticsTreeStyle.error))
          .trimRight();
    } else {
      errorJson['renderedErrorText'] =
          'Another exception was thrown: ${details.summary}';
    }

    _errorsSinceReload += 1;
    postEvent('Flutter.Error', errorJson);
  }

  void _resetErrorCount() {
    _errorsSinceReload = 0;
  }

  bool isStructuredErrorsEnabled() {
    // This is a debug mode only feature and will default to false for
    // profile mode.
    bool enabled = false;
    assert(() {
      // TODO(kenz): add support for structured errors on the web.
      enabled = const bool.fromEnvironment('flutter.inspector.structuredErrors',
          defaultValue: !kIsWeb);
      return true;
    }());
    return enabled;
  }

  void initServiceExtensions(
      RegisterServiceExtensionCallback registerExtension) {
    final FlutterExceptionHandler defaultExceptionHandler =
        FlutterError.presentError;

    if (isStructuredErrorsEnabled()) {
      FlutterError.presentError = _reportStructuredError;
    }
    assert(!_debugServiceExtensionsRegistered);
    assert(() {
      _debugServiceExtensionsRegistered = true;
      return true;
    }());

    SchedulerBinding.instance.addPersistentFrameCallback(_onFrameStart);

    _registerBoolServiceExtension(
      name: WidgetInspectorServiceExtensions.structuredErrors.name,
      getter: () async => FlutterError.presentError == _reportStructuredError,
      setter: (bool value) {
        FlutterError.presentError =
            value ? _reportStructuredError : defaultExceptionHandler;
        return Future<void>.value();
      },
      registerExtension: registerExtension,
    );

    _registerBoolServiceExtension(
      name: WidgetInspectorServiceExtensions.show.name,
      getter: () async => WidgetsApp.debugShowWidgetInspectorOverride,
      setter: (bool value) {
        if (WidgetsApp.debugShowWidgetInspectorOverride == value) {
          return Future<void>.value();
        }
        WidgetsApp.debugShowWidgetInspectorOverride = value;
        return forceRebuild();
      },
      registerExtension: registerExtension,
    );

    if (isWidgetCreationTracked()) {
      // Service extensions that are only supported if widget creation locations
      // are tracked.
      _registerBoolServiceExtension(
        name: WidgetInspectorServiceExtensions.trackRebuildDirtyWidgets.name,
        getter: () async => _trackRebuildDirtyWidgets,
        setter: (bool value) async {
          if (value == _trackRebuildDirtyWidgets) {
            return;
          }
          _rebuildStats.resetCounts();
          _trackRebuildDirtyWidgets = value;
          if (value) {
            assert(debugOnRebuildDirtyWidget == null);
            debugOnRebuildDirtyWidget = _onRebuildWidget;
            // Trigger a rebuild so there are baseline stats for rebuilds
            // performed by the app.
            await forceRebuild();
            return;
          } else {
            debugOnRebuildDirtyWidget = null;
            return;
          }
        },
        registerExtension: registerExtension,
      );

      _registerBoolServiceExtension(
        name: WidgetInspectorServiceExtensions.trackRepaintWidgets.name,
        getter: () async => _trackRepaintWidgets,
        setter: (bool value) async {
          if (value == _trackRepaintWidgets) {
            return;
          }
          _repaintStats.resetCounts();
          _trackRepaintWidgets = value;
          if (value) {
            assert(debugOnProfilePaint == null);
            debugOnProfilePaint = _onPaint;
            // Trigger an immediate paint so the user has some baseline painting
            // stats to view.
            void markTreeNeedsPaint(RenderObject renderObject) {
              renderObject.markNeedsPaint();
              renderObject.visitChildren(markTreeNeedsPaint);
            }

            RendererBinding.instance.renderViews.forEach(markTreeNeedsPaint);
          } else {
            debugOnProfilePaint = null;
          }
        },
        registerExtension: registerExtension,
      );
    }

    _registerSignalServiceExtension(
      name: WidgetInspectorServiceExtensions.disposeAllGroups.name,
      callback: () async {
        disposeAllGroups();
        return null;
      },
      registerExtension: registerExtension,
    );
    _registerObjectGroupServiceExtension(
      name: WidgetInspectorServiceExtensions.disposeGroup.name,
      callback: (String name) async {
        disposeGroup(name);
        return null;
      },
      registerExtension: registerExtension,
    );
    _registerSignalServiceExtension(
      name: WidgetInspectorServiceExtensions.isWidgetTreeReady.name,
      callback: isWidgetTreeReady,
      registerExtension: registerExtension,
    );
    _registerServiceExtensionWithArg(
      name: WidgetInspectorServiceExtensions.disposeId.name,
      callback: (String? objectId, String objectGroup) async {
        disposeId(objectId, objectGroup);
        return null;
      },
      registerExtension: registerExtension,
    );
    _registerServiceExtensionVarArgs(
      name: WidgetInspectorServiceExtensions.setPubRootDirectories.name,
      callback: (List<String> args) async {
        setPubRootDirectories(args);
        return null;
      },
      registerExtension: registerExtension,
    );
    _registerServiceExtensionVarArgs(
      name: WidgetInspectorServiceExtensions.addPubRootDirectories.name,
      callback: (List<String> args) async {
        addPubRootDirectories(args);
        return null;
      },
      registerExtension: registerExtension,
    );
    _registerServiceExtensionVarArgs(
      name: WidgetInspectorServiceExtensions.removePubRootDirectories.name,
      callback: (List<String> args) async {
        removePubRootDirectories(args);
        return null;
      },
      registerExtension: registerExtension,
    );
    registerServiceExtension(
      name: WidgetInspectorServiceExtensions.getPubRootDirectories.name,
      callback: pubRootDirectories,
      registerExtension: registerExtension,
    );
    _registerServiceExtensionWithArg(
      name: WidgetInspectorServiceExtensions.setSelectionById.name,
      callback: setSelectionById,
      registerExtension: registerExtension,
    );
    _registerServiceExtensionWithArg(
      name: WidgetInspectorServiceExtensions.getParentChain.name,
      callback: _getParentChain,
      registerExtension: registerExtension,
    );
    _registerServiceExtensionWithArg(
      name: WidgetInspectorServiceExtensions.getProperties.name,
      callback: _getProperties,
      registerExtension: registerExtension,
    );
    _registerServiceExtensionWithArg(
      name: WidgetInspectorServiceExtensions.getChildren.name,
      callback: _getChildren,
      registerExtension: registerExtension,
    );

    _registerServiceExtensionWithArg(
      name: WidgetInspectorServiceExtensions.getChildrenSummaryTree.name,
      callback: _getChildrenSummaryTree,
      registerExtension: registerExtension,
    );

    _registerServiceExtensionWithArg(
      name: WidgetInspectorServiceExtensions.getChildrenDetailsSubtree.name,
      callback: _getChildrenDetailsSubtree,
      registerExtension: registerExtension,
    );

    _registerObjectGroupServiceExtension(
      name: WidgetInspectorServiceExtensions.getRootWidget.name,
      callback: _getRootWidget,
      registerExtension: registerExtension,
    );
    _registerObjectGroupServiceExtension(
      name: WidgetInspectorServiceExtensions.getRootWidgetSummaryTree.name,
      callback: _getRootWidgetSummaryTree,
      registerExtension: registerExtension,
    );
    registerServiceExtension(
      name: WidgetInspectorServiceExtensions
          .getRootWidgetSummaryTreeWithPreviews.name,
      callback: _getRootWidgetSummaryTreeWithPreviews,
      registerExtension: registerExtension,
    );
    registerServiceExtension(
      name: WidgetInspectorServiceExtensions.getDetailsSubtree.name,
      callback: (Map<String, String> parameters) async {
        assert(parameters.containsKey('objectGroup'));
        final String? subtreeDepth = parameters['subtreeDepth'];
        return <String, Object?>{
          'result': _getDetailsSubtree(
            parameters['arg'],
            parameters['objectGroup'],
            subtreeDepth != null ? int.parse(subtreeDepth) : 2,
          ),
        };
      },
      registerExtension: registerExtension,
    );
    _registerServiceExtensionWithArg(
      name: WidgetInspectorServiceExtensions.getSelectedWidget.name,
      callback: _getSelectedWidget,
      registerExtension: registerExtension,
    );
    _registerServiceExtensionWithArg(
      name: WidgetInspectorServiceExtensions.getSelectedSummaryWidget.name,
      callback: _getSelectedSummaryWidget,
      registerExtension: registerExtension,
    );

    _registerSignalServiceExtension(
      name: WidgetInspectorServiceExtensions.isWidgetCreationTracked.name,
      callback: isWidgetCreationTracked,
      registerExtension: registerExtension,
    );
    registerServiceExtension(
      name: WidgetInspectorServiceExtensions.screenshot.name,
      callback: (Map<String, String> parameters) async {
        assert(parameters.containsKey('id'));
        assert(parameters.containsKey('width'));
        assert(parameters.containsKey('height'));

        final ui.Image? image = await screenshot(
          toObject(parameters['id']),
          width: double.parse(parameters['width']!),
          height: double.parse(parameters['height']!),
          margin: parameters.containsKey('margin')
              ? double.parse(parameters['margin']!)
              : 0.0,
          maxPixelRatio: parameters.containsKey('maxPixelRatio')
              ? double.parse(parameters['maxPixelRatio']!)
              : 1.0,
          debugPaint: parameters['debugPaint'] == 'true',
        );
        if (image == null) {
          return <String, Object?>{'result': null};
        }
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        return <String, Object>{
          'result': base64.encoder.convert(Uint8List.view(byteData!.buffer)),
        };
      },
      registerExtension: registerExtension,
    );
    registerServiceExtension(
      name: WidgetInspectorServiceExtensions.getLayoutExplorerNode.name,
      callback: _getLayoutExplorerNode,
      registerExtension: registerExtension,
    );
    registerServiceExtension(
      name: WidgetInspectorServiceExtensions.setFlexFit.name,
      callback: _setFlexFit,
      registerExtension: registerExtension,
    );
    registerServiceExtension(
      name: WidgetInspectorServiceExtensions.setFlexFactor.name,
      callback: _setFlexFactor,
      registerExtension: registerExtension,
    );
    registerServiceExtension(
      name: WidgetInspectorServiceExtensions.setFlexProperties.name,
      callback: _setFlexProperties,
      registerExtension: registerExtension,
    );
  }

  void _clearStats() {
    _rebuildStats.resetCounts();
    _repaintStats.resetCounts();
  }

  @visibleForTesting
  @protected
  void disposeAllGroups() {
    _groups.clear();
    _idToReferenceData.clear();
    _objectToId.clear();
    _nextId = 0;
  }

  @visibleForTesting
  @protected
  @mustCallSuper
  void resetAllState() {
    disposeAllGroups();
    selection.clear();
    resetPubRootDirectories();
  }

  @protected
  void disposeGroup(String name) {
    final Set<InspectorReferenceData>? references = _groups.remove(name);
    if (references == null) {
      return;
    }
    references.forEach(_decrementReferenceCount);
  }

  void _decrementReferenceCount(InspectorReferenceData reference) {
    reference.count -= 1;
    assert(reference.count >= 0);
    if (reference.count == 0) {
      final Object? value = reference.value;
      if (value != null) {
        _objectToId.remove(value);
      }
      _idToReferenceData.remove(reference.id);
    }
  }

  @protected
  String? toId(Object? object, String groupName) {
    if (object == null) {
      return null;
    }

    final Set<InspectorReferenceData> group = _groups.putIfAbsent(
        groupName, () => Set<InspectorReferenceData>.identity());
    String? id = _objectToId[object];
    InspectorReferenceData referenceData;
    if (id == null) {
      // TODO(polina-c): comment here why we increase memory footprint by the prefix 'inspector-'.
      // https://github.com/flutter/devtools/issues/5995
      id = 'inspector-$_nextId';
      _nextId += 1;
      _objectToId[object] = id;
      referenceData = InspectorReferenceData(object, id);
      _idToReferenceData[id] = referenceData;
      group.add(referenceData);
    } else {
      referenceData = _idToReferenceData[id]!;
      if (group.add(referenceData)) {
        referenceData.count += 1;
      }
    }
    return id;
  }

  @protected
  bool isWidgetTreeReady([String? groupName]) {
    return WidgetsBinding.instance.debugDidSendFirstFrameEvent;
  }

  @protected
  Object? toObject(String? id, [String? groupName]) {
    if (id == null) {
      return null;
    }

    final InspectorReferenceData? data = _idToReferenceData[id];
    if (data == null) {
      throw FlutterError.fromParts(
          <DiagnosticsNode>[ErrorSummary('Id does not exist.')]);
    }
    return data.value;
  }

  @protected
  Object? toObjectForSourceLocation(String id, [String? groupName]) {
    final Object? object = toObject(id);
    if (object is Element) {
      return object.widget;
    }
    return object;
  }

  @protected
  void disposeId(String? id, String groupName) {
    if (id == null) {
      return;
    }

    final InspectorReferenceData? referenceData = _idToReferenceData[id];
    if (referenceData == null) {
      throw FlutterError.fromParts(
          <DiagnosticsNode>[ErrorSummary('Id does not exist')]);
    }
    if (_groups[groupName]?.remove(referenceData) != true) {
      throw FlutterError.fromParts(
          <DiagnosticsNode>[ErrorSummary('Id is not in group')]);
    }
    _decrementReferenceCount(referenceData);
  }

  @protected
  @Deprecated(
    'Use addPubRootDirectories instead. '
    'This feature was deprecated after v3.1.0-9.0.pre.',
  )
  void setPubRootDirectories(List<String> pubRootDirectories) {
    addPubRootDirectories(pubRootDirectories);
  }

  @visibleForTesting
  @protected
  void resetPubRootDirectories() {
    _pubRootDirectories = <String>[];
    _isLocalCreationCache.clear();
  }

  @protected
  void addPubRootDirectories(List<String> pubRootDirectories) {
    pubRootDirectories = pubRootDirectories
        .map<String>((String directory) => Uri.parse(directory).path)
        .toList();

    final Set<String> directorySet = Set<String>.from(pubRootDirectories);
    if (_pubRootDirectories != null) {
      directorySet.addAll(_pubRootDirectories!);
    }

    _pubRootDirectories = directorySet.toList();
    _isLocalCreationCache.clear();
  }

  @protected
  void removePubRootDirectories(List<String> pubRootDirectories) {
    if (_pubRootDirectories == null) {
      return;
    }
    pubRootDirectories = pubRootDirectories
        .map<String>((String directory) => Uri.parse(directory).path)
        .toList();

    final Set<String> directorySet = Set<String>.from(_pubRootDirectories!);
    directorySet.removeAll(pubRootDirectories);

    _pubRootDirectories = directorySet.toList();
    _isLocalCreationCache.clear();
  }

  @protected
  @visibleForTesting
  Future<Map<String, dynamic>> pubRootDirectories(
    Map<String, String> parameters,
  ) {
    return Future<Map<String, Object>>.value(<String, Object>{
      'result': _pubRootDirectories ?? <String>[],
    });
  }

  @protected
  bool setSelectionById(String? id, [String? groupName]) {
    return setSelection(toObject(id), groupName);
  }

  @protected
  bool setSelection(Object? object, [String? groupName]) {
    if (object is Element || object is RenderObject) {
      if (object is Element) {
        if (object == selection.currentElement) {
          return false;
        }
        selection.currentElement = object;
        _sendInspectEvent(selection.currentElement);
      } else {
        if (object == selection.current) {
          return false;
        }
        selection.current = object! as RenderObject;
        _sendInspectEvent(selection.current);
      }

      return true;
    }
    return false;
  }

  void _sendInspectEvent(Object? object) {
    inspect(object);

    final _Location? location = _getSelectedSummaryWidgetLocation(null);
    if (location != null) {
      postEvent(
        'navigate',
        <String, Object>{
          'fileUri': location.file, // URI file path of the location.
          'line': location.line, // 1-based line number.
          'column': location.column, // 1-based column number.
          'source': 'flutter.inspector',
        },
        stream: 'ToolEvent',
      );
    }
  }

  String? _devToolsInspectorUriForElement(Element element) {
    if (activeDevToolsServerAddress != null && connectedVmServiceUri != null) {
      final String? inspectorRef = toId(element, _consoleObjectGroup);
      if (inspectorRef != null) {
        return devToolsInspectorUri(inspectorRef);
      }
    }
    return null;
  }

  @visibleForTesting
  String devToolsInspectorUri(String inspectorRef) {
    assert(activeDevToolsServerAddress != null);
    assert(connectedVmServiceUri != null);

    final Uri uri = Uri.parse(activeDevToolsServerAddress!).replace(
      queryParameters: <String, dynamic>{
        'uri': connectedVmServiceUri,
        'inspectorRef': inspectorRef,
      },
    );

    // We cannot add the '/#/inspector' path by means of
    // [Uri.replace(path: '/#/inspector')] because the '#' character will be
    // encoded when we try to print the url as a string. DevTools will not
    // load properly if this character is encoded in the url.
    // Related: https://github.com/flutter/devtools/issues/2475.
    final String devToolsInspectorUri = uri.toString();
    final int startQueryParamIndex = devToolsInspectorUri.indexOf('?');
    // The query parameter character '?' should be present because we manually
    // added query parameters above.
    assert(startQueryParamIndex != -1);
    return '${devToolsInspectorUri.substring(0, startQueryParamIndex)}'
        '/#/inspector'
        '${devToolsInspectorUri.substring(startQueryParamIndex)}';
  }

  @protected
  String getParentChain(String id, String groupName) {
    return _safeJsonEncode(_getParentChain(id, groupName));
  }

  List<Object?> _getParentChain(String? id, String groupName) {
    final Object? value = toObject(id);
    List<_DiagnosticsPathNode> path;
    if (value is RenderObject) {
      path = _getRenderObjectParentChain(value, groupName)!;
    } else if (value is Element) {
      path = _getElementParentChain(value, groupName);
    } else {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
            'Cannot get parent chain for node of type ${value.runtimeType}')
      ]);
    }

    return path
        .map<Object?>((_DiagnosticsPathNode node) => _pathNodeToJson(
              node,
              InspectorSerializationDelegate(
                  groupName: groupName, service: this),
            ))
        .toList();
  }

  Map<String, Object?>? _pathNodeToJson(
      _DiagnosticsPathNode? pathNode, InspectorSerializationDelegate delegate) {
    if (pathNode == null) {
      return null;
    }
    return <String, Object?>{
      'node': _nodeToJson(pathNode.node, delegate),
      'children':
          _nodesToJson(pathNode.children, delegate, parent: pathNode.node),
      'childIndex': pathNode.childIndex,
    };
  }

  List<Element> _getRawElementParentChain(Element element,
      {required int? numLocalParents}) {
    List<Element> elements = element.debugGetDiagnosticChain();
    if (numLocalParents != null) {
      for (int i = 0; i < elements.length; i += 1) {
        if (_isValueCreatedByLocalProject(elements[i])) {
          numLocalParents = numLocalParents! - 1;
          if (numLocalParents <= 0) {
            elements = elements.take(i + 1).toList();
            break;
          }
        }
      }
    }
    return elements.reversed.toList();
  }

  List<_DiagnosticsPathNode> _getElementParentChain(
      Element element, String groupName,
      {int? numLocalParents}) {
    return _followDiagnosticableChain(
          _getRawElementParentChain(element, numLocalParents: numLocalParents),
        ) ??
        const <_DiagnosticsPathNode>[];
  }

  List<_DiagnosticsPathNode>? _getRenderObjectParentChain(
      RenderObject? renderObject, String groupName) {
    final List<RenderObject> chain = <RenderObject>[];
    while (renderObject != null) {
      chain.add(renderObject);
      renderObject = renderObject.parent;
    }
    return _followDiagnosticableChain(chain.reversed.toList());
  }

  Map<String, Object?>? _nodeToJson(
    DiagnosticsNode? node,
    InspectorSerializationDelegate delegate,
  ) {
    return node?.toJsonMap(delegate);
  }

  bool _isValueCreatedByLocalProject(Object? value) {
    final _Location? creationLocation = _getCreationLocation(value);
    if (creationLocation == null) {
      return false;
    }
    return _isLocalCreationLocation(creationLocation.file);
  }

  bool _isLocalCreationLocationImpl(String locationUri) {
    final String file = Uri.parse(locationUri).path;

    // By default check whether the creation location was within package:flutter.
    if (_pubRootDirectories == null) {
      // TODO(chunhtai): Make it more robust once
      // https://github.com/flutter/flutter/issues/32660 is fixed.
      return !file.contains('packages/flutter/');
    }
    for (final String directory in _pubRootDirectories!) {
      if (file.startsWith(directory)) {
        return true;
      }
    }
    return false;
  }

  bool _isLocalCreationLocation(String locationUri) {
    final bool? cachedValue = _isLocalCreationCache[locationUri];
    if (cachedValue != null) {
      return cachedValue;
    }
    final bool result = _isLocalCreationLocationImpl(locationUri);
    _isLocalCreationCache[locationUri] = result;
    return result;
  }

  //
  // TODO(jacobr): Replace this with a better solution once
  // https://github.com/dart-lang/sdk/issues/32919 is fixed.
  String _safeJsonEncode(Object? object) {
    final String jsonString = json.encode(object);
    _serializeRing[_serializeRingIndex] = jsonString;
    _serializeRingIndex = (_serializeRingIndex + 1) % _serializeRing.length;
    return jsonString;
  }

  List<DiagnosticsNode> _truncateNodes(
      Iterable<DiagnosticsNode> nodes, int maxDescendentsTruncatableNode) {
    if (nodes.every((DiagnosticsNode node) => node.value is Element) &&
        isWidgetCreationTracked()) {
      final List<DiagnosticsNode> localNodes = nodes
          .where((DiagnosticsNode node) =>
              _isValueCreatedByLocalProject(node.value))
          .toList();
      if (localNodes.isNotEmpty) {
        return localNodes;
      }
    }
    return nodes.take(maxDescendentsTruncatableNode).toList();
  }

  List<Map<String, Object?>> _nodesToJson(
    List<DiagnosticsNode> nodes,
    InspectorSerializationDelegate delegate, {
    required DiagnosticsNode? parent,
  }) {
    return DiagnosticsNode.toJsonList(nodes, parent, delegate);
  }

  @protected
  String getProperties(String diagnosticsNodeId, String groupName) {
    return _safeJsonEncode(_getProperties(diagnosticsNodeId, groupName));
  }

  List<Object> _getProperties(String? diagnosticableId, String groupName) {
    final DiagnosticsNode? node = _idToDiagnosticsNode(diagnosticableId);
    if (node == null) {
      return const <Object>[];
    }
    return _nodesToJson(node.getProperties(),
        InspectorSerializationDelegate(groupName: groupName, service: this),
        parent: node);
  }

  String getChildren(String diagnosticsNodeId, String groupName) {
    return _safeJsonEncode(_getChildren(diagnosticsNodeId, groupName));
  }

  List<Object> _getChildren(String? diagnosticsNodeId, String groupName) {
    final DiagnosticsNode? node =
        toObject(diagnosticsNodeId) as DiagnosticsNode?;
    final InspectorSerializationDelegate delegate =
        InspectorSerializationDelegate(groupName: groupName, service: this);
    return _nodesToJson(
        node == null
            ? const <DiagnosticsNode>[]
            : _getChildrenFiltered(node, delegate),
        delegate,
        parent: node);
  }

  String getChildrenSummaryTree(String diagnosticsNodeId, String groupName) {
    return _safeJsonEncode(
        _getChildrenSummaryTree(diagnosticsNodeId, groupName));
  }

  DiagnosticsNode? _idToDiagnosticsNode(String? diagnosticableId) {
    final Object? object = toObject(diagnosticableId);
    return objectToDiagnosticsNode(object);
  }

  @visibleForTesting
  static DiagnosticsNode? objectToDiagnosticsNode(Object? object) {
    if (object is Diagnosticable) {
      return object.toDiagnosticsNode();
    }
    return null;
  }

  List<Object> _getChildrenSummaryTree(
      String? diagnosticableId, String groupName) {
    final DiagnosticsNode? node = _idToDiagnosticsNode(diagnosticableId);
    if (node == null) {
      return <Object>[];
    }

    final InspectorSerializationDelegate delegate =
        InspectorSerializationDelegate(
            groupName: groupName, summaryTree: true, service: this);
    return _nodesToJson(_getChildrenFiltered(node, delegate), delegate,
        parent: node);
  }

  String getChildrenDetailsSubtree(String diagnosticableId, String groupName) {
    return _safeJsonEncode(
        _getChildrenDetailsSubtree(diagnosticableId, groupName));
  }

  List<Object> _getChildrenDetailsSubtree(
      String? diagnosticableId, String groupName) {
    final DiagnosticsNode? node = _idToDiagnosticsNode(diagnosticableId);
    // With this value of minDepth we only expand one extra level of important nodes.
    final InspectorSerializationDelegate delegate =
        InspectorSerializationDelegate(
            groupName: groupName, includeProperties: true, service: this);
    return _nodesToJson(
        node == null
            ? const <DiagnosticsNode>[]
            : _getChildrenFiltered(node, delegate),
        delegate,
        parent: node);
  }

  bool _shouldShowInSummaryTree(DiagnosticsNode node) {
    if (node.level == DiagnosticLevel.error) {
      return true;
    }
    final Object? value = node.value;
    if (value is! Diagnosticable) {
      return true;
    }
    if (value is! Element || !isWidgetCreationTracked()) {
      // Creation locations are not available so include all nodes in the
      // summary tree.
      return true;
    }
    return _isValueCreatedByLocalProject(value);
  }

  List<DiagnosticsNode> _getChildrenFiltered(
    DiagnosticsNode node,
    InspectorSerializationDelegate delegate,
  ) {
    return _filterChildren(node.getChildren(), delegate);
  }

  List<DiagnosticsNode> _filterChildren(
    List<DiagnosticsNode> nodes,
    InspectorSerializationDelegate delegate,
  ) {
    final List<DiagnosticsNode> children = <DiagnosticsNode>[
      for (final DiagnosticsNode child in nodes)
        if (!delegate.summaryTree || _shouldShowInSummaryTree(child))
          child
        else
          ..._getChildrenFiltered(child, delegate),
    ];
    return children;
  }

  String getRootWidget(String groupName) {
    return _safeJsonEncode(_getRootWidget(groupName));
  }

  Map<String, Object?>? _getRootWidget(String groupName) {
    return _nodeToJson(WidgetsBinding.instance.rootElement?.toDiagnosticsNode(),
        InspectorSerializationDelegate(groupName: groupName, service: this));
  }

  String getRootWidgetSummaryTree(String groupName) {
    return _safeJsonEncode(_getRootWidgetSummaryTree(groupName));
  }

  Map<String, Object?>? _getRootWidgetSummaryTree(
    String groupName, {
    Map<String, Object>? Function(
            DiagnosticsNode, InspectorSerializationDelegate)?
        addAdditionalPropertiesCallback,
  }) {
    return _nodeToJson(
      WidgetsBinding.instance.rootElement?.toDiagnosticsNode(),
      InspectorSerializationDelegate(
        groupName: groupName,
        subtreeDepth: 1000000,
        summaryTree: true,
        service: this,
        addAdditionalPropertiesCallback: addAdditionalPropertiesCallback,
      ),
    );
  }

  Future<Map<String, Object?>> _getRootWidgetSummaryTreeWithPreviews(
    Map<String, String> parameters,
  ) {
    final String groupName = parameters['groupName']!;
    final Map<String, Object?>? result = _getRootWidgetSummaryTree(
      groupName,
      addAdditionalPropertiesCallback:
          (DiagnosticsNode node, InspectorSerializationDelegate? delegate) {
        final Map<String, Object> additionalJson = <String, Object>{};
        final Object? value = node.value;
        if (value is Element) {
          final RenderObject? renderObject = value.renderObject;
          if (renderObject is RenderParagraph) {
            additionalJson['textPreview'] = renderObject.text.toPlainText();
          }
        }
        return additionalJson;
      },
    );
    return Future<Map<String, dynamic>>.value(<String, dynamic>{
      'result': result,
    });
  }

  String getDetailsSubtree(
    String diagnosticableId,
    String groupName, {
    int subtreeDepth = 2,
  }) {
    return _safeJsonEncode(
        _getDetailsSubtree(diagnosticableId, groupName, subtreeDepth));
  }

  Map<String, Object?>? _getDetailsSubtree(
    String? diagnosticableId,
    String? groupName,
    int subtreeDepth,
  ) {
    final DiagnosticsNode? root = _idToDiagnosticsNode(diagnosticableId);
    if (root == null) {
      return null;
    }
    return _nodeToJson(
      root,
      InspectorSerializationDelegate(
        groupName: groupName,
        subtreeDepth: subtreeDepth,
        includeProperties: true,
        service: this,
      ),
    );
  }

  @protected
  String getSelectedWidget(String? previousSelectionId, String groupName) {
    if (previousSelectionId != null) {
      debugPrint('previousSelectionId is deprecated in API');
    }
    return _safeJsonEncode(_getSelectedWidget(null, groupName));
  }

  @protected
  Future<ui.Image?> screenshot(
    Object? object, {
    required double width,
    required double height,
    double margin = 0.0,
    double maxPixelRatio = 1.0,
    bool debugPaint = false,
  }) async {
    if (object is! Element && object is! RenderObject) {
      return null;
    }
    final RenderObject? renderObject =
        object is Element ? object.renderObject : (object as RenderObject?);
    if (renderObject == null || !renderObject.attached) {
      return null;
    }

    if (renderObject.debugNeedsLayout) {
      final PipelineOwner owner = renderObject.owner!;
      assert(!owner.debugDoingLayout);
      owner
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();

      // If we still need layout, then that means that renderObject was skipped
      // in the layout phase and therefore can't be painted. It is clearer to
      // return null indicating that a screenshot is unavailable than to return
      // an empty image.
      if (renderObject.debugNeedsLayout) {
        return null;
      }
    }

    Rect renderBounds = _calculateSubtreeBounds(renderObject);
    if (margin != 0.0) {
      renderBounds = renderBounds.inflate(margin);
    }
    if (renderBounds.isEmpty) {
      return null;
    }

    final double pixelRatio = math.min(
      maxPixelRatio,
      math.min(
        width / renderBounds.width,
        height / renderBounds.height,
      ),
    );

    return _ScreenshotPaintingContext.toImage(
      renderObject,
      renderBounds,
      pixelRatio: pixelRatio,
      debugPaint: debugPaint,
    );
  }

  Future<Map<String, Object?>> _getLayoutExplorerNode(
    Map<String, String> parameters,
  ) {
    final String? diagnosticableId = parameters['id'];
    final int subtreeDepth = int.parse(parameters['subtreeDepth']!);
    final String? groupName = parameters['groupName'];
    Map<String, dynamic>? result = <String, dynamic>{};
    final DiagnosticsNode? root = _idToDiagnosticsNode(diagnosticableId);
    if (root == null) {
      return Future<Map<String, dynamic>>.value(<String, dynamic>{
        'result': result,
      });
    }
    result = _nodeToJson(
      root,
      InspectorSerializationDelegate(
        groupName: groupName,
        summaryTree: true,
        subtreeDepth: subtreeDepth,
        service: this,
        addAdditionalPropertiesCallback:
            (DiagnosticsNode node, InspectorSerializationDelegate delegate) {
          final Object? value = node.value;
          final RenderObject? renderObject =
              value is Element ? value.renderObject : null;
          if (renderObject == null) {
            return const <String, Object>{};
          }

          final DiagnosticsSerializationDelegate
              renderObjectSerializationDelegate = delegate.copyWith(
            subtreeDepth: 0,
            includeProperties: true,
            expandPropertyValues: false,
          );
          final Map<String, Object> additionalJson = <String, Object>{
            // Only include renderObject properties separately if this value is not already the renderObject.
            // Only include if we are expanding property values to mitigate the risk of infinite loops if
            // RenderObjects have properties that are Element objects.
            if (value is! RenderObject && delegate.expandPropertyValues)
              'renderObject': renderObject
                  .toDiagnosticsNode()
                  .toJsonMap(renderObjectSerializationDelegate),
          };

          final RenderObject? renderParent = renderObject.parent;
          if (renderParent != null &&
              delegate.subtreeDepth > 0 &&
              delegate.expandPropertyValues) {
            final Object? parentCreator = renderParent.debugCreator;
            if (parentCreator is DebugCreator) {
              additionalJson['parentRenderElement'] =
                  parentCreator.element.toDiagnosticsNode().toJsonMap(
                        delegate.copyWith(
                          subtreeDepth: 0,
                          includeProperties: true,
                        ),
                      );
              // TODO(jacobr): also describe the path back up the tree to
              // the RenderParentElement from the current element. It
              // could be a surprising distance up the tree if a lot of
              // elements don't have their own RenderObjects.
            }
          }

          try {
            if (!renderObject.debugNeedsLayout) {
              // ignore: invalid_use_of_protected_member
              final Constraints constraints = renderObject.constraints;
              final Map<String, Object> constraintsProperty = <String, Object>{
                'type': constraints.runtimeType.toString(),
                'description': constraints.toString(),
              };
              if (constraints is BoxConstraints) {
                constraintsProperty.addAll(<String, Object>{
                  'minWidth': constraints.minWidth.toString(),
                  'minHeight': constraints.minHeight.toString(),
                  'maxWidth': constraints.maxWidth.toString(),
                  'maxHeight': constraints.maxHeight.toString(),
                });
              }
              additionalJson['constraints'] = constraintsProperty;
            }
          } catch (e) {
            // Constraints are sometimes unavailable even though
            // debugNeedsLayout is false.
          }

          try {
            if (renderObject is RenderBox) {
              additionalJson['isBox'] = true;
              additionalJson['size'] = <String, Object>{
                'width': renderObject.size.width.toString(),
                'height': renderObject.size.height.toString(),
              };

              final ParentData? parentData = renderObject.parentData;
              if (parentData is FlexParentData) {
                additionalJson['flexFactor'] = parentData.flex!;
                additionalJson['flexFit'] =
                    (parentData.fit ?? FlexFit.tight).name;
              } else if (parentData is BoxParentData) {
                final Offset offset = parentData.offset;
                additionalJson['parentData'] = <String, Object>{
                  'offsetX': offset.dx.toString(),
                  'offsetY': offset.dy.toString(),
                };
              }
            } else if (renderObject is RenderView) {
              additionalJson['size'] = <String, Object>{
                'width': renderObject.size.width.toString(),
                'height': renderObject.size.height.toString(),
              };
            }
          } catch (e) {
            // Not laid out yet.
          }
          return additionalJson;
        },
      ),
    );
    return Future<Map<String, dynamic>>.value(<String, dynamic>{
      'result': result,
    });
  }

  Future<Map<String, dynamic>> _setFlexFit(Map<String, String> parameters) {
    final String? id = parameters['id'];
    final String parameter = parameters['flexFit']!;
    final FlexFit flexFit = _toEnumEntry<FlexFit>(FlexFit.values, parameter);
    final Object? object = toObject(id);
    bool succeed = false;
    if (object != null && object is Element) {
      final RenderObject? render = object.renderObject;
      final ParentData? parentData = render?.parentData;
      if (parentData is FlexParentData) {
        parentData.fit = flexFit;
        render!.markNeedsLayout();
        succeed = true;
      }
    }
    return Future<Map<String, Object>>.value(<String, Object>{
      'result': succeed,
    });
  }

  Future<Map<String, dynamic>> _setFlexFactor(Map<String, String> parameters) {
    final String? id = parameters['id'];
    final String flexFactor = parameters['flexFactor']!;
    final int? factor = flexFactor == 'null' ? null : int.parse(flexFactor);
    final dynamic object = toObject(id);
    bool succeed = false;
    if (object != null && object is Element) {
      final RenderObject? render = object.renderObject;
      final ParentData? parentData = render?.parentData;
      if (parentData is FlexParentData) {
        parentData.flex = factor;
        render!.markNeedsLayout();
        succeed = true;
      }
    }
    return Future<Map<String, Object>>.value(
        <String, Object>{'result': succeed});
  }

  Future<Map<String, dynamic>> _setFlexProperties(
    Map<String, String> parameters,
  ) {
    final String? id = parameters['id'];
    final MainAxisAlignment mainAxisAlignment = _toEnumEntry<MainAxisAlignment>(
      MainAxisAlignment.values,
      parameters['mainAxisAlignment']!,
    );
    final CrossAxisAlignment crossAxisAlignment =
        _toEnumEntry<CrossAxisAlignment>(
      CrossAxisAlignment.values,
      parameters['crossAxisAlignment']!,
    );
    final Object? object = toObject(id);
    bool succeed = false;
    if (object != null && object is Element) {
      final RenderObject? render = object.renderObject;
      if (render is RenderFlex) {
        render.mainAxisAlignment = mainAxisAlignment;
        render.crossAxisAlignment = crossAxisAlignment;
        render.markNeedsLayout();
        render.markNeedsPaint();
        succeed = true;
      }
    }
    return Future<Map<String, Object>>.value(
        <String, Object>{'result': succeed});
  }

  T _toEnumEntry<T>(List<T> enumEntries, String name) {
    for (final T entry in enumEntries) {
      if (entry.toString() == name) {
        return entry;
      }
    }
    throw Exception('Enum value $name not found');
  }

  Map<String, Object?>? _getSelectedWidget(
      String? previousSelectionId, String groupName) {
    return _nodeToJson(
      _getSelectedWidgetDiagnosticsNode(previousSelectionId),
      InspectorSerializationDelegate(groupName: groupName, service: this),
    );
  }

  DiagnosticsNode? _getSelectedWidgetDiagnosticsNode(
      String? previousSelectionId) {
    final DiagnosticsNode? previousSelection =
        toObject(previousSelectionId) as DiagnosticsNode?;
    final Element? current = selection.currentElement;
    return current == previousSelection?.value
        ? previousSelection
        : current?.toDiagnosticsNode();
  }

  String getSelectedSummaryWidget(
      String? previousSelectionId, String groupName) {
    if (previousSelectionId != null) {
      debugPrint('previousSelectionId is deprecated in API');
    }
    return _safeJsonEncode(_getSelectedSummaryWidget(null, groupName));
  }

  _Location? _getSelectedSummaryWidgetLocation(String? previousSelectionId) {
    return _getCreationLocation(
        _getSelectedSummaryDiagnosticsNode(previousSelectionId)?.value);
  }

  DiagnosticsNode? _getSelectedSummaryDiagnosticsNode(
      String? previousSelectionId) {
    if (!isWidgetCreationTracked()) {
      return _getSelectedWidgetDiagnosticsNode(previousSelectionId);
    }
    final DiagnosticsNode? previousSelection =
        toObject(previousSelectionId) as DiagnosticsNode?;
    Element? current = selection.currentElement;
    if (current != null && !_isValueCreatedByLocalProject(current)) {
      Element? firstLocal;
      for (final Element candidate in current.debugGetDiagnosticChain()) {
        if (_isValueCreatedByLocalProject(candidate)) {
          firstLocal = candidate;
          break;
        }
      }
      current = firstLocal;
    }
    return current == previousSelection?.value
        ? previousSelection
        : current?.toDiagnosticsNode();
  }

  Map<String, Object?>? _getSelectedSummaryWidget(
      String? previousSelectionId, String groupName) {
    return _nodeToJson(_getSelectedSummaryDiagnosticsNode(previousSelectionId),
        InspectorSerializationDelegate(groupName: groupName, service: this));
  }

  bool isWidgetCreationTracked() {
    _widgetCreationTracked ??=
        const _WidgetForTypeTests() is _HasCreationLocation;
    return _widgetCreationTracked!;
  }

  bool? _widgetCreationTracked;

  late Duration _frameStart;

  void _onFrameStart(Duration timeStamp) {
    _frameStart = timeStamp;
    SchedulerBinding.instance.addPostFrameCallback(_onFrameEnd);
  }

  void _onFrameEnd(Duration timeStamp) {
    if (_trackRebuildDirtyWidgets) {
      _postStatsEvent('Flutter.RebuiltWidgets', _rebuildStats);
    }
    if (_trackRepaintWidgets) {
      _postStatsEvent('Flutter.RepaintWidgets', _repaintStats);
    }
  }

  void _postStatsEvent(String eventName, _ElementLocationStatsTracker stats) {
    postEvent(eventName, stats.exportToJson(_frameStart));
  }

  @protected
  void postEvent(
    String eventKind,
    Map<Object, Object?> eventData, {
    String stream = 'Extension',
  }) {
    developer.postEvent(eventKind, eventData, stream: stream);
  }

  @protected
  void inspect(Object? object) {
    developer.inspect(object);
  }

  final _ElementLocationStatsTracker _rebuildStats =
      _ElementLocationStatsTracker();
  final _ElementLocationStatsTracker _repaintStats =
      _ElementLocationStatsTracker();

  void _onRebuildWidget(Element element, bool builtOnce) {
    _rebuildStats.add(element);
  }

  void _onPaint(RenderObject renderObject) {
    try {
      final Element? element =
          (renderObject.debugCreator as DebugCreator?)?.element;
      if (element is! RenderObjectElement) {
        // This branch should not hit as long as all RenderObjects were created
        // by Widgets. It is possible there might be some render objects
        // created directly without using the Widget layer so we add this check
        // to improve robustness.
        return;
      }
      _repaintStats.add(element);

      // Give all ancestor elements credit for repainting as long as they do
      // not have their own associated RenderObject.
      element.visitAncestorElements((Element ancestor) {
        if (ancestor is RenderObjectElement) {
          // This ancestor has its own RenderObject so we can precisely track
          // when it repaints.
          return false;
        }
        _repaintStats.add(ancestor);
        return true;
      });
    } catch (exception, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'widget inspector library',
          context: ErrorDescription('while tracking widget repaints'),
        ),
      );
    }
  }

  void performReassemble() {
    _clearStats();
    _resetErrorCount();
  }
}

class _LocationCount {
  _LocationCount({
    required this.location,
    required this.id,
    required this.local,
  });

  final int id;

  final bool local;

  final _Location location;

  int get count => _count;
  int _count = 0;

  void reset() {
    _count = 0;
  }

  void increment() {
    _count++;
  }
}

class _ElementLocationStatsTracker {
  // All known creation location tracked.
  //
  // This could also be stored as a `Map<int, _LocationCount>` but this
  // representation is more efficient as all location ids from 0 to n are
  // typically present.
  //
  // All logic in this class assumes that if `_stats[i]` is not null
  // `_stats[i].id` equals `i`.
  final List<_LocationCount?> _stats = <_LocationCount?>[];

  final List<_LocationCount> active = <_LocationCount>[];

  final List<_LocationCount> newLocations = <_LocationCount>[];

  void add(Element element) {
    final Object widget = element.widget;
    if (widget is! _HasCreationLocation) {
      return;
    }
    final _HasCreationLocation creationLocationSource = widget;
    final _Location? location = creationLocationSource._location;
    if (location == null) {
      return;
    }
    final int id = _toLocationId(location);

    _LocationCount entry;
    if (id >= _stats.length || _stats[id] == null) {
      // After the first frame, almost all creation ids will already be in
      // _stats so this slow path will rarely be hit.
      while (id >= _stats.length) {
        _stats.add(null);
      }
      entry = _LocationCount(
        location: location,
        id: id,
        local: WidgetInspectorService.instance
            ._isLocalCreationLocation(location.file),
      );
      if (entry.local) {
        newLocations.add(entry);
      }
      _stats[id] = entry;
    } else {
      entry = _stats[id]!;
    }

    // We could in the future add an option to track stats for all widgets but
    // that would significantly increase the size of the events posted using
    // [developer.postEvent] and current use cases for this feature focus on
    // helping users find problems with their widgets not the platform
    // widgets.
    if (entry.local) {
      if (entry.count == 0) {
        active.add(entry);
      }
      entry.increment();
    }
  }

  void resetCounts() {
    // We chose to only reset the active counts instead of clearing all data
    // to reduce the number memory allocations performed after the first frame.
    // Once an app has warmed up, location stats tracking should not
    // trigger significant additional memory allocations. Avoiding memory
    // allocations is important to minimize the impact this class has on cpu
    // and memory performance of the running app.
    for (final _LocationCount entry in active) {
      entry.reset();
    }
    active.clear();
  }

  Map<String, dynamic> exportToJson(Duration startTime) {
    final List<int> events = List<int>.filled(active.length * 2, 0);
    int j = 0;
    for (final _LocationCount stat in active) {
      events[j++] = stat.id;
      events[j++] = stat.count;
    }

    final Map<String, dynamic> json = <String, dynamic>{
      'startTime': startTime.inMicroseconds,
      'events': events,
    };

    // Encode the new locations using the older encoding.
    if (newLocations.isNotEmpty) {
      // Add all newly used location ids to the JSON.
      final Map<String, List<int>> locationsJson = <String, List<int>>{};
      for (final _LocationCount entry in newLocations) {
        final _Location location = entry.location;
        final List<int> jsonForFile = locationsJson.putIfAbsent(
          location.file,
          () => <int>[],
        );
        jsonForFile
          ..add(entry.id)
          ..add(location.line)
          ..add(location.column);
      }
      json['newLocations'] = locationsJson;
    }

    // Encode the new locations using the newer encoding (as of v2.4.0).
    if (newLocations.isNotEmpty) {
      final Map<String, Map<String, List<Object?>>> fileLocationsMap =
          <String, Map<String, List<Object?>>>{};
      for (final _LocationCount entry in newLocations) {
        final _Location location = entry.location;
        final Map<String, List<Object?>> locations =
            fileLocationsMap.putIfAbsent(
          location.file,
          () => <String, List<Object?>>{
            'ids': <int>[],
            'lines': <int>[],
            'columns': <int>[],
            'names': <String?>[],
          },
        );

        locations['ids']!.add(entry.id);
        locations['lines']!.add(location.line);
        locations['columns']!.add(location.column);
        locations['names']!.add(location.name);
      }
      json['locations'] = fileLocationsMap;
    }

    resetCounts();
    newLocations.clear();
    return json;
  }
}

class _WidgetForTypeTests extends Widget {
  const _WidgetForTypeTests();

  @override
  Element createElement() => throw UnimplementedError();
}

class WidgetInspector extends StatefulWidget {
  const WidgetInspector({
    super.key,
    required this.child,
    required this.selectButtonBuilder,
  });

  final Widget child;

  final InspectorSelectButtonBuilder? selectButtonBuilder;

  @override
  State<WidgetInspector> createState() => _WidgetInspectorState();
}

class _WidgetInspectorState extends State<WidgetInspector>
    with WidgetsBindingObserver {
  _WidgetInspectorState();

  Offset? _lastPointerLocation;

  late InspectorSelection selection;

  late bool isSelectMode;

  final GlobalKey _ignorePointerKey = GlobalKey();

  static const double _edgeHitMargin = 2.0;

  @override
  void initState() {
    super.initState();

    WidgetInspectorService.instance.selection
        .addListener(_selectionInformationChanged);
    WidgetInspectorService.instance.isSelectMode
        .addListener(_selectionInformationChanged);
    selection = WidgetInspectorService.instance.selection;
    isSelectMode = WidgetInspectorService.instance.isSelectMode.value;
  }

  @override
  void dispose() {
    WidgetInspectorService.instance.selection
        .removeListener(_selectionInformationChanged);
    WidgetInspectorService.instance.isSelectMode
        .removeListener(_selectionInformationChanged);
    super.dispose();
  }

  void _selectionInformationChanged() => setState(() {
        selection = WidgetInspectorService.instance.selection;
        isSelectMode = WidgetInspectorService.instance.isSelectMode.value;
      });

  bool _hitTestHelper(
    List<RenderObject> hits,
    List<RenderObject> edgeHits,
    Offset position,
    RenderObject object,
    Matrix4 transform,
  ) {
    bool hit = false;
    final Matrix4? inverse = Matrix4.tryInvert(transform);
    if (inverse == null) {
      // We cannot invert the transform. That means the object doesn't appear on
      // screen and cannot be hit.
      return false;
    }
    final Offset localPosition = MatrixUtils.transformPoint(inverse, position);

    final List<DiagnosticsNode> children = object.debugDescribeChildren();
    for (int i = children.length - 1; i >= 0; i -= 1) {
      final DiagnosticsNode diagnostics = children[i];
      if (diagnostics.style == DiagnosticsTreeStyle.offstage ||
          diagnostics.value is! RenderObject) {
        continue;
      }
      final RenderObject child = diagnostics.value! as RenderObject;
      final Rect? paintClip = object.describeApproximatePaintClip(child);
      if (paintClip != null && !paintClip.contains(localPosition)) {
        continue;
      }

      final Matrix4 childTransform = transform.clone();
      object.applyPaintTransform(child, childTransform);
      if (_hitTestHelper(hits, edgeHits, position, child, childTransform)) {
        hit = true;
      }
    }

    final Rect bounds = object.semanticBounds;
    if (bounds.contains(localPosition)) {
      hit = true;
      // Hits that occur on the edge of the bounding box of an object are
      // given priority to provide a way to select objects that would
      // otherwise be hard to select.
      if (!bounds.deflate(_edgeHitMargin).contains(localPosition)) {
        edgeHits.add(object);
      }
    }
    if (hit) {
      hits.add(object);
    }
    return hit;
  }

  List<RenderObject> hitTest(Offset position, RenderObject root) {
    final List<RenderObject> regularHits = <RenderObject>[];
    final List<RenderObject> edgeHits = <RenderObject>[];

    _hitTestHelper(
        regularHits, edgeHits, position, root, root.getTransformTo(null));
    // Order matches by the size of the hit area.
    double area(RenderObject object) {
      final Size size = object.semanticBounds.size;
      return size.width * size.height;
    }

    regularHits
        .sort((RenderObject a, RenderObject b) => area(a).compareTo(area(b)));
    final Set<RenderObject> hits = <RenderObject>{
      ...edgeHits,
      ...regularHits,
    };
    return hits.toList();
  }

  void _inspectAt(Offset position) {
    if (!isSelectMode) {
      return;
    }

    final RenderIgnorePointer ignorePointer = _ignorePointerKey.currentContext!
        .findRenderObject()! as RenderIgnorePointer;
    final RenderObject userRender = ignorePointer.child!;
    final List<RenderObject> selected = hitTest(position, userRender);

    selection.candidates = selected;
  }

  void _handlePanDown(DragDownDetails event) {
    _lastPointerLocation = event.globalPosition;
    _inspectAt(event.globalPosition);
  }

  void _handlePanUpdate(DragUpdateDetails event) {
    _lastPointerLocation = event.globalPosition;
    _inspectAt(event.globalPosition);
  }

  void _handlePanEnd(DragEndDetails details) {
    // If the pan ends on the edge of the window assume that it indicates the
    // pointer is being dragged off the edge of the display not a regular touch
    // on the edge of the display. If the pointer is being dragged off the edge
    // of the display we do not want to select anything. A user can still select
    // a widget that is only at the exact screen margin by tapping.
    final ui.FlutterView view = View.of(context);
    final Rect bounds =
        (Offset.zero & (view.physicalSize / view.devicePixelRatio))
            .deflate(_kOffScreenMargin);
    if (!bounds.contains(_lastPointerLocation!)) {
      selection.clear();
    }
  }

  void _handleTap() {
    if (!isSelectMode) {
      return;
    }
    if (_lastPointerLocation != null) {
      _inspectAt(_lastPointerLocation!);
      WidgetInspectorService.instance._sendInspectEvent(selection.current);
    }

    // Only exit select mode if there is a button to return to select mode.
    if (widget.selectButtonBuilder != null) {
      WidgetInspectorService.instance.isSelectMode.value = false;
    }
  }

  void _handleEnableSelect() {
    WidgetInspectorService.instance.isSelectMode.value = true;
  }

  @override
  Widget build(BuildContext context) {
    // Be careful changing this build method. The _InspectorOverlayLayer
    // assumes the root RenderObject for the WidgetInspector will be
    // a RenderStack with a _RenderInspectorOverlay as the last child.
    return Stack(children: <Widget>[
      GestureDetector(
        onTap: _handleTap,
        onPanDown: _handlePanDown,
        onPanEnd: _handlePanEnd,
        onPanUpdate: _handlePanUpdate,
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        child: IgnorePointer(
          ignoring: isSelectMode,
          key: _ignorePointerKey,
          child: widget.child,
        ),
      ),
      if (!isSelectMode && widget.selectButtonBuilder != null)
        Positioned(
          left: _kInspectButtonMargin,
          bottom: _kInspectButtonMargin,
          child: widget.selectButtonBuilder!(context, _handleEnableSelect),
        ),
      _InspectorOverlay(selection: selection),
    ]);
  }
}

class InspectorSelection with ChangeNotifier {
  InspectorSelection() {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  List<RenderObject> get candidates => _candidates;
  List<RenderObject> _candidates = <RenderObject>[];
  set candidates(List<RenderObject> value) {
    _candidates = value;
    _index = 0;
    _computeCurrent();
  }

  int get index => _index;
  int _index = 0;
  set index(int value) {
    _index = value;
    _computeCurrent();
  }

  void clear() {
    _candidates = <RenderObject>[];
    _index = 0;
    _computeCurrent();
  }

  RenderObject? get current => active ? _current : null;

  RenderObject? _current;
  set current(RenderObject? value) {
    if (_current != value) {
      _current = value;
      _currentElement = (value?.debugCreator as DebugCreator?)?.element;
      notifyListeners();
    }
  }

  Element? get currentElement {
    return _currentElement?.debugIsDefunct ?? true ? null : _currentElement;
  }

  Element? _currentElement;
  set currentElement(Element? element) {
    if (element?.debugIsDefunct ?? false) {
      _currentElement = null;
      _current = null;
      notifyListeners();
      return;
    }
    if (currentElement != element) {
      _currentElement = element;
      _current = element!.findRenderObject();
      notifyListeners();
    }
  }

  void _computeCurrent() {
    if (_index < candidates.length) {
      _current = candidates[index];
      _currentElement = (_current?.debugCreator as DebugCreator?)?.element;
      notifyListeners();
    } else {
      _current = null;
      _currentElement = null;
      notifyListeners();
    }
  }

  bool get active => _current != null && _current!.attached;
}

class _InspectorOverlay extends LeafRenderObjectWidget {
  const _InspectorOverlay({
    required this.selection,
  });

  final InspectorSelection selection;

  @override
  _RenderInspectorOverlay createRenderObject(BuildContext context) {
    return _RenderInspectorOverlay(selection: selection);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderInspectorOverlay renderObject) {
    renderObject.selection = selection;
  }
}

class _RenderInspectorOverlay extends RenderBox {
  _RenderInspectorOverlay({required InspectorSelection selection})
      : _selection = selection;

  InspectorSelection get selection => _selection;
  InspectorSelection _selection;
  set selection(InspectorSelection value) {
    if (value != _selection) {
      _selection = value;
    }
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(Size.infinite);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(needsCompositing);
    context.addLayer(_InspectorOverlayLayer(
      overlayRect: Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
      selection: selection,
      rootRenderObject: parent is RenderObject ? parent! : null,
    ));
  }
}

@immutable
class _TransformedRect {
  _TransformedRect(RenderObject object, RenderObject? ancestor)
      : rect = object.semanticBounds,
        transform = object.getTransformTo(ancestor);

  final Rect rect;
  final Matrix4 transform;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _TransformedRect &&
        other.rect == rect &&
        other.transform == transform;
  }

  @override
  int get hashCode => Object.hash(rect, transform);
}

@immutable
class _InspectorOverlayRenderState {
  const _InspectorOverlayRenderState({
    required this.overlayRect,
    required this.selected,
    required this.candidates,
    required this.tooltip,
    required this.textDirection,
  });

  final Rect overlayRect;
  final _TransformedRect selected;
  final List<_TransformedRect> candidates;
  final String tooltip;
  final TextDirection textDirection;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _InspectorOverlayRenderState &&
        other.overlayRect == overlayRect &&
        other.selected == selected &&
        listEquals<_TransformedRect>(other.candidates, candidates) &&
        other.tooltip == tooltip;
  }

  @override
  int get hashCode =>
      Object.hash(overlayRect, selected, Object.hashAll(candidates), tooltip);
}

const int _kMaxTooltipLines = 5;
const Color _kTooltipBackgroundColor = Color.fromARGB(230, 60, 60, 60);
const Color _kHighlightedRenderObjectFillColor =
    Color.fromARGB(128, 128, 128, 255);
const Color _kHighlightedRenderObjectBorderColor =
    Color.fromARGB(128, 64, 64, 128);

class _InspectorOverlayLayer extends Layer {
  _InspectorOverlayLayer({
    required this.overlayRect,
    required this.selection,
    required this.rootRenderObject,
  }) {
    bool inDebugMode = false;
    assert(() {
      inDebugMode = true;
      return true;
    }());
    if (!inDebugMode) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
          'The inspector should never be used in production mode due to the '
          'negative performance impact.',
        ),
      ]);
    }
  }

  InspectorSelection selection;

  final Rect overlayRect;

  final RenderObject? rootRenderObject;

  _InspectorOverlayRenderState? _lastState;

  late ui.Picture _picture;

  TextPainter? _textPainter;
  double? _textPainterMaxWidth;

  @override
  void dispose() {
    _textPainter?.dispose();
    _textPainter = null;
    super.dispose();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    if (!selection.active) {
      return;
    }

    final RenderObject selected = selection.current!;

    if (!_isInInspectorRenderObjectTree(selected)) {
      return;
    }

    final List<_TransformedRect> candidates = <_TransformedRect>[];
    for (final RenderObject candidate in selection.candidates) {
      if (candidate == selected ||
          !candidate.attached ||
          !_isInInspectorRenderObjectTree(candidate)) {
        continue;
      }
      candidates.add(_TransformedRect(candidate, rootRenderObject));
    }

    final _InspectorOverlayRenderState state = _InspectorOverlayRenderState(
      overlayRect: overlayRect,
      selected: _TransformedRect(selected, rootRenderObject),
      tooltip: selection.currentElement!.toStringShort(),
      textDirection: TextDirection.ltr,
      candidates: candidates,
    );

    if (state != _lastState) {
      _lastState = state;
      _picture = _buildPicture(state);
    }
    builder.addPicture(Offset.zero, _picture);
  }

  ui.Picture _buildPicture(_InspectorOverlayRenderState state) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, state.overlayRect);
    final Size size = state.overlayRect.size;
    // The overlay rect could have an offset if the widget inspector does
    // not take all the screen.
    canvas.translate(state.overlayRect.left, state.overlayRect.top);

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _kHighlightedRenderObjectFillColor;

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _kHighlightedRenderObjectBorderColor;

    // Highlight the selected renderObject.
    final Rect selectedPaintRect = state.selected.rect.deflate(0.5);
    canvas
      ..save()
      ..transform(state.selected.transform.storage)
      ..drawRect(selectedPaintRect, fillPaint)
      ..drawRect(selectedPaintRect, borderPaint)
      ..restore();

    // Show all other candidate possibly selected elements. This helps selecting
    // render objects by selecting the edge of the bounding box shows all
    // elements the user could toggle the selection between.
    for (final _TransformedRect transformedRect in state.candidates) {
      canvas
        ..save()
        ..transform(transformedRect.transform.storage)
        ..drawRect(transformedRect.rect.deflate(0.5), borderPaint)
        ..restore();
    }

    final Rect targetRect = MatrixUtils.transformRect(
      state.selected.transform,
      state.selected.rect,
    );
    final Offset target = Offset(targetRect.left, targetRect.center.dy);
    const double offsetFromWidget = 9.0;
    final double verticalOffset = (targetRect.height) / 2 + offsetFromWidget;

    _paintDescription(canvas, state.tooltip, state.textDirection, target,
        verticalOffset, size, targetRect);

    // TODO(jacobr): provide an option to perform a debug paint of just the
    // selected widget.
    return recorder.endRecording();
  }

  void _paintDescription(
    Canvas canvas,
    String message,
    TextDirection textDirection,
    Offset target,
    double verticalOffset,
    Size size,
    Rect targetRect,
  ) {
    canvas.save();
    final double maxWidth = math.max(
      size.width - 2 * (_kScreenEdgeMargin + _kTooltipPadding),
      0,
    );
    final TextSpan? textSpan = _textPainter?.text as TextSpan?;
    if (_textPainter == null ||
        textSpan!.text != message ||
        _textPainterMaxWidth != maxWidth) {
      _textPainterMaxWidth = maxWidth;
      _textPainter?.dispose();
      _textPainter = TextPainter()
        ..maxLines = _kMaxTooltipLines
        ..ellipsis = '...'
        ..text = TextSpan(style: _messageStyle, text: message)
        ..textDirection = textDirection
        ..layout(maxWidth: maxWidth);
    }

    final Size tooltipSize = _textPainter!.size +
        const Offset(_kTooltipPadding * 2, _kTooltipPadding * 2);
    final Offset tipOffset = positionDependentBox(
      size: size,
      childSize: tooltipSize,
      target: target,
      verticalOffset: verticalOffset,
      preferBelow: false,
    );

    final Paint tooltipBackground = Paint()
      ..style = PaintingStyle.fill
      ..color = _kTooltipBackgroundColor;
    canvas.drawRect(
      Rect.fromPoints(
        tipOffset,
        tipOffset.translate(tooltipSize.width, tooltipSize.height),
      ),
      tooltipBackground,
    );

    double wedgeY = tipOffset.dy;
    final bool tooltipBelow = tipOffset.dy > target.dy;
    if (!tooltipBelow) {
      wedgeY += tooltipSize.height;
    }

    const double wedgeSize = _kTooltipPadding * 2;
    double wedgeX = math.max(tipOffset.dx, target.dx) + wedgeSize * 2;
    wedgeX = math.min(wedgeX, tipOffset.dx + tooltipSize.width - wedgeSize * 2);
    final List<Offset> wedge = <Offset>[
      Offset(wedgeX - wedgeSize, wedgeY),
      Offset(wedgeX + wedgeSize, wedgeY),
      Offset(wedgeX, wedgeY + (tooltipBelow ? -wedgeSize : wedgeSize)),
    ];
    canvas.drawPath(Path()..addPolygon(wedge, true), tooltipBackground);
    _textPainter!.paint(
        canvas, tipOffset + const Offset(_kTooltipPadding, _kTooltipPadding));
    canvas.restore();
  }

  @override
  @protected
  bool findAnnotations<S extends Object>(
    AnnotationResult<S> result,
    Offset localPosition, {
    bool? onlyFirst,
  }) {
    return false;
  }

  bool _isInInspectorRenderObjectTree(RenderObject child) {
    RenderObject? current = child.parent;
    while (current != null) {
      // We found the widget inspector render object.
      if (current is RenderStack &&
          current.lastChild is _RenderInspectorOverlay) {
        return rootRenderObject == current;
      }
      current = current.parent;
    }
    return false;
  }
}

const double _kScreenEdgeMargin = 10.0;
const double _kTooltipPadding = 5.0;
const double _kInspectButtonMargin = 10.0;

const double _kOffScreenMargin = 1.0;

const TextStyle _messageStyle = TextStyle(
  color: Color(0xFFFFFFFF),
  fontSize: 10.0,
  height: 1.2,
);

// ignore: unused_element
abstract class _HasCreationLocation {
  _Location? get _location;
}

class _Location {
  const _Location({
    required this.file,
    required this.line,
    required this.column,
    // ignore: unused_element, unused_element_parameter
    this.name,
  });

  final String file;

  final int line;

  final int column;

  final String? name;

  Map<String, Object?> toJsonMap() {
    final Map<String, Object?> json = <String, Object?>{
      'file': file,
      'line': line,
      'column': column,
    };
    if (name != null) {
      json['name'] = name;
    }
    return json;
  }

  @override
  String toString() {
    final List<String> parts = <String>[];
    if (name != null) {
      parts.add(name!);
    }
    parts.add(file);
    parts
      ..add('$line')
      ..add('$column');
    return parts.join(':');
  }
}

bool _isDebugCreator(DiagnosticsNode node) => node is DiagnosticsDebugCreator;

Iterable<DiagnosticsNode> debugTransformDebugCreator(
    Iterable<DiagnosticsNode> properties) {
  if (!kDebugMode) {
    return <DiagnosticsNode>[];
  }
  final List<DiagnosticsNode> pending = <DiagnosticsNode>[];
  ErrorSummary? errorSummary;
  for (final DiagnosticsNode node in properties) {
    if (node is ErrorSummary) {
      errorSummary = node;
      break;
    }
  }
  bool foundStackTrace = false;
  final List<DiagnosticsNode> result = <DiagnosticsNode>[];
  for (final DiagnosticsNode node in properties) {
    if (!foundStackTrace && node is DiagnosticsStackTrace) {
      foundStackTrace = true;
    }
    if (_isDebugCreator(node)) {
      result.addAll(_parseDiagnosticsNode(node, errorSummary));
    } else {
      if (foundStackTrace) {
        pending.add(node);
      } else {
        result.add(node);
      }
    }
  }
  result.addAll(pending);
  return result;
}

Iterable<DiagnosticsNode> _parseDiagnosticsNode(
  DiagnosticsNode node,
  ErrorSummary? errorSummary,
) {
  assert(_isDebugCreator(node));
  try {
    final DebugCreator debugCreator = node.value! as DebugCreator;
    final Element element = debugCreator.element;
    return _describeRelevantUserCode(element, errorSummary);
  } catch (error, stack) {
    scheduleMicrotask(() {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'widget inspector',
        informationCollector: () => <DiagnosticsNode>[
          DiagnosticsNode.message(
              'This exception was caught while trying to describe the user-relevant code of another error.'),
        ],
      ));
    });
    return <DiagnosticsNode>[];
  }
}

Iterable<DiagnosticsNode> _describeRelevantUserCode(
  Element element,
  ErrorSummary? errorSummary,
) {
  if (!WidgetInspectorService.instance.isWidgetCreationTracked()) {
    return <DiagnosticsNode>[
      ErrorDescription(
        'Widget creation tracking is currently disabled. Enabling '
        'it enables improved error messages. It can be enabled by passing '
        '`--track-widget-creation` to `flutter run` or `flutter test`.',
      ),
      ErrorSpacer(),
    ];
  }

  bool isOverflowError() {
    if (errorSummary != null && errorSummary.value.isNotEmpty) {
      final Object summary = errorSummary.value.first;
      if (summary is String &&
          summary.startsWith('A RenderFlex overflowed by')) {
        return true;
      }
    }
    return false;
  }

  final List<DiagnosticsNode> nodes = <DiagnosticsNode>[];
  bool processElement(Element target) {
    // TODO(chunhtai): should print out all the widgets that are about to cross
    // package boundaries.
    if (debugIsLocalCreationLocation(target)) {
      DiagnosticsNode? devToolsDiagnostic;

      // TODO(kenz): once the inspector is better at dealing with broken trees,
      // we can enable deep links for more errors than just RenderFlex overflow
      // errors. See https://github.com/flutter/flutter/issues/74918.
      if (isOverflowError()) {
        final String? devToolsInspectorUri = WidgetInspectorService.instance
            ._devToolsInspectorUriForElement(target);
        if (devToolsInspectorUri != null) {
          devToolsDiagnostic = DevToolsDeepLinkProperty(
            'To inspect this widget in Flutter DevTools, visit: $devToolsInspectorUri',
            devToolsInspectorUri,
          );
        }
      }

      nodes.addAll(<DiagnosticsNode>[
        DiagnosticsBlock(
          name: 'The relevant error-causing widget was',
          children: <DiagnosticsNode>[
            ErrorDescription(
                '${target.widget.toStringShort()} ${_describeCreationLocation(target)}'),
          ],
        ),
        ErrorSpacer(),
        if (devToolsDiagnostic != null) ...<DiagnosticsNode>[
          devToolsDiagnostic,
          ErrorSpacer()
        ],
      ]);
      return false;
    }
    return true;
  }

  if (processElement(element)) {
    element.visitAncestorElements(processElement);
  }
  return nodes;
}

class DevToolsDeepLinkProperty extends DiagnosticsProperty<String> {
  DevToolsDeepLinkProperty(String description, String url)
      : super('', url, description: description, level: DiagnosticLevel.info);
}

bool debugIsLocalCreationLocation(Object object) {
  bool isLocal = false;
  assert(() {
    final _Location? location = _getCreationLocation(object);
    if (location != null) {
      isLocal = WidgetInspectorService.instance
          ._isLocalCreationLocation(location.file);
    }
    return true;
  }());
  return isLocal;
}

bool debugIsWidgetLocalCreation(Widget widget) {
  final _Location? location = _getObjectCreationLocation(widget);
  return location != null &&
      WidgetInspectorService.instance._isLocalCreationLocation(location.file);
}

String? _describeCreationLocation(Object object) {
  final _Location? location = _getCreationLocation(object);
  return location?.toString();
}

_Location? _getObjectCreationLocation(Object object) {
  return object is _HasCreationLocation ? object._location : null;
}

_Location? _getCreationLocation(Object? object) {
  final Object? candidate =
      object is Element && !object.debugIsDefunct ? object.widget : object;
  return candidate == null ? null : _getObjectCreationLocation(candidate);
}

// _Location objects are always const so we don't need to worry about the GC
// issues that are a concern for other object ids tracked by
// [WidgetInspectorService].
final Map<_Location, int> _locationToId = <_Location, int>{};
final List<_Location> _locations = <_Location>[];

int _toLocationId(_Location location) {
  int? id = _locationToId[location];
  if (id != null) {
    return id;
  }
  id = _locations.length;
  _locations.add(location);
  _locationToId[location] = id;
  return id;
}

@visibleForTesting
class InspectorSerializationDelegate
    implements DiagnosticsSerializationDelegate {
  InspectorSerializationDelegate({
    this.groupName,
    this.summaryTree = false,
    this.maxDescendantsTruncatableNode = -1,
    this.expandPropertyValues = true,
    this.subtreeDepth = 1,
    this.includeProperties = false,
    required this.service,
    this.addAdditionalPropertiesCallback,
  });

  final WidgetInspectorService service;

  final String? groupName;

  final bool summaryTree;

  final int maxDescendantsTruncatableNode;

  @override
  final bool includeProperties;

  @override
  final int subtreeDepth;

  @override
  final bool expandPropertyValues;

  final Map<String, Object>? Function(
          DiagnosticsNode, InspectorSerializationDelegate)?
      addAdditionalPropertiesCallback;

  final List<DiagnosticsNode> _nodesCreatedByLocalProject = <DiagnosticsNode>[];

  bool get _interactive => groupName != null;

  @override
  Map<String, Object?> additionalNodeProperties(DiagnosticsNode node) {
    final Map<String, Object?> result = <String, Object?>{};
    final Object? value = node.value;
    if (_interactive) {
      result['valueId'] = service.toId(value, groupName!);
    }
    if (summaryTree) {
      result['summaryTree'] = true;
    }
    final _Location? creationLocation = _getCreationLocation(value);
    if (creationLocation != null) {
      result['locationId'] = _toLocationId(creationLocation);
      result['creationLocation'] = creationLocation.toJsonMap();
      if (service._isLocalCreationLocation(creationLocation.file)) {
        _nodesCreatedByLocalProject.add(node);
        result['createdByLocalProject'] = true;
      }
    }
    if (addAdditionalPropertiesCallback != null) {
      result.addAll(
          addAdditionalPropertiesCallback!(node, this) ?? <String, Object>{});
    }
    return result;
  }

  @override
  DiagnosticsSerializationDelegate delegateForNode(DiagnosticsNode node) {
    // The tricky special case here is that when in the detailsTree,
    // we keep subtreeDepth from going down to zero until we reach nodes
    // that also exist in the summary tree. This ensures that every time
    // you expand a node in the details tree, you expand the entire subtree
    // up until you reach the next nodes shared with the summary tree.
    return summaryTree ||
            subtreeDepth > 1 ||
            service._shouldShowInSummaryTree(node)
        ? copyWith(subtreeDepth: subtreeDepth - 1)
        : this;
  }

  @override
  List<DiagnosticsNode> filterChildren(
      List<DiagnosticsNode> nodes, DiagnosticsNode owner) {
    return service._filterChildren(nodes, this);
  }

  @override
  List<DiagnosticsNode> filterProperties(
      List<DiagnosticsNode> nodes, DiagnosticsNode owner) {
    final bool createdByLocalProject =
        _nodesCreatedByLocalProject.contains(owner);
    return nodes.where((DiagnosticsNode node) {
      return !node.isFiltered(
          createdByLocalProject ? DiagnosticLevel.fine : DiagnosticLevel.info);
    }).toList();
  }

  @override
  List<DiagnosticsNode> truncateNodesList(
      List<DiagnosticsNode> nodes, DiagnosticsNode? owner) {
    if (maxDescendantsTruncatableNode >= 0 &&
        owner!.allowTruncate &&
        nodes.length > maxDescendantsTruncatableNode) {
      nodes = service._truncateNodes(nodes, maxDescendantsTruncatableNode);
    }
    return nodes;
  }

  @override
  DiagnosticsSerializationDelegate copyWith(
      {int? subtreeDepth,
      bool? includeProperties,
      bool? expandPropertyValues}) {
    return InspectorSerializationDelegate(
      groupName: groupName,
      summaryTree: summaryTree,
      maxDescendantsTruncatableNode: maxDescendantsTruncatableNode,
      expandPropertyValues: expandPropertyValues ?? this.expandPropertyValues,
      subtreeDepth: subtreeDepth ?? this.subtreeDepth,
      includeProperties: includeProperties ?? this.includeProperties,
      service: service,
      addAdditionalPropertiesCallback: addAdditionalPropertiesCallback,
    );
  }
}

@Target(<TargetKind>{TargetKind.method})
class _WidgetFactory {
  const _WidgetFactory();
}

// The below ignore is needed because the static type of the annotation is used
// by the CFE kernel transformer that implements the instrumentation to
// recognize the annotation.
// ignore: library_private_types_in_public_api
const _WidgetFactory widgetFactory = _WidgetFactory();

@visibleForTesting
class WeakMap<K, V> {
  Expando<Object> _objects = Expando<Object>();

  final Map<K, V> _primitives = <K, V>{};

  bool _isPrimitive(Object? key) {
    return key == null || key is String || key is num || key is bool;
  }

  V? operator [](K key) {
    if (_isPrimitive(key)) {
      return _primitives[key];
    } else {
      return _objects[key!] as V?;
    }
  }

  void operator []=(K key, V value) {
    if (_isPrimitive(key)) {
      _primitives[key] = value;
    } else {
      _objects[key!] = value;
    }
  }

  V? remove(K key) {
    if (_isPrimitive(key)) {
      return _primitives.remove(key);
    } else {
      final V? result = _objects[key!] as V?;
      _objects[key] = null;
      return result;
    }
  }

  void clear() {
    _objects = Expando<Object>();
    _primitives.clear();
  }
}
