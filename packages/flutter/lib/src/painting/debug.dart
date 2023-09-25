import 'dart:io';
import 'dart:ui' show Image, Picture, Size;

import 'package:flutter/foundation.dart';

bool debugDisableShadows = false;

typedef HttpClientProvider = HttpClient Function();

HttpClientProvider? debugNetworkImageHttpClientProvider;

typedef PaintImageCallback = void Function(ImageSizeInfo);

@immutable
class ImageSizeInfo {
  const ImageSizeInfo({this.source, required this.displaySize, required this.imageSize});

  final String? source;

  final Size displaySize;

  final Size imageSize;

  int get displaySizeInBytes => _sizeToBytes(displaySize);

  int get decodedSizeInBytes => _sizeToBytes(imageSize);

  int _sizeToBytes(Size size) {
    // Assume 4 bytes per pixel and that mipmapping will be used, which adds
    // 4/3.
    return (size.width * size.height * 4 * (4/3)).toInt();
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'source': source,
      'displaySize': <String, Object?>{
        'width': displaySize.width,
        'height': displaySize.height,
      },
      'imageSize': <String, Object?>{
        'width': imageSize.width,
        'height': imageSize.height,
      },
      'displaySizeInBytes': displaySizeInBytes,
      'decodedSizeInBytes': decodedSizeInBytes,
    };
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ImageSizeInfo
        && other.source == source
        && other.imageSize == imageSize
        && other.displaySize == displaySize;
  }

  @override
  int get hashCode => Object.hash(source, displaySize, imageSize);

  @override
  String toString() => 'ImageSizeInfo($source, imageSize: $imageSize, displaySize: $displaySize)';
}

PaintImageCallback? debugOnPaintImage;

bool debugInvertOversizedImages = false;

const int _imageOverheadAllowanceDefault = 128 * 1024;

int debugImageOverheadAllowance = _imageOverheadAllowanceDefault;

bool debugAssertAllPaintingVarsUnset(String reason, { bool debugDisableShadowsOverride = false }) {
  assert(() {
    if (debugDisableShadows != debugDisableShadowsOverride ||
        debugNetworkImageHttpClientProvider != null ||
        debugOnPaintImage != null ||
        debugInvertOversizedImages ||
        debugImageOverheadAllowance != _imageOverheadAllowanceDefault) {
      throw FlutterError(reason);
    }
    return true;
  }());
  return true;
}

typedef ShaderWarmUpPictureCallback = bool Function(Picture);

typedef ShaderWarmUpImageCallback = bool Function(Image);

ShaderWarmUpPictureCallback debugCaptureShaderWarmUpPicture = _defaultPictureCapture;
bool _defaultPictureCapture(Picture picture) => true;

ShaderWarmUpImageCallback debugCaptureShaderWarmUpImage = _defaultImageCapture;
bool _defaultImageCapture(Image image) => true;