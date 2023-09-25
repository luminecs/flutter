import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import 'adaptive_text_selection_toolbar.dart';
import 'debug.dart';
import 'desktop_text_selection.dart';
import 'magnifier.dart';
import 'text_selection.dart';
import 'theme.dart';

class SelectionArea extends StatefulWidget {
  const SelectionArea({
    super.key,
    this.focusNode,
    this.selectionControls,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
    this.magnifierConfiguration,
    this.onSelectionChanged,
    required this.child,
  });

  final TextMagnifierConfiguration? magnifierConfiguration;

  final FocusNode? focusNode;

  final TextSelectionControls? selectionControls;

  final SelectableRegionContextMenuBuilder? contextMenuBuilder;

  final ValueChanged<SelectedContent?>? onSelectionChanged;

  final Widget child;

  static Widget _defaultContextMenuBuilder(BuildContext context, SelectableRegionState selectableRegionState) {
    return AdaptiveTextSelectionToolbar.selectableRegion(
      selectableRegionState: selectableRegionState,
    );
  }

  @override
  State<StatefulWidget> createState() => _SelectionAreaState();
}

class _SelectionAreaState extends State<SelectionArea> {
  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_internalNode ??= FocusNode());
  FocusNode? _internalNode;

  @override
  void dispose() {
    _internalNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    final TextSelectionControls controls = widget.selectionControls ?? switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.fuchsia => materialTextSelectionHandleControls,
      TargetPlatform.linux || TargetPlatform.windows   => desktopTextSelectionHandleControls,
      TargetPlatform.iOS                               => cupertinoTextSelectionHandleControls,
      TargetPlatform.macOS                             => cupertinoDesktopTextSelectionHandleControls,
    };
    return SelectableRegion(
      selectionControls: controls,
      focusNode: _effectiveFocusNode,
      contextMenuBuilder: widget.contextMenuBuilder,
      magnifierConfiguration: widget.magnifierConfiguration ?? TextMagnifier.adaptiveMagnifierConfiguration,
      onSelectionChanged: widget.onSelectionChanged,
      child: widget.child,
    );
  }
}