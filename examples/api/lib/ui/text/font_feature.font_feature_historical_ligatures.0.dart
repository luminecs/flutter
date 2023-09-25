
import 'dart:ui';

import 'package:flutter/widgets.dart';


void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      builder: (BuildContext context, Widget? navigator) => const ExampleWidget(),
      color: const Color(0xffffffff),
    );
  }
}

class ExampleWidget extends StatelessWidget {
  const ExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // The Cardo font can be downloaded from Google Fonts
    // (https://www.google.com/fonts).
    return const Text(
      'VIBRANT fish assisted his business.',
      style: TextStyle(
        fontFamily: 'Sorts Mill Goudy',
        fontFeatures: <FontFeature>[
          FontFeature.historicalForms(), // Enables "hist".
          FontFeature.historicalLigatures(), // Enables "hlig".
        ],
      ),
    );
  }
}