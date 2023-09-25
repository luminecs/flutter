import 'package:flutter/material.dart';


void main() => runApp(const GlowingOverscrollIndicatorExampleApp());

class GlowingOverscrollIndicatorExampleApp extends StatelessWidget {
  const GlowingOverscrollIndicatorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('GlowingOverscrollIndicator Sample')),
        body: const GlowingOverscrollIndicatorExample(),
      ),
    );
  }
}

class GlowingOverscrollIndicatorExample extends StatelessWidget {
  const GlowingOverscrollIndicatorExample({super.key});

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return const <Widget>[
          SliverAppBar(title: Text('Custom NestedScrollViews')),
        ];
      },
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Container(
              color: Colors.amberAccent,
              height: 100,
              child: const Center(child: Text('Glow all day!')),
            ),
          ),
          const SliverFillRemaining(child: FlutterLogo()),
        ],
      ),
    );
  }
}