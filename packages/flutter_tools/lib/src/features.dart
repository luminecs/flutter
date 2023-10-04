import 'base/context.dart';

FeatureFlags get featureFlags => context.get<FeatureFlags>()!;

abstract class FeatureFlags {
  const FeatureFlags();

  bool get isLinuxEnabled => false;

  bool get isMacOSEnabled => false;

  bool get isWebEnabled => false;

  bool get isWindowsEnabled => false;

  bool get isAndroidEnabled => true;

  bool get isIOSEnabled => true;

  bool get isFuchsiaEnabled => true;

  bool get areCustomDevicesEnabled => false;

  bool get isFlutterWebWasmEnabled => false;

  bool get isCliAnimationEnabled => true;

  bool get isNativeAssetsEnabled => false;

  bool isEnabled(Feature feature);
}

const List<Feature> allFeatures = <Feature>[
  flutterWebFeature,
  flutterLinuxDesktopFeature,
  flutterMacOSDesktopFeature,
  flutterWindowsDesktopFeature,
  flutterAndroidFeature,
  flutterIOSFeature,
  flutterFuchsiaFeature,
  flutterCustomDevicesFeature,
  flutterWebWasm,
  cliAnimation,
  nativeAssets,
];

Iterable<Feature> get allConfigurableFeatures =>
    allFeatures.where((Feature feature) => feature.configSetting != null);

const Feature flutterWebFeature = Feature.fullyEnabled(
  name: 'Flutter for web',
  configSetting: 'enable-web',
  environmentOverride: 'FLUTTER_WEB',
);

const Feature flutterMacOSDesktopFeature = Feature.fullyEnabled(
  name: 'support for desktop on macOS',
  configSetting: 'enable-macos-desktop',
  environmentOverride: 'FLUTTER_MACOS',
);

const Feature flutterLinuxDesktopFeature = Feature.fullyEnabled(
  name: 'support for desktop on Linux',
  configSetting: 'enable-linux-desktop',
  environmentOverride: 'FLUTTER_LINUX',
);

const Feature flutterWindowsDesktopFeature = Feature.fullyEnabled(
  name: 'support for desktop on Windows',
  configSetting: 'enable-windows-desktop',
  environmentOverride: 'FLUTTER_WINDOWS',
);

const Feature flutterAndroidFeature = Feature.fullyEnabled(
  name: 'Flutter for Android',
  configSetting: 'enable-android',
);

const Feature flutterIOSFeature = Feature.fullyEnabled(
  name: 'Flutter for iOS',
  configSetting: 'enable-ios',
);

const Feature flutterFuchsiaFeature = Feature(
  name: 'Flutter for Fuchsia',
  configSetting: 'enable-fuchsia',
  environmentOverride: 'FLUTTER_FUCHSIA',
  master: FeatureChannelSetting(
    available: true,
  ),
);

const Feature flutterCustomDevicesFeature = Feature(
  name: 'early support for custom device types',
  configSetting: 'enable-custom-devices',
  environmentOverride: 'FLUTTER_CUSTOM_DEVICES',
  master: FeatureChannelSetting(
    available: true,
  ),
  beta: FeatureChannelSetting(
    available: true,
  ),
  stable: FeatureChannelSetting(
    available: true,
  ),
);

const Feature flutterWebWasm = Feature(
  name: 'WebAssembly compilation from flutter build web',
  environmentOverride: 'FLUTTER_WEB_WASM',
  master: FeatureChannelSetting(
    available: true,
    enabledByDefault: true,
  ),
);

const Feature cliAnimation = Feature.fullyEnabled(
  name: 'animations in the command line interface',
  configSetting: 'cli-animations',
);

const Feature nativeAssets = Feature(
  name: 'native assets compilation and bundling',
  configSetting: 'enable-native-assets',
  environmentOverride: 'FLUTTER_NATIVE_ASSETS',
  master: FeatureChannelSetting(
    available: true,
  ),
);

class Feature {
  const Feature(
      {required this.name,
      this.environmentOverride,
      this.configSetting,
      this.extraHelpText,
      this.master = const FeatureChannelSetting(),
      this.beta = const FeatureChannelSetting(),
      this.stable = const FeatureChannelSetting()});

  const Feature.fullyEnabled(
      {required this.name,
      this.environmentOverride,
      this.configSetting,
      this.extraHelpText})
      : master = const FeatureChannelSetting(
          available: true,
          enabledByDefault: true,
        ),
        beta = const FeatureChannelSetting(
          available: true,
          enabledByDefault: true,
        ),
        stable = const FeatureChannelSetting(
          available: true,
          enabledByDefault: true,
        );

  final String name;

  final FeatureChannelSetting master;

  final FeatureChannelSetting beta;

  final FeatureChannelSetting stable;

  final String? environmentOverride;

  final String? configSetting;

  final String? extraHelpText;

  String? generateHelpMessage() {
    if (configSetting == null) {
      return null;
    }
    final StringBuffer buffer = StringBuffer('Enable or disable $name.');
    final List<String> channels = <String>[
      if (master.available) 'master',
      if (beta.available) 'beta',
      if (stable.available) 'stable',
    ];
    // Add channel info for settings only on some channels.
    if (channels.length == 1) {
      buffer.write(
          '\nThis setting applies only to the ${channels.single} channel.');
    } else if (channels.length == 2) {
      buffer.write(
          '\nThis setting applies only to the ${channels.join(' and ')} channels.');
    }
    if (extraHelpText != null) {
      buffer.write(' $extraHelpText');
    }
    return buffer.toString();
  }

  FeatureChannelSetting getSettingForChannel(String channel) {
    switch (channel) {
      case 'stable':
        return stable;
      case 'beta':
        return beta;
      case 'master':
      default:
        return master;
    }
  }
}

class FeatureChannelSetting {
  const FeatureChannelSetting({
    this.available = false,
    this.enabledByDefault = false,
  });

  final bool available;

  final bool enabledByDefault;
}
