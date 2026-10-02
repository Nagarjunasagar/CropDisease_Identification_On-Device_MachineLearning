import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/widgets.dart';
import '../../providers.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classifier = ref.watch(classifierProvider).valueOrNull;
    final catalog = ref.watch(diseaseCatalogProvider).valueOrNull;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'How it works',
            icon: Icons.memory,
            child: Text(
              'A MobileNetV2 neural network, fine-tuned on tomato leaf images and '
              'quantised for phones, runs entirely on this device with LiteRT '
              '(TensorFlow Lite). No photo is uploaded.',
              style: text.bodyMedium,
            ),
          ),
          SectionCard(
            title: 'Recognised classes',
            icon: Icons.list_alt,
            child: BulletList([
              for (final id in classifier?.labels ?? catalog?.ids ?? const <String>[])
                catalog?[id].name ?? id,
            ]),
          ),
          SectionCard(
            title: 'Limitations',
            icon: Icons.report_outlined,
            child: const BulletList([
              'Trained mostly on close-up photos of single leaves. Busy '
                  'backgrounds, whole plants or fruit reduce accuracy.',
              'Only tomato leaves are supported. Other plants will still get a '
                  '(meaningless) answer, which is why low-confidence results '
                  'are marked "Not sure".',
              'Several diseases can look alike. Treat the result as a first '
                  'opinion, not a diagnosis.',
            ]),
          ),
          if (catalog != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(catalog.disclaimer, style: text.bodySmall),
            ),
          if (classifier != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Model: ${classifier.modelName} · input ${classifier.inputSize}px · '
                '${classifier.labels.length} classes',
                style: text.labelSmall,
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'CroHeal',
                applicationVersion: '2.0.0',
              ),
              child: const Text('Open-source licences'),
            ),
          ),
        ],
      ),
    );
  }
}
