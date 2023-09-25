// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

class SynchronousFuture<T> implements Future<T> {
  SynchronousFuture(this._value);

  final T _value;

  @override
  Stream<T> asStream() {
    final StreamController<T> controller = StreamController<T>();
    controller.add(_value);
    controller.close();
    return controller.stream;
  }

  @override
  Future<T> catchError(Function onError, { bool Function(Object error)? test }) => Completer<T>().future;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, { Function? onError }) {
    final FutureOr<R> result = onValue(_value);
    if (result is Future<R>) {
      return result;
    }
    return SynchronousFuture<R>(result);
  }

  @override
  Future<T> timeout(Duration timeLimit, { FutureOr<T> Function()? onTimeout }) {
    return Future<T>.value(_value).timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<T> whenComplete(FutureOr<dynamic> Function() action) {
    try {
      final FutureOr<dynamic> result = action();
      if (result is Future) {
        return result.then<T>((dynamic value) => _value);
      }
      return this;
    } catch (e, stack) {
      return Future<T>.error(e, stack);
    }
  }
}