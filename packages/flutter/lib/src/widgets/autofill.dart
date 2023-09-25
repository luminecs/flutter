import 'package:flutter/services.dart';
import 'framework.dart';

export 'package:flutter/services.dart' show AutofillHints;

enum AutofillContextAction {
  commit,

  cancel,
}

class AutofillGroup extends StatefulWidget {
  const AutofillGroup({
    super.key,
    required this.child,
    this.onDisposeAction = AutofillContextAction.commit,
  });

  static AutofillGroupState? maybeOf(BuildContext context) {
    final _AutofillScope? scope = context.dependOnInheritedWidgetOfExactType<_AutofillScope>();
    return scope?._scope;
  }

  static AutofillGroupState of(BuildContext context) {
    final AutofillGroupState? groupState = maybeOf(context);
    assert(() {
      if (groupState == null) {
        throw FlutterError(
          'AutofillGroup.of() was called with a context that does not contain an '
          'AutofillGroup widget.\n'
          'No AutofillGroup widget ancestor could be found starting from the '
          'context that was passed to AutofillGroup.of(). This can happen '
          'because you are using a widget that looks for an AutofillGroup '
          'ancestor, but no such ancestor exists.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return groupState!;
  }

  final Widget child;

  final AutofillContextAction onDisposeAction;

  @override
  AutofillGroupState createState() => AutofillGroupState();
}

class AutofillGroupState extends State<AutofillGroup> with AutofillScopeMixin {
  final Map<String, AutofillClient> _clients = <String, AutofillClient>{};

  // Whether this AutofillGroup widget is the topmost AutofillGroup (i.e., it
  // has no AutofillGroup ancestor). Each topmost AutofillGroup runs its
  // `AutofillGroup.onDisposeAction` when it gets disposed.
  bool _isTopmostAutofillGroup = false;

  @override
  AutofillClient? getAutofillClient(String autofillId) => _clients[autofillId];

  @override
  Iterable<AutofillClient> get autofillClients {
    return _clients.values
      .where((AutofillClient client) => client.textInputConfiguration.autofillConfiguration.enabled);
  }

  void register(AutofillClient client) {
    _clients.putIfAbsent(client.autofillId, () => client);
  }

  void unregister(String autofillId) {
    assert(_clients.containsKey(autofillId));
    _clients.remove(autofillId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isTopmostAutofillGroup = AutofillGroup.maybeOf(context) == null;
  }

  @override
  Widget build(BuildContext context) {
    return _AutofillScope(
      autofillScopeState: this,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    super.dispose();

    if (!_isTopmostAutofillGroup) {
      return;
    }
    switch (widget.onDisposeAction) {
      case AutofillContextAction.cancel:
        TextInput.finishAutofillContext(shouldSave: false);
      case AutofillContextAction.commit:
        TextInput.finishAutofillContext();
    }
  }
}

class _AutofillScope extends InheritedWidget {
  const _AutofillScope({
    required super.child,
    AutofillGroupState? autofillScopeState,
  }) : _scope = autofillScopeState;

  final AutofillGroupState? _scope;

  AutofillGroup get client => _scope!.widget;

  @override
  bool updateShouldNotify(_AutofillScope old) => _scope != old._scope;
}