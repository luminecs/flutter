
import 'dart:async';

import 'system_channels.dart';

// Examples can assume:
// // so that we can import the fake "split_component.dart" in an example below:
// // ignore_for_file: uri_does_not_exist

abstract final class DeferredComponent {
  // TODO(garyq): We should eventually expand this to install components by loadingUnitId
  // as well as componentName, but currently, loadingUnitId is opaque to the dart code
  // so this is not possible. The API has been left flexible to allow adding
  // loadingUnitId as a parameter.

  static Future<void> installDeferredComponent({required String componentName}) async {
    await SystemChannels.deferredComponent.invokeMethod<void>(
      'installDeferredComponent',
      <String, dynamic>{ 'loadingUnitId': -1, 'componentName': componentName },
    );
  }

  static Future<void> uninstallDeferredComponent({required String componentName}) async {
    await SystemChannels.deferredComponent.invokeMethod<void>(
      'uninstallDeferredComponent',
      <String, dynamic>{ 'loadingUnitId': -1, 'componentName': componentName },
    );
  }
}