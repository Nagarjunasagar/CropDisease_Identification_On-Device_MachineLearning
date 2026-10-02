import 'package:flutter/material.dart';

import '../inference/prediction.dart';

/// Horizontal probability bar with label and percentage.
class ScoreBar extends StatelessWidget {
  const ScoreBar({
    super.key,
    required this.label,
    required this.probability,
    this.emphasis = false,
  });

  final String label;
  final double probability;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label ${(probability * 100).round()} percent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: emphasis ? text.titleSmall : text.bodyMedium,
                  ),
                ),
                Text(
                  '${(probability * 100).toStringAsFixed(probability < 0.1 ? 1 : 0)}%',
                  style: text.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: probability.clamp(0, 1),
                minHeight: emphasis ? 10 : 6,
                backgroundColor: scheme.surfaceContainerHighest,
                color: emphasis ? scheme.primary : scheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon + colour per result kind; never colour alone.
({IconData icon, Color color}) resultStyle(
  BuildContext context, {
  required bool healthy,
  required Certainty certainty,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (certainty == Certainty.uncertain) {
    return (icon: Icons.help_outline, color: scheme.outline);
  }
  return healthy
      ? (icon: Icons.check_circle_outline, color: scheme.primary)
      : (icon: Icons.warning_amber_rounded, color: scheme.error);
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class BulletList extends StatelessWidget {
  const BulletList(this.items, {super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}
