
import 'package:flutter/foundation.dart';

import 'basic.dart';
import 'focus_manager.dart';
import 'framework.dart';
import 'inherited_notifier.dart';

class Focus extends StatefulWidget {
  const Focus({
    super.key,
    required this.child,
    this.focusNode,
    this.parentNode,
    this.autofocus = false,
    this.onFocusChange,
    FocusOnKeyEventCallback? onKeyEvent,
    FocusOnKeyCallback? onKey,
    bool? canRequestFocus,
    bool? skipTraversal,
    bool? descendantsAreFocusable,
    bool? descendantsAreTraversable,
    this.includeSemantics = true,
    String? debugLabel,
  })  : _onKeyEvent = onKeyEvent,
        _onKey = onKey,
        _canRequestFocus = canRequestFocus,
        _skipTraversal = skipTraversal,
        _descendantsAreFocusable = descendantsAreFocusable,
        _descendantsAreTraversable = descendantsAreTraversable,
        _debugLabel = debugLabel;

  const factory Focus.withExternalFocusNode({
    Key? key,
    required Widget child,
    required FocusNode focusNode,
    FocusNode? parentNode,
    bool autofocus,
    ValueChanged<bool>? onFocusChange,
    bool includeSemantics,
  }) = _FocusWithExternalFocusNode;

  // Indicates whether the widget's focusNode attributes should have priority
  // when then widget is updated.
  bool get _usingExternalFocus => false;

  final FocusNode? parentNode;

  final Widget child;

  final FocusNode? focusNode;

  final bool autofocus;

  final ValueChanged<bool>? onFocusChange;

  FocusOnKeyEventCallback? get onKeyEvent => _onKeyEvent ?? focusNode?.onKeyEvent;
  final FocusOnKeyEventCallback? _onKeyEvent;

  FocusOnKeyCallback? get onKey => _onKey ?? focusNode?.onKey;
  final FocusOnKeyCallback? _onKey;

  bool get canRequestFocus => _canRequestFocus ?? focusNode?.canRequestFocus ?? true;
  final bool? _canRequestFocus;

  bool get skipTraversal => _skipTraversal ?? focusNode?.skipTraversal ?? false;
  final bool? _skipTraversal;

  bool get descendantsAreFocusable => _descendantsAreFocusable ?? focusNode?.descendantsAreFocusable ?? true;
  final bool? _descendantsAreFocusable;

  bool get descendantsAreTraversable => _descendantsAreTraversable ?? focusNode?.descendantsAreTraversable ?? true;
  final bool? _descendantsAreTraversable;

  final bool includeSemantics;

  String? get debugLabel => _debugLabel ?? focusNode?.debugLabel;
  final String? _debugLabel;

  static FocusNode of(BuildContext context, { bool scopeOk = false, bool createDependency = true }) {
    final FocusNode? node = Focus.maybeOf(context, scopeOk: scopeOk, createDependency: createDependency);
    assert(() {
      if (node == null) {
        throw FlutterError(
          'Focus.of() was called with a context that does not contain a Focus widget.\n'
          'No Focus widget ancestor could be found starting from the context that was passed to '
          'Focus.of(). This can happen because you are using a widget that looks for a Focus '
          'ancestor, and do not have a Focus widget descendant in the nearest FocusScope.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    assert(() {
      if (!scopeOk && node is FocusScopeNode) {
        throw FlutterError(
          'Focus.of() was called with a context that does not contain a Focus between the given '
          'context and the nearest FocusScope widget.\n'
          'No Focus ancestor could be found starting from the context that was passed to '
          'Focus.of() to the point where it found the nearest FocusScope widget. This can happen '
          'because you are using a widget that looks for a Focus ancestor, and do not have a '
          'Focus widget ancestor in the current FocusScope.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return node!;
  }

  static FocusNode? maybeOf(BuildContext context, { bool scopeOk = false, bool createDependency = true }) {
    final _FocusInheritedScope? scope;
    if (createDependency) {
      scope = context.dependOnInheritedWidgetOfExactType<_FocusInheritedScope>();
    } else {
      scope = context.getInheritedWidgetOfExactType<_FocusInheritedScope>();
    }
    final FocusNode? node = scope?.notifier;
    if (node == null) {
      return null;
    }
    if (!scopeOk && node is FocusScopeNode) {
      return null;
    }
    return node;
  }

  static bool isAt(BuildContext context) => Focus.maybeOf(context)?.hasFocus ?? false;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('debugLabel', debugLabel, defaultValue: null));
    properties.add(FlagProperty('autofocus', value: autofocus, ifTrue: 'AUTOFOCUS', defaultValue: false));
    properties.add(FlagProperty('canRequestFocus', value: canRequestFocus, ifFalse: 'NOT FOCUSABLE', defaultValue: false));
    properties.add(FlagProperty('descendantsAreFocusable', value: descendantsAreFocusable, ifFalse: 'DESCENDANTS UNFOCUSABLE', defaultValue: true));
    properties.add(FlagProperty('descendantsAreTraversable', value: descendantsAreTraversable, ifFalse: 'DESCENDANTS UNTRAVERSABLE', defaultValue: true));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode, defaultValue: null));
  }

  @override
  State<Focus> createState() => _FocusState();
}

// Implements the behavior differences when the Focus.withExternalFocusNode
// constructor is used.
class _FocusWithExternalFocusNode extends Focus {
  const _FocusWithExternalFocusNode({
    super.key,
    required super.child,
    required FocusNode super.focusNode,
    super.parentNode,
    super.autofocus,
    super.onFocusChange,
    super.includeSemantics,
  });

  @override
  bool get _usingExternalFocus => true;
  @override
  FocusOnKeyEventCallback? get onKeyEvent => focusNode!.onKeyEvent;
  @override
  FocusOnKeyCallback? get onKey => focusNode!.onKey;
  @override
  bool get canRequestFocus => focusNode!.canRequestFocus;
  @override
  bool get skipTraversal => focusNode!.skipTraversal;
  @override
  bool get descendantsAreFocusable => focusNode!.descendantsAreFocusable;
  @override
  bool? get _descendantsAreTraversable => focusNode!.descendantsAreTraversable;
  @override
  String? get debugLabel => focusNode!.debugLabel;
}

class _FocusState extends State<Focus> {
  FocusNode? _internalNode;
  FocusNode get focusNode => widget.focusNode ?? _internalNode!;
  late bool _hadPrimaryFocus;
  late bool _couldRequestFocus;
  late bool _descendantsWereFocusable;
  late bool _descendantsWereTraversable;
  bool _didAutofocus = false;
  FocusAttachment? _focusAttachment;

  @override
  void initState() {
    super.initState();
    _initNode();
  }

  void _initNode() {
    if (widget.focusNode == null) {
      // Only create a new node if the widget doesn't have one.
      // This calls a function instead of just allocating in place because
      // _createNode is overridden in _FocusScopeState.
      _internalNode ??= _createNode();
    }
    focusNode.descendantsAreFocusable = widget.descendantsAreFocusable;
    focusNode.descendantsAreTraversable = widget.descendantsAreTraversable;
    focusNode.skipTraversal = widget.skipTraversal;
    if (widget._canRequestFocus != null) {
      focusNode.canRequestFocus = widget._canRequestFocus!;
    }
    _couldRequestFocus = focusNode.canRequestFocus;
    _descendantsWereFocusable = focusNode.descendantsAreFocusable;
    _descendantsWereTraversable = focusNode.descendantsAreTraversable;
    _hadPrimaryFocus = focusNode.hasPrimaryFocus;
    _focusAttachment = focusNode.attach(context, onKeyEvent: widget.onKeyEvent, onKey: widget.onKey);

    // Add listener even if the _internalNode existed before, since it should
    // not be listening now if we're re-using a previous one because it should
    // have already removed its listener.
    focusNode.addListener(_handleFocusChanged);
  }

  FocusNode _createNode() {
    return FocusNode(
      debugLabel: widget.debugLabel,
      canRequestFocus: widget.canRequestFocus,
      descendantsAreFocusable: widget.descendantsAreFocusable,
      descendantsAreTraversable: widget.descendantsAreTraversable,
      skipTraversal: widget.skipTraversal,
    );
  }

  @override
  void dispose() {
    // Regardless of the node owner, we need to remove it from the tree and stop
    // listening to it.
    focusNode.removeListener(_handleFocusChanged);
    _focusAttachment!.detach();

    // Don't manage the lifetime of external nodes given to the widget, just the
    // internal node.
    _internalNode?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusAttachment?.reparent();
    _handleAutofocus();
  }

  void _handleAutofocus() {
    if (!_didAutofocus && widget.autofocus) {
      FocusScope.of(context).autofocus(focusNode);
      _didAutofocus = true;
    }
  }

  @override
  void deactivate() {
    super.deactivate();
    // The focus node's location in the tree is no longer valid here. But
    // we can't unfocus or remove the node from the tree because if the widget
    // is moved to a different part of the tree (via global key) it should
    // retain its focus state. That's why we temporarily park it on the root
    // focus node (via reparent) until it either gets moved to a different part
    // of the tree (via didChangeDependencies) or until it is disposed.
    _focusAttachment?.reparent();
    _didAutofocus = false;
  }

  @override
  void didUpdateWidget(Focus oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(() {
      // Only update the debug label in debug builds.
      if (oldWidget.focusNode == widget.focusNode &&
          !widget._usingExternalFocus &&
          oldWidget.debugLabel != widget.debugLabel) {
        focusNode.debugLabel = widget.debugLabel;
      }
      return true;
    }());

    if (oldWidget.focusNode == widget.focusNode) {
      if (!widget._usingExternalFocus) {
        if (widget.onKey != focusNode.onKey) {
          focusNode.onKey = widget.onKey;
        }
        if (widget.onKeyEvent != focusNode.onKeyEvent) {
          focusNode.onKeyEvent = widget.onKeyEvent;
        }
        focusNode.skipTraversal = widget.skipTraversal;
        if (widget._canRequestFocus != null) {
          focusNode.canRequestFocus = widget._canRequestFocus!;
        }
        focusNode.descendantsAreFocusable = widget.descendantsAreFocusable;
        focusNode.descendantsAreTraversable = widget.descendantsAreTraversable;
      }
    } else {
      _focusAttachment!.detach();
      oldWidget.focusNode?.removeListener(_handleFocusChanged);
      _initNode();
    }

    if (oldWidget.autofocus != widget.autofocus) {
      _handleAutofocus();
    }
  }

  void _handleFocusChanged() {
    final bool hasPrimaryFocus = focusNode.hasPrimaryFocus;
    final bool canRequestFocus = focusNode.canRequestFocus;
    final bool descendantsAreFocusable = focusNode.descendantsAreFocusable;
    final bool descendantsAreTraversable = focusNode.descendantsAreTraversable;
    widget.onFocusChange?.call(focusNode.hasFocus);
    // Check the cached states that matter here, and call setState if they have
    // changed.
    if (_hadPrimaryFocus != hasPrimaryFocus) {
      setState(() {
        _hadPrimaryFocus = hasPrimaryFocus;
      });
    }
    if (_couldRequestFocus != canRequestFocus) {
      setState(() {
        _couldRequestFocus = canRequestFocus;
      });
    }
    if (_descendantsWereFocusable != descendantsAreFocusable) {
      setState(() {
        _descendantsWereFocusable = descendantsAreFocusable;
      });
    }
    if (_descendantsWereTraversable != descendantsAreTraversable) {
      setState(() {
        _descendantsWereTraversable = descendantsAreTraversable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _focusAttachment!.reparent(parent: widget.parentNode);
    Widget child = widget.child;
    if (widget.includeSemantics) {
      child = Semantics(
        focusable: _couldRequestFocus,
        focused: _hadPrimaryFocus,
        child: widget.child,
      );
    }
    return _FocusInheritedScope(
      node: focusNode,
      child: child,
    );
  }
}

class FocusScope extends Focus {
  const FocusScope({
    super.key,
    FocusScopeNode? node,
    super.parentNode,
    required super.child,
    super.autofocus,
    super.onFocusChange,
    super.canRequestFocus,
    super.skipTraversal,
    super.onKeyEvent,
    super.onKey,
    super.debugLabel,
  })  : super(
          focusNode: node,
        );

  const factory FocusScope.withExternalFocusNode({
    Key? key,
    required Widget child,
    required FocusScopeNode focusScopeNode,
    FocusNode? parentNode,
    bool autofocus,
    ValueChanged<bool>? onFocusChange,
  })  = _FocusScopeWithExternalFocusNode;

  static FocusScopeNode of(BuildContext context, { bool createDependency = true }) {
    return Focus.maybeOf(context, scopeOk: true, createDependency: createDependency)?.nearestScope
        ?? context.owner!.focusManager.rootScope;
  }

  @override
  State<Focus> createState() => _FocusScopeState();
}

// Implements the behavior differences when the FocusScope.withExternalFocusNode
// constructor is used.
class _FocusScopeWithExternalFocusNode extends FocusScope {
  const _FocusScopeWithExternalFocusNode({
    super.key,
    required super.child,
    required FocusScopeNode focusScopeNode,
    super.parentNode,
    super.autofocus,
    super.onFocusChange,
  }) : super(
    node: focusScopeNode,
  );

  @override
  bool get _usingExternalFocus => true;
  @override
  FocusOnKeyEventCallback? get onKeyEvent => focusNode!.onKeyEvent;
  @override
  FocusOnKeyCallback? get onKey => focusNode!.onKey;
  @override
  bool get canRequestFocus => focusNode!.canRequestFocus;
  @override
  bool get skipTraversal => focusNode!.skipTraversal;
  @override
  bool get descendantsAreFocusable => focusNode!.descendantsAreFocusable;
  @override
  bool get descendantsAreTraversable => focusNode!.descendantsAreTraversable;
  @override
  String? get debugLabel => focusNode!.debugLabel;
}

class _FocusScopeState extends _FocusState {
  @override
  FocusScopeNode _createNode() {
    return FocusScopeNode(
      debugLabel: widget.debugLabel,
      canRequestFocus: widget.canRequestFocus,
      skipTraversal: widget.skipTraversal,
    );
  }

  @override
  Widget build(BuildContext context) {
    _focusAttachment!.reparent(parent: widget.parentNode);
    return Semantics(
      explicitChildNodes: true,
      child: _FocusInheritedScope(
        node: focusNode,
        child: widget.child,
      ),
    );
  }
}

// The InheritedWidget for Focus and FocusScope.
class _FocusInheritedScope extends InheritedNotifier<FocusNode> {
  const _FocusInheritedScope({
    required FocusNode node,
    required super.child,
  })  : super(notifier: node);
}

class ExcludeFocus extends StatelessWidget {
  const ExcludeFocus({
    super.key,
    this.excluding = true,
    required this.child,
  });

  final bool excluding;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      descendantsAreFocusable: !excluding,
      child: child,
    );
  }
}