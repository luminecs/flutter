
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'debug.dart';
import 'framework.dart';
import 'media_query.dart';

enum SnapshotMode {
  permissive,

  normal,

  forced,
}

class SnapshotController extends ChangeNotifier {
  SnapshotController({
    bool allowSnapshotting = false,
  }) : _allowSnapshotting = allowSnapshotting;

  void clear() {
    notifyListeners();
  }

  bool get allowSnapshotting => _allowSnapshotting;
  bool _allowSnapshotting;
  set allowSnapshotting(bool value) {
    if (value == allowSnapshotting) {
      return;
    }
    _allowSnapshotting = value;
    notifyListeners();
  }
}

class SnapshotWidget extends SingleChildRenderObjectWidget {
  const SnapshotWidget({
    super.key,
    this.mode = SnapshotMode.normal,
    this.painter = const _DefaultSnapshotPainter(),
    this.autoresize = false,
    required this.controller,
    required super.child
  });

  final SnapshotController controller;

  final SnapshotMode mode;

  final bool autoresize;

  final SnapshotPainter painter;

  @override
  RenderObject createRenderObject(BuildContext context) {
    debugCheckHasMediaQuery(context);
    return _RenderSnapshotWidget(
      controller: controller,
      mode: mode,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      painter: painter,
      autoresize: autoresize,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    debugCheckHasMediaQuery(context);
    (renderObject as _RenderSnapshotWidget)
      ..controller = controller
      ..mode = mode
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context)
      ..painter = painter
      ..autoresize = autoresize;
  }
}

// A render object that conditionally converts its child into a [ui.Image]
// and then paints it in place of the child.
class _RenderSnapshotWidget extends RenderProxyBox {
  // Create a new [_RenderSnapshotWidget].
  _RenderSnapshotWidget({
    required double devicePixelRatio,
    required SnapshotController controller,
    required SnapshotMode mode,
    required SnapshotPainter painter,
    required bool autoresize,
  }) : _devicePixelRatio = devicePixelRatio,
       _controller = controller,
       _mode = mode,
       _painter = painter,
       _autoresize = autoresize;

  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == devicePixelRatio) {
      return;
    }
    _devicePixelRatio = value;
    if (_childRaster == null) {
      return;
    } else {
      _childRaster?.dispose();
      _childRaster = null;
      markNeedsPaint();
    }
  }

  SnapshotPainter get painter => _painter;
  SnapshotPainter _painter;
  set painter(SnapshotPainter value) {
    if (value == painter) {
      return;
    }
    final SnapshotPainter oldPainter = painter;
    oldPainter.removeListener(markNeedsPaint);
    _painter = value;
    if (oldPainter.runtimeType != painter.runtimeType ||
        painter.shouldRepaint(oldPainter)) {
      markNeedsPaint();
    }
    if (attached) {
      painter.addListener(markNeedsPaint);
    }
  }

  SnapshotController get controller => _controller;
  SnapshotController _controller;
  set controller(SnapshotController value) {
    if (value == controller) {
      return;
    }
    controller.removeListener(_onRasterValueChanged);
    final bool oldValue = controller.allowSnapshotting;
    _controller = value;
    if (attached) {
      controller.addListener(_onRasterValueChanged);
      if (oldValue != controller.allowSnapshotting) {
        _onRasterValueChanged();
      }
    }
  }

  SnapshotMode get mode => _mode;
  SnapshotMode _mode;
  set mode(SnapshotMode value) {
    if (value == _mode) {
      return;
    }
    _mode = value;
    markNeedsPaint();
  }

  bool get autoresize => _autoresize;
  bool _autoresize;
  set autoresize(bool value) {
    if (value == autoresize) {
      return;
    }
    _autoresize = value;
    markNeedsPaint();
  }

  ui.Image? _childRaster;
  Size? _childRasterSize;
  // Set to true if the snapshot mode was not forced and a platform view
  // was encountered while attempting to snapshot the child.
  bool _disableSnapshotAttempt = false;

  @override
  void attach(covariant PipelineOwner owner) {
    controller.addListener(_onRasterValueChanged);
    painter.addListener(markNeedsPaint);
    super.attach(owner);
  }

  @override
  void detach() {
    _disableSnapshotAttempt = false;
    controller.removeListener(_onRasterValueChanged);
    painter.removeListener(markNeedsPaint);
    _childRaster?.dispose();
    _childRaster = null;
    _childRasterSize = null;
    super.detach();
  }

  @override
  void dispose() {
    controller.removeListener(_onRasterValueChanged);
    painter.removeListener(markNeedsPaint);
    _childRaster?.dispose();
    _childRaster = null;
    _childRasterSize = null;
    super.dispose();
  }

  void _onRasterValueChanged() {
    _disableSnapshotAttempt = false;
    _childRaster?.dispose();
    _childRaster = null;
    _childRasterSize = null;
    markNeedsPaint();
  }

  // Paint [child] with this painting context, then convert to a raster and detach all
  // children from this layer.
  ui.Image? _paintAndDetachToImage() {
    final OffsetLayer offsetLayer = OffsetLayer();
    final PaintingContext context = PaintingContext(offsetLayer, Offset.zero & size);
    super.paint(context, Offset.zero);
    // This ignore is here because this method is protected by the `PaintingContext`. Adding a new
    // method that performs the work of `_paintAndDetachToImage` would avoid the need for this, but
    // that would conflict with our goals of minimizing painting context.
    // ignore: invalid_use_of_protected_member
    context.stopRecordingIfNeeded();
    if (mode != SnapshotMode.forced && !offsetLayer.supportsRasterization()) {
      if (mode == SnapshotMode.normal) {
        throw FlutterError('SnapshotWidget used with a child that contains a PlatformView.');
      }
      _disableSnapshotAttempt = true;
      return null;
    }
    final ui.Image image = offsetLayer.toImageSync(Offset.zero & size, pixelRatio: devicePixelRatio);
    offsetLayer.dispose();
    _lastCachedSize = size;
    return image;
  }

  Size? _lastCachedSize;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) {
      _childRaster?.dispose();
      _childRaster = null;
      _childRasterSize = null;
      return;
    }
    if (!controller.allowSnapshotting || _disableSnapshotAttempt) {
      _childRaster?.dispose();
      _childRaster = null;
      _childRasterSize = null;
      painter.paint(context, offset, size, super.paint);
      return;
    }

    if (autoresize && size != _lastCachedSize && _lastCachedSize != null) {
      _childRaster?.dispose();
      _childRaster = null;
    }

    if (_childRaster == null) {
      _childRaster = _paintAndDetachToImage();
      _childRasterSize = size * devicePixelRatio;
    }
    if (_childRaster == null) {
      painter.paint(context, offset, size, super.paint);
    } else {
      painter.paintSnapshot(context, offset, size, _childRaster!, _childRasterSize!, devicePixelRatio);
    }
  }
}

abstract class SnapshotPainter extends ChangeNotifier  {
  void paintSnapshot(PaintingContext context, Offset offset, Size size, ui.Image image, Size sourceSize, double pixelRatio);

  void paint(PaintingContext context, Offset offset, Size size, PaintingContextCallback painter);

  bool shouldRepaint(covariant SnapshotPainter oldPainter);
}

class _DefaultSnapshotPainter implements SnapshotPainter {
  const _DefaultSnapshotPainter();

  @override
  void addListener(ui.VoidCallback listener) { }

  @override
  void dispose() { }

  @override
  bool get hasListeners => false;

  @override
  void notifyListeners() { }

  @override
  void paint(PaintingContext context, ui.Offset offset, ui.Size size, PaintingContextCallback painter) {
    painter(context, offset);
  }

  @override
  void paintSnapshot(PaintingContext context, ui.Offset offset, ui.Size size, ui.Image image, Size sourceSize, double pixelRatio) {
    final Rect src = Rect.fromLTWH(0, 0, sourceSize.width, sourceSize.height);
    final Rect dst = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
    final Paint paint = Paint()
      ..filterQuality = FilterQuality.low;
    context.canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  void removeListener(ui.VoidCallback listener) { }

  @override
  bool shouldRepaint(covariant _DefaultSnapshotPainter oldPainter) => false;
}