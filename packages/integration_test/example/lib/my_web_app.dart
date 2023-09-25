import 'dart:html' as html;
import 'package:flutter/material.dart';

// ignore_for_file: public_member_api_docs

void startApp() => runApp(const MyWebApp());

class MyWebApp extends StatefulWidget {
  const MyWebApp({super.key});

  @override
  State<MyWebApp> createState() => _MyWebAppState();
}

class _MyWebAppState extends State<MyWebApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          key: const Key('mainapp'),
          child: Text('Platform: ${html.window.navigator.platform}\n'),
        ),
      ),
    );
  }
}