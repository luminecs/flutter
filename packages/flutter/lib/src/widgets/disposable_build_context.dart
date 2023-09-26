import 'framework.dart';

@optionalTypeArgs
class DisposableBuildContext<T extends State> {
  DisposableBuildContext(T this._state)
      : assert(_state.mounted,
            'A DisposableBuildContext was given a BuildContext for an Element that is not mounted.');

  T? _state;

  BuildContext? get context {
    assert(_debugValidate());
    if (_state == null) {
      return null;
    }
    return _state!.context;
  }

  bool _debugValidate() {
    assert(
      _state == null || _state!.mounted,
      'A DisposableBuildContext tried to access the BuildContext of a disposed '
      'State object. This can happen when the creator of this '
      'DisposableBuildContext fails to call dispose when it is disposed.',
    );
    return true;
  }

  void dispose() {
    _state = null;
  }
}
