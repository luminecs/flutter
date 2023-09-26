import 'dart:ui';

import 'recorder.dart';
import 'test_data.dart';

const double kRowHeight = 20.0;

const int kRows = 100;

const int kColumns = 10;

const double kScrollDelta = 2.0;

class BenchDynamicClipOnStaticPicture extends SceneBuilderRecorder {
  BenchDynamicClipOnStaticPicture() : super(name: benchmarkName) {
    // If the scrollable extent is too small, the benchmark may end up
    // scrolling the picture out of the clip area entirely, resulting in
    // bogus metric values.
    const double maxScrollExtent = kDefaultTotalSampleCount * kScrollDelta;
    const double pictureHeight = kRows * kRowHeight;
    if (maxScrollExtent > pictureHeight) {
      throw Exception(
          'Bad combination of constant values kRowHeight, kRows, and '
          'kScrollData. With these numbers there is risk that the picture '
          'will scroll out of the clip entirely. To fix the issue reduce '
          'kScrollDelta, or increase either kRows or kRowHeight.');
    }

    // Create one static picture, then never change it again.
    const Color black = Color.fromARGB(255, 0, 0, 0);
    final PictureRecorder pictureRecorder = PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    viewSize = view.physicalSize / view.devicePixelRatio;
    clipSize = Size(
      viewSize.width / 2,
      viewSize.height / 5,
    );
    final double cellWidth = viewSize.width / kColumns;

    final List<Paragraph> paragraphs = generateLaidOutParagraphs(
      paragraphCount: 500,
      minWordCountPerParagraph: 3,
      maxWordCountPerParagraph: 3,
      widthConstraint: cellWidth,
      color: black,
    );

    int paragraphCounter = 0;
    double yOffset = 0.0;
    for (int row = 0; row < kRows; row += 1) {
      for (int column = 0; column < kColumns; column += 1) {
        final double left = cellWidth * column;
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(
          left,
          yOffset,
          cellWidth,
          20.0,
        ));
        canvas.drawParagraph(
          paragraphs[paragraphCounter % paragraphs.length],
          Offset(left, yOffset),
        );
        canvas.restore();
        paragraphCounter += 1;
      }
      yOffset += kRowHeight;
    }

    picture = pictureRecorder.endRecording();
  }

  static const String benchmarkName = 'dynamic_clip_on_static_picture';

  late Size viewSize;
  late Size clipSize;
  late Picture picture;
  double pictureVerticalOffset = 0.0;

  @override
  void onDrawFrame(SceneBuilder sceneBuilder) {
    // Render the exact same picture, but offset it as if it's being scrolled.
    // This will move the clip along the Y axis in picture's local coordinates
    // causing a repaint. If we're not efficient at managing clips and/or
    // repaints this will jank (see https://github.com/flutter/flutter/issues/42987).
    final Rect clip = Rect.fromLTWH(0.0, 0.0, clipSize.width, clipSize.height);
    sceneBuilder.pushClipRect(clip);
    sceneBuilder.pushOffset(0.0, pictureVerticalOffset);
    sceneBuilder.addPicture(Offset.zero, picture);
    sceneBuilder.pop();
    sceneBuilder.pop();
    pictureVerticalOffset -= kScrollDelta;
  }
}
