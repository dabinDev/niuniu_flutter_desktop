import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/application/export_bundle_service.dart';
import '../../../shared/application/stock_link_service.dart';
import '../../../shared/application/workspace_capture_service.dart';
import '../../../shared/data/market_api_repository.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/trade_date_navigation.dart';
import '../application/market_center_provider.dart';
import '../data/market_center_repository.dart';

class MarketCenterPage extends ConsumerStatefulWidget {
  const MarketCenterPage({
    super.key,
    this.initialTradeDate,
  });

  final String? initialTradeDate;

  @override
  ConsumerState<MarketCenterPage> createState() => _MarketCenterPageState();
}

class _MarketCenterPageState extends ConsumerState<MarketCenterPage> {
  final GlobalKey _captureKey = GlobalKey();
  String? _selectedTradeDate;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _selectedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
  }

  @override
  void didUpdateWidget(covariant MarketCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTradeDate != widget.initialTradeDate) {
      _selectedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(marketCenterProvider(_selectedTradeDate));

    return AppShell(
      currentPath: '/market-center',
      title: '行情中心',
      subtitle: '六大股池联动复盘，支持按交易日切换与个股联查。',
      child: data.when(
        data: (page) {
          final snapshot = _sortSnapshot(page.marketCenter);
          final totalRows = snapshot.tables.fold<int>(
            0,
            (sum, section) => sum + section.total,
          );
          final activeSections =
              snapshot.tables.where((section) => section.total > 0).length;
          final largestSection = _largestSection(snapshot.tables);

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1180;
              final workspaceHeight = isWide ? 940.0 : 780.0;

              return RefreshIndicator(
                onRefresh: _refreshData,
                child: RepaintBoundary(
                  key: _captureKey,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildSummaryPanel(
                        context,
                        page: page,
                        snapshot: snapshot,
                        totalRows: totalRows,
                        activeSections: activeSections,
                        largestSection: largestSection,
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.tables.isEmpty)
                        _buildEmptyWorkspace(context)
                      else
                        DefaultTabController(
                          length: snapshot.tables.length,
                          child: _buildWorkspace(
                            context,
                            snapshot: snapshot,
                            height: workspaceHeight,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '行情中心请求失败：$error',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPanel(
    BuildContext context, {
    required MarketCenterPageData page,
    required TableSectionsSnapshot snapshot,
    required int totalRows,
    required int activeSections,
    required TableSectionData? largestSection,
  }) {
    final theme = Theme.of(context);
    final resolvedTradeDate =
        page.navigation.resolvedTradeDate ?? snapshot.tradeDate;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('六大股池', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '交易日 ${resolvedTradeDate ?? '--'}  |  快照 ${_formatTimestamp(snapshot.fetchedAt)}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '沿用旧版桌面端阅读顺序：先看日期，再切股池，最后看明细表格。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '股池 ${snapshot.tables.length} · 非空 $activeSections · 条目 $totalRows · 主池 ${largestSection == null ? '--' : _formatSectionTitle(largestSection.title)} ${largestSection == null ? '' : largestSection.total}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TradeDateActionBar(
            keyPrefix: 'market-center',
            resolvedTradeDate: resolvedTradeDate,
            selectedTradeDate: _selectedTradeDate,
            previousTradeDate: page.navigation.previousTradeDate,
            nextTradeDate: page.navigation.nextTradeDate,
            onSelectTradeDate: _selectTradeDate,
            leadingChildren: [
              _ToolbarControl(
                child: FilledButton.tonalIcon(
                  onPressed: _isRefreshing ? null : _refreshData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_isRefreshing ? '刷新中...' : '刷新'),
                ),
              ),
              _ToolbarControl(
                child: OutlinedButton.icon(
                  onPressed: page.navigation.availableTradeDates.isEmpty
                      ? null
                      : () => _pickTradeDate(
                            page.navigation.availableTradeDates,
                            resolvedTradeDate,
                          ),
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(resolvedTradeDate ?? '选择日期'),
                ),
              ),
              _ToolbarControl(
                child: OutlinedButton.icon(
                  onPressed: _copyWorkspaceImage,
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('复制图片'),
                ),
              ),
              _ToolbarControl(
                child: OutlinedButton.icon(
                  onPressed: () => _copySnapshotText(snapshot),
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('复制文本'),
                ),
              ),
              _ToolbarControl(
                child: OutlinedButton.icon(
                  onPressed: () => _exportSnapshotExcel(snapshot),
                  icon: const Icon(Icons.table_chart_rounded),
                  label: const Text('导出 Excel'),
                ),
              ),
              _ToolbarControl(
                child: OutlinedButton.icon(
                  onPressed: () => _exportSnapshotCsv(snapshot),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('导出 CSV'),
                ),
              ),
            ],
            previousLabel: '前一日',
            nextLabel: '后一日',
            latestLabel: '最新',
          ),
          if (page.navigation.availableTradeDates.isNotEmpty) ...[
            const SizedBox(height: 12),
            TradeDateChoiceChips(
              keyPrefix: 'market-center',
              availableTradeDates: page.navigation.availableTradeDates,
              resolvedTradeDate: resolvedTradeDate,
              maxVisibleDates: 6,
              onSelectTradeDate: _selectTradeDate,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required TableSectionsSnapshot snapshot,
    required double height,
  }) {
    final theme = Theme.of(context);

    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('股池工作台', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '六个标签保持与旧版一致，切换后直接查看对应股池明细。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: snapshot.tables
                .map(
                  (section) => Tab(
                    child: Semantics(
                      button: true,
                      label: 'pw-market-center-tab-${section.key}',
                      child: Text(
                        '${_formatSectionTitle(section.title)} (${section.total})',
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: snapshot.tables
                  .map((section) => _buildSectionView(context, section))
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionView(BuildContext context, TableSectionData section) {
    final theme = Theme.of(context);
    final sectionTone = _sectionTone(section.key);

    return Container(
      decoration: BoxDecoration(
        color: sectionTone.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: sectionTone.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 38,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: sectionTone.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatSectionTitle(section.title),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sectionDescription(section),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${section.total} 条 · ${section.displayColumns.length} 列',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
            if (section.displayColumns.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                section.displayColumns
                    .take(10)
                    .map((column) => column.label)
                    .join(' / '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: section.displayRows.isEmpty
                  ? Center(
                      child: Text(
                        '当前股池暂无数据。',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  : Scrollbar(
                      child: LayoutBuilder(
                        builder: (context, tableConstraints) {
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: sectionTone.border,
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: tableConstraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    headingRowHeight: 34,
                                    dataRowMinHeight: 32,
                                    dataRowMaxHeight: 38,
                                    horizontalMargin: 10,
                                    columnSpacing: 16,
                                    headingRowColor: WidgetStateProperty.all(
                                      sectionTone.header,
                                    ),
                                    columns: section.displayColumns
                                        .map(
                                          (column) => DataColumn(
                                            label: SizedBox(
                                              width: _marketColumnWidth(column),
                                              child: Text(
                                                column.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: _columnTextAlign(
                                                  column.align,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    rows: section.displayRows
                                        .asMap()
                                        .entries
                                        .map(
                                          (entry) => DataRow(
                                            color: WidgetStateProperty.all(
                                              entry.key.isEven
                                                  ? sectionTone.rowEven
                                                  : sectionTone.rowOdd,
                                            ),
                                            cells: _buildRowCells(
                                              context,
                                              section,
                                              entry.value,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
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
      ),
    );
  }

  Widget _buildEmptyWorkspace(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        '行情中心暂时还没有可展示的股池数据。',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  TableSectionData? _largestSection(List<TableSectionData> sections) {
    if (sections.isEmpty) {
      return null;
    }
    final sorted = [...sections]
      ..sort((left, right) => right.total.compareTo(left.total));
    return sorted.first;
  }

  String _sectionDescription(TableSectionData section) {
    const descriptions = {
      'zt': '涨停股池，重点看封板资金、封板时间和连板高度。',
      'zrzt': '昨日涨停股池，重点观察承接强弱与昨日封板质量。',
      'qs': '强势股池，关注涨速、量比和入选理由。',
      'cx': '次新股池，关注开板天数、上市日期与是否新高。',
      'zb': '炸板股池，观察首次封板、炸板次数和振幅。',
      'dt': '跌停股池，跟踪封板资金、板上成交额与连续跌停。',
    };
    return descriptions[section.key] ?? '当前股池结构化快照。';
  }

  String _formatMarketCell(TableColumnData column, String rawValue) {
    final normalized = _normalizeMarketText(rawValue);
    final key = column.key.trim().toLowerCase();
    if (!_isAmountLikeColumn(key)) {
      return normalized;
    }
    if (RegExp(r'[亿万]').hasMatch(normalized)) {
      return normalized;
    }
    final numeric = double.tryParse(normalized.replaceAll(',', ''));
    if (numeric == null) {
      return normalized;
    }
    final absValue = numeric.abs();
    if (absValue >= 100000000) {
      return '${_trimNumber(numeric / 100000000)}亿';
    }
    if (absValue >= 10000) {
      return '${_trimNumber(numeric / 10000)}万';
    }
    return '${_trimNumber(numeric)}亿';
  }

  bool _isAmountLikeColumn(String key) {
    return key == 'amount' ||
        key == 'seal_amount' ||
        key == 'board_amount' ||
        key == 'float_market_cap' ||
        key == 'total_market_cap' ||
        key.endsWith('_amount') ||
        key.contains('market_cap');
  }

  String _normalizeMarketText(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      return '--';
    }
    normalized = normalized
        .replaceAllMapped(
          RegExp(r'(-?\d+(?:\.\d+)?)\s*yi\b', caseSensitive: false),
          (match) => '${match.group(1)}亿',
        )
        .replaceAllMapped(
          RegExp(r'(-?\d+(?:\.\d+)?)\s*wan\b', caseSensitive: false),
          (match) => '${match.group(1)}万',
        )
        .replaceAll(RegExp(r'\bprev\b', caseSensitive: false), '昨')
        .replaceAllMapped(
      RegExp(r'(\d+)\s*天\s*/?\s*(\d+)\s*次'),
      (match) {
        final days = int.tryParse(match.group(1) ?? '');
        final hits = int.tryParse(match.group(2) ?? '');
        if (days != null && hits != null && days == hits) {
          return '$days板';
        }
        return '${match.group(1)}天/${match.group(2)}次';
      },
    ).replaceAllMapped(
      RegExp(r'(\d+)\s*days\s*/\s*(\d+)\s*hits', caseSensitive: false),
      (match) {
        final days = int.tryParse(match.group(1) ?? '');
        final hits = int.tryParse(match.group(2) ?? '');
        if (days != null && hits != null && days == hits) {
          return '$days板';
        }
        return '${match.group(1)}天/${match.group(2)}次';
      },
    );
    const labels = {
      'inspect': '查看',
      'null': '--',
    };
    return labels[normalized.toLowerCase()] ?? normalized;
  }

  String _trimNumber(double value) {
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  List<DataCell> _buildRowCells(
    BuildContext context,
    TableSectionData section,
    List<String> row,
  ) {
    final theme = Theme.of(context);
    final stockCode = _extractStockCode(section, row);
    final marketTag = stockCode == null ? null : inferStockMarketTag(stockCode);
    final displayColumns = section.displayColumns;
    final codeIndex = _findColumnIndex(
      displayColumns,
      const {'code', 'stock_code', 'symbol'},
    );
    final nameIndex = _findColumnIndex(
      displayColumns,
      const {'name', 'stock_name'},
    );

    return List.generate(displayColumns.length, (columnIndex) {
      final cell = columnIndex < row.length ? row[columnIndex] : '--';
      final column = displayColumns[columnIndex];
      final displayCell = _formatMarketCell(column, cell);
      final cellColor = _marketCellColor(context, column, displayCell);
      final cellWeight = _marketCellWeight(column);
      final cellWidth = _marketColumnWidth(column);
      final isCodeCell = stockCode != null && columnIndex == codeIndex;
      final isNameCell = stockCode != null && columnIndex == nameIndex;
      final isStockCell = isCodeCell || isNameCell;
      final stockSemanticsLabel = stockCode == null
          ? null
          : 'pw-market-center-stock-${section.key}-$stockCode';
      final codeSemanticsLabel = stockCode == null
          ? null
          : 'pw-market-center-code-${section.key}-$stockCode';

      if (isNameCell) {
        return DataCell(
          SizedBox(
            width: cellWidth,
            child: Semantics(
              container: true,
              button: true,
              label: stockSemanticsLabel,
              child: ExcludeSemantics(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    excludeFromSemantics: true,
                    message: '打开个股',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (marketTag != null) ...[
                          _InlineMarketBadge(label: marketTag),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Align(
                            alignment: _columnAlignment(column.align),
                            child: Text(
                              displayCell,
                              overflow: TextOverflow.ellipsis,
                              textAlign: _columnTextAlign(column.align),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          onTap: () => _openStock(stockCode),
        );
      }

      if (isCodeCell) {
        return DataCell(
          SizedBox(
            width: cellWidth,
            child: Semantics(
              container: true,
              button: true,
              label: codeSemanticsLabel,
              child: ExcludeSemantics(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    excludeFromSemantics: true,
                    message: '打开个股',
                    child: Text(
                      marketTag == null
                          ? displayCell
                          : '$marketTag $displayCell',
                      overflow: TextOverflow.ellipsis,
                      textAlign: _columnTextAlign(column.align),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          onTap: () => _openStock(stockCode),
        );
      }

      final rawChild = isStockCell
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(
                message: '打开个股',
                child: Text(
                  displayCell,
                  textAlign: _columnTextAlign(column.align),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.primary,
                  ),
                ),
              ),
            )
          : Align(
              alignment: _columnAlignment(column.align),
              child: _MarketValueText(
                column: column,
                value: displayCell,
                color: cellColor,
                fontWeight: cellWeight,
                textAlign: _columnTextAlign(column.align),
              ),
            );

      return DataCell(
        SizedBox(width: cellWidth, child: rawChild),
        onTap: stockCode == null || !isStockCell
            ? null
            : () => _openStock(stockCode),
      );
    });
  }

  Color _marketCellColor(
    BuildContext context,
    TableColumnData column,
    String value,
  ) {
    final normalized = value.trim();
    final key = column.key.trim().toLowerCase();
    final numeric = _parseCellNumber(normalized);
    if (key.contains('pct') ||
        key.contains('change') ||
        normalized.endsWith('%')) {
      if (numeric != null && numeric > 0) {
        return AppTheme.danger;
      }
      if (numeric != null && numeric < 0) {
        return AppTheme.fall;
      }
    }
    if (_isAmountLikeColumn(key)) {
      return AppTheme.secondary;
    }
    if (key.contains('board') || key.contains('limit')) {
      return const Color(0xFFD56B07);
    }
    if (key.contains('concept') || key.contains('reason')) {
      return const Color(0xFF5D6472);
    }
    if (key.contains('industry')) {
      return const Color(0xFF2E6386);
    }
    if (key.contains('time') || key.contains('date')) {
      return AppTheme.primary;
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  FontWeight _marketCellWeight(TableColumnData column) {
    final key = column.key.trim().toLowerCase();
    if (_isAmountLikeColumn(key) ||
        key.contains('pct') ||
        key.contains('change') ||
        key.contains('board') ||
        key.contains('limit')) {
      return FontWeight.w700;
    }
    return FontWeight.w500;
  }

  double? _parseCellNumber(String value) {
    final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(value);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(0) ?? '');
  }

  int _findColumnIndex(List<TableColumnData> columns, Set<String> candidates) {
    for (var index = 0; index < columns.length; index += 1) {
      if (candidates.contains(columns[index].key.trim().toLowerCase())) {
        return index;
      }
    }
    return -1;
  }

  String? _extractStockCode(TableSectionData section, List<String> row) {
    final codeIndex = _findColumnIndex(
      section.displayColumns,
      const {'code', 'stock_code', 'symbol'},
    );
    if (codeIndex >= 0 && codeIndex < row.length) {
      final normalized = _normalizeStockCode(row[codeIndex]);
      if (normalized != null) {
        return normalized;
      }
    }

    final matcher = RegExp(r'\b(\d{6})\b');
    for (final cell in row) {
      final match = matcher.firstMatch(cell);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  String? _normalizeStockCode(String value) {
    final trimmed = value.trim();
    return RegExp(r'^\d{6}$').hasMatch(trimmed) ? trimmed : null;
  }

  TableSectionsSnapshot _sortSnapshot(TableSectionsSnapshot snapshot) {
    const order = {
      'zt': 0,
      'zrzt': 1,
      'qs': 2,
      'cx': 3,
      'zb': 4,
      'dt': 5,
    };
    final sortedTables = [...snapshot.tables]..sort((left, right) {
        final leftOrder = order[left.key] ?? 999;
        final rightOrder = order[right.key] ?? 999;
        return leftOrder.compareTo(rightOrder);
      });
    return TableSectionsSnapshot(
      tradeDate: snapshot.tradeDate,
      fetchedAt: snapshot.fetchedAt,
      tables: sortedTables,
    );
  }

  void _selectTradeDate(String? tradeDate) {
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    setState(() {
      _selectedTradeDate = normalizedTradeDate;
    });
    _syncMarketCenterRoute(normalizedTradeDate);
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
    });
    final provider = marketCenterProvider(_selectedTradeDate);
    try {
      ref.invalidate(provider);
      await ref.read(provider.future);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _pickTradeDate(
    List<String> availableTradeDates,
    String? currentTradeDate,
  ) async {
    if (availableTradeDates.isEmpty) {
      return;
    }

    final parsedDates = availableTradeDates
        .map(_tryParseTradeDate)
        .whereType<DateTime>()
        .toList(growable: false);
    if (parsedDates.isEmpty) {
      return;
    }

    final allowed = {
      for (final date in parsedDates) _tradeDateKey(date),
    };
    final initialDate =
        _tryParseTradeDate(currentTradeDate) ?? parsedDates.first;
    final firstDate = parsedDates.reduce(
      (left, right) => left.isBefore(right) ? left : right,
    );
    final lastDate = parsedDates.reduce(
      (left, right) => left.isAfter(right) ? left : right,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (date) => allowed.contains(_tradeDateKey(date)),
      helpText: '选择交易日',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (!mounted || picked == null) {
      return;
    }

    _selectTradeDate(_formatTradeDate(picked));
  }

  Future<void> _copyWorkspaceImage() async {
    final result = await captureWorkspaceImage(
      repaintBoundaryKey: _captureKey,
      context: context,
      bundleName: 'market_center_workspace',
      fileName: '行情中心.png',
    );
    if (result == null) {
      _showInfo('当前工作区暂时无法生成图片。');
      return;
    }
    _showInfo(
      result.copiedToClipboard
          ? '行情中心图片已复制到剪贴板。'
          : '行情中心图片已导出：${result.filePath}',
    );
  }

  Future<void> _copySnapshotText(TableSectionsSnapshot snapshot) async {
    final buffer = StringBuffer()
      ..writeln('行情中心')
      ..writeln('交易日：${snapshot.tradeDate ?? '--'}')
      ..writeln('快照：${_formatTimestamp(snapshot.fetchedAt)}');
    for (final section in snapshot.tables) {
      final columns = section.displayColumns;
      buffer
        ..writeln()
        ..writeln('[${_formatSectionTitle(section.title)}]');
      buffer.writeln(columns.map((column) => column.label).join('\t'));
      for (final row in section.displayRows) {
        buffer.writeln(
          List<String>.generate(
            columns.length,
            (index) => _formatMarketCell(
              columns[index],
              index < row.length ? row[index] : '--',
            ),
          ).join('\t'),
        );
      }
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    _showInfo('行情中心数据已复制到剪贴板。');
  }

  Future<void> _exportSnapshotExcel(TableSectionsSnapshot snapshot) async {
    final files = _buildSnapshotExportFiles(snapshot);
    final filePath = await writeExcelWorkbook(
      bundleName: 'market_center',
      fileName: '行情中心.xlsx',
      sheets: files.entries
          .map((entry) => ExcelSheetData(name: entry.key, rows: entry.value))
          .toList(growable: false),
    );
    _showInfo('行情中心 Excel 已导出：$filePath');
  }

  Future<void> _exportSnapshotCsv(TableSectionsSnapshot snapshot) async {
    final result = await writeCsvBundle(
      bundleName: 'market_center',
      files: _buildSnapshotExportFiles(snapshot),
    );
    _showInfo('行情中心 CSV 已导出：${result.directoryPath}');
  }

  Map<String, List<List<String>>> _buildSnapshotExportFiles(
    TableSectionsSnapshot snapshot,
  ) {
    final files = <String, List<List<String>>>{
      'summary': [
        ['trade_date', snapshot.tradeDate ?? '--'],
        ['snapshot_at', _formatTimestamp(snapshot.fetchedAt)],
        ['sections', '${snapshot.tables.length}'],
        [
          'rows',
          '${snapshot.tables.fold<int>(0, (sum, section) => sum + section.total)}',
        ],
      ],
    };

    for (final section in snapshot.tables) {
      final columns = section.displayColumns;
      files[_formatSectionTitle(section.title)] = [
        columns.map((column) => column.label).toList(growable: false),
        ...section.displayRows.map(
          (row) => List<String>.generate(
            columns.length,
            (index) => _formatMarketCell(
              columns[index],
              index < row.length ? row[index] : '--',
            ),
            growable: false,
          ),
        ),
      ];
    }
    return files;
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openStock(String code) async {
    await openStockLinkFromUi(
      context: context,
      ref: ref,
      code: code,
    );
  }

  String _formatTimestamp(String? value) {
    if (value == null || value.isEmpty) {
      return '--';
    }
    return value.replaceFirst('T', ' ').split('.').first;
  }

  String _formatSectionTitle(String value) {
    const aliases = {
      'zt': '涨停股池',
      'limit_up': '涨停股池',
      'limit_up_pool': '涨停股池',
      'zrzt': '昨日涨停',
      'yesterday_limit_up': '昨日涨停',
      'yesterday_limit_up_pool': '昨日涨停',
      'qs': '强势股池',
      'trend_up': '强势股池',
      'strong_pool': '强势股池',
      'cx': '次新股池',
      'new_high': '次新股池',
      'new_listing_pool': '次新股池',
      'zb': '炸板股池',
      'broken_limit': '炸板股池',
      'broken_limit_pool': '炸板股池',
      'dt': '跌停股池',
      'limit_down': '跌停股池',
      'limit_down_pool': '跌停股池',
    };
    return aliases[value] ?? _titleize(value);
  }

  Alignment _columnAlignment(String value) {
    return switch (value.trim().toLowerCase()) {
      'center' => Alignment.center,
      'right' => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };
  }

  TextAlign _columnTextAlign(String value) {
    return switch (value.trim().toLowerCase()) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
  }

  double _marketColumnWidth(TableColumnData column) {
    return (column.width ?? 110).clamp(66, 220).toDouble();
  }

  String _titleize(String value) {
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  DateTime? _tryParseTradeDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  String _formatTradeDate(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String _tradeDateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String? _normalizeTradeDate(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _syncMarketCenterRoute(String? tradeDate) {
    if (!mounted) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    final uri = Uri(
      path: '/market-center',
      queryParameters: normalizedTradeDate == null
          ? null
          : <String, String>{'tradeDate': normalizedTradeDate},
    );
    router.replace(uri.toString());
  }
}

class _SectionTone {
  const _SectionTone({
    required this.accent,
    required this.surface,
    required this.header,
    required this.rowEven,
    required this.rowOdd,
    required this.border,
  });

  final Color accent;
  final Color surface;
  final Color header;
  final Color rowEven;
  final Color rowOdd;
  final Color border;
}

class _ToolbarControl extends StatelessWidget {
  const _ToolbarControl({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: child,
    );
  }
}

_SectionTone _sectionTone(String key) {
  final normalized = key.trim().toLowerCase();
  final accent = switch (normalized) {
    'zt' || 'limit_up' || 'limit_up_pool' => const Color(0xFFC9553F),
    'zrzt' ||
    'yesterday_limit_up' ||
    'yesterday_limit_up_pool' =>
      const Color(0xFFD56B07),
    'qs' || 'trend_up' || 'strong_pool' => AppTheme.primary,
    'cx' || 'new_high' || 'new_listing_pool' => const Color(0xFF6D5BC3),
    'zb' || 'broken_limit' || 'broken_limit_pool' => const Color(0xFFF97316),
    'dt' || 'limit_down' || 'limit_down_pool' => const Color(0xFF0A8F3D),
    _ => AppTheme.primary,
  };
  return _SectionTone(
    accent: accent,
    surface: Color.lerp(Colors.white, accent, 0.018)!,
    header: Color.lerp(Colors.white, accent, 0.085)!,
    rowEven: Colors.white,
    rowOdd: Color.lerp(Colors.white, accent, 0.018)!,
    border: accent.withValues(alpha: 0.18),
  );
}

class _MarketValueText extends StatelessWidget {
  const _MarketValueText({
    required this.column,
    required this.value,
    required this.color,
    required this.fontWeight,
    required this.textAlign,
  });

  final TableColumnData column;
  final String value;
  final Color color;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = column.key.trim().toLowerCase();
    final boardCount = _extractBoardCount(value);
    if (boardCount != null &&
        (key.contains('limit_stats') ||
            key.contains('board_count') ||
            key.contains('limit'))) {
      final tone = _boardCountTone(boardCount);
      return Align(
        alignment: _textAlignToAlignment(textAlign),
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: tone.border),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tone.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    final isConceptLike = key.contains('concept') ||
        key.contains('reason') ||
        key.contains('industry');
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: isConceptLike ? const Color(0xFF4F5F6B) : color,
        fontWeight: isConceptLike ? FontWeight.w600 : fontWeight,
      ),
    );
  }
}

class _InlineMarketBadge extends StatelessWidget {
  const _InlineMarketBadge({
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

Color _marketAccent(String market) {
  return switch (market) {
    'SH' => const Color(0xFF2E6386),
    'SZ' => const Color(0xFF2F7C5D),
    'BJ' => const Color(0xFFB56A10),
    'CY' => const Color(0xFF4D6A97),
    'KC' => const Color(0xFF7A5838),
    _ => const Color(0xFF406257),
  };
}

int? _extractBoardCount(String value) {
  final normalized = value.trim();
  final boardMatch = RegExp(r'(\d+)\s*板').firstMatch(normalized);
  if (boardMatch != null) {
    return int.tryParse(boardMatch.group(1) ?? '');
  }
  final plainNumber = RegExp(r'^\d+$').firstMatch(normalized);
  if (plainNumber != null) {
    return int.tryParse(normalized);
  }
  return null;
}

({Color background, Color border, Color text}) _boardCountTone(int count) {
  if (count >= 5) {
    return const (
      background: Color(0xFFFFEEF0),
      border: Color(0x66E64C62),
      text: Color(0xFFD7403D),
    );
  }
  if (count >= 3) {
    return const (
      background: Color(0xFFFFF2E6),
      border: Color(0x66FD6524),
      text: Color(0xFFD56B07),
    );
  }
  if (count >= 2) {
    return const (
      background: Color(0xFFFFF8DF),
      border: Color(0x66FE9506),
      text: Color(0xFFC47605),
    );
  }
  return const (
    background: Color(0xFFEAF3FF),
    border: Color(0x662D83F8),
    text: Color(0xFF2D83F8),
  );
}

Alignment _textAlignToAlignment(TextAlign textAlign) {
  return switch (textAlign) {
    TextAlign.right => Alignment.centerRight,
    TextAlign.center => Alignment.center,
    _ => Alignment.centerLeft,
  };
}
