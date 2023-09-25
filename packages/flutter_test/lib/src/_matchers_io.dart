import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:matcher/expect.dart';
import 'package:matcher/src/expect/async_matcher.dart'; // ignore: implementation_imports
import 'package:test_api/hooks.dart' show TestFailure;

import 'binding.dart';
import 'finders.dart';
import 'goldens.dart';

Future<ui.Image> captureImage(Element element) {
  assert(element.renderObject != null);
  RenderObject renderObject = element.renderObject!;
  while (!renderObject.isRepaintBoundary) {
    renderObject = renderObject.parent!;
  }
  assert(!renderObject.debugNeedsPaint);
  final OffsetLayer layer = renderObject.debugLayer! as OffsetLayer;
  return layer.toImage(renderObject.paintBounds);
}

const bool canCaptureImage = true;

class MatchesGoldenFile extends AsyncMatcher {
  const MatchesGoldenFile(this.key, this.version);

  MatchesGoldenFile.forStringPath(String path, this.version) : key = Uri.parse(path);

  final Uri key;

  final int? version;

  @override
  Future<String?> matchAsync(dynamic item) async {
    final Uri testNameUri = goldenFileComparator.getTestUri(key, version);

    Uint8List? buffer;
    if (item is Future<List<int>?>) {
      final List<int>? bytes = await item;
      buffer = bytes == null ? null : Uint8List.fromList(bytes);
    } else if (item is List<int>) {
      buffer = Uint8List.fromList(item);
    }
    if (buffer != null) {
      if (autoUpdateGoldenFiles) {
        await goldenFileComparator.update(testNameUri, buffer);
        return null;
      }
      try {
        final bool success = await goldenFileComparator.compare(buffer, testNameUri);
        return success ? null : 'does not match';
      } on TestFailure catch (ex) {
        return ex.message;
      }
    }
    Future<ui.Image?> imageFuture;
    final bool disposeImage; // set to true if the matcher created and owns the image and must therefore dispose it.
    if (item is Future<ui.Image?>) {
      imageFuture = item;
      disposeImage = false;
    } else if (item is ui.Image) {
      imageFuture = Future<ui.Image>.value(item);
      disposeImage = false;
    } else if (item is Finder) {
      final Iterable<Element> elements = item.evaluate();
      if (elements.isEmpty) {
        return 'could not be rendered because no widget was found';
      } else if (elements.length > 1) {
        return 'matched too many widgets';
      }
      imageFuture = captureImage(elements.single);
      disposeImage = true;
    } else {
      throw AssertionError('must provide a Finder, Image, Future<Image>, List<int>, or Future<List<int>>');
    }

    final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.instance;
    return binding.runAsync<String?>(() async {
      final ui.Image? image = await imageFuture;
      if (image == null) {
        throw AssertionError('Future<Image> completed to null');
      }
      try {
        final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) {
          return 'could not encode screenshot.';
        }
        if (autoUpdateGoldenFiles) {
          await goldenFileComparator.update(testNameUri, bytes.buffer.asUint8List());
          return null;
        }
        try {
          final bool success = await goldenFileComparator.compare(bytes.buffer.asUint8List(), testNameUri);
          return success ? null : 'does not match';
        } on TestFailure catch (ex) {
          return ex.message;
        }
      } finally {
        if (disposeImage) {
          image.dispose();
        }
      }
    });
  }

  @override
  Description describe(Description description) {
    final Uri testNameUri = goldenFileComparator.getTestUri(key, version);
    return description.add('one widget whose rasterized image matches golden image "$testNameUri"');
  }
}