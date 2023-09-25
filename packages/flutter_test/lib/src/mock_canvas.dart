
import 'dart:ui' as ui show Image, Paragraph;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:matcher/expect.dart';

import 'finders.dart';
import 'recording_canvas.dart';
import 'test_async_utils.dart';

// Examples can assume:
// late RenderObject myRenderObject;
// late Symbol methodName;

PaintPattern get paints => _TestRecordingCanvasPatternMatcher();

Matcher get paintsNothing => _TestRecordingCanvasPaintsNothingMatcher();

Matcher get paintsAssertion => _TestRecordingCanvasPaintsAssertionMatcher();

Matcher paintsExactlyCountTimes(Symbol methodName, int count) {
  return _TestRecordingCanvasPaintsCountMatcher(methodName, count);
}

typedef PaintPatternPredicate = bool Function(Symbol methodName, List<dynamic> arguments);

typedef _ContextPainterFunction = void Function(PaintingContext context, Offset offset);

typedef _CanvasPainterFunction = void Function(Canvas canvas);

abstract class PaintPattern {
  void transform({ dynamic matrix4 });

  void translate({ double? x, double? y });

  void scale({ double? x, double? y });

  void rotate({ double? angle });

  void save();

  void restore();

  void saveRestore();

  void clipRect({ Rect? rect });

  void clipPath({ Matcher? pathMatcher });

  void rect({ Rect? rect, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style });

  void clipRRect({ RRect? rrect });

  void rrect({ RRect? rrect, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style });

  void drrect({ RRect? outer, RRect? inner, Color? color, double strokeWidth, bool hasMaskFilter, PaintingStyle style });

  void circle({ double? x, double? y, double? radius, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style });

  void path({ Iterable<Offset>? includes, Iterable<Offset>? excludes, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style });

  void line({ Offset? p1, Offset? p2, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style });

  void arc({ Rect? rect, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style, StrokeCap? strokeCap });

  void paragraph({ ui.Paragraph? paragraph, dynamic offset });

  void shadow({ Iterable<Offset>? includes, Iterable<Offset>? excludes, Color? color, double? elevation, bool? transparentOccluder });

  void image({ ui.Image? image, double? x, double? y, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style });

  void drawImageRect({ ui.Image? image, Rect? source, Rect? destination, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style });

  void something(PaintPatternPredicate predicate);

  void everything(PaintPatternPredicate predicate);
}

Matcher isPathThat({
  Iterable<Offset> includes = const <Offset>[],
  Iterable<Offset> excludes = const <Offset>[],
}) {
  return _PathMatcher(includes.toList(), excludes.toList());
}

class _PathMatcher extends Matcher {
  _PathMatcher(this.includes, this.excludes);

  List<Offset> includes;
  List<Offset> excludes;

  @override
  bool matches(Object? object, Map<dynamic, dynamic> matchState) {
    if (object is! Path) {
      matchState[this] = 'The given object ($object) was not a Path.';
      return false;
    }
    final Path path = object;
    final List<String> errors = <String>[
      for (final Offset offset in includes)
        if (!path.contains(offset))
          'Offset $offset should be inside the path, but is not.',
      for (final Offset offset in excludes)
        if (path.contains(offset))
          'Offset $offset should be outside the path, but is not.',
    ];
    if (errors.isEmpty) {
      return true;
    }
    matchState[this] = 'Not all the given points were inside or outside the '
      'path as expected:\n  ${errors.join("\n  ")}';
    return false;
  }

  @override
  Description describe(Description description) {
    String points(List<Offset> list) {
      final int count = list.length;
      if (count == 1) {
        return 'one particular point';
      }
      return '$count particular points';
    }
    return description.add('A Path that contains ${points(includes)} but does '
      'not contain ${points(excludes)}.');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description description,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    return description.add(matchState[this] as String);
  }
}

class _MismatchedCall extends Error {
  _MismatchedCall(this.message, this.callIntroduction, this.call);
  final String message;
  final String callIntroduction;
  final RecordedInvocation call;
}

bool _evaluatePainter(Object? object, Canvas canvas, PaintingContext context) {
  if (object is _ContextPainterFunction) {
    final _ContextPainterFunction function = object;
    function(context, Offset.zero);
  } else if (object is _CanvasPainterFunction) {
    final _CanvasPainterFunction function = object;
    function(canvas);
  } else {
    if (object is Finder) {
      TestAsyncUtils.guardSync();
      final Finder finder = object;
      object = finder.evaluate().single.renderObject;
    }
    if (object is RenderObject) {
      final RenderObject renderObject = object;
      renderObject.paint(context, Offset.zero);
    } else {
      return false;
    }
  }
  return true;
}

abstract class _TestRecordingCanvasMatcher extends Matcher {
  @override
  bool matches(Object? object, Map<dynamic, dynamic> matchState) {
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    final TestRecordingPaintingContext context = TestRecordingPaintingContext(canvas);
    final StringBuffer description = StringBuffer();
    String prefixMessage = 'unexpectedly failed.';
    bool result = false;
    try {
      if (!_evaluatePainter(object, canvas, context)) {
        matchState[this] = 'was not one of the supported objects for the '
          '"paints" matcher.';
        return false;
      }
      result = _evaluatePredicates(canvas.invocations, description);
      if (!result) {
        prefixMessage = 'did not match the pattern.';
      }
    } catch (error, stack) {
      prefixMessage = 'threw the following exception:';
      description.writeln(error.toString());
      description.write(stack.toString());
      result = false;
    }
    if (!result) {
      if (canvas.invocations.isNotEmpty) {
        description.write('The complete display list was:');
        for (final RecordedInvocation call in canvas.invocations) {
          description.write('\n  * $call');
        }
      }
      matchState[this] = '$prefixMessage\n$description';
    }
    return result;
  }

  bool _evaluatePredicates(Iterable<RecordedInvocation> calls, StringBuffer description);

  @override
  Description describeMismatch(
    dynamic item,
    Description description,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    return description.add(matchState[this] as String);
  }
}

class _TestRecordingCanvasPaintsCountMatcher extends _TestRecordingCanvasMatcher {
  _TestRecordingCanvasPaintsCountMatcher(Symbol methodName, int count)
    : _methodName = methodName,
      _count = count;

  final Symbol _methodName;
  final int _count;

  @override
  Description describe(Description description) {
    return description.add('Object or closure painting $_methodName exactly $_count times');
  }

  @override
  bool _evaluatePredicates(Iterable<RecordedInvocation> calls, StringBuffer description) {
    int count = 0;
    for (final RecordedInvocation call in calls) {
      if (call.invocation.isMethod && call.invocation.memberName == _methodName) {
        count++;
      }
    }
    if (count != _count) {
      description.write('It painted $_methodName $count times instead of $_count times.');
    }
    return count == _count;
  }
}

class _TestRecordingCanvasPaintsNothingMatcher extends _TestRecordingCanvasMatcher {
  @override
  Description describe(Description description) {
    return description.add('An object or closure that paints nothing.');
  }

  @override
  bool _evaluatePredicates(Iterable<RecordedInvocation> calls, StringBuffer description) {
    final Iterable<RecordedInvocation> paintingCalls = _filterCanvasCalls(calls);
    if (paintingCalls.isEmpty) {
      return true;
    }
    description.write(
      'painted something, the first call having the following stack:\n'
      '${paintingCalls.first.stackToString(indent: "  ")}\n',
    );
    return false;
  }

  static const List<Symbol> _nonPaintingOperations = <Symbol> [
    #save,
    #restore,
  ];

  // Filters out canvas calls that are not painting anything.
  static Iterable<RecordedInvocation> _filterCanvasCalls(Iterable<RecordedInvocation> canvasCalls) {
    return canvasCalls.where((RecordedInvocation canvasCall) =>
      !_nonPaintingOperations.contains(canvasCall.invocation.memberName),
    );
  }
}

class _TestRecordingCanvasPaintsAssertionMatcher extends Matcher {
  @override
  bool matches(Object? object, Map<dynamic, dynamic> matchState) {
    final TestRecordingCanvas canvas = TestRecordingCanvas();
    final TestRecordingPaintingContext context = TestRecordingPaintingContext(canvas);
    final StringBuffer description = StringBuffer();
    String prefixMessage = 'unexpectedly failed.';
    bool result = false;
    try {
      if (!_evaluatePainter(object, canvas, context)) {
        matchState[this] = 'was not one of the supported objects for the '
          '"paints" matcher.';
        return false;
      }
      prefixMessage = 'did not assert.';
    } on AssertionError {
      result = true;
    } catch (error, stack) {
      prefixMessage = 'threw the following exception:';
      description.writeln(error.toString());
      description.write(stack.toString());
      result = false;
    }
    if (!result) {
      if (canvas.invocations.isNotEmpty) {
        description.write('The complete display list was:');
        for (final RecordedInvocation call in canvas.invocations) {
          description.write('\n  * $call');
        }
      }
      matchState[this] = '$prefixMessage\n$description';
    }
    return result;
  }

  @override
  Description describe(Description description) {
    return description.add('An object or closure that asserts when it tries to paint.');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description description,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    return description.add(matchState[this] as String);
  }
}

class _TestRecordingCanvasPatternMatcher extends _TestRecordingCanvasMatcher implements PaintPattern {
  final List<_PaintPredicate> _predicates = <_PaintPredicate>[];

  @override
  void transform({ dynamic matrix4 }) {
    _predicates.add(_FunctionPaintPredicate(#transform, <dynamic>[matrix4]));
  }

  @override
  void translate({ double? x, double? y }) {
    _predicates.add(_FunctionPaintPredicate(#translate, <dynamic>[x, y]));
  }

  @override
  void scale({ double? x, double? y }) {
    _predicates.add(_FunctionPaintPredicate(#scale, <dynamic>[x, y]));
  }

  @override
  void rotate({ double? angle }) {
    _predicates.add(_FunctionPaintPredicate(#rotate, <dynamic>[angle]));
  }

  @override
  void save() {
    _predicates.add(_FunctionPaintPredicate(#save, <dynamic>[]));
  }

  @override
  void restore() {
    _predicates.add(_FunctionPaintPredicate(#restore, <dynamic>[]));
  }

  @override
  void saveRestore() {
    _predicates.add(_SaveRestorePairPaintPredicate());
  }

  @override
  void clipRect({ Rect? rect }) {
    _predicates.add(_FunctionPaintPredicate(#clipRect, <dynamic>[rect]));
  }

  @override
  void clipPath({ Matcher? pathMatcher }) {
    _predicates.add(_FunctionPaintPredicate(#clipPath, <dynamic>[pathMatcher]));
  }

  @override
  void rect({ Rect? rect, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style }) {
    _predicates.add(_RectPaintPredicate(rect: rect, color: color, strokeWidth: strokeWidth, hasMaskFilter: hasMaskFilter, style: style));
  }

  @override
  void clipRRect({ RRect? rrect }) {
    _predicates.add(_FunctionPaintPredicate(#clipRRect, <dynamic>[rrect]));
  }

  @override
  void rrect({ RRect? rrect, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style }) {
    _predicates.add(_RRectPaintPredicate(rrect: rrect, color: color, strokeWidth: strokeWidth, hasMaskFilter: hasMaskFilter, style: style));
  }

  @override
  void drrect({ RRect? outer, RRect? inner, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style }) {
    _predicates.add(_DRRectPaintPredicate(outer: outer, inner: inner, color: color, strokeWidth: strokeWidth, hasMaskFilter: hasMaskFilter, style: style));
  }

  @override
  void circle({ double? x, double? y, double? radius, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style }) {
    _predicates.add(_CirclePaintPredicate(x: x, y: y, radius: radius, color: color, strokeWidth: strokeWidth, hasMaskFilter: hasMaskFilter, style: style));
  }

  @override
  void path({ Iterable<Offset>? includes, Iterable<Offset>? excludes, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style }) {
    _predicates.add(_PathPaintPredicate(includes: includes, excludes: excludes, color: color, strokeWidth: strokeWidth, hasMaskFilter: hasMaskFilter, style: style));
  }

  @override
  void line({ Offset? p1, Offset? p2, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style }) {
    _predicates.add(_LinePaintPredicate(p1: p1, p2: p2, color: color, strokeWidth: strokeWidth, hasMaskFilter: hasMaskFilter, style: style));
  }

  @override
  void arc({ Rect? rect, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style, StrokeCap? strokeCap }) {
    _predicates.add(_ArcPaintPredicate(rect: rect, color: color, strokeWidth: strokeWidth, hasMaskFilter: hasMaskFilter, style: style, strokeCap: strokeCap));
  }

  @override
  void paragraph({ ui.Paragraph? paragraph, dynamic offset }) {
    _predicates.add(_FunctionPaintPredicate(#drawParagraph, <dynamic>[paragraph, offset]));
  }

  @override
  void shadow({ Iterable<Offset>? includes, Iterable<Offset>? excludes, Color? color, double? elevation, bool? transparentOccluder }) {
    _predicates.add(_ShadowPredicate(includes: includes, excludes: excludes, color: color, elevation: elevation, transparentOccluder: transparentOccluder));
  }

  @override
  void image({ ui.Image? image, double? x, double? y, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style }) {
    _predicates.add(_DrawImagePaintPredicate(image: image, x: x, y: y, color: color, strokeWidth: strokeWidth, hasMaskFilter: hasMaskFilter, style: style));
  }

  @override
  void drawImageRect({ ui.Image? image, Rect? source, Rect? destination, Color? color, double? strokeWidth, bool? hasMaskFilter, PaintingStyle? style }) {
    _predicates.add(_DrawImageRectPaintPredicate(image: image, source: source, destination: destination, color: color, strokeWidth: strokeWidth, hasMaskFilter: hasMaskFilter, style: style));
  }

  @override
  void something(PaintPatternPredicate predicate) {
    _predicates.add(_SomethingPaintPredicate(predicate));
  }

  @override
  void everything(PaintPatternPredicate predicate) {
    _predicates.add(_EverythingPaintPredicate(predicate));
  }

  @override
  Description describe(Description description) {
    if (_predicates.isEmpty) {
      return description.add('An object or closure and a paint pattern.');
    }
    description.add('Object or closure painting:\n');
    return description.addAll(
      '', '\n', '',
      _predicates.map<String>((_PaintPredicate predicate) => predicate.toString()),
    );
  }

  @override
  bool _evaluatePredicates(Iterable<RecordedInvocation> calls, StringBuffer description) {
    if (calls.isEmpty) {
      description.writeln('It painted nothing.');
      return false;
    }
    if (_predicates.isEmpty) {
      description.writeln(
        'It painted something, but you must now add a pattern to the paints '
        'matcher in the test to verify that it matches the important parts of '
        'the following.',
      );
      return false;
    }
    final Iterator<_PaintPredicate> predicate = _predicates.iterator;
    final Iterator<RecordedInvocation> call = calls.iterator..moveNext();
    try {
      while (predicate.moveNext()) {
        predicate.current.match(call);
      }
      // We allow painting more than expected.
    } on _MismatchedCall catch (data) {
      description.writeln(data.message);
      description.writeln(data.callIntroduction);
      description.writeln(data.call.stackToString(indent: '  '));
      return false;
    } on String catch (s) {
      description.writeln(s);
      try {
        description.write('The stack of the offending call was:\n${call.current.stackToString(indent: "  ")}\n');
      } on TypeError catch (_) {
        // All calls have been evaluated
      }
      return false;
    }
    return true;
  }
}

abstract class _PaintPredicate {
  void match(Iterator<RecordedInvocation> call);

  @protected
  void checkMethod(Iterator<RecordedInvocation> call, Symbol symbol) {
    int others = 0;
    final RecordedInvocation firstCall = call.current;
    while (!call.current.invocation.isMethod || call.current.invocation.memberName != symbol) {
      others += 1;
      if (!call.moveNext()) {
        throw _MismatchedCall(
          'It called $others other method${ others == 1 ? "" : "s" } on the '
          'canvas, the first of which was $firstCall, but did not call '
          '${_symbolName(symbol)}() at the time where $this was expected.',
          'The first method that was called when the call to '
          '${_symbolName(symbol)}() was expected, $firstCall, was called with '
          'the following stack:',
          firstCall,
        );
      }
    }
  }

  @override
  String toString() {
    throw FlutterError('$runtimeType does not implement toString.');
  }
}

abstract class _DrawCommandPaintPredicate extends _PaintPredicate {
  _DrawCommandPaintPredicate(
    this.symbol,
    this.name,
    this.argumentCount,
    this.paintArgumentIndex, {
    this.color,
    this.strokeWidth,
    this.hasMaskFilter,
    this.style,
    this.strokeCap,
  });

  final Symbol symbol;
  final String name;
  final int argumentCount;
  final int paintArgumentIndex;
  final Color? color;
  final double? strokeWidth;
  final bool? hasMaskFilter;
  final PaintingStyle? style;
  final StrokeCap? strokeCap;

  String get methodName => _symbolName(symbol);

  @override
  void match(Iterator<RecordedInvocation> call) {
    checkMethod(call, symbol);
    final int actualArgumentCount = call.current.invocation.positionalArguments.length;
    if (actualArgumentCount != argumentCount) {
      throw FlutterError(
        'It called $methodName with $actualArgumentCount '
        'argument${actualArgumentCount == 1 ? "" : "s"}; expected '
        '$argumentCount.'
      );
    }
    verifyArguments(call.current.invocation.positionalArguments);
    call.moveNext();
  }

  @protected
  @mustCallSuper
  void verifyArguments(List<dynamic> arguments) {
    final Paint paintArgument = arguments[paintArgumentIndex] as Paint;
    if (color != null && paintArgument.color != color) {
      throw FlutterError(
        'It called $methodName with a paint whose color, '
        '${paintArgument.color}, was not exactly the expected color ($color).'
      );
    }
    if (strokeWidth != null && paintArgument.strokeWidth != strokeWidth) {
      throw FlutterError(
        'It called $methodName with a paint whose strokeWidth, '
        '${paintArgument.strokeWidth}, was not exactly the expected '
        'strokeWidth ($strokeWidth).'
      );
    }
    if (hasMaskFilter != null && (paintArgument.maskFilter != null) != hasMaskFilter) {
      if (hasMaskFilter!) {
        throw FlutterError(
          'It called $methodName with a paint that did not have a mask filter, '
          'despite expecting one.'
        );
      } else {
        throw FlutterError(
          'It called $methodName with a paint that had a mask filter, '
          'despite not expecting one.'
        );
      }
    }
    if (style != null && paintArgument.style != style) {
      throw FlutterError(
        'It called $methodName with a paint whose style, '
        '${paintArgument.style}, was not exactly the expected style ($style).'
      );
    }
    if (strokeCap != null && paintArgument.strokeCap != strokeCap) {
      throw FlutterError(
        'It called $methodName with a paint whose strokeCap, '
        '${paintArgument.strokeCap}, was not exactly the expected '
        'strokeCap ($strokeCap).'
      );
    }
  }

  @override
  String toString() {
    final List<String> description = <String>[];
    debugFillDescription(description);
    String result = name;
    if (description.isNotEmpty) {
      result += ' with ${description.join(", ")}';
    }
    return result;
  }

  @protected
  @mustCallSuper
  void debugFillDescription(List<String> description) {
    if (color != null) {
      description.add('$color');
    }
    if (strokeWidth != null) {
      description.add('strokeWidth: $strokeWidth');
    }
    if (hasMaskFilter != null) {
      description.add(hasMaskFilter! ? 'a mask filter' : 'no mask filter');
    }
    if (style != null) {
      description.add('$style');
    }
  }
}

class _OneParameterPaintPredicate<T> extends _DrawCommandPaintPredicate {
  _OneParameterPaintPredicate(
    Symbol symbol,
    String name, {
    required this.expected,
    required super.color,
    required super.strokeWidth,
    required super.hasMaskFilter,
    required super.style,
  }) : super(symbol, name, 2, 1);

  final T? expected;

  @override
  void verifyArguments(List<dynamic> arguments) {
    super.verifyArguments(arguments);
    final T actual = arguments[0] as T;
    if (expected != null && actual != expected) {
      throw FlutterError(
        'It called $methodName with $T, $actual, which was not exactly the '
        'expected $T ($expected).'
      );
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (expected != null) {
      if (expected.toString().contains(T.toString())) {
        description.add('$expected');
      } else {
        description.add('$T: $expected');
      }
    }
  }
}

class _TwoParameterPaintPredicate<T1, T2> extends _DrawCommandPaintPredicate {
  _TwoParameterPaintPredicate(
    Symbol symbol,
    String name, {
    required this.expected1,
    required this.expected2,
    required super.color,
    required super.strokeWidth,
    required super.hasMaskFilter,
    required super.style,
  }) : super(symbol, name, 3, 2);

  final T1? expected1;

  final T2? expected2;

  @override
  void verifyArguments(List<dynamic> arguments) {
    super.verifyArguments(arguments);
    final T1 actual1 = arguments[0] as T1;
    if (expected1 != null && actual1 != expected1) {
      throw FlutterError(
        'It called $methodName with its first argument (a $T1), $actual1, '
        'which was not exactly the expected $T1 ($expected1).'
      );
    }
    final T2 actual2 = arguments[1] as T2;
    if (expected2 != null && actual2 != expected2) {
      throw FlutterError(
        'It called $methodName with its second argument (a $T2), $actual2, '
        'which was not exactly the expected $T2 ($expected2).'
      );
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (expected1 != null) {
      if (expected1.toString().contains(T1.toString())) {
        description.add('$expected1');
      } else {
        description.add('$T1: $expected1');
      }
    }
    if (expected2 != null) {
      if (expected2.toString().contains(T2.toString())) {
        description.add('$expected2');
      } else {
        description.add('$T2: $expected2');
      }
    }
  }
}

class _RectPaintPredicate extends _OneParameterPaintPredicate<Rect> {
  _RectPaintPredicate({
    Rect? rect,
    super.color,
    super.strokeWidth,
    super.hasMaskFilter,
    super.style,
  }) : super(#drawRect, 'a rectangle', expected: rect);
}

class _RRectPaintPredicate extends _DrawCommandPaintPredicate {
  _RRectPaintPredicate({
    this.rrect,
    super.color,
    super.strokeWidth,
    super.hasMaskFilter,
    super.style,
  }) : super(#drawRRect, 'a rounded rectangle', 2, 1);

  final RRect? rrect;

  @override
  void verifyArguments(List<dynamic> arguments) {
    super.verifyArguments(arguments);
    const double eps = .0001;
    final RRect actual = arguments[0] as RRect;
    if (rrect != null &&
       ((actual.left - rrect!.left).abs() > eps ||
        (actual.right - rrect!.right).abs() > eps ||
        (actual.top - rrect!.top).abs() > eps ||
        (actual.bottom - rrect!.bottom).abs() > eps ||
        (actual.blRadiusX - rrect!.blRadiusX).abs() > eps ||
        (actual.blRadiusY - rrect!.blRadiusY).abs() > eps ||
        (actual.brRadiusX - rrect!.brRadiusX).abs() > eps ||
        (actual.brRadiusY - rrect!.brRadiusY).abs() > eps ||
        (actual.tlRadiusX - rrect!.tlRadiusX).abs() > eps ||
        (actual.tlRadiusY - rrect!.tlRadiusY).abs() > eps ||
        (actual.trRadiusX - rrect!.trRadiusX).abs() > eps ||
        (actual.trRadiusY - rrect!.trRadiusY).abs() > eps)) {
      throw FlutterError(
        'It called $methodName with RRect, $actual, which was not exactly the '
        'expected RRect ($rrect).'
      );
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (rrect != null) {
      description.add('RRect: $rrect');
    }
  }
}

class _DRRectPaintPredicate extends _TwoParameterPaintPredicate<RRect, RRect> {
  _DRRectPaintPredicate({
    RRect? inner,
    RRect? outer,
    super.color,
    super.strokeWidth,
    super.hasMaskFilter,
    super.style,
  }) : super(#drawDRRect, 'a rounded rectangle outline', expected1: outer, expected2: inner);
}

class _CirclePaintPredicate extends _DrawCommandPaintPredicate {
  _CirclePaintPredicate({
    this.x,
    this.y,
    this.radius,
    super.color,
    super.strokeWidth,
    super.hasMaskFilter,
    super.style,
  }) : super(#drawCircle, 'a circle', 3, 2);

  final double? x;
  final double? y;
  final double? radius;

  @override
  void verifyArguments(List<dynamic> arguments) {
    super.verifyArguments(arguments);
    final Offset pointArgument = arguments[0] as Offset;
    if (x != null && y != null) {
      final Offset point = Offset(x!, y!);
      if (point != pointArgument) {
        throw FlutterError(
          'It called $methodName with a center coordinate, $pointArgument, '
          'which was not exactly the expected coordinate ($point).'
        );
      }
    } else {
      if (x != null && pointArgument.dx != x) {
        throw FlutterError(
          'It called $methodName with a center coordinate, $pointArgument, '
          'whose x-coordinate was not exactly the expected coordinate '
          '(${x!.toStringAsFixed(1)}).'
        );
      }
      if (y != null && pointArgument.dy != y) {
        throw FlutterError(
          'It called $methodName with a center coordinate, $pointArgument, '
          'whose y-coordinate was not exactly the expected coordinate '
          '(${y!.toStringAsFixed(1)}).'
        );
      }
    }
    final double radiusArgument = arguments[1] as double;
    if (radius != null && radiusArgument != radius) {
      throw FlutterError(
        'It called $methodName with radius, '
        '${radiusArgument.toStringAsFixed(1)}, which was not exactly the '
        'expected radius (${radius!.toStringAsFixed(1)}).'
      );
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (x != null && y != null) {
      description.add('point ${Offset(x!, y!)}');
    } else {
      if (x != null) {
        description.add('x-coordinate ${x!.toStringAsFixed(1)}');
      }
      if (y != null) {
        description.add('y-coordinate ${y!.toStringAsFixed(1)}');
      }
    }
    if (radius != null) {
      description.add('radius ${radius!.toStringAsFixed(1)}');
    }
  }
}

class _PathPaintPredicate extends _DrawCommandPaintPredicate {
  _PathPaintPredicate({
    this.includes,
    this.excludes,
    super.color,
    super.strokeWidth,
    super.hasMaskFilter,
    super.style,
  }) : super(#drawPath, 'a path', 2, 1);

  final Iterable<Offset>? includes;
  final Iterable<Offset>? excludes;

  @override
  void verifyArguments(List<dynamic> arguments) {
    super.verifyArguments(arguments);
    final Path pathArgument = arguments[0] as Path;
    if (includes != null) {
      for (final Offset offset in includes!) {
        if (!pathArgument.contains(offset)) {
          throw FlutterError(
            'It called $methodName with a path that unexpectedly did not '
            'contain $offset.'
          );
        }
      }
    }
    if (excludes != null) {
      for (final Offset offset in excludes!) {
        if (pathArgument.contains(offset)) {
          throw FlutterError(
            'It called $methodName with a path that unexpectedly contained '
            '$offset.'
          );
        }
      }
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (includes != null && excludes != null) {
      description.add('that contains $includes and does not contain $excludes');
    } else if (includes != null) {
      description.add('that contains $includes');
    } else if (excludes != null) {
      description.add('that does not contain $excludes');
    }
  }
}

// TODO(ianh): add arguments to test the length, angle, that kind of thing
class _LinePaintPredicate extends _DrawCommandPaintPredicate {
  _LinePaintPredicate({
    this.p1,
    this.p2,
    super.color,
    super.strokeWidth,
    super.hasMaskFilter,
    super.style,
  }) : super(#drawLine, 'a line', 3, 2);

  final Offset? p1;
  final Offset? p2;

  @override
  void verifyArguments(List<dynamic> arguments) {
    super.verifyArguments(arguments); // Checks the 3rd argument, a Paint
    if (arguments.length != 3) {
      throw FlutterError(
        'It called $methodName with ${arguments.length} arguments; expected 3.'
      );
    }
    final Offset p1Argument = arguments[0] as Offset;
    final Offset p2Argument = arguments[1] as Offset;
    if (p1 != null && p1Argument != p1) {
      throw FlutterError(
        'It called $methodName with p1 endpoint, $p1Argument, which was not '
        'exactly the expected endpoint ($p1).'
      );
    }
    if (p2 != null && p2Argument != p2) {
      throw FlutterError(
        'It called $methodName with p2 endpoint, $p2Argument, which was not '
        'exactly the expected endpoint ($p2).'
      );
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (p1 != null) {
      description.add('end point p1: $p1');
    }
    if (p2 != null) {
      description.add('end point p2: $p2');
    }
  }
}

class _ArcPaintPredicate extends _DrawCommandPaintPredicate {
  _ArcPaintPredicate({
    this.rect,
    super.color,
    super.strokeWidth,
    super.hasMaskFilter,
    super.style,
    super.strokeCap,
  }) : super(#drawArc, 'an arc', 5, 4);

  final Rect? rect;

  @override
  void verifyArguments(List<dynamic> arguments) {
    super.verifyArguments(arguments);
    final Rect rectArgument = arguments[0] as Rect;
    if (rect != null && rectArgument != rect) {
      throw FlutterError(
        'It called $methodName with a paint whose rect, $rectArgument, was not '
        'exactly the expected rect ($rect).'
      );
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (rect != null) {
      description.add('rect $rect');
    }
  }
}

class _ShadowPredicate extends _PaintPredicate {
  _ShadowPredicate({ this.includes, this.excludes, this.color, this.elevation, this.transparentOccluder });

  final Iterable<Offset>? includes;
  final Iterable<Offset>? excludes;
  final Color? color;
  final double? elevation;
  final bool? transparentOccluder;

  static const Symbol symbol = #drawShadow;
  String get methodName => _symbolName(symbol);

  @protected
  void verifyArguments(List<dynamic> arguments) {
    if (arguments.length != 4) {
      throw FlutterError(
        'It called $methodName with ${arguments.length} arguments; expected 4.'
      );
    }
    final Path pathArgument = arguments[0] as Path;
    if (includes != null) {
      for (final Offset offset in includes!) {
        if (!pathArgument.contains(offset)) {
          throw FlutterError(
            'It called $methodName with a path that unexpectedly did not '
            'contain $offset.'
          );
        }
      }
    }
    if (excludes != null) {
      for (final Offset offset in excludes!) {
        if (pathArgument.contains(offset)) {
          throw FlutterError(
            'It called $methodName with a path that unexpectedly contained '
            '$offset.'
          );
        }
      }
    }
    final Color actualColor = arguments[1] as Color;
    if (color != null && actualColor != color) {
      throw FlutterError(
        'It called $methodName with a color, $actualColor, which was not '
        'exactly the expected color ($color).'
      );
    }
    final double actualElevation = arguments[2] as double;
    if (elevation != null && actualElevation != elevation) {
      throw FlutterError(
        'It called $methodName with an elevation, $actualElevation, which was '
        'not exactly the expected value ($elevation).'
      );
    }
    final bool actualTransparentOccluder = arguments[3] as bool;
    if (transparentOccluder != null && actualTransparentOccluder != transparentOccluder) {
      throw FlutterError(
        'It called $methodName with a transparentOccluder value, '
        '$actualTransparentOccluder, which was not exactly the expected value '
        '($transparentOccluder).'
      );
    }
  }

  @override
  void match(Iterator<RecordedInvocation> call) {
    checkMethod(call, symbol);
    verifyArguments(call.current.invocation.positionalArguments);
    call.moveNext();
  }

  @protected
  void debugFillDescription(List<String> description) {
    if (includes != null && excludes != null) {
      description.add('that contains $includes and does not contain $excludes');
    } else if (includes != null) {
      description.add('that contains $includes');
    } else if (excludes != null) {
      description.add('that does not contain $excludes');
    }
    if (color != null) {
      description.add('$color');
    }
    if (elevation != null) {
      description.add('elevation: $elevation');
    }
    if (transparentOccluder != null) {
      description.add('transparentOccluder: $transparentOccluder');
    }
  }

  @override
  String toString() {
    final List<String> description = <String>[];
    debugFillDescription(description);
    String result = methodName;
    if (description.isNotEmpty) {
      result += ' with ${description.join(", ")}';
    }
    return result;
  }
}

class _DrawImagePaintPredicate extends _DrawCommandPaintPredicate {
  _DrawImagePaintPredicate({
    this.image,
    this.x,
    this.y,
    super.color,
    super.strokeWidth,
    super.hasMaskFilter,
    super.style,
  }) : super(#drawImage, 'an image', 3, 2);

  final ui.Image? image;
  final double? x;
  final double? y;

  @override
  void verifyArguments(List<dynamic> arguments) {
    super.verifyArguments(arguments);
    final ui.Image imageArgument = arguments[0] as ui.Image;
    if (image != null && !image!.isCloneOf(imageArgument)) {
      throw FlutterError(
        'It called $methodName with an image, $imageArgument, which was not '
        'exactly the expected image ($image).'
      );
    }
    final Offset pointArgument = arguments[0] as Offset;
    if (x != null && y != null) {
      final Offset point = Offset(x!, y!);
      if (point != pointArgument) {
        throw FlutterError(
          'It called $methodName with an offset coordinate, $pointArgument, '
          'which was not exactly the expected coordinate ($point).'
        );
      }
    } else {
      if (x != null && pointArgument.dx != x) {
        throw FlutterError(
          'It called $methodName with an offset coordinate, $pointArgument, '
          'whose x-coordinate was not exactly the expected coordinate '
          '(${x!.toStringAsFixed(1)}).'
        );
      }
      if (y != null && pointArgument.dy != y) {
        throw FlutterError(
          'It called $methodName with an offset coordinate, $pointArgument, '
          'whose y-coordinate was not exactly the expected coordinate '
          '(${y!.toStringAsFixed(1)}).'
        );
      }
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (image != null) {
      description.add('image $image');
    }
    if (x != null && y != null) {
      description.add('point ${Offset(x!, y!)}');
    } else {
      if (x != null) {
        description.add('x-coordinate ${x!.toStringAsFixed(1)}');
      }
      if (y != null) {
        description.add('y-coordinate ${y!.toStringAsFixed(1)}');
      }
    }
  }
}

class _DrawImageRectPaintPredicate extends _DrawCommandPaintPredicate {
  _DrawImageRectPaintPredicate({
    this.image,
    this.source,
    this.destination,
    super.color,
    super.strokeWidth,
    super.hasMaskFilter,
    super.style,
  }) : super(#drawImageRect, 'an image', 4, 3);

  final ui.Image? image;
  final Rect? source;
  final Rect? destination;

  @override
  void verifyArguments(List<dynamic> arguments) {
    super.verifyArguments(arguments);
    final ui.Image imageArgument = arguments[0] as ui.Image;
    if (image != null && !image!.isCloneOf(imageArgument)) {
      throw FlutterError(
        'It called $methodName with an image, $imageArgument, which was not '
        'exactly the expected image ($image).'
      );
    }
    final Rect sourceArgument = arguments[1] as Rect;
    if (source != null && sourceArgument != source) {
      throw FlutterError(
        'It called $methodName with a source rectangle, $sourceArgument, which '
        'was not exactly the expected rectangle ($source).'
      );
    }
    final Rect destinationArgument = arguments[2] as Rect;
    if (destination != null && destinationArgument != destination) {
      throw FlutterError(
        'It called $methodName with a destination rectangle, '
        '$destinationArgument, which was not exactly the expected rectangle '
        '($destination).'
      );
    }
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (image != null) {
      description.add('image $image');
    }
    if (source != null) {
      description.add('source $source');
    }
    if (destination != null) {
      description.add('destination $destination');
    }
  }
}

class _SomethingPaintPredicate extends _PaintPredicate {
  _SomethingPaintPredicate(this.predicate);

  final PaintPatternPredicate predicate;

  @override
  void match(Iterator<RecordedInvocation> call) {
    RecordedInvocation currentCall;
    bool testedAllCalls = false;
    do {
      if (testedAllCalls) {
        throw FlutterError(
          'It painted methods that the predicate passed to a "something" step, '
          'in the paint pattern, none of which were considered correct.'
        );
      }
      currentCall = call.current;
      if (!currentCall.invocation.isMethod) {
        throw FlutterError(
          'It called $currentCall, which was not a method, when the paint '
          'pattern expected a method call'
        );
      }
      testedAllCalls = !call.moveNext();
    } while (!_runPredicate(currentCall.invocation.memberName, currentCall.invocation.positionalArguments));
  }

  bool _runPredicate(Symbol methodName, List<dynamic> arguments) {
    try {
      return predicate(methodName, arguments);
    } on String catch (s) {
      throw FlutterError(
        'It painted something that the predicate passed to a "something" step '
        'in the paint pattern considered incorrect:\n      $s\n  '
      );
    }
  }

  @override
  String toString() => 'a "something" step';
}

class _EverythingPaintPredicate extends _PaintPredicate {
  _EverythingPaintPredicate(this.predicate);

  final PaintPatternPredicate predicate;

  @override
  void match(Iterator<RecordedInvocation> call) {
    do {
      final RecordedInvocation currentCall = call.current;
      if (!currentCall.invocation.isMethod) {
        throw FlutterError(
          'It called $currentCall, which was not a method, when the paint '
          'pattern expected a method call'
        );
      }
      if (!_runPredicate(currentCall.invocation.memberName, currentCall.invocation.positionalArguments)) {
        throw FlutterError(
          'It painted something that the predicate passed to an "everything" '
          'step in the paint pattern considered incorrect.\n'
        );
      }
    } while (call.moveNext());
  }

  bool _runPredicate(Symbol methodName, List<dynamic> arguments) {
    try {
      return predicate(methodName, arguments);
    } on String catch (s) {
      throw FlutterError(
        'It painted something that the predicate passed to an "everything" step '
        'in the paint pattern considered incorrect:\n      $s\n  '
      );
    }
  }

  @override
  String toString() => 'an "everything" step';
}

class _FunctionPaintPredicate extends _PaintPredicate {
  _FunctionPaintPredicate(this.symbol, this.arguments);

  final Symbol symbol;

  final List<dynamic> arguments;

  @override
  void match(Iterator<RecordedInvocation> call) {
    checkMethod(call, symbol);
    if (call.current.invocation.positionalArguments.length != arguments.length) {
      throw FlutterError(
        'It called ${_symbolName(symbol)} with '
        '${call.current.invocation.positionalArguments.length} arguments; '
        'expected ${arguments.length}.'
      );
    }
    for (int index = 0; index < arguments.length; index += 1) {
      final dynamic actualArgument = call.current.invocation.positionalArguments[index];
      final dynamic desiredArgument = arguments[index];

      if (desiredArgument is Matcher) {
        expect(actualArgument, desiredArgument);
      } else if (desiredArgument != null && desiredArgument != actualArgument) {
        throw FlutterError(
          'It called ${_symbolName(symbol)} with argument $index having value '
          '${_valueName(actualArgument)} when ${_valueName(desiredArgument)} '
          'was expected.'
        );
      }
    }
    call.moveNext();
  }

  @override
  String toString() {
    final List<String> adjectives = <String>[
      for (int index = 0; index < arguments.length; index += 1)
        arguments[index] != null ? _valueName(arguments[index]) : '...',
    ];
    return '${_symbolName(symbol)}(${adjectives.join(", ")})';
  }
}

class _SaveRestorePairPaintPredicate extends _PaintPredicate {
  @override
  void match(Iterator<RecordedInvocation> call) {
    checkMethod(call, #save);
    int depth = 1;
    while (depth > 0) {
      if (!call.moveNext()) {
        throw FlutterError(
          'It did not have a matching restore() for the save() that was found '
          'where $this was expected.'
        );
      }
      if (call.current.invocation.isMethod) {
        if (call.current.invocation.memberName == #save) {
          depth += 1;
        } else if (call.current.invocation.memberName == #restore) {
          depth -= 1;
        }
      }
    }
    call.moveNext();
  }

  @override
  String toString() => 'a matching save/restore pair';
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