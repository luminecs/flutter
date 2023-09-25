import 'dart:math';

import 'package:flutter/material.dart';


void main() => runApp(const MatrixTransitionExampleApp());

class MatrixTransitionExampleApp extends StatelessWidget {
  const MatrixTransitionExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MatrixTransitionExample(),
    );
  }
}

class MatrixTransitionExample extends StatefulWidget {
  const MatrixTransitionExample({super.key});

  @override
  State<MatrixTransitionExample> createState() => _MatrixTransitionExampleState();
}

class _MatrixTransitionExampleState extends State<MatrixTransitionExample> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MatrixTransition(
          animation: _animation,
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: FlutterLogo(size: 150.0),
          ),
          onTransform: (double value) {
            return Matrix4.identity()
              ..setEntry(3, 2, 0.004)
              ..rotateY(pi * 2.0 * value);
          },
        ),
      ),
    );
  }
}