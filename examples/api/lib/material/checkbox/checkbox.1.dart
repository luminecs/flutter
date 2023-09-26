import 'package:flutter/material.dart';

void main() => runApp(const CheckboxExampleApp());

class CheckboxExampleApp extends StatelessWidget {
  const CheckboxExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          useMaterial3: true, colorSchemeSeed: const Color(0xff6750a4)),
      title: 'Checkbox Sample',
      home: Scaffold(
        appBar: AppBar(title: const Text('Checkbox Sample')),
        body: const Center(
          child: CheckboxExample(),
        ),
      ),
    );
  }
}

class CheckboxExample extends StatefulWidget {
  const CheckboxExample({super.key});

  @override
  State<CheckboxExample> createState() => _CheckboxExampleState();
}

class _CheckboxExampleState extends State<CheckboxExample> {
  bool? isChecked = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Checkbox(
          tristate: true,
          value: isChecked,
          onChanged: (bool? value) {
            setState(() {
              isChecked = value;
            });
          },
        ),
        Checkbox(
          isError: true,
          tristate: true,
          value: isChecked,
          onChanged: (bool? value) {
            setState(() {
              isChecked = value;
            });
          },
        ),
        Checkbox(
          isError: true,
          tristate: true,
          value: isChecked,
          onChanged: null,
        ),
      ],
    );
  }
}
