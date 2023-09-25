
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'adaptive_text_selection_toolbar.dart';
import 'colors.dart';
import 'form_row.dart';
import 'text_field.dart';

class CupertinoTextFormFieldRow extends FormField<String> {
  CupertinoTextFormFieldRow({
    super.key,
    this.prefix,
    this.padding,
    this.controller,
    String? initialValue,
    FocusNode? focusNode,
    BoxDecoration? decoration,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction? textInputAction,
    TextStyle? style,
    StrutStyle? strutStyle,
    TextDirection? textDirection,
    TextAlign textAlign = TextAlign.start,
    TextAlignVertical? textAlignVertical,
    bool autofocus = false,
    bool readOnly = false,
    @Deprecated(
      'Use `contextMenuBuilder` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    ToolbarOptions? toolbarOptions,
    bool? showCursor,
    String obscuringCharacter = '•',
    bool obscureText = false,
    bool autocorrect = true,
    SmartDashesType? smartDashesType,
    SmartQuotesType? smartQuotesType,
    bool enableSuggestions = true,
    int? maxLines = 1,
    int? minLines,
    bool expands = false,
    int? maxLength,
    this.onChanged,
    GestureTapCallback? onTap,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onFieldSubmitted,
    super.onSaved,
    super.validator,
    List<TextInputFormatter>? inputFormatters,
    bool? enabled,
    double cursorWidth = 2.0,
    double? cursorHeight,
    Color? cursorColor,
    Brightness? keyboardAppearance,
    EdgeInsets scrollPadding = const EdgeInsets.all(20.0),
    bool enableInteractiveSelection = true,
    TextSelectionControls? selectionControls,
    ScrollPhysics? scrollPhysics,
    Iterable<String>? autofillHints,
    AutovalidateMode super.autovalidateMode = AutovalidateMode.disabled,
    String? placeholder,
    TextStyle? placeholderStyle = const TextStyle(
      fontWeight: FontWeight.w400,
      color: CupertinoColors.placeholderText,
    ),
    EditableTextContextMenuBuilder? contextMenuBuilder = _defaultContextMenuBuilder,
  })  : assert(initialValue == null || controller == null),
        assert(obscuringCharacter.length == 1),
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
        assert(maxLength == null || maxLength > 0),
        super(
          initialValue: controller?.text ?? initialValue ?? '',
          builder: (FormFieldState<String> field) {
            final _CupertinoTextFormFieldRowState state =
                field as _CupertinoTextFormFieldRowState;

            void onChangedHandler(String value) {
              field.didChange(value);
              onChanged?.call(value);
            }

            return CupertinoFormRow(
              prefix: prefix,
              padding: padding,
              error: (field.errorText == null) ? null : Text(field.errorText!),
              child: CupertinoTextField.borderless(
                controller: state._effectiveController,
                focusNode: focusNode,
                keyboardType: keyboardType,
                decoration: decoration,
                textInputAction: textInputAction,
                style: style,
                strutStyle: strutStyle,
                textAlign: textAlign,
                textAlignVertical: textAlignVertical,
                textCapitalization: textCapitalization,
                textDirection: textDirection,
                autofocus: autofocus,
                toolbarOptions: toolbarOptions,
                readOnly: readOnly,
                showCursor: showCursor,
                obscuringCharacter: obscuringCharacter,
                obscureText: obscureText,
                autocorrect: autocorrect,
                smartDashesType: smartDashesType,
                smartQuotesType: smartQuotesType,
                enableSuggestions: enableSuggestions,
                maxLines: maxLines,
                minLines: minLines,
                expands: expands,
                maxLength: maxLength,
                onChanged: onChangedHandler,
                onTap: onTap,
                onEditingComplete: onEditingComplete,
                onSubmitted: onFieldSubmitted,
                inputFormatters: inputFormatters,
                enabled: enabled ?? true,
                cursorWidth: cursorWidth,
                cursorHeight: cursorHeight,
                cursorColor: cursorColor,
                scrollPadding: scrollPadding,
                scrollPhysics: scrollPhysics,
                keyboardAppearance: keyboardAppearance,
                enableInteractiveSelection: enableInteractiveSelection,
                selectionControls: selectionControls,
                autofillHints: autofillHints,
                placeholder: placeholder,
                placeholderStyle: placeholderStyle,
                contextMenuBuilder: contextMenuBuilder,
              ),
            );
          },
        );

  final Widget? prefix;

  final EdgeInsetsGeometry? padding;

  final TextEditingController? controller;

  final ValueChanged<String>? onChanged;

  static Widget _defaultContextMenuBuilder(BuildContext context, EditableTextState editableTextState) {
    return CupertinoAdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  @override
  FormFieldState<String> createState() => _CupertinoTextFormFieldRowState();
}

class _CupertinoTextFormFieldRowState extends FormFieldState<String> {
  TextEditingController? _controller;

  TextEditingController? get _effectiveController =>
      _cupertinoTextFormFieldRow.controller ?? _controller;

  CupertinoTextFormFieldRow get _cupertinoTextFormFieldRow =>
      super.widget as CupertinoTextFormFieldRow;

  @override
  void initState() {
    super.initState();
    if (_cupertinoTextFormFieldRow.controller == null) {
      _controller = TextEditingController(text: widget.initialValue);
    } else {
      _cupertinoTextFormFieldRow.controller!.addListener(_handleControllerChanged);
    }
  }

  @override
  void didUpdateWidget(CupertinoTextFormFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cupertinoTextFormFieldRow.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      _cupertinoTextFormFieldRow.controller?.addListener(_handleControllerChanged);

      if (oldWidget.controller != null && _cupertinoTextFormFieldRow.controller == null) {
        _controller =
            TextEditingController.fromValue(oldWidget.controller!.value);
      }

      if (_cupertinoTextFormFieldRow.controller != null) {
        setValue(_cupertinoTextFormFieldRow.controller!.text);
        if (oldWidget.controller == null) {
          _controller = null;
        }
      }
    }
  }

  @override
  void dispose() {
    _cupertinoTextFormFieldRow.controller?.removeListener(_handleControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChange(String? value) {
    super.didChange(value);

    if (value != null && _effectiveController!.text != value) {
      _effectiveController!.text = value;
    }
  }

  @override
  void reset() {
    // Set the controller value before calling super.reset() to let
    // _handleControllerChanged suppress the change.
    _effectiveController!.text = widget.initialValue!;
    super.reset();
    _cupertinoTextFormFieldRow.onChanged?.call(_effectiveController!.text);
  }

  void _handleControllerChanged() {
    // Suppress changes that originated from within this class.
    //
    // In the case where a controller has been passed in to this widget, we
    // register this change listener. In these cases, we'll also receive change
    // notifications for changes originating from within this class -- for
    // example, the reset() method. In such cases, the FormField value will
    // already have been set.
    if (_effectiveController!.text != value) {
      didChange(_effectiveController!.text);
    }
  }
}