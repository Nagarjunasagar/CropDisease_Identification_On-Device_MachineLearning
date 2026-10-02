import 'dart:math' as math;

/// One class score.
class ClassScore {
  const ClassScore(this.label, this.probability);

  final String label;
  final double probability;

  Map<String, Object> toJson() => {'label': label, 'p': probability};

  factory ClassScore.fromJson(Map<String, Object?> json) =>
      ClassScore(json['label']! as String, (json['p']! as num).toDouble());
}

enum Certainty { confident, uncertain }

/// Result of classifying one photo.
class Prediction {
  Prediction({required this.scores, required this.inferenceMs});

  /// Sorted, highest probability first.
  final List<ClassScore> scores;
  final int inferenceMs;

  /// Below this top-1 probability the app asks for a better photo.
  static const double minConfidence = 0.55;

  /// ...or when the top two classes are this close.
  static const double minMargin = 0.15;

  ClassScore get top => scores.first;

  List<ClassScore> topK(int k) => scores.take(k).toList();

  Certainty get certainty {
    final second = scores.length > 1 ? scores[1].probability : 0.0;
    if (top.probability < minConfidence ||
        top.probability - second < minMargin) {
      return Certainty.uncertain;
    }
    return Certainty.confident;
  }

  /// Builds a prediction from raw model output (probabilities in label order).
  factory Prediction.fromProbabilities(
    List<double> probs,
    List<String> labels, {
    int inferenceMs = 0,
  }) {
    if (probs.length != labels.length) {
      throw ArgumentError(
        'model produced ${probs.length} scores for ${labels.length} labels',
      );
    }
    // The model ends in softmax, but re-normalise defensively (quantised
    // outputs may not sum to exactly 1).
    final sum = probs.fold<double>(0, (a, b) => a + math.max(b, 0));
    final scores = [
      for (var i = 0; i < probs.length; i++)
        ClassScore(labels[i], sum > 0 ? math.max(probs[i], 0) / sum : 0),
    ]..sort((a, b) => b.probability.compareTo(a.probability));
    return Prediction(scores: scores, inferenceMs: inferenceMs);
  }
}
