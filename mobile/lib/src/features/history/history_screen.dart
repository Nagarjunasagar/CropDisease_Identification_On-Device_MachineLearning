import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/widgets.dart';
import '../../providers.dart';
import '../result/result_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all scans?'),
        content: const Text('Photos and results are removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete all')),
        ],
      ),
    );
    if (ok ?? false) await ref.read(historyProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final catalog = ref.watch(diseaseCatalogProvider).valueOrNull;
    final repo = ref.watch(historyRepositoryProvider).valueOrNull;
    final loc = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (history.valueOrNull?.isNotEmpty ?? false)
            IconButton(
              tooltip: 'Delete all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load history.')),
        data: (records) {
          if (records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No scans yet. Results you take are saved here, on this phone only.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = records[i];
              final p = r.prediction;
              final info = catalog?[p.top.label];
              final style = resultStyle(
                context,
                healthy: info?.isHealthy ?? false,
                certainty: p.certainty,
              );
              return Dismissible(
                key: ValueKey(r.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => ref.read(historyProvider.notifier).delete(r.id),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(
                      dimension: 52,
                      child: repo == null
                          ? const ColoredBox(color: Colors.black12)
                          : Image.file(
                              repo.imageFor(r),
                              fit: BoxFit.cover,
                              cacheWidth: 156,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                    ),
                  ),
                  title: Text(info?.name ?? p.top.label),
                  subtitle: Text(
                    '${loc.formatMediumDate(r.timestamp)} · '
                    '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(r.timestamp))} · '
                    '${(p.top.probability * 100).round()}%',
                  ),
                  trailing: Icon(style.icon, color: style.color),
                  onTap: () => openRecord(context, r),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
