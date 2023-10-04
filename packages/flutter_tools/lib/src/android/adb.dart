final RegExp _whitespace = RegExp(r'\s+');

String cleanAdbDeviceName(String name) {
  // Some emulators use `___` in the name as separators.
  name = name.replaceAll('___', ', ');

  // Convert `Nexus_7` / `Nexus_5X` style names to `Nexus 7` ones.
  name = name.replaceAll('_', ' ');

  name = name.replaceAll(_whitespace, ' ').trim();

  return name;
}
