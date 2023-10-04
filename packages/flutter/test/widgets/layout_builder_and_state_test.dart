import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import 'test_widgets.dart';

class StatefulWrapper extends StatefulWidget {
  const StatefulWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  StatefulWrapperState createState() => StatefulWrapperState();
}

class StatefulWrapperState extends State<StatefulWrapper> {
  void trigger() {
    setState(() {/* no-op setState */});
  }

  bool built = false;

  @override
  Widget build(BuildContext context) {
    built = true;
    return widget.child;
  }
}

class Wrapper extends StatelessWidget {
  const Wrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

void main() {
  testWidgetsWithLeakTracking(
      'Calling setState on a widget that moves into a LayoutBuilder in the same frame',
      (WidgetTester tester) async {
    StatefulWrapperState statefulWrapper;
    final Widget inner = Wrapper(
      child: StatefulWrapper(
        key: GlobalKey(),
        child: Container(),
      ),
    );
    await tester.pumpWidget(FlipWidget(
      left: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
        return inner;
      }),
      right: inner,
    ));
    statefulWrapper = tester.state(find.byType(StatefulWrapper));
    expect(statefulWrapper.built, true);
    statefulWrapper.built = false;

    statefulWrapper.trigger();
    flipStatefulWidget(tester);
    await tester.pump();
    expect(statefulWrapper.built, true);
    statefulWrapper.built = false;

    statefulWrapper.trigger();
    flipStatefulWidget(tester);
    await tester.pump();
    expect(statefulWrapper.built, true);
    statefulWrapper.built = false;

    statefulWrapper.trigger();
    flipStatefulWidget(tester);
    await tester.pump();
    expect(statefulWrapper.built, true);
    statefulWrapper.built = false;
  });
}
