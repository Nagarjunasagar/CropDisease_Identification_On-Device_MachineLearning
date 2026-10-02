import 'dart:io';

import 'package:croheal/src/data/disease_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against the model, labels and disease guide drifting apart.
void main() {
  final labels = File('assets/models/labels.txt')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toList();

  test('bundled model exists', () {
    expect(File('assets/models/crop_disease.tflite').lengthSync(), greaterThan(100000));
  });

  test('every label has disease guidance', () {
    final catalog =
        DiseaseCatalog.parse(File('assets/models/disease_info.json').readAsStringSync());
    expect(labels, hasLength(10));
    for (final id in labels) {
      expect(catalog.ids, contains(id));
      expect(catalog[id].management, isNotEmpty, reason: id);
    }
  });
}
