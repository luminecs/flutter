import 'package:flutter/foundation.dart';

import 'system_channels.dart';

abstract final class SystemNavigator {
  static Future<void> setFrameworkHandlesBack(bool frameworkHandlesBack) async {
    // Currently, this method call is only relevant on Android.
    if (kIsWeb) {
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return;
      case TargetPlatform.android:
        return SystemChannels.platform.invokeMethod<void>(
          'SystemNavigator.setFrameworkHandlesBack',
          frameworkHandlesBack,
        );
    }
  }

  static Future<void> pop({bool? animated}) async {
    await SystemChannels.platform.invokeMethod<void>('SystemNavigator.pop', animated);
  }

  static Future<void> selectSingleEntryHistory() {
    return SystemChannels.navigation.invokeMethod<void>('selectSingleEntryHistory');
  }

  static Future<void> selectMultiEntryHistory() {
    return SystemChannels.navigation.invokeMethod<void>('selectMultiEntryHistory');
  }

  static Future<void> routeInformationUpdated({
    @Deprecated(
      'Pass Uri.parse(location) to uri parameter instead. '
      'This feature was deprecated after v3.8.0-3.0.pre.'
    )
    String? location,
    Uri? uri,
    Object? state,
    bool replace = false,
  }) {
    assert((location != null) != (uri != null), 'One of uri or location must be provided, but not both.');
    uri ??= Uri.parse(location!);
    return SystemChannels.navigation.invokeMethod<void>(
      'routeInformationUpdated',
      <String, dynamic>{
        'uri': uri.toString(),
        'state': state,
        'replace': replace,
      },
    );
  }
}