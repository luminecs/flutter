// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

import '../convert.dart';
import 'common.dart';
import 'io.dart';
import 'terminal.dart' show OutputPreferences, Terminal, TerminalColor;
import 'utils.dart';

const int kDefaultStatusPadding = 59;

class StopwatchFactory {
  const StopwatchFactory();

  Stopwatch createStopwatch([String name = '']) => Stopwatch();
}

typedef VoidCallback = void Function();

abstract class Logger {
  bool get isVerbose => false;

  bool quiet = false;

  bool get supportsColor;

  bool get hasTerminal;

  bool hadErrorOutput = false;

  bool hadWarningOutput = false;

  bool fatalWarnings = false;

  Terminal get terminal;

  OutputPreferences get _outputPreferences;

  void printError(
    String message, {
    StackTrace? stackTrace,
    bool? emphasis,
    TerminalColor? color,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  });

  void printWarning(
    String message, {
    bool? emphasis,
    TerminalColor? color,
    int? indent,
    int? hangingIndent,
    bool? wrap,
    bool fatal = true,
  });

  void printStatus(
    String message, {
    bool? emphasis,
    TerminalColor? color,
    bool? newline,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  });

  void printBox(
    String message, {
    String? title,
  });

  void printTrace(String message);

  Status startProgress(
    String message, {
    String? progressId,
    int progressIndicatorPadding = kDefaultStatusPadding,
  });

  Status startSpinner({
    VoidCallback? onFinish,
    Duration? timeout,
    SlowWarningCallback? slowWarningCallback,
    TerminalColor? warningColor,
  });

  void sendEvent(String name, [Map<String, dynamic>? args]) { }

  void clear();

  void checkForFatalLogs() {
    if (fatalWarnings && (hadWarningOutput || hadErrorOutput)) {
      throwToolExit('Logger received ${hadErrorOutput ? 'error' : 'warning'} output '
          'during the run, and "--fatal-warnings" is enabled.');
    }
  }
}

class DelegatingLogger implements Logger {
  @visibleForTesting
  @protected
  DelegatingLogger(this._delegate);

  final Logger _delegate;

  @override
  bool get quiet => _delegate.quiet;

  @override
  set quiet(bool value) => _delegate.quiet = value;

  @override
  bool get hasTerminal => _delegate.hasTerminal;

  @override
  Terminal get terminal => _delegate.terminal;

  @override
  OutputPreferences get _outputPreferences => _delegate._outputPreferences;

  @override
  bool get isVerbose => _delegate.isVerbose;

  @override
  bool get hadErrorOutput => _delegate.hadErrorOutput;

  @override
  set hadErrorOutput(bool value) => _delegate.hadErrorOutput = value;

  @override
  bool get hadWarningOutput => _delegate.hadWarningOutput;

  @override
  set hadWarningOutput(bool value) => _delegate.hadWarningOutput = value;

  @override
  bool get fatalWarnings => _delegate.fatalWarnings;

  @override
  set fatalWarnings(bool value) => _delegate.fatalWarnings = value;

  @override
  void printError(String message, {
    StackTrace? stackTrace,
    bool? emphasis,
    TerminalColor? color,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    _delegate.printError(
      message,
      stackTrace: stackTrace,
      emphasis: emphasis,
      color: color,
      indent: indent,
      hangingIndent: hangingIndent,
      wrap: wrap,
    );
  }

  @override
  void printWarning(String message, {
    bool? emphasis,
    TerminalColor? color,
    int? indent,
    int? hangingIndent,
    bool? wrap,
    bool fatal = true,
  }) {
    _delegate.printWarning(
      message,
      emphasis: emphasis,
      color: color,
      indent: indent,
      hangingIndent: hangingIndent,
      wrap: wrap,
      fatal: fatal,
    );
  }

  @override
  void printStatus(String message, {
    bool? emphasis,
    TerminalColor? color,
    bool? newline,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    _delegate.printStatus(message,
      emphasis: emphasis,
      color: color,
      newline: newline,
      indent: indent,
      hangingIndent: hangingIndent,
      wrap: wrap,
    );
  }

  @override
  void printBox(String message, {
    String? title,
  }) {
    _delegate.printBox(message, title: title);
  }

  @override
  void printTrace(String message) {
    _delegate.printTrace(message);
  }

  @override
  void sendEvent(String name, [Map<String, dynamic>? args]) {
    _delegate.sendEvent(name, args);
  }

  @override
  Status startProgress(String message, {
    String? progressId,
    int progressIndicatorPadding = kDefaultStatusPadding,
  }) {
    return _delegate.startProgress(message,
      progressId: progressId,
      progressIndicatorPadding: progressIndicatorPadding,
    );
  }

  @override
  Status startSpinner({
    VoidCallback? onFinish,
    Duration? timeout,
    SlowWarningCallback? slowWarningCallback,
    TerminalColor? warningColor,
  }) {
    return _delegate.startSpinner(
      onFinish: onFinish,
      timeout: timeout,
      slowWarningCallback: slowWarningCallback,
      warningColor: warningColor,
    );
  }

  @override
  bool get supportsColor => _delegate.supportsColor;

  @override
  void clear() => _delegate.clear();

  @override
  void checkForFatalLogs() => _delegate.checkForFatalLogs();
}

@override
T asLogger<T extends Logger>(Logger logger) {
  final Logger original = logger;
  while (true) {
    if (logger is T) {
      return logger;
    } else if (logger is DelegatingLogger) {
      logger = logger._delegate;
    } else {
      throw StateError('$original has no ancestor delegate of type $T');
    }
  }
}

class StdoutLogger extends Logger {
  StdoutLogger({
    required this.terminal,
    required Stdio stdio,
    required OutputPreferences outputPreferences,
    StopwatchFactory stopwatchFactory = const StopwatchFactory(),
  })
    : _stdio = stdio,
      _outputPreferences = outputPreferences,
      _stopwatchFactory = stopwatchFactory;

  @override
  final Terminal terminal;
  @override
  final OutputPreferences _outputPreferences;
  final Stdio _stdio;
  final StopwatchFactory _stopwatchFactory;

  Status? _status;

  @override
  bool get isVerbose => false;

  @override
  bool get supportsColor => terminal.supportsColor && terminal.isCliAnimationEnabled;

  @override
  bool get hasTerminal => _stdio.stdinHasTerminal;

  @override
  void printError(
    String message, {
    StackTrace? stackTrace,
    bool? emphasis,
    TerminalColor? color,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    hadErrorOutput = true;
    _status?.pause();
    message = wrapText(message,
      indent: indent,
      hangingIndent: hangingIndent,
      shouldWrap: wrap ?? _outputPreferences.wrapText,
      columnWidth: _outputPreferences.wrapColumn,
    );
    if (emphasis ?? false) {
      message = terminal.bolden(message);
    }
    message = terminal.color(message, color ?? TerminalColor.red);
    writeToStdErr('$message\n');
    if (stackTrace != null) {
      writeToStdErr('$stackTrace\n');
    }
    _status?.resume();
  }

  @override
  void printWarning(
    String message, {
    bool? emphasis,
    TerminalColor? color,
    int? indent,
    int? hangingIndent,
    bool? wrap,
    bool fatal = true,
  }) {
    hadWarningOutput = hadWarningOutput || fatal;
    _status?.pause();
    message = wrapText(message,
      indent: indent,
      hangingIndent: hangingIndent,
      shouldWrap: wrap ?? _outputPreferences.wrapText,
      columnWidth: _outputPreferences.wrapColumn,
    );
    if (emphasis ?? false) {
      message = terminal.bolden(message);
    }
    message = terminal.color(message, color ?? TerminalColor.cyan);
    writeToStdErr('$message\n');
    _status?.resume();
  }

  @override
  void printStatus(
    String message, {
    bool? emphasis,
    TerminalColor? color,
    bool? newline,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    _status?.pause();
    message = wrapText(message,
      indent: indent,
      hangingIndent: hangingIndent,
      shouldWrap: wrap ?? _outputPreferences.wrapText,
      columnWidth: _outputPreferences.wrapColumn,
    );
    if (emphasis ?? false) {
      message = terminal.bolden(message);
    }
    if (color != null) {
      message = terminal.color(message, color);
    }
    if (newline ?? true) {
      message = '$message\n';
    }
    writeToStdOut(message);
    _status?.resume();
  }

  @override
  void printBox(String message, {
    String? title,
  }) {
    _status?.pause();
    _generateBox(
      title: title,
      message: message,
      wrapColumn: _outputPreferences.wrapColumn,
      terminal: terminal,
      write: writeToStdOut,
    );
    _status?.resume();
  }

  @protected
  void writeToStdOut(String message) => _stdio.stdoutWrite(message);

  @protected
  void writeToStdErr(String message) => _stdio.stderrWrite(message);

  @override
  void printTrace(String message) { }

  @override
  Status startProgress(
    String message, {
    String? progressId,
    int progressIndicatorPadding = kDefaultStatusPadding,
  }) {
    if (_status != null) {
      // Ignore nested progresses; return a no-op status object.
      return SilentStatus(
        stopwatch: _stopwatchFactory.createStopwatch(),
      )..start();
    }
    if (supportsColor) {
      _status = SpinnerStatus(
        message: message,
        padding: progressIndicatorPadding,
        onFinish: _clearStatus,
        stdio: _stdio,
        stopwatch: _stopwatchFactory.createStopwatch(),
        terminal: terminal,
      )..start();
    } else {
      _status = SummaryStatus(
        message: message,
        padding: progressIndicatorPadding,
        onFinish: _clearStatus,
        stdio: _stdio,
        stopwatch: _stopwatchFactory.createStopwatch(),
      )..start();
    }
    return _status!;
  }

  @override
  Status startSpinner({
    VoidCallback? onFinish,
    Duration? timeout,
    SlowWarningCallback? slowWarningCallback,
    TerminalColor? warningColor,
  }) {
    if (_status != null || !supportsColor) {
      return SilentStatus(
        onFinish: onFinish,
        stopwatch: _stopwatchFactory.createStopwatch(),
      )..start();
    }
    _status = AnonymousSpinnerStatus(
      onFinish: () {
        if (onFinish != null) {
          onFinish();
        }
        _clearStatus();
      },
      stdio: _stdio,
      stopwatch: _stopwatchFactory.createStopwatch(),
      terminal: terminal,
      timeout: timeout,
      slowWarningCallback: slowWarningCallback,
      warningColor: warningColor,
    )..start();
    return _status!;
  }

  void _clearStatus() {
    _status = null;
  }

  @override
  void sendEvent(String name, [Map<String, dynamic>? args]) { }

  @override
  void clear() {
    _status?.pause();
    writeToStdOut('${terminal.clearScreen()}\n');
    _status?.resume();
  }
}

typedef _Writer = void Function(String message);

void _generateBox({
  required String message,
  required int wrapColumn,
  required _Writer write,
  required Terminal terminal,
  String? title,
}) {
  const int kPaddingLeftRight = 1;
  const int kEdges = 2;

  final int maxTextWidthPerLine = wrapColumn - kEdges - kPaddingLeftRight * 2;
  final List<String> lines = wrapText(message, shouldWrap: true, columnWidth: maxTextWidthPerLine).split('\n');
  final List<int> lineWidth = lines.map((String line) => _getColumnSize(line)).toList();
  final int maxColumnSize = lineWidth.reduce((int currLen, int maxLen) => max(currLen, maxLen));
  final int textWidth = min(maxColumnSize, maxTextWidthPerLine);
  final int textWithPaddingWidth = textWidth + kPaddingLeftRight * 2;

  write('\n');

  // Write `┌─ [title] ─┐`.
  write('┌');
  write('─');
  if (title == null) {
    write('─' * (textWithPaddingWidth - 1));
  } else {
    write(' ${terminal.bolden(title)} ');
    write('─' * (textWithPaddingWidth - title.length - 3));
  }
  write('┐');
  write('\n');

  // Write `│ [message] │`.
  for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
    write('│');
    write(' ' * kPaddingLeftRight);
    write(lines[lineIdx]);
    final int remainingSpacesToEnd = textWidth - lineWidth[lineIdx];
    write(' ' * (remainingSpacesToEnd + kPaddingLeftRight));
    write('│');
    write('\n');
  }

  // Write `└───────────┘`.
  write('└');
  write('─' * textWithPaddingWidth);
  write('┘');
  write('\n');
}

final RegExp _ansiEscapePattern = RegExp('\x1B\\[[\x30-\x3F]*[\x20-\x2F]*[\x40-\x7E]');

int _getColumnSize(String line) {
  // Remove ANSI escape characters from the string.
  return line.replaceAll(_ansiEscapePattern, '').length;
}

class WindowsStdoutLogger extends StdoutLogger {
  WindowsStdoutLogger({
    required super.terminal,
    required super.stdio,
    required super.outputPreferences,
    super.stopwatchFactory,
  });

  @override
  void writeToStdOut(String message) {
    final String windowsMessage = terminal.supportsEmoji
      ? message
      : message.replaceAll('🔥', '')
               .replaceAll('🖼️', '')
               .replaceAll('✗', 'X')
               .replaceAll('✓', '√')
               .replaceAll('🔨', '')
               .replaceAll('💪', '')
               .replaceAll('⚠️', '!')
               .replaceAll('✏️', '');
    _stdio.stdoutWrite(windowsMessage);
  }
}

class BufferLogger extends Logger {
  BufferLogger({
    required this.terminal,
    required OutputPreferences outputPreferences,
    StopwatchFactory stopwatchFactory = const StopwatchFactory(),
    bool verbose = false,
  }) : _outputPreferences = outputPreferences,
       _stopwatchFactory = stopwatchFactory,
       _verbose = verbose;

  BufferLogger.test({
    Terminal? terminal,
    OutputPreferences? outputPreferences,
    bool verbose = false,
  }) : terminal = terminal ?? Terminal.test(),
       _outputPreferences = outputPreferences ?? OutputPreferences.test(),
       _stopwatchFactory = const StopwatchFactory(),
       _verbose = verbose;

  @override
  final OutputPreferences _outputPreferences;

  @override
  final Terminal terminal;

  final StopwatchFactory _stopwatchFactory;

  final bool _verbose;

  @override
  bool get isVerbose => _verbose;

  @override
  bool get supportsColor => terminal.supportsColor && terminal.isCliAnimationEnabled;

  final StringBuffer _error = StringBuffer();
  final StringBuffer _warning = StringBuffer();
  final StringBuffer _status = StringBuffer();
  final StringBuffer _trace = StringBuffer();
  final StringBuffer _events = StringBuffer();

  String get errorText => _error.toString();
  String get warningText => _warning.toString();
  String get statusText => _status.toString();
  String get traceText => _trace.toString();
  String get eventText => _events.toString();

  @override
  bool get hasTerminal => false;

  @override
  void printError(
    String message, {
    StackTrace? stackTrace,
    bool? emphasis,
    TerminalColor? color,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    hadErrorOutput = true;
    final StringBuffer errorMessage = StringBuffer();
    errorMessage.write(message);
    if (stackTrace != null) {
      errorMessage.writeln();
      errorMessage.write(stackTrace);
    }
    _error.writeln(terminal.color(
      wrapText(errorMessage.toString(),
        indent: indent,
        hangingIndent: hangingIndent,
        shouldWrap: wrap ?? _outputPreferences.wrapText,
        columnWidth: _outputPreferences.wrapColumn,
      ),
      color ?? TerminalColor.red,
    ));
  }

  @override
  void printWarning(
    String message, {
    bool? emphasis,
    TerminalColor? color,
    int? indent,
    int? hangingIndent,
    bool? wrap,
    bool fatal = true,
  }) {
    hadWarningOutput = hadWarningOutput || fatal;
    _warning.writeln(terminal.color(
      wrapText(message,
        indent: indent,
        hangingIndent: hangingIndent,
        shouldWrap: wrap ?? _outputPreferences.wrapText,
        columnWidth: _outputPreferences.wrapColumn,
      ),
      color ?? TerminalColor.cyan,
    ));
  }

  @override
  void printStatus(
    String message, {
    bool? emphasis,
    TerminalColor? color,
    bool? newline,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    if (newline ?? true) {
      _status.writeln(wrapText(message,
        indent: indent,
        hangingIndent: hangingIndent,
        shouldWrap: wrap ?? _outputPreferences.wrapText,
        columnWidth: _outputPreferences.wrapColumn,
      ));
    } else {
      _status.write(wrapText(message,
        indent: indent,
        hangingIndent: hangingIndent,
        shouldWrap: wrap ?? _outputPreferences.wrapText,
        columnWidth: _outputPreferences.wrapColumn,
      ));
    }
  }

  @override
  void printBox(String message, {
    String? title,
  }) {
    _generateBox(
      title: title,
      message: message,
      wrapColumn: _outputPreferences.wrapColumn,
      terminal: terminal,
      write: _status.write,
    );
  }

  @override
  void printTrace(String message) => _trace.writeln(message);

  @override
  Status startProgress(
    String message, {
    String? progressId,
    int progressIndicatorPadding = kDefaultStatusPadding,
  }) {
    printStatus(message);
    return SilentStatus(
      stopwatch: _stopwatchFactory.createStopwatch(),
    )..start();
  }

  @override
  Status startSpinner({
    VoidCallback? onFinish,
    Duration? timeout,
    SlowWarningCallback? slowWarningCallback,
    TerminalColor? warningColor,
  }) {
    return SilentStatus(
      stopwatch: _stopwatchFactory.createStopwatch(),
      onFinish: onFinish,
    )..start();
  }

  @override
  void clear() {
    _error.clear();
    _status.clear();
    _trace.clear();
    _events.clear();
  }

  @override
  void sendEvent(String name, [Map<String, dynamic>? args]) {
    _events.write(json.encode(<String, Object?>{
      'name': name,
      'args': args,
    }));
  }
}

class VerboseLogger extends DelegatingLogger {
  VerboseLogger(super.parent, {
    StopwatchFactory stopwatchFactory = const StopwatchFactory()
  }) : _stopwatch = stopwatchFactory.createStopwatch(),
       _stopwatchFactory = stopwatchFactory {
    _stopwatch.start();
  }

  final Stopwatch _stopwatch;

  final StopwatchFactory _stopwatchFactory;

  @override
  bool get isVerbose => true;

  @override
  void printError(
    String message, {
    StackTrace? stackTrace,
    bool? emphasis,
    TerminalColor? color,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    hadErrorOutput = true;
    _emit(
      _LogType.error,
      wrapText(message,
        indent: indent,
        hangingIndent: hangingIndent,
        shouldWrap: wrap ?? _outputPreferences.wrapText,
        columnWidth: _outputPreferences.wrapColumn,
      ),
      stackTrace,
    );
  }

  @override
  void printWarning(
      String message, {
        StackTrace? stackTrace,
        bool? emphasis,
        TerminalColor? color,
        int? indent,
        int? hangingIndent,
        bool? wrap,
        bool fatal = true,
      }) {
    hadWarningOutput = true;
    _emit(
      _LogType.warning,
      wrapText(message,
        indent: indent,
        hangingIndent: hangingIndent,
        shouldWrap: wrap ?? _outputPreferences.wrapText,
        columnWidth: _outputPreferences.wrapColumn,
      ),
      stackTrace,
    );
  }

  @override
  void printStatus(
    String message, {
    bool? emphasis,
    TerminalColor? color,
    bool? newline,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    _emit(_LogType.status, wrapText(message,
      indent: indent,
      hangingIndent: hangingIndent,
      shouldWrap: wrap ?? _outputPreferences.wrapText,
      columnWidth: _outputPreferences.wrapColumn,
    ));
  }

  @override
  void printBox(String message, {
    String? title,
  }) {
    String composedMessage = '';
    _generateBox(
      title: title,
      message: message,
      wrapColumn: _outputPreferences.wrapColumn,
      terminal: terminal,
      write: (String line) {
        composedMessage += line;
      },
    );
    _emit(_LogType.status, composedMessage);
  }

  @override
  void printTrace(String message) {
    _emit(_LogType.trace, message);
  }

  @override
  Status startProgress(
    String message, {
    String? progressId,
    int progressIndicatorPadding = kDefaultStatusPadding,
  }) {
    printStatus(message);
    final Stopwatch timer = _stopwatchFactory.createStopwatch()..start();
    return SilentStatus(
      // This is intentionally a different stopwatch than above.
      stopwatch: _stopwatchFactory.createStopwatch(),
      onFinish: () {
        String time;
        if (timer.elapsed.inSeconds > 2) {
          time = getElapsedAsSeconds(timer.elapsed);
        } else {
          time = getElapsedAsMilliseconds(timer.elapsed);
        }
        printTrace('$message (completed in $time)');
      },
    )..start();
  }

  void _emit(_LogType type, String message, [ StackTrace? stackTrace ]) {
    if (message.trim().isEmpty) {
      return;
    }

    final int millis = _stopwatch.elapsedMilliseconds;
    _stopwatch.reset();

    String prefix;
    const int prefixWidth = 8;
    if (millis == 0) {
      prefix = ''.padLeft(prefixWidth);
    } else {
      prefix = '+$millis ms'.padLeft(prefixWidth);
      if (millis >= 100) {
        prefix = terminal.bolden(prefix);
      }
    }
    prefix = '[$prefix] ';

    final String indent = ''.padLeft(prefix.length);
    final String indentMessage = message.replaceAll('\n', '\n$indent');

    switch (type) {
      case _LogType.error:
        super.printError(prefix + terminal.bolden(indentMessage));
        if (stackTrace != null) {
          super.printError(indent + stackTrace.toString().replaceAll('\n', '\n$indent'));
        }
      case _LogType.warning:
        super.printWarning(prefix + terminal.bolden(indentMessage));
      case _LogType.status:
        super.printStatus(prefix + terminal.bolden(indentMessage));
      case _LogType.trace:
        // This seems wrong, since there is a 'printTrace' to call on the
        // superclass, but it's actually the entire point of this logger: to
        // make things more verbose than they normally would be.
        super.printStatus(prefix + indentMessage);
    }
  }

  @override
  void sendEvent(String name, [Map<String, dynamic>? args]) { }
}

class PrefixedErrorLogger extends DelegatingLogger {
  PrefixedErrorLogger(super.parent);

  @override
  void printError(
    String message, {
    StackTrace? stackTrace,
    bool? emphasis,
    TerminalColor? color,
    int? indent,
    int? hangingIndent,
    bool? wrap,
  }) {
    hadErrorOutput = true;
    if (message.trim().isNotEmpty) {
      message = 'ERROR: $message';
    }
    super.printError(
      message,
      stackTrace: stackTrace,
      emphasis: emphasis,
      color: color,
      indent: indent,
      hangingIndent: hangingIndent,
      wrap: wrap,
    );
  }
}

enum _LogType { error, warning, status, trace }

typedef SlowWarningCallback = String Function();

abstract class Status {
  Status({
    this.onFinish,
    required Stopwatch stopwatch,
    this.timeout,
  }) : _stopwatch = stopwatch;

  final VoidCallback? onFinish;
  final Duration? timeout;

  @protected
  final Stopwatch _stopwatch;

  @protected
  String get elapsedTime {
    if (_stopwatch.elapsed.inSeconds > 2) {
      return getElapsedAsSeconds(_stopwatch.elapsed);
    }
    return getElapsedAsMilliseconds(_stopwatch.elapsed);
  }

  @visibleForTesting
  bool get seemsSlow => timeout != null && _stopwatch.elapsed > timeout!;

  void start() {
    assert(!_stopwatch.isRunning);
    _stopwatch.start();
  }

  void stop() {
    finish();
  }

  void cancel() {
    finish();
  }

  void pause() { }

  void resume() { }

  @protected
  void finish() {
    assert(_stopwatch.isRunning);
    _stopwatch.stop();
    onFinish?.call();
  }
}

class SilentStatus extends Status {
  SilentStatus({
    required super.stopwatch,
    super.onFinish,
  });

  @override
  void finish() {
    onFinish?.call();
  }
}

const int _kTimePadding = 8; // should fit "99,999ms"

class SummaryStatus extends Status {
  SummaryStatus({
    this.message = '',
    required super.stopwatch,
    this.padding = kDefaultStatusPadding,
    super.onFinish,
    required Stdio stdio,
  }) : _stdio = stdio;

  final String message;
  final int padding;
  final Stdio _stdio;

  bool _messageShowingOnCurrentLine = false;

  @override
  void start() {
    _printMessage();
    super.start();
  }

  void _writeToStdOut(String message) => _stdio.stdoutWrite(message);

  void _printMessage() {
    assert(!_messageShowingOnCurrentLine);
    _writeToStdOut('${message.padRight(padding)}     ');
    _messageShowingOnCurrentLine = true;
  }

  @override
  void stop() {
    if (!_messageShowingOnCurrentLine) {
      _printMessage();
    }
    super.stop();
    assert(_messageShowingOnCurrentLine);
    _writeToStdOut(elapsedTime.padLeft(_kTimePadding));
    _writeToStdOut('\n');
  }

  @override
  void cancel() {
    super.cancel();
    if (_messageShowingOnCurrentLine) {
      _writeToStdOut('\n');
    }
  }

  @override
  void pause() {
    super.pause();
    if (_messageShowingOnCurrentLine) {
      _writeToStdOut('\n');
      _messageShowingOnCurrentLine = false;
    }
  }
}

class AnonymousSpinnerStatus extends Status {
  AnonymousSpinnerStatus({
    super.onFinish,
    required super.stopwatch,
    required Stdio stdio,
    required Terminal terminal,
    this.slowWarningCallback,
    this.warningColor,
    super.timeout,
  }) : _stdio = stdio,
       _terminal = terminal,
       _animation = _selectAnimation(terminal);

  final Stdio _stdio;
  final Terminal _terminal;
  String _slowWarning = '';
  final SlowWarningCallback? slowWarningCallback;
  final TerminalColor? warningColor;

  static const String _backspaceChar = '\b';
  static const String _clearChar = ' ';

  static const List<String> _emojiAnimations = <String>[
    '⣾⣽⣻⢿⡿⣟⣯⣷', // counter-clockwise
    '⣾⣷⣯⣟⡿⢿⣻⣽', // clockwise
    '⣾⣷⣯⣟⡿⢿⣻⣽⣷⣾⣽⣻⢿⡿⣟⣯⣷', // bouncing clockwise and counter-clockwise
    '⣾⣷⣯⣽⣻⣟⡿⢿⣻⣟⣯⣽', // snaking
    '⣾⣽⣻⢿⣿⣷⣯⣟⡿⣿', // alternating rain
    '⣀⣠⣤⣦⣶⣾⣿⡿⠿⠻⠛⠋⠉⠙⠛⠟⠿⢿⣿⣷⣶⣴⣤⣄', // crawl up and down, large
    '⠙⠚⠖⠦⢤⣠⣄⡤⠴⠲⠓⠋', // crawl up and down, small
    '⣀⡠⠤⠔⠒⠊⠉⠑⠒⠢⠤⢄', // crawl up and down, tiny
    '⡀⣄⣦⢷⠻⠙⠈⠀⠁⠋⠟⡾⣴⣠⢀⠀', // slide up and down
    '⠙⠸⢰⣠⣄⡆⠇⠋', // clockwise line
    '⠁⠈⠐⠠⢀⡀⠄⠂', // clockwise dot
    '⢇⢣⢱⡸⡜⡎', // vertical wobble up
    '⡇⡎⡜⡸⢸⢱⢣⢇', // vertical wobble down
    '⡀⣀⣐⣒⣖⣶⣾⣿⢿⠿⠯⠭⠩⠉⠁⠀', // swirl
    '⠁⠐⠄⢀⢈⢂⢠⣀⣁⣐⣄⣌⣆⣤⣥⣴⣼⣶⣷⣿⣾⣶⣦⣤⣠⣀⡀⠀⠀', // snowing and melting
    '⠁⠋⠞⡴⣠⢀⠀⠈⠙⠻⢷⣦⣄⡀⠀⠉⠛⠲⢤⢀⠀', // falling water
    '⠄⡢⢑⠈⠀⢀⣠⣤⡶⠞⠋⠁⠀⠈⠙⠳⣆⡀⠀⠆⡷⣹⢈⠀⠐⠪⢅⡀⠀', // fireworks
    '⠐⢐⢒⣒⣲⣶⣷⣿⡿⡷⡧⠧⠇⠃⠁⠀⡀⡠⡡⡱⣱⣳⣷⣿⢿⢯⢧⠧⠣⠃⠂⠀⠈⠨⠸⠺⡺⡾⡿⣿⡿⡷⡗⡇⡅⡄⠄⠀⡀⡐⣐⣒⣓⣳⣻⣿⣾⣼⡼⡸⡘⡈⠈⠀', // fade
    '⢸⡯⠭⠅⢸⣇⣀⡀⢸⣇⣸⡇⠈⢹⡏⠁⠈⢹⡏⠁⢸⣯⣭⡅⢸⡯⢕⡂⠀⠀', // text crawl
  ];

  static const List<String> _asciiAnimations = <String>[
    r'-\|/',
  ];

  static List<String> _selectAnimation(Terminal terminal) {
    final List<String> animations = terminal.supportsEmoji ? _emojiAnimations : _asciiAnimations;
    return animations[terminal.preferredStyle % animations.length]
      .runes
      .map<String>((int scalar) => String.fromCharCode(scalar))
      .toList();
  }

  final List<String> _animation;

  Timer? timer;
  int ticks = 0;
  int _lastAnimationFrameLength = 0;
  bool timedOut = false;

  String get _currentAnimationFrame => _animation[ticks % _animation.length];
  int get _currentLineLength => _lastAnimationFrameLength + _slowWarning.length;

  void _writeToStdOut(String message) => _stdio.stdoutWrite(message);

  void _clear(int length) {
    _writeToStdOut(
      '${_backspaceChar * length}'
      '${_clearChar * length}'
      '${_backspaceChar * length}'
    );
  }

  @override
  void start() {
    super.start();
    assert(timer == null);
    _startSpinner();
  }

  void _startSpinner() {
    timer = Timer.periodic(const Duration(milliseconds: 100), _callback);
    _callback(timer!);
  }

  void _callback(Timer timer) {
    assert(this.timer == timer);
    assert(timer.isActive);
    _writeToStdOut(_backspaceChar * _lastAnimationFrameLength);
    ticks += 1;
    if (seemsSlow) {
      if (!timedOut) {
        timedOut = true;
        if (_currentLineLength > _lastAnimationFrameLength) {
          _clear(_currentLineLength - _lastAnimationFrameLength);
        }
      }
      final SlowWarningCallback? callback = slowWarningCallback;
      if (_slowWarning.isEmpty && callback != null) {
        final TerminalColor? color = warningColor;
        if (color != null) {
          _slowWarning = _terminal.color(callback(), color);
        } else {
          _slowWarning = callback();
        }

        _writeToStdOut(_slowWarning);
      }
    }
    final String newFrame = _currentAnimationFrame;
    _lastAnimationFrameLength = newFrame.runes.length;
    _writeToStdOut(newFrame);
  }

  @override
  void pause() {
    assert(timer != null);
    assert(timer!.isActive);
    if (_terminal.supportsColor) {
      _writeToStdOut('\r\x1B[K'); // go to start of line and clear line
    } else {
      _clear(_currentLineLength);
    }
    _lastAnimationFrameLength = 0;
    timer?.cancel();
  }

  @override
  void resume() {
    assert(timer != null);
    assert(!timer!.isActive);
    _startSpinner();
  }

  @override
  void finish() {
    assert(timer != null);
    assert(timer!.isActive);
    timer?.cancel();
    timer = null;
    _clear(_lastAnimationFrameLength + _slowWarning.length);
    _slowWarning = '';
    _lastAnimationFrameLength = 0;
    super.finish();
  }
}

class SpinnerStatus extends AnonymousSpinnerStatus {
  SpinnerStatus({
    required this.message,
    this.padding = kDefaultStatusPadding,
    super.onFinish,
    required super.stopwatch,
    required super.stdio,
    required super.terminal,
  });

  final String message;
  final int padding;

  static final String _margin = AnonymousSpinnerStatus._clearChar * (5 + _kTimePadding - 1);

  int _totalMessageLength = 0;

  @override
  int get _currentLineLength => _totalMessageLength + super._currentLineLength;

  @override
  void start() {
    _printStatus();
    super.start();
  }

  void _printStatus() {
    final String line = '${message.padRight(padding)}$_margin';
    _totalMessageLength = line.length;
    _writeToStdOut(line);
  }

  @override
  void pause() {
    super.pause();
    _totalMessageLength = 0;
  }

  @override
  void resume() {
    _printStatus();
    super.resume();
  }

  @override
  void stop() {
    super.stop(); // calls finish, which clears the spinner
    assert(_totalMessageLength > _kTimePadding);
    _writeToStdOut(AnonymousSpinnerStatus._backspaceChar * (_kTimePadding - 1));
    _writeToStdOut(elapsedTime.padLeft(_kTimePadding));
    _writeToStdOut('\n');
  }

  @override
  void cancel() {
    super.cancel(); // calls finish, which clears the spinner
    assert(_totalMessageLength > 0);
    _writeToStdOut('\n');
  }
}