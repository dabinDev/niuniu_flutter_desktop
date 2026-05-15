import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/application/export_bundle_service.dart';
import '../../../shared/application/stock_link_service.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/data/market_api_provider.dart';
import '../../../shared/data/market_api_repository.dart'
    show KlineBarData, KlineSnapshot;
import '../application/plate_rotation_provider.dart';
import '../data/plate_rotation_repository.dart';

const _rankWidth = 52.0;
const _matrixCellWidth = 68.0;
const _leaderDayWidth = 116.0;
const _matrixHeaderHeight = 30.0;
const _matrixCellHeight = 72.0;
const _matrixGap = 4.0;
const _leaderStockWidth = 220.0;
const _selectedFill = AppTheme.primary;

class PlateRotationPage extends ConsumerStatefulWidget {
  const PlateRotationPage({
    super.key,
    this.initialTradeDate,
  });

  final String? initialTradeDate;

  @override
  ConsumerState<PlateRotationPage> createState() => _PlateRotationPageState();
}

class _PlateRotationPageState extends ConsumerState<PlateRotationPage> {
  final GlobalKey _captureKey = GlobalKey();
  final ScrollController _matrixScrollController = ScrollController();
  final ScrollController _crossDayScrollController = ScrollController();
  bool _isSyncingHorizontalScroll = false;
  int _daysToShow = 20;
  String? _selectedTradeDate;
  String? _selectedPlateName;
  String? _selectedPlateCode;
  String? _selectedDate;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    final normalizedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
    _selectedTradeDate = normalizedTradeDate;
    _selectedDate = normalizedTradeDate;
    _matrixScrollController.addListener(_syncLeaderScrollFromMatrix);
    _crossDayScrollController.addListener(_syncMatrixScrollFromLeader);
  }

  @override
  void didUpdateWidget(covariant PlateRotationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTradeDate != widget.initialTradeDate) {
      final normalizedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
      _selectedTradeDate = normalizedTradeDate;
      _selectedPlateName = null;
      _selectedPlateCode = null;
      _selectedDate = normalizedTradeDate;
    }
  }

  @override
  void dispose() {
    _matrixScrollController.removeListener(_syncLeaderScrollFromMatrix);
    _crossDayScrollController.removeListener(_syncMatrixScrollFromLeader);
    _matrixScrollController.dispose();
    _crossDayScrollController.dispose();
    super.dispose();
  }

  void _syncLeaderScrollFromMatrix() {
    _syncHorizontalScroll(
      source: _matrixScrollController,
      target: _crossDayScrollController,
    );
  }

  void _syncMatrixScrollFromLeader() {
    _syncHorizontalScroll(
      source: _crossDayScrollController,
      target: _matrixScrollController,
    );
  }

  void _syncHorizontalScroll({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_isSyncingHorizontalScroll ||
        !source.hasClients ||
        !target.hasClients) {
      return;
    }
    final targetPosition = target.position;
    final nextOffset = source.offset.clamp(
      targetPosition.minScrollExtent,
      targetPosition.maxScrollExtent,
    );
    if ((target.offset - nextOffset).abs() < 0.5) {
      return;
    }
    _isSyncingHorizontalScroll = true;
    target.jumpTo(nextOffset);
    _isSyncingHorizontalScroll = false;
  }

  String? _normalizeTradeDate(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  List<String> _availableTradeDates(PlateRotationSnapshot snapshot) {
    final source = snapshot.availableTradeDates.isNotEmpty
        ? snapshot.availableTradeDates
        : snapshot.dates;
    return _sortDatesNewestFirst(source);
  }

  List<String> _sortDatesNewestFirst(List<String> dates) {
    final sorted = dates
        .map((date) => date.trim())
        .where((date) => date.isNotEmpty)
        .toSet()
        .toList(growable: false);
    sorted.sort((left, right) => right.compareTo(left));
    return sorted;
  }

  double _alignedDateColumnWidth({
    required double availableWidth,
    required int dateCount,
  }) {
    if (dateCount <= 0) {
      return _matrixCellWidth;
    }
    final gapsWidth = _matrixGap * (dateCount + 1);
    final usableWidth = availableWidth - _rankWidth - gapsWidth;
    return math.max(_matrixCellWidth, usableWidth / dateCount);
  }

  void _selectTradeDate(String? tradeDate) {
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    setState(() {
      _selectedTradeDate = normalizedTradeDate;
      _selectedPlateName = null;
      _selectedPlateCode = null;
      _selectedDate = normalizedTradeDate;
    });
    _syncPlateRotationRoute(normalizedTradeDate);
  }

  void _syncPlateRotationRoute(String? tradeDate) {
    if (!mounted) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    final uri = Uri(
      path: '/plate-rotation',
      queryParameters: normalizedTradeDate == null
          ? null
          : <String, String>{'tradeDate': normalizedTradeDate},
    );
    router.replace(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        plateRotationProvider((limit: 120, tradeDate: _selectedTradeDate));
    final data = ref.watch(provider);

    return AppShell(
      currentPath: '/plate-rotation',
      title: '板块轮动',
      subtitle: '按旧版板块轮动页的习惯组织：先看矩阵强度，再看跨日龙头，最后落到当日行情。',
      child: data.when(
        data: (snapshot) => _buildBody(context, snapshot),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '板块轮动请求失败：$error',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PlateRotationSnapshot snapshot) {
    final dates = _resolveDates(snapshot.dates, _daysToShow);
    final matrix = _buildMatrix(snapshot, dates);
    final selection = _resolveSelection(matrix);
    final selectedSummary = _findSelectedDateSummary(snapshot, selection);
    final frequencyMap = _buildFrequencyMap(matrix);
    final plateStocksAsync = selection.plateCode == null
        ? null
        : ref.watch(
            plateRotationPlateStocksProvider(
              (plateCode: selection.plateCode!, limit: 10),
            ),
          );
    final leaderQuotesAsync =
        selection.plateCode == null || selection.date == null
            ? null
            : ref.watch(
                plateRotationDateLeadersProvider(
                  (
                    plateCode: selection.plateCode!,
                    date: selection.date!,
                    stockLimit: 10,
                  ),
                ),
              );
    final plateStocksSnapshot = plateStocksAsync?.asData?.value;
    final leaderQuotesSnapshot = leaderQuotesAsync?.asData?.value;

    return RepaintBoundary(
      key: _captureKey,
      child: ListView(
        children: [
          _buildSummaryHero(
            context,
            snapshot: snapshot,
            dates: dates,
            matrix: matrix,
            selection: selection,
            selectedSummary: selectedSummary,
            plateStocksSnapshot: plateStocksSnapshot,
            leaderQuotesSnapshot: leaderQuotesSnapshot,
          ),
          const SizedBox(height: 10),
          if (dates.isEmpty || _matrixIsEmpty(matrix))
            _buildEmptyWorkspace(context)
          else
            _buildMatrixWorkspace(
              context,
              dates: dates,
              matrix: matrix,
              frequencyMap: frequencyMap,
              selection: selection,
            ),
          const SizedBox(height: 12),
          _buildLeaderWorkspace(
            context,
            dates: dates,
            selection: selection,
            selectedSummary: selectedSummary,
            plateStocksAsync: plateStocksAsync,
            leaderQuotesAsync: leaderQuotesAsync,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHero(
    BuildContext context, {
    required PlateRotationSnapshot snapshot,
    required List<String> dates,
    required List<List<_MatrixCellData?>> matrix,
    required _SelectedPlate selection,
    required PlateRotationDateSummaryData? selectedSummary,
    required PlateStocksSnapshot? plateStocksSnapshot,
    required PlateLeaderQuotesSnapshot? leaderQuotesSnapshot,
  }) {
    final theme = Theme.of(context);
    final availableTradeDates = _availableTradeDates(snapshot);
    final resolvedTradeDate =
        _normalizeTradeDate(snapshot.tradeDate) ?? _selectedTradeDate;
    final previousTradeDate = snapshot.previousTradeDate;
    final nextTradeDate = snapshot.nextTradeDate;
    final repeatedPlates =
        _buildFrequencyMap(matrix).values.where((v) => v > 0).length;

    final rangeLabel = dates.isEmpty ? '--' : '${dates.first} 至 ${dates.last}';
    final selectionLabel = selection.plateName == null
        ? '未选择'
        : '${selection.plateName}'
            '${selection.date == null ? '' : ' · ${selection.date}'}';
    final selectionDetail = selectedSummary == null
        ? selectionLabel
        : '$selectionLabel · 第 ${selectedSummary.rank ?? '--'} · 涨停 ${selectedSummary.ztCount ?? '--'}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('20 日板块轮动', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '快照 ${_formatTimestamp(snapshot.fetchedAt)}  |  $rangeLabel  |  热点 $repeatedPlates  |  $selectionDetail',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildDayChip(10),
                  _buildDayChip(20),
                  _buildToolbarIconButton(
                    tooltip: '上一日',
                    icon: Icons.chevron_left_rounded,
                    onPressed: previousTradeDate == null
                        ? null
                        : () => _selectTradeDate(previousTradeDate),
                  ),
                  _buildToolbarIconButton(
                    tooltip: '下一日',
                    icon: Icons.chevron_right_rounded,
                    onPressed: nextTradeDate == null
                        ? null
                        : () => _selectTradeDate(nextTradeDate),
                  ),
                  _buildToolbarIconButton(
                    tooltip: '最新',
                    icon: Icons.today_rounded,
                    onPressed: _selectedTradeDate == null
                        ? null
                        : () => _selectTradeDate(null),
                  ),
                  _buildToolbarIconButton(
                    tooltip: _isRefreshing ? '刷新中' : '刷新',
                    icon: Icons.refresh_rounded,
                    onPressed: _isRefreshing ? null : _refreshData,
                  ),
                  _buildToolbarIconButton(
                    tooltip: '复制图片',
                    icon: Icons.image_rounded,
                    onPressed: () => _copyWorkspaceImage(snapshot),
                  ),
                  _buildToolbarIconButton(
                    tooltip: '复制文本',
                    icon: Icons.copy_all_rounded,
                    onPressed: () => _copySnapshotText(
                      snapshot: snapshot,
                      dates: dates,
                      matrix: matrix,
                      selection: selection,
                      plateStocksSnapshot: plateStocksSnapshot,
                      leaderQuotesSnapshot: leaderQuotesSnapshot,
                    ),
                  ),
                  _buildToolbarIconButton(
                    tooltip: '导出 Excel',
                    icon: Icons.table_view_rounded,
                    onPressed: () => _exportExcelSnapshot(
                      snapshot: snapshot,
                      dates: dates,
                      matrix: matrix,
                      selection: selection,
                      plateStocksSnapshot: plateStocksSnapshot,
                      leaderQuotesSnapshot: leaderQuotesSnapshot,
                    ),
                  ),
                  _buildToolbarIconButton(
                    tooltip: '导出 CSV',
                    icon: Icons.download_rounded,
                    onPressed: () => _exportCsvSnapshot(
                      snapshot: snapshot,
                      dates: dates,
                      matrix: matrix,
                      selection: selection,
                      plateStocksSnapshot: plateStocksSnapshot,
                      leaderQuotesSnapshot: leaderQuotesSnapshot,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (availableTradeDates.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('交易日', style: theme.textTheme.labelMedium),
                  const SizedBox(width: 8),
                  ...availableTradeDates.take(8).map(
                        (tradeDate) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            key: ValueKey<String>(
                              'plate-rotation-trade-date-$tradeDate',
                            ),
                            label: Text(tradeDate),
                            selected: resolvedTradeDate == tradeDate,
                            onSelected: (_) => _selectTradeDate(tradeDate),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildTwoDayStrengthBand(
            context,
            dates: dates,
            matrix: matrix,
            selection: selection,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: onPressed != null,
          label: 'pw-plate-rotation-toolbar-$tooltip',
          child: IconButton.filledTonal(
            onPressed: onPressed,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoDayStrengthBand(
    BuildContext context, {
    required List<String> dates,
    required List<List<_MatrixCellData?>> matrix,
    required _SelectedPlate selection,
  }) {
    final theme = Theme.of(context);
    final visibleDates = dates.length <= 2
        ? dates
        : dates.sublist(dates.length - 2).toList(growable: false);
    if (visibleDates.isEmpty) {
      return const SizedBox.shrink();
    }
    final frequencyMap = _buildFrequencyMap(matrix);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('近两日强度板块', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: visibleDates.asMap().entries.map((entry) {
              final date = entry.value;
              final cells = _matrixCellsForDate(matrix, date).take(5).toList();
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: entry.key == visibleDates.length - 1 ? 0 : 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (cells.isEmpty)
                        Text('暂无强度板块', style: theme.textTheme.bodyMedium)
                      else
                        ...cells.map((cell) {
                          final selected =
                              selection.plateName == cell.plateName &&
                                  selection.date == cell.date;
                          final tone = _toneForIndex(
                            frequencyMap[cell.plateName],
                            selected,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Semantics(
                              button: true,
                              label:
                                  'pw-plate-rotation-two-day-${cell.date}-${cell.plateCode ?? cell.plateName}',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  setState(() {
                                    _selectedPlateName = cell.plateName;
                                    _selectedPlateCode = cell.plateCode;
                                    _selectedDate = cell.date;
                                  });
                                },
                                child: Container(
                                  height: 26,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? _selectedToneFill(tone)
                                        : tone.background,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: tone.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        child: Text(
                                          '${cell.rank ?? cells.indexOf(cell) + 1}',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: selected
                                                ? Colors.white
                                                : tone.text,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          cell.plateName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: selected
                                                ? Colors.white
                                                : tone.text,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '涨停 ${cell.ztCount}',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: selected
                                              ? Colors.white
                                                  .withValues(alpha: 0.88)
                                              : tone.text
                                                  .withValues(alpha: 0.86),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(int days) {
    return ChoiceChip(
      label: Text('$days 日'),
      selected: _daysToShow == days,
      onSelected: (_) {
        setState(() {
          _daysToShow = days;
        });
      },
    );
  }

  Widget _buildMatrixWorkspace(
    BuildContext context, {
    required List<String> dates,
    required List<List<_MatrixCellData?>> matrix,
    required Map<String, int> frequencyMap,
    required _SelectedPlate selection,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
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
                    Text('20 日轮动矩阵', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '重复出现的板块会保持同色系。点击任意单元格即可同时锁定板块和交易日。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (selection.plateName != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryOutline),
                  ),
                  child: Text(
                    selection.date == null
                        ? selection.plateName!
                        : '${selection.plateName!}  |  ${selection.date!}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final matrixCellWidth = dates.isEmpty
                  ? _matrixCellWidth
                  : _alignedDateColumnWidth(
                      availableWidth: constraints.maxWidth,
                      dateCount: dates.length,
                    );
              return Scrollbar(
                thumbVisibility: true,
                controller: _matrixScrollController,
                child: SingleChildScrollView(
                  controller: _matrixScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _HeaderCell(
                            width: _rankWidth,
                            label: '排名',
                            selected: false,
                          ),
                          ...dates.map(
                            (date) => _HeaderCell(
                              width: matrixCellWidth,
                              label:
                                  date.length >= 5 ? date.substring(5) : date,
                              selected: selection.date == date,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: _matrixGap),
                      ...List.generate(matrix.length, (rowIndex) {
                        final row = matrix[rowIndex];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: _matrixGap),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _RankCell(rank: rowIndex + 1, width: _rankWidth),
                              ...row.map(
                                (cell) => _buildMatrixCell(
                                  context,
                                  width: matrixCellWidth,
                                  cell: cell,
                                  toneIndex: cell == null
                                      ? null
                                      : frequencyMap[cell.plateName],
                                  selection: selection,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixCell(
    BuildContext context, {
    required double width,
    required _MatrixCellData? cell,
    required int? toneIndex,
    required _SelectedPlate selection,
  }) {
    final theme = Theme.of(context);
    final isSamePlate = cell != null && selection.plateName == cell.plateName;
    final isSelectedCell = cell != null &&
        selection.plateName == cell.plateName &&
        selection.date == cell.date;
    final tone = _toneForIndex(toneIndex, isSamePlate);

    if (cell == null) {
      return Container(
        width: width,
        height: _matrixCellHeight,
        margin: const EdgeInsets.only(right: _matrixGap),
        decoration: BoxDecoration(
          color: AppTheme.surfaceSoft.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
      );
    }

    final semanticLabel =
        'pw-plate-rotation-cell-${cell.date}-${cell.plateCode ?? cell.plateName}';
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Container(
        key: ValueKey<String>(
          'plate-rotation-matrix-${cell.date}-${cell.plateCode ?? cell.plateName}',
        ),
        width: width,
        height: _matrixCellHeight,
        margin: const EdgeInsets.only(right: _matrixGap),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(3),
            onTap: () {
              setState(() {
                _selectedPlateName = cell.plateName;
                _selectedPlateCode = cell.plateCode;
                _selectedDate = cell.date;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color:
                    isSelectedCell ? _selectedToneFill(tone) : tone.background,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: isSelectedCell
                      ? tone.border
                      : selection.date == cell.date
                          ? tone.text.withValues(alpha: 0.72)
                          : tone.border.withValues(alpha: 0.74),
                  width: isSelectedCell ? 1.6 : 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cell.plateName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelectedCell ? Colors.white : tone.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isSelectedCell)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '涨停 ${cell.ztCount}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isSelectedCell ? Colors.white : tone.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    cell.strengthText ?? '--',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelectedCell
                          ? Colors.white.withValues(alpha: 0.86)
                          : tone.text.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderWorkspace(
    BuildContext context, {
    required List<String> dates,
    required _SelectedPlate selection,
    required PlateRotationDateSummaryData? selectedSummary,
    required AsyncValue<PlateStocksSnapshot>? plateStocksAsync,
    required AsyncValue<PlateLeaderQuotesSnapshot>? leaderQuotesAsync,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
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
                    Text('龙头联动', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      selection.plateName == null
                          ? '先从上方矩阵里选择一个板块，再加载对应跨日龙头。'
                          : _formatLeaderSummaryIntro(
                              selection,
                              selectedSummary,
                            ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (selection.plateCode != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryOutline),
                  ),
                  child: Text(
                    selection.date == null
                        ? selection.plateCode!
                        : '${selection.plateCode!}  |  ${selection.date!}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (selection.plateName == null)
            _buildMessageBlock(context, '先从上方矩阵里选择一个板块。')
          else if (selection.plateCode == null)
            _buildMessageBlock(
              context,
              '当前快照里的板块没有稳定代码，暂时无法请求联动龙头。',
            )
          else if (plateStocksAsync == null)
            _buildMessageBlock(context, '还没有发起板块龙头请求。')
          else
            plateStocksAsync.when(
              data: (snapshot) {
                final groups = _buildStockGroups(snapshot, dates);
                final hasAnyStocks =
                    groups.any((group) => group.stocks.isNotEmpty);
                if (!hasAnyStocks) {
                  return _buildMessageBlock(
                    context,
                    '该板块暂未返回跨日龙头数据。',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCrossDayLeaderRow(
                      context,
                      groups: groups,
                      selection: selection,
                    ),
                    const SizedBox(height: 18),
                    _buildSelectedDateQuotePanel(
                      context,
                      selection: selection,
                      leaderQuotesAsync: leaderQuotesAsync,
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _buildMessageBlock(
                context,
                '板块个股请求失败：$error',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCrossDayLeaderRow(
    BuildContext context, {
    required List<PlateStockDateGroupData> groups,
    required _SelectedPlate selection,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('领涨日期带', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final dayWidth = _alignedDateColumnWidth(
              availableWidth: constraints.maxWidth,
              dateCount: groups.length,
            );
            return Scrollbar(
              thumbVisibility: true,
              controller: _crossDayScrollController,
              child: SingleChildScrollView(
                controller: _crossDayScrollController,
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _HeaderCell(
                          width: _rankWidth,
                          label: '领涨',
                          selected: false,
                        ),
                        ...groups.map(
                          (group) => _HeaderCell(
                            width: dayWidth,
                            label: _formatBarDate(group.date),
                            selected: selection.date == group.date,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _matrixGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LeaderBandLeadCell(
                          plateName: selection.plateName ?? '--',
                          width: _rankWidth,
                        ),
                        ...groups.map(
                          (group) => _LeaderBandDateCell(
                            group: group,
                            width: dayWidth,
                            selected: selection.date == group.date,
                            onTap: () {
                              setState(() {
                                _selectedDate = group.date;
                              });
                            },
                            onOpenStock: _openStock,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildCrossDayLeaderCards(
    BuildContext context, {
    required List<PlateStockDateGroupData> groups,
    required _SelectedPlate selection,
  }) {
    final theme = Theme.of(context);
    return Scrollbar(
      thumbVisibility: true,
      controller: _crossDayScrollController,
      child: SingleChildScrollView(
        controller: _crossDayScrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _rankWidth,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '龙头',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '分日',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.84),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ...groups.map(
              (group) => _CrossDayColumn(
                group: group,
                selected: selection.date == group.date,
                onTap: () {
                  setState(() {
                    _selectedDate = group.date;
                  });
                },
                onOpenStock: _openStock,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDateQuotePanel(
    BuildContext context, {
    required _SelectedPlate selection,
    required AsyncValue<PlateLeaderQuotesSnapshot>? leaderQuotesAsync,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当日行情', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            selection.date == null
                ? '先点矩阵单元或上方龙头列，再加载所选日期的批量行情。'
                : '${selection.plateName ?? '--'} 在 ${selection.date!} 的行情快照。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (selection.date == null)
            _buildMessageBlock(context, '还没有锁定交易日。')
          else if (leaderQuotesAsync == null)
            _buildMessageBlock(context, '还没有发起当日行情请求。')
          else
            leaderQuotesAsync.when(
              data: (snapshot) {
                if (snapshot.leaders.isEmpty) {
                  return _buildMessageBlock(
                    context,
                    '所选日期暂未返回批量行情数据。',
                  );
                }
                return _LeaderQuoteTable(
                  snapshot: snapshot,
                  onLeaderTap: (item) => _openLeaderDetailSheet(context, item),
                  onOpenStock: _openStock,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _buildMessageBlock(
                context,
                '当日龙头行情请求失败：$error',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBlock(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge,
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
        '当前快照暂无可展示的轮动矩阵。',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) {
      return;
    }
    final provider =
        plateRotationProvider((limit: 120, tradeDate: _selectedTradeDate));

    setState(() {
      _isRefreshing = true;
    });
    try {
      ref.invalidate(provider);

      final plateCode = _selectedPlateCode;
      final date = _selectedDate;
      if (plateCode != null) {
        ref.invalidate(
          plateRotationPlateStocksProvider((plateCode: plateCode, limit: 10)),
        );
        if (date != null) {
          ref.invalidate(
            plateRotationDateLeadersProvider(
              (plateCode: plateCode, date: date, stockLimit: 10),
            ),
          );
        }
      }

      await ref.read(provider.future);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _copyWorkspaceImage(PlateRotationSnapshot snapshot) async {
    final pngBytes = await _captureWorkspacePng();
    if (pngBytes == null) {
      _showInfo('板块轮动图片生成失败。');
      return;
    }

    final filePath = await writeBinaryFile(
      bundleName: 'plate_rotation_snapshot_image',
      fileName: 'plate_rotation_${snapshot.tradeDate ?? 'snapshot'}.png',
      bytes: pngBytes,
    );

    final copied = await _copyImageToClipboard(filePath);
    if (!mounted) {
      return;
    }
    if (copied) {
      _showInfo('板块轮动图片已复制到剪贴板：$filePath');
      return;
    }

    _showInfo('板块轮动 PNG 已保存：$filePath');
  }

  Future<void> _copySnapshotText({
    required PlateRotationSnapshot snapshot,
    required List<String> dates,
    required List<List<_MatrixCellData?>> matrix,
    required _SelectedPlate selection,
    required PlateStocksSnapshot? plateStocksSnapshot,
    required PlateLeaderQuotesSnapshot? leaderQuotesSnapshot,
  }) async {
    final selectedSummary = _findSelectedDateSummary(snapshot, selection);
    final buffer = StringBuffer()
      ..writeln('板块轮动')
      ..writeln('交易日：${snapshot.tradeDate ?? '--'}')
      ..writeln('快照：${_formatTimestamp(snapshot.fetchedAt)}')
      ..writeln('展示日期数：${dates.length}')
      ..writeln(
        '选中板块：${selection.plateName ?? '--'}'
        ' | ${selection.plateCode ?? '--'}'
        ' | ${selection.date ?? '--'}',
      )
      ..writeln()
      ..writeln(
        '接口摘要：${selectedSummary == null ? '--' : _formatSelectedSummaryCaption(selection, selectedSummary)}',
      )
      ..writeln()
      ..writeln('[轮动矩阵]')
      ..writeln(['排名', ...dates].join('\t'));

    for (var rowIndex = 0; rowIndex < matrix.length; rowIndex++) {
      final row = matrix[rowIndex];
      final cells = <String>['${rowIndex + 1}'];
      for (final cell in row) {
        cells.add(cell == null ? '--' : '${cell.plateName} (${cell.ztCount})');
      }
      buffer.writeln(cells.join('\t'));
    }

    buffer
      ..writeln()
      ..writeln('[板块序列]');
    for (final item in snapshot.items) {
      for (final point in item.series) {
        buffer.writeln(
          '${item.plateCode ?? '--'}\t${item.plateName}\t${point.date}\t'
          '${point.ztCount ?? 0}\t${point.strengthText ?? '--'}',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('[选中板块龙头]');
    if (plateStocksSnapshot == null) {
      buffer.writeln('未加载');
    } else {
      for (final group in plateStocksSnapshot.items) {
        buffer.writeln(group.date);
        for (final stock in group.stocks) {
          buffer.writeln(
            '${stock.rankNo}\t${stock.stockCode}\t${stock.stockName}',
          );
        }
        buffer.writeln();
      }
    }

    buffer.writeln('[选中日期行情]');
    if (leaderQuotesSnapshot == null) {
      buffer.writeln('未加载');
    } else {
      for (final leader in leaderQuotesSnapshot.leaders) {
        buffer.writeln(
          '${leader.rankNo}\t${leader.stockCode}\t${leader.stockName}\t'
          '${_fmtNumber(leader.quote?.price)}\t${_fmtSignedPct(leader.quote?.changePct)}\t'
          '${_fmtAmount(leader.quote?.amount)}',
        );
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    _showInfo('板块轮动文本已复制到剪贴板。');
  }

  Future<void> _exportExcelSnapshot({
    required PlateRotationSnapshot snapshot,
    required List<String> dates,
    required List<List<_MatrixCellData?>> matrix,
    required _SelectedPlate selection,
    required PlateStocksSnapshot? plateStocksSnapshot,
    required PlateLeaderQuotesSnapshot? leaderQuotesSnapshot,
  }) async {
    final filePath = await writeExcelWorkbook(
      bundleName: 'plate_rotation_excel',
      fileName: 'plate_rotation_${snapshot.tradeDate ?? 'snapshot'}.xlsx',
      sheets: _buildExportSheets(
        snapshot: snapshot,
        dates: dates,
        matrix: matrix,
        selection: selection,
        plateStocksSnapshot: plateStocksSnapshot,
        leaderQuotesSnapshot: leaderQuotesSnapshot,
      )
          .entries
          .map(
            (entry) => ExcelSheetData(
              name: entry.key,
              rows: entry.value,
            ),
          )
          .toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    _showInfo('板块轮动 Excel 已导出：$filePath');
  }

  Future<void> _exportCsvSnapshot({
    required PlateRotationSnapshot snapshot,
    required List<String> dates,
    required List<List<_MatrixCellData?>> matrix,
    required _SelectedPlate selection,
    required PlateStocksSnapshot? plateStocksSnapshot,
    required PlateLeaderQuotesSnapshot? leaderQuotesSnapshot,
  }) async {
    final result = await writeCsvBundle(
      bundleName: 'plate_rotation_snapshot',
      files: _buildExportSheets(
        snapshot: snapshot,
        dates: dates,
        matrix: matrix,
        selection: selection,
        plateStocksSnapshot: plateStocksSnapshot,
        leaderQuotesSnapshot: leaderQuotesSnapshot,
      ),
    );
    if (!mounted) {
      return;
    }
    _showInfo('板块轮动 CSV 已导出：${result.directoryPath}');
  }

  Map<String, List<List<String>>> _buildExportSheets({
    required PlateRotationSnapshot snapshot,
    required List<String> dates,
    required List<List<_MatrixCellData?>> matrix,
    required _SelectedPlate selection,
    required PlateStocksSnapshot? plateStocksSnapshot,
    required PlateLeaderQuotesSnapshot? leaderQuotesSnapshot,
  }) {
    final files = <String, List<List<String>>>{
      'summary': [
        ['trade_date', snapshot.tradeDate ?? '--'],
        ['fetched_at', _formatTimestamp(snapshot.fetchedAt)],
        ['displayed_dates', '${dates.length}'],
        ['total_plates', '${snapshot.total}'],
        ['selection_plate_name', selection.plateName ?? '--'],
        ['selection_plate_code', selection.plateCode ?? '--'],
        ['selection_date', selection.date ?? '--'],
      ],
      'matrix': _matrixCsvRows(dates, matrix),
      'plate_series': [
        [
          'plate_code',
          'plate_name',
          'latest_zt',
          'latest_strength_text',
          'date',
          'zt_count',
          'strength',
          'strength_text',
        ],
        ...snapshot.items.expand(
          (item) => item.series.map(
            (point) => [
              item.plateCode ?? '--',
              item.plateName,
              '${item.latestZt ?? 0}',
              item.latestStrengthText ?? '--',
              point.date,
              '${point.ztCount ?? 0}',
              point.strength?.toString() ?? '--',
              point.strengthText ?? '--',
            ],
          ),
        ),
      ],
      'plate_date_summaries': [
        [
          'date',
          'plate_code',
          'plate_name',
          'rank',
          'zt_count',
          'strength',
          'strength_text',
          'latest_zt',
          'latest_strength_text',
          'is_matrix_top',
          'leader_total',
          'leaders_preview',
        ],
        ...snapshot.plateDateSummaries.map(
          (summary) => [
            summary.date,
            summary.plateCode ?? '--',
            summary.plateName,
            '${summary.rank ?? 0}',
            '${summary.ztCount ?? 0}',
            summary.strength?.toString() ?? '--',
            summary.strengthText ?? '--',
            '${summary.latestZt ?? 0}',
            summary.latestStrengthText ?? '--',
            summary.isMatrixTop ? '1' : '0',
            '${summary.leaderTotal}',
            summary.leadersPreview
                .map(
                  (leader) =>
                      '${leader.rankNo}:${leader.stockCode}:${leader.stockName}',
                )
                .join(' | '),
          ],
        ),
      ],
    };

    if (plateStocksSnapshot != null) {
      files['selected_plate_leaders'] = [
        [
          'plate_code',
          'plate_name',
          'date',
          'rank_no',
          'stock_code',
          'stock_name',
        ],
        ...plateStocksSnapshot.items.expand(
          (group) => group.stocks.map(
            (stock) => [
              plateStocksSnapshot.plateCode,
              plateStocksSnapshot.plateName ?? '--',
              group.date,
              '${stock.rankNo}',
              stock.stockCode,
              stock.stockName,
            ],
          ),
        ),
      ];
    }

    if (leaderQuotesSnapshot != null) {
      files['selected_date_quotes'] = [
        [
          'plate_code',
          'plate_name',
          'date',
          'rank_no',
          'stock_code',
          'stock_name',
          'price',
          'open',
          'change_pct',
          'amplitude',
          'amount',
        ],
        ...leaderQuotesSnapshot.leaders.map(
          (leader) => [
            leaderQuotesSnapshot.plateCode,
            leaderQuotesSnapshot.plateName ?? '--',
            leaderQuotesSnapshot.date ?? '--',
            '${leader.rankNo}',
            leader.stockCode,
            leader.stockName,
            leader.quote?.price?.toString() ?? '--',
            leader.quote?.open?.toString() ?? '--',
            leader.quote?.changePct?.toString() ?? '--',
            leader.quote?.amplitude?.toString() ?? '--',
            leader.quote?.amount?.toString() ?? '--',
          ],
        ),
      ];
    }

    return files;
  }

  List<List<String>> _matrixCsvRows(
    List<String> dates,
    List<List<_MatrixCellData?>> matrix,
  ) {
    return [
      ['rank', ...dates],
      ...List.generate(
        matrix.length,
        (rowIndex) => [
          '${rowIndex + 1}',
          ...matrix[rowIndex].map(
            (cell) => cell == null ? '' : '${cell.plateName} (${cell.ztCount})',
          ),
        ],
      ),
    ];
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
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

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

    final heightScaleCap =
        boundary.size.height <= 0 ? 1.0 : 3000 / boundary.size.height;
    final pixelRatio = math.min(
      math.min(devicePixelRatio, 2.0),
      heightScaleCap <= 0 ? 1.0 : heightScaleCap,
    );

    final image = await boundary.toImage(
      pixelRatio: pixelRatio <= 0 ? 1.0 : pixelRatio,
    );
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

  bool _matrixIsEmpty(List<List<_MatrixCellData?>> matrix) {
    for (final row in matrix) {
      for (final cell in row) {
        if (cell != null) {
          return false;
        }
      }
    }
    return true;
  }

  List<String> _resolveDates(List<String> dates, int daysToShow) {
    final sortedDates = _sortDatesNewestFirst(dates);
    if (daysToShow <= 0 || sortedDates.length <= daysToShow) {
      return sortedDates;
    }
    return sortedDates.take(daysToShow).toList(growable: false);
  }

  List<List<_MatrixCellData?>> _buildMatrix(
    PlateRotationSnapshot snapshot,
    List<String> dates,
  ) {
    final apiMatrix = _buildMatrixFromColumns(snapshot.matrixColumns, dates);
    if (!_matrixIsEmpty(apiMatrix)) {
      return apiMatrix;
    }

    final byDate = <String, List<_MatrixCellData>>{};

    for (final date in dates) {
      final cells = <_MatrixCellData>[];
      for (final item in snapshot.items) {
        PlateRotationPointData? point;
        for (final series in item.series) {
          if (series.date == date) {
            point = series;
            break;
          }
        }
        if (point == null || point.ztCount == null) {
          continue;
        }
        cells.add(
          _MatrixCellData(
            plateName: item.plateName,
            plateCode: item.plateCode,
            ztCount: point.ztCount!,
            strength: point.strength,
            strengthText: point.strengthText,
            date: date,
          ),
        );
      }
      cells.sort((left, right) {
        final ztCompare = right.ztCount.compareTo(left.ztCount);
        if (ztCompare != 0) {
          return ztCompare;
        }
        return (right.strength ?? 0).compareTo(left.strength ?? 0);
      });
      byDate[date] = cells.take(10).toList(growable: false);
    }

    return List.generate(
      10,
      (rankIndex) => dates
          .map(
            (date) => rankIndex < (byDate[date]?.length ?? 0)
                ? byDate[date]![rankIndex].copyWith(rank: rankIndex + 1)
                : null,
          )
          .toList(growable: false),
      growable: false,
    );
  }

  List<List<_MatrixCellData?>> _buildMatrixFromColumns(
    List<PlateRotationMatrixColumnData> columns,
    List<String> dates,
  ) {
    if (columns.isEmpty) {
      return const <List<_MatrixCellData?>>[];
    }

    final byDate = <String, List<PlateRotationMatrixCellData>>{
      for (final column in columns) column.date: column.items,
    };
    return List.generate(
      10,
      (rankIndex) => dates.map((date) {
        final items = byDate[date] ?? const <PlateRotationMatrixCellData>[];
        if (rankIndex >= items.length) {
          return null;
        }
        final item = items[rankIndex];
        final ztCount = item.ztCount;
        if (ztCount == null) {
          return null;
        }
        return _MatrixCellData(
          plateName: item.plateName,
          plateCode: item.plateCode,
          ztCount: ztCount,
          strength: item.strength,
          strengthText: item.strengthText,
          date: date,
          rank: item.rank == 0 ? rankIndex + 1 : item.rank,
        );
      }).toList(growable: false),
      growable: false,
    );
  }

  Map<String, int> _buildFrequencyMap(List<List<_MatrixCellData?>> matrix) {
    final counts = <String, int>{};
    for (final row in matrix) {
      for (final cell in row.whereType<_MatrixCellData>()) {
        counts.update(cell.plateName, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final sorted = counts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final mapping = <String, int>{};
    for (var index = 0; index < sorted.length; index++) {
      mapping[sorted[index].key] = math.min(index, 5);
    }
    return mapping;
  }

  List<_MatrixCellData> _matrixCellsForDate(
    List<List<_MatrixCellData?>> matrix,
    String date,
  ) {
    final cells = <_MatrixCellData>[];
    for (final row in matrix) {
      for (final cell in row.whereType<_MatrixCellData>()) {
        if (cell.date == date) {
          cells.add(cell);
        }
      }
    }
    cells.sort((left, right) {
      final leftRank = left.rank ?? 999;
      final rightRank = right.rank ?? 999;
      final rankCompare = leftRank.compareTo(rightRank);
      if (rankCompare != 0) {
        return rankCompare;
      }
      return right.ztCount.compareTo(left.ztCount);
    });
    return cells;
  }

  _SelectedPlate _resolveSelection(List<List<_MatrixCellData?>> matrix) {
    final available = matrix
        .expand((row) => row)
        .whereType<_MatrixCellData>()
        .toList(growable: false);
    if (available.isEmpty) {
      return const _SelectedPlate();
    }
    final resolvedDate = available.any((cell) => cell.date == _selectedDate)
        ? _selectedDate
        : null;

    for (final cell in available) {
      if (_selectedPlateCode != null &&
          _selectedPlateCode == cell.plateCode &&
          resolvedDate != null &&
          resolvedDate == cell.date) {
        return _SelectedPlate(
          plateName: cell.plateName,
          plateCode: cell.plateCode,
          date: cell.date,
        );
      }
    }

    for (final cell in available) {
      if (_selectedPlateCode != null && _selectedPlateCode == cell.plateCode) {
        return _SelectedPlate(
          plateName: cell.plateName,
          plateCode: cell.plateCode,
          date: resolvedDate ?? cell.date,
        );
      }
    }

    for (final cell in available) {
      if (_selectedPlateName != null && _selectedPlateName == cell.plateName) {
        return _SelectedPlate(
          plateName: cell.plateName,
          plateCode: cell.plateCode,
          date: resolvedDate ?? cell.date,
        );
      }
    }

    final first = available.first;
    return _SelectedPlate(
      plateName: first.plateName,
      plateCode: first.plateCode,
      date: resolvedDate ?? first.date,
    );
  }

  List<PlateStockDateGroupData> _buildStockGroups(
    PlateStocksSnapshot snapshot,
    List<String> dates,
  ) {
    final byDate = <String, PlateStockDateGroupData>{
      for (final item in snapshot.items) item.date: item,
    };
    return dates
        .map(
          (date) =>
              byDate[date] ??
              PlateStockDateGroupData(
                date: date,
                total: 0,
                stocks: const [],
              ),
        )
        .toList(growable: false);
  }

  PlateRotationDateSummaryData? _findSelectedDateSummary(
    PlateRotationSnapshot snapshot,
    _SelectedPlate selection,
  ) {
    if (selection.date == null || snapshot.plateDateSummaries.isEmpty) {
      return null;
    }

    for (final summary in snapshot.plateDateSummaries) {
      if (summary.date != selection.date) {
        continue;
      }
      if (_plateCodeMatches(summary.plateCode, selection.plateCode)) {
        return summary;
      }
    }

    for (final summary in snapshot.plateDateSummaries) {
      if (summary.date == selection.date &&
          summary.plateName == selection.plateName) {
        return summary;
      }
    }
    return null;
  }

  bool _plateCodeMatches(String? left, String? right) {
    final leftKey = _normalizePlateCodeKey(left);
    final rightKey = _normalizePlateCodeKey(right);
    return leftKey != null && rightKey != null && leftKey == rightKey;
  }

  String? _normalizePlateCodeKey(String? value) {
    final normalized = value?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final withoutPrefix =
        normalized.startsWith('BK') ? normalized.substring(2) : normalized;
    final withoutZeros = withoutPrefix.replaceFirst(RegExp(r'^0+'), '');
    return withoutZeros.isEmpty ? normalized : withoutZeros;
  }

  String _formatSelectedSummaryCaption(
    _SelectedPlate selection,
    PlateRotationDateSummaryData? summary,
  ) {
    if (summary == null) {
      return selection.date == null
          ? (selection.plateCode ?? '等待有效板块代码')
          : '${selection.date}  |  ${selection.plateCode ?? '--'}';
    }

    final parts = <String>[
      selection.date ?? summary.date,
      selection.plateCode ?? summary.plateCode ?? '--',
      '排名 ${summary.rank ?? '--'}',
      '涨停 ${summary.ztCount ?? '--'}',
    ];
    if (summary.leaderTotal > 0) {
      parts.add('龙头 ${summary.leaderTotal}');
    }
    return parts.join('  |  ');
  }

  String _formatLeaderSummaryIntro(
    _SelectedPlate selection,
    PlateRotationDateSummaryData? summary,
  ) {
    final base = '${selection.plateName} 的跨日龙头列表，以及所选日期的行情细节。';
    if (summary == null) {
      return base;
    }

    final leaderPreview = summary.leadersPreview
        .take(3)
        .map((item) => item.stockName)
        .where((name) => name.trim().isNotEmpty && name != '--')
        .join('、');
    final leaderText = summary.leaderTotal <= 0
        ? '暂未返回龙头预览'
        : '龙头 ${summary.leaderTotal} 个'
            '${leaderPreview.isEmpty ? '' : '：$leaderPreview'}';
    return '$base 接口摘要：排名 ${summary.rank ?? '--'}，涨停 ${summary.ztCount ?? '--'}，$leaderText。';
  }

  Future<void> _openLeaderDetailSheet(
    BuildContext context,
    PlateLeaderQuoteItemData item,
  ) async {
    final klineFuture = ref.read(marketApiRepositoryProvider).fetchKline(
          item.stockCode,
          days: 21,
        );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _LeaderDetailSheet(
        item: item,
        klineFuture: klineFuture,
        onOpenStock: () => _openStock(item.stockCode),
      ),
    );
  }

  Future<void> _openStock(String code) async {
    await openStockLinkFromUi(
      context: context,
      ref: ref,
      code: code,
    );
  }

  _PlateTone _toneForIndex(int? index, bool isSelected) {
    const tones = [
      _PlateTone(
        background: Color(0xFFFFB3B8),
        border: Color(0xFFFF7783),
        text: Color(0xFFC41D24),
      ),
      _PlateTone(
        background: Color(0xFFFFD4B8),
        border: Color(0xFFFD9A66),
        text: Color(0xFFC4501C),
      ),
      _PlateTone(
        background: Color(0xFFFFE8B3),
        border: Color(0xFFF3C14C),
        text: Color(0xFFC47605),
      ),
      _PlateTone(
        background: Color(0xFFB3E0F2),
        border: Color(0xFF5BC0DE),
        text: Color(0xFF2980B9),
      ),
      _PlateTone(
        background: Color(0xFFE8E8E8),
        border: Color(0xFFBDBDBD),
        text: Color(0xFF555555),
      ),
      _PlateTone(
        background: Color(0xFFE0F7FA),
        border: Color(0xFFB9E3DA),
        text: Color(0xFF00838F),
      ),
    ];

    final base =
        index == null ? null : tones[math.min(index, tones.length - 1)];
    if (base == null) {
      return isSelected
          ? const _PlateTone(
              background: AppTheme.primarySoft,
              border: AppTheme.primary,
              text: AppTheme.primary,
            )
          : const _PlateTone(
              background: AppTheme.surfaceSoft,
              border: AppTheme.outline,
              text: AppTheme.text,
            );
    }

    if (!isSelected) {
      return base;
    }

    return _PlateTone(
      background: base.background,
      border: base.text,
      text: base.text,
    );
  }

  String _formatTimestamp(String? value) {
    if (value == null || value.isEmpty) {
      return '--';
    }
    return value.replaceFirst('T', ' ').split('.').first;
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.width,
    required this.label,
    required this.selected,
  });

  final double width;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: _matrixHeaderHeight,
      margin: const EdgeInsets.only(right: _matrixGap),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _selectedFill : AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: selected ? AppTheme.primaryOutline : AppTheme.outline,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: selected ? Colors.white : null,
        ),
      ),
    );
  }
}

class _RankCell extends StatelessWidget {
  const _RankCell({
    required this.rank,
    required this.width,
  });

  final int rank;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (rank) {
      1 => AppTheme.rise,
      2 => AppTheme.secondary,
      3 => AppTheme.primary,
      _ => theme.colorScheme.primary.withValues(alpha: 0.12),
    };

    return Container(
      width: width,
      height: _matrixCellHeight,
      margin: const EdgeInsets.only(right: _matrixGap),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: theme.textTheme.titleMedium?.copyWith(
          color: rank <= 3 ? Colors.white : theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _LeaderBandLeadCell extends StatelessWidget {
  const _LeaderBandLeadCell({
    required this.plateName,
    required this.width,
  });

  final String plateName;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: 190,
      margin: const EdgeInsets.only(right: _matrixGap),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '领涨',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              plateName,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderBandDateCell extends StatelessWidget {
  const _LeaderBandDateCell({
    required this.group,
    required this.width,
    required this.selected,
    required this.onTap,
    required this.onOpenStock,
  });

  final PlateStockDateGroupData group;
  final double width;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String> onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = selected ? Colors.white : AppTheme.text;
    final mutedColor =
        selected ? Colors.white.withValues(alpha: 0.76) : AppTheme.mutedText;

    return Semantics(
      button: true,
      label: 'pw-plate-rotation-leader-band-date-${group.date}',
      child: Container(
        key: ValueKey('plate-rotation-leader-band-${group.date}'),
        width: width,
        height: 190,
        margin: const EdgeInsets.only(right: _matrixGap),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? _selectedFill : AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected
                      ? _selectedFill
                      : theme.colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: group.stocks.isEmpty
                  ? Center(
                      child: Text(
                        '当日无领涨',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mutedColor,
                        ),
                      ),
                    )
                  : Column(
                      children: group.stocks.take(5).map((stock) {
                        final canOpenStock =
                            RegExp(r'^\d{6}$').hasMatch(stock.stockCode);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Semantics(
                            button: canOpenStock,
                            enabled: canOpenStock,
                            label:
                                '打开股票 pw-plate-rotation-leader-${stock.stockCode}',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: canOpenStock
                                  ? () => onOpenStock(stock.stockCode)
                                  : null,
                              child: Container(
                                height: 32,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.14)
                                      : Colors.white.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.16)
                                          : theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      child: Text(
                                        '${stock.rankNo}',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: selected
                                              ? Colors.white
                                              : AppTheme.danger,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        stock.stockName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    ExcludeSemantics(
                                      child: Icon(
                                        Icons.open_in_new_rounded,
                                        size: 15,
                                        color: selected
                                            ? Colors.white
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossDayColumn extends StatelessWidget {
  const _CrossDayColumn({
    required this.group,
    required this.selected,
    required this.onTap,
    required this.onOpenStock,
  });

  final PlateStockDateGroupData group;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String> onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: _leaderDayWidth,
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? _selectedFill : AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    selected ? _selectedFill : theme.colorScheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.date.length >= 5 ? group.date.substring(5) : group.date,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: selected ? Colors.white : AppTheme.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${group.total} 只',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        selected ? Colors.white.withValues(alpha: 0.82) : null,
                  ),
                ),
                const SizedBox(height: 12),
                if (group.stocks.isEmpty)
                  Text(
                    '暂无龙头',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.82)
                          : null,
                    ),
                  )
                else
                  ...group.stocks.take(5).map((stock) {
                    final canOpenStock =
                        RegExp(r'^\d{6}$').hasMatch(stock.stockCode);
                    final openSemanticsLabel =
                        'pw-plate-rotation-stock-open-${group.date}-${stock.stockCode}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.14)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.16)
                              : AppTheme.outline,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : AppTheme.secondary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${stock.rankNo}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stock.stockName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: selected ? Colors.white : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  stock.stockCode,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: selected
                                        ? Colors.white.withValues(alpha: 0.82)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tooltip(
                            message: '打开股票',
                            child: Semantics(
                              button: canOpenStock,
                              enabled: canOpenStock,
                              label: openSemanticsLabel,
                              child: IconButton(
                                onPressed: canOpenStock
                                    ? () => onOpenStock(stock.stockCode)
                                    : null,
                                tooltip: '打开股票',
                                constraints: const BoxConstraints.tightFor(
                                  width: 34,
                                  height: 34,
                                ),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18,
                                  color: selected
                                      ? Colors.white
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderQuoteTable extends StatelessWidget {
  const _LeaderQuoteTable({
    required this.snapshot,
    required this.onLeaderTap,
    required this.onOpenStock,
  });

  final PlateLeaderQuotesSnapshot snapshot;
  final ValueChanged<PlateLeaderQuoteItemData> onLeaderTap;
  final ValueChanged<String> onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoTag(
                label: '板块', value: snapshot.plateName ?? snapshot.plateCode),
            _InfoTag(label: '日期', value: snapshot.date ?? '--'),
            _InfoTag(label: '行数', value: '${snapshot.total}'),
            _InfoTag(
              label: '行情同步',
              value: _formatShortTimestamp(
                  snapshot.quoteFetchedAt ?? snapshot.fetchedAt),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '点击任意龙头行可展开 21 日个股详情，也可以用联动按钮直接跳转到已配置客户端。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const baseTableWidth = 820.0;
            const fixedColumnsWidth = 54.0 + 88.0 * 4 + 110.0 + 56.0 + 28.0;
            final tableWidth = math.max(baseTableWidth, constraints.maxWidth);
            final stockWidth = math.max(
              _leaderStockWidth,
              tableWidth - fixedColumnsWidth,
            );

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: tableWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Row(
                        children: [
                          _headerText(context, '排名', width: 54),
                          _headerText(context, '个股', width: stockWidth),
                          _headerText(context, '现价'),
                          _headerText(context, '开盘'),
                          _headerText(context, '涨幅'),
                          _headerText(context, '振幅'),
                          _headerText(context, '成交额', width: 110),
                          _headerText(context, '联动', width: 56),
                        ],
                      ),
                    ),
                    ...snapshot.leaders.map((item) {
                      final canOpenStock =
                          RegExp(r'^\d{6}$').hasMatch(item.stockCode);
                      final stockSemanticsLabel =
                          'pw-plate-rotation-leader-stock-${snapshot.date ?? '--'}-${item.stockCode}';
                      final rowSemanticsLabel =
                          'pw-plate-rotation-leader-${snapshot.date ?? '--'}-${item.stockCode}';
                      final openSemanticsLabel =
                          'pw-plate-rotation-leader-open-${snapshot.date ?? '--'}-${item.stockCode}';
                      return Padding(
                        padding: EdgeInsets.zero,
                        child: Semantics(
                          container: true,
                          button: true,
                          label: rowSemanticsLabel,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onLeaderTap(item),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: item.rankNo.isEven
                                      ? AppTheme.surfaceSoft
                                          .withValues(alpha: 0.38)
                                      : Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 54,
                                      child: Text(
                                        '${item.rankNo}',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          color: item.rankNo <= 3
                                              ? theme.colorScheme.primary
                                              : AppTheme.text,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: stockWidth,
                                      child: Semantics(
                                        container: true,
                                        button: true,
                                        enabled: true,
                                        label: stockSemanticsLabel,
                                        child: ExcludeSemantics(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => onLeaderTap(item),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.stockName,
                                                  style: theme
                                                      .textTheme.titleMedium
                                                      ?.copyWith(
                                                    color: AppTheme.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${item.stockCode}  |  21 日明细',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    _quoteText(
                                      context,
                                      _fmtNumber(item.quote?.price),
                                      width: 88,
                                      color: _quoteColor(
                                          context, item.quote?.changePct),
                                      weight: FontWeight.w700,
                                    ),
                                    _quoteText(
                                      context,
                                      _fmtNumber(item.quote?.open),
                                      width: 88,
                                    ),
                                    _quoteText(
                                      context,
                                      _fmtSignedPct(item.quote?.changePct),
                                      width: 88,
                                      color: _quoteColor(
                                          context, item.quote?.changePct),
                                      weight: FontWeight.w600,
                                    ),
                                    _quoteText(
                                      context,
                                      _fmtPct(item.quote?.amplitude),
                                      width: 88,
                                    ),
                                    _quoteText(
                                      context,
                                      _fmtAmount(item.quote?.amount),
                                      width: 110,
                                    ),
                                    SizedBox(
                                      width: 56,
                                      child: Tooltip(
                                        excludeFromSemantics: true,
                                        message: '打开股票',
                                        child: Semantics(
                                          container: true,
                                          button: canOpenStock,
                                          enabled: canOpenStock,
                                          label: openSemanticsLabel,
                                          child: ExcludeSemantics(
                                            child: IconButton(
                                              onPressed: canOpenStock
                                                  ? () => onOpenStock(
                                                        item.stockCode,
                                                      )
                                                  : null,
                                              tooltip: '打开股票',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints.tightFor(
                                                width: 34,
                                                height: 34,
                                              ),
                                              icon: const Icon(
                                                Icons.open_in_new_rounded,
                                                size: 18,
                                              ),
                                            ),
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
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _headerText(
    BuildContext context,
    String text, {
    double width = 88,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }

  Widget _quoteText(
    BuildContext context,
    String text, {
    required double width,
    Color? color,
    FontWeight? weight,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: weight,
            ),
      ),
    );
  }
}

class _LeaderDetailSheet extends StatelessWidget {
  const _LeaderDetailSheet({
    required this.item,
    required this.klineFuture,
    required this.onOpenStock,
  });

  final PlateLeaderQuoteItemData item;
  final Future<KlineSnapshot> klineFuture;
  final VoidCallback onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quote = item.quote;

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 56,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.outlineStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.stockName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${item.stockCode}  |  龙头排名 ${item.rankNo}',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: onOpenStock,
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('打开股票'),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _DetailMetricCard(
                          label: '现价',
                          value: _fmtNumber(quote?.price),
                          accent: _quoteColor(context, quote?.changePct),
                        ),
                        _DetailMetricCard(
                          label: '开盘',
                          value: _fmtNumber(quote?.open),
                        ),
                        _DetailMetricCard(
                          label: '涨幅',
                          value: _fmtSignedPct(quote?.changePct),
                          accent: _quoteColor(context, quote?.changePct),
                        ),
                        _DetailMetricCard(
                          label: '振幅',
                          value: _fmtPct(quote?.amplitude),
                        ),
                        _DetailMetricCard(
                          label: '成交额',
                          value: _fmtAmount(quote?.amount),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder<KlineSnapshot>(
                      future: klineFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildStateCard(
                            context,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return _buildStateCard(
                            context,
                            child: Text(
                              'K 线请求失败：${snapshot.error}',
                              style: theme.textTheme.bodyLarge,
                            ),
                          );
                        }

                        final kline = snapshot.data;
                        final bars = kline?.bars ?? const <KlineBarData>[];
                        if (kline == null || bars.isEmpty) {
                          return _buildStateCard(
                            context,
                            child: Text(
                              '当前个股还没有可展示的近期日线数据。',
                              style: theme.textTheme.bodyLarge,
                            ),
                          );
                        }

                        final latest = bars.last;
                        final earliest = bars.first;
                        final rangeLow =
                            bars.map((bar) => bar.lowPrice).reduce(math.min);
                        final rangeHigh =
                            bars.map((bar) => bar.highPrice).reduce(math.max);
                        final basePrice =
                            earliest.openPrice == 0 ? null : earliest.openPrice;
                        final periodChange = basePrice == null
                            ? null
                            : (latest.closePrice - basePrice) / basePrice * 100;
                        final recentBars =
                            bars.reversed.take(5).toList(growable: false);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStateCard(
                              context,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '21 日 K 线',
                                              style: theme.textTheme.titleLarge,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '按需从个股接口加载日线，用于核对龙头强弱节奏。',
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${kline.total} 根',
                                        style: theme.textTheme.labelLarge,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _MiniKlineChart(bars: bars),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _InfoTag(
                                        label: '最新',
                                        value: latest.tradeDate,
                                      ),
                                      _InfoTag(
                                        label: '收盘',
                                        value: _fmtNumber(latest.closePrice),
                                      ),
                                      _InfoTag(
                                        label: '21 日区间',
                                        value:
                                            '${_fmtNumber(rangeLow)} - ${_fmtNumber(rangeHigh)}',
                                      ),
                                      _InfoTag(
                                        label: '阶段涨幅',
                                        value: _fmtSignedPct(periodChange),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildStateCard(
                              context,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '最近五日',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  ...recentBars.map(
                                    (bar) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 92,
                                            child: Text(
                                              _formatBarDate(bar.tradeDate),
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              'O ${_fmtNumber(bar.openPrice)}  '
                                              'C ${_fmtNumber(bar.closePrice)}  '
                                              'H ${_fmtNumber(bar.highPrice)}  '
                                              'L ${_fmtNumber(bar.lowPrice)}',
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 108,
                                            child: Text(
                                              _fmtAmount(bar.volume),
                                              textAlign: TextAlign.end,
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: child,
    );
  }
}

class _DetailMetricCard extends StatelessWidget {
  const _DetailMetricCard({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 138,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: accent ?? AppTheme.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniKlineChart extends StatelessWidget {
  const _MiniKlineChart({
    required this.bars,
  });

  final List<KlineBarData> bars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 252,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _KlinePainter(
                bars: bars,
                gridColor: theme.colorScheme.outlineVariant,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _formatBarDate(bars.first.tradeDate),
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                _formatBarDate(bars.last.tradeDate),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KlinePainter extends CustomPainter {
  const _KlinePainter({
    required this.bars,
    required this.gridColor,
  });

  final List<KlineBarData> bars;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final maxHigh = bars.map((bar) => bar.highPrice).reduce(math.max);
    final minLow = bars.map((bar) => bar.lowPrice).reduce(math.min);
    final range = math.max(maxHigh - minLow, 0.01);
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var step = 0; step < 4; step++) {
      final y = size.height * step / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final slotWidth = size.width / bars.length;
    final candleWidth = math.max(3.0, slotWidth * 0.52);

    double projectY(double price) {
      final ratio = (price - minLow) / range;
      return size.height - (ratio * size.height);
    }

    for (var index = 0; index < bars.length; index++) {
      final bar = bars[index];
      final x = slotWidth * index + (slotWidth / 2);
      final highY = projectY(bar.highPrice);
      final lowY = projectY(bar.lowPrice);
      final openY = projectY(bar.openPrice);
      final closeY = projectY(bar.closePrice);
      final isUp = bar.closePrice >= bar.openPrice;
      final color = isUp ? AppTheme.rise : AppTheme.fall;

      final wickPaint = Paint()
        ..color = color.withValues(alpha: 0.92)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      final top = math.min(openY, closeY);
      final bottom = math.max(openY, closeY);
      final rect = Rect.fromCenter(
        center: Offset(x, (top + bottom) / 2),
        width: candleWidth,
        height: math.max(bottom - top, 2),
      );
      final bodyPaint = Paint()
        ..color = color.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KlinePainter oldDelegate) {
    return oldDelegate.bars != bars || oldDelegate.gridColor != gridColor;
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label  ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.66),
                  ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _MatrixCellData {
  const _MatrixCellData({
    required this.plateName,
    required this.plateCode,
    required this.ztCount,
    required this.strength,
    required this.strengthText,
    required this.date,
    this.rank,
  });

  final String plateName;
  final String? plateCode;
  final int ztCount;
  final double? strength;
  final String? strengthText;
  final String date;
  final int? rank;

  _MatrixCellData copyWith({int? rank}) {
    return _MatrixCellData(
      plateName: plateName,
      plateCode: plateCode,
      ztCount: ztCount,
      strength: strength,
      strengthText: strengthText,
      date: date,
      rank: rank ?? this.rank,
    );
  }
}

class _SelectedPlate {
  const _SelectedPlate({
    this.plateName,
    this.plateCode,
    this.date,
  });

  final String? plateName;
  final String? plateCode;
  final String? date;
}

class _PlateTone {
  const _PlateTone({
    required this.background,
    required this.border,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color text;
}

Color _selectedToneFill(_PlateTone tone) {
  return Color.lerp(tone.background, tone.border, 0.74) ?? tone.border;
}

String _formatShortTimestamp(String? value) {
  if (value == null || value.isEmpty) {
    return '--';
  }
  final normalized = value.replaceFirst('T', ' ').replaceAll('Z', '');
  return normalized.length > 19 ? normalized.substring(0, 19) : normalized;
}

String _formatBarDate(String value) {
  if (value.length >= 10) {
    return value.substring(5, 10);
  }
  return value;
}

String _fmtNumber(num? value, {int digits = 2}) {
  if (value == null) {
    return '--';
  }
  return value.toStringAsFixed(digits);
}

String _fmtPct(num? value, {int digits = 2}) {
  if (value == null) {
    return '--';
  }
  return '${value.toStringAsFixed(digits)}%';
}

String _fmtSignedPct(num? value, {int digits = 2}) {
  if (value == null) {
    return '--';
  }
  final number = value.toDouble();
  final prefix = number > 0 ? '+' : '';
  return '$prefix${number.toStringAsFixed(digits)}%';
}

String _fmtAmount(num? value) {
  if (value == null) {
    return '--';
  }
  final number = value.toDouble();
  if (number.abs() >= 100000000) {
    return '${(number / 100000000).toStringAsFixed(2)}亿';
  }
  if (number.abs() >= 10000) {
    return '${(number / 10000).toStringAsFixed(1)}万';
  }
  return number.toStringAsFixed(0);
}

Color _quoteColor(BuildContext context, num? value) {
  if (value == null) {
    return Theme.of(context).colorScheme.onSurface;
  }
  if (value > 0) {
    return AppTheme.rise;
  }
  if (value < 0) {
    return AppTheme.fall;
  }
  return Theme.of(context).colorScheme.onSurface;
}
