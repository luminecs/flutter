// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';
import 'dart:io';

enum LoggingLevel {
  none,

  severe,

  warning,

  info,

  fine,

  all,
}

typedef LoggingFunction = void Function(LogMessage log);

void defaultLoggingFunction(LogMessage log) {
  // ignore: avoid_print
  print('[${log.levelName}]::${log.tag}--${log.time}: ${log.message}');
  if (log.level == LoggingLevel.severe) {
    exit(1);
  }
}

class LogMessage {
  LogMessage(this.message, this.tag, this.level)
    : levelName = level.toString().substring(level.toString().indexOf('.') + 1),
      time = DateTime.now();

  final String message;

  final DateTime time;

  final LoggingLevel level;

  final String levelName;

  final String tag;
}

class Logger {
  Logger(this.tag);

  final String tag;

  static LoggingFunction loggingFunction = defaultLoggingFunction;

  static LoggingLevel globalLevel = LoggingLevel.none;

  void severe(String message) {
    loggingFunction(LogMessage(message, tag, LoggingLevel.severe));
  }

  void warning(String message) {
    if (globalLevel.index >= LoggingLevel.warning.index) {
      loggingFunction(LogMessage(message, tag, LoggingLevel.warning));
    }
  }

  void info(String message) {
    if (globalLevel.index >= LoggingLevel.info.index) {
      loggingFunction(LogMessage(message, tag, LoggingLevel.info));
    }
  }

  void fine(String message) {
    if (globalLevel.index >= LoggingLevel.fine.index) {
      loggingFunction(LogMessage(message, tag, LoggingLevel.fine));
    }
  }
}