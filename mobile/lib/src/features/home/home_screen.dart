import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers.dart';
import '../about/about_screen.dart';
import '../history/history_screen.dart';
import '../result/result_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.picker});

  /// Injectable for tests.
  final ImagePicker? picker;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  bool _working = false;

  Future<void> _scan(ImageSource source) async {
    final classifier = ref.read(classifierProvider).valueOrNull;
    if (classifier == null || _working) return;

    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: 1600, // plenty for a 224 px model; keeps decode fast
        maxHeight: 1600,
        imageQuality: 92,
      );
    } catch (e) {
      _showError('Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}.');
      return;
    }
    if (file == null) return; // user cancelled

    setState(() => _working = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      final prediction = await classifier.classify(bytes);
      final record = await ref.read(historyProvider.notifier).add(prediction, bytes);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(record: record, photoBytes: bytes),
        ),
      );
    } on FormatException {
      _showError('That file is not an image we can read.');
    } catch (e) {
      _showError('Something went wrong while analysing the photo.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(classifierProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ready = model.hasValue && !_working;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CroHeal'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.eco, size: 56, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'Tomato leaf check',
              style: text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Photograph one leaf to identify 9 common diseases and pests. '
              'Works offline: your photos never leave the phone.',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: ready ? () => _scan(ImageSource.camera) : null,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take a photo'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: ready ? () => _scan(ImageSource.gallery) : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from gallery'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            ),
            const SizedBox(height: 16),
            _StatusLine(
              loading: model.isLoading,
              error: model.hasError,
              working: _working,
            ),
            const SizedBox(height: 16),
            const _TipsCard(),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.loading,
    required this.error,
    required this.working,
  });

  final bool loading;
  final bool error;
  final bool working;

  @override
  Widget build(BuildContext context) {
    if (error) {
      return Text(
        'The model could not be loaded. Please reinstall the app.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    if (loading || working) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(loading ? 'Loading model…' : 'Analysing leaf…'),
        ],
      );
    }
    return const SizedBox(height: 18);
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For the best result', style: text.titleMedium),
            const SizedBox(height: 8),
            for (final (icon, tip) in const [
              (Icons.crop_free, 'Fill the frame with a single leaf'),
              (Icons.wb_sunny_outlined, 'Use daylight and avoid harsh shadows'),
              (Icons.center_focus_strong_outlined, 'Hold steady so the spots are sharp'),
              (Icons.flip_outlined, 'Photograph the side that shows symptoms'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
