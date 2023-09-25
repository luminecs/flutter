// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base/context.dart';
import '../build_info.dart';
import '../project.dart';

AndroidBuilder? get androidBuilder {
  return context.get<AndroidBuilder>();
}

abstract class AndroidBuilder {
  const AndroidBuilder();
  Future<void> buildAar({
    required FlutterProject project,
    required Set<AndroidBuildInfo> androidBuildInfo,
    required String target,
    String? outputDirectoryPath,
    required String buildNumber,
  });

  Future<void> buildApk({
    required FlutterProject project,
    required AndroidBuildInfo androidBuildInfo,
    required String target,
    bool configOnly = false,
  });

  Future<void> buildAab({
    required FlutterProject project,
    required AndroidBuildInfo androidBuildInfo,
    required String target,
    bool validateDeferredComponents = true,
    bool deferredComponentsEnabled = false,
    bool configOnly = false,
  });

  Future<List<String>> getBuildVariants({required FlutterProject project});

  Future<void> outputsAppLinkSettings(
    String buildVariant, {
    required FlutterProject project,
  });
}