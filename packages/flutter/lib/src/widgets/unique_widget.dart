import 'framework.dart';

abstract class UniqueWidget<T extends State<StatefulWidget>>
    extends StatefulWidget {
  const UniqueWidget({
    required GlobalKey<T> key,
  }) : super(key: key);

  @override
  T createState();

  T? get currentState {
    final GlobalKey<T> globalKey = key! as GlobalKey<T>;
    return globalKey.currentState;
  }
}
