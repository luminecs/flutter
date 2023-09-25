// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The widget in this file is an empty mock for non-web platforms. See
// `_platform_selectable_region_context_menu_web.dart` for the web
// implementation.

import 'framework.dart';
import 'selection_container.dart';

@visibleForTesting
typedef RegisterViewFactory = void Function(String, Object Function(int viewId), {bool isVisible});

class PlatformSelectableRegionContextMenu extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  PlatformSelectableRegionContextMenu({
    // ignore: avoid_unused_constructor_parameters
    required Widget child,
    super.key,
  });

  static void attach(SelectionContainerDelegate client) => throw UnimplementedError();

  static void detach(SelectionContainerDelegate client) => throw UnimplementedError();

  @visibleForTesting
  static RegisterViewFactory? debugOverrideRegisterViewFactory;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}