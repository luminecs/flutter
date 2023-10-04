import 'dart:math' show max, min;
import 'dart:ui' as ui
    show
        BoxHeightStyle,
        BoxWidthStyle,
        LineMetrics,
        Paragraph,
        ParagraphBuilder,
        ParagraphConstraints,
        ParagraphStyle,
        PlaceholderAlignment,
        TextHeightBehavior,
        TextStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'basic_types.dart';
import 'inline_span.dart';
import 'placeholder_span.dart';
import 'strut_style.dart';
import 'text_scaler.dart';
import 'text_span.dart';

export 'package:flutter/services.dart' show TextRange, TextSelection;

// The default font size if none is specified. This should be kept in
// sync with the default values in text_style.dart, as well as the
// defaults set in the engine (eg, LibTxt's text_style.h, paragraph_style.h).
const double _kDefaultFontSize = 14.0;

enum TextOverflow {
  clip,

  fade,

  ellipsis,

  visible,
}

@immutable
class PlaceholderDimensions {
  const PlaceholderDimensions({
    required this.size,
    required this.alignment,
    this.baseline,
    this.baselineOffset,
  });

  static const PlaceholderDimensions empty = PlaceholderDimensions(
      size: Size.zero, alignment: ui.PlaceholderAlignment.bottom);

  final Size size;

  final ui.PlaceholderAlignment alignment;

  final double? baselineOffset;

  final TextBaseline? baseline;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PlaceholderDimensions &&
        other.size == size &&
        other.alignment == alignment &&
        other.baseline == baseline &&
        other.baselineOffset == baselineOffset;
  }

  @override
  int get hashCode => Object.hash(size, alignment, baseline, baselineOffset);

  @override
  String toString() {
    return switch (alignment) {
      ui.PlaceholderAlignment.top ||
      ui.PlaceholderAlignment.bottom ||
      ui.PlaceholderAlignment.middle ||
      ui.PlaceholderAlignment.aboveBaseline ||
      ui.PlaceholderAlignment.belowBaseline =>
        'PlaceholderDimensions($size, $alignment)',
      ui.PlaceholderAlignment.baseline =>
        'PlaceholderDimensions($size, $alignment($baselineOffset from top))',
    };
  }
}

enum TextWidthBasis {
  parent,

  longestLine,
}

class WordBoundary extends TextBoundary {
  WordBoundary._(this._text, this._paragraph);

  final InlineSpan _text;
  final ui.Paragraph _paragraph;

  @override
  TextRange getTextBoundaryAt(int position) =>
      _paragraph.getWordBoundary(TextPosition(offset: max(position, 0)));

  // Combines two UTF-16 code units (high surrogate + low surrogate) into a
  // single code point that represents a supplementary character.
  static int _codePointFromSurrogates(int highSurrogate, int lowSurrogate) {
    assert(
      TextPainter.isHighSurrogate(highSurrogate),
      'U+${highSurrogate.toRadixString(16).toUpperCase().padLeft(4, "0")}) is not a high surrogate.',
    );
    assert(
      TextPainter.isLowSurrogate(lowSurrogate),
      'U+${lowSurrogate.toRadixString(16).toUpperCase().padLeft(4, "0")}) is not a low surrogate.',
    );
    const int base = 0x010000 - (0xD800 << 10) - 0xDC00;
    return (highSurrogate << 10) + lowSurrogate + base;
  }

  // The Runes class does not provide random access with a code unit offset.
  int? _codePointAt(int index) {
    final int? codeUnitAtIndex = _text.codeUnitAt(index);
    if (codeUnitAtIndex == null) {
      return null;
    }
    return switch (codeUnitAtIndex & 0xFC00) {
      0xD800 =>
        _codePointFromSurrogates(codeUnitAtIndex, _text.codeUnitAt(index + 1)!),
      0xDC00 =>
        _codePointFromSurrogates(_text.codeUnitAt(index - 1)!, codeUnitAtIndex),
      _ => codeUnitAtIndex,
    };
  }

  static bool _isNewline(int codePoint) {
    return switch (codePoint) {
      0x000A || 0x0085 || 0x000B || 0x000C || 0x2028 || 0x2029 => true,
      _ => false,
    };
  }

  bool _skipSpacesAndPunctuations(int offset, bool forward) {
    // Use code point since some punctuations are supplementary characters.
    // "inner" here refers to the code unit that's before the break in the
    // search direction (`forward`).
    final int? innerCodePoint = _codePointAt(forward ? offset - 1 : offset);
    final int? outerCodeUnit = _text.codeUnitAt(forward ? offset : offset - 1);

    // Make sure the hard break rules in UAX#29 take precedence over the ones we
    // add below. Luckily there're only 4 hard break rules for word breaks, and
    // dictionary based breaking does not introduce new hard breaks:
    // https://unicode-org.github.io/icu/userguide/boundaryanalysis/break-rules.html#word-dictionaries
    //
    // WB1 & WB2: always break at the start or the end of the text.
    final bool hardBreakRulesApply = innerCodePoint == null ||
        outerCodeUnit == null
        // WB3a & WB3b: always break before and after newlines.
        ||
        _isNewline(innerCodePoint) ||
        _isNewline(outerCodeUnit);
    return hardBreakRulesApply ||
        !RegExp(r'[\p{Space_Separator}\p{Punctuation}]', unicode: true)
            .hasMatch(String.fromCharCode(innerCodePoint));
  }

  late final TextBoundary moveByWordBoundary =
      _UntilTextBoundary(this, _skipSpacesAndPunctuations);
}

class _UntilTextBoundary extends TextBoundary {
  const _UntilTextBoundary(this._textBoundary, this._predicate);

  final UntilPredicate _predicate;
  final TextBoundary _textBoundary;

  @override
  int? getLeadingTextBoundaryAt(int position) {
    if (position < 0) {
      return null;
    }
    final int? offset = _textBoundary.getLeadingTextBoundaryAt(position);
    return offset == null || _predicate(offset, false)
        ? offset
        : getLeadingTextBoundaryAt(offset - 1);
  }

  @override
  int? getTrailingTextBoundaryAt(int position) {
    final int? offset =
        _textBoundary.getTrailingTextBoundaryAt(max(position, 0));
    return offset == null || _predicate(offset, true)
        ? offset
        : getTrailingTextBoundaryAt(offset);
  }
}

class _TextLayout {
  _TextLayout._(this._paragraph);

  // This field is not final because the owner TextPainter could create a new
  // ui.Paragraph with the exact same text layout (for example, when only the
  // color of the text is changed).
  //
  // The creator of this _TextLayout is also responsible for disposing this
  // object when it's no logner needed.
  ui.Paragraph _paragraph;

  bool get debugDisposed => _paragraph.debugDisposed;

  double get width => _paragraph.width;

  double get height => _paragraph.height;

  double get minIntrinsicLineExtent => _paragraph.minIntrinsicWidth;

  double get maxIntrinsicLineExtent => _paragraph.maxIntrinsicWidth;

  double get longestLine => _paragraph.longestLine;

  double getDistanceToBaseline(TextBaseline baseline) {
    return switch (baseline) {
      TextBaseline.alphabetic => _paragraph.alphabeticBaseline,
      TextBaseline.ideographic => _paragraph.ideographicBaseline,
    };
  }
}

// This class stores the current text layout and the corresponding
// paintOffset/contentWidth, as well as some cached text metrics values that
// depends on the current text layout, which will be invalidated as soon as the
// text layout is invalidated.
class _TextPainterLayoutCacheWithOffset {
  _TextPainterLayoutCacheWithOffset(this.layout, this.textAlignment,
      double minWidth, double maxWidth, TextWidthBasis widthBasis)
      : contentWidth = _contentWidthFor(minWidth, maxWidth, widthBasis, layout),
        assert(textAlignment >= 0.0 && textAlignment <= 1.0);

  final _TextLayout layout;

  // The content width the text painter should report in TextPainter.width.
  // This is also used to compute `paintOffset`
  double contentWidth;

  // The effective text alignment in the TextPainter's canvas. The value is
  // within the [0, 1] interval: 0 for left aligned and 1 for right aligned.
  final double textAlignment;

  // The paintOffset of the `paragraph` in the TextPainter's canvas.
  //
  // It's coordinate values are guaranteed to not be NaN.
  Offset get paintOffset {
    if (textAlignment == 0) {
      return Offset.zero;
    }
    if (!paragraph.width.isFinite) {
      return const Offset(double.infinity, 0.0);
    }
    final double dx = textAlignment * (contentWidth - paragraph.width);
    assert(!dx.isNaN);
    return Offset(dx, 0);
  }

  ui.Paragraph get paragraph => layout._paragraph;

  static double _contentWidthFor(double minWidth, double maxWidth,
      TextWidthBasis widthBasis, _TextLayout layout) {
    return switch (widthBasis) {
      TextWidthBasis.longestLine =>
        clampDouble(layout.longestLine, minWidth, maxWidth),
      TextWidthBasis.parent =>
        clampDouble(layout.maxIntrinsicLineExtent, minWidth, maxWidth),
    };
  }

  // Try to resize the contentWidth to fit the new input constraints, by just
  // adjusting the paint offset (so no line-breaking changes needed).
  //
  // Returns false if the new constraints require re-computing the line breaks,
  // in which case no side effects will occur.
  bool _resizeToFit(
      double minWidth, double maxWidth, TextWidthBasis widthBasis) {
    assert(layout.maxIntrinsicLineExtent.isFinite);
    // The assumption here is that if a Paragraph's width is already >= its
    // maxIntrinsicWidth, further increasing the input width does not change its
    // layout (but may change the paint offset if it's not left-aligned). This is
    // true even for TextAlign.justify: when width >= maxIntrinsicWidth
    // TextAlign.justify will behave exactly the same as TextAlign.start.
    //
    // An exception to this is when the text is not left-aligned, and the input
    // width is double.infinity. Since the resulting Paragraph will have a width
    // of double.infinity, and to make the text visible the paintOffset.dx is
    // bound to be double.negativeInfinity, which invalidates all arithmetic
    // operations.
    final double newContentWidth =
        _contentWidthFor(minWidth, maxWidth, widthBasis, layout);
    if (newContentWidth == contentWidth) {
      return true;
    }
    assert(minWidth <= maxWidth);
    // Always needsLayout when the current paintOffset and the paragraph width are not finite.
    if (!paintOffset.dx.isFinite &&
        !paragraph.width.isFinite &&
        minWidth.isFinite) {
      assert(paintOffset.dx == double.infinity);
      assert(paragraph.width == double.infinity);
      return false;
    }
    final double maxIntrinsicWidth = paragraph.maxIntrinsicWidth;
    if ((paragraph.width - maxIntrinsicWidth) > -precisionErrorTolerance &&
        (maxWidth - maxIntrinsicWidth) > -precisionErrorTolerance) {
      // Adjust the paintOffset and contentWidth to the new input constraints.
      contentWidth = newContentWidth;
      return true;
    }
    return false;
  }

  // ---- Cached Values ----

  List<TextBox> get inlinePlaceholderBoxes =>
      _cachedInlinePlaceholderBoxes ??= paragraph.getBoxesForPlaceholders();
  List<TextBox>? _cachedInlinePlaceholderBoxes;

  List<ui.LineMetrics> get lineMetrics =>
      _cachedLineMetrics ??= paragraph.computeLineMetrics();
  List<ui.LineMetrics>? _cachedLineMetrics;

  // Holds the TextPosition the last caret metrics were computed with. When new
  // values are passed in, we recompute the caret metrics only as necessary.
  TextPosition? _previousCaretPosition;
}

// A _CaretMetrics is either a _LineCaretMetrics or an _EmptyLineCaretMetrics.
@immutable
sealed class _CaretMetrics {}

final class _LineCaretMetrics implements _CaretMetrics {
  const _LineCaretMetrics(
      {required this.offset,
      required this.writingDirection,
      required this.fullHeight});
  final Offset offset;
  final TextDirection writingDirection;
  final double fullHeight;
}

final class _EmptyLineCaretMetrics implements _CaretMetrics {
  const _EmptyLineCaretMetrics({required this.lineVerticalOffset});

  final double lineVerticalOffset;
}

class TextPainter {
  TextPainter({
    InlineSpan? text,
    TextAlign textAlign = TextAlign.start,
    TextDirection? textDirection,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
    String? ellipsis,
    Locale? locale,
    StrutStyle? strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    ui.TextHeightBehavior? textHeightBehavior,
  })  : assert(text == null || text.debugAssertIsValid()),
        assert(maxLines == null || maxLines > 0),
        assert(
            textScaleFactor == 1.0 ||
                identical(textScaler, TextScaler.noScaling),
            'Use textScaler instead.'),
        _text = text,
        _textAlign = textAlign,
        _textDirection = textDirection,
        _textScaler = textScaler == TextScaler.noScaling
            ? TextScaler.linear(textScaleFactor)
            : textScaler,
        _maxLines = maxLines,
        _ellipsis = ellipsis,
        _locale = locale,
        _strutStyle = strutStyle,
        _textWidthBasis = textWidthBasis,
        _textHeightBehavior = textHeightBehavior;

  static double computeWidth({
    required InlineSpan text,
    required TextDirection textDirection,
    TextAlign textAlign = TextAlign.start,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
    String? ellipsis,
    Locale? locale,
    StrutStyle? strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    ui.TextHeightBehavior? textHeightBehavior,
    double minWidth = 0.0,
    double maxWidth = double.infinity,
  }) {
    assert(
      textScaleFactor == 1.0 || identical(textScaler, TextScaler.noScaling),
      'Use textScaler instead.',
    );
    final TextPainter painter = TextPainter(
      text: text,
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler == TextScaler.noScaling
          ? TextScaler.linear(textScaleFactor)
          : textScaler,
      maxLines: maxLines,
      ellipsis: ellipsis,
      locale: locale,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    )..layout(minWidth: minWidth, maxWidth: maxWidth);

    try {
      return painter.width;
    } finally {
      painter.dispose();
    }
  }

  static double computeMaxIntrinsicWidth({
    required InlineSpan text,
    required TextDirection textDirection,
    TextAlign textAlign = TextAlign.start,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
    String? ellipsis,
    Locale? locale,
    StrutStyle? strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    ui.TextHeightBehavior? textHeightBehavior,
    double minWidth = 0.0,
    double maxWidth = double.infinity,
  }) {
    assert(
      textScaleFactor == 1.0 || identical(textScaler, TextScaler.noScaling),
      'Use textScaler instead.',
    );
    final TextPainter painter = TextPainter(
      text: text,
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler == TextScaler.noScaling
          ? TextScaler.linear(textScaleFactor)
          : textScaler,
      maxLines: maxLines,
      ellipsis: ellipsis,
      locale: locale,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    )..layout(minWidth: minWidth, maxWidth: maxWidth);

    try {
      return painter.maxIntrinsicWidth;
    } finally {
      painter.dispose();
    }
  }

  // Whether textWidthBasis has changed after the most recent `layout` call.
  bool _debugNeedsRelayout = true;
  // The result of the most recent `layout` call.
  _TextPainterLayoutCacheWithOffset? _layoutCache;

  // Whether _layoutCache contains outdated paint information and needs to be
  // updated before painting.
  //
  // ui.Paragraph is entirely immutable, thus text style changes that can affect
  // layout and those who can't both require the ui.Paragraph object being
  // recreated. The caller may not call `layout` again after text color is
  // updated. See: https://github.com/flutter/flutter/issues/85108
  bool _rebuildParagraphForPaint = true;
  // `_layoutCache`'s input width. This is only needed because there's no API to
  // create paint only updates that don't affect the text layout (e.g., changing
  // the color of the text), on ui.Paragraph or ui.ParagraphBuilder.
  double _inputWidth = double.nan;

  bool get _debugAssertTextLayoutIsValid {
    assert(!debugDisposed);
    if (_layoutCache == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('Text layout not available'),
        if (_debugMarkNeedsLayoutCallStack != null)
          DiagnosticsStackTrace(
              'The calls that first invalidated the text layout were',
              _debugMarkNeedsLayoutCallStack)
        else
          ErrorDescription('The TextPainter has never been laid out.')
      ]);
    }
    return true;
  }

  StackTrace? _debugMarkNeedsLayoutCallStack;

  void markNeedsLayout() {
    assert(() {
      if (_layoutCache != null) {
        _debugMarkNeedsLayoutCallStack ??= StackTrace.current;
      }
      return true;
    }());
    _layoutCache?.paragraph.dispose();
    _layoutCache = null;
  }

  InlineSpan? get text => _text;
  InlineSpan? _text;
  set text(InlineSpan? value) {
    assert(value == null || value.debugAssertIsValid());
    if (_text == value) {
      return;
    }
    if (_text?.style != value?.style) {
      _layoutTemplate?.dispose();
      _layoutTemplate = null;
    }

    final RenderComparison comparison = value == null
        ? RenderComparison.layout
        : _text?.compareTo(value) ?? RenderComparison.layout;

    _text = value;
    _cachedPlainText = null;

    if (comparison.index >= RenderComparison.layout.index) {
      markNeedsLayout();
    } else if (comparison.index >= RenderComparison.paint.index) {
      // Don't invalid the _layoutCache just yet. It still contains valid layout
      // information.
      _rebuildParagraphForPaint = true;
    }
    // Neither relayout or repaint is needed.
  }

  String get plainText {
    _cachedPlainText ??= _text?.toPlainText(includeSemanticsLabels: false);
    return _cachedPlainText ?? '';
  }

  String? _cachedPlainText;

  TextAlign get textAlign => _textAlign;
  TextAlign _textAlign;
  set textAlign(TextAlign value) {
    if (_textAlign == value) {
      return;
    }
    _textAlign = value;
    markNeedsLayout();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
    _layoutTemplate?.dispose();
    _layoutTemplate =
        null; // Shouldn't really matter, but for strict correctness...
  }

  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  double get textScaleFactor => textScaler.textScaleFactor;
  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  set textScaleFactor(double value) {
    textScaler = TextScaler.linear(value);
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) {
      return;
    }
    _textScaler = value;
    markNeedsLayout();
    _layoutTemplate?.dispose();
    _layoutTemplate = null;
  }

  String? get ellipsis => _ellipsis;
  String? _ellipsis;
  set ellipsis(String? value) {
    assert(value == null || value.isNotEmpty);
    if (_ellipsis == value) {
      return;
    }
    _ellipsis = value;
    markNeedsLayout();
  }

  Locale? get locale => _locale;
  Locale? _locale;
  set locale(Locale? value) {
    if (_locale == value) {
      return;
    }
    _locale = value;
    markNeedsLayout();
  }

  int? get maxLines => _maxLines;
  int? _maxLines;
  set maxLines(int? value) {
    assert(value == null || value > 0);
    if (_maxLines == value) {
      return;
    }
    _maxLines = value;
    markNeedsLayout();
  }

  StrutStyle? get strutStyle => _strutStyle;
  StrutStyle? _strutStyle;
  set strutStyle(StrutStyle? value) {
    if (_strutStyle == value) {
      return;
    }
    _strutStyle = value;
    markNeedsLayout();
  }

  TextWidthBasis get textWidthBasis => _textWidthBasis;
  TextWidthBasis _textWidthBasis;
  set textWidthBasis(TextWidthBasis value) {
    if (_textWidthBasis == value) {
      return;
    }
    assert(() {
      return _debugNeedsRelayout = true;
    }());
    _textWidthBasis = value;
  }

  ui.TextHeightBehavior? get textHeightBehavior => _textHeightBehavior;
  ui.TextHeightBehavior? _textHeightBehavior;
  set textHeightBehavior(ui.TextHeightBehavior? value) {
    if (_textHeightBehavior == value) {
      return;
    }
    _textHeightBehavior = value;
    markNeedsLayout();
  }

  List<TextBox>? get inlinePlaceholderBoxes {
    final _TextPainterLayoutCacheWithOffset? layout = _layoutCache;
    if (layout == null) {
      return null;
    }
    final Offset offset = layout.paintOffset;
    if (!offset.dx.isFinite || !offset.dy.isFinite) {
      return <TextBox>[];
    }
    final List<TextBox> rawBoxes = layout.inlinePlaceholderBoxes;
    if (offset == Offset.zero) {
      return rawBoxes;
    }
    return rawBoxes
        .map((TextBox box) => _shiftTextBox(box, offset))
        .toList(growable: false);
  }

  void setPlaceholderDimensions(List<PlaceholderDimensions>? value) {
    if (value == null ||
        value.isEmpty ||
        listEquals(value, _placeholderDimensions)) {
      return;
    }
    assert(() {
      int placeholderCount = 0;
      text!.visitChildren((InlineSpan span) {
        if (span is PlaceholderSpan) {
          placeholderCount += 1;
        }
        return value.length >= placeholderCount;
      });
      return placeholderCount == value.length;
    }());
    _placeholderDimensions = value;
    markNeedsLayout();
  }

  List<PlaceholderDimensions>? _placeholderDimensions;

  ui.ParagraphStyle _createParagraphStyle(
      [TextDirection? defaultTextDirection]) {
    // The defaultTextDirection argument is used for preferredLineHeight in case
    // textDirection hasn't yet been set.
    assert(textDirection != null || defaultTextDirection != null,
        'TextPainter.textDirection must be set to a non-null value before using the TextPainter.');
    return _text!.style?.getParagraphStyle(
          textAlign: textAlign,
          textDirection: textDirection ?? defaultTextDirection,
          textScaler: textScaler,
          maxLines: _maxLines,
          textHeightBehavior: _textHeightBehavior,
          ellipsis: _ellipsis,
          locale: _locale,
          strutStyle: _strutStyle,
        ) ??
        ui.ParagraphStyle(
          textAlign: textAlign,
          textDirection: textDirection ?? defaultTextDirection,
          // Use the default font size to multiply by as RichText does not
          // perform inheriting [TextStyle]s and would otherwise
          // fail to apply textScaler.
          fontSize: textScaler.scale(_kDefaultFontSize),
          maxLines: maxLines,
          textHeightBehavior: _textHeightBehavior,
          ellipsis: ellipsis,
          locale: locale,
        );
  }

  ui.Paragraph? _layoutTemplate;
  ui.Paragraph _createLayoutTemplate() {
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      _createParagraphStyle(TextDirection.rtl),
    ); // direction doesn't matter, text is just a space
    final ui.TextStyle? textStyle =
        text?.style?.getTextStyle(textScaler: textScaler);
    if (textStyle != null) {
      builder.pushStyle(textStyle);
    }
    builder.addText(' ');
    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
  }

  double get preferredLineHeight =>
      (_layoutTemplate ??= _createLayoutTemplate()).height;

  double get minIntrinsicWidth {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.minIntrinsicLineExtent;
  }

  double get maxIntrinsicWidth {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.maxIntrinsicLineExtent;
  }

  double get width {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    return _layoutCache!.contentWidth;
  }

  double get height {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.height;
  }

  Size get size {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    return Size(width, height);
  }

  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.layout.getDistanceToBaseline(baseline);
  }

  bool get didExceedMaxLines {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.didExceedMaxLines;
  }

  // Creates a ui.Paragraph using the current configurations in this class and
  // assign it to _paragraph.
  ui.Paragraph _createParagraph(InlineSpan text) {
    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(_createParagraphStyle());
    text.build(builder,
        textScaler: textScaler, dimensions: _placeholderDimensions);
    assert(() {
      _debugMarkNeedsLayoutCallStack = null;
      return true;
    }());
    _rebuildParagraphForPaint = false;
    return builder.build();
  }

  void layout({double minWidth = 0.0, double maxWidth = double.infinity}) {
    assert(!maxWidth.isNaN);
    assert(!minWidth.isNaN);
    assert(() {
      _debugNeedsRelayout = false;
      return true;
    }());

    final _TextPainterLayoutCacheWithOffset? cachedLayout = _layoutCache;
    if (cachedLayout != null &&
        cachedLayout._resizeToFit(minWidth, maxWidth, textWidthBasis)) {
      return;
    }

    final InlineSpan? text = this.text;
    if (text == null) {
      throw StateError(
          'TextPainter.text must be set to a non-null value before using the TextPainter.');
    }
    final TextDirection? textDirection = this.textDirection;
    if (textDirection == null) {
      throw StateError(
          'TextPainter.textDirection must be set to a non-null value before using the TextPainter.');
    }

    final double paintOffsetAlignment =
        _computePaintOffsetFraction(textAlign, textDirection);
    // Try to avoid laying out the paragraph with maxWidth=double.infinity
    // when the text is not left-aligned, so we don't have to deal with an
    // infinite paint offset.
    final bool adjustMaxWidth = !maxWidth.isFinite && paintOffsetAlignment != 0;
    final double? adjustedMaxWidth = !adjustMaxWidth
        ? maxWidth
        : cachedLayout?.layout.maxIntrinsicLineExtent;
    _inputWidth = adjustedMaxWidth ?? maxWidth;

    // Only rebuild the paragraph when there're layout changes, even when
    // `_rebuildParagraphForPaint` is true. It's best to not eagerly rebuild
    // the paragraph to avoid the extra work, because:
    // 1. the text color could change again before `paint` is called (so one of
    //    the paragraph rebuilds is unnecessary)
    // 2. the user could be measuring the text layout so `paint` will never be
    //    called.
    final ui.Paragraph paragraph = (cachedLayout?.paragraph ??
        _createParagraph(text))
      ..layout(ui.ParagraphConstraints(width: _inputWidth));
    final _TextPainterLayoutCacheWithOffset newLayoutCache =
        _TextPainterLayoutCacheWithOffset(
      _TextLayout._(paragraph),
      paintOffsetAlignment,
      minWidth,
      maxWidth,
      textWidthBasis,
    );
    // Call layout again if newLayoutCache had an infinite paint offset.
    // This is not as expensive as it seems, line breaking is relatively cheap
    // as compared to shaping.
    if (adjustedMaxWidth == null && minWidth.isFinite) {
      assert(maxWidth.isInfinite);
      final double newInputWidth = newLayoutCache.layout.maxIntrinsicLineExtent;
      paragraph.layout(ui.ParagraphConstraints(width: newInputWidth));
      _inputWidth = newInputWidth;
    }
    _layoutCache = newLayoutCache;
  }

  void paint(Canvas canvas, Offset offset) {
    final _TextPainterLayoutCacheWithOffset? layoutCache = _layoutCache;
    if (layoutCache == null) {
      throw StateError(
        'TextPainter.paint called when text geometry was not yet calculated.\n'
        'Please call layout() before paint() to position the text before painting it.',
      );
    }

    if (!layoutCache.paintOffset.dx.isFinite ||
        !layoutCache.paintOffset.dy.isFinite) {
      return;
    }

    if (_rebuildParagraphForPaint) {
      Size? debugSize;
      assert(() {
        debugSize = size;
        return true;
      }());

      final ui.Paragraph paragraph = layoutCache.paragraph;
      // Unfortunately even if we know that there is only paint changes, there's
      // no API to only make those updates so the paragraph has to be recreated
      // and re-laid out.
      assert(!_inputWidth.isNaN);
      layoutCache.layout._paragraph = _createParagraph(text!)
        ..layout(ui.ParagraphConstraints(width: _inputWidth));
      assert(paragraph.width == layoutCache.layout._paragraph.width);
      paragraph.dispose();
      assert(debugSize == size);
    }
    assert(!_rebuildParagraphForPaint);
    canvas.drawParagraph(
        layoutCache.paragraph, offset + layoutCache.paintOffset);
  }

  // Returns true if value falls in the valid range of the UTF16 encoding.
  static bool _isUTF16(int value) {
    return value >= 0x0 && value <= 0xFFFFF;
  }

  static bool isHighSurrogate(int value) {
    assert(_isUTF16(value));
    return value & 0xFC00 == 0xD800;
  }

  static bool isLowSurrogate(int value) {
    assert(_isUTF16(value));
    return value & 0xFC00 == 0xDC00;
  }

  // Checks if the glyph is either [Unicode.RLM] or [Unicode.LRM]. These values take
  // up zero space and do not have valid bounding boxes around them.
  //
  // We do not directly use the [Unicode] constants since they are strings.
  static bool _isUnicodeDirectionality(int value) {
    return value == 0x200F || value == 0x200E;
  }

  int? getOffsetAfter(int offset) {
    final int? nextCodeUnit = _text!.codeUnitAt(offset);
    if (nextCodeUnit == null) {
      return null;
    }
    // TODO(goderbauer): doesn't handle extended grapheme clusters with more than one Unicode scalar value (https://github.com/flutter/flutter/issues/13404).
    return isHighSurrogate(nextCodeUnit) ? offset + 2 : offset + 1;
  }

  int? getOffsetBefore(int offset) {
    final int? prevCodeUnit = _text!.codeUnitAt(offset - 1);
    if (prevCodeUnit == null) {
      return null;
    }
    // TODO(goderbauer): doesn't handle extended grapheme clusters with more than one Unicode scalar value (https://github.com/flutter/flutter/issues/13404).
    return isLowSurrogate(prevCodeUnit) ? offset - 2 : offset - 1;
  }

  // Unicode value for a zero width joiner character.
  static const int _zwjUtf16 = 0x200d;

  // Get the caret metrics (in logical pixels) based off the near edge of the
  // character upstream from the given string offset.
  _CaretMetrics? _getMetricsFromUpstream(int offset) {
    assert(offset >= 0);
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0 || offset > plainTextLength) {
      return null;
    }
    final int prevCodeUnit = plainText.codeUnitAt(max(0, offset - 1));

    // If the upstream character is a newline, cursor is at start of next line
    const int NEWLINE_CODE_UNIT = 10;

    // Check for multi-code-unit glyphs such as emojis or zero width joiner.
    final bool needsSearch = isHighSurrogate(prevCodeUnit) ||
        isLowSurrogate(prevCodeUnit) ||
        _text!.codeUnitAt(offset) == _zwjUtf16 ||
        _isUnicodeDirectionality(prevCodeUnit);
    int graphemeClusterLength = needsSearch ? 2 : 1;
    List<TextBox> boxes = <TextBox>[];
    while (boxes.isEmpty) {
      final int prevRuneOffset = offset - graphemeClusterLength;
      // Use BoxHeightStyle.strut to ensure that the caret's height fits within
      // the line's height and is consistent throughout the line.
      boxes = _layoutCache!.paragraph.getBoxesForRange(
          max(0, prevRuneOffset), offset,
          boxHeightStyle: ui.BoxHeightStyle.strut);
      // When the range does not include a full cluster, no boxes will be returned.
      if (boxes.isEmpty) {
        // When we are at the beginning of the line, a non-surrogate position will
        // return empty boxes. We break and try from downstream instead.
        if (!needsSearch && prevCodeUnit == NEWLINE_CODE_UNIT) {
          break; // Only perform one iteration if no search is required.
        }
        if (prevRuneOffset < -plainTextLength) {
          break; // Stop iterating when beyond the max length of the text.
        }
        // Multiply by two to log(n) time cover the entire text span. This allows
        // faster discovery of very long clusters and reduces the possibility
        // of certain large clusters taking much longer than others, which can
        // cause jank.
        graphemeClusterLength *= 2;
        continue;
      }

      // Try to identify the box nearest the offset.  This logic works when
      // there's just one box, and when all boxes have the same direction.
      // It may not work in bidi text: https://github.com/flutter/flutter/issues/123424
      final TextBox box =
          boxes.last.direction == TextDirection.ltr ? boxes.last : boxes.first;
      return prevCodeUnit == NEWLINE_CODE_UNIT
          ? _EmptyLineCaretMetrics(lineVerticalOffset: box.bottom)
          : _LineCaretMetrics(
              offset: Offset(box.end, box.top),
              writingDirection: box.direction,
              fullHeight: box.bottom - box.top);
    }
    return null;
  }

  // Get the caret metrics (in logical pixels) based off the near edge of the
  // character downstream from the given string offset.
  _CaretMetrics? _getMetricsFromDownstream(int offset) {
    assert(offset >= 0);
    final int plainTextLength = plainText.length;
    if (plainTextLength == 0) {
      return null;
    }
    // We cap the offset at the final index of plain text.
    final int nextCodeUnit =
        plainText.codeUnitAt(min(offset, plainTextLength - 1));

    // Check for multi-code-unit glyphs such as emojis or zero width joiner
    final bool needsSearch = isHighSurrogate(nextCodeUnit) ||
        isLowSurrogate(nextCodeUnit) ||
        nextCodeUnit == _zwjUtf16 ||
        _isUnicodeDirectionality(nextCodeUnit);
    int graphemeClusterLength = needsSearch ? 2 : 1;
    List<TextBox> boxes = <TextBox>[];
    while (boxes.isEmpty) {
      final int nextRuneOffset = offset + graphemeClusterLength;
      // Use BoxHeightStyle.strut to ensure that the caret's height fits within
      // the line's height and is consistent throughout the line.
      boxes = _layoutCache!.paragraph.getBoxesForRange(offset, nextRuneOffset,
          boxHeightStyle: ui.BoxHeightStyle.strut);
      // When the range does not include a full cluster, no boxes will be returned.
      if (boxes.isEmpty) {
        // When we are at the end of the line, a non-surrogate position will
        // return empty boxes. We break and try from upstream instead.
        if (!needsSearch) {
          break; // Only perform one iteration if no search is required.
        }
        if (nextRuneOffset >= plainTextLength << 1) {
          break; // Stop iterating when beyond the max length of the text.
        }
        // Multiply by two to log(n) time cover the entire text span. This allows
        // faster discovery of very long clusters and reduces the possibility
        // of certain large clusters taking much longer than others, which can
        // cause jank.
        graphemeClusterLength *= 2;
        continue;
      }

      // Try to identify the box nearest the offset.  This logic works when
      // there's just one box, and when all boxes have the same direction.
      // It may not work in bidi text: https://github.com/flutter/flutter/issues/123424
      final TextBox box =
          boxes.first.direction == TextDirection.ltr ? boxes.first : boxes.last;
      return _LineCaretMetrics(
          offset: Offset(box.start, box.top),
          writingDirection: box.direction,
          fullHeight: box.bottom - box.top);
    }
    return null;
  }

  static double _computePaintOffsetFraction(
      TextAlign textAlign, TextDirection textDirection) {
    return switch ((textAlign, textDirection)) {
      (TextAlign.left, _) => 0.0,
      (TextAlign.right, _) => 1.0,
      (TextAlign.center, _) => 0.5,
      (TextAlign.start, TextDirection.ltr) => 0.0,
      (TextAlign.start, TextDirection.rtl) => 1.0,
      (TextAlign.justify, TextDirection.ltr) => 0.0,
      (TextAlign.justify, TextDirection.rtl) => 1.0,
      (TextAlign.end, TextDirection.ltr) => 1.0,
      (TextAlign.end, TextDirection.rtl) => 0.0,
    };
  }

  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    final _CaretMetrics caretMetrics;
    final _TextPainterLayoutCacheWithOffset layoutCache = _layoutCache!;
    if (position.offset < 0) {
      // TODO(LongCatIsLooong): make this case impossible; see https://github.com/flutter/flutter/issues/79495
      caretMetrics = const _EmptyLineCaretMetrics(lineVerticalOffset: 0);
    } else {
      caretMetrics = _computeCaretMetrics(position);
    }

    final Offset rawOffset;
    switch (caretMetrics) {
      case _EmptyLineCaretMetrics(:final double lineVerticalOffset):
        final double paintOffsetAlignment =
            _computePaintOffsetFraction(textAlign, textDirection!);
        // The full width is not (width - caretPrototype.width)
        // because RenderEditable reserves cursor width on the right. Ideally this
        // should be handled by RenderEditable instead.
        final double dx = paintOffsetAlignment == 0
            ? 0
            : paintOffsetAlignment * layoutCache.contentWidth;
        return Offset(dx, lineVerticalOffset);
      case _LineCaretMetrics(
          writingDirection: TextDirection.ltr,
          :final Offset offset
        ):
        rawOffset = offset;
      case _LineCaretMetrics(
          writingDirection: TextDirection.rtl,
          :final Offset offset
        ):
        rawOffset = Offset(offset.dx - caretPrototype.width, offset.dy);
    }
    // If offset.dx is outside of the advertised content area, then the associated
    // glyph cluster belongs to a trailing newline character. Ideally the behavior
    // should be handled by higher-level implementations (for instance,
    // RenderEditable reserves width for showing the caret, it's best to handle
    // the clamping there).
    final double adjustedDx = clampDouble(
        rawOffset.dx + layoutCache.paintOffset.dx, 0, layoutCache.contentWidth);
    return Offset(adjustedDx, rawOffset.dy + layoutCache.paintOffset.dy);
  }

  double? getFullHeightForCaret(TextPosition position, Rect caretPrototype) {
    if (position.offset < 0) {
      // TODO(LongCatIsLooong): make this case impossible; see https://github.com/flutter/flutter/issues/79495
      return null;
    }
    return switch (_computeCaretMetrics(position)) {
      _LineCaretMetrics(:final double fullHeight) => fullHeight,
      _EmptyLineCaretMetrics() => null,
    };
  }

  // Cached caret metrics. This allows multiple invokes of [getOffsetForCaret] and
  // [getFullHeightForCaret] in a row without performing redundant and expensive
  // get rect calls to the paragraph.
  late _CaretMetrics _caretMetrics;

  // Checks if the [position] and [caretPrototype] have changed from the cached
  // version and recomputes the metrics required to position the caret.
  _CaretMetrics _computeCaretMetrics(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset cachedLayout = _layoutCache!;
    if (position == cachedLayout._previousCaretPosition) {
      return _caretMetrics;
    }
    final int offset = position.offset;
    final _CaretMetrics? metrics = switch (position.affinity) {
      TextAffinity.upstream =>
        _getMetricsFromUpstream(offset) ?? _getMetricsFromDownstream(offset),
      TextAffinity.downstream =>
        _getMetricsFromDownstream(offset) ?? _getMetricsFromUpstream(offset),
    };
    // Cache the input parameters to prevent repeat work later.
    cachedLayout._previousCaretPosition = position;
    return _caretMetrics =
        metrics ?? const _EmptyLineCaretMetrics(lineVerticalOffset: 0);
  }

  List<TextBox> getBoxesForSelection(
    TextSelection selection, {
    ui.BoxHeightStyle boxHeightStyle = ui.BoxHeightStyle.tight,
    ui.BoxWidthStyle boxWidthStyle = ui.BoxWidthStyle.tight,
  }) {
    assert(_debugAssertTextLayoutIsValid);
    assert(selection.isValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset cachedLayout = _layoutCache!;
    final Offset offset = cachedLayout.paintOffset;
    if (!offset.dx.isFinite || !offset.dy.isFinite) {
      return <TextBox>[];
    }
    final List<TextBox> boxes = cachedLayout.paragraph.getBoxesForRange(
      selection.start,
      selection.end,
      boxHeightStyle: boxHeightStyle,
      boxWidthStyle: boxWidthStyle,
    );
    return offset == Offset.zero
        ? boxes
        : boxes
            .map((TextBox box) => _shiftTextBox(box, offset))
            .toList(growable: false);
  }

  TextPosition getPositionForOffset(Offset offset) {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset cachedLayout = _layoutCache!;
    return cachedLayout.paragraph
        .getPositionForOffset(offset - cachedLayout.paintOffset);
  }

  TextRange getWordBoundary(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.getWordBoundary(position);
  }

  WordBoundary get wordBoundaries =>
      WordBoundary._(text!, _layoutCache!.paragraph);

  TextRange getLineBoundary(TextPosition position) {
    assert(_debugAssertTextLayoutIsValid);
    return _layoutCache!.paragraph.getLineBoundary(position);
  }

  static ui.LineMetrics _shiftLineMetrics(
      ui.LineMetrics metrics, Offset offset) {
    assert(offset.dx.isFinite);
    assert(offset.dy.isFinite);
    return ui.LineMetrics(
      hardBreak: metrics.hardBreak,
      ascent: metrics.ascent,
      descent: metrics.descent,
      unscaledAscent: metrics.unscaledAscent,
      height: metrics.height,
      width: metrics.width,
      left: metrics.left + offset.dx,
      baseline: metrics.baseline + offset.dy,
      lineNumber: metrics.lineNumber,
    );
  }

  static TextBox _shiftTextBox(TextBox box, Offset offset) {
    assert(offset.dx.isFinite);
    assert(offset.dy.isFinite);
    return TextBox.fromLTRBD(
      box.left + offset.dx,
      box.top + offset.dy,
      box.right + offset.dx,
      box.bottom + offset.dy,
      box.direction,
    );
  }

  List<ui.LineMetrics> computeLineMetrics() {
    assert(_debugAssertTextLayoutIsValid);
    assert(!_debugNeedsRelayout);
    final _TextPainterLayoutCacheWithOffset layout = _layoutCache!;
    final Offset offset = layout.paintOffset;
    if (!offset.dx.isFinite || !offset.dy.isFinite) {
      return const <ui.LineMetrics>[];
    }
    final List<ui.LineMetrics> rawMetrics = layout.lineMetrics;
    return offset == Offset.zero
        ? rawMetrics
        : rawMetrics
            .map((ui.LineMetrics metrics) => _shiftLineMetrics(metrics, offset))
            .toList(growable: false);
  }

  bool _disposed = false;

  bool get debugDisposed {
    bool? disposed;
    assert(() {
      disposed = _disposed;
      return true;
    }());
    return disposed ??
        (throw StateError('debugDisposed only available when asserts are on.'));
  }

  void dispose() {
    assert(() {
      _disposed = true;
      return true;
    }());
    _layoutTemplate?.dispose();
    _layoutTemplate = null;
    _layoutCache?.paragraph.dispose();
    _layoutCache = null;
    _text = null;
  }
}
