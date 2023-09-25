import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'focus_manager.dart';
import 'focus_scope.dart';
import 'framework.dart';
import 'media_query.dart';
import 'shortcuts.dart';

BuildContext _getParent(BuildContext context) {
  late final BuildContext parent;
  context.visitAncestorElements((Element ancestor) {
    parent = ancestor;
    return false;
  });
  return parent;
}

@immutable
abstract class Intent with Diagnosticable {
  const Intent();

  static const DoNothingIntent doNothing = DoNothingIntent._();
}

typedef ActionListenerCallback = void Function(Action<Intent> action);

abstract class Action<T extends Intent> with Diagnosticable {
  Action();

  factory Action.overridable({
    required Action<T> defaultAction,
    required BuildContext context,
  }) {
    return defaultAction._makeOverridableAction(context);
  }

  final ObserverList<ActionListenerCallback> _listeners = ObserverList<ActionListenerCallback>();

  Action<T>? _currentCallingAction;
  // ignore: use_setters_to_change_properties, (code predates enabling of this lint)
  void _updateCallingAction(Action<T>? value) {
    _currentCallingAction = value;
  }

  @protected
  Action<T>? get callingAction => _currentCallingAction;

  Type get intentType => T;

  bool isEnabled(T intent) => isActionEnabled;

  bool _isEnabled(T intent, BuildContext? context) {
    final Action<T> self = this;
    if (self is ContextAction<T>) {
      return self.isEnabled(intent, context);
    }
    return self.isEnabled(intent);
  }

  //
  bool get isActionEnabled => true;

  bool consumesKey(T intent) => true;

  KeyEventResult toKeyEventResult(T intent, covariant Object? invokeResult) {
    return consumesKey(intent)
      ? KeyEventResult.handled
      : KeyEventResult.skipRemainingHandlers;
  }

  @protected
  Object? invoke(T intent);

  Object? _invoke(T intent, BuildContext? context) {
    final Action<T> self = this;
    if (self is ContextAction<T>) {
      return self.invoke(intent, context);
    }
    return self.invoke(intent);
  }

  @mustCallSuper
  void addActionListener(ActionListenerCallback listener) => _listeners.add(listener);

  @mustCallSuper
  void removeActionListener(ActionListenerCallback listener) => _listeners.remove(listener);

  @protected
  @visibleForTesting
  @pragma('vm:notify-debugger-on-exception')
  void notifyActionListeners() {
    if (_listeners.isEmpty) {
      return;
    }

    // Make a local copy so that a listener can unregister while the list is
    // being iterated over.
    final List<ActionListenerCallback> localListeners = List<ActionListenerCallback>.of(_listeners);
    for (final ActionListenerCallback listener in localListeners) {
      InformationCollector? collector;
      assert(() {
        collector = () => <DiagnosticsNode>[
          DiagnosticsProperty<Action<T>>(
            'The $runtimeType sending notification was',
            this,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
        ];
        return true;
      }());
      try {
        if (_listeners.contains(listener)) {
          listener(this);
        }
      } catch (exception, stack) {
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

  Action<T> _makeOverridableAction(BuildContext context) {
    return _OverridableAction<T>(defaultAction: this, lookupContext: context);
  }
}

@immutable
class ActionListener extends StatefulWidget {
  const ActionListener({
    super.key,
    required this.listener,
    required this.action,
    required this.child,
  });

  final ActionListenerCallback listener;

  final Action<Intent> action;

  final Widget child;

  @override
  State<ActionListener> createState() => _ActionListenerState();
}

class _ActionListenerState extends State<ActionListener> {
  @override
  void initState() {
    super.initState();
    widget.action.addActionListener(widget.listener);
  }

  @override
  void didUpdateWidget(ActionListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action == widget.action && oldWidget.listener == widget.listener) {
      return;
    }
    oldWidget.action.removeActionListener(oldWidget.listener);
    widget.action.addActionListener(widget.listener);
  }

  @override
  void dispose() {
    widget.action.removeActionListener(widget.listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

abstract class ContextAction<T extends Intent> extends Action<T> {
  @override
  bool isEnabled(T intent, [BuildContext? context]) => super.isEnabled(intent);

  @protected
  @override
  Object? invoke(T intent, [BuildContext? context]);

  @override
  ContextAction<T> _makeOverridableAction(BuildContext context) {
    return _OverridableContextAction<T>(defaultAction: this, lookupContext: context);
  }
}

typedef OnInvokeCallback<T extends Intent> = Object? Function(T intent);

class CallbackAction<T extends Intent> extends Action<T> {
  CallbackAction({required this.onInvoke});

  @protected
  final OnInvokeCallback<T> onInvoke;

  @override
  Object? invoke(T intent) => onInvoke(intent);
}

class ActionDispatcher with Diagnosticable {
  const ActionDispatcher();

  Object? invokeAction(
    covariant Action<Intent> action,
    covariant Intent intent, [
    BuildContext? context,
  ]) {
    final BuildContext? target = context ?? primaryFocus?.context;
    assert(action._isEnabled(intent, target), 'Action must be enabled when calling invokeAction');
    return action._invoke(intent, target);
  }

  (bool, Object?) invokeActionIfEnabled(
    covariant Action<Intent> action,
    covariant Intent intent, [
    BuildContext? context,
  ]) {
    final BuildContext? target = context ?? primaryFocus?.context;
    if (action._isEnabled(intent, target)) {
      return (true, action._invoke(intent, target));
    }
    return (false, null);
  }
}

class Actions extends StatefulWidget {
  const Actions({
    super.key,
    this.dispatcher,
    required this.actions,
    required this.child,
  });

  final ActionDispatcher? dispatcher;

  final Map<Type, Action<Intent>> actions;

  final Widget child;

  // Visits the Actions widget ancestors of the given element using
  // getElementForInheritedWidgetOfExactType. Returns true if the visitor found
  // what it was looking for.
  static bool _visitActionsAncestors(BuildContext context, bool Function(InheritedElement element) visitor) {
    InheritedElement? actionsElement = context.getElementForInheritedWidgetOfExactType<_ActionsScope>();
    while (actionsElement != null) {
      if (visitor(actionsElement)) {
        break;
      }
      // _getParent is needed here because
      // context.getElementForInheritedWidgetOfExactType will return itself if it
      // happens to be of the correct type.
      final BuildContext parent = _getParent(actionsElement);
      actionsElement = parent.getElementForInheritedWidgetOfExactType<_ActionsScope>();
    }
    return actionsElement != null;
  }

  // Finds the nearest valid ActionDispatcher, or creates a new one if it
  // doesn't find one.
  static ActionDispatcher _findDispatcher(BuildContext context) {
    ActionDispatcher? dispatcher;
    _visitActionsAncestors(context, (InheritedElement element) {
      final ActionDispatcher? found = (element.widget as _ActionsScope).dispatcher;
      if (found != null) {
        dispatcher = found;
        return true;
      }
      return false;
    });
    return dispatcher ?? const ActionDispatcher();
  }

  static VoidCallback? handler<T extends Intent>(BuildContext context, T intent) {
    final Action<T>? action = Actions.maybeFind<T>(context);
    if (action != null && action._isEnabled(intent, context)) {
      return () {
        // Could be that the action was enabled when the closure was created,
        // but is now no longer enabled, so check again.
        if (action._isEnabled(intent, context)) {
          Actions.of(context).invokeAction(action, intent, context);
        }
      };
    }
    return null;
  }

  static Action<T> find<T extends Intent>(BuildContext context, { T? intent }) {
    final Action<T>? action = maybeFind(context, intent: intent);

    assert(() {
      if (action == null) {
        final Type type = intent?.runtimeType ?? T;
        throw FlutterError(
          'Unable to find an action for a $type in an $Actions widget '
          'in the given context.\n'
          "$Actions.find() was called on a context that doesn't contain an "
          '$Actions widget with a mapping for the given intent type.\n'
          'The context used was:\n'
          '  $context\n'
          'The intent type requested was:\n'
          '  $type',
        );
      }
      return true;
    }());
    return action!;
  }

  static Action<T>? maybeFind<T extends Intent>(BuildContext context, { T? intent }) {
    Action<T>? action;

    // Specialize the type if a runtime example instance of the intent is given.
    // This allows this function to be called by code that doesn't know the
    // concrete type of the intent at compile time.
    final Type type = intent?.runtimeType ?? T;
    assert(
      type != Intent,
      'The type passed to "find" resolved to "Intent": either a non-Intent '
      'generic type argument or an example intent derived from Intent must be '
      'specified. Intent may be used as the generic type as long as the optional '
      '"intent" argument is passed.',
    );

    _visitActionsAncestors(context, (InheritedElement element) {
      final _ActionsScope actions = element.widget as _ActionsScope;
      final Action<T>? result = _castAction(actions, intent: intent);
      if (result != null) {
        context.dependOnInheritedElement(element);
        action = result;
        return true;
      }
      return false;
    });

    return action;
  }

  static Action<T>? _maybeFindWithoutDependingOn<T extends Intent>(BuildContext context, { T? intent }) {
    Action<T>? action;

    // Specialize the type if a runtime example instance of the intent is given.
    // This allows this function to be called by code that doesn't know the
    // concrete type of the intent at compile time.
    final Type type = intent?.runtimeType ?? T;
    assert(
      type != Intent,
      'The type passed to "find" resolved to "Intent": either a non-Intent '
      'generic type argument or an example intent derived from Intent must be '
      'specified. Intent may be used as the generic type as long as the optional '
      '"intent" argument is passed.',
    );

    _visitActionsAncestors(context, (InheritedElement element) {
      final _ActionsScope actions = element.widget as _ActionsScope;
      final Action<T>? result = _castAction(actions, intent: intent);
      if (result != null) {
        action = result;
        return true;
      }
      return false;
    });

    return action;
  }

  // Find the [Action] that handles the given `intent` in the given
  // `_ActionsScope`, and verify it has the right type parameter.
  static Action<T>? _castAction<T extends Intent>(_ActionsScope actionsMarker, { T? intent }) {
    final Action<Intent>? mappedAction = actionsMarker.actions[intent?.runtimeType ?? T];
    if (mappedAction is Action<T>?) {
      return mappedAction;
    } else {
      assert(
        false,
        '$T cannot be handled by an Action of runtime type ${mappedAction.runtimeType}.'
      );
      return null;
    }
  }

  static ActionDispatcher of(BuildContext context) {
    final _ActionsScope? marker = context.dependOnInheritedWidgetOfExactType<_ActionsScope>();
    return marker?.dispatcher ?? _findDispatcher(context);
  }

  static Object? invoke<T extends Intent>(
    BuildContext context,
    T intent,
  ) {
    Object? returnValue;

    final bool actionFound = _visitActionsAncestors(context, (InheritedElement element) {
      final _ActionsScope actions = element.widget as _ActionsScope;
      final Action<T>? result = _castAction(actions, intent: intent);
      if (result != null && result._isEnabled(intent, context)) {
        // Invoke the action we found using the relevant dispatcher from the Actions
        // Element we found.
        returnValue = _findDispatcher(element).invokeAction(result, intent, context);
      }
      return result != null;
    });

    assert(() {
      if (!actionFound) {
        throw FlutterError(
          'Unable to find an action for an Intent with type '
          '${intent.runtimeType} in an $Actions widget in the given context.\n'
          '$Actions.invoke() was unable to find an $Actions widget that '
          "contained a mapping for the given intent, or the intent type isn't the "
          'same as the type argument to invoke (which is $T - try supplying a '
          'type argument to invoke if one was not given)\n'
          'The context used was:\n'
          '  $context\n'
          'The intent type requested was:\n'
          '  ${intent.runtimeType}',
        );
      }
      return true;
    }());
    return returnValue;
  }

  static Object? maybeInvoke<T extends Intent>(
    BuildContext context,
    T intent,
  ) {
    Object? returnValue;
    _visitActionsAncestors(context, (InheritedElement element) {
      final _ActionsScope actions = element.widget as _ActionsScope;
      final Action<T>? result = _castAction(actions, intent: intent);
      if (result != null && result._isEnabled(intent, context)) {
        // Invoke the action we found using the relevant dispatcher from the Actions
        // element we found.
        returnValue = _findDispatcher(element).invokeAction(result, intent, context);
      }
      return result != null;
    });
    return returnValue;
  }

  @override
  State<Actions> createState() => _ActionsState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ActionDispatcher>('dispatcher', dispatcher));
    properties.add(DiagnosticsProperty<Map<Type, Action<Intent>>>('actions', actions));
  }
}

class _ActionsState extends State<Actions> {
  // The set of actions that this Actions widget is current listening to.
  Set<Action<Intent>>? listenedActions = <Action<Intent>>{};
  // Used to tell the marker to rebuild its dependencies when the state of an
  // action in the map changes.
  Object rebuildKey = Object();

  @override
  void initState() {
    super.initState();
    _updateActionListeners();
  }

  void _handleActionChanged(Action<Intent> action) {
    // Generate a new key so that the marker notifies dependents.
    setState(() {
      rebuildKey = Object();
    });
  }

  void _updateActionListeners() {
    final Set<Action<Intent>> widgetActions = widget.actions.values.toSet();
    final Set<Action<Intent>> removedActions = listenedActions!.difference(widgetActions);
    final Set<Action<Intent>> addedActions = widgetActions.difference(listenedActions!);

    for (final Action<Intent> action in removedActions) {
      action.removeActionListener(_handleActionChanged);
    }
    for (final Action<Intent> action in addedActions) {
      action.addActionListener(_handleActionChanged);
    }
    listenedActions = widgetActions;
  }

  @override
  void didUpdateWidget(Actions oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateActionListeners();
  }

  @override
  void dispose() {
    super.dispose();
    for (final Action<Intent> action in listenedActions!) {
      action.removeActionListener(_handleActionChanged);
    }
    listenedActions = null;
  }

  @override
  Widget build(BuildContext context) {
    return _ActionsScope(
      actions: widget.actions,
      dispatcher: widget.dispatcher,
      rebuildKey: rebuildKey,
      child: widget.child,
    );
  }
}

// An inherited widget used by Actions widget for fast lookup of the Actions
// widget information.
class _ActionsScope extends InheritedWidget {
  const _ActionsScope({
    required this.dispatcher,
    required this.actions,
    required this.rebuildKey,
    required super.child,
  });

  final ActionDispatcher? dispatcher;
  final Map<Type, Action<Intent>> actions;
  final Object rebuildKey;

  @override
  bool updateShouldNotify(_ActionsScope oldWidget) {
    return rebuildKey != oldWidget.rebuildKey
        || oldWidget.dispatcher != dispatcher
        || !mapEquals<Type, Action<Intent>>(oldWidget.actions, actions);
  }
}

class FocusableActionDetector extends StatefulWidget {
  const FocusableActionDetector({
    super.key,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.descendantsAreFocusable = true,
    this.descendantsAreTraversable = true,
    this.shortcuts,
    this.actions,
    this.onShowFocusHighlight,
    this.onShowHoverHighlight,
    this.onFocusChange,
    this.mouseCursor = MouseCursor.defer,
    this.includeFocusSemantics = true,
    required this.child,
  });

  final bool enabled;

  final FocusNode? focusNode;

  final bool autofocus;

  final bool descendantsAreFocusable;

  final bool descendantsAreTraversable;

  final Map<Type, Action<Intent>>? actions;

  final Map<ShortcutActivator, Intent>? shortcuts;

  final ValueChanged<bool>? onShowFocusHighlight;

  final ValueChanged<bool>? onShowHoverHighlight;

  final ValueChanged<bool>? onFocusChange;

  final MouseCursor mouseCursor;

  final bool includeFocusSemantics;

  final Widget child;

  @override
  State<FocusableActionDetector> createState() => _FocusableActionDetectorState();
}

class _FocusableActionDetectorState extends State<FocusableActionDetector> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
      _updateHighlightMode(FocusManager.instance.highlightMode);
    });
    FocusManager.instance.addHighlightModeListener(_handleFocusHighlightModeChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleFocusHighlightModeChange);
    super.dispose();
  }

  bool _canShowHighlight = false;
  void _updateHighlightMode(FocusHighlightMode mode) {
    _mayTriggerCallback(task: () {
      switch (FocusManager.instance.highlightMode) {
        case FocusHighlightMode.touch:
          _canShowHighlight = false;
        case FocusHighlightMode.traditional:
          _canShowHighlight = true;
      }
    });
  }

  // Have to have this separate from the _updateHighlightMode because it gets
  // called in initState, where things aren't mounted yet.
  // Since this method is a highlight mode listener, it is only called
  // immediately following pointer events.
  void _handleFocusHighlightModeChange(FocusHighlightMode mode) {
    if (!mounted) {
      return;
    }
    _updateHighlightMode(mode);
  }

  bool _hovering = false;
  void _handleMouseEnter(PointerEnterEvent event) {
    if (!_hovering) {
      _mayTriggerCallback(task: () {
        _hovering = true;
      });
    }
  }

  void _handleMouseExit(PointerExitEvent event) {
    if (_hovering) {
      _mayTriggerCallback(task: () {
        _hovering = false;
      });
    }
  }

  bool _focused = false;
  void _handleFocusChange(bool focused) {
    if (_focused != focused) {
      _mayTriggerCallback(task: () {
        _focused = focused;
      });
      widget.onFocusChange?.call(_focused);
    }
  }

  // Record old states, do `task` if not null, then compare old states with the
  // new states, and trigger callbacks if necessary.
  //
  // The old states are collected from `oldWidget` if it is provided, or the
  // current widget (before doing `task`) otherwise. The new states are always
  // collected from the current widget.
  void _mayTriggerCallback({VoidCallback? task, FocusableActionDetector? oldWidget}) {
    bool shouldShowHoverHighlight(FocusableActionDetector target) {
      return _hovering && target.enabled && _canShowHighlight;
    }

    bool canRequestFocus(FocusableActionDetector target) {
      final NavigationMode mode = MediaQuery.maybeNavigationModeOf(context) ?? NavigationMode.traditional;
      switch (mode) {
        case NavigationMode.traditional:
          return target.enabled;
        case NavigationMode.directional:
          return true;
      }
    }

    bool shouldShowFocusHighlight(FocusableActionDetector target) {
      return _focused && _canShowHighlight && canRequestFocus(target);
    }

    assert(SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks);
    final FocusableActionDetector oldTarget = oldWidget ?? widget;
    final bool didShowHoverHighlight = shouldShowHoverHighlight(oldTarget);
    final bool didShowFocusHighlight = shouldShowFocusHighlight(oldTarget);
    if (task != null) {
      task();
    }
    final bool doShowHoverHighlight = shouldShowHoverHighlight(widget);
    final bool doShowFocusHighlight = shouldShowFocusHighlight(widget);
    if (didShowFocusHighlight != doShowFocusHighlight) {
      widget.onShowFocusHighlight?.call(doShowFocusHighlight);
    }
    if (didShowHoverHighlight != doShowHoverHighlight) {
      widget.onShowHoverHighlight?.call(doShowHoverHighlight);
    }
  }

  @override
  void didUpdateWidget(FocusableActionDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
        _mayTriggerCallback(oldWidget: oldWidget);
      });
    }
  }

  bool get _canRequestFocus {
    final NavigationMode mode = MediaQuery.maybeNavigationModeOf(context) ?? NavigationMode.traditional;
    switch (mode) {
      case NavigationMode.traditional:
        return widget.enabled;
      case NavigationMode.directional:
        return true;
    }
  }

  // This global key is needed to keep only the necessary widgets in the tree
  // while maintaining the subtree's state.
  //
  // See https://github.com/flutter/flutter/issues/64058 for an explanation of
  // why using a global key over keeping the shape of the tree.
  final GlobalKey _mouseRegionKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    Widget child = MouseRegion(
      key: _mouseRegionKey,
      onEnter: _handleMouseEnter,
      onExit: _handleMouseExit,
      cursor: widget.mouseCursor,
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        descendantsAreFocusable: widget.descendantsAreFocusable,
        descendantsAreTraversable: widget.descendantsAreTraversable,
        canRequestFocus: _canRequestFocus,
        onFocusChange: _handleFocusChange,
        includeSemantics: widget.includeFocusSemantics,
        child: widget.child,
      ),
    );
    if (widget.enabled && widget.actions != null && widget.actions!.isNotEmpty) {
      child = Actions(actions: widget.actions!, child: child);
    }
    if (widget.enabled && widget.shortcuts != null && widget.shortcuts!.isNotEmpty) {
      child = Shortcuts(shortcuts: widget.shortcuts!, child: child);
    }
    return child;
  }
}

class VoidCallbackIntent extends Intent {
  const VoidCallbackIntent(this.callback);

  final VoidCallback callback;
}

class VoidCallbackAction extends Action<VoidCallbackIntent> {
  @override
  Object? invoke(VoidCallbackIntent intent) {
    intent.callback();
    return null;
  }
}

class DoNothingIntent extends Intent {
  const factory DoNothingIntent() = DoNothingIntent._;

  // Make DoNothingIntent constructor private so it can't be subclassed.
  const DoNothingIntent._();
}

class DoNothingAndStopPropagationIntent extends Intent {
  const factory DoNothingAndStopPropagationIntent() = DoNothingAndStopPropagationIntent._;

  // Make DoNothingAndStopPropagationIntent constructor private so it can't be subclassed.
  const DoNothingAndStopPropagationIntent._();
}

class DoNothingAction extends Action<Intent> {
  DoNothingAction({bool consumesKey = true}) : _consumesKey = consumesKey;

  @override
  bool consumesKey(Intent intent) => _consumesKey;
  final bool _consumesKey;

  @override
  void invoke(Intent intent) {}
}

class ActivateIntent extends Intent {
  const ActivateIntent();
}

class ButtonActivateIntent extends Intent {
  const ButtonActivateIntent();
}

abstract class ActivateAction extends Action<ActivateIntent> { }

class SelectIntent extends Intent {
  const SelectIntent();
}

abstract class SelectAction extends Action<SelectIntent> { }

class DismissIntent extends Intent {
  const DismissIntent();
}

abstract class DismissAction extends Action<DismissIntent> { }

class PrioritizedIntents extends Intent {
  const PrioritizedIntents({
    required this.orderedIntents,
  });

  final List<Intent> orderedIntents;
}

class PrioritizedAction extends ContextAction<PrioritizedIntents> {
  late Action<dynamic> _selectedAction;
  late Intent _selectedIntent;

  @override
  bool isEnabled(PrioritizedIntents intent, [ BuildContext? context ]) {
    final FocusNode? focus = primaryFocus;
    if  (focus == null || focus.context == null) {
      return false;
    }
    for (final Intent candidateIntent in intent.orderedIntents) {
      final Action<Intent>? candidateAction = Actions.maybeFind<Intent>(
        focus.context!,
        intent: candidateIntent,
      );
      if (candidateAction != null && candidateAction._isEnabled(candidateIntent, context)) {
        _selectedAction = candidateAction;
        _selectedIntent = candidateIntent;
        return true;
      }
    }
    return false;
  }

  @override
  void invoke(PrioritizedIntents intent, [ BuildContext? context ]) {
    _selectedAction._invoke(_selectedIntent, context);
  }
}

mixin _OverridableActionMixin<T extends Intent> on Action<T> {
  // When debugAssertMutuallyRecursive is true, this action will throw an
  // assertion error when the override calls this action's "invoke" method and
  // the override is already being invoked from within the "invoke" method.
  bool debugAssertMutuallyRecursive = false;
  bool debugAssertIsActionEnabledMutuallyRecursive = false;
  bool debugAssertIsEnabledMutuallyRecursive = false;
  bool debugAssertConsumeKeyMutuallyRecursive = false;

  // The default action to invoke if an enabled override Action can't be found
  // using [lookupContext].
  Action<T> get defaultAction;

  // The [BuildContext] used to find the override of this [Action].
  BuildContext get lookupContext;

  // How to invoke [defaultAction], given the caller [fromAction].
  Object? invokeDefaultAction(T intent, Action<T>? fromAction, BuildContext? context);

  Action<T>? getOverrideAction({ bool declareDependency = false }) {
    final Action<T>? override = declareDependency
     ? Actions.maybeFind(lookupContext)
     : Actions._maybeFindWithoutDependingOn(lookupContext);
    assert(!identical(override, this));
    return override;
  }

  @override
  void _updateCallingAction(Action<T>? value) {
    super._updateCallingAction(value);
    defaultAction._updateCallingAction(value);
  }

  Object? _invokeOverride(Action<T> overrideAction, T intent, BuildContext? context) {
    assert(!debugAssertMutuallyRecursive);
    assert(() {
      debugAssertMutuallyRecursive = true;
      return true;
    }());
    overrideAction._updateCallingAction(defaultAction);
    final Object? returnValue = overrideAction._invoke(intent, context);
    overrideAction._updateCallingAction(null);
    assert(() {
      debugAssertMutuallyRecursive = false;
      return true;
    }());
    return returnValue;
  }

  @override
  Object? invoke(T intent, [BuildContext? context]) {
    final Action<T>? overrideAction = getOverrideAction();
    final Object? returnValue = overrideAction == null
      ? invokeDefaultAction(intent, callingAction, context)
      : _invokeOverride(overrideAction, intent, context);
    return returnValue;
  }

  bool isOverrideActionEnabled(Action<T> overrideAction) {
    assert(!debugAssertIsActionEnabledMutuallyRecursive);
    assert(() {
      debugAssertIsActionEnabledMutuallyRecursive = true;
      return true;
    }());
    overrideAction._updateCallingAction(defaultAction);
    final bool isOverrideEnabled = overrideAction.isActionEnabled;
    overrideAction._updateCallingAction(null);
    assert(() {
      debugAssertIsActionEnabledMutuallyRecursive = false;
      return true;
    }());
    return isOverrideEnabled;
  }

  @override
  bool get isActionEnabled {
    final Action<T>? overrideAction = getOverrideAction(declareDependency: true);
    final bool returnValue = overrideAction != null
      ? isOverrideActionEnabled(overrideAction)
      : defaultAction.isActionEnabled;
    return returnValue;
  }

  @override
  bool isEnabled(T intent, [BuildContext? context]) {
    assert(!debugAssertIsEnabledMutuallyRecursive);
    assert(() {
      debugAssertIsEnabledMutuallyRecursive = true;
      return true;
    }());

    final Action<T>? overrideAction = getOverrideAction();
    overrideAction?._updateCallingAction(defaultAction);
    final bool returnValue = (overrideAction ?? defaultAction)._isEnabled(intent, context);
    overrideAction?._updateCallingAction(null);
    assert(() {
      debugAssertIsEnabledMutuallyRecursive = false;
      return true;
    }());
    return returnValue;
  }

  @override
  bool consumesKey(T intent) {
    assert(!debugAssertConsumeKeyMutuallyRecursive);
    assert(() {
      debugAssertConsumeKeyMutuallyRecursive = true;
      return true;
    }());
    final Action<T>? overrideAction = getOverrideAction();
    overrideAction?._updateCallingAction(defaultAction);
    final bool isEnabled = (overrideAction ?? defaultAction).consumesKey(intent);
    overrideAction?._updateCallingAction(null);
    assert(() {
      debugAssertConsumeKeyMutuallyRecursive = false;
      return true;
    }());
    return isEnabled;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Action<T>>('defaultAction', defaultAction));
  }
}

class _OverridableAction<T extends Intent> extends ContextAction<T> with _OverridableActionMixin<T> {
  _OverridableAction({ required this.defaultAction, required this.lookupContext }) ;

  @override
  final Action<T> defaultAction;

  @override
  final BuildContext lookupContext;

  @override
  Object? invokeDefaultAction(T intent, Action<T>? fromAction, BuildContext? context) {
    if (fromAction == null) {
      return defaultAction.invoke(intent);
    } else {
      final Object? returnValue = defaultAction.invoke(intent);
      return returnValue;
    }
  }

  @override
  ContextAction<T> _makeOverridableAction(BuildContext context) {
    return _OverridableAction<T>(defaultAction: defaultAction, lookupContext: context);
  }
}

class _OverridableContextAction<T extends Intent> extends ContextAction<T> with _OverridableActionMixin<T> {
  _OverridableContextAction({ required this.defaultAction, required this.lookupContext });

  @override
  final ContextAction<T> defaultAction;

  @override
  final BuildContext lookupContext;

  @override
  Object? _invokeOverride(Action<T> overrideAction, T intent, BuildContext? context) {
    assert(context != null);
    assert(!debugAssertMutuallyRecursive);
    assert(() {
      debugAssertMutuallyRecursive = true;
      return true;
    }());

    // Wrap the default Action together with the calling context in case
    // overrideAction is not a ContextAction and thus have no access to the
    // calling BuildContext.
    final Action<T> wrappedDefault = _ContextActionToActionAdapter<T>(invokeContext: context!, action: defaultAction);
    overrideAction._updateCallingAction(wrappedDefault);
    final Object? returnValue = overrideAction._invoke(intent, context);
    overrideAction._updateCallingAction(null);

    assert(() {
      debugAssertMutuallyRecursive = false;
      return true;
    }());
    return returnValue;
  }

  @override
  Object? invokeDefaultAction(T intent, Action<T>? fromAction, BuildContext? context) {
    if (fromAction == null) {
      return defaultAction.invoke(intent, context);
    } else {
      final Object? returnValue = defaultAction.invoke(intent, context);
      return returnValue;
    }
  }

  @override
  ContextAction<T> _makeOverridableAction(BuildContext context) {
    return _OverridableContextAction<T>(defaultAction: defaultAction, lookupContext: context);
  }
}

class _ContextActionToActionAdapter<T extends Intent> extends Action<T> {
  _ContextActionToActionAdapter({required this.invokeContext, required this.action});

  final BuildContext invokeContext;
  final ContextAction<T> action;

  @override
  void _updateCallingAction(Action<T>? value) {
    action._updateCallingAction(value);
  }

  @override
  Action<T>? get callingAction => action.callingAction;

  @override
  bool isEnabled(T intent) => action.isEnabled(intent, invokeContext);

  @override
  bool get isActionEnabled => action.isActionEnabled;

  @override
  bool consumesKey(T intent) => action.consumesKey(intent);

  @override
  void addActionListener(ActionListenerCallback listener) {
    super.addActionListener(listener);
    action.addActionListener(listener);
  }

  @override
  void removeActionListener(ActionListenerCallback listener) {
    super.removeActionListener(listener);
    action.removeActionListener(listener);
  }

  @override
  @protected
  void notifyActionListeners() => action.notifyActionListeners();

  @override
  Object? invoke(T intent) => action.invoke(intent, invokeContext);
}