
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui show FlutterView, Image;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'alignment.dart';
import 'basic_types.dart';
import 'binding.dart';
import 'borders.dart';
import 'box_fit.dart';
import 'debug.dart';
import 'image_provider.dart';
import 'image_stream.dart';

enum ImageRepeat {
  repeat,

  repeatX,

  repeatY,

  noRepeat,
}

@immutable
class DecorationImage {
  const DecorationImage({
    required this.image,
    this.onError,
    this.colorFilter,
    this.fit,
    this.alignment = Alignment.center,
    this.centerSlice,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.filterQuality = FilterQuality.low,
    this.invertColors = false,
    this.isAntiAlias = false,
  });

  final ImageProvider image;

  final ImageErrorListener? onError;

  final ColorFilter? colorFilter;

  final BoxFit? fit;

  final AlignmentGeometry alignment;

  final Rect? centerSlice;

  final ImageRepeat repeat;

  final bool matchTextDirection;

  final double scale;

  final double opacity;

  final FilterQuality filterQuality;

  final bool invertColors;

  final bool isAntiAlias;

  DecorationImagePainter createPainter(VoidCallback onChanged) {
    return _DecorationImagePainter._(this, onChanged);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is DecorationImage
        && other.image == image
        && other.colorFilter == colorFilter
        && other.fit == fit
        && other.alignment == alignment
        && other.centerSlice == centerSlice
        && other.repeat == repeat
        && other.matchTextDirection == matchTextDirection
        && other.scale == scale
        && other.opacity == opacity
        && other.filterQuality == filterQuality
        && other.invertColors == invertColors
        && other.isAntiAlias == isAntiAlias;
  }

  @override
  int get hashCode => Object.hash(
    image,
    colorFilter,
    fit,
    alignment,
    centerSlice,
    repeat,
    matchTextDirection,
    scale,
    opacity,
    filterQuality,
    invertColors,
    isAntiAlias,
  );

  @override
  String toString() {
    final List<String> properties = <String>[
      '$image',
      if (colorFilter != null)
        '$colorFilter',
      if (fit != null &&
          !(fit == BoxFit.fill && centerSlice != null) &&
          !(fit == BoxFit.scaleDown && centerSlice == null))
        '$fit',
      '$alignment',
      if (centerSlice != null)
        'centerSlice: $centerSlice',
      if (repeat != ImageRepeat.noRepeat)
        '$repeat',
      if (matchTextDirection)
        'match text direction',
      'scale ${scale.toStringAsFixed(1)}',
      'opacity ${opacity.toStringAsFixed(1)}',
      '$filterQuality',
      if (invertColors)
        'invert colors',
      if (isAntiAlias)
        'use anti-aliasing',
    ];
    return '${objectRuntimeType(this, 'DecorationImage')}(${properties.join(", ")})';
  }

  static DecorationImage? lerp(DecorationImage? a, DecorationImage? b, double t) {
    if (identical(a, b) || t == 0.0) {
      return a;
    }
    if (t == 1.0) {
      return b;
    }
    return _BlendedDecorationImage(a, b, t);
  }
}

abstract interface class DecorationImagePainter {
  void paint(Canvas canvas, Rect rect, Path? clipPath, ImageConfiguration configuration, { double blend = 1.0, BlendMode blendMode = BlendMode.srcOver });

  void dispose();
}

class _DecorationImagePainter implements DecorationImagePainter {
  _DecorationImagePainter._(this._details, this._onChanged);

  final DecorationImage _details;
  final VoidCallback _onChanged;

  ImageStream? _imageStream;
  ImageInfo? _image;

  @override
  void paint(Canvas canvas, Rect rect, Path? clipPath, ImageConfiguration configuration, { double blend = 1.0, BlendMode blendMode = BlendMode.srcOver }) {
    bool flipHorizontally = false;
    if (_details.matchTextDirection) {
      assert(() {
        // We check this first so that the assert will fire immediately, not just
        // when the image is ready.
        if (configuration.textDirection == null) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('DecorationImage.matchTextDirection can only be used when a TextDirection is available.'),
            ErrorDescription(
              'When DecorationImagePainter.paint() was called, there was no text direction provided '
              'in the ImageConfiguration object to match.',
            ),
            DiagnosticsProperty<DecorationImage>('The DecorationImage was', _details, style: DiagnosticsTreeStyle.errorProperty),
            DiagnosticsProperty<ImageConfiguration>('The ImageConfiguration was', configuration, style: DiagnosticsTreeStyle.errorProperty),
          ]);
        }
        return true;
      }());
      if (configuration.textDirection == TextDirection.rtl) {
        flipHorizontally = true;
      }
    }

    final ImageStream newImageStream = _details.image.resolve(configuration);
    if (newImageStream.key != _imageStream?.key) {
      final ImageStreamListener listener = ImageStreamListener(
        _handleImage,
        onError: _details.onError,
      );
      _imageStream?.removeListener(listener);
      _imageStream = newImageStream;
      _imageStream!.addListener(listener);
    }
    if (_image == null) {
      return;
    }

    if (clipPath != null) {
      canvas.save();
      canvas.clipPath(clipPath);
    }

    paintImage(
      canvas: canvas,
      rect: rect,
      image: _image!.image,
      debugImageLabel: _image!.debugLabel,
      scale: _details.scale * _image!.scale,
      colorFilter: _details.colorFilter,
      fit: _details.fit,
      alignment: _details.alignment.resolve(configuration.textDirection),
      centerSlice: _details.centerSlice,
      repeat: _details.repeat,
      flipHorizontally: flipHorizontally,
      opacity: _details.opacity * blend,
      filterQuality: _details.filterQuality,
      invertColors: _details.invertColors,
      isAntiAlias: _details.isAntiAlias,
      blendMode: blendMode,
    );

    if (clipPath != null) {
      canvas.restore();
    }
  }

  void _handleImage(ImageInfo value, bool synchronousCall) {
    if (_image == value) {
      return;
    }
    if (_image != null && _image!.isCloneOf(value)) {
      value.dispose();
      return;
    }
    _image?.dispose();
    _image = value;
    if (!synchronousCall) {
      _onChanged();
    }
  }

  @override
  void dispose() {
    _imageStream?.removeListener(ImageStreamListener(
      _handleImage,
      onError: _details.onError,
    ));
    _image?.dispose();
    _image = null;
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'DecorationImagePainter')}(stream: $_imageStream, image: $_image) for $_details';
  }
}

Map<String, ImageSizeInfo> _pendingImageSizeInfo = <String, ImageSizeInfo>{};

Set<ImageSizeInfo> _lastFrameImageSizeInfo = <ImageSizeInfo>{};

@visibleForTesting
void debugFlushLastFrameImageSizeInfo() {
  assert(() {
    _lastFrameImageSizeInfo = <ImageSizeInfo>{};
    return true;
  }());
}

void paintImage({
  required Canvas canvas,
  required Rect rect,
  required ui.Image image,
  String? debugImageLabel,
  double scale = 1.0,
  double opacity = 1.0,
  ColorFilter? colorFilter,
  BoxFit? fit,
  Alignment alignment = Alignment.center,
  Rect? centerSlice,
  ImageRepeat repeat = ImageRepeat.noRepeat,
  bool flipHorizontally = false,
  bool invertColors = false,
  FilterQuality filterQuality = FilterQuality.low,
  bool isAntiAlias = false,
  BlendMode blendMode = BlendMode.srcOver,
}) {
  assert(
    image.debugGetOpenHandleStackTraces()?.isNotEmpty ?? true,
    'Cannot paint an image that is disposed.\n'
    'The caller of paintImage is expected to wait to dispose the image until '
    'after painting has completed.',
  );
  if (rect.isEmpty) {
    return;
  }
  Size outputSize = rect.size;
  Size inputSize = Size(image.width.toDouble(), image.height.toDouble());
  Offset? sliceBorder;
  if (centerSlice != null) {
    sliceBorder = inputSize / scale - centerSlice.size as Offset;
    outputSize = outputSize - sliceBorder as Size;
    inputSize = inputSize - sliceBorder * scale as Size;
  }
  fit ??= centerSlice == null ? BoxFit.scaleDown : BoxFit.fill;
  assert(centerSlice == null || (fit != BoxFit.none && fit != BoxFit.cover));
  final FittedSizes fittedSizes = applyBoxFit(fit, inputSize / scale, outputSize);
  final Size sourceSize = fittedSizes.source * scale;
  Size destinationSize = fittedSizes.destination;
  if (centerSlice != null) {
    outputSize += sliceBorder!;
    destinationSize += sliceBorder;
    // We don't have the ability to draw a subset of the image at the same time
    // as we apply a nine-patch stretch.
    assert(sourceSize == inputSize, 'centerSlice was used with a BoxFit that does not guarantee that the image is fully visible.');
  }

  if (repeat != ImageRepeat.noRepeat && destinationSize == outputSize) {
    // There's no need to repeat the image because we're exactly filling the
    // output rect with the image.
    repeat = ImageRepeat.noRepeat;
  }
  final Paint paint = Paint()..isAntiAlias = isAntiAlias;
  if (colorFilter != null) {
    paint.colorFilter = colorFilter;
  }
  paint.color = Color.fromRGBO(0, 0, 0, clampDouble(opacity, 0.0, 1.0));
  paint.filterQuality = filterQuality;
  paint.invertColors = invertColors;
  paint.blendMode = blendMode;
  final double halfWidthDelta = (outputSize.width - destinationSize.width) / 2.0;
  final double halfHeightDelta = (outputSize.height - destinationSize.height) / 2.0;
  final double dx = halfWidthDelta + (flipHorizontally ? -alignment.x : alignment.x) * halfWidthDelta;
  final double dy = halfHeightDelta + alignment.y * halfHeightDelta;
  final Offset destinationPosition = rect.topLeft.translate(dx, dy);
  final Rect destinationRect = destinationPosition & destinationSize;

  // Set to true if we added a saveLayer to the canvas to invert/flip the image.
  bool invertedCanvas = false;
  // Output size and destination rect are fully calculated.

  // Implement debug-mode and profile-mode features:
  //  - cacheWidth/cacheHeight warning
  //  - debugInvertOversizedImages
  //  - debugOnPaintImage
  //  - Flutter.ImageSizesForFrame events in timeline
  if (!kReleaseMode) {
    // We can use the devicePixelRatio of the views directly here (instead of
    // going through a MediaQuery) because if it changes, whatever is aware of
    // the MediaQuery will be repainting the image anyways.
    // Furthermore, for the memory check below we just assume that all images
    // are decoded for the view with the highest device pixel ratio and use that
    // as an upper bound for the display size of the image.
    final double maxDevicePixelRatio = PaintingBinding.instance.platformDispatcher.views.fold(
      0.0,
      (double previousValue, ui.FlutterView view) => math.max(previousValue, view.devicePixelRatio),
    );
    final ImageSizeInfo sizeInfo = ImageSizeInfo(
      // Some ImageProvider implementations may not have given this.
      source: debugImageLabel ?? '<Unknown Image(${image.width}×${image.height})>',
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      displaySize: outputSize * maxDevicePixelRatio,
    );
    assert(() {
      if (debugInvertOversizedImages &&
          sizeInfo.decodedSizeInBytes > sizeInfo.displaySizeInBytes + debugImageOverheadAllowance) {
        final int overheadInKilobytes = (sizeInfo.decodedSizeInBytes - sizeInfo.displaySizeInBytes) ~/ 1024;
        final int outputWidth = sizeInfo.displaySize.width.toInt();
        final int outputHeight = sizeInfo.displaySize.height.toInt();
        FlutterError.reportError(FlutterErrorDetails(
          exception: 'Image $debugImageLabel has a display size of '
            '$outputWidth×$outputHeight but a decode size of '
            '${image.width}×${image.height}, which uses an additional '
            '${overheadInKilobytes}KB (assuming a device pixel ratio of '
            '$maxDevicePixelRatio).\n\n'
            'Consider resizing the asset ahead of time, supplying a cacheWidth '
            'parameter of $outputWidth, a cacheHeight parameter of '
            '$outputHeight, or using a ResizeImage.',
          library: 'painting library',
          context: ErrorDescription('while painting an image'),
        ));
        // Invert the colors of the canvas.
        canvas.saveLayer(
          destinationRect,
          Paint()..colorFilter = const ColorFilter.matrix(<double>[
            -1,  0,  0, 0, 255,
             0, -1,  0, 0, 255,
             0,  0, -1, 0, 255,
             0,  0,  0, 1,   0,
          ]),
        );
        // Flip the canvas vertically.
        final double dy = -(rect.top + rect.height / 2.0);
        canvas.translate(0.0, -dy);
        canvas.scale(1.0, -1.0);
        canvas.translate(0.0, dy);
        invertedCanvas = true;
      }
      return true;
    }());
    // Avoid emitting events that are the same as those emitted in the last frame.
    if (!_lastFrameImageSizeInfo.contains(sizeInfo)) {
      final ImageSizeInfo? existingSizeInfo = _pendingImageSizeInfo[sizeInfo.source];
      if (existingSizeInfo == null || existingSizeInfo.displaySizeInBytes < sizeInfo.displaySizeInBytes) {
        _pendingImageSizeInfo[sizeInfo.source!] = sizeInfo;
      }
      debugOnPaintImage?.call(sizeInfo);
      SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
        _lastFrameImageSizeInfo = _pendingImageSizeInfo.values.toSet();
        if (_pendingImageSizeInfo.isEmpty) {
          return;
        }
        developer.postEvent(
          'Flutter.ImageSizesForFrame',
          <String, Object>{
            for (final ImageSizeInfo imageSizeInfo in _pendingImageSizeInfo.values)
              imageSizeInfo.source!: imageSizeInfo.toJson(),
          },
        );
        _pendingImageSizeInfo = <String, ImageSizeInfo>{};
      });
    }
  }

  final bool needSave = centerSlice != null || repeat != ImageRepeat.noRepeat || flipHorizontally;
  if (needSave) {
    canvas.save();
  }
  if (repeat != ImageRepeat.noRepeat) {
    canvas.clipRect(rect);
  }
  if (flipHorizontally) {
    final double dx = -(rect.left + rect.width / 2.0);
    canvas.translate(-dx, 0.0);
    canvas.scale(-1.0, 1.0);
    canvas.translate(dx, 0.0);
  }
  if (centerSlice == null) {
    final Rect sourceRect = alignment.inscribe(
      sourceSize, Offset.zero & inputSize,
    );
    if (repeat == ImageRepeat.noRepeat) {
      canvas.drawImageRect(image, sourceRect, destinationRect, paint);
    } else {
      for (final Rect tileRect in _generateImageTileRects(rect, destinationRect, repeat)) {
        canvas.drawImageRect(image, sourceRect, tileRect, paint);
      }
    }
  } else {
    canvas.scale(1 / scale);
    if (repeat == ImageRepeat.noRepeat) {
      canvas.drawImageNine(image, _scaleRect(centerSlice, scale), _scaleRect(destinationRect, scale), paint);
    } else {
      for (final Rect tileRect in _generateImageTileRects(rect, destinationRect, repeat)) {
        canvas.drawImageNine(image, _scaleRect(centerSlice, scale), _scaleRect(tileRect, scale), paint);
      }
    }
  }
  if (needSave) {
    canvas.restore();
  }

  if (invertedCanvas) {
    canvas.restore();
  }
}

Iterable<Rect> _generateImageTileRects(Rect outputRect, Rect fundamentalRect, ImageRepeat repeat) {
  int startX = 0;
  int startY = 0;
  int stopX = 0;
  int stopY = 0;
  final double strideX = fundamentalRect.width;
  final double strideY = fundamentalRect.height;

  if (repeat == ImageRepeat.repeat || repeat == ImageRepeat.repeatX) {
    startX = ((outputRect.left - fundamentalRect.left) / strideX).floor();
    stopX = ((outputRect.right - fundamentalRect.right) / strideX).ceil();
  }

  if (repeat == ImageRepeat.repeat || repeat == ImageRepeat.repeatY) {
    startY = ((outputRect.top - fundamentalRect.top) / strideY).floor();
    stopY = ((outputRect.bottom - fundamentalRect.bottom) / strideY).ceil();
  }

  return <Rect>[
    for (int i = startX; i <= stopX; ++i)
      for (int j = startY; j <= stopY; ++j)
        fundamentalRect.shift(Offset(i * strideX, j * strideY)),
  ];
}

Rect _scaleRect(Rect rect, double scale) => Rect.fromLTRB(rect.left * scale, rect.top * scale, rect.right * scale, rect.bottom * scale);

// Implements DecorationImage.lerp when the image is different.
//
// This class just paints both decorations on top of each other, blended together.
//
// The Decoration properties are faked by just forwarded to the target image.
class _BlendedDecorationImage implements DecorationImage {
  const _BlendedDecorationImage(this.a, this.b, this.t) : assert(a != null || b != null);

  final DecorationImage? a;
  final DecorationImage? b;
  final double t;

  @override
  ImageProvider get image => b?.image ?? a!.image;
  @override
  ImageErrorListener? get onError => b?.onError ?? a!.onError;
  @override
  ColorFilter? get colorFilter => b?.colorFilter ?? a!.colorFilter;
  @override
  BoxFit? get fit => b?.fit ?? a!.fit;
  @override
  AlignmentGeometry get alignment => b?.alignment ?? a!.alignment;
  @override
  Rect? get centerSlice => b?.centerSlice ?? a!.centerSlice;
  @override
  ImageRepeat get repeat => b?.repeat ?? a!.repeat;
  @override
  bool get matchTextDirection => b?.matchTextDirection ?? a!.matchTextDirection;
  @override
  double get scale => b?.scale ?? a!.scale;
  @override
  double get opacity => b?.opacity ?? a!.opacity;
  @override
  FilterQuality get filterQuality => b?.filterQuality ?? a!.filterQuality;
  @override
  bool get invertColors => b?.invertColors ?? a!.invertColors;
  @override
  bool get isAntiAlias => b?.isAntiAlias ?? a!.isAntiAlias;

  @override
  DecorationImagePainter createPainter(VoidCallback onChanged) {
    return _BlendedDecorationImagePainter._(
      a?.createPainter(onChanged),
      b?.createPainter(onChanged),
      t,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _BlendedDecorationImage
        && other.a == a
        && other.b == b
        && other.t == t;
  }

  @override
  int get hashCode => Object.hash(a, b, t);

  @override
  String toString() {
    return '${objectRuntimeType(this, '_BlendedDecorationImage')}($a, $b, $t)';
  }
}

class _BlendedDecorationImagePainter implements DecorationImagePainter {
  _BlendedDecorationImagePainter._(this.a, this.b, this.t);

  final DecorationImagePainter? a;
  final DecorationImagePainter? b;
  final double t;

  @override
  void paint(Canvas canvas, Rect rect, Path? clipPath, ImageConfiguration configuration, { double blend = 1.0, BlendMode blendMode = BlendMode.srcOver }) {
    canvas.saveLayer(null, Paint());
    a?.paint(canvas, rect, clipPath, configuration, blend: blend * (1.0 - t), blendMode: blendMode);
    b?.paint(canvas, rect, clipPath, configuration, blend: blend * t, blendMode: a != null ? BlendMode.plus : blendMode);
    canvas.restore();
  }

  @override
  void dispose() {
    a?.dispose();
    b?.dispose();
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, '_BlendedDecorationImagePainter')}($a, $b, $t)';
  }
}