import '_platform_io.dart' if (dart.library.js_util) '_platform_web.dart'
    as platform;

//
// When adding support for a new platform (e.g. Windows Phone, Raspberry Pi),
// first create a new value on the [TargetPlatform] enum, then add a rule for
// selecting that platform in `_platform_io.dart` and `_platform_web.dart`.
//
// It would be incorrect to make a platform that isn't supported by
// [TargetPlatform] default to the behavior of another platform, because doing
// that would mean we'd be stuck with that platform forever emulating the other,
// and we'd never be able to introduce dedicated behavior for that platform
// (since doing so would be a big breaking change).
TargetPlatform get defaultTargetPlatform => platform.defaultTargetPlatform;

//
// When you add values here, make sure to also add them to
// nextPlatform() in flutter_tools/lib/src/resident_runner.dart so that
// the tool can support the new platform for its "o" option.
enum TargetPlatform {
  android,

  fuchsia,

  iOS,

  linux,

  macOS,

  windows,
}

TargetPlatform? debugDefaultTargetPlatformOverride;
