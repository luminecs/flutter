import 'package:flutter/material.dart';

import 'calculator/home.dart';

class CalculatorDemo extends StatelessWidget {
  const CalculatorDemo({super.key});

  static const String routeName = '/calculator';

  @override
  Widget build(BuildContext context) => const Calculator();
}