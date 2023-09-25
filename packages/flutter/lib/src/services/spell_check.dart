
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'system_channels.dart';

@immutable
class SuggestionSpan {
  const SuggestionSpan(this.range, this.suggestions);

  final TextRange range;

  final List<String> suggestions;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is SuggestionSpan &&
        other.range.start == range.start &&
        other.range.end == range.end &&
        listEquals<String>(other.suggestions, suggestions);
  }

  @override
  int get hashCode => Object.hash(range.start, range.end, Object.hashAll(suggestions));
}

@immutable
class SpellCheckResults {
  const SpellCheckResults(this.spellCheckedText, this.suggestionSpans);

  final String spellCheckedText;

  final List<SuggestionSpan> suggestionSpans;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
        return true;
    }

    return other is SpellCheckResults &&
        other.spellCheckedText == spellCheckedText &&
        listEquals<SuggestionSpan>(other.suggestionSpans, suggestionSpans);
  }

  @override
  int get hashCode => Object.hash(spellCheckedText, Object.hashAll(suggestionSpans));
}

abstract class SpellCheckService {
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale, String text
  );
}

class DefaultSpellCheckService implements SpellCheckService {
  DefaultSpellCheckService() {
    spellCheckChannel = SystemChannels.spellCheck;
  }

  SpellCheckResults? lastSavedResults;

  late MethodChannel spellCheckChannel;

  static List<SuggestionSpan> mergeResults(
      List<SuggestionSpan> oldResults, List<SuggestionSpan> newResults) {
    final List<SuggestionSpan> mergedResults = <SuggestionSpan>[];

    SuggestionSpan oldSpan;
    SuggestionSpan newSpan;
    int oldSpanPointer = 0;
    int newSpanPointer = 0;

    while (oldSpanPointer < oldResults.length &&
        newSpanPointer < newResults.length) {
      oldSpan = oldResults[oldSpanPointer];
      newSpan = newResults[newSpanPointer];

      if (oldSpan.range.start == newSpan.range.start) {
        mergedResults.add(oldSpan);
        oldSpanPointer++;
        newSpanPointer++;
      } else {
        if (oldSpan.range.start < newSpan.range.start) {
          mergedResults.add(oldSpan);
          oldSpanPointer++;
        } else {
          mergedResults.add(newSpan);
          newSpanPointer++;
        }
      }
    }

    mergedResults.addAll(oldResults.sublist(oldSpanPointer));
    mergedResults.addAll(newResults.sublist(newSpanPointer));

    return mergedResults;
  }

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
      Locale locale, String text) async {

    final List<dynamic> rawResults;
    final String languageTag = locale.toLanguageTag();

    try {
      rawResults = await spellCheckChannel.invokeMethod(
        'SpellCheck.initiateSpellCheck',
        <String>[languageTag, text],
      ) as List<dynamic>;
    } catch (e) {
      // Spell check request canceled due to pending request.
      return null;
    }

    List<SuggestionSpan> suggestionSpans = <SuggestionSpan>[];

    for (final dynamic result in rawResults) {
      final Map<String, dynamic> resultMap =
        Map<String,dynamic>.from(result as Map<dynamic, dynamic>);
      suggestionSpans.add(
        SuggestionSpan(
          TextRange(
            start: resultMap['startIndex'] as int,
            end: resultMap['endIndex'] as int),
          (resultMap['suggestions'] as List<dynamic>).cast<String>(),
        )
      );
    }

    if (lastSavedResults != null) {
      // Merge current and previous spell check results if between requests,
      // the text has not changed but the spell check results have.
      final bool textHasNotChanged = lastSavedResults!.spellCheckedText == text;
      final bool spansHaveChanged =
          listEquals(lastSavedResults!.suggestionSpans, suggestionSpans);

      if (textHasNotChanged && spansHaveChanged) {
        suggestionSpans = mergeResults(lastSavedResults!.suggestionSpans, suggestionSpans);
      }
    }
    lastSavedResults = SpellCheckResults(text, suggestionSpans);

    return suggestionSpans;
  }
}