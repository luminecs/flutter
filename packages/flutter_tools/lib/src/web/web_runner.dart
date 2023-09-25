
import '../base/context.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/net.dart';
import '../base/time.dart';
import '../device.dart';
import '../project.dart';
import '../reporting/reporting.dart';
import '../resident_runner.dart';

WebRunnerFactory? get webRunnerFactory => context.get<WebRunnerFactory>();

// Hack to hide web imports for google3.
abstract class WebRunnerFactory {
  const WebRunnerFactory();

  ResidentRunner createWebRunner(
    FlutterDevice device, {
    String? target,
    required bool stayResident,
    required FlutterProject flutterProject,
    required bool? ipv6,
    required DebuggingOptions debuggingOptions,
    UrlTunneller? urlTunneller,
    required Logger logger,
    required FileSystem fileSystem,
    required SystemClock systemClock,
    required Usage usage,
    bool machine = false,
  });
}