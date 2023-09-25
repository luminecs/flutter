import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import 'basic.dart';
import 'container.dart';
import 'editable_text.dart';
import 'focus_manager.dart';
import 'framework.dart';
import 'inherited_notifier.dart';
import 'overlay.dart';
import 'shortcuts.dart';
import 'tap_region.dart';

// Examples can assume:
// late BuildContext context;

typedef AutocompleteOptionsBuilder<T extends Object> = FutureOr<Iterable<T>> Function(TextEditingValue textEditingValue);

typedef AutocompleteOnSelected<T extends Object> = void Function(T option);

typedef AutocompleteOptionsViewBuilder<T extends Object> = Widget Function(
  BuildContext context,
  AutocompleteOnSelected<T> onSelected,
  Iterable<T> options,
);

typedef AutocompleteFieldViewBuilder = Widget Function(
  BuildContext context,
  TextEditingController textEditingController,
  FocusNode focusNode,
  VoidCallback onFieldSubmitted,
);

typedef AutocompleteOptionToString<T extends Object> = String Function(T option);

enum OptionsViewOpenDirection {
  up,

  down,
}

// TODO(justinmc): Mention AutocompleteCupertino when it is implemented.
class RawAutocomplete<T extends Object> extends StatefulWidget {
  const RawAutocomplete({
    super.key,
    required this.optionsViewBuilder,
    required this.optionsBuilder,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
    this.displayStringForOption = defaultStringForOption,
    this.fieldViewBuilder,
    this.focusNode,
    this.onSelected,
    this.textEditingController,
    this.initialValue,
  }) : assert(
         fieldViewBuilder != null
            || (key != null && focusNode != null && textEditingController != null),
         'Pass in a fieldViewBuilder, or otherwise create a separate field and pass in the FocusNode, TextEditingController, and a key. Use the key with RawAutocomplete.onFieldSubmitted.',
        ),
       assert((focusNode == null) == (textEditingController == null)),
       assert(
         !(textEditingController != null && initialValue != null),
         'textEditingController and initialValue cannot be simultaneously defined.',
       );

  final AutocompleteFieldViewBuilder? fieldViewBuilder;

  final FocusNode? focusNode;

  final AutocompleteOptionsViewBuilder<T> optionsViewBuilder;

  final OptionsViewOpenDirection optionsViewOpenDirection;

  final AutocompleteOptionToString<T> displayStringForOption;

  final AutocompleteOnSelected<T>? onSelected;

  final AutocompleteOptionsBuilder<T> optionsBuilder;

  final TextEditingController? textEditingController;

  final TextEditingValue? initialValue;

  static void onFieldSubmitted<T extends Object>(GlobalKey key) {
    final _RawAutocompleteState<T> rawAutocomplete = key.currentState! as _RawAutocompleteState<T>;
    rawAutocomplete._onFieldSubmitted();
  }

  static String defaultStringForOption(Object? option) {
    return option.toString();
  }

  @override
  State<RawAutocomplete<T>> createState() => _RawAutocompleteState<T>();
}

class _RawAutocompleteState<T extends Object> extends State<RawAutocomplete<T>> {
  final GlobalKey _fieldKey = GlobalKey();
  final LayerLink _optionsLayerLink = LayerLink();
  late TextEditingController _textEditingController;
  late FocusNode _focusNode;
  late final Map<Type, Action<Intent>> _actionMap;
  late final _AutocompleteCallbackAction<AutocompletePreviousOptionIntent> _previousOptionAction;
  late final _AutocompleteCallbackAction<AutocompleteNextOptionIntent> _nextOptionAction;
  late final _AutocompleteCallbackAction<DismissIntent> _hideOptionsAction;
  Iterable<T> _options = Iterable<T>.empty();
  T? _selection;
  bool _userHidOptions = false;
  String _lastFieldText = '';
  final ValueNotifier<int> _highlightedOptionIndex = ValueNotifier<int>(0);

  static const Map<ShortcutActivator, Intent> _shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp): AutocompletePreviousOptionIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown): AutocompleteNextOptionIntent(),
  };

  // The OverlayEntry containing the options.
  OverlayEntry? _floatingOptions;

  // True iff the state indicates that the options should be visible.
  bool get _shouldShowOptions {
    return !_userHidOptions && _focusNode.hasFocus && _selection == null && _options.isNotEmpty;
  }

  // Called when _textEditingController changes.
  Future<void> _onChangedField() async {
    final TextEditingValue value = _textEditingController.value;
    final Iterable<T> options = await widget.optionsBuilder(
      value,
    );
    _options = options;
    _updateHighlight(_highlightedOptionIndex.value);
    if (_selection != null
        && value.text != widget.displayStringForOption(_selection!)) {
      _selection = null;
    }

    // Make sure the options are no longer hidden if the content of the field
    // changes (ignore selection changes).
    if (value.text != _lastFieldText) {
      _userHidOptions = false;
      _lastFieldText = value.text;
    }
    _updateActions();
    _updateOverlay();
  }

  // Called when the field's FocusNode changes.
  void _onChangedFocus() {
    // Options should no longer be hidden when the field is re-focused.
    _userHidOptions = !_focusNode.hasFocus;
    _updateActions();
    _updateOverlay();
  }

  // Called from fieldViewBuilder when the user submits the field.
  void _onFieldSubmitted() {
    if (_options.isEmpty || _userHidOptions) {
      return;
    }
    _select(_options.elementAt(_highlightedOptionIndex.value));
  }

  // Select the given option and update the widget.
  void _select(T nextSelection) {
    if (nextSelection == _selection) {
      return;
    }
    _selection = nextSelection;
    final String selectionString = widget.displayStringForOption(nextSelection);
    _textEditingController.value = TextEditingValue(
      selection: TextSelection.collapsed(offset: selectionString.length),
      text: selectionString,
    );
    _updateActions();
    _updateOverlay();
    widget.onSelected?.call(_selection!);
  }

  void _updateHighlight(int newIndex) {
    _highlightedOptionIndex.value = _options.isEmpty ? 0 : newIndex % _options.length;
  }

  void _highlightPreviousOption(AutocompletePreviousOptionIntent intent) {
    if (_userHidOptions) {
      _userHidOptions = false;
      _updateActions();
      _updateOverlay();
      return;
    }
    _updateHighlight(_highlightedOptionIndex.value - 1);
  }

  void _highlightNextOption(AutocompleteNextOptionIntent intent) {
    if (_userHidOptions) {
      _userHidOptions = false;
      _updateActions();
      _updateOverlay();
      return;
    }
    _updateHighlight(_highlightedOptionIndex.value + 1);
  }

  Object? _hideOptions(DismissIntent intent) {
    if (!_userHidOptions) {
      _userHidOptions = true;
      _updateActions();
      _updateOverlay();
      return null;
    }
    return Actions.invoke(context, intent);
  }

  void _setActionsEnabled(bool enabled) {
    // The enabled state determines whether the action will consume the
    // key shortcut or let it continue on to the underlying text field.
    // They should only be enabled when the options are showing so shortcuts
    // can be used to navigate them.
    _previousOptionAction.enabled = enabled;
    _nextOptionAction.enabled = enabled;
    _hideOptionsAction.enabled = enabled;
  }

  void _updateActions() {
    _setActionsEnabled(_focusNode.hasFocus && _selection == null && _options.isNotEmpty);
  }

  bool _floatingOptionsUpdateScheduled = false;
  // Hide or show the options overlay, if needed.
  void _updateOverlay() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (!_floatingOptionsUpdateScheduled) {
        _floatingOptionsUpdateScheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
          _floatingOptionsUpdateScheduled = false;
          _updateOverlay();
        });
      }
      return;
    }

    _floatingOptions?.remove();
    _floatingOptions?.dispose();
    if (_shouldShowOptions) {
      final OverlayEntry newFloatingOptions = OverlayEntry(
        builder: (BuildContext context) {
          return CompositedTransformFollower(
            link: _optionsLayerLink,
            showWhenUnlinked: false,
            targetAnchor: switch (widget.optionsViewOpenDirection) {
              OptionsViewOpenDirection.up => Alignment.topLeft,
              OptionsViewOpenDirection.down => Alignment.bottomLeft,
            },
            followerAnchor: switch (widget.optionsViewOpenDirection) {
              OptionsViewOpenDirection.up => Alignment.bottomLeft,
              OptionsViewOpenDirection.down => Alignment.topLeft,
            },
            child: TextFieldTapRegion(
              child: AutocompleteHighlightedOption(
                highlightIndexNotifier: _highlightedOptionIndex,
                child: Builder(
                  builder: (BuildContext context) {
                    return widget.optionsViewBuilder(context, _select, _options);
                  }
                )
              ),
            ),
          );
        },
      );
      Overlay.of(context, rootOverlay: true, debugRequiredFor: widget).insert(newFloatingOptions);
      _floatingOptions = newFloatingOptions;
    } else {
      _floatingOptions = null;
    }
  }

  // Handle a potential change in textEditingController by properly disposing of
  // the old one and setting up the new one, if needed.
  void _updateTextEditingController(TextEditingController? old, TextEditingController? current) {
    if ((old == null && current == null) || old == current) {
      return;
    }
    if (old == null) {
      _textEditingController.removeListener(_onChangedField);
      _textEditingController.dispose();
      _textEditingController = current!;
    } else if (current == null) {
      _textEditingController.removeListener(_onChangedField);
      _textEditingController = TextEditingController();
    } else {
      _textEditingController.removeListener(_onChangedField);
      _textEditingController = current;
    }
    _textEditingController.addListener(_onChangedField);
  }

  // Handle a potential change in focusNode by properly disposing of the old one
  // and setting up the new one, if needed.
  void _updateFocusNode(FocusNode? old, FocusNode? current) {
    if ((old == null && current == null) || old == current) {
      return;
    }
    if (old == null) {
      _focusNode.removeListener(_onChangedFocus);
      _focusNode.dispose();
      _focusNode = current!;
    } else if (current == null) {
      _focusNode.removeListener(_onChangedFocus);
      _focusNode = FocusNode();
    } else {
      _focusNode.removeListener(_onChangedFocus);
      _focusNode = current;
    }
    _focusNode.addListener(_onChangedFocus);
  }

  @override
  void initState() {
    super.initState();
    _textEditingController = widget.textEditingController ?? TextEditingController.fromValue(widget.initialValue);
    _textEditingController.addListener(_onChangedField);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onChangedFocus);
    _previousOptionAction = _AutocompleteCallbackAction<AutocompletePreviousOptionIntent>(onInvoke: _highlightPreviousOption);
    _nextOptionAction = _AutocompleteCallbackAction<AutocompleteNextOptionIntent>(onInvoke: _highlightNextOption);
    _hideOptionsAction = _AutocompleteCallbackAction<DismissIntent>(onInvoke: _hideOptions);
    _actionMap = <Type, Action<Intent>> {
      AutocompletePreviousOptionIntent: _previousOptionAction,
      AutocompleteNextOptionIntent: _nextOptionAction,
      DismissIntent: _hideOptionsAction,
    };
    _updateActions();
    _updateOverlay();
  }

  @override
  void didUpdateWidget(RawAutocomplete<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTextEditingController(
      oldWidget.textEditingController,
      widget.textEditingController,
    );
    _updateFocusNode(oldWidget.focusNode, widget.focusNode);
    _updateActions();
    _updateOverlay();
  }

  @override
  void dispose() {
    _textEditingController.removeListener(_onChangedField);
    if (widget.textEditingController == null) {
      _textEditingController.dispose();
    }
    _focusNode.removeListener(_onChangedFocus);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _floatingOptions?.remove();
    _floatingOptions?.dispose();
    _floatingOptions = null;
    _highlightedOptionIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Container(
        key: _fieldKey,
        child: Shortcuts(
          shortcuts: _shortcuts,
          child: Actions(
            actions: _actionMap,
            child: CompositedTransformTarget(
              link: _optionsLayerLink,
              child: widget.fieldViewBuilder == null
                ? const SizedBox.shrink()
                : widget.fieldViewBuilder!(
                    context,
                    _textEditingController,
                    _focusNode,
                    _onFieldSubmitted,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutocompleteCallbackAction<T extends Intent> extends CallbackAction<T> {
  _AutocompleteCallbackAction({
    required super.onInvoke,
    this.enabled = true,
  });

  bool enabled;

  @override
  bool isEnabled(covariant T intent) => enabled;

  @override
  bool consumesKey(covariant T intent) => enabled;
}

class AutocompletePreviousOptionIntent extends Intent {
  const AutocompletePreviousOptionIntent();
}

class AutocompleteNextOptionIntent extends Intent {
  const AutocompleteNextOptionIntent();
}

class AutocompleteHighlightedOption extends InheritedNotifier<ValueNotifier<int>> {
  const AutocompleteHighlightedOption({
    super.key,
    required ValueNotifier<int> highlightIndexNotifier,
    required super.child,
  }) : super(notifier: highlightIndexNotifier);

  static int of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AutocompleteHighlightedOption>()?.notifier?.value ?? 0;
  }
}