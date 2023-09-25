
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import 'focus_manager.dart';
import 'framework.dart';
import 'text_editing_intents.dart';

class UndoHistory<T> extends StatefulWidget {
  const UndoHistory({
    super.key,
    this.shouldChangeUndoStack,
    required this.value,
    required this.onTriggered,
    required this.focusNode,
    this.controller,
    required this.child,
  });

  final ValueNotifier<T> value;

  final bool Function(T? oldValue, T newValue)? shouldChangeUndoStack;

  final void Function(T value) onTriggered;

  final FocusNode focusNode;

  final UndoHistoryController? controller;

  final Widget child;

  @override
  State<UndoHistory<T>> createState() => UndoHistoryState<T>();
}

@visibleForTesting
class UndoHistoryState<T> extends State<UndoHistory<T>> with UndoManagerClient {
  final _UndoStack<T> _stack = _UndoStack<T>();
  late final _Throttled<T> _throttledPush;
  Timer? _throttleTimer;
  bool _duringTrigger = false;

  // This duration was chosen as a best fit for the behavior of Mac, Linux,
  // and Windows undo/redo state save durations, but it is not perfect for any
  // of them.
  static const Duration _kThrottleDuration = Duration(milliseconds: 500);

  // Record the last value to prevent pushing multiple
  // of the same value in a row onto the undo stack. For example, _push gets
  // called both in initState and when the EditableText receives focus.
  T? _lastValue;

  UndoHistoryController? _controller;

  UndoHistoryController get _effectiveController => widget.controller ?? (_controller ??= UndoHistoryController());

  @override
  void undo() {
    if (_stack.currentValue == null)  {
      // Returns early if there is not a first value registered in the history.
      // This is important because, if an undo is received while the initial
      // value is being pushed (a.k.a when the field gets the focus but the
      // throttling delay is pending), the initial push should not be canceled.
      return;
    }
    if (_throttleTimer?.isActive ?? false) {
      _throttleTimer?.cancel(); // Cancel ongoing push, if any.
      _update(_stack.currentValue);
    } else {
      _update(_stack.undo());
    }
    _updateState();
  }

  @override
  void redo() {
    _update(_stack.redo());
    _updateState();
  }

  @override
  bool get canUndo => _stack.canUndo;

  @override
  bool get canRedo => _stack.canRedo;

  void _updateState() {
    _effectiveController.value = UndoHistoryValue(canUndo: canUndo, canRedo: canRedo);

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    if (UndoManager.client == this) {
      UndoManager.setUndoState(canUndo: canUndo, canRedo: canRedo);
    }
  }

  void _undoFromIntent(UndoTextIntent intent) {
    undo();
  }

  void _redoFromIntent(RedoTextIntent intent) {
    redo();
  }

  void _update(T? nextValue) {
    if (nextValue == null) {
      return;
    }
    if (nextValue == _lastValue) {
      return;
    }
    _lastValue = nextValue;
    _duringTrigger = true;
    try {
      widget.onTriggered(nextValue);
      assert(widget.value.value == nextValue);
    } finally {
      _duringTrigger = false;
    }
  }

  void _push() {
    if (widget.value.value == _lastValue) {
      return;
    }

    if (_duringTrigger) {
      return;
    }

    if (!(widget.shouldChangeUndoStack?.call(_lastValue, widget.value.value) ?? true)) {
      return;
    }

    _lastValue = widget.value.value;

    _throttleTimer = _throttledPush(widget.value.value);
  }

  void _handleFocus() {
    if (!widget.focusNode.hasFocus) {
      return;
    }
    UndoManager.client = this;
    _updateState();
  }

  @override
  void handlePlatformUndo(UndoDirection direction) {
    switch (direction) {
      case UndoDirection.undo:
        undo();
      case UndoDirection.redo:
        redo();
    }
  }

  @override
  void initState() {
    super.initState();
    _throttledPush = _throttle<T>(
      duration: _kThrottleDuration,
      function: (T currentValue) {
        _stack.push(currentValue);
        _updateState();
      },
    );
    _push();
    widget.value.addListener(_push);
    _handleFocus();
    widget.focusNode.addListener(_handleFocus);
    _effectiveController.onUndo.addListener(undo);
    _effectiveController.onRedo.addListener(redo);
  }

  @override
  void didUpdateWidget(UndoHistory<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _stack.clear();
      oldWidget.value.removeListener(_push);
      widget.value.addListener(_push);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocus);
      widget.focusNode.addListener(_handleFocus);
    }
    if (widget.controller != oldWidget.controller) {
      _effectiveController.onUndo.removeListener(undo);
      _effectiveController.onRedo.removeListener(redo);
      _controller?.dispose();
      _controller = null;
      _effectiveController.onUndo.addListener(undo);
      _effectiveController.onRedo.addListener(redo);
    }
  }

  @override
  void dispose() {
    widget.value.removeListener(_push);
    widget.focusNode.removeListener(_handleFocus);
    _effectiveController.onUndo.removeListener(undo);
    _effectiveController.onRedo.removeListener(redo);
    _controller?.dispose();
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        UndoTextIntent: Action<UndoTextIntent>.overridable(context: context, defaultAction: CallbackAction<UndoTextIntent>(onInvoke: _undoFromIntent)),
        RedoTextIntent: Action<RedoTextIntent>.overridable(context: context, defaultAction: CallbackAction<RedoTextIntent>(onInvoke: _redoFromIntent)),
      },
      child: widget.child,
    );
  }
}

@immutable
class UndoHistoryValue {
  const UndoHistoryValue({this.canUndo = false, this.canRedo = false});

  static const UndoHistoryValue empty = UndoHistoryValue();

  final bool canUndo;

  final bool canRedo;

  @override
  String toString() => '${objectRuntimeType(this, 'UndoHistoryValue')}(canUndo: $canUndo, canRedo: $canRedo)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is UndoHistoryValue && other.canUndo == canUndo && other.canRedo == canRedo;
  }

  @override
  int get hashCode => Object.hash(
    canUndo.hashCode,
    canRedo.hashCode,
  );
}

class UndoHistoryController extends ValueNotifier<UndoHistoryValue> {
  UndoHistoryController({UndoHistoryValue? value}) : super(value ?? UndoHistoryValue.empty);

  final ChangeNotifier onUndo = ChangeNotifier();

  final ChangeNotifier onRedo = ChangeNotifier();

  void undo() {
    if (!value.canUndo) {
      return;
    }

    onUndo.notifyListeners();
  }

  void redo() {
    if (!value.canRedo) {
      return;
    }

    onRedo.notifyListeners();
  }

  @override
  void dispose() {
    onUndo.dispose();
    onRedo.dispose();
    super.dispose();
  }
}

class _UndoStack<T> {
  _UndoStack();

  final List<T> _list = <T>[];

  // The index of the current value, or -1 if the list is empty.
  int _index = -1;

  T? get currentValue => _list.isEmpty ? null : _list[_index];

  bool get canUndo => _list.isNotEmpty && _index > 0;

  bool get canRedo => _list.isNotEmpty && _index < _list.length - 1;

  void push(T value) {
    if (_list.isEmpty) {
      _index = 0;
      _list.add(value);
      return;
    }

    assert(_index < _list.length && _index >= 0);

    if (value == currentValue) {
      return;
    }

    // If anything has been undone in this stack, remove those irrelevant states
    // before adding the new one.
    if (_index != _list.length - 1) {
      _list.removeRange(_index + 1, _list.length);
    }
    _list.add(value);
    _index = _list.length - 1;
  }

  T? undo() {
    if (_list.isEmpty) {
      return null;
    }

    assert(_index < _list.length && _index >= 0);

    if (_index != 0) {
      _index = _index - 1;
    }

    return currentValue;
  }

  T? redo() {
    if (_list.isEmpty) {
      return null;
    }

    assert(_index < _list.length && _index >= 0);

    if (_index < _list.length - 1) {
      _index = _index + 1;
    }

    return currentValue;
  }

  void clear() {
    _list.clear();
    _index = -1;
  }

  @override
  String toString() {
    return '_UndoStack $_list';
  }
}

typedef _Throttleable<T> = void Function(T currentArg);

typedef _Throttled<T> = Timer Function(T currentArg);

_Throttled<T> _throttle<T>({
  required Duration duration,
  required _Throttleable<T> function,
}) {
  Timer? timer;
  late T arg;

  return (T currentArg) {
    arg = currentArg;
    if (timer != null && timer!.isActive) {
      return timer!;
    }
    timer = Timer(duration, () {
      function(arg);
      timer = null;
    });
    return timer!;
  };
}