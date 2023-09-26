import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show SelectionChangedCause, SuggestionSpan;
import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'localizations.dart';
import 'text_selection_toolbar.dart';
import 'text_selection_toolbar_button.dart';

const int _kMaxSuggestions = 3;

class CupertinoSpellCheckSuggestionsToolbar extends StatelessWidget {
  const CupertinoSpellCheckSuggestionsToolbar({
    super.key,
    required this.anchors,
    required this.buttonItems,
  }) : assert(buttonItems.length <= _kMaxSuggestions);

  CupertinoSpellCheckSuggestionsToolbar.editableText({
    super.key,
    required EditableTextState editableTextState,
  })  : buttonItems =
            buildButtonItems(editableTextState) ?? <ContextMenuButtonItem>[],
        anchors = editableTextState.contextMenuAnchors;

  final TextSelectionToolbarAnchors anchors;

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
    if (spanAtCursorIndex.suggestions.isEmpty) {
      assert(debugCheckHasCupertinoLocalizations(editableTextState.context));
      final CupertinoLocalizations localizations =
          CupertinoLocalizations.of(editableTextState.context);
      return <ContextMenuButtonItem>[
        ContextMenuButtonItem(
          onPressed: null,
          label: localizations.noSpellCheckReplacementsLabel,
        )
      ];
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
    return buttonItems;
  }

  static void _replaceText(EditableTextState editableTextState, String text,
      TextRange replacementRange) {
    // Replacement cannot be performed if the text is read only or obscured.
    assert(!editableTextState.widget.readOnly &&
        !editableTextState.widget.obscureText);

    final TextEditingValue newValue = editableTextState.textEditingValue
        .replaced(
          replacementRange,
          text,
        )
        .copyWith(
          selection: TextSelection.collapsed(
            offset: replacementRange.start + text.length,
          ),
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

  List<Widget> _buildToolbarButtons(BuildContext context) {
    return buttonItems.map((ContextMenuButtonItem buttonItem) {
      return CupertinoTextSelectionToolbarButton.buttonItem(
        buttonItem: buttonItem,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (buttonItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Widget> children = _buildToolbarButtons(context);
    return CupertinoTextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor == null
          ? anchors.primaryAnchor
          : anchors.secondaryAnchor!,
      children: children,
    );
  }
}
