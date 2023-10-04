import 'package:flutter/services.dart';

import 'actions.dart';

class DoNothingAndStopPropagationTextIntent extends Intent {
  const DoNothingAndStopPropagationTextIntent();
}

abstract class DirectionalTextEditingIntent extends Intent {
  const DirectionalTextEditingIntent(
    this.forward,
  );

  final bool forward;
}

class DeleteCharacterIntent extends DirectionalTextEditingIntent {
  const DeleteCharacterIntent({required bool forward}) : super(forward);
}

class DeleteToNextWordBoundaryIntent extends DirectionalTextEditingIntent {
  const DeleteToNextWordBoundaryIntent({required bool forward})
      : super(forward);
}

class DeleteToLineBreakIntent extends DirectionalTextEditingIntent {
  const DeleteToLineBreakIntent({required bool forward}) : super(forward);
}

abstract class DirectionalCaretMovementIntent
    extends DirectionalTextEditingIntent {
  const DirectionalCaretMovementIntent(
    super.forward,
    this.collapseSelection, [
    this.collapseAtReversal = false,
    this.continuesAtWrap = false,
  ]) : assert(!collapseSelection || !collapseAtReversal);

  final bool collapseSelection;

  final bool collapseAtReversal;

  final bool continuesAtWrap;
}

class ExtendSelectionByCharacterIntent extends DirectionalCaretMovementIntent {
  const ExtendSelectionByCharacterIntent({
    required bool forward,
    required bool collapseSelection,
  }) : super(forward, collapseSelection);
}

class ExtendSelectionToNextWordBoundaryIntent
    extends DirectionalCaretMovementIntent {
  const ExtendSelectionToNextWordBoundaryIntent({
    required bool forward,
    required bool collapseSelection,
  }) : super(forward, collapseSelection);
}

class ExtendSelectionToNextWordBoundaryOrCaretLocationIntent
    extends DirectionalCaretMovementIntent {
  const ExtendSelectionToNextWordBoundaryOrCaretLocationIntent({
    required bool forward,
  }) : super(forward, false, true);
}

class ExpandSelectionToDocumentBoundaryIntent
    extends DirectionalCaretMovementIntent {
  const ExpandSelectionToDocumentBoundaryIntent({
    required bool forward,
  }) : super(forward, false);
}

class ExpandSelectionToLineBreakIntent extends DirectionalCaretMovementIntent {
  const ExpandSelectionToLineBreakIntent({
    required bool forward,
  }) : super(forward, false);
}

class ExtendSelectionToLineBreakIntent extends DirectionalCaretMovementIntent {
  const ExtendSelectionToLineBreakIntent({
    required bool forward,
    required bool collapseSelection,
    bool collapseAtReversal = false,
    bool continuesAtWrap = false,
  })  : assert(!collapseSelection || !collapseAtReversal),
        super(forward, collapseSelection, collapseAtReversal, continuesAtWrap);
}

class ExtendSelectionVerticallyToAdjacentLineIntent
    extends DirectionalCaretMovementIntent {
  const ExtendSelectionVerticallyToAdjacentLineIntent({
    required bool forward,
    required bool collapseSelection,
  }) : super(forward, collapseSelection);
}

class ExtendSelectionVerticallyToAdjacentPageIntent
    extends DirectionalCaretMovementIntent {
  const ExtendSelectionVerticallyToAdjacentPageIntent({
    required bool forward,
    required bool collapseSelection,
  }) : super(forward, collapseSelection);
}

class ExtendSelectionToNextParagraphBoundaryIntent
    extends DirectionalCaretMovementIntent {
  const ExtendSelectionToNextParagraphBoundaryIntent({
    required bool forward,
    required bool collapseSelection,
  }) : super(forward, collapseSelection);
}

class ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent
    extends DirectionalCaretMovementIntent {
  const ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent({
    required bool forward,
  }) : super(forward, false, true);
}

class ExtendSelectionToDocumentBoundaryIntent
    extends DirectionalCaretMovementIntent {
  const ExtendSelectionToDocumentBoundaryIntent({
    required bool forward,
    required bool collapseSelection,
  }) : super(forward, collapseSelection);
}

class ScrollToDocumentBoundaryIntent extends DirectionalTextEditingIntent {
  const ScrollToDocumentBoundaryIntent({
    required bool forward,
  }) : super(forward);
}

class ExtendSelectionByPageIntent extends DirectionalTextEditingIntent {
  const ExtendSelectionByPageIntent({
    required bool forward,
  }) : super(forward);
}

class SelectAllTextIntent extends Intent {
  const SelectAllTextIntent(this.cause);

  final SelectionChangedCause cause;
}

class CopySelectionTextIntent extends Intent {
  const CopySelectionTextIntent._(this.cause, this.collapseSelection);

  const CopySelectionTextIntent.cut(SelectionChangedCause cause)
      : this._(cause, true);

  static const CopySelectionTextIntent copy =
      CopySelectionTextIntent._(SelectionChangedCause.keyboard, false);

  final SelectionChangedCause cause;

  final bool collapseSelection;
}

class PasteTextIntent extends Intent {
  const PasteTextIntent(this.cause);

  final SelectionChangedCause cause;
}

class RedoTextIntent extends Intent {
  const RedoTextIntent(this.cause);

  final SelectionChangedCause cause;
}

class ReplaceTextIntent extends Intent {
  const ReplaceTextIntent(this.currentTextEditingValue, this.replacementText,
      this.replacementRange, this.cause);

  final TextEditingValue currentTextEditingValue;

  final String replacementText;

  final TextRange replacementRange;

  final SelectionChangedCause cause;
}

class UndoTextIntent extends Intent {
  const UndoTextIntent(this.cause);

  final SelectionChangedCause cause;
}

class UpdateSelectionIntent extends Intent {
  const UpdateSelectionIntent(
      this.currentTextEditingValue, this.newSelection, this.cause);

  final TextEditingValue currentTextEditingValue;

  final TextSelection newSelection;

  final SelectionChangedCause cause;
}

class TransposeCharactersIntent extends Intent {
  const TransposeCharactersIntent();
}
