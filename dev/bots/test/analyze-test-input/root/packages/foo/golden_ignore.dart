
// This would fail analysis, but it is ignored
// flutter_ignore_for_file: golden_tag (see analyze.dart)

@Tags(<String>['some-other-tag'])
library;

import 'package:test/test.dart';

import 'golden_class.dart';

void main() {
  matchesGoldenFile('missing_tag.png');
}