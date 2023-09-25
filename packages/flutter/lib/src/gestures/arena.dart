// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'dart:async';

import 'package:flutter/foundation.dart';

import 'debug.dart';

enum GestureDisposition {
  accepted,

  rejected,
}

abstract class GestureArenaMember {
  void acceptGesture(int pointer);

  void rejectGesture(int pointer);
}

class GestureArenaEntry {
  GestureArenaEntry._(this._arena, this._pointer, this._member);

  final GestureArenaManager _arena;
  final int _pointer;
  final GestureArenaMember _member;

  void resolve(GestureDisposition disposition) {
    _arena._resolve(_pointer, _member, disposition);
  }
}

class _GestureArena {
  final List<GestureArenaMember> members = <GestureArenaMember>[];
  bool isOpen = true;
  bool isHeld = false;
  bool hasPendingSweep = false;

  GestureArenaMember? eagerWinner;

  void add(GestureArenaMember member) {
    assert(isOpen);
    members.add(member);
  }

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    if (members.isEmpty) {
      buffer.write('<empty>');
    } else {
      buffer.write(members.map<String>((GestureArenaMember member) {
        if (member == eagerWinner) {
          return '$member (eager winner)';
        }
        return '$member';
      }).join(', '));
    }
    if (isOpen) {
      buffer.write(' [open]');
    }
    if (isHeld) {
      buffer.write(' [held]');
    }
    if (hasPendingSweep) {
      buffer.write(' [hasPendingSweep]');
    }
    return buffer.toString();
  }
}

class GestureArenaManager {
  final Map<int, _GestureArena> _arenas = <int, _GestureArena>{};

  GestureArenaEntry add(int pointer, GestureArenaMember member) {
    final _GestureArena state = _arenas.putIfAbsent(pointer, () {
      assert(_debugLogDiagnostic(pointer, '★ Opening new gesture arena.'));
      return _GestureArena();
    });
    state.add(member);
    assert(_debugLogDiagnostic(pointer, 'Adding: $member'));
    return GestureArenaEntry._(this, pointer, member);
  }

  void close(int pointer) {
    final _GestureArena? state = _arenas[pointer];
    if (state == null) {
      return; // This arena either never existed or has been resolved.
    }
    state.isOpen = false;
    assert(_debugLogDiagnostic(pointer, 'Closing', state));
    _tryToResolveArena(pointer, state);
  }

  void sweep(int pointer) {
    final _GestureArena? state = _arenas[pointer];
    if (state == null) {
      return; // This arena either never existed or has been resolved.
    }
    assert(!state.isOpen);
    if (state.isHeld) {
      state.hasPendingSweep = true;
      assert(_debugLogDiagnostic(pointer, 'Delaying sweep', state));
      return; // This arena is being held for a long-lived member.
    }
    assert(_debugLogDiagnostic(pointer, 'Sweeping', state));
    _arenas.remove(pointer);
    if (state.members.isNotEmpty) {
      // First member wins.
      assert(_debugLogDiagnostic(pointer, 'Winner: ${state.members.first}'));
      state.members.first.acceptGesture(pointer);
      // Give all the other members the bad news.
      for (int i = 1; i < state.members.length; i++) {
        state.members[i].rejectGesture(pointer);
      }
    }
  }

  void hold(int pointer) {
    final _GestureArena? state = _arenas[pointer];
    if (state == null) {
      return; // This arena either never existed or has been resolved.
    }
    state.isHeld = true;
    assert(_debugLogDiagnostic(pointer, 'Holding', state));
  }

  void release(int pointer) {
    final _GestureArena? state = _arenas[pointer];
    if (state == null) {
      return; // This arena either never existed or has been resolved.
    }
    state.isHeld = false;
    assert(_debugLogDiagnostic(pointer, 'Releasing', state));
    if (state.hasPendingSweep) {
      sweep(pointer);
    }
  }

  void _resolve(int pointer, GestureArenaMember member, GestureDisposition disposition) {
    final _GestureArena? state = _arenas[pointer];
    if (state == null) {
      return; // This arena has already resolved.
    }
    assert(_debugLogDiagnostic(pointer, '${ disposition == GestureDisposition.accepted ? "Accepting" : "Rejecting" }: $member'));
    assert(state.members.contains(member));
    if (disposition == GestureDisposition.rejected) {
      state.members.remove(member);
      member.rejectGesture(pointer);
      if (!state.isOpen) {
        _tryToResolveArena(pointer, state);
      }
    } else {
      assert(disposition == GestureDisposition.accepted);
      if (state.isOpen) {
        state.eagerWinner ??= member;
      } else {
        assert(_debugLogDiagnostic(pointer, 'Self-declared winner: $member'));
        _resolveInFavorOf(pointer, state, member);
      }
    }
  }

  void _tryToResolveArena(int pointer, _GestureArena state) {
    assert(_arenas[pointer] == state);
    assert(!state.isOpen);
    if (state.members.length == 1) {
      scheduleMicrotask(() => _resolveByDefault(pointer, state));
    } else if (state.members.isEmpty) {
      _arenas.remove(pointer);
      assert(_debugLogDiagnostic(pointer, 'Arena empty.'));
    } else if (state.eagerWinner != null) {
      assert(_debugLogDiagnostic(pointer, 'Eager winner: ${state.eagerWinner}'));
      _resolveInFavorOf(pointer, state, state.eagerWinner!);
    }
  }

  void _resolveByDefault(int pointer, _GestureArena state) {
    if (!_arenas.containsKey(pointer)) {
      return; // This arena has already resolved.
    }
    assert(_arenas[pointer] == state);
    assert(!state.isOpen);
    final List<GestureArenaMember> members = state.members;
    assert(members.length == 1);
    _arenas.remove(pointer);
    assert(_debugLogDiagnostic(pointer, 'Default winner: ${state.members.first}'));
    state.members.first.acceptGesture(pointer);
  }

  void _resolveInFavorOf(int pointer, _GestureArena state, GestureArenaMember member) {
    assert(state == _arenas[pointer]);
    assert(state.eagerWinner == null || state.eagerWinner == member);
    assert(!state.isOpen);
    _arenas.remove(pointer);
    for (final GestureArenaMember rejectedMember in state.members) {
      if (rejectedMember != member) {
        rejectedMember.rejectGesture(pointer);
      }
    }
    member.acceptGesture(pointer);
  }

  bool _debugLogDiagnostic(int pointer, String message, [ _GestureArena? state ]) {
    assert(() {
      if (debugPrintGestureArenaDiagnostics) {
        final int? count = state?.members.length;
        final String s = count != 1 ? 's' : '';
        debugPrint('Gesture arena ${pointer.toString().padRight(4)} ❙ $message${ count != null ? " with $count member$s." : ""}');
      }
      return true;
    }());
    return true;
  }
}