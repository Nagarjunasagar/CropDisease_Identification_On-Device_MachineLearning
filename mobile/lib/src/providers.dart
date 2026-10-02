import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'data/disease_catalog.dart';
import 'data/history_repository.dart';
import 'inference/classifier.dart';
import 'inference/prediction.dart';
import 'inference/preprocess.dart';

/// The on-device model. Overridden with a fake in widget tests.
final classifierProvider = FutureProvider<DiseaseClassifier>((ref) async {
  final classifier = await LiteRtClassifier.load();
  ref.onDispose(classifier.close);
  return classifier;
});

final diseaseCatalogProvider = FutureProvider<DiseaseCatalog>((ref) async {
  return DiseaseCatalog.parse(
    await rootBundle.loadString('assets/models/disease_info.json'),
  );
});

final historyRepositoryProvider = FutureProvider<HistoryRepository>((ref) async {
  final docs = await getApplicationDocumentsDirectory();
  return HistoryRepository(Directory('${docs.path}/scans'));
});

class HistoryNotifier extends AsyncNotifier<List<ScanRecord>> {
  @override
  Future<List<ScanRecord>> build() async {
    final repo = await ref.watch(historyRepositoryProvider.future);
    return repo.load();
  }

  Future<ScanRecord> add(Prediction prediction, Uint8List photo) async {
    final repo = await ref.read(historyRepositoryProvider.future);
    final preview = await Isolate.run(() => thumbnailJpeg(photo, size: 512));
    final record = await repo.add(prediction, preview);
    state = AsyncData([record, ...state.valueOrNull ?? []]);
    return record;
  }

  Future<void> delete(String id) async {
    final repo = await ref.read(historyRepositoryProvider.future);
    await repo.delete(id);
    state = AsyncData([...?state.valueOrNull?.where((r) => r.id != id)]);
  }

  Future<void> clear() async {
    final repo = await ref.read(historyRepositoryProvider.future);
    await repo.clear();
    state = const AsyncData([]);
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<ScanRecord>>(HistoryNotifier.new);
