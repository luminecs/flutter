// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart' show File;

import 'globals.dart';
import 'proto/conductor_state.pb.dart' as pb;
import 'repository.dart';
import 'state.dart';
import 'stdio.dart' show Stdio;

abstract class Context {
  const Context({
    required this.checkouts,
    required this.stateFile,
  });

  final Checkouts checkouts;
  final File stateFile;
  Stdio get stdio => checkouts.stdio;

  Future<bool> prompt(String message) async {
    stdio.write('${message.trim()} (y/n) ');
    final String response = stdio.readLineSync().trim();
    final String firstChar = response[0].toUpperCase();
    if (firstChar == 'Y') {
      return true;
    }
    if (firstChar == 'N') {
      return false;
    }
    throw ConductorException(
      'Unknown user input (expected "y" or "n"): $response',
    );
  }

  void updateState(pb.ConductorState state, [List<String> logs = const <String>[]]) {
    writeStateToFile(stateFile, state, logs);
  }
}