import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'dropdown_menu_theme.dart';
import 'icon_button.dart';
import 'icons.dart';
import 'input_border.dart';
import 'input_decorator.dart';
import 'material_state.dart';
import 'menu_anchor.dart';
import 'menu_style.dart';
import 'text_field.dart';
import 'theme.dart';
import 'theme_data.dart';

// Navigation shortcuts to move the selected menu items up or down.
Map<ShortcutActivator, Intent> _kMenuTraversalShortcuts =
    <ShortcutActivator, Intent>{
  LogicalKeySet(LogicalKeyboardKey.arrowUp): const _ArrowUpIntent(),
  LogicalKeySet(LogicalKeyboardKey.arrowDown): const _ArrowDownIntent(),
};

const double _kMinimumWidth = 112.0;

const double _kDefaultHorizontalPadding = 12.0;

class DropdownMenuEntry<T> {
  const DropdownMenuEntry({
    required this.value,
    required this.label,
    this.labelWidget,
    this.leadingIcon,
    this.trailingIcon,
    this.enabled = true,
    this.style,
  });

  final T value;

  final String label;

  final Widget? labelWidget;

  final Widget? leadingIcon;

  final Widget? trailingIcon;

  final bool enabled;

  final ButtonStyle? style;
}

class DropdownMenu<T> extends StatefulWidget {
  const DropdownMenu({
    super.key,
    this.enabled = true,
    this.width,
    this.menuHeight,
    this.leadingIcon,
    this.trailingIcon,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.selectedTrailingIcon,
    this.enableFilter = false,
    this.enableSearch = true,
    this.textStyle,
    this.inputDecorationTheme,
    this.menuStyle,
    this.controller,
    this.initialSelection,
    this.onSelected,
    this.requestFocusOnTap,
    this.expandedInsets,
    required this.dropdownMenuEntries,
  });

  final bool enabled;

  final double? width;

  final double? menuHeight;

  final Widget? leadingIcon;

  final Widget? trailingIcon;

  final Widget? label;

  final String? hintText;

  final String? helperText;

  final String? errorText;

  final Widget? selectedTrailingIcon;

  final bool enableFilter;

  final bool enableSearch;

  final TextStyle? textStyle;

  final InputDecorationTheme? inputDecorationTheme;

  final MenuStyle? menuStyle;

  final TextEditingController? controller;

  final T? initialSelection;

  final ValueChanged<T?>? onSelected;

  final bool? requestFocusOnTap;

  final List<DropdownMenuEntry<T>> dropdownMenuEntries;

  final EdgeInsets? expandedInsets;

  @override
  State<DropdownMenu<T>> createState() => _DropdownMenuState<T>();
}

class _DropdownMenuState<T> extends State<DropdownMenu<T>> {
  final GlobalKey _anchorKey = GlobalKey();
  final GlobalKey _leadingKey = GlobalKey();
  late List<GlobalKey> buttonItemKeys;
  final MenuController _controller = MenuController();
  late final TextEditingController _textEditingController;
  late bool _enableFilter;
  late List<DropdownMenuEntry<T>> filteredEntries;
  List<Widget>? _initialMenu;
  int? currentHighlight;
  double? leadingPadding;
  bool _menuHasEnabledItem = false;

  @override
  void initState() {
    super.initState();
    _textEditingController = widget.controller ?? TextEditingController();
    _enableFilter = widget.enableFilter;
    filteredEntries = widget.dropdownMenuEntries;
    buttonItemKeys = List<GlobalKey>.generate(
        filteredEntries.length, (int index) => GlobalKey());
    _menuHasEnabledItem =
        filteredEntries.any((DropdownMenuEntry<T> entry) => entry.enabled);

    final int index = filteredEntries.indexWhere(
        (DropdownMenuEntry<T> entry) => entry.value == widget.initialSelection);
    if (index != -1) {
      _textEditingController.text = filteredEntries[index].label;
      _textEditingController.selection =
          TextSelection.collapsed(offset: _textEditingController.text.length);
    }
    refreshLeadingPadding();
  }

  @override
  void didUpdateWidget(DropdownMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableSearch != widget.enableSearch) {
      if (!widget.enableSearch) {
        currentHighlight = null;
      }
    }
    if (oldWidget.dropdownMenuEntries != widget.dropdownMenuEntries) {
      currentHighlight = null;
      filteredEntries = widget.dropdownMenuEntries;
      buttonItemKeys = List<GlobalKey>.generate(
          filteredEntries.length, (int index) => GlobalKey());
      _menuHasEnabledItem =
          filteredEntries.any((DropdownMenuEntry<T> entry) => entry.enabled);
    }
    if (oldWidget.leadingIcon != widget.leadingIcon) {
      refreshLeadingPadding();
    }
    if (oldWidget.initialSelection != widget.initialSelection) {
      final int index = filteredEntries.indexWhere(
          (DropdownMenuEntry<T> entry) =>
              entry.value == widget.initialSelection);
      if (index != -1) {
        _textEditingController.text = filteredEntries[index].label;
        _textEditingController.selection =
            TextSelection.collapsed(offset: _textEditingController.text.length);
      }
    }
  }

  bool canRequestFocus() {
    if (widget.requestFocusOnTap != null) {
      return widget.requestFocusOnTap!;
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return false;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
    }
  }

  void refreshLeadingPadding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        leadingPadding = getWidth(_leadingKey);
      });
    });
  }

  void scrollToHighlight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? highlightContext =
          buttonItemKeys[currentHighlight!].currentContext;
      if (highlightContext != null) {
        Scrollable.ensureVisible(highlightContext);
      }
    });
  }

  double? getWidth(GlobalKey key) {
    final BuildContext? context = key.currentContext;
    if (context != null) {
      final RenderBox box = context.findRenderObject()! as RenderBox;
      return box.hasSize ? box.size.width : null;
    }
    return null;
  }

  List<DropdownMenuEntry<T>> filter(List<DropdownMenuEntry<T>> entries,
      TextEditingController textEditingController) {
    final String filterText = textEditingController.text.toLowerCase();
    return entries
        .where((DropdownMenuEntry<T> entry) =>
            entry.label.toLowerCase().contains(filterText))
        .toList();
  }

  int? search(List<DropdownMenuEntry<T>> entries,
      TextEditingController textEditingController) {
    final String searchText = textEditingController.value.text.toLowerCase();
    if (searchText.isEmpty) {
      return null;
    }
    final int index = entries.indexWhere((DropdownMenuEntry<T> entry) =>
        entry.label.toLowerCase().contains(searchText));

    return index != -1 ? index : null;
  }

  List<Widget> _buildButtons(List<DropdownMenuEntry<T>> filteredEntries,
      TextEditingController textEditingController, TextDirection textDirection,
      {int? focusedIndex, bool enableScrollToHighlight = true}) {
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < filteredEntries.length; i++) {
      final DropdownMenuEntry<T> entry = filteredEntries[i];

      // By default, when the text field has a leading icon but a menu entry doesn't
      // have one, the label of the entry should have extra padding to be aligned
      // with the text in the text input field. When both the text field and the
      // menu entry have leading icons, the menu entry should remove the extra
      // paddings so its leading icon will be aligned with the leading icon of
      // the text field.
      final double padding = entry.leadingIcon == null
          ? (leadingPadding ?? _kDefaultHorizontalPadding)
          : _kDefaultHorizontalPadding;
      final ButtonStyle defaultStyle;
      switch (textDirection) {
        case TextDirection.rtl:
          defaultStyle = MenuItemButton.styleFrom(
            padding: EdgeInsets.only(
                left: _kDefaultHorizontalPadding, right: padding),
          );
        case TextDirection.ltr:
          defaultStyle = MenuItemButton.styleFrom(
            padding: EdgeInsets.only(
                left: padding, right: _kDefaultHorizontalPadding),
          );
      }

      ButtonStyle effectiveStyle = entry.style ?? defaultStyle;
      final Color focusedBackgroundColor = effectiveStyle.foregroundColor
              ?.resolve(<MaterialState>{MaterialState.focused}) ??
          Theme.of(context).colorScheme.onSurface;

      Widget label = entry.labelWidget ?? Text(entry.label);
      if (widget.width != null) {
        final double horizontalPadding = padding + _kDefaultHorizontalPadding;
        label = ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: widget.width! - horizontalPadding),
          child: label,
        );
      }

      // Simulate the focused state because the text field should always be focused
      // during traversal. If the menu item has a custom foreground color, the "focused"
      // color will also change to foregroundColor.withOpacity(0.12).
      effectiveStyle = entry.enabled && i == focusedIndex
          ? effectiveStyle.copyWith(
              backgroundColor: MaterialStatePropertyAll<Color>(
                  focusedBackgroundColor.withOpacity(0.12)))
          : effectiveStyle;

      final Widget menuItemButton = MenuItemButton(
        key: enableScrollToHighlight ? buttonItemKeys[i] : null,
        style: effectiveStyle,
        leadingIcon: entry.leadingIcon,
        trailingIcon: entry.trailingIcon,
        onPressed: entry.enabled
            ? () {
                textEditingController.text = entry.label;
                textEditingController.selection = TextSelection.collapsed(
                    offset: textEditingController.text.length);
                currentHighlight = widget.enableSearch ? i : null;
                widget.onSelected?.call(entry.value);
              }
            : null,
        requestFocusOnHover: false,
        child: label,
      );
      result.add(menuItemButton);
    }

    return result;
  }

  void handleUpKeyInvoke(_) => setState(() {
        if (!_menuHasEnabledItem || !_controller.isOpen) {
          return;
        }
        _enableFilter = false;
        currentHighlight ??= 0;
        currentHighlight = (currentHighlight! - 1) % filteredEntries.length;
        while (!filteredEntries[currentHighlight!].enabled) {
          currentHighlight = (currentHighlight! - 1) % filteredEntries.length;
        }
        final String currentLabel = filteredEntries[currentHighlight!].label;
        _textEditingController.text = currentLabel;
        _textEditingController.selection =
            TextSelection.collapsed(offset: _textEditingController.text.length);
      });

  void handleDownKeyInvoke(_) => setState(() {
        if (!_menuHasEnabledItem || !_controller.isOpen) {
          return;
        }
        _enableFilter = false;
        currentHighlight ??= -1;
        currentHighlight = (currentHighlight! + 1) % filteredEntries.length;
        while (!filteredEntries[currentHighlight!].enabled) {
          currentHighlight = (currentHighlight! + 1) % filteredEntries.length;
        }
        final String currentLabel = filteredEntries[currentHighlight!].label;
        _textEditingController.text = currentLabel;
        _textEditingController.selection =
            TextSelection.collapsed(offset: _textEditingController.text.length);
      });

  void handlePressed(MenuController controller) {
    if (controller.isOpen) {
      currentHighlight = null;
      controller.close();
    } else {
      // close to open
      if (_textEditingController.text.isNotEmpty) {
        _enableFilter = false;
      }
      controller.open();
    }
    setState(() {});
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _textEditingController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);
    _initialMenu ??= _buildButtons(
        widget.dropdownMenuEntries, _textEditingController, textDirection,
        enableScrollToHighlight: false);
    final DropdownMenuThemeData theme = DropdownMenuTheme.of(context);
    final DropdownMenuThemeData defaults = _DropdownMenuDefaultsM3(context);

    if (_enableFilter) {
      filteredEntries =
          filter(widget.dropdownMenuEntries, _textEditingController);
    }

    if (widget.enableSearch) {
      currentHighlight = search(filteredEntries, _textEditingController);
      if (currentHighlight != null) {
        scrollToHighlight();
      }
    }

    final List<Widget> menu = _buildButtons(
        filteredEntries, _textEditingController, textDirection,
        focusedIndex: currentHighlight);

    final TextStyle? effectiveTextStyle =
        widget.textStyle ?? theme.textStyle ?? defaults.textStyle;

    MenuStyle? effectiveMenuStyle =
        widget.menuStyle ?? theme.menuStyle ?? defaults.menuStyle!;

    final double? anchorWidth = getWidth(_anchorKey);
    if (widget.width != null) {
      effectiveMenuStyle = effectiveMenuStyle.copyWith(
          minimumSize:
              MaterialStatePropertyAll<Size?>(Size(widget.width!, 0.0)));
    } else if (anchorWidth != null) {
      effectiveMenuStyle = effectiveMenuStyle.copyWith(
          minimumSize: MaterialStatePropertyAll<Size?>(Size(anchorWidth, 0.0)));
    }

    if (widget.menuHeight != null) {
      effectiveMenuStyle = effectiveMenuStyle.copyWith(
          maximumSize: MaterialStatePropertyAll<Size>(
              Size(double.infinity, widget.menuHeight!)));
    }
    final InputDecorationTheme effectiveInputDecorationTheme =
        widget.inputDecorationTheme ??
            theme.inputDecorationTheme ??
            defaults.inputDecorationTheme!;

    final MouseCursor effectiveMouseCursor =
        canRequestFocus() ? SystemMouseCursors.text : SystemMouseCursors.click;

    Widget menuAnchor = MenuAnchor(
      style: effectiveMenuStyle,
      controller: _controller,
      menuChildren: menu,
      crossAxisUnconstrained: false,
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
        assert(_initialMenu != null);
        final Widget trailingButton = Padding(
          padding: const EdgeInsets.all(4.0),
          child: IconButton(
            isSelected: controller.isOpen,
            icon: widget.trailingIcon ?? const Icon(Icons.arrow_drop_down),
            selectedIcon:
                widget.selectedTrailingIcon ?? const Icon(Icons.arrow_drop_up),
            onPressed: () {
              handlePressed(controller);
            },
          ),
        );

        final Widget leadingButton = Padding(
            padding: const EdgeInsets.all(8.0),
            child: widget.leadingIcon ?? const SizedBox());

        final Widget textField = TextField(
            key: _anchorKey,
            mouseCursor: effectiveMouseCursor,
            canRequestFocus: canRequestFocus(),
            enableInteractiveSelection: canRequestFocus(),
            textAlignVertical: TextAlignVertical.center,
            style: effectiveTextStyle,
            controller: _textEditingController,
            onEditingComplete: () {
              if (currentHighlight != null) {
                final DropdownMenuEntry<T> entry =
                    filteredEntries[currentHighlight!];
                if (entry.enabled) {
                  _textEditingController.text = entry.label;
                  _textEditingController.selection = TextSelection.collapsed(
                      offset: _textEditingController.text.length);
                  widget.onSelected?.call(entry.value);
                }
              } else {
                widget.onSelected?.call(null);
              }
              if (!widget.enableSearch) {
                currentHighlight = null;
              }
              controller.close();
            },
            onTap: () {
              handlePressed(controller);
            },
            onChanged: (String text) {
              controller.open();
              setState(() {
                filteredEntries = widget.dropdownMenuEntries;
                _enableFilter = widget.enableFilter;
              });
            },
            decoration: InputDecoration(
              enabled: widget.enabled,
              label: widget.label,
              hintText: widget.hintText,
              helperText: widget.helperText,
              errorText: widget.errorText,
              prefixIcon: widget.leadingIcon != null
                  ? Container(key: _leadingKey, child: widget.leadingIcon)
                  : null,
              suffixIcon: trailingButton,
            ).applyDefaults(effectiveInputDecorationTheme));

        if (widget.expandedInsets != null) {
          // If [expandedInsets] is not null, the width of the text field should depend
          // on its parent width. So we don't need to use `_DropdownMenuBody` to
          // calculate the children's width.
          return textField;
        }

        return _DropdownMenuBody(
          width: widget.width,
          children: <Widget>[
            textField,
            for (final Widget item in _initialMenu!) item,
            trailingButton,
            leadingButton,
          ],
        );
      },
    );

    if (widget.expandedInsets != null) {
      menuAnchor = Container(
        alignment: AlignmentDirectional.topStart,
        padding: widget.expandedInsets?.copyWith(top: 0.0, bottom: 0.0),
        child: menuAnchor,
      );
    }

    return Shortcuts(
      shortcuts: _kMenuTraversalShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ArrowUpIntent: CallbackAction<_ArrowUpIntent>(
            onInvoke: handleUpKeyInvoke,
          ),
          _ArrowDownIntent: CallbackAction<_ArrowDownIntent>(
            onInvoke: handleDownKeyInvoke,
          ),
        },
        child: menuAnchor,
      ),
    );
  }
}

class _ArrowUpIntent extends Intent {
  const _ArrowUpIntent();
}

class _ArrowDownIntent extends Intent {
  const _ArrowDownIntent();
}

class _DropdownMenuBody extends MultiChildRenderObjectWidget {
  const _DropdownMenuBody({
    super.children,
    this.width,
  });

  final double? width;

  @override
  _RenderDropdownMenuBody createRenderObject(BuildContext context) {
    return _RenderDropdownMenuBody(
      width: width,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderDropdownMenuBody renderObject) {
    renderObject.width = width;
  }
}

class _DropdownMenuBodyParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDropdownMenuBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DropdownMenuBodyParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox,
            _DropdownMenuBodyParentData> {
  _RenderDropdownMenuBody({
    double? width,
  }) : _width = width;

  double? get width => _width;
  double? _width;
  set width(double? value) {
    if (_width == value) {
      return;
    }
    _width = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DropdownMenuBodyParentData) {
      child.parentData = _DropdownMenuBodyParentData();
    }
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    double maxWidth = 0.0;
    double? maxHeight;
    RenderBox? child = firstChild;

    final BoxConstraints innerConstraints = BoxConstraints(
      maxWidth: width ?? computeMaxIntrinsicWidth(constraints.maxWidth),
      maxHeight: computeMaxIntrinsicHeight(constraints.maxHeight),
    );
    while (child != null) {
      if (child == firstChild) {
        child.layout(innerConstraints, parentUsesSize: true);
        maxHeight ??= child.size.height;
        final _DropdownMenuBodyParentData childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        assert(child.parentData == childParentData);
        child = childParentData.nextSibling;
        continue;
      }
      child.layout(innerConstraints, parentUsesSize: true);
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      childParentData.offset = Offset.zero;
      maxWidth = math.max(maxWidth, child.size.width);
      maxHeight ??= child.size.height;
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }

    assert(maxHeight != null);
    maxWidth = math.max(_kMinimumWidth, maxWidth);
    size = constraints.constrain(Size(width ?? maxWidth, maxHeight!));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = firstChild;
    if (child != null) {
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      context.paintChild(child, offset + childParentData.offset);
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final BoxConstraints constraints = this.constraints;
    double maxWidth = 0.0;
    double? maxHeight;
    RenderBox? child = firstChild;
    final BoxConstraints innerConstraints = BoxConstraints(
      maxWidth: width ?? computeMaxIntrinsicWidth(constraints.maxWidth),
      maxHeight: computeMaxIntrinsicHeight(constraints.maxHeight),
    );

    while (child != null) {
      if (child == firstChild) {
        final Size childSize = child.getDryLayout(innerConstraints);
        maxHeight ??= childSize.height;
        final _DropdownMenuBodyParentData childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        assert(child.parentData == childParentData);
        child = childParentData.nextSibling;
        continue;
      }
      final Size childSize = child.getDryLayout(innerConstraints);
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      childParentData.offset = Offset.zero;
      maxWidth = math.max(maxWidth, childSize.width);
      maxHeight ??= childSize.height;
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }

    assert(maxHeight != null);
    maxWidth = math.max(_kMinimumWidth, maxWidth);
    return constraints.constrain(Size(width ?? maxWidth, maxHeight!));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    double width = 0;
    while (child != null) {
      if (child == firstChild) {
        final _DropdownMenuBodyParentData childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        child = childParentData.nextSibling;
        continue;
      }
      final double maxIntrinsicWidth = child.getMinIntrinsicWidth(height);
      if (child == lastChild) {
        width += maxIntrinsicWidth;
      }
      if (child == childBefore(lastChild!)) {
        width += maxIntrinsicWidth;
      }
      width = math.max(width, maxIntrinsicWidth);
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      child = childParentData.nextSibling;
    }

    return math.max(width, _kMinimumWidth);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    double width = 0;
    while (child != null) {
      if (child == firstChild) {
        final _DropdownMenuBodyParentData childParentData =
            child.parentData! as _DropdownMenuBodyParentData;
        child = childParentData.nextSibling;
        continue;
      }
      final double maxIntrinsicWidth = child.getMaxIntrinsicWidth(height);
      // Add the width of leading Icon.
      if (child == lastChild) {
        width += maxIntrinsicWidth;
      }
      // Add the width of trailing Icon.
      if (child == childBefore(lastChild!)) {
        width += maxIntrinsicWidth;
      }
      width = math.max(width, maxIntrinsicWidth);
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      child = childParentData.nextSibling;
    }

    return math.max(width, _kMinimumWidth);
  }

  @override
  double computeMinIntrinsicHeight(double height) {
    final RenderBox? child = firstChild;
    double width = 0;
    if (child != null) {
      width = math.max(width, child.getMinIntrinsicHeight(height));
    }
    return width;
  }

  @override
  double computeMaxIntrinsicHeight(double height) {
    final RenderBox? child = firstChild;
    double width = 0;
    if (child != null) {
      width = math.max(width, child.getMaxIntrinsicHeight(height));
    }
    return width;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? child = firstChild;
    if (child != null) {
      final _DropdownMenuBodyParentData childParentData =
          child.parentData! as _DropdownMenuBodyParentData;
      final bool isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - childParentData.offset);
          return child.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
    }
    return false;
  }
}

// Hand coded defaults. These will be updated once we have tokens/spec.
class _DropdownMenuDefaultsM3 extends DropdownMenuThemeData {
  _DropdownMenuDefaultsM3(this.context);

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);

  @override
  TextStyle? get textStyle => _theme.textTheme.bodyLarge;

  @override
  MenuStyle get menuStyle {
    return const MenuStyle(
      minimumSize: MaterialStatePropertyAll<Size>(Size(_kMinimumWidth, 0.0)),
      maximumSize: MaterialStatePropertyAll<Size>(Size.infinite),
      visualDensity: VisualDensity.standard,
    );
  }

  @override
  InputDecorationTheme get inputDecorationTheme {
    return const InputDecorationTheme(border: OutlineInputBorder());
  }
}
