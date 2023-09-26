// Examples can assume:
// class Cat { }

class Category {
  const Category(this.sections);

  final List<String> sections;
}

class DocumentationIcon {
  const DocumentationIcon(this.url);

  final String url;
}

class Summary {
  const Summary(this.text);

  final String text;
}
