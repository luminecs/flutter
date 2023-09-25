class AndroidClassName {
  static const String checkBox = 'android.widget.CheckBox';

  static const String view = 'android.view.View';

  static const String radio = 'android.widget.RadioButton';

  static const String editText = 'android.widget.EditText';

  static const String textView = 'android.widget.TextView';

  static const String toggleSwitch = 'android.widget.Switch';

  static const String button = 'android.widget.Button';
}

enum AndroidSemanticsAction {

  focus(_kFocusIndex),

  clearFocus(_kClearFocusIndex),

  select(_kSelectIndex),

  clearSelection(_kClearSelectionIndex),

  click(_kClickIndex),

  longClick(_kLongClickIndex),

  accessibilityFocus(_kAccessibilityFocusIndex),

  clearAccessibilityFocus(_kClearAccessibilityFocusIndex),

  nextAtMovementGranularity(_kNextAtMovementGranularityIndex),

  previousAtMovementGranularity(_kPreviousAtMovementGranularityIndex),

  nextHtmlElement(_kNextHtmlElementIndex),

  previousHtmlElement(_kPreviousHtmlElementIndex),

  scrollForward(_kScrollForwardIndex),

  scrollBackward(_kScrollBackwardIndex),

  cut(_kCutIndex),

  copy(_kCopyIndex),

  paste(_kPasteIndex),

  setSelection(_kSetSelectionIndex),

  expand(_kExpandIndex),

  collapse(_kCollapseIndex),

  setText(_kSetText);

  const AndroidSemanticsAction(this.id);

  final int id;

  // These indices need to be in sync with android_semantics_testing/android/app/src/main/java/com/yourcompany/platforminteraction/MainActivity.java
  static const int _kFocusIndex = 1 << 0;
  static const int _kClearFocusIndex = 1 << 1;
  static const int _kSelectIndex = 1 << 2;
  static const int _kClearSelectionIndex = 1 << 3;
  static const int _kClickIndex = 1 << 4;
  static const int _kLongClickIndex = 1 << 5;
  static const int _kAccessibilityFocusIndex = 1 << 6;
  static const int _kClearAccessibilityFocusIndex = 1 << 7;
  static const int _kNextAtMovementGranularityIndex = 1 << 8;
  static const int _kPreviousAtMovementGranularityIndex = 1 << 9;
  static const int _kNextHtmlElementIndex = 1 << 10;
  static const int _kPreviousHtmlElementIndex = 1 << 11;
  static const int _kScrollForwardIndex = 1 << 12;
  static const int _kScrollBackwardIndex = 1 << 13;
  static const int _kCutIndex = 1 << 14;
  static const int _kCopyIndex = 1 << 15;
  static const int _kPasteIndex = 1 << 16;
  static const int _kSetSelectionIndex = 1 << 17;
  static const int _kExpandIndex = 1 << 18;
  static const int _kCollapseIndex = 1 << 19;
  static const int _kSetText = 1 << 21;

  static const Map<int, AndroidSemanticsAction> _kActionById = <int, AndroidSemanticsAction>{
    _kFocusIndex: focus,
    _kClearFocusIndex: clearFocus,
    _kSelectIndex: select,
    _kClearSelectionIndex: clearSelection,
    _kClickIndex: click,
    _kLongClickIndex: longClick,
    _kAccessibilityFocusIndex: accessibilityFocus,
    _kClearAccessibilityFocusIndex: clearAccessibilityFocus,
    _kNextAtMovementGranularityIndex: nextAtMovementGranularity,
    _kPreviousAtMovementGranularityIndex: previousAtMovementGranularity,
    _kNextHtmlElementIndex: nextHtmlElement,
    _kPreviousHtmlElementIndex: previousHtmlElement,
    _kScrollForwardIndex: scrollForward,
    _kScrollBackwardIndex: scrollBackward,
    _kCutIndex: cut,
    _kCopyIndex: copy,
    _kPasteIndex: paste,
    _kSetSelectionIndex: setSelection,
    _kExpandIndex: expand,
    _kCollapseIndex: collapse,
    _kSetText: setText,
  };

  static AndroidSemanticsAction? deserialize(int value) {
    return _kActionById[value];
  }
}