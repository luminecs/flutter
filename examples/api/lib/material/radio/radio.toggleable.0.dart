import 'package:flutter/material.dart';

void main() => runApp(const ToggleableExampleApp());

class ToggleableExampleApp extends StatelessWidget {
  const ToggleableExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Radio Sample')),
        body: const ToggleableExample(),
      ),
    );
  }
}

class ToggleableExample extends StatefulWidget {
  const ToggleableExample({super.key});

  @override
  State<ToggleableExample> createState() => _ToggleableExampleState();
}

class _ToggleableExampleState extends State<ToggleableExample> {
  int? groupValue;
  static const List<String> selections = <String>[
    'Hercules Mulligan',
    'Eliza Hamilton',
    'Philip Schuyler',
    'Maria Reynolds',
    'Samuel Seabury',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemBuilder: (BuildContext context, int index) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Radio<int>(
                  value: index,
                  groupValue: groupValue,
                  // TRY THIS: Try setting the toggleable value to false and
                  // see how that changes the behavior of the widget.
                  toggleable: true,
                  onChanged: (int? value) {
                    setState(() {
                      groupValue = value;
                    });
                  }),
              Text(selections[index]),
            ],
          );
        },
        itemCount: selections.length,
      ),
    );
  }
}
