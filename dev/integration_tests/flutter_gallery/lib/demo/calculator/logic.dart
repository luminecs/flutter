class ExpressionToken {
  ExpressionToken(this.stringRep);

  final String? stringRep;

  @override
  String toString() => stringRep!;
}

class NumberToken extends ExpressionToken {
  NumberToken(String super.stringRep, this.number);

  NumberToken.fromNumber(num number) : this('$number', number);

  final num number;
}

class IntToken extends NumberToken {
  IntToken(String stringRep) : super(stringRep, int.parse(stringRep));
}

class FloatToken extends NumberToken {
  FloatToken(String stringRep) : super(stringRep, _parse(stringRep));

  static double _parse(String stringRep) {
    String toParse = stringRep;
    if (toParse.startsWith('.')) {
      toParse = '0$toParse';
    }
    if (toParse.endsWith('.')) {
      toParse = '${toParse}0';
    }
    return double.parse(toParse);
  }
}

class ResultToken extends NumberToken {
  ResultToken(num number) : super.fromNumber(round(number));

  static num round(num number) {
    if (number is int) {
      return number;
    }
    return double.parse(number.toStringAsPrecision(14));
  }
}

class LeadingNegToken extends ExpressionToken {
  LeadingNegToken() : super('-');
}

enum Operation { Addition, Subtraction, Multiplication, Division }

class OperationToken extends ExpressionToken {
  OperationToken(this.operation)
   : super(opString(operation));

  Operation operation;

  static String? opString(Operation operation) {
    switch (operation) {
      case Operation.Addition:
        return ' + ';
      case Operation.Subtraction:
        return ' - ';
      case Operation.Multiplication:
        return '  \u00D7  ';
      case Operation.Division:
        return '  \u00F7  ';
    }
  }
}

enum ExpressionState {
  Start,

  LeadingNeg,

  Number,

  Point,

  NumberWithPoint,

  Result,
}

class CalcExpression {
  CalcExpression(this._list, this.state);

  CalcExpression.empty()
    : this(<ExpressionToken>[], ExpressionState.Start);

  CalcExpression.result(FloatToken result)
    : _list = <ExpressionToken?>[],
      state = ExpressionState.Result {
    _list.add(result);
  }

  final List<ExpressionToken?> _list;
  final ExpressionState state;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeAll(_list);
    return buffer.toString();
  }

  CalcExpression? appendDigit(int digit) {
    ExpressionState newState = ExpressionState.Number;
    ExpressionToken? newToken;
    final List<ExpressionToken?> outList = _list.toList();
    switch (state) {
      case ExpressionState.Start:
        // Start a new number with digit.
        newToken = IntToken('$digit');
      case ExpressionState.LeadingNeg:
        // Replace the leading neg with a negative number starting with digit.
        outList.removeLast();
        newToken = IntToken('-$digit');
      case ExpressionState.Number:
        final ExpressionToken last = outList.removeLast()!;
        newToken = IntToken('${last.stringRep}$digit');
      case ExpressionState.Point:
      case ExpressionState.NumberWithPoint:
        final ExpressionToken last = outList.removeLast()!;
        newState = ExpressionState.NumberWithPoint;
        newToken = FloatToken('${last.stringRep}$digit');
      case ExpressionState.Result:
        // Cannot enter a number now
        return null;
    }
    outList.add(newToken);
    return CalcExpression(outList, newState);
  }

  CalcExpression? appendPoint() {
    ExpressionToken? newToken;
    final List<ExpressionToken?> outList = _list.toList();
    switch (state) {
      case ExpressionState.Start:
        newToken = FloatToken('.');
      case ExpressionState.LeadingNeg:
      case ExpressionState.Number:
        final ExpressionToken last = outList.removeLast()!;
        final String value = last.stringRep!;
        newToken = FloatToken('$value.');
      case ExpressionState.Point:
      case ExpressionState.NumberWithPoint:
      case ExpressionState.Result:
        // Cannot enter a point now
        return null;
    }
    outList.add(newToken);
    return CalcExpression(outList, ExpressionState.Point);
  }

  CalcExpression? appendOperation(Operation op) {
    switch (state) {
      case ExpressionState.Start:
      case ExpressionState.LeadingNeg:
      case ExpressionState.Point:
        // Cannot enter operation now.
        return null;
      case ExpressionState.Number:
      case ExpressionState.NumberWithPoint:
      case ExpressionState.Result:
        break;
    }
    final List<ExpressionToken?> outList = _list.toList();
    outList.add(OperationToken(op));
    return CalcExpression(outList, ExpressionState.Start);
  }

  CalcExpression? appendLeadingNeg() {
    switch (state) {
      case ExpressionState.Start:
        break;
      case ExpressionState.LeadingNeg:
      case ExpressionState.Point:
      case ExpressionState.Number:
      case ExpressionState.NumberWithPoint:
      case ExpressionState.Result:
        // Cannot enter leading neg now.
        return null;
    }
    final List<ExpressionToken?> outList = _list.toList();
    outList.add(LeadingNegToken());
    return CalcExpression(outList, ExpressionState.LeadingNeg);
  }

  CalcExpression? appendMinus() {
    switch (state) {
      case ExpressionState.Start:
        return appendLeadingNeg();
      case ExpressionState.LeadingNeg:
      case ExpressionState.Point:
      case ExpressionState.Number:
      case ExpressionState.NumberWithPoint:
      case ExpressionState.Result:
        return appendOperation(Operation.Subtraction);
    }
  }

  CalcExpression? computeResult() {
    switch (state) {
      case ExpressionState.Start:
      case ExpressionState.LeadingNeg:
      case ExpressionState.Point:
      case ExpressionState.Result:
        // Cannot compute result now.
        return null;
      case ExpressionState.Number:
      case ExpressionState.NumberWithPoint:
        break;
    }

    // We make a copy of _list because CalcExpressions are supposed to
    // be immutable.
    final List<ExpressionToken?> list = _list.toList();
    // We obey order-of-operations by computing the sum of the 'terms',
    // where a "term" is defined to be a sequence of numbers separated by
    // multiplication or division symbols.
    num currentTermValue = removeNextTerm(list);
    while (list.isNotEmpty) {
      final OperationToken opToken = list.removeAt(0)! as OperationToken;
      final num nextTermValue = removeNextTerm(list);
      switch (opToken.operation) {
        case Operation.Addition:
          currentTermValue += nextTermValue;
        case Operation.Subtraction:
          currentTermValue -= nextTermValue;
        case Operation.Multiplication:
        case Operation.Division:
          // Logic error.
          assert(false);
      }
    }
    final List<ExpressionToken> outList = <ExpressionToken>[
      ResultToken(currentTermValue),
    ];
    return CalcExpression(outList, ExpressionState.Result);
  }

  static num removeNextTerm(List<ExpressionToken?> list) {
    assert(list.isNotEmpty);
    final NumberToken firstNumToken = list.removeAt(0)! as NumberToken;
    num currentValue = firstNumToken.number;
    while (list.isNotEmpty) {
      bool isDivision = false;
      final OperationToken nextOpToken = list.first! as OperationToken;
      switch (nextOpToken.operation) {
        case Operation.Addition:
        case Operation.Subtraction:
          // We have reached the end of the current term
          return currentValue;
        case Operation.Multiplication:
          break;
        case Operation.Division:
          isDivision = true;
      }
      // Remove the operation token.
      list.removeAt(0);
      // Remove the next number token.
      final NumberToken nextNumToken = list.removeAt(0)! as NumberToken;
      final num nextNumber = nextNumToken.number;
      if (isDivision) {
        currentValue /= nextNumber;
      } else {
        currentValue *= nextNumber;
      }
    }
    return currentValue;
  }
}