// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/web_benchmarks.dart';

Future<void> main() async {
  await task(() async {
    return runWebBenchmark((
      webRenderer: 'html',
      useWasm: false
    ));
  });
}