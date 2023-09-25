// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base/utils.dart';

abstract class WebCompilerConfig {
  const WebCompilerConfig();

  bool get isWasm;

  Map<String, String> toBuildSystemEnvironment();

  Map<String, Object> get buildEventAnalyticsValues => <String, Object>{
        'wasm-compile': isWasm,
      };
}

class JsCompilerConfig extends WebCompilerConfig {
  const JsCompilerConfig({
    required this.csp,
    required this.dumpInfo,
    required this.nativeNullAssertions,
    required this.optimizationLevel,
    required this.noFrequencyBasedMinification,
    required this.sourceMaps,
  });

  const JsCompilerConfig.run({required bool nativeNullAssertions})
      : this(
          csp: false,
          dumpInfo: false,
          nativeNullAssertions: nativeNullAssertions,
          noFrequencyBasedMinification: false,
          optimizationLevel: kDart2jsDefaultOptimizationLevel,
          sourceMaps: true,
        );

  factory JsCompilerConfig.fromBuildSystemEnvironment(
          Map<String, String> defines) =>
      JsCompilerConfig(
        csp: defines[kCspMode] == 'true',
        dumpInfo: defines[kDart2jsDumpInfo] == 'true',
        nativeNullAssertions: defines[kNativeNullAssertions] == 'true',
        optimizationLevel: defines[kDart2jsOptimization] ?? kDart2jsDefaultOptimizationLevel,
        noFrequencyBasedMinification: defines[kDart2jsNoFrequencyBasedMinification] == 'true',
        sourceMaps: defines[kSourceMapsEnabled] == 'true',
      );

  static const String kDart2jsDefaultOptimizationLevel = 'O4';

  static const String kDart2jsOptimization = 'Dart2jsOptimization';

  static const String kDart2jsDumpInfo = 'Dart2jsDumpInfo';

  static const String kDart2jsNoFrequencyBasedMinification =
      'Dart2jsNoFrequencyBasedMinification';

  static const String kCspMode = 'cspMode';

  static const String kSourceMapsEnabled = 'SourceMaps';

  static const String kNativeNullAssertions = 'NativeNullAssertions';

  final bool csp;

  final bool dumpInfo;

  final bool nativeNullAssertions;

  // If `--no-frequency-based-minification` should be passed to dart2js
  // TODO(kevmoo): consider renaming this to be "positive". Double negatives are confusing.
  final bool noFrequencyBasedMinification;

  // TODO(kevmoo): consider storing this as an [int] and validating it!
  final String optimizationLevel;

  final bool sourceMaps;

  @override
  bool get isWasm => false;

  @override
  Map<String, String> toBuildSystemEnvironment() => <String, String>{
        kCspMode: csp.toString(),
        kDart2jsDumpInfo: dumpInfo.toString(),
        kNativeNullAssertions: nativeNullAssertions.toString(),
        kDart2jsNoFrequencyBasedMinification: noFrequencyBasedMinification.toString(),
        kDart2jsOptimization: optimizationLevel,
        kSourceMapsEnabled: sourceMaps.toString(),
      };

  List<String> toSharedCommandOptions() => <String>[
        if (nativeNullAssertions) '--native-null-assertions',
        if (!sourceMaps) '--no-source-maps',
      ];

  List<String> toCommandOptions() => <String>[
        ...toSharedCommandOptions(),
        '-$optimizationLevel',
        if (dumpInfo) '--dump-info',
        if (noFrequencyBasedMinification) '--no-frequency-based-minification',
        if (csp) '--csp',
      ];
}

class WasmCompilerConfig extends WebCompilerConfig {
  const WasmCompilerConfig({
    required this.omitTypeChecks,
    required this.wasmOpt,
  });

  factory WasmCompilerConfig.fromBuildSystemEnvironment(
          Map<String, String> defines) =>
      WasmCompilerConfig(
        omitTypeChecks: defines[kOmitTypeChecks] == 'true',
        wasmOpt: WasmOptLevel.values.byName(defines[kRunWasmOpt]!),
      );

  static const String kOmitTypeChecks = 'WasmOmitTypeChecks';

  static const String kRunWasmOpt = 'RunWasmOpt';

  final bool omitTypeChecks;

  final WasmOptLevel wasmOpt;

  @override
  bool get isWasm => true;

  bool get runWasmOpt => wasmOpt == WasmOptLevel.full || wasmOpt == WasmOptLevel.debug;

  @override
  Map<String, String> toBuildSystemEnvironment() => <String, String>{
    kOmitTypeChecks: omitTypeChecks.toString(),
    kRunWasmOpt: wasmOpt.name,
  };

  List<String> toCommandOptions() => <String>[
    if (omitTypeChecks) '--omit-type-checks',
  ];

  @override
  Map<String, Object> get buildEventAnalyticsValues => <String, Object>{
    ...super.buildEventAnalyticsValues,
    ...toBuildSystemEnvironment(),
  };
}

enum WasmOptLevel implements CliEnum {
  full,
  debug,
  none;

  static const WasmOptLevel defaultValue = WasmOptLevel.full;

  @override
  String get cliName => name;

  @override
  String get helpText => switch (this) {
    WasmOptLevel.none => 'wasm-opt is not run. Fastest build; bigger, slower output.',
    WasmOptLevel.debug => 'Similar to `${WasmOptLevel.full.name}`, but member names are preserved. Debugging is easier, but size is a bit bigger.',
    WasmOptLevel.full => 'wasm-opt is run. Build time is slower, but output is smaller and faster.',
  };
}