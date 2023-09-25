double findPercentile(List<double> doubles, double p) {
  assert(doubles.isNotEmpty);
  doubles.sort();
  return doubles[((doubles.length - 1) * (p / 100)).round()];
}