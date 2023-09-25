import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:meta/meta.dart';

import 'assertions.dart';
import 'constants.dart';
import 'debug.dart';
import 'object.dart';

// Examples can assume:
// late int rows, columns;
// late String _name;
// late bool inherit;
// abstract class ExampleSuperclass with Diagnosticable { }
// late String message;
// late double stepWidth;
// late double scale;
// late double hitTestExtent;
// late double paintExtent;
// late double maxWidth;
// late double progress;
// late int maxLines;
// late Duration duration;
// late int depth;
// late bool primary;
// late bool isCurrent;
// late bool keepAlive;
// late bool obscureText;
// late TextAlign textAlign;
// late ImageRepeat repeat;
// late Widget widget;
// late List<BoxShadow> boxShadow;
// late Size size;
// late bool hasSize;
// late Matrix4 transform;
// late Color color;
// late Map<Listenable, VoidCallback>? handles;
// late DiagnosticsTreeStyle style;
// late IconData icon;
// late double devicePixelRatio;

enum DiagnosticLevel {
  hidden,

  fine,

  debug,

  info,

  warning,

  hint,

  summary,

  error,

  off,
}

enum DiagnosticsTreeStyle {
  none,

  sparse,

  offstage,

  dense,

  transition,

  error,

  whitespace,

  flat,

  singleLine,

  errorProperty,

  shallow,

  truncateChildren,
}

class TextTreeConfiguration {
  TextTreeConfiguration({
    required this.prefixLineOne,
    required this.prefixOtherLines,
    required this.prefixLastChildLineOne,
    required this.prefixOtherLinesRootNode,
    required this.linkCharacter,
    required this.propertyPrefixIfChildren,
    required this.propertyPrefixNoChildren,
    this.lineBreak = '\n',
    this.lineBreakProperties = true,
    this.afterName = ':',
    this.afterDescriptionIfBody = '',
    this.afterDescription = '',
    this.beforeProperties = '',
    this.afterProperties = '',
    this.mandatoryAfterProperties = '',
    this.propertySeparator = '',
    this.bodyIndent = '',
    this.footer = '',
    this.showChildren = true,
    this.addBlankLineIfNoChildren = true,
    this.isNameOnOwnLine = false,
    this.isBlankLineBetweenPropertiesAndChildren = true,
    this.beforeName = '',
    this.suffixLineOne = '',
    this.mandatoryFooter = '',
  }) : childLinkSpace = ' ' * linkCharacter.length;

  final String prefixLineOne;

  final String suffixLineOne;

  final String prefixOtherLines;

  final String prefixLastChildLineOne;

  final String prefixOtherLinesRootNode;

  final String propertyPrefixIfChildren;

  final String propertyPrefixNoChildren;

  final String linkCharacter;

  final String childLinkSpace;

  final String lineBreak;

  final bool lineBreakProperties;


  final String beforeName;

  final String afterName;

  final String afterDescriptionIfBody;

  final String afterDescription;

  final String beforeProperties;

  final String afterProperties;

  final String mandatoryAfterProperties;

  final String propertySeparator;

  final String bodyIndent;

  final bool showChildren;

  final bool addBlankLineIfNoChildren;

  final bool isNameOnOwnLine;

  final String footer;

  final String mandatoryFooter;

  final bool isBlankLineBetweenPropertiesAndChildren;
}

final TextTreeConfiguration sparseTextConfiguration = TextTreeConfiguration(
  prefixLineOne:            '├─',
  prefixOtherLines:         ' ',
  prefixLastChildLineOne:   '└─',
  linkCharacter:            '│',
  propertyPrefixIfChildren: '│ ',
  propertyPrefixNoChildren: '  ',
  prefixOtherLinesRootNode: ' ',
);

final TextTreeConfiguration dashedTextConfiguration = TextTreeConfiguration(
  prefixLineOne:            '╎╌',
  prefixLastChildLineOne:   '└╌',
  prefixOtherLines:         ' ',
  linkCharacter:            '╎',
  // Intentionally not set as a dashed line as that would make the properties
  // look like they were disabled.
  propertyPrefixIfChildren: '│ ',
  propertyPrefixNoChildren: '  ',
  prefixOtherLinesRootNode: ' ',
);

final TextTreeConfiguration denseTextConfiguration = TextTreeConfiguration(
  propertySeparator: ', ',
  beforeProperties: '(',
  afterProperties: ')',
  lineBreakProperties: false,
  prefixLineOne:            '├',
  prefixOtherLines:         '',
  prefixLastChildLineOne:   '└',
  linkCharacter:            '│',
  propertyPrefixIfChildren: '│',
  propertyPrefixNoChildren: ' ',
  prefixOtherLinesRootNode: '',
  addBlankLineIfNoChildren: false,
  isBlankLineBetweenPropertiesAndChildren: false,
);

final TextTreeConfiguration transitionTextConfiguration = TextTreeConfiguration(
  prefixLineOne:           '╞═╦══ ',
  prefixLastChildLineOne:  '╘═╦══ ',
  prefixOtherLines:         ' ║ ',
  footer:                   ' ╚═══════════',
  linkCharacter:            '│',
  // Subtree boundaries are clear due to the border around the node so omit the
  // property prefix.
  propertyPrefixIfChildren: '',
  propertyPrefixNoChildren: '',
  prefixOtherLinesRootNode: '',
  afterName:                ' ═══',
  // Add a colon after the description if the node has a body to make the
  // connection between the description and the body clearer.
  afterDescriptionIfBody: ':',
  // Members are indented an extra two spaces to disambiguate as the description
  // is placed within the box instead of along side the name as is the case for
  // other styles.
  bodyIndent: '  ',
  isNameOnOwnLine: true,
  // No need to add a blank line as the footer makes the boundary of this
  // subtree unambiguous.
  addBlankLineIfNoChildren: false,
  isBlankLineBetweenPropertiesAndChildren: false,
);

final TextTreeConfiguration errorTextConfiguration = TextTreeConfiguration(
  prefixLineOne:           '╞═╦',
  prefixLastChildLineOne:  '╘═╦',
  prefixOtherLines:         ' ║ ',
  footer:                   ' ╚═══════════',
  linkCharacter:            '│',
  // Subtree boundaries are clear due to the border around the node so omit the
  // property prefix.
  propertyPrefixIfChildren: '',
  propertyPrefixNoChildren: '',
  prefixOtherLinesRootNode: '',
  beforeName:               '══╡ ',
  suffixLineOne:            ' ╞══',
  mandatoryFooter:          '═════',
  // No need to add a blank line as the footer makes the boundary of this
  // subtree unambiguous.
  addBlankLineIfNoChildren: false,
  isBlankLineBetweenPropertiesAndChildren: false,
);

final TextTreeConfiguration whitespaceTextConfiguration = TextTreeConfiguration(
  prefixLineOne: '',
  prefixLastChildLineOne: '',
  prefixOtherLines: ' ',
  prefixOtherLinesRootNode: '  ',
  propertyPrefixIfChildren: '',
  propertyPrefixNoChildren: '',
  linkCharacter: ' ',
  addBlankLineIfNoChildren: false,
  // Add a colon after the description and before the properties to link the
  // properties to the description line.
  afterDescriptionIfBody: ':',
  isBlankLineBetweenPropertiesAndChildren: false,
);

final TextTreeConfiguration flatTextConfiguration = TextTreeConfiguration(
  prefixLineOne: '',
  prefixLastChildLineOne: '',
  prefixOtherLines: '',
  prefixOtherLinesRootNode: '',
  propertyPrefixIfChildren: '',
  propertyPrefixNoChildren: '',
  linkCharacter: '',
  addBlankLineIfNoChildren: false,
  // Add a colon after the description and before the properties to link the
  // properties to the description line.
  afterDescriptionIfBody: ':',
  isBlankLineBetweenPropertiesAndChildren: false,
);
final TextTreeConfiguration singleLineTextConfiguration = TextTreeConfiguration(
  propertySeparator: ', ',
  beforeProperties: '(',
  afterProperties: ')',
  prefixLineOne: '',
  prefixOtherLines: '',
  prefixLastChildLineOne: '',
  lineBreak: '',
  lineBreakProperties: false,
  addBlankLineIfNoChildren: false,
  showChildren: false,
  propertyPrefixIfChildren: '  ',
  propertyPrefixNoChildren: '  ',
  linkCharacter: '',
  prefixOtherLinesRootNode: '',
);

final TextTreeConfiguration errorPropertyTextConfiguration = TextTreeConfiguration(
  propertySeparator: ', ',
  beforeProperties: '(',
  afterProperties: ')',
  prefixLineOne: '',
  prefixOtherLines: '',
  prefixLastChildLineOne: '',
  lineBreakProperties: false,
  addBlankLineIfNoChildren: false,
  showChildren: false,
  propertyPrefixIfChildren: '  ',
  propertyPrefixNoChildren: '  ',
  linkCharacter: '',
  prefixOtherLinesRootNode: '',
  isNameOnOwnLine: true,
);

final TextTreeConfiguration shallowTextConfiguration = TextTreeConfiguration(
  prefixLineOne: '',
  prefixLastChildLineOne: '',
  prefixOtherLines: ' ',
  prefixOtherLinesRootNode: '  ',
  propertyPrefixIfChildren: '',
  propertyPrefixNoChildren: '',
  linkCharacter: ' ',
  addBlankLineIfNoChildren: false,
  // Add a colon after the description and before the properties to link the
  // properties to the description line.
  afterDescriptionIfBody: ':',
  isBlankLineBetweenPropertiesAndChildren: false,
  showChildren: false,
);

enum _WordWrapParseMode { inSpace, inWord, atBreak }

class _PrefixedStringBuilder {
  _PrefixedStringBuilder({
    required this.prefixLineOne,
    required String? prefixOtherLines,
    this.wrapWidth,
  })  : _prefixOtherLines = prefixOtherLines;

  final String prefixLineOne;

  String? get prefixOtherLines => _nextPrefixOtherLines ?? _prefixOtherLines;
  String? _prefixOtherLines;
  set prefixOtherLines(String? prefix) {
    _prefixOtherLines = prefix;
    _nextPrefixOtherLines = null;
  }

  String? _nextPrefixOtherLines;
  void incrementPrefixOtherLines(String suffix, {required bool updateCurrentLine}) {
    if (_currentLine.isEmpty || updateCurrentLine) {
      _prefixOtherLines = prefixOtherLines! + suffix;
      _nextPrefixOtherLines = null;
    } else {
      _nextPrefixOtherLines = prefixOtherLines! + suffix;
    }
  }

  final int? wrapWidth;

  final StringBuffer _buffer = StringBuffer();
  final StringBuffer _currentLine = StringBuffer();
  final List<int> _wrappableRanges = <int>[];

  bool get requiresMultipleLines => _numLines > 1 || (_numLines == 1 && _currentLine.isNotEmpty) ||
      (_currentLine.length + _getCurrentPrefix(true)!.length > wrapWidth!);

  bool get isCurrentLineEmpty => _currentLine.isEmpty;

  int _numLines = 0;

  void _finalizeLine(bool addTrailingLineBreak) {
    final bool firstLine = _buffer.isEmpty;
    final String text = _currentLine.toString();
    _currentLine.clear();

    if (_wrappableRanges.isEmpty) {
      // Fast path. There were no wrappable spans of text.
      _writeLine(
        text,
        includeLineBreak: addTrailingLineBreak,
        firstLine: firstLine,
      );
      return;
    }
    final Iterable<String> lines = _wordWrapLine(
      text,
      _wrappableRanges,
      wrapWidth!,
      startOffset: firstLine ? prefixLineOne.length : _prefixOtherLines!.length,
      otherLineOffset: _prefixOtherLines!.length,
    );
    int i = 0;
    final int length = lines.length;
    for (final String line in lines) {
      i++;
      _writeLine(
        line,
        includeLineBreak: addTrailingLineBreak || i < length,
        firstLine: firstLine,
      );
    }
    _wrappableRanges.clear();
  }

  static Iterable<String> _wordWrapLine(String message, List<int> wrapRanges, int width, { int startOffset = 0, int otherLineOffset = 0}) {
    if (message.length + startOffset < width) {
      // Nothing to do. The line doesn't wrap.
      return <String>[message];
    }
    final List<String> wrappedLine = <String>[];
    int startForLengthCalculations = -startOffset;
    bool addPrefix = false;
    int index = 0;
    _WordWrapParseMode mode = _WordWrapParseMode.inSpace;
    late int lastWordStart;
    int? lastWordEnd;
    int start = 0;

    int currentChunk = 0;

    // This helper is called with increasing indexes.
    bool noWrap(int index) {
      while (true) {
        if (currentChunk >= wrapRanges.length) {
          return true;
        }

        if (index < wrapRanges[currentChunk + 1]) {
          break; // Found nearest chunk.
        }
        currentChunk+= 2;
      }
      return index < wrapRanges[currentChunk];
    }
    while (true) {
      switch (mode) {
        case _WordWrapParseMode.inSpace: // at start of break point (or start of line); can't break until next break
          while ((index < message.length) && (message[index] == ' ')) {
            index += 1;
          }
          lastWordStart = index;
          mode = _WordWrapParseMode.inWord;
        case _WordWrapParseMode.inWord: // looking for a good break point. Treat all text
          while ((index < message.length) && (message[index] != ' ' || noWrap(index))) {
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
            final String line = message.substring(start, lastWordEnd);
            wrappedLine.add(line);
            addPrefix = true;
            if (lastWordEnd >= message.length) {
              return wrappedLine;
            }
            // just yielded a line
            if (lastWordEnd == index) {
              // we broke at current position
              // eat all the wrappable spaces, then set our start point
              // Even if some of the spaces are not wrappable that is ok.
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
            startForLengthCalculations = start - otherLineOffset;
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

  void write(String s, {bool allowWrap = false}) {
    if (s.isEmpty) {
      return;
    }

    final List<String> lines = s.split('\n');
    for (int i = 0; i < lines.length; i += 1) {
      if (i > 0) {
        _finalizeLine(true);
        _updatePrefix();
      }
      final String line = lines[i];
      if (line.isNotEmpty) {
        if (allowWrap && wrapWidth != null) {
          final int wrapStart = _currentLine.length;
          final int wrapEnd = wrapStart + line.length;
          if (_wrappableRanges.isNotEmpty && _wrappableRanges.last == wrapStart) {
            // Extend last range.
            _wrappableRanges.last = wrapEnd;
          } else {
            _wrappableRanges..add(wrapStart)..add(wrapEnd);
          }
        }
        _currentLine.write(line);
      }
    }
  }
  void _updatePrefix() {
    if (_nextPrefixOtherLines != null) {
      _prefixOtherLines = _nextPrefixOtherLines;
      _nextPrefixOtherLines = null;
    }
  }

  void _writeLine(
    String line, {
    required bool includeLineBreak,
    required bool firstLine,
  }) {
    line = '${_getCurrentPrefix(firstLine)}$line';
    _buffer.write(line.trimRight());
    if (includeLineBreak) {
      _buffer.write('\n');
    }
    _numLines++;
  }

  String? _getCurrentPrefix(bool firstLine) {
    return _buffer.isEmpty ? prefixLineOne : _prefixOtherLines;
  }

  void writeRawLines(String lines) {
    if (lines.isEmpty) {
      return;
    }

    if (_currentLine.isNotEmpty) {
      _finalizeLine(true);
    }
    assert (_currentLine.isEmpty);

    _buffer.write(lines);
    if (!lines.endsWith('\n')) {
      _buffer.write('\n');
    }
    _numLines++;
    _updatePrefix();
  }

  void writeStretched(String text, int targetLineLength) {
    write(text);
    final int currentLineLength = _currentLine.length + _getCurrentPrefix(_buffer.isEmpty)!.length;
    assert (_currentLine.length > 0);
    final int targetLength = targetLineLength - currentLineLength;
    if (targetLength > 0) {
      assert(text.isNotEmpty);
      final String lastChar = text[text.length - 1];
      assert(lastChar != '\n');
      _currentLine.write(lastChar * targetLength);
    }
    // Mark the entire line as not wrappable.
    _wrappableRanges.clear();
  }

  String build() {
    if (_currentLine.isNotEmpty) {
      _finalizeLine(false);
    }

    return _buffer.toString();
  }
}

class _NoDefaultValue {
  const _NoDefaultValue();
}

const Object kNoDefaultValue = _NoDefaultValue();

bool _isSingleLine(DiagnosticsTreeStyle? style) {
  return style == DiagnosticsTreeStyle.singleLine;
}

class TextTreeRenderer {
  TextTreeRenderer({
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
    int wrapWidth = 100,
    int wrapWidthProperties = 65,
    int maxDescendentsTruncatableNode = -1,
  }) : _minLevel = minLevel,
       _wrapWidth = wrapWidth,
       _wrapWidthProperties = wrapWidthProperties,
       _maxDescendentsTruncatableNode = maxDescendentsTruncatableNode;

  final int _wrapWidth;
  final int _wrapWidthProperties;
  final DiagnosticLevel _minLevel;
  final int _maxDescendentsTruncatableNode;

  TextTreeConfiguration? _childTextConfiguration(
    DiagnosticsNode child,
    TextTreeConfiguration textStyle,
  ) {
    final DiagnosticsTreeStyle? childStyle = child.style;
    return (_isSingleLine(childStyle) || childStyle == DiagnosticsTreeStyle.errorProperty) ? textStyle : child.textTreeConfiguration;
  }

  String render(
    DiagnosticsNode node, {
    String prefixLineOne = '',
    String? prefixOtherLines,
    TextTreeConfiguration? parentConfiguration,
  }) {
    if (kReleaseMode) {
      return '';
    } else {
      return _debugRender(
        node,
        prefixLineOne: prefixLineOne,
        prefixOtherLines: prefixOtherLines,
        parentConfiguration: parentConfiguration,
      );
    }
  }

  String _debugRender(
    DiagnosticsNode node, {
    String prefixLineOne = '',
    String? prefixOtherLines,
    TextTreeConfiguration? parentConfiguration,
  }) {
    final bool isSingleLine = _isSingleLine(node.style) && parentConfiguration?.lineBreakProperties != true;
    prefixOtherLines ??= prefixLineOne;
    if (node.linePrefix != null) {
      prefixLineOne += node.linePrefix!;
      prefixOtherLines += node.linePrefix!;
    }

    final TextTreeConfiguration config = node.textTreeConfiguration!;
    if (prefixOtherLines.isEmpty) {
      prefixOtherLines += config.prefixOtherLinesRootNode;
    }

    if (node.style == DiagnosticsTreeStyle.truncateChildren) {
      // This style is different enough that it isn't worthwhile to reuse the
      // existing logic.
      final List<String> descendants = <String>[];
      const int maxDepth = 5;
      int depth = 0;
      const int maxLines = 25;
      int lines = 0;
      void visitor(DiagnosticsNode node) {
        for (final DiagnosticsNode child in node.getChildren()) {
          if (lines < maxLines) {
            depth += 1;
            descendants.add('$prefixOtherLines${"  " * depth}$child');
            if (depth < maxDepth) {
              visitor(child);
            }
            depth -= 1;
          } else if (lines == maxLines) {
            descendants.add('$prefixOtherLines  ...(descendants list truncated after $lines lines)');
          }
          lines += 1;
        }
      }
      visitor(node);
      final StringBuffer information = StringBuffer(prefixLineOne);
      if (lines > 1) {
        information.writeln('This ${node.name} had the following descendants (showing up to depth $maxDepth):');
      } else if (descendants.length == 1) {
        information.writeln('This ${node.name} had the following child:');
      } else {
        information.writeln('This ${node.name} has no descendants.');
      }
      information.writeAll(descendants, '\n');
      return information.toString();
    }
    final _PrefixedStringBuilder builder = _PrefixedStringBuilder(
      prefixLineOne: prefixLineOne,
      prefixOtherLines: prefixOtherLines,
      wrapWidth: math.max(_wrapWidth, prefixOtherLines.length + _wrapWidthProperties),
    );

    List<DiagnosticsNode> children = node.getChildren();

    String description = node.toDescription(parentConfiguration: parentConfiguration);
    if (config.beforeName.isNotEmpty) {
      builder.write(config.beforeName);
    }
    final bool wrapName = !isSingleLine && node.allowNameWrap;
    final bool wrapDescription = !isSingleLine && node.allowWrap;
    final bool uppercaseTitle = node.style == DiagnosticsTreeStyle.error;
    String? name = node.name;
    if (uppercaseTitle) {
      name = name?.toUpperCase();
    }
    if (description.isEmpty) {
      if (node.showName && name != null) {
        builder.write(name, allowWrap: wrapName);
      }
    } else {
      bool includeName = false;
      if (name != null && name.isNotEmpty && node.showName) {
        includeName = true;
        builder.write(name, allowWrap: wrapName);
        if (node.showSeparator) {
          builder.write(config.afterName, allowWrap: wrapName);
        }

        builder.write(
          config.isNameOnOwnLine || description.contains('\n') ? '\n' : ' ',
          allowWrap: wrapName,
        );
      }
      if (!isSingleLine && builder.requiresMultipleLines && !builder.isCurrentLineEmpty) {
        // Make sure there is a break between the current line and next one if
        // there is not one already.
        builder.write('\n');
      }
      if (includeName) {
        builder.incrementPrefixOtherLines(
          children.isEmpty ? config.propertyPrefixNoChildren : config.propertyPrefixIfChildren,
          updateCurrentLine: true,
        );
      }

      if (uppercaseTitle) {
        description = description.toUpperCase();
      }
      builder.write(description.trimRight(), allowWrap: wrapDescription);

      if (!includeName) {
        builder.incrementPrefixOtherLines(
          children.isEmpty ? config.propertyPrefixNoChildren : config.propertyPrefixIfChildren,
          updateCurrentLine: false,
        );
      }
    }
    if (config.suffixLineOne.isNotEmpty) {
      builder.writeStretched(config.suffixLineOne, builder.wrapWidth!);
    }

    final Iterable<DiagnosticsNode> propertiesIterable = node.getProperties().where(
            (DiagnosticsNode n) => !n.isFiltered(_minLevel),
    );
    List<DiagnosticsNode> properties;
    if (_maxDescendentsTruncatableNode >= 0 && node.allowTruncate) {
      if (propertiesIterable.length < _maxDescendentsTruncatableNode) {
        properties =
            propertiesIterable.take(_maxDescendentsTruncatableNode).toList();
        properties.add(DiagnosticsNode.message('...'));
      } else {
        properties = propertiesIterable.toList();
      }
      if (_maxDescendentsTruncatableNode < children.length) {
        children = children.take(_maxDescendentsTruncatableNode).toList();
        children.add(DiagnosticsNode.message('...'));
      }
    } else {
      properties = propertiesIterable.toList();
    }

    // If the node does not show a separator and there is no description then
    // we should not place a separator between the name and the value.
    // Essentially in this case the properties are treated a bit like a value.
    if ((properties.isNotEmpty || children.isNotEmpty || node.emptyBodyDescription != null) &&
        (node.showSeparator || description.isNotEmpty)) {
      builder.write(config.afterDescriptionIfBody);
    }

    if (config.lineBreakProperties) {
      builder.write(config.lineBreak);
    }

    if (properties.isNotEmpty) {
      builder.write(config.beforeProperties);
    }

    builder.incrementPrefixOtherLines(config.bodyIndent, updateCurrentLine: false);

    if (node.emptyBodyDescription != null &&
        properties.isEmpty &&
        children.isEmpty &&
        prefixLineOne.isNotEmpty) {
      builder.write(node.emptyBodyDescription!);
      if (config.lineBreakProperties) {
        builder.write(config.lineBreak);
      }
    }

    for (int i = 0; i < properties.length; ++i) {
      final DiagnosticsNode property = properties[i];
      if (i > 0) {
        builder.write(config.propertySeparator);
      }

      final TextTreeConfiguration propertyStyle = property.textTreeConfiguration!;
      if (_isSingleLine(property.style)) {
        // We have to treat single line properties slightly differently to deal
        // with cases where a single line properties output may not have single
        // linebreak.
        final String propertyRender = render(property,
          prefixLineOne: propertyStyle.prefixLineOne,
          prefixOtherLines: '${propertyStyle.childLinkSpace}${propertyStyle.prefixOtherLines}',
          parentConfiguration: config,
        );
        final List<String> propertyLines = propertyRender.split('\n');
        if (propertyLines.length == 1 && !config.lineBreakProperties) {
          builder.write(propertyLines.first);
        } else {
          builder.write(propertyRender);
          if (!propertyRender.endsWith('\n')) {
            builder.write('\n');
          }
        }
      } else {
        final String propertyRender = render(property,
          prefixLineOne: '${builder.prefixOtherLines}${propertyStyle.prefixLineOne}',
          prefixOtherLines: '${builder.prefixOtherLines}${propertyStyle.childLinkSpace}${propertyStyle.prefixOtherLines}',
          parentConfiguration: config,
        );
        builder.writeRawLines(propertyRender);
      }
    }
    if (properties.isNotEmpty) {
      builder.write(config.afterProperties);
    }

    builder.write(config.mandatoryAfterProperties);

    if (!config.lineBreakProperties) {
      builder.write(config.lineBreak);
    }

    final String prefixChildren = config.bodyIndent;
    final String prefixChildrenRaw = '$prefixOtherLines$prefixChildren';
    if (children.isEmpty &&
        config.addBlankLineIfNoChildren &&
        builder.requiresMultipleLines &&
        builder.prefixOtherLines!.trimRight().isNotEmpty
    ) {
      builder.write(config.lineBreak);
    }

    if (children.isNotEmpty && config.showChildren) {
      if (config.isBlankLineBetweenPropertiesAndChildren &&
          properties.isNotEmpty &&
          children.first.textTreeConfiguration!.isBlankLineBetweenPropertiesAndChildren) {
        builder.write(config.lineBreak);
      }

      builder.prefixOtherLines = prefixOtherLines;

      for (int i = 0; i < children.length; i++) {
        final DiagnosticsNode child = children[i];
        final TextTreeConfiguration childConfig = _childTextConfiguration(child, config)!;
        if (i == children.length - 1) {
          final String lastChildPrefixLineOne = '$prefixChildrenRaw${childConfig.prefixLastChildLineOne}';
          final String childPrefixOtherLines = '$prefixChildrenRaw${childConfig.childLinkSpace}${childConfig.prefixOtherLines}';
          builder.writeRawLines(render(
            child,
            prefixLineOne: lastChildPrefixLineOne,
            prefixOtherLines: childPrefixOtherLines,
            parentConfiguration: config,
          ));
          if (childConfig.footer.isNotEmpty) {
            builder.prefixOtherLines = prefixChildrenRaw;
            builder.write('${childConfig.childLinkSpace}${childConfig.footer}');
            if (childConfig.mandatoryFooter.isNotEmpty) {
              builder.writeStretched(
                childConfig.mandatoryFooter,
                math.max(builder.wrapWidth!, _wrapWidthProperties + childPrefixOtherLines.length),
              );
            }
            builder.write(config.lineBreak);
          }
        } else {
          final TextTreeConfiguration nextChildStyle = _childTextConfiguration(children[i + 1], config)!;
          final String childPrefixLineOne = '$prefixChildrenRaw${childConfig.prefixLineOne}';
          final String childPrefixOtherLines ='$prefixChildrenRaw${nextChildStyle.linkCharacter}${childConfig.prefixOtherLines}';
          builder.writeRawLines(render(
            child,
            prefixLineOne: childPrefixLineOne,
            prefixOtherLines: childPrefixOtherLines,
            parentConfiguration: config,
          ));
          if (childConfig.footer.isNotEmpty) {
            builder.prefixOtherLines = prefixChildrenRaw;
            builder.write('${childConfig.linkCharacter}${childConfig.footer}');
            if (childConfig.mandatoryFooter.isNotEmpty) {
              builder.writeStretched(
                childConfig.mandatoryFooter,
                math.max(builder.wrapWidth!, _wrapWidthProperties + childPrefixOtherLines.length),
              );
            }
            builder.write(config.lineBreak);
          }
        }
      }
    }
    if (parentConfiguration == null && config.mandatoryFooter.isNotEmpty) {
      builder.writeStretched(config.mandatoryFooter, builder.wrapWidth!);
      builder.write(config.lineBreak);
    }
    return builder.build();
  }
}

abstract class DiagnosticsNode {
  DiagnosticsNode({
    required this.name,
    this.style,
    this.showName = true,
    this.showSeparator = true,
    this.linePrefix,
  }) : assert(
         // A name ending with ':' indicates that the user forgot that the ':' will
         // be automatically added for them when generating descriptions of the
         // property.
         name == null || !name.endsWith(':'),
         'Names of diagnostic nodes must not end with colons.\n'
         'name:\n'
         '  "$name"',
       );

  factory DiagnosticsNode.message(
    String message, {
    DiagnosticsTreeStyle style = DiagnosticsTreeStyle.singleLine,
    DiagnosticLevel level = DiagnosticLevel.info,
    bool allowWrap = true,
  }) {
    return DiagnosticsProperty<void>(
      '',
      null,
      description: message,
      style: style,
      showName: false,
      allowWrap: allowWrap,
      level: level,
    );
  }

  final String? name;

  String toDescription({ TextTreeConfiguration? parentConfiguration });

  final bool showSeparator;

  bool isFiltered(DiagnosticLevel minLevel) => kReleaseMode || level.index < minLevel.index;

  DiagnosticLevel get level => kReleaseMode ? DiagnosticLevel.hidden : DiagnosticLevel.info;

  final bool showName;

  final String? linePrefix;

  String? get emptyBodyDescription => null;

  Object? get value;

  final DiagnosticsTreeStyle? style;

  bool get allowWrap => false;

  bool get allowNameWrap => false;

  bool get allowTruncate => false;

  List<DiagnosticsNode> getProperties();

  List<DiagnosticsNode> getChildren();

  String get _separator => showSeparator ? ':' : '';

  Map<String, String>? toTimelineArguments() {
    if (!kReleaseMode) {
      // We don't throw in release builds, to avoid hurting users. We also don't do anything useful.
      if (kProfileMode) {
        throw FlutterError(
          // Parts of this string are searched for verbatim by a test in dev/bots/test.dart.
          '$DiagnosticsNode.toTimelineArguments used in non-debug build.\n'
          'The $DiagnosticsNode.toTimelineArguments API is expensive and causes timeline traces '
          'to be non-representative. As such, it should not be used in profile builds. However, '
          'this application is compiled in profile mode and yet still invoked the method.'
        );
      }
      final Map<String, String> result = <String, String>{};
      for (final DiagnosticsNode property in getProperties()) {
        if (property.name != null) {
          result[property.name!] = property.toDescription(parentConfiguration: singleLineTextConfiguration);
        }
      }
      return result;
    }
    return null;
  }

  @mustCallSuper
  Map<String, Object?> toJsonMap(DiagnosticsSerializationDelegate delegate) {
    Map<String, Object?> result = <String, Object?>{};
    assert(() {
      final bool hasChildren = getChildren().isNotEmpty;
      result = <String, Object?>{
        'description': toDescription(),
        'type': runtimeType.toString(),
        if (name != null)
          'name': name,
        if (!showSeparator)
          'showSeparator': showSeparator,
        if (level != DiagnosticLevel.info)
          'level': level.name,
        if (!showName)
          'showName': showName,
        if (emptyBodyDescription != null)
          'emptyBodyDescription': emptyBodyDescription,
        if (style != DiagnosticsTreeStyle.sparse)
          'style': style!.name,
        if (allowTruncate)
          'allowTruncate': allowTruncate,
        if (hasChildren)
          'hasChildren': hasChildren,
        if (linePrefix?.isNotEmpty ?? false)
          'linePrefix': linePrefix,
        if (!allowWrap)
          'allowWrap': allowWrap,
        if (allowNameWrap)
          'allowNameWrap': allowNameWrap,
        ...delegate.additionalNodeProperties(this),
        if (delegate.includeProperties)
          'properties': toJsonList(
            delegate.filterProperties(getProperties(), this),
            this,
            delegate,
          ),
        if (delegate.subtreeDepth > 0)
          'children': toJsonList(
            delegate.filterChildren(getChildren(), this),
            this,
            delegate,
          ),
      };
      return true;
    }());
    return result;
  }

  static List<Map<String, Object?>> toJsonList(
    List<DiagnosticsNode>? nodes,
    DiagnosticsNode? parent,
    DiagnosticsSerializationDelegate delegate,
  ) {
    bool truncated = false;
    if (nodes == null) {
      return const <Map<String, Object?>>[];
    }
    final int originalNodeCount = nodes.length;
    nodes = delegate.truncateNodesList(nodes, parent);
    if (nodes.length != originalNodeCount) {
      nodes.add(DiagnosticsNode.message('...'));
      truncated = true;
    }
    final List<Map<String, Object?>> json = nodes.map<Map<String, Object?>>((DiagnosticsNode node) {
      return node.toJsonMap(delegate.delegateForNode(node));
    }).toList();
    if (truncated) {
      json.last['truncated'] = true;
    }
    return json;
  }

  @override
  String toString({
    TextTreeConfiguration? parentConfiguration,
    DiagnosticLevel minLevel = DiagnosticLevel.info,
  }) {
    String result = super.toString();
    assert(style != null);
    assert(() {
      if (_isSingleLine(style)) {
        result = toStringDeep(parentConfiguration: parentConfiguration, minLevel: minLevel);
      } else {
        final String description = toDescription(parentConfiguration: parentConfiguration);

        if (name == null || name!.isEmpty || !showName) {
          result = description;
        } else {
          result = description.contains('\n') ? '$name$_separator\n$description'
              : '$name$_separator $description';
        }
      }
      return true;
    }());
    return result;
  }

  @protected
  TextTreeConfiguration? get textTreeConfiguration {
    assert(style != null);
    switch (style!) {
      case DiagnosticsTreeStyle.none:
        return null;
      case DiagnosticsTreeStyle.dense:
        return denseTextConfiguration;
      case DiagnosticsTreeStyle.sparse:
        return sparseTextConfiguration;
      case DiagnosticsTreeStyle.offstage:
        return dashedTextConfiguration;
      case DiagnosticsTreeStyle.whitespace:
        return whitespaceTextConfiguration;
      case DiagnosticsTreeStyle.transition:
        return transitionTextConfiguration;
      case DiagnosticsTreeStyle.singleLine:
        return singleLineTextConfiguration;
      case DiagnosticsTreeStyle.errorProperty:
        return errorPropertyTextConfiguration;
      case DiagnosticsTreeStyle.shallow:
        return shallowTextConfiguration;
      case DiagnosticsTreeStyle.error:
        return errorTextConfiguration;
      case DiagnosticsTreeStyle.truncateChildren:
        // Truncate children doesn't really need its own text style as the
        // rendering is quite custom.
        return whitespaceTextConfiguration;
      case DiagnosticsTreeStyle.flat:
        return flatTextConfiguration;
    }
  }

  String toStringDeep({
    String prefixLineOne = '',
    String? prefixOtherLines,
    TextTreeConfiguration? parentConfiguration,
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
  }) {
    String result = '';
    assert(() {
      result = TextTreeRenderer(
        minLevel: minLevel,
        wrapWidth: 65,
      ).render(
        this,
        prefixLineOne: prefixLineOne,
        prefixOtherLines: prefixOtherLines,
        parentConfiguration: parentConfiguration,
      );
      return true;
    }());
    return result;
  }
}

class MessageProperty extends DiagnosticsProperty<void> {
  MessageProperty(
    String name,
    String message, {
    DiagnosticsTreeStyle style = DiagnosticsTreeStyle.singleLine,
    DiagnosticLevel level = DiagnosticLevel.info,
  }) : super(name, null, description: message, style: style, level: level);
}

class StringProperty extends DiagnosticsProperty<String> {
  StringProperty(
    String super.name,
    super.value, {
    super.description,
    super.tooltip,
    super.showName,
    super.defaultValue,
    this.quoted = true,
    super.ifEmpty,
    super.style,
    super.level,
  });

  final bool quoted;

  @override
  Map<String, Object?> toJsonMap(DiagnosticsSerializationDelegate delegate) {
    final Map<String, Object?> json = super.toJsonMap(delegate);
    json['quoted'] = quoted;
    return json;
  }

  @override
  String valueToString({ TextTreeConfiguration? parentConfiguration }) {
    String? text = _description ?? value;
    if (parentConfiguration != null &&
        !parentConfiguration.lineBreakProperties &&
        text != null) {
      // Escape linebreaks in multiline strings to avoid confusing output when
      // the parent of this node is trying to display all properties on the same
      // line.
      text = text.replaceAll('\n', r'\n');
    }

    if (quoted && text != null) {
      // An empty value would not appear empty after being surrounded with
      // quotes so we have to handle this case separately.
      if (ifEmpty != null && text.isEmpty) {
        return ifEmpty!;
      }
      return '"$text"';
    }
    return text.toString();
  }
}

abstract class _NumProperty<T extends num> extends DiagnosticsProperty<T> {
  _NumProperty(
    String super.name,
    super.value, {
    super.ifNull,
    this.unit,
    super.showName,
    super.defaultValue,
    super.tooltip,
    super.style,
    super.level,
  });

  _NumProperty.lazy(
    String super.name,
    super.computeValue, {
    super.ifNull,
    this.unit,
    super.showName,
    super.defaultValue,
    super.tooltip,
    super.style,
    super.level,
  }) : super.lazy();

  @override
  Map<String, Object?> toJsonMap(DiagnosticsSerializationDelegate delegate) {
    final Map<String, Object?> json = super.toJsonMap(delegate);
    if (unit != null) {
      json['unit'] = unit;
    }

    json['numberToString'] = numberToString();
    return json;
  }

  final String? unit;

  String numberToString();

  @override
  String valueToString({ TextTreeConfiguration? parentConfiguration }) {
    if (value == null) {
      return value.toString();
    }

    return unit != null ? '${numberToString()}$unit' : numberToString();
  }
}
class DoubleProperty extends _NumProperty<double> {
  DoubleProperty(
    super.name,
    super.value, {
    super.ifNull,
    super.unit,
    super.tooltip,
    super.defaultValue,
    super.showName,
    super.style,
    super.level,
  });

  DoubleProperty.lazy(
    super.name,
    super.computeValue, {
    super.ifNull,
    super.showName,
    super.unit,
    super.tooltip,
    super.defaultValue,
    super.level,
  }) : super.lazy();

  @override
  String numberToString() => debugFormatDouble(value);
}

class IntProperty extends _NumProperty<int> {
  IntProperty(
    super.name,
    super.value, {
    super.ifNull,
    super.showName,
    super.unit,
    super.defaultValue,
    super.style,
    super.level,
  });

  @override
  String numberToString() => value.toString();
}

class PercentProperty extends DoubleProperty {
  PercentProperty(
    super.name,
    super.fraction, {
    super.ifNull,
    super.showName,
    super.tooltip,
    super.unit,
    super.level,
  });

  @override
  String valueToString({ TextTreeConfiguration? parentConfiguration }) {
    if (value == null) {
      return value.toString();
    }
    return unit != null ? '${numberToString()} $unit' : numberToString();
  }

  @override
  String numberToString() {
    final double? v = value;
    if (v == null) {
      return value.toString();
    }
    return '${(clampDouble(v, 0.0, 1.0) * 100.0).toStringAsFixed(1)}%';
  }
}

class FlagProperty extends DiagnosticsProperty<bool> {
  FlagProperty(
    String name, {
    required bool? value,
    this.ifTrue,
    this.ifFalse,
    bool showName = false,
    Object? defaultValue,
    DiagnosticLevel level = DiagnosticLevel.info,
  }) : assert(ifTrue != null || ifFalse != null),
       super(
         name,
         value,
         showName: showName,
         defaultValue: defaultValue,
         level: level,
       );

  @override
  Map<String, Object?> toJsonMap(DiagnosticsSerializationDelegate delegate) {
    final Map<String, Object?> json = super.toJsonMap(delegate);
    if (ifTrue != null) {
      json['ifTrue'] = ifTrue;
    }
    if (ifFalse != null) {
      json['ifFalse'] = ifFalse;
    }

    return json;
  }

  final String? ifTrue;

  final String? ifFalse;

  @override
  String valueToString({ TextTreeConfiguration? parentConfiguration }) {
    if (value ?? false) {
      if (ifTrue != null) {
        return ifTrue!;
      }
    } else if (value == false) {
      if (ifFalse != null) {
        return ifFalse!;
      }
    }
    return super.valueToString(parentConfiguration: parentConfiguration);
  }

  @override
  bool get showName {
    if (value == null || ((value ?? false) && ifTrue == null) || (!(value ?? true) && ifFalse == null)) {
      // We are missing a description for the flag value so we need to show the
      // flag name. The property will have DiagnosticLevel.hidden for this case
      // so users will not see this property in this case unless they are
      // displaying hidden properties.
      return true;
    }
    return super.showName;
  }

  @override
  DiagnosticLevel get level {
    if (value ?? false) {
      if (ifTrue == null) {
        return DiagnosticLevel.hidden;
      }
    }
    if (value == false) {
      if (ifFalse == null) {
        return DiagnosticLevel.hidden;
      }
    }
    return super.level;
  }
}

class IterableProperty<T> extends DiagnosticsProperty<Iterable<T>> {
  IterableProperty(
    String super.name,
    super.value, {
    super.defaultValue,
    super.ifNull,
    super.ifEmpty = '[]',
    super.style,
    super.showName,
    super.showSeparator,
    super.level,
  });

  @override
  String valueToString({TextTreeConfiguration? parentConfiguration}) {
    if (value == null) {
      return value.toString();
    }

    if (value!.isEmpty) {
      return ifEmpty ?? '[]';
    }

    final Iterable<String> formattedValues = value!.map((T v) {
      if (T == double && v is double) {
        return debugFormatDouble(v);
      } else {
        return v.toString();
      }
    });

    if (parentConfiguration != null && !parentConfiguration.lineBreakProperties) {
      // Always display the value as a single line and enclose the iterable
      // value in brackets to avoid ambiguity.
      return '[${formattedValues.join(', ')}]';
    }

    return formattedValues.join(_isSingleLine(style) ? ', ' : '\n');
  }

  @override
  DiagnosticLevel get level {
    if (ifEmpty == null && value != null && value!.isEmpty && super.level != DiagnosticLevel.hidden) {
      return DiagnosticLevel.fine;
    }
    return super.level;
  }

  @override
  Map<String, Object?> toJsonMap(DiagnosticsSerializationDelegate delegate) {
    final Map<String, Object?> json = super.toJsonMap(delegate);
    if (value != null) {
      json['values'] = value!.map<String>((T value) => value.toString()).toList();
    }
    return json;
  }
}

class EnumProperty<T extends Enum?> extends DiagnosticsProperty<T> {
  EnumProperty(
    String super.name,
    super.value, {
    super.defaultValue,
    super.level,
  });

  @override
  String valueToString({ TextTreeConfiguration? parentConfiguration }) {
    if (value == null) {
      return value.toString();
    }
    return value!.name;
  }
}

class ObjectFlagProperty<T> extends DiagnosticsProperty<T> {
  ObjectFlagProperty(
    String super.name,
    super.value, {
    this.ifPresent,
    super.ifNull,
    super.showName = false,
    super.level,
  }) : assert(ifPresent != null || ifNull != null);

  ObjectFlagProperty.has(
    String super.name,
    super.value, {
    super.level,
  }) : ifPresent = 'has $name',
       super(
    showName: false,
  );

  final String? ifPresent;

  @override
  String valueToString({ TextTreeConfiguration? parentConfiguration }) {
    if (value != null) {
      if (ifPresent != null) {
        return ifPresent!;
      }
    } else {
      if (ifNull != null) {
        return ifNull!;
      }
    }
    return super.valueToString(parentConfiguration: parentConfiguration);
  }

  @override
  bool get showName {
    if ((value != null && ifPresent == null) || (value == null && ifNull == null)) {
      // We are missing a description for the flag value so we need to show the
      // flag name. The property will have DiagnosticLevel.hidden for this case
      // so users will not see this property in this case unless they are
      // displaying hidden properties.
      return true;
    }
    return super.showName;
  }

  @override
  DiagnosticLevel get level {
    if (value != null) {
      if (ifPresent == null) {
        return DiagnosticLevel.hidden;
      }
    } else {
      if (ifNull == null) {
        return DiagnosticLevel.hidden;
      }
    }

    return super.level;
  }

  @override
  Map<String, Object?> toJsonMap(DiagnosticsSerializationDelegate delegate) {
    final Map<String, Object?> json = super.toJsonMap(delegate);
    if (ifPresent != null) {
      json['ifPresent'] = ifPresent;
    }
    return json;
  }
}

class FlagsSummary<T> extends DiagnosticsProperty<Map<String, T?>> {
  FlagsSummary(
    String super.name,
    Map<String, T?> super.value, {
    super.ifEmpty,
    super.showName,
    super.showSeparator,
    super.level,
  });

  @override
  Map<String, T?> get value => super.value!;

  @override
  String valueToString({TextTreeConfiguration? parentConfiguration}) {
    if (!_hasNonNullEntry() && ifEmpty != null) {
      return ifEmpty!;
    }

    final Iterable<String> formattedValues = _formattedValues();
    if (parentConfiguration != null && !parentConfiguration.lineBreakProperties) {
      // Always display the value as a single line and enclose the iterable
      // value in brackets to avoid ambiguity.
      return '[${formattedValues.join(', ')}]';
    }

    return formattedValues.join(_isSingleLine(style) ? ', ' : '\n');
  }

  @override
  DiagnosticLevel get level {
    if (!_hasNonNullEntry() && ifEmpty == null) {
      return DiagnosticLevel.hidden;
    }
    return super.level;
  }

  @override
  Map<String, Object?> toJsonMap(DiagnosticsSerializationDelegate delegate) {
    final Map<String, Object?> json = super.toJsonMap(delegate);
    if (value.isNotEmpty) {
      json['values'] = _formattedValues().toList();
    }
    return json;
  }

  bool _hasNonNullEntry() => value.values.any((T? o) => o != null);

  // An iterable of each entry's description in [value].
  //
  // For a non-null value, its description is its key.
  //
  // For a null value, it is omitted unless `includeEmpty` is true and
  // [ifEntryNull] contains a corresponding description.
  Iterable<String> _formattedValues() {
    return value.entries
        .where((MapEntry<String, T?> entry) => entry.value != null)
        .map((MapEntry<String, T?> entry) => entry.key);
  }
}

typedef ComputePropertyValueCallback<T> = T? Function();

class DiagnosticsProperty<T> extends DiagnosticsNode {
  DiagnosticsProperty(
    String? name,
    T? value, {
    String? description,
    String? ifNull,
    this.ifEmpty,
    super.showName,
    super.showSeparator,
    this.defaultValue = kNoDefaultValue,
    this.tooltip,
    this.missingIfNull = false,
    super.linePrefix,
    this.expandableValue = false,
    this.allowWrap = true,
    this.allowNameWrap = true,
    DiagnosticsTreeStyle super.style = DiagnosticsTreeStyle.singleLine,
    DiagnosticLevel level = DiagnosticLevel.info,
  }) : _description = description,
       _valueComputed = true,
       _value = value,
       _computeValue = null,
       ifNull = ifNull ?? (missingIfNull ? 'MISSING' : null),
       _defaultLevel = level,
       super(
         name: name,
      );

  DiagnosticsProperty.lazy(
    String? name,
    ComputePropertyValueCallback<T> computeValue, {
    String? description,
    String? ifNull,
    this.ifEmpty,
    super.showName,
    super.showSeparator,
    this.defaultValue = kNoDefaultValue,
    this.tooltip,
    this.missingIfNull = false,
    this.expandableValue = false,
    this.allowWrap = true,
    this.allowNameWrap = true,
    DiagnosticsTreeStyle super.style = DiagnosticsTreeStyle.singleLine,
    DiagnosticLevel level = DiagnosticLevel.info,
  }) : assert(defaultValue == kNoDefaultValue || defaultValue is T?),
       _description = description,
       _valueComputed = false,
       _value = null,
       _computeValue = computeValue,
       _defaultLevel = level,
       ifNull = ifNull ?? (missingIfNull ? 'MISSING' : null),
       super(
         name: name,
       );

  final String? _description;

  final bool expandableValue;

  @override
  final bool allowWrap;

  @override
  final bool allowNameWrap;

  @override
  Map<String, Object?> toJsonMap(DiagnosticsSerializationDelegate delegate) {
    final T? v = value;
    List<Map<String, Object?>>? properties;
    if (delegate.expandPropertyValues && delegate.includeProperties && v is Diagnosticable && getProperties().isEmpty) {
      // Exclude children for expanded nodes to avoid cycles.
      delegate = delegate.copyWith(subtreeDepth: 0, includeProperties: false);
      properties = DiagnosticsNode.toJsonList(
        delegate.filterProperties(v.toDiagnosticsNode().getProperties(), this),
        this,
        delegate,
      );
    }
    final Map<String, Object?> json = super.toJsonMap(delegate);
    if (properties != null) {
      json['properties'] = properties;
    }
    if (defaultValue != kNoDefaultValue) {
      json['defaultValue'] = defaultValue.toString();
    }
    if (ifEmpty != null) {
      json['ifEmpty'] = ifEmpty;
    }
    if (ifNull != null) {
      json['ifNull'] = ifNull;
    }
    if (tooltip != null) {
      json['tooltip'] = tooltip;
    }
    json['missingIfNull'] = missingIfNull;
    if (exception != null) {
      json['exception'] = exception.toString();
    }
    json['propertyType'] = propertyType.toString();
    json['defaultLevel'] = _defaultLevel.name;
    if (value is Diagnosticable || value is DiagnosticsNode) {
      json['isDiagnosticableValue'] = true;
    }
    if (v is num) {
      // TODO(jacob314): Workaround, since JSON.stringify replaces infinity and NaN with null,
      // https://github.com/flutter/flutter/issues/39937#issuecomment-529558033)
      json['value'] = v.isFinite ? v :  v.toString();
    }
    if (value is String || value is bool || value == null) {
      json['value'] = value;
    }
    return json;
  }

  String valueToString({ TextTreeConfiguration? parentConfiguration }) {
    final T? v = value;
    // DiagnosticableTree values are shown using the shorter toStringShort()
    // instead of the longer toString() because the toString() for a
    // DiagnosticableTree value is likely too large to be useful.
    return v is DiagnosticableTree ? v.toStringShort() : v.toString();
  }

  @override
  String toDescription({ TextTreeConfiguration? parentConfiguration }) {
    if (_description != null) {
      return _addTooltip(_description);
    }

    if (exception != null) {
      return 'EXCEPTION (${exception.runtimeType})';
    }

    if (ifNull != null && value == null) {
      return _addTooltip(ifNull!);
    }

    String result = valueToString(parentConfiguration: parentConfiguration);
    if (result.isEmpty && ifEmpty != null) {
      result = ifEmpty!;
    }
    return _addTooltip(result);
  }

  String _addTooltip(String text) {
    return tooltip == null ? text : '$text ($tooltip)';
  }

  final String? ifNull;

  final String? ifEmpty;

  final String? tooltip;

  final bool missingIfNull;

  Type get propertyType => T;

  @override
  T? get value {
    _maybeCacheValue();
    return _value;
  }

  T? _value;

  bool _valueComputed;

  Object? _exception;

  Object? get exception {
    _maybeCacheValue();
    return _exception;
  }

  void _maybeCacheValue() {
    if (_valueComputed) {
      return;
    }

    _valueComputed = true;
    assert(_computeValue != null);
    try {
      _value = _computeValue!();
    } catch (exception) {
      // The error is reported to inspector; rethrowing would destroy the
      // debugging experience.
      _exception = exception;
      _value = null;
    }
  }

  final Object? defaultValue;

  bool get isInteresting => defaultValue == kNoDefaultValue || value != defaultValue;

  final DiagnosticLevel _defaultLevel;

  @override
  DiagnosticLevel get level {
    if (_defaultLevel == DiagnosticLevel.hidden) {
      return _defaultLevel;
    }

    if (exception != null) {
      return DiagnosticLevel.error;
    }

    if (value == null && missingIfNull) {
      return DiagnosticLevel.warning;
    }

    if (!isInteresting) {
      return DiagnosticLevel.fine;
    }

    return _defaultLevel;
  }

  final ComputePropertyValueCallback<T>? _computeValue;

  @override
  List<DiagnosticsNode> getProperties() {
    if (expandableValue) {
      final T? object = value;
      if (object is DiagnosticsNode) {
        return object.getProperties();
      }
      if (object is Diagnosticable) {
        return object.toDiagnosticsNode(style: style).getProperties();
      }
    }
    return const <DiagnosticsNode>[];
  }

  @override
  List<DiagnosticsNode> getChildren() {
    if (expandableValue) {
      final T? object = value;
      if (object is DiagnosticsNode) {
        return object.getChildren();
      }
      if (object is Diagnosticable) {
        return object.toDiagnosticsNode(style: style).getChildren();
      }
    }
    return const <DiagnosticsNode>[];
  }
}

class DiagnosticableNode<T extends Diagnosticable> extends DiagnosticsNode {
  DiagnosticableNode({
    super.name,
    required this.value,
    required super.style,
  });

  @override
  final T value;

  DiagnosticPropertiesBuilder? _cachedBuilder;

  DiagnosticPropertiesBuilder? get builder {
    if (kReleaseMode) {
      return null;
    } else {
      assert(() {
        if (_cachedBuilder == null) {
          _cachedBuilder = DiagnosticPropertiesBuilder();
          value.debugFillProperties(_cachedBuilder!);
        }
        return true;
      }());
      return _cachedBuilder;
    }
  }

  @override
  DiagnosticsTreeStyle get style {
    return kReleaseMode ? DiagnosticsTreeStyle.none : super.style ?? builder!.defaultDiagnosticsTreeStyle;
  }

  @override
  String? get emptyBodyDescription => (kReleaseMode || kProfileMode) ? '' : builder!.emptyBodyDescription;

  @override
  List<DiagnosticsNode> getProperties() => (kReleaseMode || kProfileMode) ? const <DiagnosticsNode>[] : builder!.properties;

  @override
  List<DiagnosticsNode> getChildren() {
    return const<DiagnosticsNode>[];
  }

  @override
  String toDescription({ TextTreeConfiguration? parentConfiguration }) {
    String result = '';
    assert(() {
      result = value.toStringShort();
      return true;
    }());
    return result;
  }
}

class DiagnosticableTreeNode extends DiagnosticableNode<DiagnosticableTree> {
  DiagnosticableTreeNode({
    super.name,
    required super.value,
    required super.style,
  });

  @override
  List<DiagnosticsNode> getChildren() => value.debugDescribeChildren();
}

String shortHash(Object? object) {
  return object.hashCode.toUnsigned(20).toRadixString(16).padLeft(5, '0');
}

String describeIdentity(Object? object) => '${objectRuntimeType(object, '<optimized out>')}#${shortHash(object)}';

@Deprecated(
  'Use the `name` getter on enums instead. '
  'This feature was deprecated after v3.10.0-1.1.pre.'
)
String describeEnum(Object enumEntry) {
  if (enumEntry is Enum) {
    return enumEntry.name;
  }
  final String description = enumEntry.toString();
  final int indexOfDot = description.indexOf('.');
  assert(
    indexOfDot != -1 && indexOfDot < description.length - 1,
    'The provided object "$enumEntry" is not an enum.',
  );
  return description.substring(indexOfDot + 1);
}

class DiagnosticPropertiesBuilder {
  DiagnosticPropertiesBuilder() : properties = <DiagnosticsNode>[];

  DiagnosticPropertiesBuilder.fromProperties(this.properties);

  void add(DiagnosticsNode property) {
    assert(() {
      properties.add(property);
      return true;
    }());
  }

  final List<DiagnosticsNode> properties;

  DiagnosticsTreeStyle defaultDiagnosticsTreeStyle = DiagnosticsTreeStyle.sparse;

  String? emptyBodyDescription;
}

// Examples can assume:
// class ExampleSuperclass with Diagnosticable { late String message; late double stepWidth; late double scale; late double paintExtent; late double hitTestExtent; late double paintExtend; late double maxWidth; late bool primary; late double progress; late int maxLines; late Duration duration; late int depth; Iterable<BoxShadow>? boxShadow; late DiagnosticsTreeStyle style; late bool hasSize; late Matrix4 transform; Map<Listenable, VoidCallback>? handles; late Color color; late bool obscureText; late ImageRepeat repeat; late Size size; late Widget widget; late bool isCurrent; late bool keepAlive; late TextAlign textAlign; }

mixin Diagnosticable {
  String toStringShort() => describeIdentity(this);

  @override
  String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    String? fullString;
    assert(() {
      fullString = toDiagnosticsNode(style: DiagnosticsTreeStyle.singleLine).toString(minLevel: minLevel);
      return true;
    }());
    return fullString ?? toStringShort();
  }

  DiagnosticsNode toDiagnosticsNode({ String? name, DiagnosticsTreeStyle? style }) {
    return DiagnosticableNode<Diagnosticable>(
      name: name,
      value: this,
      style: style,
    );
  }

  @protected
  @mustCallSuper
  void debugFillProperties(DiagnosticPropertiesBuilder properties) { }
}

abstract class DiagnosticableTree with Diagnosticable {
  const DiagnosticableTree();

  String toStringShallow({
    String joiner = ', ',
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
  }) {
    String? shallowString;
    assert(() {
      final StringBuffer result = StringBuffer();
      result.write(toString());
      result.write(joiner);
      final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();
      debugFillProperties(builder);
      result.write(
        builder.properties.where((DiagnosticsNode n) => !n.isFiltered(minLevel))
            .join(joiner),
      );
      shallowString = result.toString();
      return true;
    }());
    return shallowString ?? toString();
  }

  String toStringDeep({
    String prefixLineOne = '',
    String? prefixOtherLines,
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
  }) {
    return toDiagnosticsNode().toStringDeep(prefixLineOne: prefixLineOne, prefixOtherLines: prefixOtherLines, minLevel: minLevel);
  }

  @override
  String toStringShort() => describeIdentity(this);

  @override
  DiagnosticsNode toDiagnosticsNode({ String? name, DiagnosticsTreeStyle? style }) {
    return DiagnosticableTreeNode(
      name: name,
      value: this,
      style: style,
    );
  }

  @protected
  List<DiagnosticsNode> debugDescribeChildren() => const <DiagnosticsNode>[];
}

mixin DiagnosticableTreeMixin implements DiagnosticableTree {
  @override
  String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return toDiagnosticsNode(style: DiagnosticsTreeStyle.singleLine).toString(minLevel: minLevel);
  }

  @override
  String toStringShallow({
    String joiner = ', ',
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
  }) {
    String? shallowString;
    assert(() {
      final StringBuffer result = StringBuffer();
      result.write(toStringShort());
      result.write(joiner);
      final DiagnosticPropertiesBuilder builder = DiagnosticPropertiesBuilder();
      debugFillProperties(builder);
      result.write(
        builder.properties.where((DiagnosticsNode n) => !n.isFiltered(minLevel))
            .join(joiner),
      );
      shallowString = result.toString();
      return true;
    }());
    return shallowString ?? toString();
  }

  @override
  String toStringDeep({
    String prefixLineOne = '',
    String? prefixOtherLines,
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
  }) {
    return toDiagnosticsNode().toStringDeep(prefixLineOne: prefixLineOne, prefixOtherLines: prefixOtherLines, minLevel: minLevel);
  }

  @override
  String toStringShort() => describeIdentity(this);

  @override
  DiagnosticsNode toDiagnosticsNode({ String? name, DiagnosticsTreeStyle? style }) {
    return DiagnosticableTreeNode(
      name: name,
      value: this,
      style: style,
    );
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() => const <DiagnosticsNode>[];

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) { }
}


class DiagnosticsBlock extends DiagnosticsNode {
  DiagnosticsBlock({
    super.name,
    DiagnosticsTreeStyle super.style = DiagnosticsTreeStyle.whitespace,
    bool showName = true,
    super.showSeparator,
    super.linePrefix,
    this.value,
    String? description,
    this.level = DiagnosticLevel.info,
    this.allowTruncate = false,
    List<DiagnosticsNode> children = const<DiagnosticsNode>[],
    List<DiagnosticsNode> properties = const <DiagnosticsNode>[],
  }) : _description = description ?? '',
       _children = children,
       _properties = properties,
    super(
    showName: showName && name != null,
  );

  final List<DiagnosticsNode> _children;
  final List<DiagnosticsNode> _properties;

  @override
  final DiagnosticLevel level;

  final String _description;

  @override
  final Object? value;

  @override
  final bool allowTruncate;

  @override
  List<DiagnosticsNode> getChildren() => _children;

  @override
  List<DiagnosticsNode> getProperties() => _properties;

  @override
  String toDescription({TextTreeConfiguration? parentConfiguration}) => _description;
}

abstract class DiagnosticsSerializationDelegate {
  const factory DiagnosticsSerializationDelegate({
    int subtreeDepth,
    bool includeProperties,
  }) = _DefaultDiagnosticsSerializationDelegate;

  Map<String, Object?> additionalNodeProperties(DiagnosticsNode node);

  List<DiagnosticsNode> filterChildren(List<DiagnosticsNode> nodes, DiagnosticsNode owner);

  List<DiagnosticsNode> filterProperties(List<DiagnosticsNode> nodes, DiagnosticsNode owner);

  List<DiagnosticsNode> truncateNodesList(List<DiagnosticsNode> nodes, DiagnosticsNode? owner);

  DiagnosticsSerializationDelegate delegateForNode(DiagnosticsNode node);

  int get subtreeDepth;

  bool get includeProperties;

  bool get expandPropertyValues;

  DiagnosticsSerializationDelegate copyWith({
    int subtreeDepth,
    bool includeProperties,
  });
}

class _DefaultDiagnosticsSerializationDelegate implements DiagnosticsSerializationDelegate {
  const _DefaultDiagnosticsSerializationDelegate({
    this.includeProperties = false,
    this.subtreeDepth = 0,
  });

  @override
  Map<String, Object?> additionalNodeProperties(DiagnosticsNode node) {
    return const <String, Object?>{};
  }

  @override
  DiagnosticsSerializationDelegate delegateForNode(DiagnosticsNode node) {
    return subtreeDepth > 0 ? copyWith(subtreeDepth: subtreeDepth - 1) : this;
  }

  @override
  bool get expandPropertyValues => false;

  @override
  List<DiagnosticsNode> filterChildren(List<DiagnosticsNode> nodes, DiagnosticsNode owner) {
    return nodes;
  }

  @override
  List<DiagnosticsNode> filterProperties(List<DiagnosticsNode> nodes, DiagnosticsNode owner) {
    return nodes;
  }

  @override
  final bool includeProperties;

  @override
  final int subtreeDepth;

  @override
  List<DiagnosticsNode> truncateNodesList(List<DiagnosticsNode> nodes, DiagnosticsNode? owner) {
    return nodes;
  }

  @override
  DiagnosticsSerializationDelegate copyWith({int? subtreeDepth, bool? includeProperties}) {
    return _DefaultDiagnosticsSerializationDelegate(
      subtreeDepth: subtreeDepth ?? this.subtreeDepth,
      includeProperties: includeProperties ?? this.includeProperties,
    );
  }
}