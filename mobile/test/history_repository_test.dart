import 'dart:io';
import 'dart:typed_data';

import 'package:croheal/src/data/history_repository.dart';
import 'package:croheal/src/inference/prediction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('croheal_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Prediction pred(String top) =>
      Prediction.fromProbabilities([0.9, 0.1], [top, 'other'], inferenceMs: 7);

  test('add, reload, delete, clear', () async {
    final repo = HistoryRepository(Directory('${tmp.path}/scans'));
    expect(await repo.load(), isEmpty);

    final a = await repo.add(pred('early_blight'), Uint8List.fromList([1, 2, 3]));
    final b = await repo.add(pred('healthy'), Uint8List.fromList([4, 5]));
    var all = await repo.load();
    expect(all.map((r) => r.id), [b.id, a.id]); // newest first
    expect(all.first.prediction.top.label, 'healthy');
    expect(all.first.inferenceMs, 7);
    expect(repo.imageFor(a).existsSync(), isTrue);

    await repo.delete(a.id);
    all = await repo.load();
    expect(all.map((r) => r.id), [b.id]);
    expect(repo.imageFor(a).existsSync(), isFalse);

    await repo.clear();
    expect(await repo.load(), isEmpty);
  });

  test('keeps at most maxRecords', () async {
    final repo = HistoryRepository(Directory('${tmp.path}/scans'), maxRecords: 2);
    for (var i = 0; i < 4; i++) {
      await repo.add(pred('c$i'), Uint8List(1));
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final all = await repo.load();
    expect(all.map((r) => r.prediction.top.label), ['c3', 'c2']);
    expect(Directory('${tmp.path}/scans').listSync().whereType<File>()
        .where((f) => f.path.endsWith('.jpg')), hasLength(2));
  });

  test('corrupt index does not crash', () async {
    final dir = Directory('${tmp.path}/scans')..createSync();
    File('${dir.path}/index.json').writeAsStringSync('{not json');
    expect(await HistoryRepository(dir).load(), isEmpty);
  });
}
