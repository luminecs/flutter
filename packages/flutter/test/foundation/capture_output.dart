import 'dart:async';
import 'package:flutter/foundation.dart';

List<String> captureOutput(VoidCallback fn) {
  final List<String> log = <String>[];

  runZoned<void>(fn, zoneSpecification: ZoneSpecification(
    print: (
      Zone self,
      ZoneDelegate parent,
      Zone zone,
      String line,
    ) {
      log.add(line);
    },
  ));

  return log;
}
