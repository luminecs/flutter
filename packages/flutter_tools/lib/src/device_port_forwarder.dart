
import 'dart:async';

import 'base/io.dart';

class ForwardedPort {
  ForwardedPort(this.hostPort, this.devicePort) : context = null;
  ForwardedPort.withContext(this.hostPort, this.devicePort, this.context);

  final int hostPort;
  final int devicePort;
  final Process? context;

  @override
  String toString() => 'ForwardedPort HOST:$hostPort to DEVICE:$devicePort';

  void dispose() {
    if (context != null) {
      context!.kill();
    }
  }
}

abstract class DevicePortForwarder {
  List<ForwardedPort> get forwardedPorts;

  Future<int> forward(int devicePort, { int? hostPort });

  Future<void> unforward(ForwardedPort forwardedPort);

  Future<void> dispose();
}

// A port forwarder which does not support forwarding ports.
class NoOpDevicePortForwarder implements DevicePortForwarder {
  const NoOpDevicePortForwarder();

  @override
  Future<int> forward(int devicePort, { int? hostPort }) async => devicePort;

  @override
  List<ForwardedPort> get forwardedPorts => <ForwardedPort>[];

  @override
  Future<void> unforward(ForwardedPort forwardedPort) async { }

  @override
  Future<void> dispose() async { }
}