import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

class RecordedInvocation {
  const RecordedInvocation(this.invocation, {required this.stack});

  final Invocation invocation;

  final StackTrace stack;

  @override
  String toString() => _describeInvocation(invocation);

  String stackToString({String indent = ''}) {
    return indent +
        FlutterError.defaultStackFilter(
          stack.toString().trimRight().split('\n'),
        ).join('\n$indent');
  }
}

// Examples can assume:
// late WidgetTester tester;

class TestRecordingCanvas implements Canvas {
  final List<RecordedInvocation> invocations = <RecordedInvocation>[];

  int _saveCount = 0;

  @override
  int getSaveCount() => _saveCount;

  @override
  void save() {
    _saveCount += 1;
    invocations
        .add(RecordedInvocation(_MethodCall(#save), stack: StackTrace.current));
  }

  @override
  void saveLayer(Rect? bounds, Paint paint) {
    _saveCount += 1;
    invocations.add(RecordedInvocation(
        _MethodCall(#saveLayer, <dynamic>[bounds, paint]),
        stack: StackTrace.current));
  }

  @override
  void restore() {
    _saveCount -= 1;
    assert(_saveCount >= 0);
    invocations.add(
        RecordedInvocation(_MethodCall(#restore), stack: StackTrace.current));
  }

  @override
  void noSuchMethod(Invocation invocation) {
    invocations.add(RecordedInvocation(invocation, stack: StackTrace.current));
  }
}

class TestRecordingPaintingContext extends ClipContext
    implements PaintingContext {
  TestRecordingPaintingContext(this.canvas);

  final List<OpacityLayer> _createdLayers = <OpacityLayer>[];

  @override
  final Canvas canvas;

  @override
  void paintChild(RenderObject child, Offset offset) {
    child.paint(this, offset);
  }

  @override
  ClipRectLayer? pushClipRect(
    bool needsCompositing,
    Offset offset,
    Rect clipRect,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.hardEdge,
    ClipRectLayer? oldLayer,
  }) {
    clipRectAndPaint(clipRect.shift(offset), clipBehavior,
        clipRect.shift(offset), () => painter(this, offset));
    return null;
  }

  @override
  ClipRRectLayer? pushClipRRect(
    bool needsCompositing,
    Offset offset,
    Rect bounds,
    RRect clipRRect,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.antiAlias,
    ClipRRectLayer? oldLayer,
  }) {
    clipRRectAndPaint(clipRRect.shift(offset), clipBehavior,
        bounds.shift(offset), () => painter(this, offset));
    return null;
  }

  @override
  ClipPathLayer? pushClipPath(
    bool needsCompositing,
    Offset offset,
    Rect bounds,
    Path clipPath,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.antiAlias,
    ClipPathLayer? oldLayer,
  }) {
    clipPathAndPaint(clipPath.shift(offset), clipBehavior, bounds.shift(offset),
        () => painter(this, offset));
    return null;
  }

  @override
  TransformLayer? pushTransform(
    bool needsCompositing,
    Offset offset,
    Matrix4 transform,
    PaintingContextCallback painter, {
    TransformLayer? oldLayer,
  }) {
    canvas.save();
    canvas.transform(transform.storage);
    painter(this, offset);
    canvas.restore();
    return null;
  }

  @override
  OpacityLayer pushOpacity(
    Offset offset,
    int alpha,
    PaintingContextCallback painter, {
    OpacityLayer? oldLayer,
  }) {
    canvas.saveLayer(null, Paint()); // TODO(ianh): Expose the alpha somewhere.
    painter(this, offset);
    canvas.restore();
    final OpacityLayer layer = OpacityLayer();
    _createdLayers.add(layer);
    return layer;
  }

  @mustCallSuper
  void dispose() {
    for (final OpacityLayer layer in _createdLayers) {
      layer.dispose();
    }
    _createdLayers.clear();
  }

  @override
  void pushLayer(
    Layer childLayer,
    PaintingContextCallback painter,
    Offset offset, {
    Rect? childPaintBounds,
  }) {
    painter(this, offset);
  }

  @override
  VoidCallback addCompositionCallback(CompositionCallback callback) => () {};

  @override
  void noSuchMethod(Invocation invocation) {}
}

class _MethodCall implements Invocation {
  _MethodCall(this._name, [this._arguments = const <dynamic>[]]);
  final Symbol _name;
  final List<dynamic> _arguments;
  @override
  bool get isAccessor => false;
  @override
  bool get isGetter => false;
  @override
  bool get isMethod => true;
  @override
  bool get isSetter => false;
  @override
  Symbol get memberName => _name;
  @override
  Map<Symbol, dynamic> get namedArguments => <Symbol, dynamic>{};
  @override
  List<dynamic> get positionalArguments => _arguments;
  @override
  List<Type> get typeArguments => const <Type>[];
}

String _valueName(Object? value) {
  if (value is double) {
    return value.toStringAsFixed(1);
  }
  return value.toString();
}

// Workaround for https://github.com/dart-lang/sdk/issues/28372
String _symbolName(Symbol symbol) {
  // WARNING: Assumes a fixed format for Symbol.toString which is *not*
  // guaranteed anywhere.
  final String s = '$symbol';
  return s.substring(8, s.length - 2);
}

// Workaround for https://github.com/dart-lang/sdk/issues/28373
String _describeInvocation(Invocation call) {
  final StringBuffer buffer = StringBuffer();
  buffer.write(_symbolName(call.memberName));
  if (call.isSetter) {
    buffer.write(call.positionalArguments[0].toString());
  } else if (call.isMethod) {
    buffer.write('(');
    buffer.writeAll(call.positionalArguments.map<String>(_valueName), ', ');
    String separator = call.positionalArguments.isEmpty ? '' : ', ';
    call.namedArguments.forEach((Symbol name, Object? value) {
      buffer.write(separator);
      buffer.write(_symbolName(name));
      buffer.write(': ');
      buffer.write(_valueName(value));
      separator = ', ';
    });
    buffer.write(')');
  }
  return buffer.toString();
}
