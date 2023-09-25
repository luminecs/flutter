import 'package:flutter/foundation.dart';

import 'framework.dart';
import 'navigator.dart';
import 'routes.dart';

class PopScope extends StatefulWidget {
  const PopScope({
    super.key,
    required this.child,
    this.canPop = true,
    this.onPopInvoked,
  });

  final Widget child;

  final PopInvokedCallback? onPopInvoked;

  final bool canPop;

  @override
  State<PopScope> createState() => _PopScopeState();
}

class _PopScopeState extends State<PopScope> implements PopEntry {
  ModalRoute<dynamic>? _route;

  @override
  PopInvokedCallback? get onPopInvoked => widget.onPopInvoked;

  @override
  late final ValueNotifier<bool> canPopNotifier;

  @override
  void initState() {
    super.initState();
    canPopNotifier = ValueNotifier<bool>(widget.canPop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? nextRoute = ModalRoute.of(context);
    if (nextRoute != _route) {
      _route?.unregisterPopEntry(this);
      _route = nextRoute;
      _route?.registerPopEntry(this);
    }
  }

  @override
  void didUpdateWidget(PopScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    canPopNotifier.value = widget.canPop;
  }

  @override
  void dispose() {
    _route?.unregisterPopEntry(this);
    canPopNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}