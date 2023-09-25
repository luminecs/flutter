
import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'base/common.dart';
import 'base/io.dart';
import 'base/logger.dart';
import 'base/utils.dart';
import 'convert.dart';

class DaemonMessage {
  DaemonMessage(this.data, [this.binary]);

  final Map<String, Object?> data;

  final Stream<List<int>>? binary;
}

class DaemonEventData {
  DaemonEventData(this.eventName, this.data, [this.binary]);

  final String eventName;

  final Object? data;

  final Stream<List<int>>? binary;
}

const String _binaryLengthKey = '_binaryLength';

enum _InputStreamParseState {
  json,
  binary,
}

@visibleForTesting
class DaemonInputStreamConverter {
  DaemonInputStreamConverter(this.inputStream) {
    // Lazily listen to the input stream.
    _controller.onListen = () {
      final StreamSubscription<List<int>> subscription = inputStream.listen((List<int> chunk) {
        _processChunk(chunk);
      }, onError: (Object error, StackTrace stackTrace) {
        _controller.addError(error, stackTrace);
      }, onDone: () {
        unawaited(_controller.close());
      });

      _controller.onCancel = subscription.cancel;
      // We should not handle onPause or onResume. When the stream is paused, we
      // still need to read from the input stream.
    };
  }

  final Stream<List<int>> inputStream;

  final StreamController<DaemonMessage> _controller = StreamController<DaemonMessage>();
  Stream<DaemonMessage> get convertedStream => _controller.stream;

  // Internal states
  _InputStreamParseState state = _InputStreamParseState.json;

  late StreamController<List<int>> currentBinaryStream;

  int remainingBinaryLength = 0;

  final BytesBuilder bytesBuilder = BytesBuilder(copy: false);

  // Processes a single chunk received in the input stream.
  void _processChunk(List<int> chunk) {

    int start = 0;
    while (start < chunk.length) {
      if (state == _InputStreamParseState.json) {
        start += _processChunkInJsonMode(chunk, start);
      } else if (state == _InputStreamParseState.binary) {
        final int bytesSent = _addBinaryChunk(chunk, start, remainingBinaryLength);
        start += bytesSent;
        remainingBinaryLength -= bytesSent;

        if (remainingBinaryLength <= 0) {
          assert(remainingBinaryLength == 0);

          unawaited(currentBinaryStream.close());
          state = _InputStreamParseState.json;
        }
      }
    }
  }

  int _processChunkInJsonMode(List<int> chunk, int start) {
    const int LF = 10; // The '\n' character

    // Search for newline character.
    final int indexOfNewLine = chunk.indexOf(LF, start);
    if (indexOfNewLine < 0) {
      bytesBuilder.add(chunk.sublist(start));
      return chunk.length - start;
    }

    bytesBuilder.add(chunk.sublist(start, indexOfNewLine + 1));

    // Process chunk here
    final Uint8List combinedChunk = bytesBuilder.takeBytes();
    String jsonString = utf8.decode(combinedChunk).trim();
    if (jsonString.startsWith('[{') && jsonString.endsWith('}]')) {
      jsonString = jsonString.substring(1, jsonString.length - 1);
      final Map<String, Object?>? value = castStringKeyedMap(json.decode(jsonString));
      if (value != null) {
        // Check if we need to consume another binary blob.
        if (value[_binaryLengthKey] != null) {
          remainingBinaryLength = value[_binaryLengthKey]! as int;
          currentBinaryStream = StreamController<List<int>>();
          state = _InputStreamParseState.binary;
          _controller.add(DaemonMessage(value, currentBinaryStream.stream));
        } else {
          _controller.add(DaemonMessage(value));
        }
      }
    }

    return indexOfNewLine + 1 - start;
  }

  int _addBinaryChunk(List<int> chunk, int start, int maximumSizeToRead) {
    if (start == 0 && chunk.length <= remainingBinaryLength) {
      currentBinaryStream.add(chunk);
      return chunk.length;
    } else {
      final int chunkRemainingLength = chunk.length - start;
      final int sizeToRead = chunkRemainingLength < remainingBinaryLength ? chunkRemainingLength : remainingBinaryLength;
      currentBinaryStream.add(chunk.sublist(start, start + sizeToRead));
      return sizeToRead;
    }
  }
}

class DaemonStreams {
  DaemonStreams(
    Stream<List<int>> rawInputStream,
    StreamSink<List<int>> outputSink, {
    required Logger logger,
  }) :
    _outputSink = outputSink,
    inputStream = DaemonInputStreamConverter(rawInputStream).convertedStream,
    _logger = logger;

  DaemonStreams.fromStdio(Stdio stdio, { required Logger logger })
    : this(stdio.stdin, stdio.stdout, logger: logger);

  DaemonStreams.fromSocket(Socket socket, { required Logger logger })
    : this(socket, socket, logger: logger);

  factory DaemonStreams.connect(String host, int port, { required Logger logger }) {
    final Future<Socket> socketFuture = Socket.connect(host, port);
    final StreamController<List<int>> inputStreamController = StreamController<List<int>>();
    final StreamController<List<int>> outputStreamController = StreamController<List<int>>();
    socketFuture.then((Socket socket) {
      inputStreamController.addStream(socket);
      socket.addStream(outputStreamController.stream);
    }).onError((Object error, StackTrace stackTrace) {
      logger.printError('Socket error: $error');
      logger.printTrace('$stackTrace');
      // Propagate the error to the streams.
      inputStreamController.addError(error, stackTrace);
      unawaited(outputStreamController.close());
    });
    return DaemonStreams(inputStreamController.stream, outputStreamController.sink, logger: logger);
  }

  final StreamSink<List<int>> _outputSink;
  final Logger _logger;

  final Stream<DaemonMessage> inputStream;

  void send(Map<String, Object?> message, [ List<int>? binary ]) {
    try {
      if (binary != null) {
        message[_binaryLengthKey] = binary.length;
      }
      _outputSink.add(utf8.encode('[${json.encode(message)}]\n'));
      if (binary != null) {
        _outputSink.add(binary);
      }
    } on StateError catch (error) {
      _logger.printError('Failed to write daemon command response: $error');
      // Failed to send, close the connection
      _outputSink.close();
    } on IOException catch (error) {
      _logger.printError('Failed to write daemon command response: $error');
      // Failed to send, close the connection
      _outputSink.close();
    }
  }

  Future<void> dispose() async {
    unawaited(_outputSink.close());
  }
}

class DaemonConnection {
  DaemonConnection({
    required DaemonStreams daemonStreams,
    required Logger logger,
  }): _logger = logger,
      _daemonStreams = daemonStreams {
    _commandSubscription = daemonStreams.inputStream.listen(
      _handleMessage,
      onError: (Object error, StackTrace stackTrace) {
        // We have to listen for on error otherwise the error on the socket
        // will end up in the Zone error handler.
        // Do nothing here and let the stream close handlers handle shutting
        // down the daemon.
      }
    );
  }

  final DaemonStreams _daemonStreams;

  final Logger _logger;

  late final StreamSubscription<DaemonMessage> _commandSubscription;

  int _outgoingRequestId = 0;
  final Map<String, Completer<Object?>> _outgoingRequestCompleters = <String, Completer<Object?>>{};

  final StreamController<DaemonEventData> _events = StreamController<DaemonEventData>.broadcast();
  final StreamController<DaemonMessage> _incomingCommands = StreamController<DaemonMessage>();

  Stream<DaemonMessage> get incomingCommands => _incomingCommands.stream;

  Stream<DaemonEventData> listenToEvent(String eventToListen) {
    return _events.stream
      .where((DaemonEventData event) => event.eventName == eventToListen);
  }

  Future<Object?> sendRequest(String method, [Object? params, List<int>? binary]) async {
    final String id = '${++_outgoingRequestId}';
    final Completer<Object?> completer = Completer<Object?>();
    _outgoingRequestCompleters[id] = completer;
    final Map<String, Object?> data = <String, Object?>{
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };
    _logger.printTrace('-> Sending to daemon, id = $id, method = $method');
    _daemonStreams.send(data, binary);
    return completer.future;
  }

  void sendResponse(Object id, [Object? result]) {
    _daemonStreams.send(<String, Object?>{
      'id': id,
      if (result != null) 'result': result,
    });
  }

  void sendErrorResponse(Object id, Object? error, StackTrace trace) {
    _daemonStreams.send(<String, Object?>{
      'id': id,
      'error': error,
      'trace': '$trace',
    });
  }

  void sendEvent(String name, [ Object? params, List<int>? binary ]) {
    _daemonStreams.send(<String, Object?>{
      'event': name,
      if (params != null) 'params': params,
    }, binary);
  }

  void _handleMessage(DaemonMessage message) {
    final Map<String, Object?> data = message.data;
    if (data['id'] != null) {
      if (data['method'] == null) {
        // This is a response to previously sent request.
        final String id = data['id']! as String;
        if (data['error'] != null) {
          // This is an error response.
          _logger.printTrace('<- Error response received from daemon, id = $id');
          final Object error = data['error']!;
          final String stackTrace = data['stackTrace'] as String? ?? '';
          _outgoingRequestCompleters.remove(id)?.completeError(error, StackTrace.fromString(stackTrace));
        } else {
          _logger.printTrace('<- Response received from daemon, id = $id');
          final Object? result = data['result'];
          _outgoingRequestCompleters.remove(id)?.complete(result);
        }
      } else {
        _incomingCommands.add(message);
      }
    } else if (data['event'] != null) {
      // This is an event
      _logger.printTrace('<- Event received: ${data['event']}');
      final Object? eventName = data['event'];
      if (eventName is String) {
        _events.add(DaemonEventData(
          eventName,
          data['params'],
          message.binary,
        ));
      } else {
        throwToolExit('event name received is not string!');
      }
    } else {
      _logger.printError('Unknown data received from daemon');
    }
  }

  Future<void> dispose() async {
    await _commandSubscription.cancel();
    await _daemonStreams.dispose();
    unawaited(_events.close());
    unawaited(_incomingCommands.close());
  }
}