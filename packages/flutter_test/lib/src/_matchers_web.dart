
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
  throw UnsupportedError('captureImage is not supported on the web.');
}

const bool canCaptureImage = false;

class MatchesGoldenFile extends AsyncMatcher {
  const MatchesGoldenFile(this.key, this.version);

  MatchesGoldenFile.forStringPath(String path, this.version) : key = Uri.parse(path);

  final Uri key;

  final int? version;

  @override
  Future<String?> matchAsync(dynamic item) async {
    if (item is! Finder) {
      return 'web goldens only supports matching finders.';
    }
    final Iterable<Element> elements = item.evaluate();
    if (elements.isEmpty) {
      return 'could not be rendered because no widget was found';
    } else if (elements.length > 1) {
      return 'matched too many widgets';
    }
    final Element element = elements.single;
    final RenderObject renderObject = _findRepaintBoundary(element);
    final Size size = renderObject.paintBounds.size;
    final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.instance;
    final ui.FlutterView view = binding.platformDispatcher.implicitView!;
    final RenderView renderView = binding.renderViews.firstWhere((RenderView r) => r.flutterView == view);

    // Unlike `flutter_tester`, we don't have the ability to render an element
    // to an image directly. Instead, we will use `window.render()` to render
    // only the element being requested, and send a request to the test server
    // requesting it to take a screenshot through the browser's debug interface.
    _renderElement(view, renderObject);
    final String? result = await binding.runAsync<String?>(() async {
      if (autoUpdateGoldenFiles) {
        await webGoldenComparator.update(size.width, size.height, key);
        return null;
      }
      try {
        final bool success = await webGoldenComparator.compare(size.width, size.height, key);
        return success ? null : 'does not match';
      } on TestFailure catch (ex) {
        return ex.message;
      }
    });
    _renderElement(view, renderView);
    return result;
  }

  @override
  Description describe(Description description) {
    final Uri testNameUri = webGoldenComparator.getTestUri(key, version);
    return description.add('one widget whose rasterized image matches golden image "$testNameUri"');
  }
}

RenderObject _findRepaintBoundary(Element element) {
  assert(element.renderObject != null);
  RenderObject renderObject = element.renderObject!;
  while (!renderObject.isRepaintBoundary) {
    renderObject = renderObject.parent!;
  }
  return renderObject;
}

void _renderElement(ui.FlutterView window, RenderObject renderObject) {
  assert(renderObject.debugLayer != null);
  final Layer layer = renderObject.debugLayer!;
  final ui.SceneBuilder sceneBuilder = ui.SceneBuilder();
  if (layer is OffsetLayer) {
    sceneBuilder.pushOffset(-layer.offset.dx, -layer.offset.dy);
  }
  // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
  layer.updateSubtreeNeedsAddToScene();
  // ignore: invalid_use_of_protected_member
  layer.addToScene(sceneBuilder);
  sceneBuilder.pop();
  window.render(sceneBuilder.build());
}