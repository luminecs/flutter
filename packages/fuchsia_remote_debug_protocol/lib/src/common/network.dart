
import 'dart:core';

void validateAddress(String address) {
  if (!(isIpV4Address(address) || isIpV6Address(address))) {
    throw ArgumentError(
        '"$address" is neither a valid IPv4 nor IPv6 address');
  }
}

bool isIpV6Address(String address) {
  try {
    // parseIpv6Address fails if there's a zone ID. Since this is still a valid
    // IP, remove any zone ID before parsing.
    final List<String> addressParts = address.split('%');
    Uri.parseIPv6Address(addressParts[0]);
    return true;
  } on FormatException {
    return false;
  }
}

bool isIpV4Address(String address) {
  try {
    Uri.parseIPv4Address(address);
    return true;
  } on FormatException {
    return false;
  }
}