import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show SelectionChangedCause, SuggestionSpan;

import 'adaptive_text_selection_toolbar.dart';
import 'colors.dart';
import 'material.dart';
import 'spell_check_suggestions_toolbar_layout_delegate.dart';
import 'text_selection_toolbar_text_button.dart';

// The default height of the SpellCheckSuggestionsToolbar, which
// assumes there are the maximum number of spell check suggestions available, 3.
// Size eyeballed on Pixel 4 emulator running Android API 31.
const double _kDefaultToolbarHeight = 193.0;

const int _kMaxSuggestions = 3;

class SpellCheckSuggestionsToolbar extends StatelessWidget {
  const SpellCheckSuggestionsToolbar({
    super.key,
    required this.anchor,
    required this.buttonItems,
  }) : assert(buttonItems.length <= _kMaxSuggestions + 1);

  SpellCheckSuggestionsToolbar.editableText({
    super.key,
    required EditableTextState editableTextState,
  })  : buttonItems =
            buildButtonItems(editableTextState) ?? <ContextMenuButtonItem>[],
        anchor = getToolbarAnchor(editableTextState.contextMenuAnchors);

  final Offset anchor;

  final List<ContextMenuButtonItem> buttonItems;

  static List<ContextMenuButtonItem>? buildButtonItems(
    EditableTextState editableTextState,
  ) {
    // Determine if composing region is misspelled.
    final SuggestionSpan? spanAtCursorIndex =
        editableTextState.findSuggestionSpanAtCursorIndex(
      editableTextState.currentTextEditingValue.selection.baseOffset,
    );

    if (spanAtCursorIndex == null) {
      return null;
    }

    final List<ContextMenuButtonItem> buttonItems = <ContextMenuButtonItem>[];

    // Build suggestion buttons.
    for (final String suggestion
        in spanAtCursorIndex.suggestions.take(_kMaxSuggestions)) {
      buttonItems.add(ContextMenuButtonItem(
        onPressed: () {
          if (!editableTextState.mounted) {
            return;
          }
          _replaceText(
            editableTextState,
            suggestion,
            spanAtCursorIndex.range,
          );
        },
        label: suggestion,
      ));
    }

    // Build delete button.
    final ContextMenuButtonItem deleteButton = ContextMenuButtonItem(
      onPressed: () {
        if (!editableTextState.mounted) {
          return;
        }
        _replaceText(
          editableTextState,
          '',
          editableTextState.currentTextEditingValue.composing,
        );
      },
      type: ContextMenuButtonType.delete,
    );
    buttonItems.add(deleteButton);

    return buttonItems;
  }

  static void _replaceText(EditableTextState editableTextState, String text,
      TextRange replacementRange) {
    // Replacement cannot be performed if the text is read only or obscured.
    assert(!editableTextState.widget.readOnly &&
        !editableTextState.widget.obscureText);

    final TextEditingValue newValue =
        editableTextState.textEditingValue.replaced(
      replacementRange,
      text,
    );
    editableTextState.userUpdateTextEditingValue(
        newValue, SelectionChangedCause.toolbar);

    // Schedule a call to bringIntoView() after renderEditable updates.
    SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
      if (editableTextState.mounted) {
        editableTextState
            .bringIntoView(editableTextState.textEditingValue.selection.extent);
      }
    });
    editableTextState.hideToolbar();
  }

  static Offset getToolbarAnchor(TextSelectionToolbarAnchors anchors) {
    // Since this will be positioned below the anchor point, use the secondary
    // anchor by default.
    return anchors.secondaryAnchor == null
        ? anchors.primaryAnchor
        : anchors.secondaryAnchor!;
  }

  List<Widget> _buildToolbarButtons(BuildContext context) {
    return buttonItems.map((ContextMenuButtonItem buttonItem) {
      final TextSelectionToolbarTextButton button =
          TextSelectionToolbarTextButton(
        padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
        onPressed: buttonItem.onPressed,
        alignment: Alignment.centerLeft,
        child: Text(
          AdaptiveTextSelectionToolbar.getButtonLabel(context, buttonItem),
          style: buttonItem.type == ContextMenuButtonType.delete
              ? const TextStyle(color: Colors.blue)
              : null,
        ),
      );

      if (buttonItem.type != ContextMenuButtonType.delete) {
        return button;
      }
      return DecoratedBox(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey))),
        child: button,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (buttonItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Adjust toolbar height if needed.
    final double spellCheckSuggestionsToolbarHeight =
        _kDefaultToolbarHeight - (48.0 * (4 - buttonItems.length));
    // Incorporate the padding distance between the content and toolbar.
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    final double softKeyboardViewInsetsBottom =
        mediaQueryData.viewInsets.bottom;
    final double paddingAbove = mediaQueryData.padding.top +
        CupertinoTextSelectionToolbar.kToolbarScreenPadding;
    // Makes up for the Padding.
    final Offset localAdjustment = Offset(
      CupertinoTextSelectionToolbar.kToolbarScreenPadding,
      paddingAbove,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        CupertinoTextSelectionToolbar.kToolbarScreenPadding,
        paddingAbove,
        CupertinoTextSelectionToolbar.kToolbarScreenPadding,
        CupertinoTextSelectionToolbar.kToolbarScreenPadding +
            softKeyboardViewInsetsBottom,
      ),
      child: CustomSingleChildLayout(
        delegate: SpellCheckSuggestionsToolbarLayoutDelegate(
          anchor: anchor - localAdjustment,
        ),
        child: AnimatedSize(
          // This duration was eyeballed on a Pixel 2 emulator running Android
          // API 28 for the Material TextSelectionToolbar.
          duration: const Duration(milliseconds: 140),
          child: _SpellCheckSuggestionsToolbarContainer(
            height: spellCheckSuggestionsToolbarHeight,
            children: <Widget>[..._buildToolbarButtons(context)],
          ),
        ),
      ),
    );
  }
}

class _SpellCheckSuggestionsToolbarContainer extends StatelessWidget {
  const _SpellCheckSuggestionsToolbarContainer({
    required this.height,
    required this.children,
  });

  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      // This elevation was eyeballed on a Pixel 4 emulator running Android
      // API 31 for the SpellCheckSuggestionsToolbar.
      elevation: 2.0,
      type: MaterialType.card,
      child: SizedBox(
        // This width was eyeballed on a Pixel 4 emulator running Android
        // API 31 for the SpellCheckSuggestionsToolbar.
        width: 165.0,
        height: height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
