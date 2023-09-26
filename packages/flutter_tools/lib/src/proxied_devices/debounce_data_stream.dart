import 'dart:async';
import 'dart:typed_data';

Stream<Uint8List> debounceDataStream(Stream<Uint8List> stream,
    [Duration duration = const Duration(milliseconds: 100)]) {
  final StreamController<Uint8List> controller = StreamController<Uint8List>();
  final BytesBuilder buffer = BytesBuilder(copy: false);

  bool isDone = false;
  Timer? timer;

  // Called when timer triggers, sends out the buffered messages.
  void onTimer() {
    if (buffer.isNotEmpty) {
      controller.add(buffer.toBytes());
      buffer.clear();
      if (isDone) {
        controller.close();
      } else {
        // Start another timer even if we have nothing to send right now, so
        // that outgoing messages are at least [duration] apart.
        timer = Timer(duration, onTimer);
      }
    } else {
      timer = null;
    }
  }

  controller.onListen = () {
    final StreamSubscription<Uint8List> subscription =
        stream.listen((Uint8List data) {
      if (timer == null) {
        controller.add(data);
        // Start the timer to make sure that the next message is at least [duration] apart.
        timer = Timer(duration, onTimer);
      } else {
        buffer.add(data);
      }
    }, onError: (Object error, StackTrace stackTrace) {
      // Forward the error.
      controller.addError(error, stackTrace);
    }, onDone: () {
      isDone = true;
      // Delay closing the channel if we still have buffered data.
      if (timer == null) {
        controller.close();
      }
    });

    controller.onCancel = () {
      subscription.cancel();
    };
  };

  return controller.stream;
}
