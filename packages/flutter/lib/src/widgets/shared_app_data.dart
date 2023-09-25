

import 'framework.dart';
import 'inherited_model.dart';

typedef SharedAppDataInitCallback<T> = T Function();

class SharedAppData extends StatefulWidget {
  const SharedAppData({ super.key, required this.child });

  final Widget child;

  @override
  State<StatefulWidget> createState() => _SharedAppDataState();

  static V getValue<K extends Object, V>(BuildContext context, K key, SharedAppDataInitCallback<V> init) {
    final _SharedAppModel? model = InheritedModel.inheritFrom<_SharedAppModel>(context, aspect: key);
    assert(_debugHasSharedAppData(model, context, 'getValue'));
    return model!.sharedAppDataState.getValue<K, V>(key, init);
  }

  static void setValue<K extends Object, V>(BuildContext context, K key, V value) {
    final _SharedAppModel? model = context.getInheritedWidgetOfExactType<_SharedAppModel>();
    assert(_debugHasSharedAppData(model, context, 'setValue'));
    model!.sharedAppDataState.setValue<K, V>(key, value);
  }

  static bool _debugHasSharedAppData(_SharedAppModel? model, BuildContext context, String methodName) {
    assert(() {
      if (model == null) {
        throw FlutterError.fromParts(
          <DiagnosticsNode>[
            ErrorSummary('No SharedAppData widget found.'),
            ErrorDescription('SharedAppData.$methodName requires an SharedAppData widget ancestor.\n'),
            context.describeWidget('The specific widget that could not find an SharedAppData ancestor was'),
            context.describeOwnershipChain('The ownership chain for the affected widget is'),
            ErrorHint(
              'Typically, the SharedAppData widget is introduced by the MaterialApp '
              'or WidgetsApp widget at the top of your application widget tree. It '
              'provides a key/value map of data that is shared with the entire '
              'application.',
            ),
          ],
        );
      }
      return true;
    }());
    return true;
  }
}

class _SharedAppDataState extends State<SharedAppData> {
  late Map<Object, Object?> data = <Object, Object?>{};

  @override
  Widget build(BuildContext context) {
    return _SharedAppModel(sharedAppDataState: this, child: widget.child);
  }

  V getValue<K extends Object, V>(K key, SharedAppDataInitCallback<V> init) {
    data[key] ??= init();
    return data[key] as V;
  }

  void setValue<K extends Object, V>(K key, V value) {
    if (data[key] != value) {
      setState(() {
        data = Map<Object, Object?>.of(data);
        data[key] = value;
      });
    }
  }
}

class _SharedAppModel extends InheritedModel<Object> {
  _SharedAppModel({
    required this.sharedAppDataState,
    required super.child
  }) : data = sharedAppDataState.data;

  final _SharedAppDataState sharedAppDataState;
  final Map<Object, Object?> data;

  @override
  bool updateShouldNotify(_SharedAppModel old) {
    return data != old.data;
  }

  @override
  bool updateShouldNotifyDependent(_SharedAppModel old, Set<Object> keys) {
    for (final Object key in keys) {
      if (data[key] != old.data[key]) {
        return true;
      }
    }
    return false;
  }
}