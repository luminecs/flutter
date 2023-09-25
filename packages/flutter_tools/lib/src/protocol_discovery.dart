
import 'dart:async';

import 'base/io.dart';
import 'base/logger.dart';
import 'device.dart';
import 'device_port_forwarder.dart';
import 'globals.dart' as globals;

class ProtocolDiscovery {
  ProtocolDiscovery._(
    this.logReader,
    this.serviceName, {
    this.portForwarder,
    required this.throttleDuration,
    this.hostPort,
    this.devicePort,
    required bool ipv6,
    required Logger logger,
  }) : _logger = logger,
       _ipv6 = ipv6 {
    _deviceLogSubscription = logReader.logLines.listen(
      _handleLine,
      onDone: _stopScrapingLogs,
    );
  }

  factory ProtocolDiscovery.vmService(
    DeviceLogReader logReader, {
    DevicePortForwarder? portForwarder,
    Duration? throttleDuration,
    int? hostPort,
    int? devicePort,
    required bool ipv6,
    required Logger logger,
  }) {
    const String kVmServiceService = 'VM Service';
    return ProtocolDiscovery._(
      logReader,
      kVmServiceService,
      portForwarder: portForwarder,
      throttleDuration: throttleDuration ?? const Duration(milliseconds: 200),
      hostPort: hostPort,
      devicePort: devicePort,
      ipv6: ipv6,
      logger: logger,
    );
  }

  final DeviceLogReader logReader;
  final String serviceName;
  final DevicePortForwarder? portForwarder;
  final int? hostPort;
  final int? devicePort;
  final bool _ipv6;
  final Logger _logger;

  final Duration throttleDuration;

  StreamSubscription<String>? _deviceLogSubscription;
  final _BufferedStreamController<Uri> _uriStreamController = _BufferedStreamController<Uri>();

  // TODO(egarciad): replace `uri` for `uris`.
  Future<Uri?> get uri async {
    try {
      return await uris.first;
    } on StateError {
      return null;
    }
  }

  Stream<Uri> get uris {
    final Stream<Uri> uriStream = _uriStreamController.stream
      .transform(_throttle<Uri>(
        waitDuration: throttleDuration,
      ));
    return uriStream.asyncMap<Uri>(_forwardPort);
  }

  Future<void> cancel() => _stopScrapingLogs();

  Future<void> _stopScrapingLogs() async {
    await _uriStreamController.close();
    await _deviceLogSubscription?.cancel();
    _deviceLogSubscription = null;
  }

  Match? _getPatternMatch(String line) {
    return globals.kVMServiceMessageRegExp.firstMatch(line);
  }

  Uri? _getVmServiceUri(String line) {
    final Match? match = _getPatternMatch(line);
    if (match != null) {
      return Uri.parse(match[1]!);
    }
    return null;
  }

  void _handleLine(String line) {
    Uri? uri;
    try {
      uri = _getVmServiceUri(line);
    } on FormatException catch (error, stackTrace) {
      _uriStreamController.addError(error, stackTrace);
    }
    if (uri == null || uri.host.isEmpty) {
      return;
    }
    if (devicePort != null && uri.port != devicePort) {
      _logger.printTrace('skipping potential VM Service $uri due to device port mismatch');
      return;
    }
    _uriStreamController.add(uri);
  }

  Future<Uri> _forwardPort(Uri deviceUri) async {
    _logger.printTrace('$serviceName URL on device: $deviceUri');
    Uri hostUri = deviceUri;

    final DevicePortForwarder? forwarder = portForwarder;
    if (forwarder != null) {
      final int actualDevicePort = deviceUri.port;
      final int actualHostPort = await forwarder.forward(actualDevicePort, hostPort: hostPort);
      _logger.printTrace('Forwarded host port $actualHostPort to device port $actualDevicePort for $serviceName');
      hostUri = deviceUri.replace(port: actualHostPort);
    }

    if (InternetAddress(hostUri.host).isLoopback && _ipv6) {
      hostUri = hostUri.replace(host: InternetAddress.loopbackIPv6.host);
    }
    return hostUri;
  }
}

class _BufferedStreamController<T> {
  _BufferedStreamController() : _events = <dynamic>[];

  Stream<T> get stream {
    return _streamController.stream;
  }

  late final StreamController<T> _streamController = () {
    final StreamController<T> streamControllerInstance = StreamController<T>.broadcast();
      streamControllerInstance.onListen = () {
      for (final dynamic event in _events) {
        if (event is T) {
          streamControllerInstance.add(event);
        } else {
          streamControllerInstance.addError(
            (event as Iterable<dynamic>).first as Object,
            event.last as StackTrace,
          );
        }
      }
      _events.clear();
    };
    return streamControllerInstance;
  }();

  final List<dynamic> _events;

  void add(T event) {
    if (_streamController.hasListener) {
      _streamController.add(event);
    } else {
      _events.add(event);
    }
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    if (_streamController.hasListener) {
      _streamController.addError(error, stackTrace);
    } else {
      _events.add(<dynamic>[error, stackTrace]);
    }
  }

  Future<void> close() {
    return _streamController.close();
  }
}

StreamTransformer<S, S> _throttle<S>({
  required Duration waitDuration,
}) {

  S latestLine;
  int? lastExecution;
  Future<void>? throttleFuture;
  bool done = false;

  return StreamTransformer<S, S>
    .fromHandlers(
      handleData: (S value, EventSink<S> sink) {
        latestLine = value;

        final bool isFirstMessage = lastExecution == null;
        final int currentTime = DateTime.now().millisecondsSinceEpoch;
        lastExecution ??= currentTime;
        final int remainingTime = currentTime - lastExecution!;

        // Always send the first event immediately.
        final int nextExecutionTime = isFirstMessage || remainingTime > waitDuration.inMilliseconds
          ? 0
          : waitDuration.inMilliseconds - remainingTime;
        throttleFuture ??= Future<void>
          .delayed(Duration(milliseconds: nextExecutionTime))
          .whenComplete(() {
            if (done) {
              return;
            }
            sink.add(latestLine);
            throttleFuture = null;
            lastExecution = DateTime.now().millisecondsSinceEpoch;
          });
      },
      handleDone: (EventSink<S> sink) {
        done = true;
        sink.close();
      }
    );
}