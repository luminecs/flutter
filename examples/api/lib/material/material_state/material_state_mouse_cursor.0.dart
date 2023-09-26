import 'package:flutter/material.dart';

void main() => runApp(const MaterialStateMouseCursorExampleApp());

class MaterialStateMouseCursorExampleApp extends StatelessWidget {
  const MaterialStateMouseCursorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('MaterialStateMouseCursor Sample')),
        body: const Center(
          child: MaterialStateMouseCursorExample(),
        ),
      ),
    );
  }
}

class ListTileCursor extends MaterialStateMouseCursor {
  const ListTileCursor();

  @override
  MouseCursor resolve(Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled)) {
      return SystemMouseCursors.forbidden;
    }
    return SystemMouseCursors.click;
  }

  @override
  String get debugDescription => 'ListTileCursor()';
}

class MaterialStateMouseCursorExample extends StatelessWidget {
  const MaterialStateMouseCursorExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      title: Text('Disabled ListTile'),
      enabled: false,
      mouseCursor: ListTileCursor(),
    );
  }
}
