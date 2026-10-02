import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../inference/prediction.dart';

/// One saved scan. Everything stays on the device.
class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.timestamp,
    required this.imageFile,
    required this.scores,
    required this.inferenceMs,
  });

  final String id;
  final DateTime timestamp;

  /// File name of the stored preview image inside the history directory.
  final String imageFile;
  final List<ClassScore> scores;
  final int inferenceMs;

  Prediction get prediction => Prediction(scores: scores, inferenceMs: inferenceMs);

  Map<String, Object> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'image': imageFile,
        'scores': [for (final s in scores) s.toJson()],
        'ms': inferenceMs,
      };

  factory ScanRecord.fromJson(Map<String, Object?> json) => ScanRecord(
        id: json['id']! as String,
        timestamp: DateTime.parse(json['timestamp']! as String),
        imageFile: json['image']! as String,
        scores: [
          for (final s in json['scores']! as List<Object?>)
            ClassScore.fromJson(s! as Map<String, Object?>),
        ],
        inferenceMs: (json['ms'] as num?)?.toInt() ?? 0,
      );
}

/// Stores scans as preview JPEGs plus a JSON index in [directory].
class HistoryRepository {
  HistoryRepository(this.directory, {this.maxRecords = 200});

  final Directory directory;
  final int maxRecords;

  File get _index => File('${directory.path}/index.json');

  File imageFor(ScanRecord r) => File('${directory.path}/${r.imageFile}');

  Future<List<ScanRecord>> load() async {
    if (!await _index.exists()) return [];
    try {
      final list = jsonDecode(await _index.readAsString()) as List<Object?>;
      return [
        for (final e in list) ScanRecord.fromJson(e! as Map<String, Object?>),
      ];
    } on FormatException {
      return []; // corrupt index: start fresh rather than crash
    }
  }

  Future<ScanRecord> add(Prediction prediction, Uint8List previewJpeg) async {
    await directory.create(recursive: true);
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final record = ScanRecord(
      id: id,
      timestamp: now,
      imageFile: '$id.jpg',
      scores: prediction.topK(5),
      inferenceMs: prediction.inferenceMs,
    );
    await imageFor(record).writeAsBytes(previewJpeg, flush: true);

    final records = [record, ...await load()];
    for (final old in records.skip(maxRecords)) {
      await _deleteFile(imageFor(old));
    }
    await _save(records.take(maxRecords).toList());
    return record;
  }

  Future<void> delete(String id) async {
    final records = await load();
    for (final r in records.where((r) => r.id == id)) {
      await _deleteFile(imageFor(r));
    }
    await _save(records.where((r) => r.id != id).toList());
  }

  Future<void> clear() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> _save(List<ScanRecord> records) async {
    await directory.create(recursive: true);
    final tmp = File('${_index.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final r in records) r.toJson()]));
    await tmp.rename(_index.path); // atomic replace
  }

  static Future<void> _deleteFile(File f) async {
    if (await f.exists()) await f.delete();
  }
}
