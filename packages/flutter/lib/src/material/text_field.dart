// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show BoxHeightStyle, BoxWidthStyle;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'adaptive_text_selection_toolbar.dart';
import 'color_scheme.dart';
import 'colors.dart';
import 'debug.dart';
import 'desktop_text_selection.dart';
import 'feedback.dart';
import 'input_decorator.dart';
import 'magnifier.dart';
import 'material_localizations.dart';
import 'material_state.dart';
import 'selectable_text.dart' show iOSHorizontalOffset;
import 'spell_check_suggestions_toolbar.dart';
import 'text_selection.dart';
import 'theme.dart';

export 'package:flutter/services.dart' show SmartDashesType, SmartQuotesType, TextCapitalization, TextInputAction, TextInputType;

// Examples can assume:
// late BuildContext context;
// late FocusNode myFocusNode;

typedef InputCounterWidgetBuilder = Widget? Function(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
});

class _TextFieldSelectionGestureDetectorBuilder extends TextSelectionGestureDetectorBuilder {
  _TextFieldSelectionGestureDetectorBuilder({
    required _TextFieldState state,
  }) : _state = state,
       super(delegate: state);

  final _TextFieldState _state;

  @override
  void onForcePressStart(ForcePressDetails details) {
    super.onForcePressStart(details);
    if (delegate.selectionEnabled && shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
  }

  @override
  void onForcePressEnd(ForcePressDetails details) {
    // Not required.
  }

  @override
  void onSingleTapUp(TapDragUpDetails details) {
    super.onSingleTapUp(details);
    _state._requestKeyboard();
    _state.widget.onTap?.call();
  }

  @override
  void onSingleLongTapStart(LongPressStartDetails details) {
    super.onSingleLongTapStart(details);
    if (delegate.selectionEnabled) {
      switch (Theme.of(_state.context).platform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          break;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          Feedback.forLongPress(_state.context);
      }
    }
  }
}

class TextField extends StatefulWidget {
  const TextField({
    super.key,
    this.controller,
    this.focusNode,
    this.undoController,
    this.decoration = const InputDecoration(),
    TextInputType? keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.readOnly = false,
    @Deprecated(
      'Use `contextMenuBuilder` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    this.toolbarOptions,
    this.showCursor,
    this.autofocus = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    SmartDashesType? smartDashesType,
    SmartQuotesType? smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.inputFormatters,
    this.enabled,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorOpacityAnimates,
    this.cursorColor,
    this.selectionHeightStyle = ui.BoxHeightStyle.tight,
    this.selectionWidthStyle = ui.BoxWidthStyle.tight,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.dragStartBehavior = DragStartBehavior.start,
    bool? enableInteractiveSelection,
    this.selectionControls,
    this.onTap,
    this.onTapOutside,
    this.mouseCursor,
    this.buildCounter,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints = const <String>[],
    this.contentInsertionConfiguration,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scribbleEnabled = true,
    this.enableIMEPersonalizedLearning = true,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
    this.canRequestFocus = true,
    this.spellCheckConfiguration,
    this.magnifierConfiguration,
  }) : assert(obscuringCharacter.length == 1),
       smartDashesType = smartDashesType ?? (obscureText ? SmartDashesType.disabled : SmartDashesType.enabled),
       smartQuotesType = smartQuotesType ?? (obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled),
       assert(maxLines == null || maxLines > 0),
       assert(minLines == null || minLines > 0),
       assert(
         (maxLines == null) || (minLines == null) || (maxLines >= minLines),
         "minLines can't be greater than maxLines",
       ),
       assert(
         !expands || (maxLines == null && minLines == null),
         'minLines and maxLines must be null when expands is true.',
       ),
       assert(!obscureText || maxLines == 1, 'Obscured fields cannot be multiline.'),
       assert(maxLength == null || maxLength == TextField.noMaxLength || maxLength > 0),
       // Assert the following instead of setting it directly to avoid surprising the user by silently changing the value they set.
       assert(
         !identical(textInputAction, TextInputAction.newline) ||
         maxLines == 1 ||
         !identical(keyboardType, TextInputType.text),
         'Use keyboardType TextInputType.multiline when using TextInputAction.newline on a multiline TextField.',
       ),
       keyboardType = keyboardType ?? (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
       enableInteractiveSelection = enableInteractiveSelection ?? (!readOnly || !obscureText);

  final TextMagnifierConfiguration? magnifierConfiguration;

  final TextEditingController? controller;

  final FocusNode? focusNode;

  final InputDecoration? decoration;

  final TextInputType keyboardType;

  final TextInputAction? textInputAction;

  final TextCapitalization textCapitalization;

  final TextStyle? style;

  final StrutStyle? strutStyle;

  final TextAlign textAlign;

  final TextAlignVertical? textAlignVertical;

  final TextDirection? textDirection;

  final bool autofocus;

  final String obscuringCharacter;

  final bool obscureText;

  final bool autocorrect;

  final SmartDashesType smartDashesType;

  final SmartQuotesType smartQuotesType;

  final bool enableSuggestions;

  final int? maxLines;

  final int? minLines;

  final bool expands;

  final bool readOnly;

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  final ToolbarOptions? toolbarOptions;

  final bool? showCursor;

  static const int noMaxLength = -1;

  final int? maxLength;

  final MaxLengthEnforcement? maxLengthEnforcement;

  final ValueChanged<String>? onChanged;

  final VoidCallback? onEditingComplete;

  final ValueChanged<String>? onSubmitted;

  final AppPrivateCommandCallback? onAppPrivateCommand;

  final List<TextInputFormatter>? inputFormatters;

  final bool? enabled;

  final double cursorWidth;

  final double? cursorHeight;

  final Radius? cursorRadius;

  final bool? cursorOpacityAnimates;

  final Color? cursorColor;

  final ui.BoxHeightStyle selectionHeightStyle;

  final ui.BoxWidthStyle selectionWidthStyle;

  final Brightness? keyboardAppearance;

  final EdgeInsets scrollPadding;

  final bool enableInteractiveSelection;

  final TextSelectionControls? selectionControls;

  final DragStartBehavior dragStartBehavior;

  bool get selectionEnabled => enableInteractiveSelection;

  final GestureTapCallback? onTap;

  final TapRegionCallback? onTapOutside;

  final MouseCursor? mouseCursor;

  final InputCounterWidgetBuilder? buildCounter;

  final ScrollPhysics? scrollPhysics;

  final ScrollController? scrollController;

  final Iterable<String>? autofillHints;

  final Clip clipBehavior;

  final String? restorationId;

  final bool scribbleEnabled;

  final bool enableIMEPersonalizedLearning;

  final ContentInsertionConfiguration? contentInsertionConfiguration;

  final EditableTextContextMenuBuilder? contextMenuBuilder;

  final bool canRequestFocus;

  final UndoHistoryController? undoController;

  static Widget _defaultContextMenuBuilder(BuildContext context, EditableTextState editableTextState) {
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  final SpellCheckConfiguration? spellCheckConfiguration;

  static const TextStyle materialMisspelledTextStyle =
    TextStyle(
      decoration: TextDecoration.underline,
      decorationColor: Colors.red,
      decorationStyle: TextDecorationStyle.wavy,
    );

  @visibleForTesting
  static Widget defaultSpellCheckSuggestionsToolbarBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return CupertinoSpellCheckSuggestionsToolbar.editableText(
          editableTextState: editableTextState,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return SpellCheckSuggestionsToolbar.editableText(
          editableTextState: editableTextState,
        );
    }
  }

  static SpellCheckConfiguration inferAndroidSpellCheckConfiguration(
    SpellCheckConfiguration? configuration,
  ) {
    if (configuration == null
      || configuration == const SpellCheckConfiguration.disabled()) {
      return const SpellCheckConfiguration.disabled();
    }
    return configuration.copyWith(
      misspelledTextStyle: configuration.misspelledTextStyle
        ?? TextField.materialMisspelledTextStyle,
      spellCheckSuggestionsToolbarBuilder:
        configuration.spellCheckSuggestionsToolbarBuilder
          ?? TextField.defaultSpellCheckSuggestionsToolbarBuilder,
    );
  }

  @override
  State<TextField> createState() => _TextFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextEditingController>('controller', controller, defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode, defaultValue: null));
    properties.add(DiagnosticsProperty<UndoHistoryController>('undoController', undoController, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('enabled', enabled, defaultValue: null));
    properties.add(DiagnosticsProperty<InputDecoration>('decoration', decoration, defaultValue: const InputDecoration()));
    properties.add(DiagnosticsProperty<TextInputType>('keyboardType', keyboardType, defaultValue: TextInputType.text));
    properties.add(DiagnosticsProperty<TextStyle>('style', style, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false));
    properties.add(DiagnosticsProperty<String>('obscuringCharacter', obscuringCharacter, defaultValue: '•'));
    properties.add(DiagnosticsProperty<bool>('obscureText', obscureText, defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('autocorrect', autocorrect, defaultValue: true));
    properties.add(EnumProperty<SmartDashesType>('smartDashesType', smartDashesType, defaultValue: obscureText ? SmartDashesType.disabled : SmartDashesType.enabled));
    properties.add(EnumProperty<SmartQuotesType>('smartQuotesType', smartQuotesType, defaultValue: obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled));
    properties.add(DiagnosticsProperty<bool>('enableSuggestions', enableSuggestions, defaultValue: true));
    properties.add(IntProperty('maxLines', maxLines, defaultValue: 1));
    properties.add(IntProperty('minLines', minLines, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(IntProperty('maxLength', maxLength, defaultValue: null));
    properties.add(EnumProperty<MaxLengthEnforcement>('maxLengthEnforcement', maxLengthEnforcement, defaultValue: null));
    properties.add(EnumProperty<TextInputAction>('textInputAction', textInputAction, defaultValue: null));
    properties.add(EnumProperty<TextCapitalization>('textCapitalization', textCapitalization, defaultValue: TextCapitalization.none));
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign, defaultValue: TextAlign.start));
    properties.add(DiagnosticsProperty<TextAlignVertical>('textAlignVertical', textAlignVertical, defaultValue: null));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
    properties.add(DoubleProperty('cursorWidth', cursorWidth, defaultValue: 2.0));
    properties.add(DoubleProperty('cursorHeight', cursorHeight, defaultValue: null));
    properties.add(DiagnosticsProperty<Radius>('cursorRadius', cursorRadius, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('cursorOpacityAnimates', cursorOpacityAnimates, defaultValue: null));
    properties.add(ColorProperty('cursorColor', cursorColor, defaultValue: null));
    properties.add(DiagnosticsProperty<Brightness>('keyboardAppearance', keyboardAppearance, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('scrollPadding', scrollPadding, defaultValue: const EdgeInsets.all(20.0)));
    properties.add(FlagProperty('selectionEnabled', value: selectionEnabled, defaultValue: true, ifFalse: 'selection disabled'));
    properties.add(DiagnosticsProperty<TextSelectionControls>('selectionControls', selectionControls, defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollController>('scrollController', scrollController, defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>('scrollPhysics', scrollPhysics, defaultValue: null));
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior, defaultValue: Clip.hardEdge));
    properties.add(DiagnosticsProperty<bool>('scribbleEnabled', scribbleEnabled, defaultValue: true));
    properties.add(DiagnosticsProperty<bool>('enableIMEPersonalizedLearning', enableIMEPersonalizedLearning, defaultValue: true));
    properties.add(DiagnosticsProperty<SpellCheckConfiguration>('spellCheckConfiguration', spellCheckConfiguration, defaultValue: null));
    properties.add(DiagnosticsProperty<List<String>>('contentCommitMimeTypes', contentInsertionConfiguration?.allowedMimeTypes ?? const <String>[], defaultValue: contentInsertionConfiguration == null ? const <String>[] : kDefaultContentInsertionMimeTypes));
  }
}

class _TextFieldState extends State<TextField> with RestorationMixin implements TextSelectionGestureDetectorBuilderDelegate, AutofillClient {
  RestorableTextEditingController? _controller;
  TextEditingController get _effectiveController => widget.controller ?? _controller!.value;

  FocusNode? _focusNode;
  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_focusNode ??= FocusNode());

  MaxLengthEnforcement get _effectiveMaxLengthEnforcement => widget.maxLengthEnforcement
    ?? LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement(Theme.of(context).platform);

  bool _isHovering = false;

  bool get needsCounter => widget.maxLength != null
    && widget.decoration != null
    && widget.decoration!.counterText == null;

  bool _showSelectionHandles = false;

  late _TextFieldSelectionGestureDetectorBuilder _selectionGestureDetectorBuilder;

  // API for TextSelectionGestureDetectorBuilderDelegate.
  @override
  late bool forcePressEnabled;

  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();

  @override
  bool get selectionEnabled => widget.selectionEnabled;
  // End of API for TextSelectionGestureDetectorBuilderDelegate.

  bool get _isEnabled =>  widget.enabled ?? widget.decoration?.enabled ?? true;

  int get _currentLength => _effectiveController.value.text.characters.length;

  bool get _hasIntrinsicError => widget.maxLength != null && widget.maxLength! > 0 && _effectiveController.value.text.characters.length > widget.maxLength!;

  bool get _hasError => widget.decoration?.errorText != null || widget.decoration?.error != null || _hasIntrinsicError;

  Color get _errorColor => widget.decoration?.errorStyle?.color ?? Theme.of(context).colorScheme.error;

  InputDecoration _getEffectiveDecoration() {
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final ThemeData themeData = Theme.of(context);
    final InputDecoration effectiveDecoration = (widget.decoration ?? const InputDecoration())
      .applyDefaults(themeData.inputDecorationTheme)
      .copyWith(
        enabled: _isEnabled,
        hintMaxLines: widget.decoration?.hintMaxLines ?? widget.maxLines,
      );

    // No need to build anything if counter or counterText were given directly.
    if (effectiveDecoration.counter != null || effectiveDecoration.counterText != null) {
      return effectiveDecoration;
    }

    // If buildCounter was provided, use it to generate a counter widget.
    Widget? counter;
    final int currentLength = _currentLength;
    if (effectiveDecoration.counter == null
        && effectiveDecoration.counterText == null
        && widget.buildCounter != null) {
      final bool isFocused = _effectiveFocusNode.hasFocus;
      final Widget? builtCounter = widget.buildCounter!(
        context,
        currentLength: currentLength,
        maxLength: widget.maxLength,
        isFocused: isFocused,
      );
      // If buildCounter returns null, don't add a counter widget to the field.
      if (builtCounter != null) {
        counter = Semantics(
          container: true,
          liveRegion: isFocused,
          child: builtCounter,
        );
      }
      return effectiveDecoration.copyWith(counter: counter);
    }

    if (widget.maxLength == null) {
      return effectiveDecoration;
    } // No counter widget

    String counterText = '$currentLength';
    String semanticCounterText = '';

    // Handle a real maxLength (positive number)
    if (widget.maxLength! > 0) {
      // Show the maxLength in the counter
      counterText += '/${widget.maxLength}';
      final int remaining = (widget.maxLength! - currentLength).clamp(0, widget.maxLength!); // ignore_clamp_double_lint
      semanticCounterText = localizations.remainingTextFieldCharacterCount(remaining);
    }

    if (_hasIntrinsicError) {
      return effectiveDecoration.copyWith(
        errorText: effectiveDecoration.errorText ?? '',
        counterStyle: effectiveDecoration.errorStyle
          ?? (themeData.useMaterial3 ? _m3CounterErrorStyle(context): _m2CounterErrorStyle(context)),
        counterText: counterText,
        semanticCounterText: semanticCounterText,
      );
    }

    return effectiveDecoration.copyWith(
      counterText: counterText,
      semanticCounterText: semanticCounterText,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectionGestureDetectorBuilder = _TextFieldSelectionGestureDetectorBuilder(state: this);
    if (widget.controller == null) {
      _createLocalController();
    }
    _effectiveFocusNode.canRequestFocus = widget.canRequestFocus && _isEnabled;
    _effectiveFocusNode.addListener(_handleFocusChanged);
  }

  bool get _canRequestFocus {
    final NavigationMode mode = MediaQuery.maybeNavigationModeOf(context) ?? NavigationMode.traditional;
    switch (mode) {
      case NavigationMode.traditional:
        return widget.canRequestFocus && _isEnabled;
      case NavigationMode.directional:
        return true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _effectiveFocusNode.canRequestFocus = _canRequestFocus;
  }

  @override
  void didUpdateWidget(TextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.controller != null) {
      _createLocalController(oldWidget.controller!.value);
    } else if (widget.controller != null && oldWidget.controller == null) {
      unregisterFromRestoration(_controller!);
      _controller!.dispose();
      _controller = null;
    }

    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _focusNode)?.removeListener(_handleFocusChanged);
      (widget.focusNode ?? _focusNode)?.addListener(_handleFocusChanged);
    }

    _effectiveFocusNode.canRequestFocus = _canRequestFocus;

    if (_effectiveFocusNode.hasFocus && widget.readOnly != oldWidget.readOnly && _isEnabled) {
      if (_effectiveController.selection.isCollapsed) {
        _showSelectionHandles = !widget.readOnly;
      }
    }
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    if (_controller != null) {
      _registerController();
    }
  }

  void _registerController() {
    assert(_controller != null);
    registerForRestoration(_controller!, 'controller');
  }

  void _createLocalController([TextEditingValue? value]) {
    assert(_controller == null);
    _controller = value == null
        ? RestorableTextEditingController()
        : RestorableTextEditingController.fromValue(value);
    if (!restorePending) {
      _registerController();
    }
  }

  @override
  String? get restorationId => widget.restorationId;

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChanged);
    _focusNode?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  EditableTextState? get _editableText => editableTextKey.currentState;

  void _requestKeyboard() {
    _editableText?.requestKeyboard();
  }

  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    // When the text field is activated by something that doesn't trigger the
    // selection overlay, we shouldn't show the handles either.
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar) {
      return false;
    }

    if (cause == SelectionChangedCause.keyboard) {
      return false;
    }

    if (widget.readOnly && _effectiveController.selection.isCollapsed) {
      return false;
    }

    if (!_isEnabled) {
      return false;
    }

    if (cause == SelectionChangedCause.longPress || cause == SelectionChangedCause.scribble) {
      return true;
    }

    if (_effectiveController.text.isNotEmpty) {
      return true;
    }

    return false;
  }

  void _handleFocusChanged() {
    setState(() {
      // Rebuild the widget on focus change to show/hide the text selection
      // highlight.
    });
  }

  void _handleSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    final bool willShowSelectionHandles = _shouldShowSelectionHandles(cause);
    if (willShowSelectionHandles != _showSelectionHandles) {
      setState(() {
        _showSelectionHandles = willShowSelectionHandles;
      });
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
      case TargetPlatform.android:
        if (cause == SelectionChangedCause.longPress) {
          _editableText?.bringIntoView(selection.extent);
        }
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.android:
        break;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        if (cause == SelectionChangedCause.drag) {
          _editableText?.hideToolbar();
        }
    }
  }

  void _handleSelectionHandleTapped() {
    if (_effectiveController.selection.isCollapsed) {
      _editableText!.toggleToolbar();
    }
  }

  void _handleHover(bool hovering) {
    if (hovering != _isHovering) {
      setState(() {
        _isHovering = hovering;
      });
    }
  }

  // AutofillClient implementation start.
  @override
  String get autofillId => _editableText!.autofillId;

  @override
  void autofill(TextEditingValue newEditingValue) => _editableText!.autofill(newEditingValue);

  @override
  TextInputConfiguration get textInputConfiguration {
    final List<String>? autofillHints = widget.autofillHints?.toList(growable: false);
    final AutofillConfiguration autofillConfiguration = autofillHints != null
      ? AutofillConfiguration(
          uniqueIdentifier: autofillId,
          autofillHints: autofillHints,
          currentEditingValue: _effectiveController.value,
          hintText: (widget.decoration ?? const InputDecoration()).hintText,
        )
      : AutofillConfiguration.disabled;

    return _editableText!.textInputConfiguration.copyWith(autofillConfiguration: autofillConfiguration);
  }
  // AutofillClient implementation end.

  Set<MaterialState> get _materialState {
    return <MaterialState>{
      if (!_isEnabled) MaterialState.disabled,
      if (_isHovering) MaterialState.hovered,
      if (_effectiveFocusNode.hasFocus) MaterialState.focused,
      if (_hasError) MaterialState.error,
    };
  }

  TextStyle _getInputStyleForState(TextStyle style) {
    final ThemeData theme = Theme.of(context);
    final TextStyle stateStyle = MaterialStateProperty.resolveAs(theme.useMaterial3 ? _m3StateInputStyle(context)! : _m2StateInputStyle(context)!, _materialState);
    final TextStyle providedStyle = MaterialStateProperty.resolveAs(style, _materialState);
    return providedStyle.merge(stateStyle);
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasDirectionality(context));
    assert(
      !(widget.style != null && !widget.style!.inherit &&
        (widget.style!.fontSize == null || widget.style!.textBaseline == null)),
      'inherit false style must supply fontSize and textBaseline',
    );

    final ThemeData theme = Theme.of(context);
    final DefaultSelectionStyle selectionStyle = DefaultSelectionStyle.of(context);
    final TextStyle? providedStyle = MaterialStateProperty.resolveAs(widget.style, _materialState);
    final TextStyle style = _getInputStyleForState(theme.useMaterial3 ? _m3InputStyle(context) : theme.textTheme.titleMedium!).merge(providedStyle);
    final Brightness keyboardAppearance = widget.keyboardAppearance ?? theme.brightness;
    final TextEditingController controller = _effectiveController;
    final FocusNode focusNode = _effectiveFocusNode;
    final List<TextInputFormatter> formatters = <TextInputFormatter>[
      ...?widget.inputFormatters,
      if (widget.maxLength != null)
        LengthLimitingTextInputFormatter(
          widget.maxLength,
          maxLengthEnforcement: _effectiveMaxLengthEnforcement,
        ),
    ];

    // Set configuration as disabled if not otherwise specified. If specified,
    // ensure that configuration uses the correct style for misspelled words for
    // the current platform, unless a custom style is specified.
    final SpellCheckConfiguration spellCheckConfiguration;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        spellCheckConfiguration =
            CupertinoTextField.inferIOSSpellCheckConfiguration(
              widget.spellCheckConfiguration,
            );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        spellCheckConfiguration = TextField.inferAndroidSpellCheckConfiguration(
          widget.spellCheckConfiguration,
        );
    }

    TextSelectionControls? textSelectionControls = widget.selectionControls;
    final bool paintCursorAboveText;
    bool? cursorOpacityAnimates = widget.cursorOpacityAnimates;
    Offset? cursorOffset;
    final Color cursorColor;
    final Color selectionColor;
    Color? autocorrectionTextRectColor;
    Radius? cursorRadius = widget.cursorRadius;
    VoidCallback? handleDidGainAccessibilityFocus;
    VoidCallback? handleDidLoseAccessibilityFocus;

    switch (theme.platform) {
      case TargetPlatform.iOS:
        final CupertinoThemeData cupertinoTheme = CupertinoTheme.of(context);
        forcePressEnabled = true;
        textSelectionControls ??= cupertinoTextSelectionHandleControls;
        paintCursorAboveText = true;
        cursorOpacityAnimates ??= true;
        cursorColor = _hasError ? _errorColor : widget.cursorColor ?? selectionStyle.cursorColor ?? cupertinoTheme.primaryColor;
        selectionColor = selectionStyle.selectionColor ?? cupertinoTheme.primaryColor.withOpacity(0.40);
        cursorRadius ??= const Radius.circular(2.0);
        cursorOffset = Offset(iOSHorizontalOffset / MediaQuery.devicePixelRatioOf(context), 0);
        autocorrectionTextRectColor = selectionColor;

      case TargetPlatform.macOS:
        final CupertinoThemeData cupertinoTheme = CupertinoTheme.of(context);
        forcePressEnabled = false;
        textSelectionControls ??= cupertinoDesktopTextSelectionHandleControls;
        paintCursorAboveText = true;
        cursorOpacityAnimates ??= false;
        cursorColor = _hasError ? _errorColor : widget.cursorColor ?? selectionStyle.cursorColor ?? cupertinoTheme.primaryColor;
        selectionColor = selectionStyle.selectionColor ?? cupertinoTheme.primaryColor.withOpacity(0.40);
        cursorRadius ??= const Radius.circular(2.0);
        cursorOffset = Offset(iOSHorizontalOffset / MediaQuery.devicePixelRatioOf(context), 0);
        handleDidGainAccessibilityFocus = () {
          // Automatically activate the TextField when it receives accessibility focus.
          if (!_effectiveFocusNode.hasFocus && _effectiveFocusNode.canRequestFocus) {
            _effectiveFocusNode.requestFocus();
          }
        };
        handleDidLoseAccessibilityFocus = () {
          _effectiveFocusNode.unfocus();
        };

      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        forcePressEnabled = false;
        textSelectionControls ??= materialTextSelectionHandleControls;
        paintCursorAboveText = false;
        cursorOpacityAnimates ??= false;
        cursorColor = _hasError ? _errorColor : widget.cursorColor ?? selectionStyle.cursorColor ?? theme.colorScheme.primary;
        selectionColor = selectionStyle.selectionColor ?? theme.colorScheme.primary.withOpacity(0.40);

      case TargetPlatform.linux:
        forcePressEnabled = false;
        textSelectionControls ??= desktopTextSelectionHandleControls;
        paintCursorAboveText = false;
        cursorOpacityAnimates ??= false;
        cursorColor = _hasError ? _errorColor : widget.cursorColor ?? selectionStyle.cursorColor ?? theme.colorScheme.primary;
        selectionColor = selectionStyle.selectionColor ?? theme.colorScheme.primary.withOpacity(0.40);
        handleDidGainAccessibilityFocus = () {
          // Automatically activate the TextField when it receives accessibility focus.
          if (!_effectiveFocusNode.hasFocus && _effectiveFocusNode.canRequestFocus) {
            _effectiveFocusNode.requestFocus();
          }
        };
        handleDidLoseAccessibilityFocus = () {
          _effectiveFocusNode.unfocus();
        };

      case TargetPlatform.windows:
        forcePressEnabled = false;
        textSelectionControls ??= desktopTextSelectionHandleControls;
        paintCursorAboveText = false;
        cursorOpacityAnimates ??= false;
        cursorColor = _hasError ? _errorColor : widget.cursorColor ?? selectionStyle.cursorColor ?? theme.colorScheme.primary;
        selectionColor = selectionStyle.selectionColor ?? theme.colorScheme.primary.withOpacity(0.40);
        handleDidGainAccessibilityFocus = () {
          // Automatically activate the TextField when it receives accessibility focus.
          if (!_effectiveFocusNode.hasFocus && _effectiveFocusNode.canRequestFocus) {
            _effectiveFocusNode.requestFocus();
          }
        };
        handleDidLoseAccessibilityFocus = () {
          _effectiveFocusNode.unfocus();
        };
    }

    Widget child = RepaintBoundary(
      child: UnmanagedRestorationScope(
        bucket: bucket,
        child: EditableText(
          key: editableTextKey,
          readOnly: widget.readOnly || !_isEnabled,
          toolbarOptions: widget.toolbarOptions,
          showCursor: widget.showCursor,
          showSelectionHandles: _showSelectionHandles,
          controller: controller,
          focusNode: focusNode,
          undoController: widget.undoController,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          style: style,
          strutStyle: widget.strutStyle,
          textAlign: widget.textAlign,
          textDirection: widget.textDirection,
          autofocus: widget.autofocus,
          obscuringCharacter: widget.obscuringCharacter,
          obscureText: widget.obscureText,
          autocorrect: widget.autocorrect,
          smartDashesType: widget.smartDashesType,
          smartQuotesType: widget.smartQuotesType,
          enableSuggestions: widget.enableSuggestions,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          expands: widget.expands,
          // Only show the selection highlight when the text field is focused.
          selectionColor: focusNode.hasFocus ? selectionColor : null,
          selectionControls: widget.selectionEnabled ? textSelectionControls : null,
          onChanged: widget.onChanged,
          onSelectionChanged: _handleSelectionChanged,
          onEditingComplete: widget.onEditingComplete,
          onSubmitted: widget.onSubmitted,
          onAppPrivateCommand: widget.onAppPrivateCommand,
          onSelectionHandleTapped: _handleSelectionHandleTapped,
          onTapOutside: widget.onTapOutside,
          inputFormatters: formatters,
          rendererIgnoresPointer: true,
          mouseCursor: MouseCursor.defer, // TextField will handle the cursor
          cursorWidth: widget.cursorWidth,
          cursorHeight: widget.cursorHeight,
          cursorRadius: cursorRadius,
          cursorColor: cursorColor,
          selectionHeightStyle: widget.selectionHeightStyle,
          selectionWidthStyle: widget.selectionWidthStyle,
          cursorOpacityAnimates: cursorOpacityAnimates,
          cursorOffset: cursorOffset,
          paintCursorAboveText: paintCursorAboveText,
          backgroundCursorColor: CupertinoColors.inactiveGray,
          scrollPadding: widget.scrollPadding,
          keyboardAppearance: keyboardAppearance,
          enableInteractiveSelection: widget.enableInteractiveSelection,
          dragStartBehavior: widget.dragStartBehavior,
          scrollController: widget.scrollController,
          scrollPhysics: widget.scrollPhysics,
          autofillClient: this,
          autocorrectionTextRectColor: autocorrectionTextRectColor,
          clipBehavior: widget.clipBehavior,
          restorationId: 'editable',
          scribbleEnabled: widget.scribbleEnabled,
          enableIMEPersonalizedLearning: widget.enableIMEPersonalizedLearning,
          contentInsertionConfiguration: widget.contentInsertionConfiguration,
          contextMenuBuilder: widget.contextMenuBuilder,
          spellCheckConfiguration: spellCheckConfiguration,
          magnifierConfiguration: widget.magnifierConfiguration ?? TextMagnifier.adaptiveMagnifierConfiguration,
        ),
      ),
    );

    if (widget.decoration != null) {
      child = AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[ focusNode, controller ]),
        builder: (BuildContext context, Widget? child) {
          return InputDecorator(
            decoration: _getEffectiveDecoration(),
            baseStyle: widget.style,
            textAlign: widget.textAlign,
            textAlignVertical: widget.textAlignVertical,
            isHovering: _isHovering,
            isFocused: focusNode.hasFocus,
            isEmpty: controller.value.text.isEmpty,
            expands: widget.expands,
            child: child,
          );
        },
        child: child,
      );
    }
    final MouseCursor effectiveMouseCursor = MaterialStateProperty.resolveAs<MouseCursor>(
      widget.mouseCursor ?? MaterialStateMouseCursor.textable,
      _materialState,
    );

    final int? semanticsMaxValueLength;
    if (_effectiveMaxLengthEnforcement != MaxLengthEnforcement.none &&
      widget.maxLength != null &&
      widget.maxLength! > 0) {
      semanticsMaxValueLength = widget.maxLength;
    } else {
      semanticsMaxValueLength = null;
    }

    return MouseRegion(
      cursor: effectiveMouseCursor,
      onEnter: (PointerEnterEvent event) => _handleHover(true),
      onExit: (PointerExitEvent event) => _handleHover(false),
      child: TextFieldTapRegion(
        child: IgnorePointer(
          ignoring: !_isEnabled,
          child: AnimatedBuilder(
            animation: controller, // changes the _currentLength
            builder: (BuildContext context, Widget? child) {
              return Semantics(
                maxValueLength: semanticsMaxValueLength,
                currentValueLength: _currentLength,
                onTap: widget.readOnly ? null : () {
                  if (!_effectiveController.selection.isValid) {
                    _effectiveController.selection = TextSelection.collapsed(offset: _effectiveController.text.length);
                  }
                  _requestKeyboard();
                },
                onDidGainAccessibilityFocus: handleDidGainAccessibilityFocus,
                onDidLoseAccessibilityFocus: handleDidLoseAccessibilityFocus,
                child: child,
              );
            },
            child: _selectionGestureDetectorBuilder.buildGestureDetector(
              behavior: HitTestBehavior.translucent,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle? _m2StateInputStyle(BuildContext context) => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
  final ThemeData theme = Theme.of(context);
  if (states.contains(MaterialState.disabled)) {
    return TextStyle(color: theme.disabledColor);
  }
  return TextStyle(color: theme.textTheme.titleMedium?.color);
});

TextStyle _m2CounterErrorStyle(BuildContext context) =>
  Theme.of(context).textTheme.bodySmall!.copyWith(color: Theme.of(context).colorScheme.error);

// BEGIN GENERATED TOKEN PROPERTIES - TextField

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

TextStyle? _m3StateInputStyle(BuildContext context) => MaterialStateTextStyle.resolveWith((Set<MaterialState> states) {
  if (states.contains(MaterialState.disabled)) {
    return TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color?.withOpacity(0.38));
  }
  return TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color);
});

TextStyle _m3InputStyle(BuildContext context) => Theme.of(context).textTheme.bodyLarge!;

TextStyle _m3CounterErrorStyle(BuildContext context) =>
  Theme.of(context).textTheme.bodySmall!.copyWith(color: Theme.of(context).colorScheme.error);

// END GENERATED TOKEN PROPERTIES - TextField