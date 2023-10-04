import 'arena.dart';
import 'binding.dart';

export 'arena.dart' show GestureArenaEntry, GestureArenaMember;

class _CombiningGestureArenaEntry implements GestureArenaEntry {
  _CombiningGestureArenaEntry(this._combiner, this._member);

  final _CombiningGestureArenaMember _combiner;
  final GestureArenaMember _member;

  @override
  void resolve(GestureDisposition disposition) {
    _combiner._resolve(_member, disposition);
  }
}

class _CombiningGestureArenaMember extends GestureArenaMember {
  _CombiningGestureArenaMember(this._owner, this._pointer);

  final GestureArenaTeam _owner;
  final List<GestureArenaMember> _members = <GestureArenaMember>[];
  final int _pointer;

  bool _resolved = false;
  GestureArenaMember? _winner;
  GestureArenaEntry? _entry;

  @override
  void acceptGesture(int pointer) {
    assert(_pointer == pointer);
    assert(_winner != null || _members.isNotEmpty);
    _close();
    _winner ??= _owner.captain ?? _members[0];
    for (final GestureArenaMember member in _members) {
      if (member != _winner) {
        member.rejectGesture(pointer);
      }
    }
    _winner!.acceptGesture(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    assert(_pointer == pointer);
    _close();
    for (final GestureArenaMember member in _members) {
      member.rejectGesture(pointer);
    }
  }

  void _close() {
    assert(!_resolved);
    _resolved = true;
    final _CombiningGestureArenaMember? combiner =
        _owner._combiners.remove(_pointer);
    assert(combiner == this);
  }

  GestureArenaEntry _add(int pointer, GestureArenaMember member) {
    assert(!_resolved);
    assert(_pointer == pointer);
    _members.add(member);
    _entry ??= GestureBinding.instance.gestureArena.add(pointer, this);
    return _CombiningGestureArenaEntry(this, member);
  }

  void _resolve(GestureArenaMember member, GestureDisposition disposition) {
    if (_resolved) {
      return;
    }
    if (disposition == GestureDisposition.rejected) {
      _members.remove(member);
      member.rejectGesture(_pointer);
      if (_members.isEmpty) {
        _entry!.resolve(disposition);
      }
    } else {
      assert(disposition == GestureDisposition.accepted);
      _winner ??= _owner.captain ?? member;
      _entry!.resolve(disposition);
    }
  }
}

class GestureArenaTeam {
  final Map<int, _CombiningGestureArenaMember> _combiners =
      <int, _CombiningGestureArenaMember>{};

  GestureArenaMember? captain;

  GestureArenaEntry add(int pointer, GestureArenaMember member) {
    final _CombiningGestureArenaMember combiner = _combiners.putIfAbsent(
      pointer,
      () => _CombiningGestureArenaMember(this, pointer),
    );
    return combiner._add(pointer, member);
  }
}
