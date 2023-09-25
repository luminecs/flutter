// This file implements debugPrint in terms of print, so avoiding
// calling "print" is sort of a non-starter here...
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:collection';

typedef DebugPrintCallback = void Function(String? message, { int? wrapWidth });

DebugPrintCallback debugPrint = debugPrintThrottled;

void debugPrintSynchronously(String? message, { int? wrapWidth }) {
  if (message != null && wrapWidth != null) {
    print(message.split('\n').expand<String>((String line) => debugWordWrap(line, wrapWidth)).join('\n'));
  } else {
    print(message);
  }
}

void debugPrintThrottled(String? message, { int? wrapWidth }) {
  final List<String> messageLines = message?.split('\n') ?? <String>['null'];
  if (wrapWidth != null) {
    _debugPrintBuffer.addAll(messageLines.expand<String>((String line) => debugWordWrap(line, wrapWidth)));
  } else {
    _debugPrintBuffer.addAll(messageLines);
  }
  if (!_debugPrintScheduled) {
    _debugPrintTask();
  }
}
int _debugPrintedCharacters = 0;
const int _kDebugPrintCapacity = 12 * 1024;
const Duration _kDebugPrintPauseTime = Duration(seconds: 1);
final Queue<String> _debugPrintBuffer = Queue<String>();
final Stopwatch _debugPrintStopwatch = Stopwatch();
Completer<void>? _debugPrintCompleter;
bool _debugPrintScheduled = false;
void _debugPrintTask() {
  _debugPrintScheduled = false;
  if (_debugPrintStopwatch.elapsed > _kDebugPrintPauseTime) {
    _debugPrintStopwatch.stop();
    _debugPrintStopwatch.reset();
    _debugPrintedCharacters = 0;
  }
  while (_debugPrintedCharacters < _kDebugPrintCapacity && _debugPrintBuffer.isNotEmpty) {
    final String line = _debugPrintBuffer.removeFirst();
    _debugPrintedCharacters += line.length; // TODO(ianh): Use the UTF-8 byte length instead
    print(line);
  }
  if (_debugPrintBuffer.isNotEmpty) {
    _debugPrintScheduled = true;
    _debugPrintedCharacters = 0;
    Timer(_kDebugPrintPauseTime, _debugPrintTask);
    _debugPrintCompleter ??= Completer<void>();
  } else {
    _debugPrintStopwatch.start();
    _debugPrintCompleter?.complete();
    _debugPrintCompleter = null;
  }
}

Future<void> get debugPrintDone => _debugPrintCompleter?.future ?? Future<void>.value();

final RegExp _indentPattern = RegExp('^ *(?:[-+*] |[0-9]+[.):] )?');
enum _WordWrapParseMode { inSpace, inWord, atBreak }

Iterable<String> debugWordWrap(String message, int width, { String wrapIndent = '' }) {
  if (message.length < width || message.trimLeft()[0] == '#') {
    return <String>[message];
  }
  final List<String> wrapped = <String>[];
  final Match prefixMatch = _indentPattern.matchAsPrefix(message)!;
  final String prefix = wrapIndent + ' ' * prefixMatch.group(0)!.length;
  int start = 0;
  int startForLengthCalculations = 0;
  bool addPrefix = false;
  int index = prefix.length;
  _WordWrapParseMode mode = _WordWrapParseMode.inSpace;
  late int lastWordStart;
  int? lastWordEnd;
  while (true) {
    switch (mode) {
      case _WordWrapParseMode.inSpace: // at start of break point (or start of line); can't break until next break
        while ((index < message.length) && (message[index] == ' ')) {
          index += 1;
        }
        lastWordStart = index;
        mode = _WordWrapParseMode.inWord;
      case _WordWrapParseMode.inWord: // looking for a good break point
        while ((index < message.length) && (message[index] != ' ')) {
          index += 1;
        }
        mode = _WordWrapParseMode.atBreak;
      case _WordWrapParseMode.atBreak: // at start of break point
        if ((index - startForLengthCalculations > width) || (index == message.length)) {
          // we are over the width line, so break
          if ((index - startForLengthCalculations <= width) || (lastWordEnd == null)) {
            // we should use this point, because either it doesn't actually go over the
            // end (last line), or it does, but there was no earlier break point
            lastWordEnd = index;
          }
          if (addPrefix) {
            wrapped.add(prefix + message.substring(start, lastWordEnd));
          } else {
            wrapped.add(message.substring(start, lastWordEnd));
            addPrefix = true;
          }
          if (lastWordEnd >= message.length) {
            return wrapped;
          }
          // just yielded a line
          if (lastWordEnd == index) {
            // we broke at current position
            // eat all the spaces, then set our start point
            while ((index < message.length) && (message[index] == ' ')) {
              index += 1;
            }
            start = index;
            mode = _WordWrapParseMode.inWord;
          } else {
            // we broke at the previous break point, and we're at the start of a new one
            assert(lastWordStart > lastWordEnd);
            start = lastWordStart;
            mode = _WordWrapParseMode.atBreak;
          }
          startForLengthCalculations = start - prefix.length;
          assert(addPrefix);
          lastWordEnd = null;
        } else {
          // save this break point, we're not yet over the line width
          lastWordEnd = index;
          // skip to the end of this break point
          mode = _WordWrapParseMode.inSpace;
        }
    }
  }
}