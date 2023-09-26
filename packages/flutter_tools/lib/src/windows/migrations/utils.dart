String replaceFirst(String originalContents, String before, String after) {
  final String result = originalContents.replaceFirst(before, after);
  if (result != originalContents) {
    return result;
  }

  final String beforeCrlf = before.replaceAll('\n', '\r\n');
  final String afterCrlf = after.replaceAll('\n', '\r\n');

  return originalContents.replaceFirst(beforeCrlf, afterCrlf);
}
