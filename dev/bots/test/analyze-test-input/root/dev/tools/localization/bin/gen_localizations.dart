void main(List<String> args) {
  String type = '';
  if (args[0] == '--material') {
    type = 'material';
  }
  if (args[0] == '--cupertino') {
    type = 'cupertino';
  }
  print('''
void main(List<String> args) {
  print('Expected output $type');
}
''');
}