
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');

const bool kProfileMode = bool.fromEnvironment('dart.vm.profile');

const bool kDebugMode = !kReleaseMode && !kProfileMode;

const double precisionErrorTolerance = 1e-10;

const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');