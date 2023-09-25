import 'package:flutter/material.dart';


void main() {
  runApp(const TextFieldExamplesApp());
}

class TextFieldExamplesApp extends StatelessWidget {
  const TextFieldExamplesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(colorSchemeSeed: const Color(0xff6750a4), useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('TextField Examples')),
        body: const Column(
          children: <Widget>[
            Spacer(),
            FilledTextFieldExample(),
            OutlinedTextFieldExample(),
            Spacer(),
          ],
        ),
      ),
    );
  }
}

class FilledTextFieldExample extends StatelessWidget {
  const FilledTextFieldExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const TextField(
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search),
        suffixIcon: Icon(Icons.clear),
        labelText: 'Filled',
        hintText: 'hint text',
        helperText: 'supporting text',
        filled: true,
      ),
    );
  }
}

class OutlinedTextFieldExample extends StatelessWidget {
  const OutlinedTextFieldExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const TextField(
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search),
        suffixIcon: Icon(Icons.clear),
        labelText: 'Outlined',
        hintText: 'hint text',
        helperText: 'supporting text',
        border: OutlineInputBorder(),
      ),
    );
  }
}