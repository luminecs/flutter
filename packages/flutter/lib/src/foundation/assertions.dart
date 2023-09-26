import 'package:meta/meta.dart';

import 'basic_types.dart';
import 'constants.dart';
import 'diagnostics.dart';
import 'print.dart';
import 'stack_frame.dart';

export 'basic_types.dart' show IterableFilter;
export 'diagnostics.dart'
    show
        DiagnosticLevel,
        DiagnosticPropertiesBuilder,
        DiagnosticsNode,
        DiagnosticsTreeStyle;
export 'stack_frame.dart' show StackFrame;

// Examples can assume:
// late String runtimeType;
// late bool draconisAlive;
// late bool draconisAmulet;
// late Diagnosticable draconis;
// void methodThatMayThrow() { }
// class Trace implements StackTrace { late StackTrace vmTrace; }
// class Chain implements StackTrace { Trace toTrace() => Trace(); }

typedef FlutterExceptionHandler = void Function(FlutterErrorDetails details);

typedef DiagnosticPropertiesTransformer = Iterable<DiagnosticsNode> Function(
    Iterable<DiagnosticsNode> properties);

typedef InformationCollector = Iterable<DiagnosticsNode> Function();

typedef StackTraceDemangler = StackTrace Function(StackTrace details);

@immutable
class PartialStackFrame {
  const PartialStackFrame({
    required this.package,
    required this.className,
    required this.method,
  });

  static const PartialStackFrame asynchronousSuspension = PartialStackFrame(
    package: '',
    className: '',
    method: 'asynchronous suspension',
  );

  final Pattern package;

  final String className;

  final String method;

  bool matches(StackFrame stackFrame) {
    final String stackFramePackage =
        '${stackFrame.packageScheme}:${stackFrame.package}/${stackFrame.packagePath}';
    // Ideally this wouldn't be necessary.
    // TODO(dnfield): https://github.com/dart-lang/sdk/issues/40117
    if (kIsWeb) {
      return package.allMatches(stackFramePackage).isNotEmpty &&
          stackFrame.method == (method.startsWith('_') ? '[$method]' : method);
    }
    return package.allMatches(stackFramePackage).isNotEmpty &&
        stackFrame.method == method &&
        stackFrame.className == className;
  }
}

abstract class StackFilter {
  const StackFilter();

  void filter(List<StackFrame> stackFrames, List<String?> reasons);
}

class RepetitiveStackFrameFilter extends StackFilter {
  const RepetitiveStackFrameFilter({
    required this.frames,
    required this.replacement,
  });

  final List<PartialStackFrame> frames;

  int get numFrames => frames.length;

  final String replacement;

  List<String> get _replacements => List<String>.filled(numFrames, replacement);

  @override
  void filter(List<StackFrame> stackFrames, List<String?> reasons) {
    for (int index = 0; index < stackFrames.length - numFrames; index += 1) {
      if (_matchesFrames(stackFrames.skip(index).take(numFrames).toList())) {
        reasons.setRange(index, index + numFrames, _replacements);
        index += numFrames - 1;
      }
    }
  }

  bool _matchesFrames(List<StackFrame> stackFrames) {
    if (stackFrames.length < numFrames) {
      return false;
    }
    for (int index = 0; index < stackFrames.length; index++) {
      if (!frames[index].matches(stackFrames[index])) {
        return false;
      }
    }
    return true;
  }
}

abstract class _ErrorDiagnostic extends DiagnosticsProperty<List<Object>> {
  _ErrorDiagnostic(
    String message, {
    DiagnosticsTreeStyle style = DiagnosticsTreeStyle.flat,
    DiagnosticLevel level = DiagnosticLevel.info,
  }) : super(
          null,
          <Object>[message],
          showName: false,
          showSeparator: false,
          defaultValue: null,
          style: style,
          level: level,
        );

  //
  // ```dart
  // _ErrorDiagnostic('Element $element must be $color')
  // ```
  // Desugars to:
  // ```dart
  // _ErrorDiagnostic.fromParts(<Object>['Element ', element, ' must be ', color])
  // ```
  //
  // Slightly more complex case:
  // ```dart
  // _ErrorDiagnostic('Element ${element.runtimeType} must be $color')
  // ```
  // Desugars to:
  //```dart
  // _ErrorDiagnostic.fromParts(<Object>[
  //   'Element ',
  //   DiagnosticsProperty(null, element, description: element.runtimeType?.toString()),
  //   ' must be ',
  //   color,
  // ])
  // ```
  _ErrorDiagnostic._fromParts(
    List<Object> messageParts, {
    DiagnosticsTreeStyle style = DiagnosticsTreeStyle.flat,
    DiagnosticLevel level = DiagnosticLevel.info,
  }) : super(
          null,
          messageParts,
          showName: false,
          showSeparator: false,
          defaultValue: null,
          style: style,
          level: level,
        );

  @override
  String toString({
    TextTreeConfiguration? parentConfiguration,
    DiagnosticLevel minLevel = DiagnosticLevel.info,
  }) {
    return valueToString(parentConfiguration: parentConfiguration);
  }

  @override
  List<Object> get value => super.value!;

  @override
  String valueToString({TextTreeConfiguration? parentConfiguration}) {
    return value.join();
  }
}

class ErrorDescription extends _ErrorDiagnostic {
  ErrorDescription(super.message) : super(level: DiagnosticLevel.info);

  // ignore: unused_element
  ErrorDescription._fromParts(super.messageParts)
      : super._fromParts(level: DiagnosticLevel.info);
}

class ErrorSummary extends _ErrorDiagnostic {
  ErrorSummary(super.message) : super(level: DiagnosticLevel.summary);

  // ignore: unused_element
  ErrorSummary._fromParts(super.messageParts)
      : super._fromParts(level: DiagnosticLevel.summary);
}

class ErrorHint extends _ErrorDiagnostic {
  ErrorHint(super.message) : super(level: DiagnosticLevel.hint);

  // ignore: unused_element
  ErrorHint._fromParts(super.messageParts)
      : super._fromParts(level: DiagnosticLevel.hint);
}

class ErrorSpacer extends DiagnosticsProperty<void> {
  ErrorSpacer()
      : super(
          '',
          null,
          description: '',
          showName: false,
        );
}

class FlutterErrorDetails with Diagnosticable {
  const FlutterErrorDetails({
    required this.exception,
    this.stack,
    this.library = 'Flutter framework',
    this.context,
    this.stackFilter,
    this.informationCollector,
    this.silent = false,
  });

  FlutterErrorDetails copyWith({
    DiagnosticsNode? context,
    Object? exception,
    InformationCollector? informationCollector,
    String? library,
    bool? silent,
    StackTrace? stack,
    IterableFilter<String>? stackFilter,
  }) {
    return FlutterErrorDetails(
      context: context ?? this.context,
      exception: exception ?? this.exception,
      informationCollector: informationCollector ?? this.informationCollector,
      library: library ?? this.library,
      silent: silent ?? this.silent,
      stack: stack ?? this.stack,
      stackFilter: stackFilter ?? this.stackFilter,
    );
  }

  static final List<DiagnosticPropertiesTransformer> propertiesTransformers =
      <DiagnosticPropertiesTransformer>[];

  final Object exception;

  final StackTrace? stack;

  final String? library;

  final DiagnosticsNode? context;

  final IterableFilter<String>? stackFilter;

  final InformationCollector? informationCollector;

  final bool silent;

  String exceptionAsString() {
    String? longMessage;
    if (exception is AssertionError) {
      // Regular _AssertionErrors thrown by assert() put the message last, after
      // some code snippets. This leads to ugly messages. To avoid this, we move
      // the assertion message up to before the code snippets, separated by a
      // newline, if we recognize that format is being used.
      final Object? message = (exception as AssertionError).message;
      final String fullMessage = exception.toString();
      if (message is String && message != fullMessage) {
        if (fullMessage.length > message.length) {
          final int position = fullMessage.lastIndexOf(message);
          if (position == fullMessage.length - message.length &&
              position > 2 &&
              fullMessage.substring(position - 2, position) == ': ') {
            // Add a linebreak so that the filename at the start of the
            // assertion message is always on its own line.
            String body = fullMessage.substring(0, position - 2);
            final int splitPoint = body.indexOf(' Failed assertion:');
            if (splitPoint >= 0) {
              body =
                  '${body.substring(0, splitPoint)}\n${body.substring(splitPoint + 1)}';
            }
            longMessage = '${message.trimRight()}\n$body';
          }
        }
      }
      longMessage ??= fullMessage;
    } else if (exception is String) {
      longMessage = exception as String;
    } else if (exception is Error || exception is Exception) {
      longMessage = exception.toString();
    } else {
      longMessage = '  $exception';
    }
    longMessage = longMessage.trimRight();
    if (longMessage.isEmpty) {
      longMessage = '  <no message available>';
    }
    return longMessage;
  }

  Diagnosticable? _exceptionToDiagnosticable() {
    final Object exception = this.exception;
    if (exception is FlutterError) {
      return exception;
    }
    if (exception is AssertionError && exception.message is FlutterError) {
      return exception.message! as FlutterError;
    }
    return null;
  }

  DiagnosticsNode get summary {
    String formatException() => exceptionAsString().split('\n')[0].trimLeft();
    if (kReleaseMode) {
      return DiagnosticsNode.message(formatException());
    }
    final Diagnosticable? diagnosticable = _exceptionToDiagnosticable();
    DiagnosticsNode? summary;
    if (diagnosticable != null) {
      final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();
      debugFillProperties(builder);
      summary = builder.properties.cast<DiagnosticsNode?>().firstWhere(
          (DiagnosticsNode? node) => node!.level == DiagnosticLevel.summary,
          orElse: () => null);
    }
    return summary ?? ErrorSummary(formatException());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final DiagnosticsNode verb = ErrorDescription(
        'thrown${context != null ? ErrorDescription(" $context") : ""}');
    final Diagnosticable? diagnosticable = _exceptionToDiagnosticable();
    if (exception is num) {
      properties.add(ErrorDescription('The number $exception was $verb.'));
    } else {
      final DiagnosticsNode errorName;
      if (exception is AssertionError) {
        errorName = ErrorDescription('assertion');
      } else if (exception is String) {
        errorName = ErrorDescription('message');
      } else if (exception is Error || exception is Exception) {
        errorName = ErrorDescription('${exception.runtimeType}');
      } else {
        errorName = ErrorDescription('${exception.runtimeType} object');
      }
      properties.add(ErrorDescription('The following $errorName was $verb:'));
      if (diagnosticable != null) {
        diagnosticable.debugFillProperties(properties);
      } else {
        // Many exception classes put their type at the head of their message.
        // This is redundant with the way we display exceptions, so attempt to
        // strip out that header when we see it.
        final String prefix = '${exception.runtimeType}: ';
        String message = exceptionAsString();
        if (message.startsWith(prefix)) {
          message = message.substring(prefix.length);
        }
        properties.add(ErrorSummary(message));
      }
    }

    if (stack != null) {
      if (exception is AssertionError && diagnosticable == null) {
        // After popping off any dart: stack frames, are there at least two more
        // stack frames coming from package flutter?
        //
        // If not: Error is in user code (user violated assertion in framework).
        // If so:  Error is in Framework. We either need an assertion higher up
        //         in the stack, or we've violated our own assertions.
        final List<StackFrame> stackFrames =
            StackFrame.fromStackTrace(FlutterError.demangleStackTrace(stack!))
                .skipWhile((StackFrame frame) => frame.packageScheme == 'dart')
                .toList();
        final bool ourFault = stackFrames.length >= 2 &&
            stackFrames[0].package == 'flutter' &&
            stackFrames[1].package == 'flutter';
        if (ourFault) {
          properties.add(ErrorSpacer());
          properties.add(ErrorHint(
            'Either the assertion indicates an error in the framework itself, or we should '
            'provide substantially more information in this error message to help you determine '
            'and fix the underlying cause.\n'
            'In either case, please report this assertion by filing a bug on GitHub:\n'
            '  https://github.com/flutter/flutter/issues/new?template=2_bug.yml',
          ));
        }
      }
      properties.add(ErrorSpacer());
      properties.add(DiagnosticsStackTrace(
          'When the exception was thrown, this was the stack', stack,
          stackFilter: stackFilter));
    }
    if (informationCollector != null) {
      properties.add(ErrorSpacer());
      informationCollector!().forEach(properties.add);
    }
  }

  @override
  String toStringShort() {
    return library != null
        ? 'Exception caught by $library'
        : 'Exception caught';
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return toDiagnosticsNode(style: DiagnosticsTreeStyle.error)
        .toStringDeep(minLevel: minLevel);
  }

  @override
  DiagnosticsNode toDiagnosticsNode(
      {String? name, DiagnosticsTreeStyle? style}) {
    return _FlutterErrorDetailsNode(
      name: name,
      value: this,
      style: style,
    );
  }
}

class FlutterError extends Error
    with DiagnosticableTreeMixin
    implements AssertionError {
  factory FlutterError(String message) {
    final List<String> lines = message.split('\n');
    return FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary(lines.first),
      ...lines
          .skip(1)
          .map<DiagnosticsNode>((String line) => ErrorDescription(line)),
    ]);
  }

  FlutterError.fromParts(this.diagnostics)
      : assert(
            diagnostics.isNotEmpty,
            FlutterError.fromParts(
                <DiagnosticsNode>[ErrorSummary('Empty FlutterError')])) {
    assert(
      diagnostics.first.level == DiagnosticLevel.summary,
      FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('FlutterError is missing a summary.'),
        ErrorDescription(
          'All FlutterError objects should start with a short (one line) '
          'summary description of the problem that was detected.',
        ),
        DiagnosticsProperty<FlutterError>('Malformed', this,
            expandableValue: true,
            showSeparator: false,
            style: DiagnosticsTreeStyle.whitespace),
        ErrorDescription(
          '\nThis error should still help you solve your problem, '
          'however please also report this malformed error in the '
          'framework by filing a bug on GitHub:\n'
          '  https://github.com/flutter/flutter/issues/new?template=2_bug.yml',
        ),
      ]),
    );
    assert(() {
      final Iterable<DiagnosticsNode> summaries = diagnostics.where(
          (DiagnosticsNode node) => node.level == DiagnosticLevel.summary);
      if (summaries.length > 1) {
        final List<DiagnosticsNode> message = <DiagnosticsNode>[
          ErrorSummary('FlutterError contained multiple error summaries.'),
          ErrorDescription(
            'All FlutterError objects should have only a single short '
            '(one line) summary description of the problem that was '
            'detected.',
          ),
          DiagnosticsProperty<FlutterError>('Malformed', this,
              expandableValue: true,
              showSeparator: false,
              style: DiagnosticsTreeStyle.whitespace),
          ErrorDescription(
              '\nThe malformed error has ${summaries.length} summaries.'),
        ];
        int i = 1;
        for (final DiagnosticsNode summary in summaries) {
          message.add(DiagnosticsProperty<DiagnosticsNode>(
              'Summary $i', summary,
              expandableValue: true));
          i += 1;
        }
        message.add(ErrorDescription(
          '\nThis error should still help you solve your problem, '
          'however please also report this malformed error in the '
          'framework by filing a bug on GitHub:\n'
          '  https://github.com/flutter/flutter/issues/new?template=2_bug.yml',
        ));
        throw FlutterError.fromParts(message);
      }
      return true;
    }());
  }

  final List<DiagnosticsNode> diagnostics;

  @override
  String get message => toString();

  static FlutterExceptionHandler? onError = presentError;

  static StackTraceDemangler demangleStackTrace = _defaultStackTraceDemangler;

  static StackTrace _defaultStackTraceDemangler(StackTrace stackTrace) =>
      stackTrace;

  static FlutterExceptionHandler presentError = dumpErrorToConsole;

  static int _errorCount = 0;

  static void resetErrorCount() {
    _errorCount = 0;
  }

  static const int wrapWidth = 100;

  static void dumpErrorToConsole(FlutterErrorDetails details,
      {bool forceReport = false}) {
    bool isInDebugMode = false;
    assert(() {
      // In debug mode, we ignore the "silent" flag.
      isInDebugMode = true;
      return true;
    }());
    final bool reportError = isInDebugMode || !details.silent;
    if (!reportError && !forceReport) {
      return;
    }
    if (_errorCount == 0 || forceReport) {
      // Diagnostics is only available in debug mode. In profile and release modes fallback to plain print.
      if (isInDebugMode) {
        debugPrint(
          TextTreeRenderer(
            wrapWidthProperties: wrapWidth,
            maxDescendentsTruncatableNode: 5,
          )
              .render(
                  details.toDiagnosticsNode(style: DiagnosticsTreeStyle.error))
              .trimRight(),
        );
      } else {
        debugPrintStack(
          stackTrace: details.stack,
          label: details.exception.toString(),
          maxFrames: 100,
        );
      }
    } else {
      debugPrint('Another exception was thrown: ${details.summary}');
    }
    _errorCount += 1;
  }

  static final List<StackFilter> _stackFilters = <StackFilter>[];

  static void addDefaultStackFilter(StackFilter filter) {
    _stackFilters.add(filter);
  }

  static Iterable<String> defaultStackFilter(Iterable<String> frames) {
    final Map<String, int> removedPackagesAndClasses = <String, int>{
      'dart:async-patch': 0,
      'dart:async': 0,
      'package:stack_trace': 0,
      'class _AssertionError': 0,
      'class _FakeAsync': 0,
      'class _FrameCallbackEntry': 0,
      'class _Timer': 0,
      'class _RawReceivePortImpl': 0,
    };
    int skipped = 0;

    final List<StackFrame> parsedFrames =
        StackFrame.fromStackString(frames.join('\n'));

    for (int index = 0; index < parsedFrames.length; index += 1) {
      final StackFrame frame = parsedFrames[index];
      final String className = 'class ${frame.className}';
      final String package = '${frame.packageScheme}:${frame.package}';
      if (removedPackagesAndClasses.containsKey(className)) {
        skipped += 1;
        removedPackagesAndClasses.update(className, (int value) => value + 1);
        parsedFrames.removeAt(index);
        index -= 1;
      } else if (removedPackagesAndClasses.containsKey(package)) {
        skipped += 1;
        removedPackagesAndClasses.update(package, (int value) => value + 1);
        parsedFrames.removeAt(index);
        index -= 1;
      }
    }
    final List<String?> reasons =
        List<String?>.filled(parsedFrames.length, null);
    for (final StackFilter filter in _stackFilters) {
      filter.filter(parsedFrames, reasons);
    }

    final List<String> result = <String>[];

    // Collapse duplicated reasons.
    for (int index = 0; index < parsedFrames.length; index += 1) {
      final int start = index;
      while (index < reasons.length - 1 &&
          reasons[index] != null &&
          reasons[index + 1] == reasons[index]) {
        index++;
      }
      String suffix = '';
      if (reasons[index] != null) {
        if (index != start) {
          suffix = ' (${index - start + 2} frames)';
        } else {
          suffix = ' (1 frame)';
        }
      }
      final String resultLine =
          '${reasons[index] ?? parsedFrames[index].source}$suffix';
      result.add(resultLine);
    }

    // Only include packages we actually elided from.
    final List<String> where = <String>[
      for (final MapEntry<String, int> entry
          in removedPackagesAndClasses.entries)
        if (entry.value > 0) entry.key,
    ]..sort();
    if (skipped == 1) {
      result.add('(elided one frame from ${where.single})');
    } else if (skipped > 1) {
      if (where.length > 1) {
        where[where.length - 1] = 'and ${where.last}';
      }
      if (where.length > 2) {
        result.add('(elided $skipped frames from ${where.join(", ")})');
      } else {
        result.add('(elided $skipped frames from ${where.join(" ")})');
      }
    }
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    diagnostics.forEach(properties.add);
  }

  @override
  String toStringShort() => 'FlutterError';

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    if (kReleaseMode) {
      final Iterable<_ErrorDiagnostic> errors =
          diagnostics.whereType<_ErrorDiagnostic>();
      return errors.isNotEmpty ? errors.first.valueToString() : toStringShort();
    }
    // Avoid wrapping lines.
    final TextTreeRenderer renderer = TextTreeRenderer(wrapWidth: 4000000000);
    return diagnostics
        .map((DiagnosticsNode node) => renderer.render(node).trimRight())
        .join('\n');
  }

  static void reportError(FlutterErrorDetails details) {
    onError?.call(details);
  }
}

void debugPrintStack({StackTrace? stackTrace, String? label, int? maxFrames}) {
  if (label != null) {
    debugPrint(label);
  }
  if (stackTrace == null) {
    stackTrace = StackTrace.current;
  } else {
    stackTrace = FlutterError.demangleStackTrace(stackTrace);
  }
  Iterable<String> lines = stackTrace.toString().trimRight().split('\n');
  if (kIsWeb && lines.isNotEmpty) {
    // Remove extra call to StackTrace.current for web platform.
    // TODO(ferhat): remove when https://github.com/flutter/flutter/issues/37635
    // is addressed.
    lines = lines.skipWhile((String line) {
      return line.contains('StackTrace.current') ||
          line.contains('dart-sdk/lib/_internal') ||
          line.contains('dart:sdk_internal');
    });
  }
  if (maxFrames != null) {
    lines = lines.take(maxFrames);
  }
  debugPrint(FlutterError.defaultStackFilter(lines).join('\n'));
}

class DiagnosticsStackTrace extends DiagnosticsBlock {
  DiagnosticsStackTrace(
    String name,
    StackTrace? stack, {
    IterableFilter<String>? stackFilter,
    super.showSeparator,
  }) : super(
          name: name,
          value: stack,
          properties: _applyStackFilter(stack, stackFilter),
          style: DiagnosticsTreeStyle.flat,
          allowTruncate: true,
        );

  DiagnosticsStackTrace.singleFrame(
    String name, {
    required String frame,
    super.showSeparator,
  }) : super(
          name: name,
          properties: <DiagnosticsNode>[_createStackFrame(frame)],
          style: DiagnosticsTreeStyle.whitespace,
        );

  static List<DiagnosticsNode> _applyStackFilter(
    StackTrace? stack,
    IterableFilter<String>? stackFilter,
  ) {
    if (stack == null) {
      return <DiagnosticsNode>[];
    }
    final IterableFilter<String> filter =
        stackFilter ?? FlutterError.defaultStackFilter;
    final Iterable<String> frames = filter(
        '${FlutterError.demangleStackTrace(stack)}'.trimRight().split('\n'));
    return frames.map<DiagnosticsNode>(_createStackFrame).toList();
  }

  static DiagnosticsNode _createStackFrame(String frame) {
    return DiagnosticsNode.message(frame, allowWrap: false);
  }

  @override
  bool get allowTruncate => false;
}

class _FlutterErrorDetailsNode extends DiagnosticableNode<FlutterErrorDetails> {
  _FlutterErrorDetailsNode({
    super.name,
    required super.value,
    required super.style,
  });

  @override
  DiagnosticPropertiesBuilder? get builder {
    final DiagnosticPropertiesBuilder? builder = super.builder;
    if (builder == null) {
      return null;
    }
    Iterable<DiagnosticsNode> properties = builder.properties;
    for (final DiagnosticPropertiesTransformer transformer
        in FlutterErrorDetails.propertiesTransformers) {
      properties = transformer(properties);
    }
    return DiagnosticPropertiesBuilder.fromProperties(properties.toList());
  }
}
