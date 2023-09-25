// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer' show Flow, Timeline;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' hide Flow;

import 'app_bar.dart';
import 'back_button.dart';
import 'card.dart';
import 'constants.dart';
import 'debug.dart';
import 'dialog.dart';
import 'divider.dart';
import 'floating_action_button_location.dart';
import 'ink_decoration.dart';
import 'list_tile.dart';
import 'material.dart';
import 'material_localizations.dart';
import 'page.dart';
import 'page_transitions_theme.dart';
import 'progress_indicator.dart';
import 'scaffold.dart';
import 'scrollbar.dart';
import 'text_button.dart';
import 'text_theme.dart';
import 'theme.dart';

// Examples can assume:
// BuildContext context;

class AboutListTile extends StatelessWidget {
  const AboutListTile({
    super.key,
    this.icon,
    this.child,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
    this.aboutBoxChildren,
    this.dense,
  });

  final Widget? icon;

  final Widget? child;

  final String? applicationName;

  final String? applicationVersion;

  final Widget? applicationIcon;

  final String? applicationLegalese;

  final List<Widget>? aboutBoxChildren;

  final bool? dense;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    return ListTile(
      leading: icon,
      title: child ?? Text(MaterialLocalizations.of(context).aboutListTileTitle(
        applicationName ?? _defaultApplicationName(context),
      )),
      dense: dense,
      onTap: () {
        showAboutDialog(
          context: context,
          applicationName: applicationName,
          applicationVersion: applicationVersion,
          applicationIcon: applicationIcon,
          applicationLegalese: applicationLegalese,
          children: aboutBoxChildren,
        );
      },
    );
  }
}

void showAboutDialog({
  required BuildContext context,
  String? applicationName,
  String? applicationVersion,
  Widget? applicationIcon,
  String? applicationLegalese,
  List<Widget>? children,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    builder: (BuildContext context) {
      return AboutDialog(
        applicationName: applicationName,
        applicationVersion: applicationVersion,
        applicationIcon: applicationIcon,
        applicationLegalese: applicationLegalese,
        children: children,
      );
    },
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
  );
}

void showLicensePage({
  required BuildContext context,
  String? applicationName,
  String? applicationVersion,
  Widget? applicationIcon,
  String? applicationLegalese,
  bool useRootNavigator = false,
}) {
  Navigator.of(context, rootNavigator: useRootNavigator).push(MaterialPageRoute<void>(
    builder: (BuildContext context) => LicensePage(
      applicationName: applicationName,
      applicationVersion: applicationVersion,
      applicationIcon: applicationIcon,
      applicationLegalese: applicationLegalese,
    ),
  ));
}

const double _textVerticalSeparation = 18.0;

class AboutDialog extends StatelessWidget {
  const AboutDialog({
    super.key,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
    this.children,
  });

  final String? applicationName;

  final String? applicationVersion;

  final Widget? applicationIcon;

  final String? applicationLegalese;

  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    final String name = applicationName ?? _defaultApplicationName(context);
    final String version = applicationVersion ?? _defaultApplicationVersion(context);
    final Widget? icon = applicationIcon ?? _defaultApplicationIcon(context);
    final ThemeData themeData = Theme.of(context);
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    return AlertDialog(
      content: ListBody(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (icon != null) IconTheme(data: themeData.iconTheme, child: icon),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ListBody(
                    children: <Widget>[
                      Text(name, style: themeData.textTheme.headlineSmall),
                      Text(version, style: themeData.textTheme.bodyMedium),
                      const SizedBox(height: _textVerticalSeparation),
                      Text(applicationLegalese ?? '', style: themeData.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ...?children,
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            themeData.useMaterial3
              ? localizations.viewLicensesButtonLabel
              : localizations.viewLicensesButtonLabel.toUpperCase()
          ),
          onPressed: () {
            showLicensePage(
              context: context,
              applicationName: applicationName,
              applicationVersion: applicationVersion,
              applicationIcon: applicationIcon,
              applicationLegalese: applicationLegalese,
            );
          },
        ),
        TextButton(
          child: Text(
            themeData.useMaterial3
              ? localizations.closeButtonLabel
              : localizations.closeButtonLabel.toUpperCase()
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
      scrollable: true,
    );
  }
}

class LicensePage extends StatefulWidget {
  const LicensePage({
    super.key,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
  });

  final String? applicationName;

  final String? applicationVersion;

  final Widget? applicationIcon;

  final String? applicationLegalese;

  @override
  State<LicensePage> createState() => _LicensePageState();
}

class _LicensePageState extends State<LicensePage> {
  final ValueNotifier<int?> selectedId = ValueNotifier<int?>(null);

  @override
  void dispose() {
    selectedId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MasterDetailFlow(
      detailPageFABlessGutterWidth: _getGutterSize(context),
      title: Text(MaterialLocalizations.of(context).licensesPageTitle),
      detailPageBuilder: _packageLicensePage,
      masterViewBuilder: _packagesView,
    );
  }

  Widget _packageLicensePage(BuildContext _, Object? args, ScrollController? scrollController) {
    assert(args is _DetailArguments);
    final _DetailArguments detailArguments = args! as _DetailArguments;
    return _PackageLicensePage(
      packageName: detailArguments.packageName,
      licenseEntries: detailArguments.licenseEntries,
      scrollController: scrollController,
    );
  }

  Widget _packagesView(final BuildContext _, final bool isLateral) {
    final Widget about = _AboutProgram(
      name: widget.applicationName ?? _defaultApplicationName(context),
      icon: widget.applicationIcon ?? _defaultApplicationIcon(context),
      version: widget.applicationVersion ?? _defaultApplicationVersion(context),
      legalese: widget.applicationLegalese,
    );
    return _PackagesView(
      about: about,
      isLateral: isLateral,
      selectedId: selectedId,
    );
  }
}

class _AboutProgram extends StatelessWidget {
  const _AboutProgram({
    required this.name,
    required this.version,
    this.icon,
    this.legalese,
  });

  final String name;
  final String version;
  final Widget? icon;
  final String? legalese;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _getGutterSize(context),
        vertical: 24.0,
      ),
      child: Column(
        children: <Widget>[
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (icon != null)
            IconTheme(data: Theme.of(context).iconTheme, child: icon!),
          if (version != '')
            Padding(
              padding: const EdgeInsets.only(bottom: _textVerticalSeparation),
              child: Text(
                version,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          if (legalese != null && legalese != '')
            Text(
              legalese!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: _textVerticalSeparation),
          Text(
            'Powered by Flutter',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PackagesView extends StatefulWidget {
  const _PackagesView({
    required this.about,
    required this.isLateral,
    required this.selectedId,
  });

  final Widget about;
  final bool isLateral;
  final ValueNotifier<int?> selectedId;

  @override
  _PackagesViewState createState() => _PackagesViewState();
}

class _PackagesViewState extends State<_PackagesView> {
  final Future<_LicenseData> licenses = LicenseRegistry.licenses
      .fold<_LicenseData>(
        _LicenseData(),
        (_LicenseData prev, LicenseEntry license) => prev..addLicense(license),
      )
      .then((_LicenseData licenseData) => licenseData..sortPackages());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LicenseData>(
      future: licenses,
      builder: (BuildContext context, AsyncSnapshot<_LicenseData> snapshot) {
        return LayoutBuilder(
          key: ValueKey<ConnectionState>(snapshot.connectionState),
          builder: (BuildContext context, BoxConstraints constraints) {
            switch (snapshot.connectionState) {
              case ConnectionState.done:
                if (snapshot.hasError) {
                  assert(() {
                    FlutterError.reportError(FlutterErrorDetails(
                      exception: snapshot.error!,
                      stack: snapshot.stackTrace,
                      context: ErrorDescription('while decoding the license file'),
                    ));
                    return true;
                  }());
                  return Center(child: Text(snapshot.error.toString()));
                }
                _initDefaultDetailPage(snapshot.data!, context);
                return ValueListenableBuilder<int?>(
                  valueListenable: widget.selectedId,
                  builder: (BuildContext context, int? selectedId, Widget? _) {
                    return Center(
                      child: Material(
                        color: Theme.of(context).cardColor,
                        elevation: 4.0,
                        child: Container(
                          constraints: BoxConstraints.loose(const Size.fromWidth(600.0)),
                          child: _packagesList(context, selectedId, snapshot.data!, widget.isLateral),
                        ),
                      ),
                    );
                  },
                );
              case ConnectionState.none:
              case ConnectionState.active:
              case ConnectionState.waiting:
                return Material(
                    color: Theme.of(context).cardColor,
                    child: Column(
                    children: <Widget>[
                      widget.about,
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                );
            }
          },
        );
      },
    );
  }

  void _initDefaultDetailPage(_LicenseData data, BuildContext context) {
    if (data.packages.isEmpty) {
      return;
    }
    final String packageName = data.packages[widget.selectedId.value ?? 0];
    final List<int> bindings = data.packageLicenseBindings[packageName]!;
    _MasterDetailFlow.of(context).setInitialDetailPage(
      _DetailArguments(
        packageName,
        bindings.map((int i) => data.licenses[i]).toList(growable: false),
      ),
    );
  }

  Widget _packagesList(
    final BuildContext context,
    final int? selectedId,
    final _LicenseData data,
    final bool drawSelection,
  ) {
    return ListView.builder(
      itemCount: data.packages.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return widget.about;
        }
        final int packageIndex = index - 1;
        final String packageName = data.packages[packageIndex];
        final List<int> bindings = data.packageLicenseBindings[packageName]!;
        return _PackageListTile(
          packageName: packageName,
          index: packageIndex,
          isSelected: drawSelection && packageIndex == (selectedId ?? 0),
          numberLicenses: bindings.length,
          onTap: () {
            widget.selectedId.value = packageIndex;
            _MasterDetailFlow.of(context).openDetailPage(_DetailArguments(
              packageName,
              bindings.map((int i) => data.licenses[i]).toList(growable: false),
            ));
          },
        );
      },
    );
  }
}

class _PackageListTile extends StatelessWidget {
  const _PackageListTile({
    required this.packageName,
    this.index,
    required this.isSelected,
    required this.numberLicenses,
    this.onTap,
});

  final String packageName;
  final int? index;
  final bool isSelected;
  final int numberLicenses;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Ink(
      color: isSelected ? Theme.of(context).highlightColor : Theme.of(context).cardColor,
      child: ListTile(
        title: Text(packageName),
        subtitle: Text(MaterialLocalizations.of(context).licensesPackageDetailText(numberLicenses)),
        selected: isSelected,
        onTap: onTap,
      ),
    );
  }
}

class _LicenseData {
  final List<LicenseEntry> licenses = <LicenseEntry>[];
  final Map<String, List<int>> packageLicenseBindings = <String, List<int>>{};
  final List<String> packages = <String>[];

  // Special treatment for the first package since it should be the package
  // for delivered application.
  String? firstPackage;

  void addLicense(LicenseEntry entry) {
    // Before the license can be added, we must first record the packages to
    // which it belongs.
    for (final String package in entry.packages) {
      _addPackage(package);
      // Bind this license to the package using the next index value. This
      // creates a contract that this license must be inserted at this same
      // index value.
      packageLicenseBindings[package]!.add(licenses.length);
    }
    licenses.add(entry); // Completion of the contract above.
  }

  void _addPackage(String package) {
    if (!packageLicenseBindings.containsKey(package)) {
      packageLicenseBindings[package] = <int>[];
      firstPackage ??= package;
      packages.add(package);
    }
  }

  void sortPackages([int Function(String a, String b)? compare]) {
    packages.sort(compare ?? (String a, String b) {
      // Based on how LicenseRegistry currently behaves, the first package
      // returned is the end user application license. This should be
      // presented first in the list. So here we make sure that first package
      // remains at the front regardless of alphabetical sorting.
      if (a == firstPackage) {
        return -1;
      }
      if (b == firstPackage) {
        return 1;
      }
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  }
}

@immutable
class _DetailArguments {
  const _DetailArguments(this.packageName, this.licenseEntries);

  final String packageName;
  final List<LicenseEntry> licenseEntries;

  @override
  bool operator ==(final Object other) {
    if (other is _DetailArguments) {
      return other.packageName == packageName;
    }
    return other == this;
  }

  @override
  int get hashCode => Object.hash(packageName, Object.hashAll(licenseEntries));
}

class _PackageLicensePage extends StatefulWidget {
  const _PackageLicensePage({
    required this.packageName,
    required this.licenseEntries,
    required this.scrollController,
  });

  final String packageName;
  final List<LicenseEntry> licenseEntries;
  final ScrollController? scrollController;

  @override
  _PackageLicensePageState createState() => _PackageLicensePageState();
}

class _PackageLicensePageState extends State<_PackageLicensePage> {
  @override
  void initState() {
    super.initState();
    _initLicenses();
  }

  final List<Widget> _licenses = <Widget>[];
  bool _loaded = false;

  Future<void> _initLicenses() async {
    int debugFlowId = -1;
    assert(() {
      final Flow flow = Flow.begin();
      Timeline.timeSync('_initLicenses()', () { }, flow: flow);
      debugFlowId = flow.id;
      return true;
    }());
    for (final LicenseEntry license in widget.licenseEntries) {
      if (!mounted) {
        return;
      }
      assert(() {
        Timeline.timeSync('_initLicenses()', () { }, flow: Flow.step(debugFlowId));
        return true;
      }());
      final List<LicenseParagraph> paragraphs =
        await SchedulerBinding.instance.scheduleTask<List<LicenseParagraph>>(
          license.paragraphs.toList,
          Priority.animation,
          debugLabel: 'License',
        );
      if (!mounted) {
        return;
      }
      setState(() {
        _licenses.add(const Padding(
          padding: EdgeInsets.all(18.0),
          child: Divider(),
        ));
        for (final LicenseParagraph paragraph in paragraphs) {
          if (paragraph.indent == LicenseParagraph.centeredIndent) {
            _licenses.add(Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                paragraph.text,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ));
          } else {
            assert(paragraph.indent >= 0);
            _licenses.add(Padding(
              padding: EdgeInsetsDirectional.only(top: 8.0, start: 16.0 * paragraph.indent),
              child: Text(paragraph.text),
            ));
          }
        }
      });
    }
    setState(() {
      _loaded = true;
    });
    assert(() {
      Timeline.timeSync('Build scheduled', () { }, flow: Flow.end(debugFlowId));
      return true;
    }());
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String title = widget.packageName;
    final String subtitle = localizations.licensesPackageDetailText(widget.licenseEntries.length);
    final double pad = _getGutterSize(context);
    final EdgeInsets padding = EdgeInsets.only(left: pad, right: pad, bottom: pad);
    final List<Widget> listWidgets = <Widget>[
      ..._licenses,
      if (!_loaded)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
    ];

    final Widget page;
    if (widget.scrollController == null) {
      page = Scaffold(
        appBar: AppBar(
          title: _PackageLicensePageTitle(
            title: title,
            subtitle: subtitle,
            theme: theme.useMaterial3 ? theme.textTheme : theme.primaryTextTheme,
            titleTextStyle: theme.appBarTheme.titleTextStyle,
            foregroundColor: theme.appBarTheme.foregroundColor,
          ),
        ),
        body: Center(
          child: Material(
            color: theme.cardColor,
            elevation: 4.0,
            child: Container(
              constraints: BoxConstraints.loose(const Size.fromWidth(600.0)),
              child: Localizations.override(
                locale: const Locale('en', 'US'),
                context: context,
                child: ScrollConfiguration(
                  // A Scrollbar is built-in below.
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: Scrollbar(
                    child: ListView(
                      primary: true,
                      padding: padding,
                      children: listWidgets,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      page = CustomScrollView(
        controller: widget.scrollController,
        slivers: <Widget>[
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            backgroundColor: theme.cardColor,
            title: _PackageLicensePageTitle(
              title: title,
              subtitle: subtitle,
              theme: theme.textTheme,
              titleTextStyle: theme.textTheme.titleLarge,
            ),
          ),
          SliverPadding(
            padding: padding,
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => Localizations.override(
                  locale: const Locale('en', 'US'),
                  context: context,
                  child: listWidgets[index],
                ),
                childCount: listWidgets.length,
              ),
            ),
          ),
        ],
      );
    }
    return DefaultTextStyle(
      style: theme.textTheme.bodySmall!,
      child: page,
    );
  }
}

class _PackageLicensePageTitle extends StatelessWidget {
  const _PackageLicensePageTitle({
    required this.title,
    required this.subtitle,
    required this.theme,
    this.titleTextStyle,
    this.foregroundColor,
  });

  final String title;
  final String subtitle;
  final TextTheme theme;
  final TextStyle? titleTextStyle;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle? effectiveTitleTextStyle = titleTextStyle ?? theme.titleLarge;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: effectiveTitleTextStyle?.copyWith(color: foregroundColor)),
        Text(subtitle, style: theme.titleSmall?.copyWith(color: foregroundColor)),
      ],
    );
  }
}

String _defaultApplicationName(BuildContext context) {
  // This doesn't handle the case of the application's title dynamically
  // changing. In theory, we should make Title expose the current application
  // title using an InheritedWidget, and so forth. However, in practice, if
  // someone really wants their application title to change dynamically, they
  // can provide an explicit applicationName to the widgets defined in this
  // file, instead of relying on the default.
  final Title? ancestorTitle = context.findAncestorWidgetOfExactType<Title>();
  return ancestorTitle?.title ?? Platform.resolvedExecutable.split(Platform.pathSeparator).last;
}

String _defaultApplicationVersion(BuildContext context) {
  // TODO(ianh): Get this from the embedder somehow.
  return '';
}

Widget? _defaultApplicationIcon(BuildContext context) {
  // TODO(ianh): Get this from the embedder somehow.
  return null;
}

const int _materialGutterThreshold = 720;
const double _wideGutterSize = 24.0;
const double _narrowGutterSize = 12.0;

double _getGutterSize(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= _materialGutterThreshold ? _wideGutterSize : _narrowGutterSize;

typedef _MasterViewBuilder = Widget Function(BuildContext context, bool isLateralUI);

typedef _DetailPageBuilder = Widget Function(BuildContext context, Object? arguments, ScrollController? scrollController);

typedef _ActionBuilder = List<Widget> Function(BuildContext context, _ActionLevel actionLevel);

enum _ActionLevel {
  top,

  view,
}

enum _LayoutMode {
  lateral,

  nested,
}

const String _navMaster = 'master';
const String _navDetail = 'detail';
enum _Focus { master, detail }

class _MasterDetailFlow extends StatefulWidget {
  const _MasterDetailFlow({
    required this.detailPageBuilder,
    required this.masterViewBuilder,
    this.detailPageFABlessGutterWidth,
    this.title,
  });

  final _MasterViewBuilder masterViewBuilder;

  final _DetailPageBuilder detailPageBuilder;

  final double? detailPageFABlessGutterWidth;

  final Widget? title;

  @override
  _MasterDetailFlowState createState() => _MasterDetailFlowState();

  // The master detail flow proxy from the closest instance of this class that encloses the given
  // context.
  //
  // Typical usage is as follows:
  //
  // ```dart
  // _MasterDetailFlow.of(context).openDetailPage(arguments);
  // ```
  static _MasterDetailFlowProxy of(BuildContext context) {
    _PageOpener? pageOpener = context.findAncestorStateOfType<_MasterDetailScaffoldState>();
    pageOpener ??= context.findAncestorStateOfType<_MasterDetailFlowState>();
    assert(() {
      if (pageOpener == null) {
        throw FlutterError(
          'Master Detail operation requested with a context that does not include a Master Detail '
          'Flow.\nThe context used to open a detail page from the Master Detail Flow must be '
          'that of a widget that is a descendant of a Master Detail Flow widget.',
        );
      }
      return true;
    }());
    return _MasterDetailFlowProxy._(pageOpener!);
  }
}

class _MasterDetailFlowProxy implements _PageOpener {
  _MasterDetailFlowProxy._(this._pageOpener);

  final _PageOpener _pageOpener;

  @override
  void openDetailPage(Object arguments) =>
      _pageOpener.openDetailPage(arguments);

  @override
  void setInitialDetailPage(Object arguments) =>
      _pageOpener.setInitialDetailPage(arguments);
}

abstract class _PageOpener {
  void openDetailPage(Object arguments);

  void setInitialDetailPage(Object arguments);
}

const int _materialWideDisplayThreshold = 840;

class _MasterDetailFlowState extends State<_MasterDetailFlow> implements _PageOpener {
  _Focus focus = _Focus.master;

  Object? _cachedDetailArguments;

  _LayoutMode? _builtLayout;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void openDetailPage(Object arguments) {
    _cachedDetailArguments = arguments;
    if (_builtLayout == _LayoutMode.nested) {
      _navigatorKey.currentState!.pushNamed(_navDetail, arguments: arguments);
    } else {
      focus = _Focus.detail;
    }
  }

  @override
  void setInitialDetailPage(Object arguments) {
    _cachedDetailArguments = arguments;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      final double availableWidth = constraints.maxWidth;
      if (availableWidth >= _materialWideDisplayThreshold) {
        return _lateralUI(context);
      }
      return _nestedUI(context);
    });
  }

  Widget _nestedUI(BuildContext context) {
    _builtLayout = _LayoutMode.nested;
    final MaterialPageRoute<void> masterPageRoute = _masterPageRoute(context);

    return NavigatorPopHandler(
      onPop: () {
        _navigatorKey.currentState!.maybePop();
      },
      child: Navigator(
        key: _navigatorKey,
        initialRoute: 'initial',
        onGenerateInitialRoutes: (NavigatorState navigator, String initialRoute) {
          switch (focus) {
            case _Focus.master:
              return <Route<void>>[masterPageRoute];
            case _Focus.detail:
              return <Route<void>>[
                masterPageRoute,
                _detailPageRoute(_cachedDetailArguments),
              ];
          }
        },
        onGenerateRoute: (RouteSettings settings) {
          switch (settings.name) {
            case _navMaster:
              // Matching state to navigation event.
              focus = _Focus.master;
              return masterPageRoute;
            case _navDetail:
              // Matching state to navigation event.
              focus = _Focus.detail;
              // Cache detail page settings.
              _cachedDetailArguments = settings.arguments;
              return _detailPageRoute(_cachedDetailArguments);
            default:
              throw Exception('Unknown route ${settings.name}');
          }
        },
      ),
    );
  }

  MaterialPageRoute<void> _masterPageRoute(BuildContext context) {
    return MaterialPageRoute<dynamic>(
      builder: (BuildContext c) {
        return BlockSemantics(
          child: _MasterPage(
            leading: Navigator.of(context).canPop()
              ? BackButton(onPressed: () { Navigator.of(context).pop(); })
              : null,
            title: widget.title,
            masterViewBuilder: widget.masterViewBuilder,
          ),
        );
      },
    );
  }

  MaterialPageRoute<void> _detailPageRoute(Object? arguments) {
    return MaterialPageRoute<dynamic>(builder: (BuildContext context) {
      return PopScope(
        onPopInvoked: (bool didPop) {
          // No need for setState() as rebuild happens on navigation pop.
          focus = _Focus.master;
        },
        child: BlockSemantics(child: widget.detailPageBuilder(context, arguments, null)),
      );
    });
  }

  Widget _lateralUI(BuildContext context) {
    _builtLayout = _LayoutMode.lateral;
    return _MasterDetailScaffold(
      actionBuilder: (_, __) => const<Widget>[],
      detailPageBuilder: (BuildContext context, Object? args, ScrollController? scrollController) =>
          widget.detailPageBuilder(context, args ?? _cachedDetailArguments, scrollController),
      detailPageFABlessGutterWidth: widget.detailPageFABlessGutterWidth,
      initialArguments: _cachedDetailArguments,
      masterViewBuilder: (BuildContext context, bool isLateral) => widget.masterViewBuilder(context, isLateral),
      title: widget.title,
    );
  }
}

class _MasterPage extends StatelessWidget {
  const _MasterPage({
    this.leading,
    this.title,
    this.masterViewBuilder,
  });

  final _MasterViewBuilder? masterViewBuilder;
  final Widget? title;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title,
        leading: leading,
        actions: const <Widget>[],
      ),
      body: masterViewBuilder!(context, false),
    );
  }

}

const double _kCardElevation = 4.0;
const double _kMasterViewWidth = 320.0;
const double _kDetailPageFABlessGutterWidth = 40.0;
const double _kDetailPageFABGutterWidth = 84.0;

class _MasterDetailScaffold extends StatefulWidget {
  const _MasterDetailScaffold({
    required this.detailPageBuilder,
    required this.masterViewBuilder,
    this.actionBuilder,
    this.initialArguments,
    this.title,
    this.detailPageFABlessGutterWidth,
  });

  final _MasterViewBuilder masterViewBuilder;

  final _DetailPageBuilder detailPageBuilder;
  final _ActionBuilder? actionBuilder;
  final Object? initialArguments;
  final Widget? title;
  final double? detailPageFABlessGutterWidth;

  @override
  _MasterDetailScaffoldState createState() => _MasterDetailScaffoldState();
}

class _MasterDetailScaffoldState extends State<_MasterDetailScaffold>
    implements _PageOpener {
  late FloatingActionButtonLocation floatingActionButtonLocation;
  late double detailPageFABGutterWidth;
  late double detailPageFABlessGutterWidth;
  late double masterViewWidth;

  final ValueNotifier<Object?> _detailArguments = ValueNotifier<Object?>(null);

  @override
  void initState() {
    super.initState();
    detailPageFABlessGutterWidth = widget.detailPageFABlessGutterWidth ?? _kDetailPageFABlessGutterWidth;
    detailPageFABGutterWidth = _kDetailPageFABGutterWidth;
    masterViewWidth = _kMasterViewWidth;
    floatingActionButtonLocation = FloatingActionButtonLocation.endTop;
  }

  @override
  void dispose() {
    _detailArguments.dispose();
    super.dispose();
  }

  @override
  void openDetailPage(Object arguments) {
    SchedulerBinding.instance.addPostFrameCallback((_) => _detailArguments.value = arguments);
    _MasterDetailFlow.of(context).openDetailPage(arguments);
  }

  @override
  void setInitialDetailPage(Object arguments) {
    SchedulerBinding.instance.addPostFrameCallback((_) => _detailArguments.value = arguments);
    _MasterDetailFlow.of(context).setInitialDetailPage(arguments);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Scaffold(
          floatingActionButtonLocation: floatingActionButtonLocation,
          appBar: AppBar(
            title: widget.title,
            actions: widget.actionBuilder!(context, _ActionLevel.top),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: Row(
                children: <Widget>[
                  ConstrainedBox(
                    constraints: BoxConstraints.tightFor(width: masterViewWidth),
                    child: IconTheme(
                      data: Theme.of(context).primaryIconTheme,
                      child: Container(
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsets.all(8),
                        child: OverflowBar(
                          spacing: 8,
                          overflowAlignment: OverflowBarAlignment.end,
                          children: widget.actionBuilder!(context, _ActionLevel.view),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _masterPanel(context),
          ),
        ),
        // Detail view stacked above main scaffold and master view.
        SafeArea(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: masterViewWidth - _kCardElevation,
              end: detailPageFABlessGutterWidth,
            ),
            child: ValueListenableBuilder<Object?>(
              valueListenable: _detailArguments,
              builder: (BuildContext context, Object? value, Widget? child) {
                return AnimatedSwitcher(
                  transitionBuilder: (Widget child, Animation<double> animation) =>
                    const FadeUpwardsPageTransitionsBuilder().buildTransitions<void>(
                      null,
                      null,
                      animation,
                      null,
                      child,
                    ),
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    key: ValueKey<Object?>(value ?? widget.initialArguments),
                    constraints: const BoxConstraints.expand(),
                    child: _DetailView(
                      builder: widget.detailPageBuilder,
                      arguments: value ?? widget.initialArguments,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  ConstrainedBox _masterPanel(BuildContext context, {bool needsScaffold = false}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: masterViewWidth),
      child: needsScaffold
          ? Scaffold(
              appBar: AppBar(
                title: widget.title,
                actions: widget.actionBuilder!(context, _ActionLevel.top),
              ),
              body: widget.masterViewBuilder(context, true),
            )
          : widget.masterViewBuilder(context, true),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({
    required _DetailPageBuilder builder,
    Object? arguments,
  })  : _builder = builder,
        _arguments = arguments;

  final _DetailPageBuilder _builder;
  final Object? _arguments;

  @override
  Widget build(BuildContext context) {
    if (_arguments == null) {
      return const SizedBox.shrink();
    }
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double minHeight = (screenHeight - kToolbarHeight) / screenHeight;

    return DraggableScrollableSheet(
      initialChildSize: minHeight,
      minChildSize: minHeight,
      expand: false,
      builder: (BuildContext context, ScrollController controller) {
        return MouseRegion(
          // TODO(TonicArtos): Remove MouseRegion workaround for pointer hover events passing through DraggableScrollableSheet once https://github.com/flutter/flutter/issues/59741 is resolved.
          child: Card(
            color: Theme.of(context).cardColor,
            elevation: _kCardElevation,
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.fromLTRB(_kCardElevation, 0.0, _kCardElevation, 0.0),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(3.0)),
            ),
            child: _builder(
              context,
              _arguments,
              controller,
            ),
          ),
        );
      },
    );
  }
}