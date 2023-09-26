import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'desktop_text_selection_toolbar.dart';
import 'desktop_text_selection_toolbar_button.dart';
import 'text_selection_toolbar.dart';
import 'text_selection_toolbar_button.dart';

class CupertinoAdaptiveTextSelectionToolbar extends StatelessWidget {
  const CupertinoAdaptiveTextSelectionToolbar({
    super.key,
    required this.children,
    required this.anchors,
  }) : buttonItems = null;

  const CupertinoAdaptiveTextSelectionToolbar.buttonItems({
    super.key,
    required this.buttonItems,
    required this.anchors,
  }) : children = null;

  CupertinoAdaptiveTextSelectionToolbar.editable({
    super.key,
    required ClipboardStatus clipboardStatus,
    required VoidCallback? onCopy,
    required VoidCallback? onCut,
    required VoidCallback? onPaste,
    required VoidCallback? onSelectAll,
    required VoidCallback? onLookUp,
    required VoidCallback? onSearchWeb,
    required VoidCallback? onShare,
    required VoidCallback? onLiveTextInput,
    required this.anchors,
  })  : children = null,
        buttonItems = EditableText.getEditableButtonItems(
            clipboardStatus: clipboardStatus,
            onCopy: onCopy,
            onCut: onCut,
            onPaste: onPaste,
            onSelectAll: onSelectAll,
            onLookUp: onLookUp,
            onSearchWeb: onSearchWeb,
            onShare: onShare,
            onLiveTextInput: onLiveTextInput);

  CupertinoAdaptiveTextSelectionToolbar.editableText({
    super.key,
    required EditableTextState editableTextState,
  })  : children = null,
        buttonItems = editableTextState.contextMenuButtonItems,
        anchors = editableTextState.contextMenuAnchors;

  CupertinoAdaptiveTextSelectionToolbar.selectable({
    super.key,
    required VoidCallback onCopy,
    required VoidCallback onSelectAll,
    required SelectionGeometry selectionGeometry,
    required this.anchors,
  })  : children = null,
        buttonItems = SelectableRegion.getSelectableButtonItems(
          selectionGeometry: selectionGeometry,
          onCopy: onCopy,
          onSelectAll: onSelectAll,
        );

  final TextSelectionToolbarAnchors anchors;

  final List<Widget>? children;

  final List<ContextMenuButtonItem>? buttonItems;

  static Iterable<Widget> getAdaptiveButtons(
      BuildContext context, List<ContextMenuButtonItem> buttonItems) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return CupertinoTextSelectionToolbarButton.buttonItem(
            buttonItem: buttonItem,
          );
        });
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return CupertinoDesktopTextSelectionToolbarButton.buttonItem(
            buttonItem: buttonItem,
          );
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there aren't any buttons to build, build an empty toolbar.
    if ((children?.isEmpty ?? false) || (buttonItems?.isEmpty ?? false)) {
      return const SizedBox.shrink();
    }

    final List<Widget> resultChildren =
        children ?? getAdaptiveButtons(context, buttonItems!).toList();

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return CupertinoTextSelectionToolbar(
          anchorAbove: anchors.primaryAnchor,
          anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
          children: resultChildren,
        );
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        return CupertinoDesktopTextSelectionToolbar(
          anchor: anchors.primaryAnchor,
          children: resultChildren,
        );
    }
  }
}
