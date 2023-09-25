
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';


void main() {
  testWidgetsWithLeakTracking('DisposableBuildContext asserts on disposed state', (WidgetTester tester) async {
    final GlobalKey<TestWidgetState> key = GlobalKey<TestWidgetState>();
    await tester.pumpWidget(TestWidget(key));

    final TestWidgetState state = key.currentState!;
    expect(state.mounted, true);

    final DisposableBuildContext context = DisposableBuildContext(state);
    expect(context.context, state.context);

    await tester.pumpWidget(const TestWidget(null));

    expect(state.mounted, false);

    expect(() => context.context, throwsAssertionError);

    context.dispose();
    expect(context.context, null);
    expect(() => state.context, throwsFlutterError);

    expect(() => DisposableBuildContext(state), throwsAssertionError);
  });
}

class TestWidget extends StatefulWidget {
  const TestWidget(Key? key) : super(key: key);

  @override
  State<TestWidget> createState() => TestWidgetState();
}

class TestWidgetState extends State<TestWidget> {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 50);
}