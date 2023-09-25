// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'data_table.dart';

abstract class DataTableSource extends ChangeNotifier {
  DataRow? getRow(int index);

  int get rowCount;

  bool get isRowCountApproximate;

  int get selectedRowCount;
}