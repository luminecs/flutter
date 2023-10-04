import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Image.frameBuilder Sample')),
        body: const Center(
          child: ImageClipExample(
            image: NetworkImage(
                'https://flutter.github.io/assets-for-api-docs/assets/widgets/puffin.jpg'),
          ),
        ),
      ),
    ),
  );
}

class ImageClipExample extends StatelessWidget {
  const ImageClipExample({super.key, required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: Ink.image(
        fit: BoxFit.fill,
        width: 300,
        height: 300,
        image: image,
        child: InkWell(
          onTap: () {/* ... */},
          child: const Align(
            child: Padding(
              padding: EdgeInsets.all(10.0),
              child: Text(
                'PUFFIN',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
