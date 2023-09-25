
import 'dart:ui' as ui show ParagraphBuilder, StringAttribute;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'basic_types.dart';
import 'text_painter.dart';
import 'text_scaler.dart';
import 'text_span.dart';
import 'text_style.dart';

// Examples can assume:
// late InlineSpan myInlineSpan;

class Accumulator {
  Accumulator([this._value = 0]);

  int get value => _value;
  int _value;

  void increment(int addend) {
    assert(addend >= 0);
    _value += addend;
  }
}
typedef InlineSpanVisitor = bool Function(InlineSpan span);

@immutable
class InlineSpanSemanticsInformation {
  const InlineSpanSemanticsInformation(
    this.text, {
    this.isPlaceholder = false,
    this.semanticsLabel,
    this.stringAttributes = const <ui.StringAttribute>[],
    this.recognizer,
  }) : assert(!isPlaceholder || (text == '\uFFFC' && semanticsLabel == null && recognizer == null)),
       requiresOwnNode = isPlaceholder || recognizer != null;

  static const InlineSpanSemanticsInformation placeholder = InlineSpanSemanticsInformation('\uFFFC', isPlaceholder: true);

  final String text;

  final String? semanticsLabel;

  final GestureRecognizer? recognizer;

  final bool isPlaceholder;

  final bool requiresOwnNode;

  final List<ui.StringAttribute> stringAttributes;

  @override
  bool operator ==(Object other) {
    return other is InlineSpanSemanticsInformation
        && other.text == text
        && other.semanticsLabel == semanticsLabel
        && other.recognizer == recognizer
        && other.isPlaceholder == isPlaceholder
        && listEquals<ui.StringAttribute>(other.stringAttributes, stringAttributes);
  }

  @override
  int get hashCode => Object.hash(text, semanticsLabel, recognizer, isPlaceholder);

  @override
  String toString() => '${objectRuntimeType(this, 'InlineSpanSemanticsInformation')}{text: $text, semanticsLabel: $semanticsLabel, recognizer: $recognizer}';
}

List<InlineSpanSemanticsInformation> combineSemanticsInfo(List<InlineSpanSemanticsInformation> infoList) {
  final List<InlineSpanSemanticsInformation> combined = <InlineSpanSemanticsInformation>[];
  String workingText = '';
  String workingLabel = '';
  List<ui.StringAttribute> workingAttributes = <ui.StringAttribute>[];
  for (final InlineSpanSemanticsInformation info in infoList) {
    if (info.requiresOwnNode) {
      combined.add(InlineSpanSemanticsInformation(
        workingText,
        semanticsLabel: workingLabel,
        stringAttributes: workingAttributes,
      ));
      workingText = '';
      workingLabel = '';
      workingAttributes = <ui.StringAttribute>[];
      combined.add(info);
    } else {
      workingText += info.text;
      final String effectiveLabel = info.semanticsLabel ?? info.text;
      for (final ui.StringAttribute infoAttribute in info.stringAttributes) {
        workingAttributes.add(
          infoAttribute.copy(
            range: TextRange(
              start: infoAttribute.range.start + workingLabel.length,
              end: infoAttribute.range.end + workingLabel.length,
            ),
          ),
        );
      }
      workingLabel += effectiveLabel;

    }
  }
  combined.add(InlineSpanSemanticsInformation(
    workingText,
    semanticsLabel: workingLabel,
    stringAttributes: workingAttributes,
  ));
  return combined;
}

@immutable
abstract class InlineSpan extends DiagnosticableTree {
  const InlineSpan({
    this.style,
  });

  final TextStyle? style;

  void build(ui.ParagraphBuilder builder, {
    TextScaler textScaler = TextScaler.noScaling,
    List<PlaceholderDimensions>? dimensions,
  });

  bool visitChildren(InlineSpanVisitor visitor);

  bool visitDirectChildren(InlineSpanVisitor visitor);

  InlineSpan? getSpanForPosition(TextPosition position) {
    assert(debugAssertIsValid());
    final Accumulator offset = Accumulator();
    InlineSpan? result;
    visitChildren((InlineSpan span) {
      result = span.getSpanForPositionVisitor(position, offset);
      return result == null;
    });
    return result;
  }

  @protected
  InlineSpan? getSpanForPositionVisitor(TextPosition position, Accumulator offset);

  String toPlainText({bool includeSemanticsLabels = true, bool includePlaceholders = true}) {
    final StringBuffer buffer = StringBuffer();
    computeToPlainText(buffer, includeSemanticsLabels: includeSemanticsLabels, includePlaceholders: includePlaceholders);
    return buffer.toString();
  }

  List<InlineSpanSemanticsInformation> getSemanticsInformation() {
    final List<InlineSpanSemanticsInformation> collector = <InlineSpanSemanticsInformation>[];
    computeSemanticsInformation(collector);
    return collector;
  }

  @protected
  void computeSemanticsInformation(List<InlineSpanSemanticsInformation> collector);

  @protected
  void computeToPlainText(StringBuffer buffer, {bool includeSemanticsLabels = true, bool includePlaceholders = true});

  int? codeUnitAt(int index) {
    if (index < 0) {
      return null;
    }
    final Accumulator offset = Accumulator();
    int? result;
    visitChildren((InlineSpan span) {
      result = span.codeUnitAtVisitor(index, offset);
      return result == null;
    });
    return result;
  }

  @protected
  int? codeUnitAtVisitor(int index, Accumulator offset);

  bool debugAssertIsValid() => true;

  RenderComparison compareTo(InlineSpan other);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is InlineSpan
        && other.style == style;
  }

  @override
  int get hashCode => style.hashCode;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.defaultDiagnosticsTreeStyle = DiagnosticsTreeStyle.whitespace;
    style?.debugFillProperties(properties);
  }
}