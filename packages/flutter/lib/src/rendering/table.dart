// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'box.dart';
import 'object.dart';
import 'table_border.dart';

class TableCellParentData extends BoxParentData {
  TableCellVerticalAlignment? verticalAlignment;

  int? x;

  int? y;

  @override
  String toString() => '${super.toString()}; ${verticalAlignment == null ? "default vertical alignment" : "$verticalAlignment"}';
}

@immutable
abstract class TableColumnWidth {
  const TableColumnWidth();

  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth);

  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth);

  double? flex(Iterable<RenderBox> cells) => null;

  @override
  String toString() => objectRuntimeType(this, 'TableColumnWidth');
}

class IntrinsicColumnWidth extends TableColumnWidth {
  const IntrinsicColumnWidth({ double? flex }) : _flex = flex;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double result = 0.0;
    for (final RenderBox cell in cells) {
      result = math.max(result, cell.getMinIntrinsicWidth(double.infinity));
    }
    return result;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double result = 0.0;
    for (final RenderBox cell in cells) {
      result = math.max(result, cell.getMaxIntrinsicWidth(double.infinity));
    }
    return result;
  }

  final double? _flex;

  @override
  double? flex(Iterable<RenderBox> cells) => _flex;

  @override
  String toString() => '${objectRuntimeType(this, 'IntrinsicColumnWidth')}(flex: ${_flex?.toStringAsFixed(1)})';
}

class FixedColumnWidth extends TableColumnWidth {
  const FixedColumnWidth(this.value);

  final double value;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return value;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return value;
  }

  @override
  String toString() => '${objectRuntimeType(this, 'FixedColumnWidth')}(${debugFormatDouble(value)})';
}

class FractionColumnWidth extends TableColumnWidth {
  const FractionColumnWidth(this.value);

  final double value;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    if (!containerWidth.isFinite) {
      return 0.0;
    }
    return value * containerWidth;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    if (!containerWidth.isFinite) {
      return 0.0;
    }
    return value * containerWidth;
  }

  @override
  String toString() => '${objectRuntimeType(this, 'FractionColumnWidth')}($value)';
}

class FlexColumnWidth extends TableColumnWidth {
  const FlexColumnWidth([this.value = 1.0]);

  final double value;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return 0.0;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return 0.0;
  }

  @override
  double flex(Iterable<RenderBox> cells) {
    return value;
  }

  @override
  String toString() => '${objectRuntimeType(this, 'FlexColumnWidth')}(${debugFormatDouble(value)})';
}

class MaxColumnWidth extends TableColumnWidth {
  const MaxColumnWidth(this.a, this.b);

  final TableColumnWidth a;

  final TableColumnWidth b;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return math.max(
      a.minIntrinsicWidth(cells, containerWidth),
      b.minIntrinsicWidth(cells, containerWidth),
    );
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return math.max(
      a.maxIntrinsicWidth(cells, containerWidth),
      b.maxIntrinsicWidth(cells, containerWidth),
    );
  }

  @override
  double? flex(Iterable<RenderBox> cells) {
    final double? aFlex = a.flex(cells);
    final double? bFlex = b.flex(cells);
    if (aFlex == null) {
      return bFlex;
    } else if (bFlex == null) {
      return aFlex;
    }
    return math.max(aFlex, bFlex);
  }

  @override
  String toString() => '${objectRuntimeType(this, 'MaxColumnWidth')}($a, $b)';
}

class MinColumnWidth extends TableColumnWidth {
  const MinColumnWidth(this.a, this.b);

  final TableColumnWidth a;

  final TableColumnWidth b;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return math.min(
      a.minIntrinsicWidth(cells, containerWidth),
      b.minIntrinsicWidth(cells, containerWidth),
    );
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return math.min(
      a.maxIntrinsicWidth(cells, containerWidth),
      b.maxIntrinsicWidth(cells, containerWidth),
    );
  }

  @override
  double? flex(Iterable<RenderBox> cells) {
    final double? aFlex = a.flex(cells);
    final double? bFlex = b.flex(cells);
    if (aFlex == null) {
      return bFlex;
    } else if (bFlex == null) {
      return aFlex;
    }
    return math.min(aFlex, bFlex);
  }

  @override
  String toString() => '${objectRuntimeType(this, 'MinColumnWidth')}($a, $b)';
}

enum TableCellVerticalAlignment {
  top,

  middle,

  bottom,

  baseline,

  fill
}

class RenderTable extends RenderBox {
  RenderTable({
    int? columns,
    int? rows,
    Map<int, TableColumnWidth>? columnWidths,
    TableColumnWidth defaultColumnWidth = const FlexColumnWidth(),
    required TextDirection textDirection,
    TableBorder? border,
    List<Decoration?>? rowDecorations,
    ImageConfiguration configuration = ImageConfiguration.empty,
    TableCellVerticalAlignment defaultVerticalAlignment = TableCellVerticalAlignment.top,
    TextBaseline? textBaseline,
    List<List<RenderBox>>? children,
  }) : assert(columns == null || columns >= 0),
       assert(rows == null || rows >= 0),
       assert(rows == null || children == null),
       _textDirection = textDirection,
       _columns = columns ?? (children != null && children.isNotEmpty ? children.first.length : 0),
       _rows = rows ?? 0,
       _columnWidths = columnWidths ?? HashMap<int, TableColumnWidth>(),
       _defaultColumnWidth = defaultColumnWidth,
       _border = border,
       _textBaseline = textBaseline,
       _defaultVerticalAlignment = defaultVerticalAlignment,
       _configuration = configuration {
    _children = <RenderBox?>[]..length = _columns * _rows;
    this.rowDecorations = rowDecorations; // must use setter to initialize box painters array
    children?.forEach(addRow);
  }

  // Children are stored in row-major order.
  // _children.length must be rows * columns
  List<RenderBox?> _children = const <RenderBox?>[];

  int get columns => _columns;
  int _columns;
  set columns(int value) {
    assert(value >= 0);
    if (value == columns) {
      return;
    }
    final int oldColumns = columns;
    final List<RenderBox?> oldChildren = _children;
    _columns = value;
    _children = List<RenderBox?>.filled(columns * rows, null);
    final int columnsToCopy = math.min(columns, oldColumns);
    for (int y = 0; y < rows; y += 1) {
      for (int x = 0; x < columnsToCopy; x += 1) {
        _children[x + y * columns] = oldChildren[x + y * oldColumns];
      }
    }
    if (oldColumns > columns) {
      for (int y = 0; y < rows; y += 1) {
        for (int x = columns; x < oldColumns; x += 1) {
          final int xy = x + y * oldColumns;
          if (oldChildren[xy] != null) {
            dropChild(oldChildren[xy]!);
          }
        }
      }
    }
    markNeedsLayout();
  }

  int get rows => _rows;
  int _rows;
  set rows(int value) {
    assert(value >= 0);
    if (value == rows) {
      return;
    }
    if (_rows > value) {
      for (int xy = columns * value; xy < _children.length; xy += 1) {
        if (_children[xy] != null) {
          dropChild(_children[xy]!);
        }
      }
    }
    _rows = value;
    _children.length = columns * rows;
    markNeedsLayout();
  }

  Map<int, TableColumnWidth>? get columnWidths => Map<int, TableColumnWidth>.unmodifiable(_columnWidths);
  Map<int, TableColumnWidth> _columnWidths;
  set columnWidths(Map<int, TableColumnWidth>? value) {
    if (_columnWidths == value) {
      return;
    }
    if (_columnWidths.isEmpty && value == null) {
      return;
    }
    _columnWidths = value ?? HashMap<int, TableColumnWidth>();
    markNeedsLayout();
  }

  void setColumnWidth(int column, TableColumnWidth value) {
    if (_columnWidths[column] == value) {
      return;
    }
    _columnWidths[column] = value;
    markNeedsLayout();
  }

  TableColumnWidth get defaultColumnWidth => _defaultColumnWidth;
  TableColumnWidth _defaultColumnWidth;
  set defaultColumnWidth(TableColumnWidth value) {
    if (defaultColumnWidth == value) {
      return;
    }
    _defaultColumnWidth = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  TableBorder? get border => _border;
  TableBorder? _border;
  set border(TableBorder? value) {
    if (border == value) {
      return;
    }
    _border = value;
    markNeedsPaint();
  }

  List<Decoration> get rowDecorations => List<Decoration>.unmodifiable(_rowDecorations ?? const <Decoration>[]);
  // _rowDecorations and _rowDecorationPainters need to be in sync. They have to
  // either both be null or have same length.
  List<Decoration?>? _rowDecorations;
  List<BoxPainter?>? _rowDecorationPainters;
  set rowDecorations(List<Decoration?>? value) {
    if (_rowDecorations == value) {
      return;
    }
    _rowDecorations = value;
    if (_rowDecorationPainters != null) {
      for (final BoxPainter? painter in _rowDecorationPainters!) {
        painter?.dispose();
      }
    }
    _rowDecorationPainters = _rowDecorations != null ? List<BoxPainter?>.filled(_rowDecorations!.length, null) : null;
  }

  ImageConfiguration get configuration => _configuration;
  ImageConfiguration _configuration;
  set configuration(ImageConfiguration value) {
    if (value == _configuration) {
      return;
    }
    _configuration = value;
    markNeedsPaint();
  }

  TableCellVerticalAlignment get defaultVerticalAlignment => _defaultVerticalAlignment;
  TableCellVerticalAlignment _defaultVerticalAlignment;
  set defaultVerticalAlignment(TableCellVerticalAlignment value) {
    if (_defaultVerticalAlignment == value) {
      return;
    }
    _defaultVerticalAlignment = value;
    markNeedsLayout();
  }

  TextBaseline? get textBaseline => _textBaseline;
  TextBaseline? _textBaseline;
  set textBaseline(TextBaseline? value) {
    if (_textBaseline == value) {
      return;
    }
    _textBaseline = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! TableCellParentData) {
      child.parentData = TableCellParentData();
    }
  }

  void setFlatChildren(int columns, List<RenderBox?> cells) {
    if (cells == _children && columns == _columns) {
      return;
    }
    assert(columns >= 0);
    // consider the case of a newly empty table
    if (columns == 0 || cells.isEmpty) {
      assert(cells.isEmpty);
      _columns = columns;
      if (_children.isEmpty) {
        assert(_rows == 0);
        return;
      }
      for (final RenderBox? oldChild in _children) {
        if (oldChild != null) {
          dropChild(oldChild);
        }
      }
      _rows = 0;
      _children.clear();
      markNeedsLayout();
      return;
    }
    assert(cells.length % columns == 0);
    // fill a set with the cells that are moving (it's important not
    // to dropChild a child that's remaining with us, because that
    // would clear their parentData field)
    final Set<RenderBox> lostChildren = HashSet<RenderBox>();
    for (int y = 0; y < _rows; y += 1) {
      for (int x = 0; x < _columns; x += 1) {
        final int xyOld = x + y * _columns;
        final int xyNew = x + y * columns;
        if (_children[xyOld] != null && (x >= columns || xyNew >= cells.length || _children[xyOld] != cells[xyNew])) {
          lostChildren.add(_children[xyOld]!);
        }
      }
    }
    // adopt cells that are arriving, and cross cells that are just moving off our list of lostChildren
    int y = 0;
    while (y * columns < cells.length) {
      for (int x = 0; x < columns; x += 1) {
        final int xyNew = x + y * columns;
        final int xyOld = x + y * _columns;
        if (cells[xyNew] != null && (x >= _columns || y >= _rows || _children[xyOld] != cells[xyNew])) {
          if (!lostChildren.remove(cells[xyNew])) {
            adoptChild(cells[xyNew]!);
          }
        }
      }
      y += 1;
    }
    // drop all the lost children
    lostChildren.forEach(dropChild);
    // update our internal values
    _columns = columns;
    _rows = cells.length ~/ columns;
    _children = List<RenderBox?>.of(cells);
    assert(_children.length == rows * columns);
    markNeedsLayout();
  }

  void setChildren(List<List<RenderBox>>? cells) {
    // TODO(ianh): Make this smarter, like setFlatChildren
    if (cells == null) {
      setFlatChildren(0, const <RenderBox?>[]);
      return;
    }
    for (final RenderBox? oldChild in _children) {
      if (oldChild != null) {
        dropChild(oldChild);
      }
    }
    _children.clear();
    _columns = cells.isNotEmpty ? cells.first.length : 0;
    _rows = 0;
    cells.forEach(addRow);
    assert(_children.length == rows * columns);
  }

  void addRow(List<RenderBox?> cells) {
    assert(cells.length == columns);
    assert(_children.length == rows * columns);
    _rows += 1;
    _children.addAll(cells);
    for (final RenderBox? cell in cells) {
      if (cell != null) {
        adoptChild(cell);
      }
    }
    markNeedsLayout();
  }

  void setChild(int x, int y, RenderBox? value) {
    assert(x >= 0 && x < columns && y >= 0 && y < rows);
    assert(_children.length == rows * columns);
    final int xy = x + y * columns;
    final RenderBox? oldChild = _children[xy];
    if (oldChild == value) {
      return;
    }
    if (oldChild != null) {
      dropChild(oldChild);
    }
    _children[xy] = value;
    if (value != null) {
      adoptChild(value);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final RenderBox? child in _children) {
      child?.attach(owner);
    }
  }

  @override
  void detach() {
    super.detach();
    if (_rowDecorationPainters != null) {
      for (final BoxPainter? painter in _rowDecorationPainters!) {
        painter?.dispose();
      }
      _rowDecorationPainters = List<BoxPainter?>.filled(_rowDecorations!.length, null);
    }
    for (final RenderBox? child in _children) {
      child?.detach();
    }
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    assert(_children.length == rows * columns);
    for (final RenderBox? child in _children) {
      if (child != null) {
        visitor(child);
      }
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    assert(_children.length == rows * columns);
    double totalMinWidth = 0.0;
    for (int x = 0; x < columns; x += 1) {
      final TableColumnWidth columnWidth = _columnWidths[x] ?? defaultColumnWidth;
      final Iterable<RenderBox> columnCells = column(x);
      totalMinWidth += columnWidth.minIntrinsicWidth(columnCells, double.infinity);
    }
    return totalMinWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    assert(_children.length == rows * columns);
    double totalMaxWidth = 0.0;
    for (int x = 0; x < columns; x += 1) {
      final TableColumnWidth columnWidth = _columnWidths[x] ?? defaultColumnWidth;
      final Iterable<RenderBox> columnCells = column(x);
      totalMaxWidth += columnWidth.maxIntrinsicWidth(columnCells, double.infinity);
    }
    return totalMaxWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    // winner of the 2016 world's most expensive intrinsic dimension function award
    // honorable mention, most likely to improve if taught about memoization award
    assert(_children.length == rows * columns);
    final List<double> widths = _computeColumnWidths(BoxConstraints.tightForFinite(width: width));
    double rowTop = 0.0;
    for (int y = 0; y < rows; y += 1) {
      double rowHeight = 0.0;
      for (int x = 0; x < columns; x += 1) {
        final int xy = x + y * columns;
        final RenderBox? child = _children[xy];
        if (child != null) {
          rowHeight = math.max(rowHeight, child.getMaxIntrinsicHeight(widths[x]));
        }
      }
      rowTop += rowHeight;
    }
    return rowTop;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return computeMinIntrinsicHeight(width);
  }

  double? _baselineDistance;
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    // returns the baseline of the first cell that has a baseline in the first row
    assert(!debugNeedsLayout);
    return _baselineDistance;
  }

  // The following uses sync* because it is public API documented to return a
  // lazy iterable.
  Iterable<RenderBox> column(int x) sync* {
    for (int y = 0; y < rows; y += 1) {
      final int xy = x + y * columns;
      final RenderBox? child = _children[xy];
      if (child != null) {
        yield child;
      }
    }
  }

  // The following uses sync* because it is public API documented to return a
  // lazy iterable.
  Iterable<RenderBox> row(int y) sync* {
    final int start = y * columns;
    final int end = (y + 1) * columns;
    for (int xy = start; xy < end; xy += 1) {
      final RenderBox? child = _children[xy];
      if (child != null) {
        yield child;
      }
    }
  }

  List<double> _computeColumnWidths(BoxConstraints constraints) {
    assert(_children.length == rows * columns);
    // We apply the constraints to the column widths in the order of
    // least important to most important:
    // 1. apply the ideal widths (maxIntrinsicWidth)
    // 2. grow the flex columns so that the table has the maxWidth (if
    //    finite) or the minWidth (if not)
    // 3. if there were no flex columns, then grow the table to the
    //    minWidth.
    // 4. apply the maximum width of the table, shrinking columns as
    //    necessary, applying minimum column widths as we go

    // 1. apply ideal widths, and collect information we'll need later
    final List<double> widths = List<double>.filled(columns, 0.0);
    final List<double> minWidths = List<double>.filled(columns, 0.0);
    final List<double?> flexes = List<double?>.filled(columns, null);
    double tableWidth = 0.0; // running tally of the sum of widths[x] for all x
    double unflexedTableWidth = 0.0; // sum of the maxIntrinsicWidths of any column that has null flex
    double totalFlex = 0.0;
    for (int x = 0; x < columns; x += 1) {
      final TableColumnWidth columnWidth = _columnWidths[x] ?? defaultColumnWidth;
      final Iterable<RenderBox> columnCells = column(x);
      // apply ideal width (maxIntrinsicWidth)
      final double maxIntrinsicWidth = columnWidth.maxIntrinsicWidth(columnCells, constraints.maxWidth);
      assert(maxIntrinsicWidth.isFinite);
      assert(maxIntrinsicWidth >= 0.0);
      widths[x] = maxIntrinsicWidth;
      tableWidth += maxIntrinsicWidth;
      // collect min width information while we're at it
      final double minIntrinsicWidth = columnWidth.minIntrinsicWidth(columnCells, constraints.maxWidth);
      assert(minIntrinsicWidth.isFinite);
      assert(minIntrinsicWidth >= 0.0);
      minWidths[x] = minIntrinsicWidth;
      assert(maxIntrinsicWidth >= minIntrinsicWidth);
      // collect flex information while we're at it
      final double? flex = columnWidth.flex(columnCells);
      if (flex != null) {
        assert(flex.isFinite);
        assert(flex > 0.0);
        flexes[x] = flex;
        totalFlex += flex;
      } else {
        unflexedTableWidth = unflexedTableWidth + maxIntrinsicWidth;
      }
    }
    final double maxWidthConstraint = constraints.maxWidth;
    final double minWidthConstraint = constraints.minWidth;

    // 2. grow the flex columns so that the table has the maxWidth (if
    //    finite) or the minWidth (if not)
    if (totalFlex > 0.0) {
      // this can only grow the table, but it _will_ grow the table at
      // least as big as the target width.
      final double targetWidth;
      if (maxWidthConstraint.isFinite) {
        targetWidth = maxWidthConstraint;
      } else {
        targetWidth = minWidthConstraint;
      }
      if (tableWidth < targetWidth) {
        final double remainingWidth = targetWidth - unflexedTableWidth;
        assert(remainingWidth.isFinite);
        assert(remainingWidth >= 0.0);
        for (int x = 0; x < columns; x += 1) {
          if (flexes[x] != null) {
            final double flexedWidth = remainingWidth * flexes[x]! / totalFlex;
            assert(flexedWidth.isFinite);
            assert(flexedWidth >= 0.0);
            if (widths[x] < flexedWidth) {
              final double delta = flexedWidth - widths[x];
              tableWidth += delta;
              widths[x] = flexedWidth;
            }
          }
        }
        assert(tableWidth + precisionErrorTolerance >= targetWidth);
      }
    } // step 2 and 3 are mutually exclusive

    // 3. if there were no flex columns, then grow the table to the
    //    minWidth.
    else if (tableWidth < minWidthConstraint) {
      final double delta = (minWidthConstraint - tableWidth) / columns;
      for (int x = 0; x < columns; x += 1) {
        widths[x] = widths[x] + delta;
      }
      tableWidth = minWidthConstraint;
    }

    // beyond this point, unflexedTableWidth is no longer valid

    // 4. apply the maximum width of the table, shrinking columns as
    //    necessary, applying minimum column widths as we go
    if (tableWidth > maxWidthConstraint) {
      double deficit = tableWidth - maxWidthConstraint;
      // Some columns may have low flex but have all the free space.
      // (Consider a case with a 1px wide column of flex 1000.0 and
      // a 1000px wide column of flex 1.0; the sizes coming from the
      // maxIntrinsicWidths. If the maximum table width is 2px, then
      // just applying the flexes to the deficit would result in a
      // table with one column at -998px and one column at 990px,
      // which is wildly unhelpful.)
      // Similarly, some columns may be flexible, but not actually
      // be shrinkable due to a large minimum width. (Consider a
      // case with two columns, one is flex and one isn't, both have
      // 1000px maxIntrinsicWidths, but the flex one has 1000px
      // minIntrinsicWidth also. The whole deficit will have to come
      // from the non-flex column.)
      // So what we do is we repeatedly iterate through the flexible
      // columns shrinking them proportionally until we have no
      // available columns, then do the same to the non-flexible ones.
      int availableColumns = columns;
      while (deficit > precisionErrorTolerance && totalFlex > precisionErrorTolerance) {
        double newTotalFlex = 0.0;
        for (int x = 0; x < columns; x += 1) {
          if (flexes[x] != null) {
            final double newWidth = widths[x] - deficit * flexes[x]! / totalFlex;
            assert(newWidth.isFinite);
            if (newWidth <= minWidths[x]) {
              // shrank to minimum
              deficit -= widths[x] - minWidths[x];
              widths[x] = minWidths[x];
              flexes[x] = null;
              availableColumns -= 1;
            } else {
              deficit -= widths[x] - newWidth;
              widths[x] = newWidth;
              newTotalFlex += flexes[x]!;
            }
            assert(widths[x] >= 0.0);
          }
        }
        totalFlex = newTotalFlex;
      }
      while (deficit > precisionErrorTolerance && availableColumns > 0) {
        // Now we have to take out the remaining space from the
        // columns that aren't minimum sized.
        // To make this fair, we repeatedly remove equal amounts from
        // each column, clamped to the minimum width, until we run out
        // of columns that aren't at their minWidth.
        final double delta = deficit / availableColumns;
        assert(delta != 0);
        int newAvailableColumns = 0;
        for (int x = 0; x < columns; x += 1) {
          final double availableDelta = widths[x] - minWidths[x];
          if (availableDelta > 0.0) {
            if (availableDelta <= delta) {
              // shrank to minimum
              deficit -= widths[x] - minWidths[x];
              widths[x] = minWidths[x];
            } else {
              deficit -= delta;
              widths[x] = widths[x] - delta;
              newAvailableColumns += 1;
            }
          }
        }
        availableColumns = newAvailableColumns;
      }
    }
    return widths;
  }

  // cache the table geometry for painting purposes
  final List<double> _rowTops = <double>[];
  Iterable<double>? _columnLefts;
  late double _tableWidth;

  Rect getRowBox(int row) {
    assert(row >= 0);
    assert(row < rows);
    assert(!debugNeedsLayout);
    return Rect.fromLTRB(0.0, _rowTops[row], size.width, _rowTops[row + 1]);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (rows * columns == 0) {
      return constraints.constrain(Size.zero);
    }
    final List<double> widths = _computeColumnWidths(constraints);
    final double tableWidth = widths.fold(0.0, (double a, double b) => a + b);
    double rowTop = 0.0;
    for (int y = 0; y < rows; y += 1) {
      double rowHeight = 0.0;
      for (int x = 0; x < columns; x += 1) {
        final int xy = x + y * columns;
        final RenderBox? child = _children[xy];
        if (child != null) {
          final TableCellParentData childParentData = child.parentData! as TableCellParentData;
          switch (childParentData.verticalAlignment ?? defaultVerticalAlignment) {
            case TableCellVerticalAlignment.baseline:
              assert(debugCannotComputeDryLayout(
                reason: 'TableCellVerticalAlignment.baseline requires a full layout for baseline metrics to be available.',
              ));
              return Size.zero;
            case TableCellVerticalAlignment.top:
            case TableCellVerticalAlignment.middle:
            case TableCellVerticalAlignment.bottom:
              final Size childSize = child.getDryLayout(BoxConstraints.tightFor(width: widths[x]));
              rowHeight = math.max(rowHeight, childSize.height);
            case TableCellVerticalAlignment.fill:
              break;
          }
        }
      }
      rowTop += rowHeight;
    }
    return constraints.constrain(Size(tableWidth, rowTop));
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    final int rows = this.rows;
    final int columns = this.columns;
    assert(_children.length == rows * columns);
    if (rows * columns == 0) {
      // TODO(ianh): if columns is zero, this should be zero width
      // TODO(ianh): if columns is not zero, this should be based on the column width specifications
      _tableWidth = 0.0;
      size = constraints.constrain(Size.zero);
      return;
    }
    final List<double> widths = _computeColumnWidths(constraints);
    final List<double> positions = List<double>.filled(columns, 0.0);
    switch (textDirection) {
      case TextDirection.rtl:
        positions[columns - 1] = 0.0;
        for (int x = columns - 2; x >= 0; x -= 1) {
          positions[x] = positions[x+1] + widths[x+1];
        }
        _columnLefts = positions.reversed;
        _tableWidth = positions.first + widths.first;
      case TextDirection.ltr:
        positions[0] = 0.0;
        for (int x = 1; x < columns; x += 1) {
          positions[x] = positions[x-1] + widths[x-1];
        }
        _columnLefts = positions;
        _tableWidth = positions.last + widths.last;
    }
    _rowTops.clear();
    _baselineDistance = null;
    // then, lay out each row
    double rowTop = 0.0;
    for (int y = 0; y < rows; y += 1) {
      _rowTops.add(rowTop);
      double rowHeight = 0.0;
      bool haveBaseline = false;
      double beforeBaselineDistance = 0.0;
      double afterBaselineDistance = 0.0;
      final List<double> baselines = List<double>.filled(columns, 0.0);
      for (int x = 0; x < columns; x += 1) {
        final int xy = x + y * columns;
        final RenderBox? child = _children[xy];
        if (child != null) {
          final TableCellParentData childParentData = child.parentData! as TableCellParentData;
          childParentData.x = x;
          childParentData.y = y;
          switch (childParentData.verticalAlignment ?? defaultVerticalAlignment) {
            case TableCellVerticalAlignment.baseline:
              assert(textBaseline != null, 'An explicit textBaseline is required when using baseline alignment.');
              child.layout(BoxConstraints.tightFor(width: widths[x]), parentUsesSize: true);
              final double? childBaseline = child.getDistanceToBaseline(textBaseline!, onlyReal: true);
              if (childBaseline != null) {
                beforeBaselineDistance = math.max(beforeBaselineDistance, childBaseline);
                afterBaselineDistance = math.max(afterBaselineDistance, child.size.height - childBaseline);
                baselines[x] = childBaseline;
                haveBaseline = true;
              } else {
                rowHeight = math.max(rowHeight, child.size.height);
                childParentData.offset = Offset(positions[x], rowTop);
              }
            case TableCellVerticalAlignment.top:
            case TableCellVerticalAlignment.middle:
            case TableCellVerticalAlignment.bottom:
              child.layout(BoxConstraints.tightFor(width: widths[x]), parentUsesSize: true);
              rowHeight = math.max(rowHeight, child.size.height);
            case TableCellVerticalAlignment.fill:
              break;
          }
        }
      }
      if (haveBaseline) {
        if (y == 0) {
          _baselineDistance = beforeBaselineDistance;
        }
        rowHeight = math.max(rowHeight, beforeBaselineDistance + afterBaselineDistance);
      }
      for (int x = 0; x < columns; x += 1) {
        final int xy = x + y * columns;
        final RenderBox? child = _children[xy];
        if (child != null) {
          final TableCellParentData childParentData = child.parentData! as TableCellParentData;
          switch (childParentData.verticalAlignment ?? defaultVerticalAlignment) {
            case TableCellVerticalAlignment.baseline:
              childParentData.offset = Offset(positions[x], rowTop + beforeBaselineDistance - baselines[x]);
            case TableCellVerticalAlignment.top:
              childParentData.offset = Offset(positions[x], rowTop);
            case TableCellVerticalAlignment.middle:
              childParentData.offset = Offset(positions[x], rowTop + (rowHeight - child.size.height) / 2.0);
            case TableCellVerticalAlignment.bottom:
              childParentData.offset = Offset(positions[x], rowTop + rowHeight - child.size.height);
            case TableCellVerticalAlignment.fill:
              child.layout(BoxConstraints.tightFor(width: widths[x], height: rowHeight));
              childParentData.offset = Offset(positions[x], rowTop);
          }
        }
      }
      rowTop += rowHeight;
    }
    _rowTops.add(rowTop);
    size = constraints.constrain(Size(_tableWidth, rowTop));
    assert(_rowTops.length == rows + 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    assert(_children.length == rows * columns);
    for (int index = _children.length - 1; index >= 0; index -= 1) {
      final RenderBox? child = _children[index];
      if (child != null) {
        final BoxParentData childParentData = child.parentData! as BoxParentData;
        final bool isHit = result.addWithPaintOffset(
          offset: childParentData.offset,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) {
            assert(transformed == position - childParentData.offset);
            return child.hitTest(result, position: transformed);
          },
        );
        if (isHit) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(_children.length == rows * columns);
    if (rows * columns == 0) {
      if (border != null) {
        final Rect borderRect = Rect.fromLTWH(offset.dx, offset.dy, _tableWidth, 0.0);
        border!.paint(context.canvas, borderRect, rows: const <double>[], columns: const <double>[]);
      }
      return;
    }
    assert(_rowTops.length == rows + 1);
    if (_rowDecorations != null) {
      assert(_rowDecorations!.length == _rowDecorationPainters!.length);
      final Canvas canvas = context.canvas;
      for (int y = 0; y < rows; y += 1) {
        if (_rowDecorations!.length <= y) {
          break;
        }
        if (_rowDecorations![y] != null) {
          _rowDecorationPainters![y] ??= _rowDecorations![y]!.createBoxPainter(markNeedsPaint);
          _rowDecorationPainters![y]!.paint(
            canvas,
            Offset(offset.dx, offset.dy + _rowTops[y]),
            configuration.copyWith(size: Size(size.width, _rowTops[y+1] - _rowTops[y])),
          );
        }
      }
    }
    for (int index = 0; index < _children.length; index += 1) {
      final RenderBox? child = _children[index];
      if (child != null) {
        final BoxParentData childParentData = child.parentData! as BoxParentData;
        context.paintChild(child, childParentData.offset + offset);
      }
    }
    assert(_rows == _rowTops.length - 1);
    assert(_columns == _columnLefts!.length);
    if (border != null) {
      // The border rect might not fill the entire height of this render object
      // if the rows underflow. We always force the columns to fill the width of
      // the render object, which means the columns cannot underflow.
      final Rect borderRect = Rect.fromLTWH(offset.dx, offset.dy, _tableWidth, _rowTops.last);
      final Iterable<double> rows = _rowTops.getRange(1, _rowTops.length - 1);
      final Iterable<double> columns = _columnLefts!.skip(1);
      border!.paint(context.canvas, borderRect, rows: rows, columns: columns);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TableBorder>('border', border, defaultValue: null));
    properties.add(DiagnosticsProperty<Map<int, TableColumnWidth>>('specified column widths', _columnWidths, level: _columnWidths.isEmpty ? DiagnosticLevel.hidden : DiagnosticLevel.info));
    properties.add(DiagnosticsProperty<TableColumnWidth>('default column width', defaultColumnWidth));
    properties.add(MessageProperty('table size', '$columns\u00D7$rows'));
    properties.add(IterableProperty<String>('column offsets', _columnLefts?.map(debugFormatDouble), ifNull: 'unknown'));
    properties.add(IterableProperty<String>('row offsets', _rowTops.map(debugFormatDouble), ifNull: 'unknown'));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    if (_children.isEmpty) {
      return <DiagnosticsNode>[DiagnosticsNode.message('table is empty')];
    }

    final List<DiagnosticsNode> children = <DiagnosticsNode>[];
    for (int y = 0; y < rows; y += 1) {
      for (int x = 0; x < columns; x += 1) {
        final int xy = x + y * columns;
        final RenderBox? child = _children[xy];
        final String name = 'child ($x, $y)';
        if (child != null) {
          children.add(child.toDiagnosticsNode(name: name));
        } else {
          children.add(DiagnosticsProperty<Object>(name, null, ifNull: 'is null', showSeparator: false));
        }
      }
    }
    return children;
  }
}