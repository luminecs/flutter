import 'dart:js_interop';

// This value is set by the engine. It is used to determine if the application is
// using canvaskit.
@JS('window.flutterCanvasKit')
external JSAny? get _windowFlutterCanvasKit;

bool get isCanvasKit => _windowFlutterCanvasKit != null;
