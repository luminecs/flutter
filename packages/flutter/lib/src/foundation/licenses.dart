import 'dart:async';

import 'package:meta/meta.dart' show visibleForTesting;

typedef LicenseEntryCollector = Stream<LicenseEntry> Function();

class LicenseParagraph {
  const LicenseParagraph(this.text, this.indent);

  final String text;

  final int indent; // can be set to centeredIndent

  static const int centeredIndent = -1;
}

abstract class LicenseEntry {
  const LicenseEntry();

  Iterable<String> get packages;

  Iterable<LicenseParagraph> get paragraphs;
}

enum _LicenseEntryWithLineBreaksParserState {
  beforeParagraph,
  inParagraph,
}

class LicenseEntryWithLineBreaks extends LicenseEntry {
  const LicenseEntryWithLineBreaks(this.packages, this.text);

  @override
  final List<String> packages;

  final String text;

  @override
  Iterable<LicenseParagraph> get paragraphs {
    int lineStart = 0;
    int currentPosition = 0;
    int lastLineIndent = 0;
    int currentLineIndent = 0;
    int? currentParagraphIndentation;
    _LicenseEntryWithLineBreaksParserState state =
        _LicenseEntryWithLineBreaksParserState.beforeParagraph;
    final List<String> lines = <String>[];
    final List<LicenseParagraph> result = <LicenseParagraph>[];

    void addLine() {
      assert(lineStart < currentPosition);
      lines.add(text.substring(lineStart, currentPosition));
    }

    LicenseParagraph getParagraph() {
      assert(lines.isNotEmpty);
      assert(currentParagraphIndentation != null);
      final LicenseParagraph result =
          LicenseParagraph(lines.join(' '), currentParagraphIndentation!);
      assert(result.text.trimLeft() == result.text);
      assert(result.text.isNotEmpty);
      lines.clear();
      return result;
    }

    while (currentPosition < text.length) {
      switch (state) {
        case _LicenseEntryWithLineBreaksParserState.beforeParagraph:
          assert(lineStart == currentPosition);
          switch (text[currentPosition]) {
            case ' ':
              lineStart = currentPosition + 1;
              currentLineIndent += 1;
              state = _LicenseEntryWithLineBreaksParserState.beforeParagraph;
            case '\t':
              lineStart = currentPosition + 1;
              currentLineIndent += 8;
              state = _LicenseEntryWithLineBreaksParserState.beforeParagraph;
            case '\r':
            case '\n':
            case '\f':
              if (lines.isNotEmpty) {
                result.add(getParagraph());
              }
              if (text[currentPosition] == '\r' &&
                  currentPosition < text.length - 1 &&
                  text[currentPosition + 1] == '\n') {
                currentPosition += 1;
              }
              lastLineIndent = 0;
              currentLineIndent = 0;
              currentParagraphIndentation = null;
              lineStart = currentPosition + 1;
              state = _LicenseEntryWithLineBreaksParserState.beforeParagraph;
            case '[':
              // This is a bit of a hack for the LGPL 2.1, which does something like this:
              //
              //   [this is a
              //    single paragraph]
              //
              // ...near the top.
              currentLineIndent += 1;
              continue startParagraph;
            startParagraph:
            default:
              if (lines.isNotEmpty && currentLineIndent > lastLineIndent) {
                result.add(getParagraph());
                currentParagraphIndentation = null;
              }
              // The following is a wild heuristic for guessing the indentation level.
              // It happens to work for common variants of the BSD and LGPL licenses.
              if (currentParagraphIndentation == null) {
                if (currentLineIndent > 10) {
                  currentParagraphIndentation = LicenseParagraph.centeredIndent;
                } else {
                  currentParagraphIndentation = currentLineIndent ~/ 3;
                }
              }
              state = _LicenseEntryWithLineBreaksParserState.inParagraph;
          }
        case _LicenseEntryWithLineBreaksParserState.inParagraph:
          switch (text[currentPosition]) {
            case '\n':
              addLine();
              lastLineIndent = currentLineIndent;
              currentLineIndent = 0;
              lineStart = currentPosition + 1;
              state = _LicenseEntryWithLineBreaksParserState.beforeParagraph;
            case '\f':
              addLine();
              result.add(getParagraph());
              lastLineIndent = 0;
              currentLineIndent = 0;
              currentParagraphIndentation = null;
              lineStart = currentPosition + 1;
              state = _LicenseEntryWithLineBreaksParserState.beforeParagraph;
            default:
              state = _LicenseEntryWithLineBreaksParserState.inParagraph;
          }
      }
      currentPosition += 1;
    }
    switch (state) {
      case _LicenseEntryWithLineBreaksParserState.beforeParagraph:
        if (lines.isNotEmpty) {
          result.add(getParagraph());
        }
      case _LicenseEntryWithLineBreaksParserState.inParagraph:
        addLine();
        result.add(getParagraph());
    }
    return result;
  }
}

abstract final class LicenseRegistry {
  static List<LicenseEntryCollector>? _collectors;

  static void addLicense(LicenseEntryCollector collector) {
    _collectors ??= <LicenseEntryCollector>[];
    _collectors!.add(collector);
  }

  static Stream<LicenseEntry> get licenses {
    if (_collectors == null) {
      return const Stream<LicenseEntry>.empty();
    }

    late final StreamController<LicenseEntry> controller;
    controller = StreamController<LicenseEntry>(
      onListen: () async {
        for (final LicenseEntryCollector collector in _collectors!) {
          await controller.addStream(collector());
        }
        await controller.close();
      },
    );
    return controller.stream;
  }

  @visibleForTesting
  static void reset() {
    _collectors = null;
  }
}
