import 'package:flutter/material.dart';


void main() => runApp(const NestedScrollViewStateExampleApp());

class NestedScrollViewStateExampleApp extends StatelessWidget {
  const NestedScrollViewStateExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: NestedScrollViewStateExample(),
    );
  }
}

final GlobalKey<NestedScrollViewState> globalKey = GlobalKey();

class NestedScrollViewStateExample extends StatelessWidget {
  const NestedScrollViewStateExample({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      key: globalKey,
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return const <Widget>[
          SliverAppBar(
            title: Text('NestedScrollViewState Demo!'),
          ),
        ];
      },
      body: const CustomScrollView(
          // Body slivers go here!
          ),
    );
  }

  ScrollController get innerController {
    return globalKey.currentState!.innerController;
  }
}