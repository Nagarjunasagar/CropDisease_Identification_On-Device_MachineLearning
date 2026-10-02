import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'prediction.dart';
import 'preprocess.dart';

/// Abstraction over the on-device model so screens can be tested with a fake.
abstract class DiseaseClassifier {
  List<String> get labels;
  int get inputSize;
  String get modelName;

  /// Classifies an encoded image (JPEG/PNG bytes).
  Future<Prediction> classify(Uint8List encodedImage);

  void close();
}

/// LiteRT (TensorFlow Lite) implementation.
///
/// Decoding, preprocessing and inference all run in a short-lived background
/// isolate, so the UI thread never blocks on a 12 MP photo decode.
class LiteRtClassifier implements DiseaseClassifier {
  LiteRtClassifier._(this._interpreter, this.labels, this.inputSize, this.modelName);

  static const defaultModel = 'assets/models/crop_disease.tflite';
  static const defaultLabels = 'assets/models/labels.txt';

  final Interpreter _interpreter;
  bool _busy = false;

  @override
  final List<String> labels;
  @override
  final int inputSize;
  @override
  final String modelName;

  static Future<LiteRtClassifier> load({
    String modelAsset = defaultModel,
    String labelsAsset = defaultLabels,
    int threads = 4,
  }) async {
    final options = InterpreterOptions()..threads = threads;
    final interpreter = await Interpreter.fromAsset(modelAsset, options: options);
    final labels = (await rootBundle.loadString(labelsAsset))
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final inShape = interpreter.getInputTensor(0).shape; // [1, H, W, 3]
    final outShape = interpreter.getOutputTensor(0).shape; // [1, classes]
    if (inShape.length != 4 || inShape[1] != inShape[2] || inShape[3] != 3) {
      throw StateError('unexpected model input shape $inShape');
    }
    if (outShape.last != labels.length) {
      throw StateError(
        'model has ${outShape.last} outputs but labels.txt has ${labels.length}',
      );
    }
    return LiteRtClassifier._(
      interpreter,
      labels,
      inShape[1],
      modelAsset.split('/').last,
    );
  }

  @override
  Future<Prediction> classify(Uint8List encodedImage) async {
    if (_busy) throw StateError('classifier is busy');
    _busy = true;
    try {
      // Capture only sendable primitives for the isolate.
      final address = _interpreter.address;
      final size = inputSize;
      final classes = labels.length;

      final (probs, ms) = await Isolate.run(() {
        final input = preprocessBytes(encodedImage, size);
        final interpreter = Interpreter.fromAddress(address);
        final output = [List<double>.filled(classes, 0)];
        final sw = Stopwatch()..start();
        interpreter.run(input.buffer.asUint8List(), output);
        return (output.first, sw.elapsedMilliseconds);
      });
      return Prediction.fromProbabilities(probs, labels, inferenceMs: ms);
    } finally {
      _busy = false;
    }
  }

  @override
  void close() => _interpreter.close();
}
