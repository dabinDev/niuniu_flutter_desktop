import 'package:flutter/material.dart';

import '../data/market_api_repository.dart';

class FeedSectionCard extends StatelessWidget {
  const FeedSectionCard({
    super.key,
    required this.title,
    required this.items,
    this.caption,
  });

  final String title;
  final List<FeedItemData> items;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(caption!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            if (items.isEmpty)
              Text('No data yet.', style: Theme.of(context).textTheme.bodyLarge)
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 16,
                            ),
                      ),
                      if ((item.subtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          if ((item.group ?? '').isNotEmpty)
                            _MetaChip(text: item.group!),
                          if ((item.time ?? '').isNotEmpty)
                            _MetaChip(text: item.time!),
                          if ((item.extra ?? '').isNotEmpty)
                            _MetaChip(text: item.extra!),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x140E5A46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
