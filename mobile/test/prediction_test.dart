import 'package:croheal/src/inference/prediction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labels = ['a', 'b', 'c'];

  test('scores are sorted and normalised', () {
    final p = Prediction.fromProbabilities([0.1, 0.7, 0.2], labels);
    expect(p.top.label, 'b');
    expect(p.scores.map((s) => s.label), ['b', 'c', 'a']);
    expect(p.scores.fold<double>(0, (a, s) => a + s.probability), closeTo(1, 1e-9));
  });

  test('quantised outputs that do not sum to 1 are re-normalised', () {
    final p = Prediction.fromProbabilities([0.0, 0.8, 0.4], labels);
    expect(p.top.probability, closeTo(0.8 / 1.2, 1e-9));
  });

  test('confident vs uncertain', () {
    expect(Prediction.fromProbabilities([0.05, 0.9, 0.05], labels).certainty,
        Certainty.confident);
    // low top-1
    expect(Prediction.fromProbabilities([0.3, 0.4, 0.3], labels).certainty,
        Certainty.uncertain);
    // high top-1 but top-2 too close
    expect(Prediction.fromProbabilities([0.0, 0.56, 0.44], labels).certainty,
        Certainty.uncertain);
  });

  test('label/output mismatch throws', () {
    expect(() => Prediction.fromProbabilities([1, 0], labels), throwsArgumentError);
  });

  test('ClassScore json round trip', () {
    final s = ClassScore.fromJson(const ClassScore('x', 0.25).toJson());
    expect((s.label, s.probability), ('x', 0.25));
  });
}
