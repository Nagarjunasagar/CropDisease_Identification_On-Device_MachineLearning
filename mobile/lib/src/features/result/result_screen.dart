import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/widgets.dart';
import '../../data/history_repository.dart';
import '../../inference/prediction.dart';
import '../../providers.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.record, this.photoBytes});

  final ScanRecord record;

  /// Original photo when coming straight from a scan; otherwise the stored
  /// preview is loaded from history.
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(diseaseCatalogProvider).valueOrNull;
    final repo = ref.watch(historyRepositoryProvider).valueOrNull;
    final prediction = record.prediction;
    final top = prediction.top;
    final info = catalog?[top.label];
    final certainty = prediction.certainty;
    final style = resultStyle(
      context,
      healthy: info?.isHealthy ?? false,
      certainty: certainty,
    );
    final text = Theme.of(context).textTheme;

    final Widget image = photoBytes != null
        ? Image.memory(photoBytes!, fit: BoxFit.cover)
        : repo != null
            ? Image.file(repo.imageFor(record), fit: BoxFit.cover)
            : const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(aspectRatio: 1, child: image),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(style.icon, color: style.color, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          certainty == Certainty.uncertain
                              ? 'Not sure'
                              : info?.name ?? top.label,
                          style: text.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (certainty == Certainty.uncertain)
                    Text(
                      'The model is not confident about this photo. Retake it '
                      'closer, in daylight, with a single leaf filling the frame. '
                      'The closest matches are shown below.',
                      style: text.bodyMedium,
                    )
                  else if (info != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(label: Text(info.type), visualDensity: VisualDensity.compact),
                        if (!info.isHealthy)
                          Chip(
                            label: Text(info.cause, overflow: TextOverflow.ellipsis),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  for (final (i, s) in prediction.topK(3).indexed)
                    ScoreBar(
                      label: catalog?[s.label].name ?? s.label,
                      probability: s.probability,
                      emphasis: i == 0,
                    ),
                ],
              ),
            ),
          ),
          if (info != null && certainty == Certainty.confident) ...[
            if (info.symptoms.isNotEmpty)
              SectionCard(
                title: info.isHealthy ? 'What healthy looks like' : 'Symptoms',
                icon: Icons.search,
                child: BulletList(info.symptoms),
              ),
            if (info.management.isNotEmpty)
              SectionCard(
                title: info.isHealthy ? 'Keep it healthy' : 'What to do',
                icon: Icons.healing_outlined,
                child: BulletList(info.management),
              ),
          ],
          if (catalog != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                catalog.disclaimer,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Text(
            'Analysed on-device in ${record.inferenceMs} ms',
            style: text.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Opens a history entry; kept here so the history list stays small.
void openRecord(BuildContext context, ScanRecord record) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ResultScreen(record: record)),
  );
}

