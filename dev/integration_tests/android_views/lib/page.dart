
import 'package:flutter/material.dart';

//
abstract class PageWidget extends StatelessWidget {
  const PageWidget(this.title, this.tileKey, {super.key});

  final String title;

  final ValueKey<String> tileKey;
}