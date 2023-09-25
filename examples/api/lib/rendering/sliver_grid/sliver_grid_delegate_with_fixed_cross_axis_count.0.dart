import 'package:flutter/material.dart';


void main() => runApp(const SliverGridDelegateWithFixedCrossAxisCountExampleApp());

class SliverGridDelegateWithFixedCrossAxisCountExampleApp extends StatelessWidget {
  const SliverGridDelegateWithFixedCrossAxisCountExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SliverGridDelegateWithFixedCrossAxisCount Sample')),
        body: const SliverGridDelegateWithFixedCrossAxisCountExample(),
      ),
    );
  }
}

class SliverGridDelegateWithFixedCrossAxisCountExample extends StatelessWidget {
  const SliverGridDelegateWithFixedCrossAxisCountExample({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.5,
      ),
      children: List<Widget>.generate(20, (int i) {
        return Builder(builder: (BuildContext context) {
          return Text('$i');
        });
      }),
    );
  }
}