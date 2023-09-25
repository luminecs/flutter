import '../convert.dart';
import 'io.dart' as io;
import 'logger.dart';
import 'platform.dart';

enum TerminalColor {
  red,
  green,
  blue,
  cyan,
  yellow,
  magenta,
  grey,
}

class OutputPreferences {
  OutputPreferences({
    bool? wrapText,
    int? wrapColumn,
    bool? showColor,
    io.Stdio? stdio,
  }) : _stdio = stdio,
       wrapText = wrapText ?? stdio?.hasTerminal ?? false,
       _overrideWrapColumn = wrapColumn,
       showColor = showColor ?? false;

  OutputPreferences.test({this.wrapText = false, int wrapColumn = kDefaultTerminalColumns, this.showColor = false})
    : _overrideWrapColumn = wrapColumn, _stdio = null;

  final io.Stdio? _stdio;

  final bool wrapText;

  static const int kDefaultTerminalColumns = 100;

  final int? _overrideWrapColumn;
  int get wrapColumn {
    return _overrideWrapColumn ?? _stdio?.terminalColumns ?? kDefaultTerminalColumns;
  }

  final bool showColor;

  @override
  String toString() {
    return '$runtimeType[wrapText: $wrapText, wrapColumn: $wrapColumn, showColor: $showColor]';
  }
}

abstract class Terminal {
  factory Terminal.test({bool supportsColor, bool supportsEmoji}) = _TestTerminal;

  bool get supportsColor;

  bool get isCliAnimationEnabled;

  bool get supportsEmoji;

  int get preferredStyle;

  bool get usesTerminalUi;
  set usesTerminalUi(bool value);

  bool get stdinHasTerminal;

  String get warningMark;

  String get successMark;

  String bolden(String message);

  String color(String message, TerminalColor color);

  String clearScreen();

  bool get singleCharMode;
  set singleCharMode(bool value);

  Stream<String> get keystrokes;

  Future<String> promptForCharInput(
    List<String> acceptedCharacters, {
    required Logger logger,
    String? prompt,
    int? defaultChoiceIndex,
    bool displayAcceptedCharacters = true,
  });
}

class AnsiTerminal implements Terminal {
  AnsiTerminal({
    required io.Stdio stdio,
    required Platform platform,
    DateTime? now, // Time used to determine preferredStyle. Defaults to 0001-01-01 00:00.
    this.isCliAnimationEnabled = true,
  })
    : _stdio = stdio,
      _platform = platform,
      _now = now ?? DateTime(1);

  final io.Stdio _stdio;
  final Platform _platform;
  final DateTime _now;

  static const String bold = '\u001B[1m';
  static const String resetAll = '\u001B[0m';
  static const String resetColor = '\u001B[39m';
  static const String resetBold = '\u001B[22m';
  static const String clear = '\u001B[2J\u001B[H';

  static const String red = '\u001b[31m';
  static const String green = '\u001b[32m';
  static const String blue = '\u001b[34m';
  static const String cyan = '\u001b[36m';
  static const String magenta = '\u001b[35m';
  static const String yellow = '\u001b[33m';
  static const String grey = '\u001b[90m';

  // Moves cursor up 1 line.
  static const String cursorUpLineCode = '\u001b[1A';

  // Moves cursor to the beginning of the line.
  static const String cursorBeginningOfLineCode = '\u001b[1G';

  // Clear the entire line, cursor position does not change.
  static const String clearEntireLineCode = '\u001b[2K';

  static const Map<TerminalColor, String> _colorMap = <TerminalColor, String>{
    TerminalColor.red: red,
    TerminalColor.green: green,
    TerminalColor.blue: blue,
    TerminalColor.cyan: cyan,
    TerminalColor.magenta: magenta,
    TerminalColor.yellow: yellow,
    TerminalColor.grey: grey,
  };

  static String colorCode(TerminalColor color) => _colorMap[color]!;

  @override
  bool get supportsColor => _platform.stdoutSupportsAnsi;

  @override
  final bool isCliAnimationEnabled;

  // Assume unicode emojis are supported when not on Windows.
  // If we are on Windows, unicode emojis are supported in Windows Terminal,
  // which sets the WT_SESSION environment variable. See:
  // https://github.com/microsoft/terminal/blob/master/doc/user-docs/index.md#tips-and-tricks
  @override
  bool get supportsEmoji => !_platform.isWindows
    || _platform.environment.containsKey('WT_SESSION');

  @override
  int get preferredStyle {
    const int workdays = DateTime.friday;
    if (_now.weekday <= workdays) {
      return _now.weekday - 1;
    }
    return _now.hour + workdays;
  }

  final RegExp _boldControls = RegExp(
    '(${RegExp.escape(resetBold)}|${RegExp.escape(bold)})',
  );

  @override
  bool usesTerminalUi = false;

  @override
  String get warningMark {
    return bolden(color('[!]', TerminalColor.red));
  }

  @override
  String get successMark {
    return bolden(color('✓', TerminalColor.green));
  }

  @override
  String bolden(String message) {
    if (!supportsColor || message.isEmpty) {
      return message;
    }
    final StringBuffer buffer = StringBuffer();
    for (String line in message.split('\n')) {
      // If there were bolds or resetBolds in the string before, then nuke them:
      // they're redundant. This prevents previously embedded resets from
      // stopping the boldness.
      line = line.replaceAll(_boldControls, '');
      buffer.writeln('$bold$line$resetBold');
    }
    final String result = buffer.toString();
    // avoid introducing a new newline to the emboldened text
    return (!message.endsWith('\n') && result.endsWith('\n'))
        ? result.substring(0, result.length - 1)
        : result;
  }

  @override
  String color(String message, TerminalColor color) {
    if (!supportsColor || message.isEmpty) {
      return message;
    }
    final StringBuffer buffer = StringBuffer();
    final String colorCodes = _colorMap[color]!;
    for (String line in message.split('\n')) {
      // If there were resets in the string before, then keep them, but
      // restart the color right after. This prevents embedded resets from
      // stopping the colors, and allows nesting of colors.
      line = line.replaceAll(resetColor, '$resetColor$colorCodes');
      buffer.writeln('$colorCodes$line$resetColor');
    }
    final String result = buffer.toString();
    // avoid introducing a new newline to the colored text
    return (!message.endsWith('\n') && result.endsWith('\n'))
        ? result.substring(0, result.length - 1)
        : result;
  }

  @override
  String clearScreen() => supportsColor && isCliAnimationEnabled ? clear : '\n\n';

  String clearLines(int numberOfLines) {
    if (!supportsColor || !isCliAnimationEnabled) {
      return '';
    }
    return cursorBeginningOfLineCode +
        clearEntireLineCode +
        (cursorUpLineCode + clearEntireLineCode) * (numberOfLines - 1);
  }

  @override
  bool get singleCharMode {
    if (!_stdio.stdinHasTerminal) {
      return false;
    }
    final io.Stdin stdin = _stdio.stdin as io.Stdin;
    return stdin.lineMode && stdin.echoMode;
  }
  @override
  set singleCharMode(bool value) {
    if (!_stdio.stdinHasTerminal) {
      return;
    }
    final io.Stdin stdin = _stdio.stdin as io.Stdin;
    // The order of setting lineMode and echoMode is important on Windows.
    if (value) {
      stdin.echoMode = false;
      stdin.lineMode = false;
    } else {
      stdin.lineMode = true;
      stdin.echoMode = true;
    }
  }

  @override
  bool get stdinHasTerminal => _stdio.stdinHasTerminal;

  Stream<String>? _broadcastStdInString;

  @override
  Stream<String> get keystrokes {
    return _broadcastStdInString ??= _stdio.stdin.transform<String>(const AsciiDecoder(allowInvalid: true)).asBroadcastStream();
  }

  @override
  Future<String> promptForCharInput(
    List<String> acceptedCharacters, {
    required Logger logger,
    String? prompt,
    int? defaultChoiceIndex,
    bool displayAcceptedCharacters = true,
  }) async {
    assert(acceptedCharacters.isNotEmpty);
    assert(prompt == null || prompt.isNotEmpty);
    if (!usesTerminalUi) {
      throw StateError('cannot prompt without a terminal ui');
    }
    List<String> charactersToDisplay = acceptedCharacters;
    if (defaultChoiceIndex != null) {
      assert(defaultChoiceIndex >= 0 && defaultChoiceIndex < acceptedCharacters.length);
      charactersToDisplay = List<String>.of(charactersToDisplay);
      charactersToDisplay[defaultChoiceIndex] = bolden(charactersToDisplay[defaultChoiceIndex]);
      acceptedCharacters.add('');
    }
    String? choice;
    singleCharMode = true;
    while (choice == null || choice.length > 1 || !acceptedCharacters.contains(choice)) {
      if (prompt != null) {
        logger.printStatus(prompt, emphasis: true, newline: false);
        if (displayAcceptedCharacters) {
          logger.printStatus(' [${charactersToDisplay.join("|")}]', newline: false);
        }
        // prompt ends with ': '
        logger.printStatus(': ', emphasis: true, newline: false);
      }
      choice = (await keystrokes.first).trim();
      logger.printStatus(choice);
    }
    singleCharMode = false;
    if (defaultChoiceIndex != null && choice == '') {
      choice = acceptedCharacters[defaultChoiceIndex];
    }
    return choice;
  }
}

class _TestTerminal implements Terminal {
  _TestTerminal({this.supportsColor = false, this.supportsEmoji = false});

  @override
  bool usesTerminalUi = false;

  @override
  String bolden(String message) => message;

  @override
  String clearScreen() => '\n\n';

  @override
  String color(String message, TerminalColor color) => message;

  @override
  Stream<String> get keystrokes => const Stream<String>.empty();

  @override
  Future<String> promptForCharInput(List<String> acceptedCharacters, {
    required Logger logger,
    String? prompt,
    int? defaultChoiceIndex,
    bool displayAcceptedCharacters = true,
  }) {
    throw UnsupportedError('promptForCharInput not supported in the test terminal.');
  }

  @override
  bool get singleCharMode => false;
  @override
  set singleCharMode(bool value) { }

  @override
  final bool supportsColor;

  @override
  bool get isCliAnimationEnabled => supportsColor;

  @override
  final bool supportsEmoji;

  @override
  int get preferredStyle => 0;

  @override
  bool get stdinHasTerminal => false;

  @override
  String get successMark => '✓';

  @override
  String get warningMark => '[!]';
}