import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui show ImageByteFormat, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/application/export_bundle_service.dart';
import '../../../shared/application/stock_link_service.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/trade_date_navigation.dart';
import '../application/board_height_provider.dart';
import '../data/board_height_repository.dart';

const _selectedSurface = Color(0xFFEAF3FF);
const _chartSurface = Color(0xFFF6F8FB);
const _chartCanvas = Color(0xFFFFFFFF);
const _chartGrid = Color(0x242D83F8);
const _chartAccent = Color(0xFFFF9800);
const _chartAssist = Color(0xFF2D83F8);
const _matrixColumnWidth = 156.0;
const _matrixTierWidth = 66.0;
const _matrixHeaderHeight = 84.0;
const _matrixCellHeight = 70.0;

class BoardHeightPage extends ConsumerStatefulWidget {
  const BoardHeightPage({
    super.key,
    this.initialTradeDate,
  });

  final String? initialTradeDate;

  @override
  ConsumerState<BoardHeightPage> createState() => _BoardHeightPageState();
}

class _BoardHeightPageState extends ConsumerState<BoardHeightPage> {
  final GlobalKey _captureKey = GlobalKey();
  final ScrollController _sessionScrollController = ScrollController();

  int _daysToShow = 12;
  bool _isRefreshing = false;
  String? _selectedTradeDate;
  String? _selectedDate;
  String? _hoveredDate;

  @override
  void initState() {
    super.initState();
    final normalizedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
    _selectedTradeDate = normalizedTradeDate;
    _selectedDate = normalizedTradeDate;
  }

  @override
  void didUpdateWidget(covariant BoardHeightPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTradeDate != widget.initialTradeDate) {
      final normalizedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
      _selectedTradeDate = normalizedTradeDate;
      _selectedDate = normalizedTradeDate;
      _hoveredDate = null;
    }
  }

  @override
  void dispose() {
    _sessionScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = boardHeightProvider(_selectedTradeDate);
    final data = ref.watch(provider);

    return AppShell(
      currentPath: '/board-height',
      title: '连板高度',
      subtitle: '按旧版连板高度页的习惯展示高度曲线、梯队变化和对应交易日的高度演进。',
      child: data.when(
        data: (snapshot) => _buildBody(context, snapshot),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '连板高度请求失败：$error',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, BoardHeightSnapshot snapshot) {
    final items = _visibleItems(snapshot.chartItems, _daysToShow);
    if (items.isEmpty) {
      return SingleChildScrollView(
        child: RepaintBoundary(
          key: _captureKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(context, snapshot, items, null, null),
              const SizedBox(height: 16),
              _buildEmptyBlock(
                context,
                '当前快照下还没有可展示的连板高度历史。',
              ),
            ],
          ),
        ),
      );
    }

    final activeDate = _activeDate(items);
    final activeItem = items.firstWhere((item) => item.date == activeDate);
    final activeColumn = _findColumn(snapshot.columns, activeDate);
    final sessions = items
        .map(
          (item) => _Session(
            item: item,
            column: _findColumn(snapshot.columns, item.date),
          ),
        )
        .toList(growable: false);

    return SingleChildScrollView(
      child: RepaintBoundary(
        key: _captureKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(context, snapshot, items, activeItem, activeColumn),
            const SizedBox(height: 16),
            _buildCurveWorkspace(context, items, activeItem, activeColumn),
            const SizedBox(height: 16),
            _buildSessionWorkspace(context, sessions, activeItem),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) {
      return;
    }
    final provider = boardHeightProvider(_selectedTradeDate);
    setState(() {
      _isRefreshing = true;
    });
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

  Widget _buildHero(
    BuildContext context,
    BoardHeightSnapshot snapshot,
    List<BoardHeightChartItemData> items,
    BoardHeightChartItemData? activeItem,
    BoardHeightColumnData? activeColumn,
  ) {
    final theme = Theme.of(context);
    final latest = items.isEmpty ? null : items.last;
    final availableTradeDates = _availableTradeDates(snapshot);
    final resolvedTradeDate =
        _normalizeTradeDate(snapshot.tradeDate) ?? _selectedTradeDate;
    final previousTradeDate = snapshot.previousTradeDate;
    final nextTradeDate = snapshot.nextTradeDate;
    final range =
        items.isEmpty ? '--' : '${items.first.date} 至 ${items.last.date}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('高度时间轴', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      '交易日 ${snapshot.tradeDate ?? '--'}  |  快照 ${_fmtTimestamp(snapshot.fetchedAt)}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '展示区间：$range',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TradeDateActionBar(
                    keyPrefix: 'board-height',
                    resolvedTradeDate: resolvedTradeDate,
                    selectedTradeDate: _selectedTradeDate,
                    previousTradeDate: previousTradeDate,
                    nextTradeDate: nextTradeDate,
                    onSelectTradeDate: _selectTradeDate,
                    leadingChildren: [
                      _buildDayChip(12),
                      _buildDayChip(20),
                    ],
                    trailingChildren: [
                      FilledButton.tonalIcon(
                        onPressed: _isRefreshing ? null : _refreshData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(_isRefreshing ? '刷新中' : '刷新'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copyWorkspaceImage(snapshot),
                        icon: const Icon(Icons.image_rounded),
                        label: const Text('复制图片'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copySnapshotText(snapshot, items),
                        icon: const Icon(Icons.copy_all_rounded),
                        label: const Text('复制文本'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _exportExcelSnapshot(snapshot, items),
                        icon: const Icon(Icons.table_view_rounded),
                        label: const Text('导出 Excel'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _exportCsvSnapshot(snapshot, items),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('导出 CSV'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (availableTradeDates.isNotEmpty) ...[
            const SizedBox(height: 12),
            TradeDateChoiceChips(
              keyPrefix: 'board-height',
              availableTradeDates: availableTradeDates,
              resolvedTradeDate: resolvedTradeDate,
              onSelectTradeDate: _selectTradeDate,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                label: '最新高度',
                value: '${snapshot.latestHeight ?? latest?.value ?? 0} 板',
                caption: latest == null ? '暂无最新交易日' : latest.date,
              ),
              _MetricCard(
                label: '当前锚点',
                value: activeItem?.date ?? '--',
                caption: activeItem == null
                    ? '悬停或点击曲线后定位'
                    : '${activeItem.value} 板  |  ${activeColumn?.stocks.length ?? 0} 只股票',
              ),
              _MetricCard(
                label: '空间龙头',
                value: _cleanLeader(activeItem?.leaderName),
                caption: activeItem?.leaderCode ?? '暂无代码',
              ),
              _MetricCard(
                label: '展示日数',
                value: '${items.length}',
                caption: '曲线与下方日期列联动',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(int days) {
    return ChoiceChip(
      label: Text('$days 日'),
      selected: _daysToShow == days,
      onSelected: (_) => setState(() => _daysToShow = days),
    );
  }

  Widget _buildCurveWorkspace(
    BuildContext context,
    List<BoardHeightChartItemData> items,
    BoardHeightChartItemData activeItem,
    BoardHeightColumnData? activeColumn,
  ) {
    final theme = Theme.of(context);
    final preview = activeColumn?.stocks.take(6).toList(growable: false) ??
        const <BoardHeightStockData>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;
        final chart = _TrendChartPanel(
          items: items,
          activeDate: activeItem.date,
          onSelect: (date) => setState(() => _selectedDate = date),
          onHover: (date) => setState(() => _hoveredDate = date),
        );
        final inspector = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryOutline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('锚点详情', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _InfoRow(label: '日期', value: activeItem.date),
              _InfoRow(label: '高度', value: '${activeItem.value} 板'),
              _InfoRow(label: '龙头', value: _cleanLeader(activeItem.leaderName)),
              _InfoRow(label: '代码', value: activeItem.leaderCode ?? '--'),
              _InfoRow(
                label: '成员数',
                value: '${activeColumn?.stocks.length ?? 0}',
              ),
              if (activeItem.leaderCode != null &&
                  activeItem.leaderCode!.isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openStock(activeItem.leaderCode!),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('打开龙头'),
                ),
              ],
              const SizedBox(height: 14),
              Text('成员预览', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              if (preview.isEmpty)
                Text('暂无解析成员。', style: theme.textTheme.bodyMedium)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: preview
                      .map(
                        (stock) => _PreviewChip(
                          label: stock.code == null || stock.code!.isEmpty
                              ? stock.name
                              : '${stock.name} ${stock.code}',
                          tone: _toneForBoard(stock.boardCount),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
        );

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('高度曲线', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          '桌面端悬停、移动端点击，都会把下方日期列锁定到当前交易日。',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primaryOutline),
                    ),
                    child: Text(
                      '${activeItem.date}  |  ${activeItem.value} 板',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: chart),
                    const SizedBox(width: 14),
                    Expanded(flex: 3, child: inspector),
                  ],
                )
              else ...[
                chart,
                const SizedBox(height: 12),
                inspector,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionWorkspace(
    BuildContext context,
    List<_Session> sessions,
    BoardHeightChartItemData activeItem,
  ) {
    final theme = Theme.of(context);
    final leaders = _splitLeaders(activeItem.leaderName);
    final maxRows = sessions.fold<int>(
      0,
      (current, session) => math.max(current, _sessionStocks(session).length),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('高度矩阵', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '按旧版表格方式横向对照每个交易日的高度成员，点击单元格可直接打开个股。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primaryOutline),
                ),
                child: Text(activeItem.date, style: theme.textTheme.labelLarge),
              ),
            ],
          ),
          if (leaders.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: leaders
                  .map(
                    (leader) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerSoft,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.dangerOutline),
                      ),
                      child: Text(
                        leader,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Scrollbar(
                controller: _sessionScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _sessionScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: _matrixTierWidth,
                            child: _HeightMatrixTierCell(
                              label: '梯队',
                              selected: false,
                              isHeader: true,
                            ),
                          ),
                          ...sessions.map(
                            (session) => SizedBox(
                              width: _matrixColumnWidth,
                              child: _HeightMatrixHeaderCell(
                                session: session,
                                selected: session.item.date == activeItem.date,
                                onTap: () => setState(
                                  () => _selectedDate = session.item.date,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (maxRows == 0)
                        SizedBox(
                          width: _matrixTierWidth +
                              _matrixColumnWidth * sessions.length,
                          child: Container(
                            height: _matrixCellHeight,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Colors.white54,
                            ),
                            child: Text(
                              '当前区间暂无高度成员',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        ...List.generate(maxRows, (rowIndex) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: _matrixTierWidth,
                                child: _HeightMatrixTierCell(
                                  label: '${rowIndex + 1}',
                                  selected: false,
                                ),
                              ),
                              ...sessions.map((session) {
                                final stocks = _sessionStocks(session);
                                final stock = rowIndex < stocks.length
                                    ? stocks[rowIndex]
                                    : null;
                                final stockCode = stock?.code;
                                return SizedBox(
                                  width: _matrixColumnWidth,
                                  child: _HeightMatrixStockCell(
                                    stock: stock,
                                    selected:
                                        session.item.date == activeItem.date,
                                    emphasized: stock != null &&
                                        _leaderMatch(stock.name, leaders),
                                    onOpenStock:
                                        stockCode == null || stockCode.isEmpty
                                            ? null
                                            : () => _openStock(stockCode),
                                  ),
                                );
                              }),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BoardHeightStockData> _sessionStocks(_Session session) {
    final stocks = session.column?.stocks ?? const <BoardHeightStockData>[];
    if (stocks.isNotEmpty) {
      return stocks;
    }
    final leaders = _splitLeaders(session.item.leaderName);
    if (leaders.isEmpty || session.item.value <= 0) {
      return const [];
    }
    return leaders
        .map(
          (leader) => BoardHeightStockData(
            name: leader,
            code: leaders.length == 1 ? session.item.leaderCode : null,
            boardCount: session.item.value,
          ),
        )
        .toList(growable: false);
  }

  Widget _buildEmptyBlock(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(message, style: theme.textTheme.bodyLarge),
    );
  }

  List<BoardHeightChartItemData> _visibleItems(
    List<BoardHeightChartItemData> items,
    int days,
  ) {
    if (items.length <= days) {
      return items;
    }
    return items.sublist(items.length - days);
  }

  String? _normalizeTradeDate(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  List<String> _availableTradeDates(BoardHeightSnapshot snapshot) {
    if (snapshot.availableTradeDates.isNotEmpty) {
      return snapshot.availableTradeDates;
    }

    final values = <String>[];
    final seen = <String>{};
    for (final item in snapshot.chartItems.reversed) {
      if (seen.add(item.date)) {
        values.add(item.date);
      }
    }
    return values;
  }

  void _selectTradeDate(String? tradeDate) {
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    setState(() {
      _selectedTradeDate = normalizedTradeDate;
      _selectedDate = normalizedTradeDate;
      _hoveredDate = null;
    });
    _syncBoardHeightRoute(normalizedTradeDate);
  }

  void _syncBoardHeightRoute(String? tradeDate) {
    if (!mounted) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    final uri = Uri(
      path: '/board-height',
      queryParameters: normalizedTradeDate == null
          ? null
          : <String, String>{'tradeDate': normalizedTradeDate},
    );
    router.replace(uri.toString());
  }

  String _activeDate(List<BoardHeightChartItemData> items) {
    if (_hoveredDate != null &&
        items.any((item) => item.date == _hoveredDate)) {
      return _hoveredDate!;
    }
    if (_selectedDate != null &&
        items.any((item) => item.date == _selectedDate)) {
      return _selectedDate!;
    }
    return items.last.date;
  }

  BoardHeightColumnData? _findColumn(
    List<BoardHeightColumnData> columns,
    String date,
  ) {
    for (final column in columns) {
      if (column.date == date) {
        return column;
      }
    }
    return null;
  }

  Future<void> _openStock(String code) async {
    await openStockLinkFromUi(
      context: context,
      ref: ref,
      code: code,
    );
  }

  Future<void> _copyWorkspaceImage(BoardHeightSnapshot snapshot) async {
    final pngBytes = await _captureWorkspacePng();
    if (pngBytes == null) {
      _showInfo('连板高度图片生成失败。');
      return;
    }

    final filePath = await writeBinaryFile(
      bundleName: 'board_height_snapshot_image',
      fileName: 'board_height_${snapshot.tradeDate ?? 'snapshot'}.png',
      bytes: pngBytes,
    );

    final copied = await _copyImageToClipboard(filePath);
    if (copied) {
      _showInfo('连板高度图片已复制到剪贴板：$filePath');
      return;
    }

    _showInfo('连板高度 PNG 已保存：$filePath');
  }

  Future<void> _copySnapshotText(
    BoardHeightSnapshot snapshot,
    List<BoardHeightChartItemData> items,
  ) async {
    final buffer = StringBuffer()
      ..writeln('连板高度')
      ..writeln('交易日：${snapshot.tradeDate ?? '--'}')
      ..writeln('快照：${_fmtTimestamp(snapshot.fetchedAt)}')
      ..writeln('最新高度：${snapshot.latestHeight ?? 0}')
      ..writeln()
      ..writeln('[时间轴]');

    for (final item in items) {
      buffer.writeln(
        '${item.date}\t${item.value}\t'
        '${_cleanLeader(item.leaderName)}\t${item.leaderCode ?? '--'}',
      );
    }

    buffer.writeln();
    buffer.writeln('[日期成员]');
    for (final column in snapshot.columns) {
      buffer.writeln(column.date);
      for (final stock in column.stocks) {
        buffer.writeln(
          '${stock.code ?? '--'}\t${stock.name}\t${stock.boardCount ?? '--'}',
        );
      }
      buffer.writeln();
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    _showInfo('连板高度文本已复制到剪贴板。');
  }

  Future<void> _exportExcelSnapshot(
    BoardHeightSnapshot snapshot,
    List<BoardHeightChartItemData> items,
  ) async {
    final filePath = await writeExcelWorkbook(
      bundleName: 'board_height_excel',
      fileName: 'board_height_${snapshot.tradeDate ?? 'snapshot'}.xlsx',
      sheets: _buildExportSheets(snapshot, items)
          .entries
          .map(
            (entry) => ExcelSheetData(
              name: entry.key,
              rows: entry.value,
            ),
          )
          .toList(growable: false),
    );
    _showInfo('连板高度 Excel 已导出：$filePath');
  }

  Future<void> _exportCsvSnapshot(
    BoardHeightSnapshot snapshot,
    List<BoardHeightChartItemData> items,
  ) async {
    final exportSheets = _buildExportSheets(snapshot, items);
    final result = await writeCsvBundle(
      bundleName: 'board_height_snapshot',
      files: exportSheets,
    );
    _showInfo('连板高度 CSV 已导出：${result.directoryPath}');
  }

  Map<String, List<List<String>>> _buildExportSheets(
    BoardHeightSnapshot snapshot,
    List<BoardHeightChartItemData> items,
  ) {
    return {
      'summary': [
        ['trade_date', snapshot.tradeDate ?? '--'],
        ['fetched_at', _fmtTimestamp(snapshot.fetchedAt)],
        ['latest_height', '${snapshot.latestHeight ?? 0}'],
        ['displayed_sessions', '${items.length}'],
      ],
      'timeline': [
        ['date', 'height', 'leader_name', 'leader_code'],
        ...items.map(
          (item) => [
            item.date,
            '${item.value}',
            _cleanLeader(item.leaderName),
            item.leaderCode ?? '--',
          ],
        ),
      ],
      'session_members': [
        ['date', 'code', 'name', 'board_count'],
        ...snapshot.columns.expand(
          (column) => column.stocks.map(
            (stock) => [
              column.date,
              stock.code ?? '--',
              stock.name,
              '${stock.boardCount ?? 0}',
            ],
          ),
        ),
      ],
    };
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<Uint8List?> _captureWorkspacePng() async {
    final pixelRatio = math.min(
      MediaQuery.devicePixelRatioOf(context),
      2.0,
    );

    if (_captureKey.currentContext == null) {
      return null;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return null;
    }

    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  Future<bool> _copyImageToClipboard(String filePath) async {
    if (!Platform.isWindows) {
      return false;
    }

    final script = '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
\$path = ${_powerShellLiteral(filePath)}
\$bytes = [System.IO.File]::ReadAllBytes(\$path)
\$stream = New-Object System.IO.MemoryStream(,\$bytes)
\$image = [System.Drawing.Image]::FromStream(\$stream)
\$bitmap = New-Object System.Drawing.Bitmap \$image
try {
  [System.Windows.Forms.Clipboard]::SetImage(\$bitmap)
} finally {
  \$bitmap.Dispose()
  \$image.Dispose()
  \$stream.Dispose()
}
''';

    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Sta',
          '-Command',
          script,
        ],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  String _powerShellLiteral(String value) {
    final escaped = value.replaceAll("'", "''");
    return "'$escaped'";
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 176,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(caption, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.label,
    required this.tone,
  });

  final String label;
  final _MemberTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tone.text,
            ),
      ),
    );
  }
}

class _Session {
  const _Session({
    required this.item,
    required this.column,
  });

  final BoardHeightChartItemData item;
  final BoardHeightColumnData? column;
}

class _HeightMatrixTierCell extends StatelessWidget {
  const _HeightMatrixTierCell({
    required this.label,
    required this.selected,
    this.isHeader = false,
  });

  final String label;
  final bool selected;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: isHeader ? _matrixHeaderHeight : _matrixCellHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isHeader
            ? AppTheme.surfaceStrong
            : selected
                ? _selectedSurface
                : AppTheme.surfaceSoft,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant),
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: const Color(0xFF17212B),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeightMatrixHeaderCell extends StatelessWidget {
  const _HeightMatrixHeaderCell({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final _Session session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: _matrixHeaderHeight,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          decoration: BoxDecoration(
            color: selected ? _selectedSurface : AppTheme.surfaceSoft,
            border: Border(
              right: BorderSide(color: theme.colorScheme.outlineVariant),
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                session.item.date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF22323A),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFDDEBFF)
                      : AppTheme.secondarySoft,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.secondaryOutline),
                ),
                child: Text(
                  '${session.item.value} 板',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF2D83F8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _cleanLeader(session.item.leaderName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeightMatrixStockCell extends StatelessWidget {
  const _HeightMatrixStockCell({
    required this.stock,
    required this.selected,
    required this.emphasized,
    required this.onOpenStock,
  });

  final BoardHeightStockData? stock;
  final bool selected;
  final bool emphasized;
  final VoidCallback? onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (stock == null) {
      return Container(
        height: _matrixCellHeight,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primarySoft
              : Colors.white.withValues(alpha: 0.62),
          border: Border(
            right: BorderSide(color: theme.colorScheme.outlineVariant),
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
      );
    }

    final stockData = stock!;
    final tone = _toneForBoard(stockData.boardCount);
    final background = emphasized
        ? tone.background
        : selected
            ? AppTheme.primarySoft
            : Colors.white.withValues(alpha: 0.88);
    final label = stockData.boardCount == null
        ? stockData.name
        : '${stockData.name}(${stockData.boardCount}板)';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('board-height-stock-${stockData.code ?? stockData.name}'),
        onTap: onOpenStock,
        child: Container(
          height: _matrixCellHeight,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          decoration: BoxDecoration(
            color: background,
            border: Border(
              right: BorderSide(color: theme.colorScheme.outlineVariant),
              bottom: BorderSide(
                color:
                    emphasized ? tone.border : theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tone.text,
                    fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  stockData.code ?? '--',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tone.text.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendChartPanel extends StatelessWidget {
  const _TrendChartPanel({
    required this.items,
    required this.activeDate,
    required this.onSelect,
    required this.onHover,
  });

  final List<BoardHeightChartItemData> items;
  final String activeDate;
  final ValueChanged<String> onSelect;
  final ValueChanged<String?> onHover;

  @override
  Widget build(BuildContext context) {
    final activeIndex = items.indexWhere((item) => item.date == activeDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _chartSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '趋势轨道',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF17212B),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '沿着曲线移动即可切换下方联动日期列。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF667085),
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 272,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);

                String dateForOffset(Offset offset) {
                  final index = _chartIndex(size, offset, items.length);
                  return items[index].date;
                }

                return MouseRegion(
                  onExit: (_) => onHover(null),
                  onHover: (event) =>
                      onHover(dateForOffset(event.localPosition)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        onSelect(dateForOffset(details.localPosition)),
                    onPanStart: (details) =>
                        onSelect(dateForOffset(details.localPosition)),
                    onPanUpdate: (details) =>
                        onSelect(dateForOffset(details.localPosition)),
                    child: CustomPaint(
                      painter: _TrendChartPainter(
                        items: items,
                        activeIndex:
                            activeIndex < 0 ? items.length - 1 : activeIndex,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _LegendChip(label: '当前锚点', accent: Color(0xFFFF9800)),
              _LegendChip(label: '梯队强调', accent: Color(0xFFE02828)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF17212B),
                ),
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({
    required this.items,
    required this.activeIndex,
  });

  final List<BoardHeightChartItemData> items;
  final int activeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _plotRect(size);
    final values = items.map((item) => item.value).toList(growable: false);
    final maxValue = math.max(3, values.fold<int>(0, math.max));
    final minValue = math.max(0, values.fold<int>(maxValue, math.min) - 1);
    final points = _plotPoints(rect, values, minValue, maxValue);
    final safeIndex = math.min(math.max(activeIndex, 0), points.length - 1);
    final activePoint = points[safeIndex];

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)),
      Paint()..color = _chartCanvas,
    );

    for (var step = 0; step <= 4; step += 1) {
      final ratio = step / 4;
      final y = ui.lerpDouble(rect.bottom, rect.top, ratio)!;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()
          ..color = _chartGrid
          ..strokeWidth = 1,
      );
      _paintText(
        canvas,
        '${(minValue + ((maxValue - minValue) * ratio)).round()}',
        const TextStyle(
          color: Color(0x99667085),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        Offset(8, y - 8),
      );
    }

    final fill = Path()..moveTo(points.first.dx, rect.bottom);
    for (final point in points) {
      fill.lineTo(point.dx, point.dy);
    }
    fill.lineTo(points.last.dx, rect.bottom);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _chartAccent.withValues(alpha: 0.18),
            _chartAssist.withValues(alpha: 0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = _chartAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawLine(
      Offset(activePoint.dx, rect.top),
      Offset(activePoint.dx, rect.bottom),
      Paint()
        ..color = _chartAssist.withValues(alpha: 0.40)
        ..strokeWidth = 1.2,
    );

    final labelStep = math.max(1, (items.length / 6).ceil());
    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      final tone = _toneForBoard(items[index].value);
      final isActive = index == safeIndex;

      canvas.drawCircle(
        point,
        isActive ? 8 : 5,
        Paint()..color = tone.background,
      );
      canvas.drawCircle(
        point,
        isActive ? 8 : 5,
        Paint()
          ..color = isActive ? const Color(0xFFF2C266) : tone.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 2.6 : 1.8,
      );
      _paintText(
        canvas,
        '${items[index].value}',
        TextStyle(
          color: isActive ? const Color(0xFFC4501C) : tone.text,
          fontSize: isActive ? 12 : 11,
          fontWeight: FontWeight.w700,
        ),
        Offset(point.dx - 10, point.dy - 28),
      );
      if (index % labelStep == 0 || index == points.length - 1) {
        _paintText(
          canvas,
          _shortDate(items[index].date),
          const TextStyle(
            color: Color(0x99667085),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          Offset(point.dx - 18, rect.bottom + 10),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.items != items || oldDelegate.activeIndex != activeIndex;
  }
}

class _MemberTone {
  const _MemberTone({
    required this.background,
    required this.border,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color text;
}

Rect _plotRect(Size size) =>
    Rect.fromLTWH(42, 24, size.width - 66, size.height - 62);

List<Offset> _plotPoints(
    Rect rect, List<int> values, int minValue, int maxValue) {
  if (values.length == 1) {
    return <Offset>[
      Offset(rect.center.dx, _plotY(rect, values.first, minValue, maxValue)),
    ];
  }
  final stepX = rect.width / (values.length - 1);
  return List<Offset>.generate(
    values.length,
    (index) => Offset(
      rect.left + (stepX * index),
      _plotY(rect, values[index], minValue, maxValue),
    ),
    growable: false,
  );
}

double _plotY(Rect rect, int value, int minValue, int maxValue) {
  final range = math.max(1, maxValue - minValue);
  final ratio = (value - minValue) / range;
  return rect.bottom - (rect.height * ratio);
}

int _chartIndex(Size size, Offset offset, int count) {
  if (count <= 1) {
    return 0;
  }
  final rect = _plotRect(size);
  final dx = offset.dx.clamp(rect.left, rect.right).toDouble();
  final ratio = (dx - rect.left) / rect.width;
  return math.min(math.max((ratio * (count - 1)).round(), 0), count - 1);
}

void _paintText(Canvas canvas, String text, TextStyle style, Offset offset) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
}

_MemberTone _toneForBoard(int? boardCount) {
  if (boardCount == null) {
    return const _MemberTone(
      background: Color(0xFFF2F5F8),
      border: Color(0xFF98A2B3),
      text: Color(0xFF667085),
    );
  }
  if (boardCount >= 10) {
    return const _MemberTone(
      background: Color(0xFFFFD7D7),
      border: Color(0xFFE02828),
      text: Color(0xFFB42318),
    );
  }
  if (boardCount >= 7) {
    return const _MemberTone(
      background: Color(0xFFFFD4B8),
      border: Color(0xFFF97316),
      text: Color(0xFFC4501C),
    );
  }
  if (boardCount >= 5) {
    return const _MemberTone(
      background: Color(0xFFFFE8B3),
      border: Color(0xFFFACC15),
      text: Color(0xFF9A6700),
    );
  }
  if (boardCount >= 3) {
    return const _MemberTone(
      background: Color(0xFFB3E0F2),
      border: Color(0xFF60A5FA),
      text: Color(0xFF1D4ED8),
    );
  }
  if (boardCount >= 2) {
    return const _MemberTone(
      background: Color(0xFFE0F7FA),
      border: Color(0xFF5BC0DE),
      text: Color(0xFF00838F),
    );
  }
  return const _MemberTone(
    background: Color(0xFFF2F5F8),
    border: Color(0xFF98A2B3),
    text: Color(0xFF667085),
  );
}

List<String> _splitLeaders(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const <String>[];
  }
  return value
      .replaceAll('\n', '/')
      .split(RegExp(r'[/|,]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

bool _leaderMatch(String stockName, List<String> leaders) {
  for (final leader in leaders) {
    if (stockName.contains(leader) || leader.contains(stockName)) {
      return true;
    }
  }
  return false;
}

String _cleanLeader(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '--';
  }
  return value.replaceAll('\n', ' / ');
}

String _shortDate(String value) =>
    value.length >= 5 ? value.substring(5) : value;

String _fmtTimestamp(String? value) {
  if (value == null || value.isEmpty) {
    return '--';
  }
  return value.replaceFirst('T', ' ').split('.').first;
}
