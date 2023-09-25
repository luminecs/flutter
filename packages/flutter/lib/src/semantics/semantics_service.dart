// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show TextDirection;

import 'package:flutter/services.dart' show SystemChannels;

import 'semantics_event.dart' show AnnounceSemanticsEvent, Assertiveness, TooltipSemanticsEvent;

export 'dart:ui' show TextDirection;

abstract final class SemanticsService {
  static Future<void> announce(String message, TextDirection textDirection, {Assertiveness assertiveness = Assertiveness.polite}) async {
    final AnnounceSemanticsEvent event = AnnounceSemanticsEvent(message, textDirection, assertiveness: assertiveness);
    await SystemChannels.accessibility.send(event.toMap());
  }

  static Future<void> tooltip(String message) async {
    final TooltipSemanticsEvent event = TooltipSemanticsEvent(message);
    await SystemChannels.accessibility.send(event.toMap());
  }
}