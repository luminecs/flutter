import 'package:flutter/material.dart';

void main() => runApp(const RawScrollbarExampleApp());

class RawScrollbarExampleApp extends StatelessWidget {
  const RawScrollbarExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('RawScrollbar Sample')),
        body: const RawScrollbarExample(),
      ),
    );
  }
}

class RawScrollbarExample extends StatelessWidget {
  const RawScrollbarExample({super.key});

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      child: GridView.builder(
        itemCount: 120,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
        itemBuilder: (BuildContext context, int index) {
          return Center(
            child: Text('item $index'),
          );
        },
      ),
    );
  }
}
