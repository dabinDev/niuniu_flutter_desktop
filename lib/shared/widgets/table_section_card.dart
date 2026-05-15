import 'package:flutter/material.dart';

import '../data/market_api_repository.dart';

class TableSectionCard extends StatelessWidget {
  const TableSectionCard({
    super.key,
    required this.section,
    this.caption,
  });

  final TableSectionData section;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: Theme.of(context).textTheme.titleLarge),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(caption!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            if (section.rows.isEmpty)
              Text('No data yet.', style: Theme.of(context).textTheme.bodyLarge)
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: section.columns
                      .map((column) => DataColumn(label: Text(column)))
                      .toList(growable: false),
                  rows: section.rows
                      .map(
                        (row) => DataRow(
                          cells: row
                              .map((cell) => DataCell(Text(cell)))
                              .toList(growable: false),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
