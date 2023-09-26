import 'package:flutter/material.dart';

Future<void> main() async {
  runApp(const Scaffold(
    body: Center(
      child: Column(
        children: <Widget>[
          Icon(Icons.ac_unit),
          Text('Hello, World', textDirection: TextDirection.ltr),
        ],
      ),
    ),
  ));
}
