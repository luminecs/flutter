// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'events.dart';

export 'dart:ui' show Offset;

export 'package:vector_math/vector_math_64.dart' show Matrix4;

export 'events.dart' show PointerEvent;

abstract interface class HitTestable {
  @Deprecated(
    'Use hitTestInView and specify the view to hit test. '
    'This feature was deprecated after v3.11.0-20.0.pre.',
  )
  void hitTest(HitTestResult result, Offset position);

  void hitTestInView(HitTestResult result, Offset position, int viewId);
}

abstract interface class HitTestDispatcher {
  void dispatchEvent(PointerEvent event, HitTestResult result);
}

abstract interface class HitTestTarget {
  void handleEvent(PointerEvent event, HitTestEntry<HitTestTarget> entry);
}

@optionalTypeArgs
class HitTestEntry<T extends HitTestTarget> {
  HitTestEntry(this.target);

  final T target;

  @override
  String toString() => '${describeIdentity(this)}($target)';

  Matrix4? get transform => _transform;
  Matrix4? _transform;
}

// A type of data that can be applied to a matrix by left-multiplication.
@immutable
abstract class _TransformPart {
  const _TransformPart();

  // Apply this transform part to `rhs` from the left.
  //
  // This should work as if this transform part is first converted to a matrix
  // and then left-multiplied to `rhs`.
  //
  // For example, if this transform part is a vector `v1`, whose corresponding
  // matrix is `m1 = Matrix4.translation(v1)`, then the result of
  // `_VectorTransformPart(v1).multiply(rhs)` should equal to `m1 * rhs`.
  Matrix4 multiply(Matrix4 rhs);
}

class _MatrixTransformPart extends _TransformPart {
  const _MatrixTransformPart(this.matrix);

  final Matrix4 matrix;

  @override
  Matrix4 multiply(Matrix4 rhs) {
    return matrix.multiplied(rhs);
  }
}

class _OffsetTransformPart extends _TransformPart {
  const _OffsetTransformPart(this.offset);

  final Offset offset;

  @override
  Matrix4 multiply(Matrix4 rhs) {
    return rhs.clone()..leftTranslate(offset.dx, offset.dy);
  }
}

class HitTestResult {
  HitTestResult()
     : _path = <HitTestEntry>[],
       _transforms = <Matrix4>[Matrix4.identity()],
       _localTransforms = <_TransformPart>[];

  HitTestResult.wrap(HitTestResult result)
     : _path = result._path,
       _transforms = result._transforms,
       _localTransforms = result._localTransforms;

  Iterable<HitTestEntry> get path => _path;
  final List<HitTestEntry> _path;

  // A stack of transform parts.
  //
  // The transform part stack leading from global to the current object is stored
  // in 2 parts:
  //
  //  * `_transforms` are globalized matrices, meaning they have been multiplied
  //    by the ancestors and are thus relative to the global coordinate space.
  //  * `_localTransforms` are local transform parts, which are relative to the
  //    parent's coordinate space.
  //
  // When new transform parts are added they're appended to `_localTransforms`,
  // and are converted to global ones and moved to `_transforms` only when used.
  final List<Matrix4> _transforms;
  final List<_TransformPart> _localTransforms;

  // Globalize all transform parts in `_localTransforms` and move them to
  // _transforms.
  void _globalizeTransforms() {
    if (_localTransforms.isEmpty) {
      return;
    }
    Matrix4 last = _transforms.last;
    for (final _TransformPart part in _localTransforms) {
      last = part.multiply(last);
      _transforms.add(last);
    }
    _localTransforms.clear();
  }

  Matrix4 get _lastTransform {
    _globalizeTransforms();
    assert(_localTransforms.isEmpty);
    return _transforms.last;
  }

  void add(HitTestEntry entry) {
    assert(entry._transform == null);
    entry._transform = _lastTransform;
    _path.add(entry);
  }

  @protected
  void pushTransform(Matrix4 transform) {
    assert(
      _debugVectorMoreOrLessEquals(transform.getRow(2), Vector4(0, 0, 1, 0)) &&
      _debugVectorMoreOrLessEquals(transform.getColumn(2), Vector4(0, 0, 1, 0)),
      'The third row and third column of a transform matrix for pointer '
      'events must be Vector4(0, 0, 1, 0) to ensure that a transformed '
      'point is directly under the pointing device. Did you forget to run the paint '
      'matrix through PointerEvent.removePerspectiveTransform? '
      'The provided matrix is:\n$transform',
    );
    _localTransforms.add(_MatrixTransformPart(transform));
  }

  @protected
  void pushOffset(Offset offset) {
    _localTransforms.add(_OffsetTransformPart(offset));
  }

  @protected
  void popTransform() {
    if (_localTransforms.isNotEmpty) {
      _localTransforms.removeLast();
    } else {
      _transforms.removeLast();
    }
    assert(_transforms.isNotEmpty);
  }

  bool _debugVectorMoreOrLessEquals(Vector4 a, Vector4 b, { double epsilon = precisionErrorTolerance }) {
    bool result = true;
    assert(() {
      final Vector4 difference = a - b;
      result = difference.storage.every((double component) => component.abs() < epsilon);
      return true;
    }());
    return result;
  }

  @override
  String toString() => 'HitTestResult(${_path.isEmpty ? "<empty path>" : _path.join(", ")})';
}