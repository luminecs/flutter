// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library flutter_test;

export 'dart:async' show Future;

export 'src/_goldens_io.dart' if (dart.library.html) 'src/_goldens_web.dart';
export 'src/_matchers_io.dart' if (dart.library.html) 'src/_matchers_web.dart';
export 'src/accessibility.dart';
export 'src/animation_sheet.dart';
export 'src/binding.dart';
export 'src/controller.dart';
export 'src/deprecated.dart';
export 'src/event_simulation.dart';
export 'src/finders.dart';
export 'src/frame_timing_summarizer.dart';
export 'src/goldens.dart';
export 'src/image.dart';
export 'src/matchers.dart';
export 'src/mock_canvas.dart';
export 'src/mock_event_channel.dart';
export 'src/nonconst.dart';
export 'src/platform.dart';
export 'src/recording_canvas.dart';
export 'src/restoration.dart';
export 'src/stack_manipulation.dart';
export 'src/test_async_utils.dart';
export 'src/test_compat.dart';
export 'src/test_default_binary_messenger.dart';
export 'src/test_exception_reporter.dart';
export 'src/test_pointer.dart';
export 'src/test_text_input.dart';
export 'src/test_vsync.dart';
export 'src/tree_traversal.dart';
export 'src/widget_tester.dart';
export 'src/window.dart';