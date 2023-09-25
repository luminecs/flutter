
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String kMessage = 'ABC';
  @override
  Widget build(BuildContext context) {
    // cause cast error.
    print(kMessage as int);
    return const Text('Hello');
  }
}