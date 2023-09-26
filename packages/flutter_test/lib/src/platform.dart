import 'dart:io';

const bool isBrowser = identical(0, 0.0);

bool get isWindows {
  if (isBrowser) {
    return false;
  }
  return Platform.isWindows;
}

bool get isMacOS {
  if (isBrowser) {
    return false;
  }
  return Platform.isMacOS;
}

bool get isLinux {
  if (isBrowser) {
    return false;
  }
  return Platform.isLinux;
}
