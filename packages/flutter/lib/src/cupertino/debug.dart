
import 'package:flutter/widgets.dart';

import 'localizations.dart';

// Examples can assume:
// late BuildContext context;

bool debugCheckHasCupertinoLocalizations(BuildContext context) {
  assert(() {
    if (Localizations.of<CupertinoLocalizations>(context, CupertinoLocalizations) == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No CupertinoLocalizations found.'),
        ErrorDescription(
          '${context.widget.runtimeType} widgets require CupertinoLocalizations '
          'to be provided by a Localizations widget ancestor.',
        ),
        ErrorDescription(
          'The cupertino library uses Localizations to generate messages, '
          'labels, and abbreviations.',
        ),
        ErrorHint(
          'To introduce a CupertinoLocalizations, either use a '
          'CupertinoApp at the root of your application to include them '
          'automatically, or add a Localization widget with a '
          'CupertinoLocalizations delegate.',
        ),
        ...context.describeMissingAncestor(expectedAncestorType: CupertinoLocalizations),
      ]);
    }
    return true;
  }());
  return true;
}