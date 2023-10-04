bool nearEqual(double? a, double? b, double epsilon) {
  assert(epsilon >= 0.0);
  if (a == null || b == null) {
    return a == b;
  }
  return (a > (b - epsilon)) && (a < (b + epsilon)) || a == b;
}

bool nearZero(double a, double epsilon) => nearEqual(a, 0.0, epsilon);
