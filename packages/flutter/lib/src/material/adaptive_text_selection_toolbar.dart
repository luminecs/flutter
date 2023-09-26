import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import 'debug.dart';
import 'desktop_text_selection_toolbar.dart';
import 'desktop_text_selection_toolbar_button.dart';
import 'material_localizations.dart';
import 'text_selection_toolbar.dart';
import 'text_selection_toolbar_text_button.dart';
import 'theme.dart';

class AdaptiveTextSelectionToolbar extends StatelessWidget {
  const AdaptiveTextSelectionToolbar({
    super.key,
    required this.children,
    required this.anchors,
  }) : buttonItems = null;

  const AdaptiveTextSelectionToolbar.buttonItems({
    super.key,
    required this.buttonItems,
    required this.anchors,
  }) : children = null;

  AdaptiveTextSelectionToolbar.editable({
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

  AdaptiveTextSelectionToolbar.editableText({
    super.key,
    required EditableTextState editableTextState,
  })  : children = null,
        buttonItems = editableTextState.contextMenuButtonItems,
        anchors = editableTextState.contextMenuAnchors;

  AdaptiveTextSelectionToolbar.selectable({
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

  AdaptiveTextSelectionToolbar.selectableRegion({
    super.key,
    required SelectableRegionState selectableRegionState,
  })  : children = null,
        buttonItems = selectableRegionState.contextMenuButtonItems,
        anchors = selectableRegionState.contextMenuAnchors;

  final List<ContextMenuButtonItem>? buttonItems;

  final List<Widget>? children;

  final TextSelectionToolbarAnchors anchors;

  static String getButtonLabel(
      BuildContext context, ContextMenuButtonItem buttonItem) {
    if (buttonItem.label != null) {
      return buttonItem.label!;
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return CupertinoTextSelectionToolbarButton.getButtonLabel(
          context,
          buttonItem,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        assert(debugCheckHasMaterialLocalizations(context));
        final MaterialLocalizations localizations =
            MaterialLocalizations.of(context);
        switch (buttonItem.type) {
          case ContextMenuButtonType.cut:
            return localizations.cutButtonLabel;
          case ContextMenuButtonType.copy:
            return localizations.copyButtonLabel;
          case ContextMenuButtonType.paste:
            return localizations.pasteButtonLabel;
          case ContextMenuButtonType.selectAll:
            return localizations.selectAllButtonLabel;
          case ContextMenuButtonType.delete:
            return localizations.deleteButtonTooltip.toUpperCase();
          case ContextMenuButtonType.lookUp:
            return localizations.lookUpButtonLabel;
          case ContextMenuButtonType.searchWeb:
            return localizations.searchWebButtonLabel;
          case ContextMenuButtonType.share:
            return localizations.searchWebButtonLabel;
          case ContextMenuButtonType.liveTextInput:
            return localizations.scanTextButtonLabel;
          case ContextMenuButtonType.custom:
            return '';
        }
    }
  }

  static Iterable<Widget> getAdaptiveButtons(
      BuildContext context, List<ContextMenuButtonItem> buttonItems) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return CupertinoTextSelectionToolbarButton.buttonItem(
            buttonItem: buttonItem,
          );
        });
      case TargetPlatform.fuchsia:
      case TargetPlatform.android:
        final List<Widget> buttons = <Widget>[];
        for (int i = 0; i < buttonItems.length; i++) {
          final ContextMenuButtonItem buttonItem = buttonItems[i];
          buttons.add(TextSelectionToolbarTextButton(
            padding: TextSelectionToolbarTextButton.getPadding(
                i, buttonItems.length),
            onPressed: buttonItem.onPressed,
            child: Text(getButtonLabel(context, buttonItem)),
          ));
        }
        return buttons;
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return DesktopTextSelectionToolbarButton.text(
            context: context,
            onPressed: buttonItem.onPressed,
            text: getButtonLabel(context, buttonItem),
          );
        });
      case TargetPlatform.macOS:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return CupertinoDesktopTextSelectionToolbarButton.text(
            onPressed: buttonItem.onPressed,
            text: getButtonLabel(context, buttonItem),
          );
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there aren't any buttons to build, build an empty toolbar.
    if ((children != null && children!.isEmpty) ||
        (buttonItems != null && buttonItems!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final List<Widget> resultChildren = children != null
        ? children!
        : getAdaptiveButtons(context, buttonItems!).toList();

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
        return CupertinoTextSelectionToolbar(
          anchorAbove: anchors.primaryAnchor,
          anchorBelow: anchors.secondaryAnchor == null
              ? anchors.primaryAnchor
              : anchors.secondaryAnchor!,
          children: resultChildren,
        );
      case TargetPlatform.android:
        return TextSelectionToolbar(
          anchorAbove: anchors.primaryAnchor,
          anchorBelow: anchors.secondaryAnchor == null
              ? anchors.primaryAnchor
              : anchors.secondaryAnchor!,
          children: resultChildren,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return DesktopTextSelectionToolbar(
          anchor: anchors.primaryAnchor,
          children: resultChildren,
        );
      case TargetPlatform.macOS:
        return CupertinoDesktopTextSelectionToolbar(
          anchor: anchors.primaryAnchor,
          children: resultChildren,
        );
    }
  }
}
