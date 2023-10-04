import 'package:flutter/material.dart';

void main() => runApp(const LabelExampleApp());

class LabelExampleApp extends StatelessWidget {
  const LabelExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('InputDecoration.label Sample')),
        body: const LabelExample(),
      ),
    );
  }
}

class LabelExample extends StatelessWidget {
  const LabelExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: TextField(
        decoration: InputDecoration(
          label: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                WidgetSpan(
                  child: Text(
                    'Username',
                  ),
                ),
                WidgetSpan(
                  child: Text(
                    '*',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
