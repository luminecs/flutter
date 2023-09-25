import 'package:html/dom.dart';
import 'package:html/parser.dart';

import 'base/common.dart';

const String kBaseHrefPlaceholder = r'$FLUTTER_BASE_HREF';

class IndexHtml {
  IndexHtml(this._content);

  String get content => _content;
  String _content;

  Document _getDocument() => parse(_content);

  String getBaseHref() {
    final Element? baseElement = _getDocument().querySelector('base');
    final String? baseHref = baseElement?.attributes == null
        ? null
        : baseElement!.attributes['href'];

    if (baseHref == null || baseHref == kBaseHrefPlaceholder) {
      return '';
    }

    if (!baseHref.startsWith('/')) {
      throw ToolExit(
        'Error: The base href in "web/index.html" must be absolute (i.e. start '
        'with a "/"), but found: `${baseElement!.outerHtml}`.\n'
        '$_kBasePathExample',
      );
    }

    if (!baseHref.endsWith('/')) {
      throw ToolExit(
        'Error: The base href in "web/index.html" must end with a "/", but found: `${baseElement!.outerHtml}`.\n'
        '$_kBasePathExample',
      );
    }

    return stripLeadingSlash(stripTrailingSlash(baseHref));
  }

  void applySubstitutions({
    required String baseHref,
    required String? serviceWorkerVersion,
  }) {
    if (_content.contains(kBaseHrefPlaceholder)) {
      _content = _content.replaceAll(kBaseHrefPlaceholder, baseHref);
    }

    if (serviceWorkerVersion != null) {
      _content = _content
          .replaceFirst(
            // Support older `var` syntax as well as new `const` syntax
            RegExp('(const|var) serviceWorkerVersion = null'),
            'const serviceWorkerVersion = "$serviceWorkerVersion"',
          )
          // This is for legacy index.html that still uses the old service
          // worker loading mechanism.
          .replaceFirst(
            "navigator.serviceWorker.register('flutter_service_worker.js')",
            "navigator.serviceWorker.register('flutter_service_worker.js?v=$serviceWorkerVersion')",
          );
    }
  }
}

String stripLeadingSlash(String path) {
  while (path.startsWith('/')) {
    path = path.substring(1);
  }
  return path;
}

String stripTrailingSlash(String path) {
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

const String _kBasePathExample = '''
For example, to serve from the root use:

    <base href="/">

To serve from a subpath "foo" (i.e. http://localhost:8080/foo/ instead of http://localhost:8080/) use:

    <base href="/foo/">

For more information, see: https://developer.mozilla.org/en-US/docs/Web/HTML/Element/base
''';