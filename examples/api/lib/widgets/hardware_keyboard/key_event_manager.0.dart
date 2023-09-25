
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: FallbackDemo(),
        ),
      ),
    ),
  );
}

class FallbackDemo extends StatefulWidget {
  const FallbackDemo({super.key});

  @override
  State<StatefulWidget> createState() => FallbackDemoState();
}

class FallbackDemoState extends State<FallbackDemo> {
  String? _capture;
  late final FallbackFocusNode _node = FallbackFocusNode(
    onKeyEvent: (KeyEvent event) {
      if (event is! KeyDownEvent) {
        return false;
      }
      setState(() {
        _capture = event.logicalKey.keyLabel;
      });
      // TRY THIS: Change the return value to true. You will no longer be able
      // to type text, because these key events will no longer be sent to the
      // text input system.
      return false;
    },
  );

  @override
  Widget build(BuildContext context) {
    return FallbackFocus(
      node: _node,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.red)),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
        child: Column(
          children: <Widget>[
            const Text('This area handles key presses that are unhandled by any shortcuts, by '
                'displaying them below. Try text shortcuts such as Ctrl-A!'),
            Text(_capture == null ? '' : '$_capture is not handled by shortcuts.'),
            const TextField(decoration: InputDecoration(label: Text('Text field 1'))),
            Shortcuts(
              shortcuts: <ShortcutActivator, Intent>{
                const SingleActivator(LogicalKeyboardKey.keyQ): VoidCallbackIntent(() {}),
              },
              child: const TextField(
                decoration: InputDecoration(
                  label: Text('This field also considers key Q as a shortcut (that does nothing).'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FallbackFocusNode {
  FallbackFocusNode({required this.onKeyEvent});

  final KeyEventCallback onKeyEvent;
}

class FallbackKeyEventRegistrar {
  FallbackKeyEventRegistrar._();
  static FallbackKeyEventRegistrar get instance {
    if (!_initialized) {
      // Get the global handler.
      final KeyMessageHandler? existing = ServicesBinding.instance.keyEventManager.keyMessageHandler;
      // The handler is guaranteed non-null since
      // `FallbackKeyEventRegistrar.instance` is only called during
      // `Focus.onFocusChange`, at which time `ServicesBinding.instance` must
      // have been called somewhere.
      assert(existing != null);
      // Assign the global handler with a patched handler.
      ServicesBinding.instance.keyEventManager.keyMessageHandler = _instance._buildHandler(existing!);
      _initialized = true;
    }
    return _instance;
  }

  static bool _initialized = false;
  static final FallbackKeyEventRegistrar _instance = FallbackKeyEventRegistrar._();

  final List<FallbackFocusNode> _fallbackNodes = <FallbackFocusNode>[];

  // Returns a handler that patches the existing `KeyEventManager.keyMessageHandler`.
  //
  // The existing `KeyEventManager.keyMessageHandler` is typically the one
  // assigned by the shortcut system, but it can be anything. The returned
  // handler calls that handler first, and if the event is not handled at all
  // by the framework, invokes the innermost `FallbackNode`'s handler.
  KeyMessageHandler _buildHandler(KeyMessageHandler existing) {
    return (KeyMessage message) {
      if (existing(message)) {
        return true;
      }
      if (_fallbackNodes.isNotEmpty) {
        for (final KeyEvent event in message.events) {
          if (_fallbackNodes.last.onKeyEvent(event)) {
            return true;
          }
        }
      }
      return false;
    };
  }
}

class FallbackFocus extends StatelessWidget {
  const FallbackFocus({
    super.key,
    required this.node,
    required this.child,
  });

  final Widget child;
  final FallbackFocusNode node;

  void _onFocusChange(bool focused) {
    if (focused) {
      FallbackKeyEventRegistrar.instance._fallbackNodes.add(node);
    } else {
      assert(FallbackKeyEventRegistrar.instance._fallbackNodes.last == node);
      FallbackKeyEventRegistrar.instance._fallbackNodes.removeLast();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _onFocusChange,
      child: child,
    );
  }
}