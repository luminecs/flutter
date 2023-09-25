import 'package:async/async.dart';

import '../base/io.dart';
import '../convert.dart';

Future<Socket> kAndroidConsoleSocketFactory(String host, int port) => Socket.connect(host, port);

typedef AndroidConsoleSocketFactory = Future<Socket> Function(String host, int port);

class AndroidConsole {
  AndroidConsole(this._socket);

  Socket? _socket;
  StreamQueue<String>? _queue;

  Future<void> connect() async {
    assert(_socket != null);
    assert(_queue == null);

    _queue = StreamQueue<String>(_socket!.asyncMap(ascii.decode));

    // Discard any initial connection text.
    await _readResponse();
  }

  Future<String?> getAvdName() async {
    if (_queue == null) {
      return null;
    }
    _write('avd name\n');
    return _readResponse();
  }

  void destroy() {
    _socket?.destroy();
    _socket = null;
    _queue = null;
  }

  Future<String?> _readResponse() async {
    if (_queue == null) {
      return null;
    }
    final StringBuffer output = StringBuffer();
    while (true) {
      if (!await _queue!.hasNext) {
        destroy();
        return null;
      }
      final String text = await _queue!.next;
      final String trimmedText = text.trim();
      if (trimmedText == 'OK') {
        break;
      }
      if (trimmedText.endsWith('\nOK')) {
        output.write(trimmedText.substring(0, trimmedText.length - 3));
        break;
      }
      output.write(text);
    }
    return output.toString().trim();
  }

  void _write(String text) {
    _socket?.add(ascii.encode(text));
  }
}