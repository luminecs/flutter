import 'dart:io' as system;

// this is a test to make sure our tests consider engine crashes to be failures
// see //flutter/dev/bots/test.dart

void main() {
  system.Process.killPid(system.pid, system.ProcessSignal.sigsegv);
}
