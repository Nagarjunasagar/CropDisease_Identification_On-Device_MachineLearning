import 'dart:async';
import 'dart:typed_data';

import 'package:croheal/main.dart';
import 'package:croheal/src/inference/classifier.dart';
import 'package:croheal/src/inference/prediction.dart';
import 'package:croheal/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClassifier implements DiseaseClassifier {
  @override
  List<String> get labels => const ['healthy', 'early_blight'];
  @override
  int get inputSize => 224;
  @override
  String get modelName => 'fake.tflite';
  @override
  Future<Prediction> classify(Uint8List encodedImage) async =>
      Prediction.fromProbabilities([0.9, 0.1], labels);
  @override
  void close() {}
}

void main() {
  testWidgets('home screen enables scanning once the model is ready', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [classifierProvider.overrideWith((ref) async => FakeClassifier())],
        child: const CroHealApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tomato leaf check'), findsOneWidget);
    final camera = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('Take a photo'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    );
    expect(camera.onPressed, isNotNull);
  });

  testWidgets('buttons are disabled while the model loads', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classifierProvider.overrideWith(
            (ref) => Completer<DiseaseClassifier>().future, // never completes
          ),
        ],
        child: const CroHealApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Loading model…'), findsOneWidget);
    final camera = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('Take a photo'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    );
    expect(camera.onPressed, isNull);
  });
}
