
// The reduced test set tag is missing. This should fail analysis.
@Tags(<String>['some-other-tag'])
library;

import 'package:test/test.dart';

import 'golden_class.dart';

void main() {
  matchesGoldenFile('missing_tag.png');
}