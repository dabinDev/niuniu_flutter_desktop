import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../data/market_api_repository.dart';

class WeaknessSectionPanel extends StatelessWidget {
  const WeaknessSectionPanel({
    super.key,
    required this.section,
    required this.onOpenStock,
    required this.keyPrefix,
    this.emptyMessage = '当前分组暂无数据。',
    this.highlighted = false,
    this.highlightLabel,
  });

  final YesterdayStatsSectionData section;
  final ValueChanged<String> onOpenStock;
  final String keyPrefix;
  final String emptyMessage;
  final bool highlighted;
  final String? highlightLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = weaknessSectionAccent(section.key);
    final title = weaknessSectionTitle(section);

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 8,
        color: theme.colorScheme.surface,
        borderColor: highlighted
            ? accent.withValues(alpha: 0.36)
            : theme.colorScheme.outlineVariant,
        elevated: highlighted,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(
                  color: accent.withValues(alpha: 0.18),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '显示 ${section.items.length} 条 / 共 ${section.total} 条',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (highlighted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      highlightLabel ?? '当前定位',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Text(
                    '${section.total}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: section.items.isEmpty
                  ? Center(
                      child: Text(
                        emptyMessage,
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final minWidth = constraints.maxWidth < 560
                            ? 560.0
                            : constraints.maxWidth;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: minWidth,
                                  ),
                                  child: DataTable(
                                    showCheckboxColumn: false,
                                    headingRowColor: WidgetStateProperty.all(
                                      accent.withValues(alpha: 0.08),
                                    ),
                                    headingTextStyle:
                                        theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.78),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    dataRowMinHeight: 34,
                                    dataRowMaxHeight: 40,
                                    horizontalMargin: 10,
                                    columnSpacing: 10,
                                    columns: const [
                                      DataColumn(label: Text('股票')),
                                      DataColumn(label: Text('现价')),
                                      DataColumn(label: Text('开盘涨幅')),
                                      DataColumn(label: Text('现涨幅')),
                                      DataColumn(label: Text('成交额')),
                                      DataColumn(label: Text('地区')),
                                      DataColumn(label: Text('行业')),
                                    ],
                                    rows: section.items
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final item = entry.value;
                                      return DataRow.byIndex(
                                        index: index,
                                        color: WidgetStateProperty.resolveWith(
                                          (states) {
                                            if (states.contains(
                                                WidgetState.hovered)) {
                                              return accent.withValues(
                                                  alpha: 0.05);
                                            }
                                            return index.isEven
                                                ? theme.colorScheme.surface
                                                : AppTheme.surfaceSoft
                                                    .withValues(alpha: 0.62);
                                          },
                                        ),
                                        cells: _buildWeaknessCells(
                                          context,
                                          item,
                                          onOpenStock,
                                          keyPrefix: keyPrefix,
                                        ),
                                      );
                                    }).toList(growable: false),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

List<DataCell> _buildWeaknessCells(
  BuildContext context,
  YesterdayStatsItemData item,
  ValueChanged<String> onOpenStock, {
  required String keyPrefix,
}) {
  final theme = Theme.of(context);
  final canOpen = RegExp(r'^\d{6}$').hasMatch(item.code);
  final marketTag = item.marketTag;
  final stockColor =
      canOpen ? theme.colorScheme.primary : theme.colorScheme.onSurface;

  Widget stockChild = SizedBox(
    height: 32,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (marketTag != null) ...[
            _WeaknessMarketBadge(label: marketTag),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: stockColor,
                ),
                children: [
                  TextSpan(
                    text: item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: canOpen ? TextDecoration.underline : null,
                      decorationColor: stockColor,
                    ),
                  ),
                  TextSpan(
                    text: ' ${item.code}',
                    style: TextStyle(
                      color: stockColor.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  if (canOpen) {
    stockChild = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: '打开个股 ${item.code}',
        child: DefaultTextStyle(
          key: ValueKey('$keyPrefix-open-${item.code}'),
          style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ) ??
              const TextStyle(),
          child: stockChild,
        ),
      ),
    );
  }

  Text valueText(
    String value, {
    double? change,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Text(
      value,
      textAlign: textAlign,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: _changeColor(change, theme),
        fontWeight: change == null ? FontWeight.w500 : FontWeight.w700,
      ),
    );
  }

  return [
    DataCell(
      stockChild,
      onTap: canOpen ? () => onOpenStock(item.code) : null,
    ),
    DataCell(valueText(_fmtDouble(item.price))),
    DataCell(
      valueText(
        _fmtSignedPct(item.openChangePct),
        change: item.openChangePct,
      ),
    ),
    DataCell(
      valueText(
        _fmtSignedPct(item.changePct),
        change: item.changePct,
      ),
    ),
    DataCell(
      valueText(
        _fmtDouble(item.amountYi, suffix: ' 亿'),
        textAlign: TextAlign.right,
      ),
    ),
    DataCell(
      Text(
        item.region ?? '--',
        style: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFF365C4F),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    DataCell(
      Text(
        item.industry ?? '--',
        style: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFF6A5B49),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ];
}

String canonicalWeaknessSectionKey(String value) {
  final normalized = value.trim();
  return switch (normalized) {
    'yesterday_limit_down' || '昨日跌停' => 'yesterday_limit_down',
    'yesterday_broken_board' ||
    'yesterday_duanban' ||
    '昨日炸板' ||
    '昨日断板' =>
      'yesterday_broken_board',
    'today_limit_down' || '今日跌停' => 'today_limit_down',
    'today_broken_board' ||
    'today_duanban' ||
    '今日炸板' ||
    '今日断板' =>
      'today_broken_board',
    _ => normalized,
  };
}

String weaknessSectionTitle(YesterdayStatsSectionData section) {
  final rawValue = [
    section.title.trim(),
    section.key.trim(),
  ].firstWhere(
    (value) => value.isNotEmpty && value != '--',
    orElse: () => section.key.trim(),
  );
  if (rawValue.isEmpty) {
    return '--';
  }
  return formatWeaknessTitle(rawValue);
}

List<YesterdayStatsSectionData> orderWeaknessSections(
  List<YesterdayStatsSectionData> sections,
) {
  const order = {
    'yesterday_limit_down': 0,
    'yesterday_broken_board': 1,
    'today_limit_down': 2,
    'today_broken_board': 3,
  };

  final sorted = [...sections]..sort(
      (left, right) =>
          (order[canonicalWeaknessSectionKey(left.key)] ?? 999).compareTo(
        order[canonicalWeaknessSectionKey(right.key)] ?? 999,
      ),
    );
  return sorted;
}

String? resolveWeaknessSectionSelectionKey(
  List<YesterdayStatsSectionData> sections,
  String? value,
) {
  final normalized = canonicalWeaknessSectionKey(value ?? '');
  if (normalized.isEmpty) {
    return null;
  }
  for (final section in sections) {
    if (canonicalWeaknessSectionKey(section.key) == normalized ||
        canonicalWeaknessSectionKey(section.title) == normalized) {
      return normalized;
    }
  }
  return null;
}

String formatWeaknessTitle(String value) {
  final normalized = canonicalWeaknessSectionKey(value);
  const aliases = {
    'yesterday_limit_down': '昨日跌停',
    'yesterday_broken_board': '昨日断板',
    'today_limit_down': '今日跌停',
    'today_broken_board': '今日断板',
  };
  return aliases[normalized] ?? value;
}

class _WeaknessMarketBadge extends StatelessWidget {
  const _WeaknessMarketBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = _marketAccent(label);

    return Text(
      '[$label]',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

Color weaknessSectionAccent(String key) {
  return switch (canonicalWeaknessSectionKey(key)) {
    'yesterday_limit_down' => const Color(0xFF0A8F3D),
    'today_limit_down' => const Color(0xFF13A05F),
    'yesterday_broken_board' => const Color(0xFFD56B07),
    'today_broken_board' => const Color(0xFF2D83F8),
    _ => AppTheme.primary,
  };
}

Color _marketAccent(String market) {
  return switch (market) {
    '沪' => const Color(0xFF2E6386),
    '深' => const Color(0xFF2F7C5D),
    '创' => const Color(0xFFB56A10),
    '科' => const Color(0xFF4D6A97),
    '北' => const Color(0xFF7A5838),
    _ => AppTheme.primary,
  };
}

String _fmtDouble(double? value, {String suffix = ''}) {
  if (value == null) {
    return '--';
  }
  return '${value.toStringAsFixed(2)}$suffix';
}

String _fmtSignedPct(double? value) {
  if (value == null) {
    return '--';
  }
  return value >= 0
      ? '+${value.toStringAsFixed(2)}%'
      : '${value.toStringAsFixed(2)}%';
}

Color? _changeColor(double? value, ThemeData theme) {
  if (value == null) {
    return null;
  }
  if (value > 0) {
    return const Color(0xFFC9553F);
  }
  if (value < 0) {
    return const Color(0xFF157A6E);
  }
  return theme.colorScheme.onSurface;
}
