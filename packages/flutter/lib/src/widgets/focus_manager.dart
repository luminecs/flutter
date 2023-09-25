import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'binding.dart';
import 'focus_scope.dart';
import 'focus_traversal.dart';
import 'framework.dart';

bool debugFocusChanges = false;

// When using _focusDebug, always call it like so:
//
// assert(_focusDebug(() => 'Blah $foo'));
//
// It needs to be inside the assert in order to be removed in release mode, and
// it needs to use a closure to generate the string in order to avoid string
// interpolation when debugFocusChanges is false.
//
// It will throw a StateError if you try to call it when the app is in release
// mode.
bool _focusDebug(
  String Function() messageFunc, [
  Iterable<Object> Function()? detailsFunc,
]) {
  if (kReleaseMode) {
    throw StateError(
      '_focusDebug was called in Release mode. It should always be wrapped in '
      'an assert. Always call _focusDebug like so:\n'
      r"  assert(_focusDebug(() => 'Blah $foo'));"
    );
  }
  if (!debugFocusChanges) {
    return true;
  }
  debugPrint('FOCUS: ${messageFunc()}');
  final Iterable<Object> details = detailsFunc?.call() ?? const <Object>[];
  if (details.isNotEmpty) {
    for (final Object detail in details) {
      debugPrint('    $detail');
    }
  }
  // Return true so that it can be used inside of an assert.
  return true;
}

enum KeyEventResult {
  handled,
  ignored,
  skipRemainingHandlers,
}

KeyEventResult combineKeyEventResults(Iterable<KeyEventResult> results) {
  bool hasSkipRemainingHandlers = false;
  for (final KeyEventResult result in results) {
    switch (result) {
      case KeyEventResult.handled:
        return KeyEventResult.handled;
      case KeyEventResult.skipRemainingHandlers:
        hasSkipRemainingHandlers = true;
      case KeyEventResult.ignored:
        break;
    }
  }
  return hasSkipRemainingHandlers ?
      KeyEventResult.skipRemainingHandlers :
      KeyEventResult.ignored;
}

typedef FocusOnKeyCallback = KeyEventResult Function(FocusNode node, RawKeyEvent event);

typedef FocusOnKeyEventCallback = KeyEventResult Function(FocusNode node, KeyEvent event);

// Represents a pending autofocus request.
@immutable
class _Autofocus {
  const _Autofocus({ required this.scope, required this.autofocusNode });

  final FocusScopeNode scope;
  final FocusNode autofocusNode;

  // Applies the autofocus request, if the node is still attached to the
  // original scope and the scope has no focused child.
  //
  // The widget tree is responsible for calling reparent/detach on attached
  // nodes to keep their parent/manager information up-to-date, so here we can
  // safely check if the scope/node involved in each autofocus request is
  // still attached, and discard the ones which are no longer attached to the
  // original manager.
  void applyIfValid(FocusManager manager) {
    final bool shouldApply  = (scope.parent != null || identical(scope, manager.rootScope))
                           && identical(scope._manager, manager)
                           && scope.focusedChild == null
                           && autofocusNode.ancestors.contains(scope);
    if (shouldApply) {
      assert(_focusDebug(() => 'Applying autofocus: $autofocusNode'));
      autofocusNode._doRequestFocus(findFirstFocus: true);
    } else {
      assert(_focusDebug(() => 'Autofocus request discarded for node: $autofocusNode.'));
    }
  }
}

class FocusAttachment {
  FocusAttachment._(this._node);

  // The focus node that this attachment manages an attachment for. The node may
  // not yet have a parent, or may have been detached from this attachment, so
  // don't count on this node being in a usable state.
  final FocusNode _node;

  bool get isAttached => _node._attachment == this;

  void detach() {
    assert(_focusDebug(() => 'Detaching node:', () => <Object>[_node, 'With enclosing scope ${_node.enclosingScope}']));
    if (isAttached) {
      if (_node.hasPrimaryFocus || (_node._manager != null && _node._manager!._markedForFocus == _node)) {
        _node.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      }
      // This node is no longer in the tree, so shouldn't send notifications anymore.
      _node._manager?._markDetached(_node);
      _node._parent?._removeChild(_node);
      _node._attachment = null;
      assert(!_node.hasPrimaryFocus);
      assert(_node._manager?._markedForFocus != _node);
    }
    assert(!isAttached);
  }

  void reparent({FocusNode? parent}) {
    if (isAttached) {
      assert(_node.context != null);
      parent ??= Focus.maybeOf(_node.context!, scopeOk: true);
      parent ??= _node.context!.owner!.focusManager.rootScope;
      parent._reparent(_node);
    }
  }
}

enum UnfocusDisposition {
  scope,

  previouslyFocusedChild,
}

class FocusNode with DiagnosticableTreeMixin, ChangeNotifier {
  FocusNode({
    String? debugLabel,
    this.onKey,
    this.onKeyEvent,
    bool skipTraversal = false,
    bool canRequestFocus = true,
    bool descendantsAreFocusable = true,
    bool descendantsAreTraversable = true,
  })  : _skipTraversal = skipTraversal,
        _canRequestFocus = canRequestFocus,
        _descendantsAreFocusable = descendantsAreFocusable,
        _descendantsAreTraversable = descendantsAreTraversable {
    // Set it via the setter so that it does nothing on release builds.
    this.debugLabel = debugLabel;

    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  bool get skipTraversal {
    if (_skipTraversal) {
      return true;
    }
    for (final FocusNode ancestor in ancestors) {
      if (!ancestor.descendantsAreTraversable) {
        return true;
      }
    }
    return false;
  }
  bool _skipTraversal;
  set skipTraversal(bool value) {
    if (value != _skipTraversal) {
      _skipTraversal = value;
      _manager?._markPropertiesChanged(this);
    }
  }

  bool get canRequestFocus {
    if (!_canRequestFocus) {
      return false;
    }
    final FocusScopeNode? scope = enclosingScope;
    if (scope != null && !scope.canRequestFocus) {
      return false;
    }
    for (final FocusNode ancestor in ancestors) {
      if (!ancestor.descendantsAreFocusable) {
        return false;
      }
    }
    return true;
  }

  bool _canRequestFocus;
  @mustCallSuper
  set canRequestFocus(bool value) {
    if (value != _canRequestFocus) {
      // Have to set this first before unfocusing, since it checks this to cull
      // unfocusable, previously-focused children.
      _canRequestFocus = value;
      if (hasFocus && !value) {
        unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      }
      _manager?._markPropertiesChanged(this);
    }
  }

  bool get descendantsAreFocusable => _descendantsAreFocusable;
  bool _descendantsAreFocusable;
  @mustCallSuper
  set descendantsAreFocusable(bool value) {
    if (value == _descendantsAreFocusable) {
      return;
    }
    // Set _descendantsAreFocusable before unfocusing, so the scope won't try
    // and focus any of the children here again if it is false.
    _descendantsAreFocusable = value;
    if (!value && hasFocus) {
      unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
    _manager?._markPropertiesChanged(this);
  }

  bool get descendantsAreTraversable => _descendantsAreTraversable;
  bool _descendantsAreTraversable;
  @mustCallSuper
  set descendantsAreTraversable(bool value) {
    if (value != _descendantsAreTraversable) {
      _descendantsAreTraversable = value;
      _manager?._markPropertiesChanged(this);
    }
  }

  BuildContext? get context => _context;
  BuildContext? _context;

  FocusOnKeyCallback? onKey;

  FocusOnKeyEventCallback? onKeyEvent;

  FocusManager? _manager;
  List<FocusNode>? _ancestors;
  List<FocusNode>? _descendants;
  bool _hasKeyboardToken = false;

  FocusNode? get parent => _parent;
  FocusNode? _parent;

  Iterable<FocusNode> get children => _children;
  final List<FocusNode> _children = <FocusNode>[];

  Iterable<FocusNode> get traversalChildren {
    if (!descendantsAreFocusable) {
      return const Iterable<FocusNode>.empty();
    }
    return children.where(
      (FocusNode node) => !node.skipTraversal && node.canRequestFocus,
    );
  }

  String? get debugLabel => _debugLabel;
  String? _debugLabel;
  set debugLabel(String? value) {
    assert(() {
      // Only set the value in debug builds.
      _debugLabel = value;
      return true;
    }());
  }

  FocusAttachment? _attachment;

  Iterable<FocusNode> get descendants {
    if (_descendants == null) {
      final List<FocusNode> result = <FocusNode>[];
      for (final FocusNode child in _children) {
        result.addAll(child.descendants);
        result.add(child);
      }
      _descendants = result;
    }
    return _descendants!;
  }

  Iterable<FocusNode> get traversalDescendants {
    if (!descendantsAreFocusable) {
      return const Iterable<FocusNode>.empty();
    }
    return descendants.where((FocusNode node) => !node.skipTraversal && node.canRequestFocus);
  }

  Iterable<FocusNode> get ancestors {
    if (_ancestors == null) {
      final List<FocusNode> result = <FocusNode>[];
      FocusNode? parent = _parent;
      while (parent != null) {
        result.add(parent);
        parent = parent._parent;
      }
      _ancestors = result;
    }
    return _ancestors!;
  }

  bool get hasFocus => hasPrimaryFocus || (_manager?.primaryFocus?.ancestors.contains(this) ?? false);

  bool get hasPrimaryFocus => _manager?.primaryFocus == this;

  FocusHighlightMode get highlightMode => FocusManager.instance.highlightMode;

  FocusScopeNode? get nearestScope => enclosingScope;

  FocusScopeNode? get enclosingScope {
    for (final FocusNode node in ancestors) {
      if (node is FocusScopeNode) {
        return node;
      }
    }
    return null;
  }

  Size get size => rect.size;

  Offset get offset {
    assert(
      context != null,
      "Tried to get the offset of a focus node that didn't have its context set yet.\n"
      'The context needs to be set before trying to evaluate traversal policies. '
      'Setting the context is typically done with the attach method.',
    );
    final RenderObject object = context!.findRenderObject()!;
    return MatrixUtils.transformPoint(object.getTransformTo(null), object.semanticBounds.topLeft);
  }

  Rect get rect {
    assert(
      context != null,
      "Tried to get the bounds of a focus node that didn't have its context set yet.\n"
      'The context needs to be set before trying to evaluate traversal policies. '
      'Setting the context is typically done with the attach method.',
    );
    final RenderObject object = context!.findRenderObject()!;
    final Offset topLeft = MatrixUtils.transformPoint(object.getTransformTo(null), object.semanticBounds.topLeft);
    final Offset bottomRight = MatrixUtils.transformPoint(object.getTransformTo(null), object.semanticBounds.bottomRight);
    return Rect.fromLTRB(topLeft.dx, topLeft.dy, bottomRight.dx, bottomRight.dy);
  }

  void unfocus({
    UnfocusDisposition disposition = UnfocusDisposition.scope,
  }) {
    if (!hasFocus && (_manager == null || _manager!._markedForFocus != this)) {
      return;
    }
    FocusScopeNode? scope = enclosingScope;
    if (scope == null) {
      // If the scope is null, then this is either the root node, or a node that
      // is not yet in the tree, neither of which do anything when unfocused.
      return;
    }
    switch (disposition) {
      case UnfocusDisposition.scope:
        // If it can't request focus, then don't modify its focused children.
        if (scope.canRequestFocus) {
          // Clearing the focused children here prevents re-focusing the node
          // that we just unfocused if we immediately hit "next" after
          // unfocusing, and also prevents choosing to refocus the next-to-last
          // focused child if unfocus is called more than once.
          scope._focusedChildren.clear();
        }

        while (!scope!.canRequestFocus) {
          scope = scope.enclosingScope ?? _manager?.rootScope;
        }
        scope._doRequestFocus(findFirstFocus: false);
      case UnfocusDisposition.previouslyFocusedChild:
        // Select the most recent focused child from the nearest focusable scope
        // and focus that. If there isn't one, focus the scope itself.
        if (scope.canRequestFocus) {
          scope._focusedChildren.remove(this);
        }
        while (!scope!.canRequestFocus) {
          scope.enclosingScope?._focusedChildren.remove(scope);
          scope = scope.enclosingScope ?? _manager?.rootScope;
        }
        scope._doRequestFocus(findFirstFocus: true);
    }
    assert(_focusDebug(() => 'Unfocused node:', () => <Object>['primary focus was $this', 'next focus will be ${_manager?._markedForFocus}']));
  }

  bool consumeKeyboardToken() {
    if (!_hasKeyboardToken) {
      return false;
    }
    _hasKeyboardToken = false;
    return true;
  }

  // Marks the node as being the next to be focused, meaning that it will become
  // the primary focus and notify listeners of a focus change the next time
  // focus is resolved by the manager. If something else calls _markNextFocus
  // before then, then that node will become the next focus instead of the
  // previous one.
  void _markNextFocus(FocusNode newFocus) {
    if (_manager != null) {
      // If we have a manager, then let it handle the focus change.
      _manager!._markNextFocus(this);
      return;
    }
    // If we don't have a manager, then change the focus locally.
    newFocus._setAsFocusedChildForScope();
    newFocus._notify();
    if (newFocus != this) {
      _notify();
    }
  }

  // Removes the given FocusNode and its children as a child of this node.
  @mustCallSuper
  void _removeChild(FocusNode node, {bool removeScopeFocus = true}) {
    assert(_children.contains(node), "Tried to remove a node that wasn't a child.");
    assert(node._parent == this);
    assert(node._manager == _manager);

    if (removeScopeFocus) {
      node.enclosingScope?._focusedChildren.remove(node);
    }

    node._parent = null;
    _children.remove(node);
    for (final FocusNode ancestor in ancestors) {
      ancestor._descendants = null;
    }
    _descendants = null;
    assert(_manager == null || !_manager!.rootScope.descendants.contains(node));
  }

  void _updateManager(FocusManager? manager) {
    _manager = manager;
    for (final FocusNode descendant in descendants) {
      descendant._manager = manager;
      descendant._ancestors = null;
    }
  }

  // Used by FocusAttachment.reparent to perform the actual parenting operation.
  @mustCallSuper
  void _reparent(FocusNode child) {
    assert(child != this, 'Tried to make a child into a parent of itself.');
    if (child._parent == this) {
      assert(_children.contains(child), "Found a node that says it's a child, but doesn't appear in the child list.");
      // The child is already a child of this parent.
      return;
    }
    assert(_manager == null || child != _manager!.rootScope, "Reparenting the root node isn't allowed.");
    assert(!ancestors.contains(child), 'The supplied child is already an ancestor of this node. Loops are not allowed.');
    final FocusScopeNode? oldScope = child.enclosingScope;
    final bool hadFocus = child.hasFocus;
    child._parent?._removeChild(child, removeScopeFocus: oldScope != nearestScope);
    _children.add(child);
    child._parent = this;
    child._ancestors = null;
    child._updateManager(_manager);
    for (final FocusNode ancestor in child.ancestors) {
      ancestor._descendants = null;
    }
    if (hadFocus) {
      // Update the focus chain for the current focus without changing it.
      _manager?.primaryFocus?._setAsFocusedChildForScope();
    }
    if (oldScope != null && child.context != null && child.enclosingScope != oldScope) {
      FocusTraversalGroup.maybeOf(child.context!)?.changedScope(node: child, oldScope: oldScope);
    }
    if (child._requestFocusWhenReparented) {
      child._doRequestFocus(findFirstFocus: true);
      child._requestFocusWhenReparented = false;
    }
  }

  @mustCallSuper
  FocusAttachment attach(
    BuildContext? context, {
    FocusOnKeyEventCallback? onKeyEvent,
    FocusOnKeyCallback? onKey,
  }) {
    _context = context;
    this.onKey = onKey ?? this.onKey;
    this.onKeyEvent = onKeyEvent ?? this.onKeyEvent;
    _attachment = FocusAttachment._(this);
    return _attachment!;
  }

  @override
  void dispose() {
    // Detaching will also unfocus and clean up the manager's data structures.
    _attachment?.detach();
    super.dispose();
  }

  @mustCallSuper
  void _notify() {
    if (_parent == null) {
      // no longer part of the tree, so don't notify.
      return;
    }
    if (hasPrimaryFocus) {
      _setAsFocusedChildForScope();
    }
    notifyListeners();
  }

  void requestFocus([FocusNode? node]) {
    if (node != null) {
      if (node._parent == null) {
        _reparent(node);
      }
      assert(node.ancestors.contains(this), 'Focus was requested for a node that is not a descendant of the scope from which it was requested.');
      node._doRequestFocus(findFirstFocus: true);
      return;
    }
    _doRequestFocus(findFirstFocus: true);
  }

  // This is overridden in FocusScopeNode.
  void _doRequestFocus({required bool findFirstFocus}) {
    if (!canRequestFocus) {
      assert(_focusDebug(() => 'Node NOT requesting focus because canRequestFocus is false: $this'));
      return;
    }
    // If the node isn't part of the tree, then we just defer the focus request
    // until the next time it is reparented, so that it's possible to focus
    // newly added widgets.
    if (_parent == null) {
      _requestFocusWhenReparented = true;
      return;
    }
    _setAsFocusedChildForScope();
    if (hasPrimaryFocus && (_manager!._markedForFocus == null || _manager!._markedForFocus == this)) {
      return;
    }
    _hasKeyboardToken = true;
    assert(_focusDebug(() => 'Node requesting focus: $this'));
    _markNextFocus(this);
  }

  // If set to true, the node will request focus on this node the next time
  // this node is reparented in the focus tree.
  //
  // Once requestFocus has been called at the next reparenting, this value
  // will be reset to false.
  //
  // This will only force a call to requestFocus for the node once the next time
  // the node is reparented. After that, _requestFocusWhenReparented would need
  // to be set to true again to have it be focused again on the next
  // reparenting.
  //
  // This is used when requestFocus is called and there is no parent yet.
  bool _requestFocusWhenReparented = false;

  void _setAsFocusedChildForScope() {
    FocusNode scopeFocus = this;
    for (final FocusScopeNode ancestor in ancestors.whereType<FocusScopeNode>()) {
      assert(scopeFocus != ancestor, 'Somehow made a loop by setting focusedChild to its scope.');
      assert(_focusDebug(() => 'Setting $scopeFocus as focused child for scope:', () => <Object>[ancestor]));
      // Remove it anywhere in the focused child history.
      ancestor._focusedChildren.remove(scopeFocus);
      // Add it to the end of the list, which is also the top of the queue: The
      // end of the list represents the currently focused child.
      ancestor._focusedChildren.add(scopeFocus);
      scopeFocus = ancestor;
    }
  }

  bool nextFocus() => FocusTraversalGroup.of(context!).next(this);

  bool previousFocus() => FocusTraversalGroup.of(context!).previous(this);

  bool focusInDirection(TraversalDirection direction) => FocusTraversalGroup.of(context!).inDirection(this, direction);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BuildContext>('context', context, defaultValue: null));
    properties.add(FlagProperty('descendantsAreFocusable', value: descendantsAreFocusable, ifFalse: 'DESCENDANTS UNFOCUSABLE', defaultValue: true));
    properties.add(FlagProperty('descendantsAreTraversable', value: descendantsAreTraversable, ifFalse: 'DESCENDANTS UNTRAVERSABLE', defaultValue: true));
    properties.add(FlagProperty('canRequestFocus', value: canRequestFocus, ifFalse: 'NOT FOCUSABLE', defaultValue: true));
    properties.add(FlagProperty('hasFocus', value: hasFocus && !hasPrimaryFocus, ifTrue: 'IN FOCUS PATH', defaultValue: false));
    properties.add(FlagProperty('hasPrimaryFocus', value: hasPrimaryFocus, ifTrue: 'PRIMARY FOCUS', defaultValue: false));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    int count = 1;
    return _children.map<DiagnosticsNode>((FocusNode child) {
      return child.toDiagnosticsNode(name: 'Child ${count++}');
    }).toList();
  }

  @override
  String toStringShort() {
    final bool hasDebugLabel = debugLabel != null && debugLabel!.isNotEmpty;
    final String extraData = '${hasDebugLabel ? debugLabel : ''}'
        '${hasFocus && hasDebugLabel ? ' ' : ''}'
        '${hasFocus && !hasPrimaryFocus ? '[IN FOCUS PATH]' : ''}'
        '${hasPrimaryFocus ? '[PRIMARY FOCUS]' : ''}';
    return '${describeIdentity(this)}${extraData.isNotEmpty ? '($extraData)' : ''}';
  }
}

class FocusScopeNode extends FocusNode {
  FocusScopeNode({
    super.debugLabel,
    super.onKeyEvent,
    super.onKey,
    super.skipTraversal,
    super.canRequestFocus,
    this.traversalEdgeBehavior = TraversalEdgeBehavior.closedLoop,
  })  : super(
          descendantsAreFocusable: true,
        );

  @override
  FocusScopeNode get nearestScope => this;

  TraversalEdgeBehavior traversalEdgeBehavior;

  bool get isFirstFocus => enclosingScope!.focusedChild == this;

  FocusNode? get focusedChild {
    assert(_focusedChildren.isEmpty || _focusedChildren.last.enclosingScope == this, 'Focused child does not have the same idea of its enclosing scope as the scope does.');
    return _focusedChildren.isNotEmpty ? _focusedChildren.last : null;
  }

  // A stack of the children that have been set as the focusedChild, most recent
  // last (which is the top of the stack).
  final List<FocusNode> _focusedChildren = <FocusNode>[];

  @override
  Iterable<FocusNode> get traversalChildren {
    if (!canRequestFocus) {
      return const Iterable<FocusNode>.empty();
    }
    return super.traversalChildren;
  }

  @override
  Iterable<FocusNode> get traversalDescendants {
    if (!canRequestFocus) {
      return const Iterable<FocusNode>.empty();
    }
    return super.traversalDescendants;
  }

  void setFirstFocus(FocusScopeNode scope) {
    assert(scope != this, 'Unexpected self-reference in setFirstFocus.');
    assert(_focusDebug(() => 'Setting scope as first focus in $this to node:', () => <Object>[scope]));
    if (scope._parent == null) {
      _reparent(scope);
    }
    assert(scope.ancestors.contains(this), '$FocusScopeNode $scope must be a child of $this to set it as first focus.');
    if (hasFocus) {
      scope._doRequestFocus(findFirstFocus: true);
    } else {
      scope._setAsFocusedChildForScope();
    }
  }

  void autofocus(FocusNode node) {
    // Attach the node to the tree first, so in _applyFocusChange if the node
    // is detached we don't add it back to the tree.
    if (node._parent == null) {
      _reparent(node);
    }

    assert(_manager != null);
    assert(_focusDebug(() => 'Autofocus scheduled for $node: scope $this'));
    _manager?._pendingAutofocuses.add(_Autofocus(scope: this, autofocusNode: node));
    _manager?._markNeedsUpdate();
  }

  @override
  void _doRequestFocus({required bool findFirstFocus}) {

    // It is possible that a previously focused child is no longer focusable.
    while (this.focusedChild != null && !this.focusedChild!.canRequestFocus) {
      _focusedChildren.removeLast();
    }

    final FocusNode? focusedChild = this.focusedChild;
    // If findFirstFocus is false, then the request is to make this scope the
    // focus instead of looking for the ultimate first focus for this scope and
    // its descendants.
    if (!findFirstFocus || focusedChild == null) {
      if (canRequestFocus) {
        _setAsFocusedChildForScope();
        _markNextFocus(this);
      }
      return;
    }

    focusedChild._doRequestFocus(findFirstFocus: true);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    if (_focusedChildren.isEmpty) {
      return;
    }
    final List<String> childList = _focusedChildren.reversed.map<String>((FocusNode child) {
      return child.toStringShort();
    }).toList();
    properties.add(IterableProperty<String>('focusedChildren', childList, defaultValue: const Iterable<String>.empty()));
    properties.add(DiagnosticsProperty<TraversalEdgeBehavior>('traversalEdgeBehavior', traversalEdgeBehavior, defaultValue: TraversalEdgeBehavior.closedLoop));
  }
}

enum FocusHighlightMode {
  touch,

  traditional,
}

enum FocusHighlightStrategy {
  automatic,

  alwaysTouch,

  alwaysTraditional,
}

class FocusManager with DiagnosticableTreeMixin, ChangeNotifier {
  FocusManager() {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
    rootScope._manager = this;
  }

  void registerGlobalHandlers() => _highlightManager.registerGlobalHandlers();

  @override
  void dispose() {
    _highlightManager.dispose();
    rootScope.dispose();
    super.dispose();
  }

  static FocusManager get instance => WidgetsBinding.instance.focusManager;

  final _HighlightModeManager _highlightManager = _HighlightModeManager();

  FocusHighlightStrategy get highlightStrategy => _highlightManager.strategy;
  set highlightStrategy(FocusHighlightStrategy value) {
    if (_highlightManager.strategy == value) {
      return;
    }
    _highlightManager.strategy = value;
  }

  // Don't want to set _highlightMode here, since it's possible for the target
  // platform to change (especially in tests).
  FocusHighlightMode get highlightMode => _highlightManager.highlightMode;

  void addHighlightModeListener(ValueChanged<FocusHighlightMode> listener) => _highlightManager.addListener(listener);

  void removeHighlightModeListener(ValueChanged<FocusHighlightMode> listener) => _highlightManager.removeListener(listener);

  final FocusScopeNode rootScope = FocusScopeNode(debugLabel: 'Root Focus Scope');

  FocusNode? get primaryFocus => _primaryFocus;
  FocusNode? _primaryFocus;

  // The set of nodes that need to notify their listeners of changes at the next
  // update.
  final Set<FocusNode> _dirtyNodes = <FocusNode>{};

  // The node that has requested to have the primary focus, but hasn't been
  // given it yet.
  FocusNode? _markedForFocus;

  void _markDetached(FocusNode node) {
    // The node has been removed from the tree, so it no longer needs to be
    // notified of changes.
    assert(_focusDebug(() => 'Node was detached: $node'));
    if (_primaryFocus == node) {
      _primaryFocus = null;
    }
    _dirtyNodes.remove(node);
  }

  void _markPropertiesChanged(FocusNode node) {
    _markNeedsUpdate();
    assert(_focusDebug(() => 'Properties changed for node $node.'));
    _dirtyNodes.add(node);
  }

  void _markNextFocus(FocusNode node) {
    if (_primaryFocus == node) {
      // The caller asked for the current focus to be the next focus, so just
      // pretend that didn't happen.
      _markedForFocus = null;
    } else {
      _markedForFocus = node;
      _markNeedsUpdate();
    }
  }

  // The list of autofocus requests made since the last _applyFocusChange call.
  final List<_Autofocus> _pendingAutofocuses = <_Autofocus>[];

  // True indicates that there is an update pending.
  bool _haveScheduledUpdate = false;

  // Request that an update be scheduled, optionally requesting focus for the
  // given newFocus node.
  void _markNeedsUpdate() {
    assert(_focusDebug(() => 'Scheduling update, current focus is $_primaryFocus, next focus will be $_markedForFocus'));
    if (_haveScheduledUpdate) {
      return;
    }
    _haveScheduledUpdate = true;
    scheduleMicrotask(applyFocusChangesIfNeeded);
  }

  void applyFocusChangesIfNeeded() {
    assert(
      SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks,
      'applyFocusChangesIfNeeded() should not be called during the build phase.'
    );

    _haveScheduledUpdate = false;
    final FocusNode? previousFocus = _primaryFocus;

    for (final _Autofocus autofocus in _pendingAutofocuses) {
      autofocus.applyIfValid(this);
    }
    _pendingAutofocuses.clear();

    if (_primaryFocus == null && _markedForFocus == null) {
      // If we don't have any current focus, and nobody has asked to focus yet,
      // then revert to the root scope.
      _markedForFocus = rootScope;
    }
    assert(_focusDebug(() => 'Refreshing focus state. Next focus will be $_markedForFocus'));
    // A node has requested to be the next focus, and isn't already the primary
    // focus.
    if (_markedForFocus != null && _markedForFocus != _primaryFocus) {
      final Set<FocusNode> previousPath = previousFocus?.ancestors.toSet() ?? <FocusNode>{};
      final Set<FocusNode> nextPath = _markedForFocus!.ancestors.toSet();
      // Notify nodes that are newly focused.
      _dirtyNodes.addAll(nextPath.difference(previousPath));
      // Notify nodes that are no longer focused
      _dirtyNodes.addAll(previousPath.difference(nextPath));

      _primaryFocus = _markedForFocus;
      _markedForFocus = null;
    }
    assert(_markedForFocus == null);
    if (previousFocus != _primaryFocus) {
      assert(_focusDebug(() => 'Updating focus from $previousFocus to $_primaryFocus'));
      if (previousFocus != null) {
        _dirtyNodes.add(previousFocus);
      }
      if (_primaryFocus != null) {
        _dirtyNodes.add(_primaryFocus!);
      }
    }
    for (final FocusNode node in _dirtyNodes) {
      node._notify();
    }
    assert(_focusDebug(() => 'Notified ${_dirtyNodes.length} dirty nodes:', () => _dirtyNodes));
    _dirtyNodes.clear();
    if (previousFocus != _primaryFocus) {
      notifyListeners();
    }
    assert(() {
      if (debugFocusChanges) {
        debugDumpFocusTree();
      }
      return true;
    }());
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return <DiagnosticsNode>[
      rootScope.toDiagnosticsNode(name: 'rootScope'),
    ];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(FlagProperty('haveScheduledUpdate', value: _haveScheduledUpdate, ifTrue: 'UPDATE SCHEDULED'));
    properties.add(DiagnosticsProperty<FocusNode>('primaryFocus', primaryFocus, defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('nextFocus', _markedForFocus, defaultValue: null));
    final Element? element = primaryFocus?.context as Element?;
    if (element != null) {
      properties.add(DiagnosticsProperty<String>('primaryFocusCreator', element.debugGetCreatorChain(20)));
    }
  }
}

// A class to detect and manage the highlight mode transitions. An instance of
// this is owned by the FocusManager.
//
// This doesn't extend ChangeNotifier because the callback passes the updated
// value, and ChangeNotifier requires using VoidCallback.
class _HighlightModeManager {
  // If set, indicates if the last interaction detected was touch or not. If
  // null, no interactions have occurred yet.
  bool? _lastInteractionWasTouch;

  FocusHighlightMode get highlightMode => _highlightMode ?? _defaultModeForPlatform;
  FocusHighlightMode? _highlightMode;

  FocusHighlightStrategy get strategy => _strategy;
  FocusHighlightStrategy _strategy = FocusHighlightStrategy.automatic;
  set strategy(FocusHighlightStrategy value) {
    if (_strategy == value) {
      return;
    }
    _strategy = value;
    updateMode();
  }

  void addListener(ValueChanged<FocusHighlightMode> listener) => _listeners.add(listener);

  void removeListener(ValueChanged<FocusHighlightMode> listener) => _listeners.remove(listener);

  // The list of listeners for [highlightMode] state changes.
  HashedObserverList<ValueChanged<FocusHighlightMode>> _listeners = HashedObserverList<ValueChanged<FocusHighlightMode>>();

  void registerGlobalHandlers() {
    assert(ServicesBinding.instance.keyEventManager.keyMessageHandler == null);
    ServicesBinding.instance.keyEventManager.keyMessageHandler = handleKeyMessage;
    GestureBinding.instance.pointerRouter.addGlobalRoute(handlePointerEvent);
  }

  @mustCallSuper
  void dispose() {
    if (ServicesBinding.instance.keyEventManager.keyMessageHandler == handleKeyMessage) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(handlePointerEvent);
      ServicesBinding.instance.keyEventManager.keyMessageHandler = null;
    }
    _listeners = HashedObserverList<ValueChanged<FocusHighlightMode>>();
  }

  @pragma('vm:notify-debugger-on-exception')
  void notifyListeners() {
    if (_listeners.isEmpty) {
      return;
    }
    final List<ValueChanged<FocusHighlightMode>> localListeners = List<ValueChanged<FocusHighlightMode>>.of(_listeners);
    for (final ValueChanged<FocusHighlightMode> listener in localListeners) {
      try {
        if (_listeners.contains(listener)) {
          listener(highlightMode);
        }
      } catch (exception, stack) {
        InformationCollector? collector;
        assert(() {
          collector = () => <DiagnosticsNode>[
            DiagnosticsProperty<_HighlightModeManager>(
              'The $runtimeType sending notification was',
              this,
              style: DiagnosticsTreeStyle.errorProperty,
            ),
          ];
          return true;
        }());
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'widgets library',
          context: ErrorDescription('while dispatching notifications for $runtimeType'),
          informationCollector: collector,
        ));
      }
    }
  }

  void handlePointerEvent(PointerEvent event) {
    final FocusHighlightMode expectedMode;
    switch (event.kind) {
      case PointerDeviceKind.touch:
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
        _lastInteractionWasTouch = true;
        expectedMode = FocusHighlightMode.touch;
      case PointerDeviceKind.mouse:
      case PointerDeviceKind.trackpad:
      case PointerDeviceKind.unknown:
        _lastInteractionWasTouch = false;
        expectedMode = FocusHighlightMode.traditional;
    }
    if (expectedMode != highlightMode) {
      updateMode();
    }
  }

  bool handleKeyMessage(KeyMessage message) {
    // Update highlightMode first, since things responding to the keys might
    // look at the highlight mode, and it should be accurate.
    _lastInteractionWasTouch = false;
    updateMode();

    assert(_focusDebug(() => 'Received key event $message'));
    if (FocusManager.instance.primaryFocus == null) {
      assert(_focusDebug(() => 'No primary focus for key event, ignored: $message'));
      return false;
    }

    // Walk the current focus from the leaf to the root, calling each one's
    // onKey on the way up, and if one responds that they handled it or want to
    // stop propagation, stop.
    bool handled = false;
    for (final FocusNode node in <FocusNode>[
      FocusManager.instance.primaryFocus!,
      ...FocusManager.instance.primaryFocus!.ancestors,
    ]) {
      final List<KeyEventResult> results = <KeyEventResult>[];
      if (node.onKeyEvent != null) {
        for (final KeyEvent event in message.events) {
          results.add(node.onKeyEvent!(node, event));
        }
      }
      if (node.onKey != null && message.rawEvent != null) {
        results.add(node.onKey!(node, message.rawEvent!));
      }
      final KeyEventResult result = combineKeyEventResults(results);
      switch (result) {
        case KeyEventResult.ignored:
          continue;
        case KeyEventResult.handled:
          assert(_focusDebug(() => 'Node $node handled key event $message.'));
          handled = true;
        case KeyEventResult.skipRemainingHandlers:
          assert(_focusDebug(() => 'Node $node stopped key event propagation: $message.'));
          handled = false;
      }
      // Only KeyEventResult.ignored will continue the for loop. All other
      // options will stop the event propagation.
      assert(result != KeyEventResult.ignored);
      break;
    }
    if (!handled) {
      assert(_focusDebug(() => 'Key event not handled by anyone: $message.'));
    }
    return handled;
  }

  // Update function to be called whenever the state relating to highlightMode
  // changes.
  void updateMode() {
    final FocusHighlightMode newMode;
    switch (strategy) {
      case FocusHighlightStrategy.automatic:
        if (_lastInteractionWasTouch == null) {
          // If we don't have any information about the last interaction yet,
          // then just rely on the default value for the platform, which will be
          // determined based on the target platform if _highlightMode is not
          // set.
          return;
        }
        if (_lastInteractionWasTouch!) {
          newMode = FocusHighlightMode.touch;
        } else {
          newMode = FocusHighlightMode.traditional;
        }
      case FocusHighlightStrategy.alwaysTouch:
        newMode = FocusHighlightMode.touch;
      case FocusHighlightStrategy.alwaysTraditional:
        newMode = FocusHighlightMode.traditional;
    }
    // We can't just compare newMode with _highlightMode here, since
    // _highlightMode could be null, so we want to compare with the return value
    // for the getter, since that's what clients will be looking at.
    final FocusHighlightMode oldMode = highlightMode;
    _highlightMode = newMode;
    if (highlightMode != oldMode) {
      notifyListeners();
    }
  }

  static FocusHighlightMode get _defaultModeForPlatform {
    // Assume that if we're on one of the mobile platforms, and there's no mouse
    // connected, that the initial interaction will be touch-based, and that
    // it's traditional mouse and keyboard on all other platforms.
    //
    // This only affects the initial value: the ongoing value is updated to a
    // known correct value as soon as any pointer/keyboard events are received.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        if (WidgetsBinding.instance.mouseTracker.mouseIsConnected) {
          return FocusHighlightMode.traditional;
        }
        return FocusHighlightMode.touch;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return FocusHighlightMode.traditional;
    }
  }
}

FocusNode? get primaryFocus => WidgetsBinding.instance.focusManager.primaryFocus;

String debugDescribeFocusTree() {
  String? result;
  assert(() {
    result = FocusManager.instance.toStringDeep();
    return true;
  }());
  return result ?? '';
}

void debugDumpFocusTree() {
  assert(() {
    debugPrint(debugDescribeFocusTree());
    return true;
  }());
}