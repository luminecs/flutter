import 'dart:ui' show TextRange;

import 'text_editing.dart';

export 'dart:ui' show TextPosition, TextRange;

export 'text_editing.dart' show TextSelection;

abstract class TextLayoutMetrics {
  // TODO(gspencergoog): replace when we expose this ICU information.
  static bool isWhitespace(int codeUnit) {
    switch (codeUnit) {
      case 0x9: // horizontal tab
      case 0xA: // line feed
      case 0xB: // vertical tab
      case 0xC: // form feed
      case 0xD: // carriage return
      case 0x1C: // file separator
      case 0x1D: // group separator
      case 0x1E: // record separator
      case 0x1F: // unit separator
      case 0x20: // space
      case 0xA0: // no-break space
      case 0x1680: // ogham space mark
      case 0x2000: // en quad
      case 0x2001: // em quad
      case 0x2002: // en space
      case 0x2003: // em space
      case 0x2004: // three-per-em space
      case 0x2005: // four-er-em space
      case 0x2006: // six-per-em space
      case 0x2007: // figure space
      case 0x2008: // punctuation space
      case 0x2009: // thin space
      case 0x200A: // hair space
      case 0x202F: // narrow no-break space
      case 0x205F: // medium mathematical space
      case 0x3000: // ideographic space
        break;
      default:
        return false;
    }
    return true;
  }

  static bool isLineTerminator(int codeUnit) {
    switch (codeUnit) {
      case 0x0A: // line feed
      case 0x0B: // vertical feed
      case 0x0C: // form feed
      case 0x0D: // carriage return
      case 0x85: // new line
      case 0x2028: // line separator
      case 0x2029: // paragraph separator
        return true;
      default:
        return false;
    }
  }

  TextSelection getLineAtOffset(TextPosition position);

  TextRange getWordBoundary(TextPosition position);

  TextPosition getTextPositionAbove(TextPosition position);

  TextPosition getTextPositionBelow(TextPosition position);
}