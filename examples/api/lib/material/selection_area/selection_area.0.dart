import 'package:flutter/material.dart';

void main() => runApp(const SelectionAreaExampleApp());

class SelectionAreaExampleApp extends StatelessWidget {
  const SelectionAreaExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SelectionArea(
        child: Scaffold(
          appBar: AppBar(title: const Text('SelectionArea Sample')),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('Row 1'),
                Text('Row 2'),
                Text('Row 3'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
