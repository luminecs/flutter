// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/task_result.dart';
import 'package:flutter_devicelab/framework/utils.dart';
import 'package:flutter_devicelab/versions/gallery.dart' show galleryVersion;
import 'package:path/path.dart' as path;

Future<void> main() async {
  await task(const NewGalleryChromeRunTest().run);
}

const Duration durationToWaitForError = Duration(seconds: 5);

const String successfullyLoadedString = 'To hot restart';

const String exceptionString = 'EXCEPTION CAUGHT';

class NewGalleryChromeRunTest {
  const NewGalleryChromeRunTest();

  Future<TaskResult> run() async {
    final Directory galleryParentDir =
        Directory.systemTemp.createTempSync('flutter_gallery_v2_chrome_run.');
    final Directory galleryDir =
        Directory(path.join(galleryParentDir.path, 'gallery'));

    await getNewGallery(galleryVersion, galleryDir);

    final TaskResult result = await inDirectory<TaskResult>(galleryDir, () async {
      await flutter('doctor');
      await flutter('packages', options: <String>['get']);

      await flutter('build', options: <String>[
        'web',
        '-v',
        '--release',
        '--no-pub',
      ]);

      final List<String> options = <String>['-d', 'chrome', '--verbose', '--resident'];
      final Process process = await startFlutter(
        'run',
        options: options,
      );

      final Completer<void> stdoutDone = Completer<void>();
      final Completer<void> stderrDone = Completer<void>();

      bool success = true;

      process.stdout
          .transform<String>(utf8.decoder)
          .transform<String>(const LineSplitter())
          .listen((String line) {
        if (line.contains(successfullyLoadedString)) {
          // Successfully started.
          Future<void>.delayed(
            durationToWaitForError,
            () {process.stdin.write('q');}
          );
        }
        if (line.contains(exceptionString)) {
          success = false;
        }
        print('stdout: $line');
      }, onDone: () {
        stdoutDone.complete();
      });

      process.stderr
          .transform<String>(utf8.decoder)
          .transform<String>(const LineSplitter())
          .listen((String line) {
        print('stderr: $line');
      }, onDone: () {
        stderrDone.complete();
      });

      await Future.wait<void>(<Future<void>>[
        stdoutDone.future,
        stderrDone.future,
      ]);

      await process.exitCode;

      if (success) {
        return TaskResult.success(<String, dynamic>{});
      } else {
        return TaskResult.failure('An exception was thrown.');
      }
    });

    rmTree(galleryParentDir);

    return result;
  }
}