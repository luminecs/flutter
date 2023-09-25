
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  testWidgetsWithLeakTracking('StatefulWidget BuildContext.mounted', (WidgetTester tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(TestStatefulWidget(
        onBuild: (BuildContext context) {
          capturedContext = context;
        }
    ));
    expect(capturedContext.mounted, isTrue);
    await tester.pumpWidget(Container());
    expect(capturedContext.mounted, isFalse);
  });

  testWidgetsWithLeakTracking('StatelessWidget BuildContext.mounted', (WidgetTester tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(TestStatelessWidget(
      onBuild: (BuildContext context) {
        capturedContext = context;
      }
    ));
    expect(capturedContext.mounted, isTrue);
    await tester.pumpWidget(Container());
    expect(capturedContext.mounted, isFalse);
  });
}

typedef BuildCallback = void Function(BuildContext);

class TestStatelessWidget extends StatelessWidget {
  const TestStatelessWidget({super.key, required this.onBuild});

  final BuildCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(context);
    return Container();
  }
}

class TestStatefulWidget extends StatefulWidget {
  const TestStatefulWidget({super.key, required this.onBuild});

  final BuildCallback onBuild;

  @override
  State<TestStatefulWidget> createState() => _TestStatefulWidgetState();
}

class _TestStatefulWidgetState extends State<TestStatefulWidget> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild(context);
    return Container();
  }
}