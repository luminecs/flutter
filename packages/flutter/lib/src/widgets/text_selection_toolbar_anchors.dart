import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

@immutable
class TextSelectionToolbarAnchors {
  const TextSelectionToolbarAnchors({
    required this.primaryAnchor,
    this.secondaryAnchor,
  });

  factory TextSelectionToolbarAnchors.fromSelection({
    required RenderBox renderBox,
    required double startGlyphHeight,
    required double endGlyphHeight,
    required List<TextSelectionPoint> selectionEndpoints,
  }) {
    final Rect editingRegion = Rect.fromPoints(
      renderBox.localToGlobal(Offset.zero),
      renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero)),
    );

    if (editingRegion.left.isNaN ||
        editingRegion.top.isNaN ||
        editingRegion.right.isNaN ||
        editingRegion.bottom.isNaN) {
      return const TextSelectionToolbarAnchors(primaryAnchor: Offset.zero);
    }

    final bool isMultiline =
        selectionEndpoints.last.point.dy - selectionEndpoints.first.point.dy >
            endGlyphHeight / 2;

    final Rect selectionRect = Rect.fromLTRB(
      isMultiline
          ? editingRegion.left
          : editingRegion.left + selectionEndpoints.first.point.dx,
      editingRegion.top + selectionEndpoints.first.point.dy - startGlyphHeight,
      isMultiline
          ? editingRegion.right
          : editingRegion.left + selectionEndpoints.last.point.dx,
      editingRegion.top + selectionEndpoints.last.point.dy,
    );

    return TextSelectionToolbarAnchors(
      primaryAnchor: Offset(
        selectionRect.left + selectionRect.width / 2,
        clampDouble(selectionRect.top, editingRegion.top, editingRegion.bottom),
      ),
      secondaryAnchor: Offset(
        selectionRect.left + selectionRect.width / 2,
        clampDouble(
            selectionRect.bottom, editingRegion.top, editingRegion.bottom),
      ),
    );
  }

  final Offset primaryAnchor;

  final Offset? secondaryAnchor;
}
