
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'debug.dart';

abstract class ShaderWarmUp {
  const ShaderWarmUp();

  ui.Size get size => const ui.Size(100.0, 100.0);

  @protected
  Future<void> warmUpOnCanvas(ui.Canvas canvas);

  Future<void> execute() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    await warmUpOnCanvas(canvas);
    final ui.Picture picture = recorder.endRecording();
    assert(debugCaptureShaderWarmUpPicture(picture));
    if (!kIsWeb || isCanvasKit) { // Picture.toImage is not yet implemented on the web.
      TimelineTask? debugShaderWarmUpTask;
      if (!kReleaseMode) {
        debugShaderWarmUpTask = TimelineTask()..start('Warm-up shader');
      }
      try {
        final ui.Image image = await picture.toImage(size.width.ceil(), size.height.ceil());
        assert(debugCaptureShaderWarmUpImage(image));
        image.dispose();
      } finally {
        if (!kReleaseMode) {
          debugShaderWarmUpTask!.finish();
        }
      }
    }
    picture.dispose();
  }
}