import 'package:flutter/material.dart';


void main() => runApp(const OfExampleApp());

class OfExampleApp extends StatelessWidget {
  const OfExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('ScaffoldMessenger.of Sample')),
        body: const Center(
          child: OfExample(),
        ),
      ),
    );
  }
}

class OfExample extends StatelessWidget {
  const OfExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      child: const Text('SHOW A SNACKBAR'),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Have a snack!'),
          ),
        );
      },
    );
  }
}