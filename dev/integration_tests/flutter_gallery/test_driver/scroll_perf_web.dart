import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_gallery/gallery/app.dart' show GalleryApp;

void main() {
  enableFlutterDriverExtension();
  runApp(const GalleryApp(testMode: true));
}