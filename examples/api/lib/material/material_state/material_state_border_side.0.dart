
import 'package:flutter/material.dart';


void main() => runApp(const MaterialStateBorderSideExampleApp());

class MaterialStateBorderSideExampleApp extends StatelessWidget {
  const MaterialStateBorderSideExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('MaterialStateBorderSide Sample')),
        body: const Center(
          child: MaterialStateBorderSideExample(),
        ),
      ),
    );
  }
}

class MaterialStateBorderSideExample extends StatefulWidget {
  const MaterialStateBorderSideExample({super.key});

  @override
  State<MaterialStateBorderSideExample> createState() => _MaterialStateBorderSideExampleState();
}

class _MaterialStateBorderSideExampleState extends State<MaterialStateBorderSideExample> {
  bool isSelected = true;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: const Text('Select chip'),
      selected: isSelected,
      onSelected: (bool value) {
        setState(() {
          isSelected = value;
        });
      },
      side: MaterialStateBorderSide.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return const BorderSide(color: Colors.red);
        }
        return null; // Defer to default value on the theme or widget.
      }),
    );
  }
}