import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/application/export_bundle_service.dart';
import '../../../shared/application/stock_link_service.dart';
import '../../../shared/application/workspace_capture_service.dart';
import '../../../shared/layout/app_shell.dart';
import '../application/node_provider.dart';
import '../data/node_repository.dart';

const _riseColor = Color(0xFFB54937);
const _fallColor = Color(0xFF1F6B59);
const _inkColor = Color(0xFF24343A);

class NodePage extends ConsumerStatefulWidget {
  const NodePage({super.key});

  @override
  ConsumerState<NodePage> createState() => _NodePageState();
}

class _NodePageState extends ConsumerState<NodePage> {
  static const _autoRefreshInterval = Duration(seconds: 5);

  final GlobalKey _captureKey = GlobalKey();
  String? _selectedDate;
  String? _selectedPlateCode;
  bool _autoRefresh = true;
  bool _isRefreshing = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefreshTimer();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(nodePageProvider);

    return AppShell(
      currentPath: '/node',
      title: '牛牛节点',
      subtitle: '按旧版节点页的工作流组织：先定指数，再定日期，再定当日板块强度，最后查看对应龙头联动。',
      child: snapshotAsync.when(
        data: (snapshot) => _buildBody(context, snapshot),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessagePanel(
          title: '节点快照不可用',
          body: '节点工作台请求失败：$error',
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NodeSnapshotData snapshot) {
    final selectedDate = _resolveSelectedDate(snapshot);
    final dateItem = _resolveDateItem(snapshot, selectedDate);
    final selectedPlateCode = _resolveSelectedPlateCode(dateItem);
    final selectedPlate = _resolveSelectedPlate(dateItem, selectedPlateCode);
    final selectedIndex = selectedDate == null
        ? -1
        : snapshot.dateItems.indexWhere((item) => item.date == selectedDate);

    final leadersAsync = selectedDate != null && selectedPlateCode != null
        ? ref.watch(
            nodeLeadersProvider(
              (
                plateCode: selectedPlateCode,
                date: selectedDate,
                stockLimit: 10,
              ),
            ),
          )
        : null;

    return RepaintBoundary(
      key: _captureKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1080;
          return ListView(
            children: [
              _Panel(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 16 : 24,
                  isWide ? 16 : 24,
                  isWide ? 16 : 24,
                  isWide ? 14 : 22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWide)
                      _CompactNodeControlBar(
                        symbol: snapshot.symbol,
                        quote: snapshot.quote,
                        fetchedAt: snapshot.fetchedAt,
                        selectedDate: selectedDate,
                        selectedPlateName: selectedPlate?.plateName,
                        autoRefresh: _autoRefresh,
                        isRefreshing: _isRefreshing,
                        onRefresh: _refreshWorkspace,
                        onToggleAutoRefresh: _toggleAutoRefresh,
                        onSymbolSelected: (symbol) {
                          setState(() {
                            _selectedDate = null;
                            _selectedPlateCode = null;
                          });
                          ref.read(nodeSymbolProvider.notifier).state = symbol;
                        },
                      )
                    else ...[
                      _WorkspaceHeader(
                        symbol: snapshot.symbol,
                        quote: snapshot.quote,
                        helperText: snapshot.helperText,
                        selectedDate: selectedDate,
                        selectedPlateName: selectedPlate?.plateName,
                        onSymbolSelected: (symbol) {
                          setState(() {
                            _selectedDate = null;
                            _selectedPlateCode = null;
                          });
                          ref.read(nodeSymbolProvider.notifier).state = symbol;
                        },
                      ),
                      const SizedBox(height: 18),
                      _SummaryBand(
                        symbol: snapshot.symbol,
                        quote: snapshot.quote,
                        fetchedAt: snapshot.fetchedAt,
                        autoRefresh: _autoRefresh,
                        isRefreshing: _isRefreshing,
                        onRefresh: _refreshWorkspace,
                        onToggleAutoRefresh: _toggleAutoRefresh,
                      ),
                    ],
                    SizedBox(height: isWide ? 12 : 18),
                    _buildKlineWorkspace(
                      context,
                      snapshot: snapshot,
                      selectedDate: selectedDate,
                      selectedIndex: selectedIndex,
                      dateItem: dateItem,
                      selectedPlateCode: selectedPlateCode,
                      plates: dateItem?.topPlates ?? const [],
                      compact: isWide,
                    ),
                  ],
                ),
              ),
              SizedBox(height: isWide ? 12 : 16),
              if (isWide)
                _LeadersPanel(
                  date: selectedDate,
                  selectedPlate: selectedPlate,
                  leadersAsync: leadersAsync,
                  isRefreshing: _isRefreshing,
                  onRefresh: () {
                    _refreshWorkspace();
                  },
                  onCopy: (data) {
                    _copyLeaders(data);
                  },
                  onCopyImage: _copyWorkspaceImage,
                  onExportExcel: (data) {
                    _exportLeadersExcel(data);
                  },
                  onExportCsv: (data) {
                    _exportLeadersCsv(data);
                  },
                  onOpenStock: _openStock,
                )
              else ...[
                _LeadersPanel(
                  date: selectedDate,
                  selectedPlate: selectedPlate,
                  leadersAsync: leadersAsync,
                  isRefreshing: _isRefreshing,
                  onRefresh: () {
                    _refreshWorkspace();
                  },
                  onCopy: (data) {
                    _copyLeaders(data);
                  },
                  onCopyImage: _copyWorkspaceImage,
                  onExportExcel: (data) {
                    _exportLeadersExcel(data);
                  },
                  onExportCsv: (data) {
                    _exportLeadersCsv(data);
                  },
                  onOpenStock: _openStock,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildKlineWorkspace(
    BuildContext context, {
    required NodeSnapshotData snapshot,
    required String? selectedDate,
    required int selectedIndex,
    required NodeDateItemData? dateItem,
    required String? selectedPlateCode,
    required List<NodePlateData> plates,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 12 : 16,
        compact ? 12 : 16,
        compact ? 10 : 14,
      ),
      decoration: _workspaceDecoration(context, toned: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '21 日指数 K 线',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _inkColor,
                  ),
                ),
              ),
              if (selectedDate != null)
                Text(
                  selectedDate,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (!compact) ...[
            Text(
              '点击柱线或日期条，右侧强度板块和下方龙头表会同步切换。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 4),
          _DateStrip(
            dateItems: snapshot.dateItems,
            selectedDate: selectedDate,
            onSelected: (date) {
              setState(() {
                _selectedDate = date;
                _selectedPlateCode = null;
              });
            },
          ),
          SizedBox(height: compact ? 8 : 10),
          _NodeCandleChart(
            dateItems: snapshot.dateItems,
            selectedIndex: selectedIndex,
            height: compact ? 190 : 230,
            onSelectIndex: (index) {
              if (index < 0 || index >= snapshot.dateItems.length) {
                return;
              }
              setState(() {
                _selectedDate = snapshot.dateItems[index].date;
                _selectedPlateCode = null;
              });
            },
          ),
          SizedBox(height: compact ? 8 : 10),
          _NodePlateTimelineBand(
            dateItems: snapshot.dateItems,
            selectedDate: selectedDate,
            selectedPlateCode: selectedPlateCode,
            onSelect: (date, plateCode) {
              setState(() {
                _selectedDate = date;
                _selectedPlateCode = plateCode;
              });
            },
          ),
          SizedBox(height: compact ? 8 : 10),
          if (!compact)
            _SelectedBarSummary(
              bar: dateItem?.bar,
              date: selectedDate,
            ),
          if (!compact) const SizedBox(height: 10),
          _NodePlateBand(
            date: selectedDate,
            selectedPlateCode: selectedPlateCode,
            plates: plates,
            onSelect: (plateCode) {
              setState(() {
                _selectedPlateCode = plateCode;
              });
            },
          ),
        ],
      ),
    );
  }

  String? _resolveSelectedDate(NodeSnapshotData snapshot) {
    final local = _selectedDate;
    if (local != null && snapshot.dateItems.any((item) => item.date == local)) {
      return local;
    }
    final fallback = snapshot.defaultDate;
    if (fallback != null &&
        snapshot.dateItems.any((item) => item.date == fallback)) {
      return fallback;
    }
    if (snapshot.dateItems.isNotEmpty) {
      return snapshot.dateItems.last.date;
    }
    return null;
  }

  NodeDateItemData? _resolveDateItem(NodeSnapshotData snapshot, String? date) {
    if (date == null) {
      return null;
    }
    for (final item in snapshot.dateItems) {
      if (item.date == date) {
        return item;
      }
    }
    return null;
  }

  String? _resolveSelectedPlateCode(NodeDateItemData? dateItem) {
    final plates = dateItem?.topPlates ?? const <NodePlateData>[];
    final local = _selectedPlateCode;
    if (local != null && plates.any((item) => item.plateCode == local)) {
      return local;
    }
    for (final plate in plates) {
      if (plate.plateCode != null && plate.plateCode!.isNotEmpty) {
        return plate.plateCode;
      }
    }
    return null;
  }

  NodePlateData? _resolveSelectedPlate(
    NodeDateItemData? dateItem,
    String? selectedPlateCode,
  ) {
    if (selectedPlateCode == null) {
      return null;
    }
    for (final plate in dateItem?.topPlates ?? const <NodePlateData>[]) {
      if (plate.plateCode == selectedPlateCode) {
        return plate;
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

  Future<void> _refreshWorkspace({
    bool includeLeaders = true,
    bool silent = false,
  }) async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
    });

    try {
      ref.invalidate(nodePageProvider);
      final snapshot = await ref.read(nodePageProvider.future);

      if (!includeLeaders) {
        return;
      }

      final selectedDate = _resolveSelectedDate(snapshot);
      final dateItem = _resolveDateItem(snapshot, selectedDate);
      final selectedPlateCode = _resolveSelectedPlateCode(dateItem);
      if (selectedDate == null || selectedPlateCode == null) {
        return;
      }

      final request = (
        plateCode: selectedPlateCode,
        date: selectedDate,
        stockLimit: 10,
      );
      ref.invalidate(nodeLeadersProvider(request));
      await ref.read(nodeLeadersProvider(request).future);
    } catch (error) {
      if (silent) {
        return;
      }
      _showInfo('节点工作台刷新失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _toggleAutoRefresh() {
    _setAutoRefresh(!_autoRefresh);
  }

  void _setAutoRefresh(bool value) {
    if (_autoRefresh == value) {
      return;
    }
    setState(() {
      _autoRefresh = value;
    });

    _autoRefreshTimer?.cancel();
    if (!value) {
      _autoRefreshTimer = null;
      return;
    }

    _refreshWorkspace(includeLeaders: false, silent: true);
    _startAutoRefreshTimer();
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    if (!_autoRefresh) {
      _autoRefreshTimer = null;
      return;
    }
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _refreshWorkspace(includeLeaders: false, silent: true);
    });
  }

  Future<void> _copyLeaders(NodePlateLeadersData data) async {
    final snapshot = ref.read(nodePageProvider).valueOrNull;
    final selectedDate =
        snapshot == null ? data.date : _resolveSelectedDate(snapshot);
    final dateItem =
        snapshot == null ? null : _resolveDateItem(snapshot, selectedDate);

    final buffer = StringBuffer()
      ..writeln('节点联动')
      ..writeln(
        '指数：${_displayIndexName(snapshot?.symbol, snapshot?.quote.name)} (${snapshot?.symbol ?? '--'})',
      )
      ..writeln('日期：${data.date ?? selectedDate ?? '--'}')
      ..writeln('板块：${data.plateName ?? data.plateCode}')
      ..writeln('行情同步：${_fmtStamp(data.quoteFetchedAt ?? data.fetchedAt)}')
      ..writeln('行数：${data.total}');

    if (dateItem != null && dateItem.topPlates.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[热门板块]');
      for (final plate in dateItem.topPlates) {
        buffer.writeln(
          '${plate.rank}\t${plate.plateName}\t${plate.plateCode ?? '--'}\t'
          '${plate.ztCount ?? '--'}\t${plate.strengthText ?? '--'}',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('[龙头列表]');
    for (final leader in data.leaders) {
      final quote = leader.quote;
      buffer.writeln(
        '${leader.rankNo}\t${leader.stockCode}\t${leader.stockName}\t'
        '${_fmtNumber(quote?.price)}\t${_fmtNumber(quote?.preClose)}\t'
        '${_fmtNumber(quote?.open)}\t${_fmtNumber(quote?.high)}\t'
        '${_fmtNumber(quote?.low)}\t${_fmtVolume(quote?.volume)}\t'
        '${_fmtAmount(quote?.amount)}\t${_fmtSigned(quote?.change)}\t'
        '${_fmtSignedPct(quote?.changePct)}\t${_fmtPct(quote?.turnoverRate)}\t'
        '${_fmtNumber(quote?.dynamicPe)}\t${_fmtPct(quote?.amplitude)}\t'
        '${_fmtAmount(quote?.circulatingCap)}\t${_fmtAmount(quote?.marketCap)}',
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    _showInfo('龙头联动数据已复制到剪贴板。');
  }

  Future<void> _copyWorkspaceImage() async {
    final result = await captureWorkspaceImage(
      repaintBoundaryKey: _captureKey,
      context: context,
      bundleName: 'node_workspace',
      fileName: '牛牛节点.png',
    );
    if (result == null) {
      _showInfo('当前工作区暂时无法生成图片。');
      return;
    }
    _showInfo(
      result.copiedToClipboard
          ? '节点工作区图片已复制到剪贴板。'
          : '节点工作区图片已导出：${result.filePath}',
    );
  }

  Future<void> _exportLeadersExcel(NodePlateLeadersData data) async {
    final files = _buildLeaderExportFiles(data);
    final filePath = await writeExcelWorkbook(
      bundleName: 'node_leaders',
      fileName: '牛牛节点-龙头联动.xlsx',
      sheets: files.entries
          .map(
            (entry) => ExcelSheetData(
              name: entry.key,
              rows: entry.value,
            ),
          )
          .toList(growable: false),
    );
    _showInfo('龙头联动 Excel 已导出：$filePath');
  }

  Future<void> _exportLeadersCsv(NodePlateLeadersData data) async {
    final files = _buildLeaderExportFiles(data);

    final result = await writeCsvBundle(
      bundleName: 'node_leaders',
      files: files,
    );
    _showInfo('龙头联动 CSV 已导出：${result.directoryPath}');
  }

  Map<String, List<List<String>>> _buildLeaderExportFiles(
    NodePlateLeadersData data,
  ) {
    final snapshot = ref.read(nodePageProvider).valueOrNull;
    final selectedDate =
        snapshot == null ? data.date : _resolveSelectedDate(snapshot);
    final dateItem =
        snapshot == null ? null : _resolveDateItem(snapshot, selectedDate);

    final files = <String, List<List<String>>>{
      'summary': [
        ['symbol', snapshot?.symbol ?? '--'],
        [
          'index_name',
          _displayIndexName(snapshot?.symbol, snapshot?.quote.name)
        ],
        ['date', data.date ?? selectedDate ?? '--'],
        ['plate_code', data.plateCode],
        ['plate_name', data.plateName ?? '--'],
        ['rows', '${data.total}'],
        ['snapshot_at', _fmtStamp(data.quoteFetchedAt ?? data.fetchedAt)],
      ],
      'leaders': [
        [
          'rank',
          'stock_code',
          'stock_name',
          'price',
          'pre_close',
          'open',
          'high',
          'low',
          'volume',
          'amount',
          'change',
          'change_pct',
          'turnover_rate',
          'dynamic_pe',
          'amplitude',
          'circulating_cap',
          'market_cap',
        ],
        ...data.leaders.map(
          (leader) => [
            '${leader.rankNo}',
            leader.stockCode,
            leader.stockName,
            _fmtNumber(leader.quote?.price),
            _fmtNumber(leader.quote?.preClose),
            _fmtNumber(leader.quote?.open),
            _fmtNumber(leader.quote?.high),
            _fmtNumber(leader.quote?.low),
            _fmtVolume(leader.quote?.volume),
            _fmtAmount(leader.quote?.amount),
            _fmtSigned(leader.quote?.change),
            _fmtSignedPct(leader.quote?.changePct),
            _fmtPct(leader.quote?.turnoverRate),
            _fmtNumber(leader.quote?.dynamicPe),
            _fmtPct(leader.quote?.amplitude),
            _fmtAmount(leader.quote?.circulatingCap),
            _fmtAmount(leader.quote?.marketCap),
          ],
        ),
      ],
    };

    if (dateItem != null && dateItem.topPlates.isNotEmpty) {
      files['top_plates'] = [
        ['rank', 'plate_code', 'plate_name', 'zt_count', 'strength_text'],
        ...dateItem.topPlates.map(
          (plate) => [
            '${plate.rank}',
            plate.plateCode ?? '--',
            plate.plateName,
            '${plate.ztCount ?? '--'}',
            plate.strengthText ?? '--',
          ],
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
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.symbol,
    required this.quote,
    required this.helperText,
    required this.selectedDate,
    required this.selectedPlateName,
    required this.onSymbolSelected,
  });

  final String symbol;
  final NodeQuoteData quote;
  final String helperText;
  final String? selectedDate;
  final String? selectedPlateName;
  final ValueChanged<String> onSymbolSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '指数联动工作台',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _inkColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_displayIndexName(symbol, quote.name)} 用来驱动日期、板块和龙头的联动切换。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _indexOptions
                  .map(
                    (option) => _SymbolPill(
                      label: option.label,
                      secondary: option.code,
                      selected: symbol == option.code,
                      onTap: () => onSymbolSelected(option.code),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: _workspaceDecoration(context),
          child: Row(
            children: [
              Icon(
                Icons.polyline_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _normalizeNodeHelperText(helperText),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (selectedDate != null ||
            (selectedPlateName ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (selectedDate != null)
                Chip(
                  avatar: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text('日期 $selectedDate'),
                ),
              if ((selectedPlateName ?? '').trim().isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.grid_view_rounded, size: 18),
                  label: Text('板块 $selectedPlateName'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SummaryBand extends StatelessWidget {
  const _SummaryBand({
    required this.symbol,
    required this.quote,
    required this.fetchedAt,
    required this.autoRefresh,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onToggleAutoRefresh,
  });

  final String symbol;
  final NodeQuoteData quote;
  final String? fetchedAt;
  final bool autoRefresh;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onToggleAutoRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changeColor = _changeColorForValue(
      context,
      quote.changePct,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _workspaceDecoration(context),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        children: [
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayIndexName(symbol, quote.name),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  _fmtNumber(quote.price),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 34,
                    color: _inkColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_fmtSigned(quote.change)} / ${_fmtSignedPct(quote.changePct)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: changeColor,
                  ),
                ),
              ],
            ),
          ),
          _MetricBlock(
            label: '区间',
            value: '${_fmtNumber(quote.low)} ~ ${_fmtNumber(quote.high)}',
          ),
          _MetricBlock(
            label: '开盘 / 昨收',
            value: '${_fmtNumber(quote.open)} / ${_fmtNumber(quote.preClose)}',
          ),
          _MetricBlock(
            label: '成交量 / 成交额',
            value:
                '${_fmtCompactInt(quote.volume)} / ${_fmtAmount(quote.amount)}',
          ),
          _MetricBlock(
            label: '换手 / 振幅',
            value:
                '${_fmtPct(quote.turnoverRate)} / ${_fmtPct(quote.amplitude)}',
          ),
          _MetricBlock(
            label: '最后同步',
            value: _fmtStamp(fetchedAt),
          ),
          _NodeToolbarIconButton(
            tooltip: isRefreshing ? '刷新中' : '刷新指数',
            icon: isRefreshing
                ? Icons.sync_disabled_rounded
                : Icons.refresh_rounded,
            onPressed: isRefreshing ? null : onRefresh,
          ),
          _NodeToolbarIconButton(
            tooltip: autoRefresh ? '停止自动刷新' : '自动 5 秒',
            icon: autoRefresh ? Icons.pause_rounded : Icons.autorenew_rounded,
            selected: autoRefresh,
            onPressed: onToggleAutoRefresh,
          ),
        ],
      ),
    );
  }
}

class _CompactNodeControlBar extends StatelessWidget {
  const _CompactNodeControlBar({
    required this.symbol,
    required this.quote,
    required this.fetchedAt,
    required this.selectedDate,
    required this.selectedPlateName,
    required this.autoRefresh,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onToggleAutoRefresh,
    required this.onSymbolSelected,
  });

  final String symbol;
  final NodeQuoteData quote;
  final String? fetchedAt;
  final String? selectedDate;
  final String? selectedPlateName;
  final bool autoRefresh;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onToggleAutoRefresh;
  final ValueChanged<String> onSymbolSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changeColor = _changeColorForValue(context, quote.changePct);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: _workspaceDecoration(context),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _indexOptions
                  .map(
                    (option) => _SymbolPill(
                      label: option.label,
                      secondary: option.code,
                      selected: symbol == option.code,
                      onTap: () => onSymbolSelected(option.code),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CompactMetric(
                  label: _displayIndexName(symbol, quote.name),
                  value: _fmtNumber(quote.price),
                  valueColor: _inkColor,
                ),
                _CompactMetric(
                  label: '涨跌',
                  value:
                      '${_fmtSigned(quote.change)} / ${_fmtSignedPct(quote.changePct)}',
                  valueColor: changeColor,
                ),
                _CompactMetric(
                  label: '成交',
                  value: _fmtAmount(quote.amount),
                ),
                _CompactMetric(
                  label: '同步',
                  value: _fmtStamp(fetchedAt),
                ),
                if (selectedDate != null)
                  Text(
                    '日期 $selectedDate',
                    style: theme.textTheme.labelLarge,
                  ),
                if ((selectedPlateName ?? '').trim().isNotEmpty)
                  Text(
                    '板块 $selectedPlateName',
                    style: theme.textTheme.labelLarge,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _NodeToolbarIconButton(
            tooltip: isRefreshing ? '刷新中' : '刷新指数',
            icon: isRefreshing
                ? Icons.sync_disabled_rounded
                : Icons.refresh_rounded,
            onPressed: isRefreshing ? null : onRefresh,
          ),
          const SizedBox(width: 6),
          _NodeToolbarIconButton(
            tooltip: autoRefresh ? '停止自动刷新' : '自动 5 秒',
            icon: autoRefresh ? Icons.pause_rounded : Icons.autorenew_rounded,
            selected: autoRefresh,
            onPressed: onToggleAutoRefresh,
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium,
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: valueColor ?? _inkColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeToolbarIconButton extends StatelessWidget {
  const _NodeToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: onPressed != null,
        label: tooltip,
        child: ExcludeSemantics(
          child: IconButton.filledTonal(
            isSelected: selected,
            onPressed: onPressed,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: 18),
          ),
        ),
      ),
    );
  }
}

class _SelectedBarSummary extends StatelessWidget {
  const _SelectedBarSummary({
    required this.bar,
    required this.date,
  });

  final NodeKlineBarData? bar;
  final String? date;

  @override
  Widget build(BuildContext context) {
    if (bar == null || date == null) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _InlineMetric(
          label: '日期',
          value: date!,
        ),
        _InlineMetric(
          label: '开盘',
          value: _fmtNumber(bar!.openPrice),
        ),
        _InlineMetric(
          label: '收盘',
          value: _fmtNumber(bar!.closePrice),
          emphasized: true,
        ),
        _InlineMetric(
          label: '最高',
          value: _fmtNumber(bar!.highPrice),
        ),
        _InlineMetric(
          label: '最低',
          value: _fmtNumber(bar!.lowPrice),
        ),
        _InlineMetric(
          label: '成交量',
          value: _fmtCompactDouble(bar!.volume),
        ),
      ],
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.dateItems,
    required this.selectedDate,
    required this.onSelected,
  });

  final List<NodeDateItemData> dateItems;
  final String? selectedDate;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            for (var index = 0; index < dateItems.length; index++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 2,
                    right: index == dateItems.length - 1 ? 0 : 2,
                  ),
                  child: _DateTile(
                    date: dateItems[index].date,
                    selected: dateItems[index].date == selectedDate,
                    onTap: () => onSelected(dateItems[index].date),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NodePlateTimelineBand extends StatelessWidget {
  const _NodePlateTimelineBand({
    required this.dateItems,
    required this.selectedDate,
    required this.selectedPlateCode,
    required this.onSelect,
  });

  final List<NodeDateItemData> dateItems;
  final String? selectedDate;
  final String? selectedPlateCode;
  final void Function(String date, String? plateCode) onSelect;

  @override
  Widget build(BuildContext context) {
    if (dateItems.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '21 日板块强度带',
              style: theme.textTheme.titleSmall?.copyWith(
                color: _inkColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '前 20 日取轮动强度，当日取当前最强板块。',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth =
                math.max(62.0, constraints.maxWidth / dateItems.length);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < dateItems.length; index++)
                    _NodePlateTimelineCell(
                      width: cellWidth,
                      dateItem: dateItems[index],
                      selectedDate: selectedDate,
                      selectedPlateCode: selectedPlateCode,
                      onSelect: onSelect,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NodePlateTimelineCell extends StatelessWidget {
  const _NodePlateTimelineCell({
    required this.width,
    required this.dateItem,
    required this.selectedDate,
    required this.selectedPlateCode,
    required this.onSelect,
  });

  final double width;
  final NodeDateItemData dateItem;
  final String? selectedDate;
  final String? selectedPlateCode;
  final void Function(String date, String? plateCode) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plate = dateItem.topPlates.isEmpty ? null : dateItem.topPlates.first;
    final selected = dateItem.date == selectedDate &&
        (plate?.plateCode == null || plate?.plateCode == selectedPlateCode);
    final tone = _nodePlateTone(plate?.rank ?? 5, selected);
    final canSelect = plate?.plateCode != null;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Semantics(
        button: true,
        enabled: true,
        label: 'pw-node-plate-timeline-${dateItem.date}',
        child: InkWell(
          borderRadius: BorderRadius.circular(3),
          onTap: () => onSelect(dateItem.date, plate?.plateCode),
          child: Container(
            width: width,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: canSelect ? tone.background : const Color(0xFFF1F4F7),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: selected
                    ? tone.border
                    : canSelect
                        ? tone.border.withValues(alpha: 0.76)
                        : const Color(0xFFD7DEE7),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _shortDate(dateItem.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: canSelect ? tone.text : const Color(0xFF74808D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plate?.plateName ?? '无板块',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: canSelect ? tone.text : const Color(0xFF74808D),
                    fontWeight: FontWeight.w700,
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

class _NodePlateBand extends StatelessWidget {
  const _NodePlateBand({
    required this.date,
    required this.selectedPlateCode,
    required this.plates,
    required this.onSelect,
  });

  final String? date;
  final String? selectedPlateCode;
  final List<NodePlateData> plates;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '当日板块强度',
              style: theme.textTheme.titleSmall?.copyWith(
                color: _inkColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              date ?? '--',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (plates.isEmpty)
          const _MessagePanel(
            title: '暂无板块强度',
            body: '当前交易日还没有对齐的板块轮动快照。',
            compact: true,
          )
        else
          Row(
            children: plates.take(5).map((plate) {
              final selected = plate.plateCode != null &&
                  plate.plateCode == selectedPlateCode;
              final tone = _nodePlateTone(plate.rank, selected);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: plate == plates.take(5).last ? 0 : 6,
                  ),
                  child: Semantics(
                    button: plate.plateCode != null,
                    label:
                        'pw-node-plate-band-${plate.plateCode ?? plate.plateName}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: plate.plateCode == null
                          ? null
                          : () => onSelect(plate.plateCode!),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: tone.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : tone.border,
                            width: selected ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${plate.rank}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: tone.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                plate.plateName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: tone.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${plate.ztCount ?? '--'}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: tone.text.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
      ],
    );
  }
}

class _LeadersPanel extends StatelessWidget {
  const _LeadersPanel({
    required this.date,
    required this.selectedPlate,
    required this.leadersAsync,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onCopy,
    required this.onCopyImage,
    required this.onExportExcel,
    required this.onExportCsv,
    required this.onOpenStock,
  });

  final String? date;
  final NodePlateData? selectedPlate;
  final AsyncValue<NodePlateLeadersData>? leadersAsync;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final ValueChanged<NodePlateLeadersData> onCopy;
  final VoidCallback onCopyImage;
  final ValueChanged<NodePlateLeadersData> onExportExcel;
  final ValueChanged<NodePlateLeadersData> onExportCsv;
  final ValueChanged<String> onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Semantics(
        container: true,
        label: '龙头联动表',
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
                      Text(
                        selectedPlate == null
                            ? '龙头联动表'
                            : '龙头联动表：${selectedPlate!.plateName}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: _inkColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selectedPlate == null
                            ? '从左侧板块列表里选择一个板块，右侧就会加载对应龙头行情。'
                            : '当日板块强度：${selectedPlate!.plateName} 在 ${date ?? '--'} 的龙头批量行情，可直接从表格联动到个股。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedPlate != null) ...[
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: isRefreshing ? null : onRefresh,
                    icon: Icon(
                      isRefreshing
                          ? Icons.sync_disabled_rounded
                          : Icons.refresh_rounded,
                    ),
                    label: Text(isRefreshing ? '刷新中' : '刷新'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (leadersAsync == null)
              const _MessagePanel(
                title: '尚未发起龙头请求',
                body: '选择一个带稳定代码的板块后，才会加载右侧龙头表。',
                compact: true,
              )
            else
              leadersAsync!.when(
                data: (data) {
                  if (data.leaders.isEmpty) {
                    return const _MessagePanel(
                      title: '暂无龙头数据',
                      body: '当前板块在该日期没有缓存的龙头行情记录。',
                      compact: true,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _InlineMetric(
                            label: '板块',
                            value: data.plateName ?? data.plateCode,
                          ),
                          _InlineMetric(
                            label: '日期',
                            value: data.date ?? '--',
                          ),
                          _InlineMetric(
                            label: '行数',
                            value: '${data.total}',
                          ),
                          _InlineMetric(
                            label: '行情同步',
                            value: _fmtStamp(
                                data.quoteFetchedAt ?? data.fetchedAt),
                          ),
                          OutlinedButton.icon(
                            onPressed: onCopyImage,
                            icon: const Icon(Icons.image_rounded),
                            label: const Text('复制图片'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => onCopy(data),
                            icon: const Icon(Icons.copy_all_rounded),
                            label: const Text('复制文本'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => onExportExcel(data),
                            icon: const Icon(Icons.table_chart_rounded),
                            label: const Text('导出 Excel'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => onExportCsv(data),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('导出 CSV'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _LeaderRichTable(
                        leaders: data.leaders,
                        onOpenStock: onOpenStock,
                      ),
                    ],
                  );
                },
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const LinearProgressIndicator(minHeight: 4),
                      const SizedBox(height: 14),
                      Text(
                        '正在加载龙头行情批次...',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                error: (error, _) => _MessagePanel(
                  title: '龙头表不可用',
                  body: '所选板块的龙头请求失败：$error',
                  compact: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LeaderRichTable extends StatelessWidget {
  const _LeaderRichTable({
    required this.leaders,
    required this.onOpenStock,
  });

  final List<NodeLeaderItemData> leaders;
  final ValueChanged<String> onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget headerCell(
      String text, {
      double width = 88,
      TextAlign align = TextAlign.left,
    }) {
      return SizedBox(
        width: width,
        child: Text(
          text,
          textAlign: align,
          style: theme.textTheme.labelLarge,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  headerCell('排序', width: 54),
                  headerCell('代码', width: 96),
                  headerCell('名称', width: 170),
                  headerCell('现价'),
                  headerCell('昨收'),
                  headerCell('开盘'),
                  headerCell('最高'),
                  headerCell('最低'),
                  headerCell('成交量', width: 116),
                  headerCell('成交额', width: 112),
                  headerCell('涨跌额'),
                  headerCell('涨跌%', width: 88),
                  headerCell('换手'),
                  headerCell('市盈率'),
                  headerCell('振幅'),
                  headerCell('流通市值', width: 124),
                  headerCell('总市值', width: 124),
                  headerCell('联动', width: 56, align: TextAlign.center),
                ],
              ),
            ),
            ...leaders.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LeaderRichRow(
                  item: item,
                  onOpenStock: onOpenStock,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderRichRow extends StatelessWidget {
  const _LeaderRichRow({
    required this.item,
    required this.onOpenStock,
  });

  final NodeLeaderItemData item;
  final ValueChanged<String> onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quote = item.quote;
    final changeColor = _changeColorForValue(context, quote?.changePct);
    final canOpenStock = RegExp(r'^\d{6}$').hasMatch(item.stockCode);
    final rowSemanticsLabel = 'pw-node-leader-row-${item.stockCode}';
    final stockSemanticsLabel = 'pw-node-leader-stock-${item.stockCode}';
    final openSemanticsLabel = 'pw-node-leader-open-${item.stockCode}';

    Widget fixedCell(
      String text, {
      double width = 88,
      TextAlign align = TextAlign.left,
      Color? color,
      FontWeight? weight,
    }) {
      return SizedBox(
        width: width,
        child: Text(
          text,
          textAlign: align,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: weight,
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: rowSemanticsLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: _workspaceDecoration(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 54,
              child: Text(
                '${item.rankNo}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: item.rankNo <= 3
                      ? Theme.of(context).colorScheme.primary
                      : _inkColor,
                ),
              ),
            ),
            SizedBox(
              width: 96,
              child: MouseRegion(
                cursor:
                    canOpenStock ? SystemMouseCursors.click : MouseCursor.defer,
                child: Semantics(
                  container: true,
                  button: canOpenStock,
                  enabled: canOpenStock,
                  label: stockSemanticsLabel,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canOpenStock
                          ? () => onOpenStock(item.stockCode)
                          : null,
                      child: SizedBox(
                        height: 32,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.stockCode,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: canOpenStock
                                  ? theme.colorScheme.primary
                                  : _inkColor,
                              fontWeight: FontWeight.w600,
                              decoration: canOpenStock
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                              decorationColor: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            fixedCell(
              item.stockName,
              width: 170,
              color: _inkColor,
              weight: FontWeight.w600,
            ),
            fixedCell(
              _fmtNumber(quote?.price),
              color: changeColor,
              weight: FontWeight.w700,
            ),
            fixedCell(_fmtNumber(quote?.preClose)),
            fixedCell(_fmtNumber(quote?.open)),
            fixedCell(_fmtNumber(quote?.high)),
            fixedCell(_fmtNumber(quote?.low)),
            fixedCell(_fmtVolume(quote?.volume), width: 116),
            fixedCell(_fmtAmount(quote?.amount), width: 112),
            fixedCell(
              _fmtSigned(quote?.change),
              color: changeColor,
              weight: FontWeight.w600,
            ),
            fixedCell(
              _fmtSignedPct(quote?.changePct),
              color: changeColor,
              weight: FontWeight.w600,
            ),
            fixedCell(_fmtPct(quote?.turnoverRate)),
            fixedCell(_fmtNumber(quote?.dynamicPe)),
            fixedCell(_fmtPct(quote?.amplitude)),
            fixedCell(_fmtAmount(quote?.circulatingCap), width: 124),
            fixedCell(_fmtAmount(quote?.marketCap), width: 124),
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
                    child: Tooltip(
                      excludeFromSemantics: true,
                      message: '打开股票',
                      child: IconButton(
                        onPressed: canOpenStock
                            ? () => onOpenStock(item.stockCode)
                            : null,
                        tooltip: '打开股票',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final String date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        selected ? theme.colorScheme.primary : theme.colorScheme.surface;
    final foreground = selected ? Colors.white : _inkColor;
    final borderColor =
        selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: TextButton(
        onPressed: onTap,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: WidgetStatePropertyAll(background),
          overlayColor: WidgetStatePropertyAll(
            foreground.withValues(alpha: 0.08),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: borderColor),
            ),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _shortDate(date),
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SymbolPill extends StatelessWidget {
  const _SymbolPill({
    required this.label,
    required this.secondary,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String secondary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? Colors.white : _inkColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                secondary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.78)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _inkColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _workspaceDecoration(context),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label  ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            TextSpan(
              text: value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: emphasized ? _inkColor : theme.colorScheme.onSurface,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.title,
    required this.body,
    this.compact = false,
  });

  final String title;
  final String body;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: _workspaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _inkColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeCandleChart extends StatelessWidget {
  const _NodeCandleChart({
    required this.dateItems,
    required this.selectedIndex,
    required this.onSelectIndex,
    this.height = 230,
  });

  final List<NodeDateItemData> dateItems;
  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void handleOffset(double dx) {
          if (dateItems.isEmpty || constraints.maxWidth <= 0) {
            return;
          }
          final ratio = (dx / constraints.maxWidth).clamp(0.0, 0.999999);
          final index = (ratio * dateItems.length).floor();
          onSelectIndex(index);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => handleOffset(details.localPosition.dx),
          onHorizontalDragStart: (details) =>
              handleOffset(details.localPosition.dx),
          onHorizontalDragUpdate: (details) =>
              handleOffset(details.localPosition.dx),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _NodeCandlePainter(
                context: context,
                dateItems: dateItems,
                selectedIndex: selectedIndex,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NodeCandlePainter extends CustomPainter {
  const _NodeCandlePainter({
    required this.context,
    required this.dateItems,
    required this.selectedIndex,
  });

  final BuildContext context;
  final List<NodeDateItemData> dateItems;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final theme = Theme.of(context);
    final framePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF7FAFE),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = theme.colorScheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final clip = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(clip, framePaint);
    canvas.drawRRect(clip, borderPaint);
    canvas.clipRRect(clip);

    if (dateItems.isEmpty) {
      return;
    }

    final bars = dateItems.map((item) => item.bar).toList(growable: false);
    final validBars =
        bars.whereType<NodeKlineBarData>().toList(growable: false);
    if (validBars.isEmpty) {
      return;
    }

    final maxHigh = validBars.map((bar) => bar.highPrice).reduce(math.max);
    final minLow = validBars.map((bar) => bar.lowPrice).reduce(math.min);
    final maxVolume = validBars.map((bar) => bar.volume).reduce(math.max);
    final rawRange = maxHigh - minLow;
    final priceRange =
        rawRange.abs() < 0.00001 ? maxHigh.abs() * 0.05 + 1 : rawRange;

    const horizontalPadding = 14.0;
    const topPadding = 16.0;
    const bottomPadding = 18.0;
    const gap = 16.0;
    final priceHeight = size.height * 0.68;
    final priceRect = Rect.fromLTWH(
      horizontalPadding,
      topPadding,
      size.width - horizontalPadding * 2,
      priceHeight,
    );
    final volumeRect = Rect.fromLTWH(
      horizontalPadding,
      priceRect.bottom + gap,
      size.width - horizontalPadding * 2,
      size.height - priceRect.bottom - gap - bottomPadding,
    );
    final step = priceRect.width / dateItems.length;
    final candleWidth = math.min(step * 0.54, 18.0);
    final baseGridColor = theme.colorScheme.outlineVariant;

    for (var i = 0; i < 4; i++) {
      final y = priceRect.top + (priceRect.height / 3) * i;
      canvas.drawLine(
        Offset(priceRect.left, y),
        Offset(priceRect.right, y),
        Paint()
          ..color = baseGridColor.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
    }

    for (var i = 0; i < 5; i++) {
      final x = priceRect.left + (priceRect.width / 4) * i;
      canvas.drawLine(
        Offset(x, priceRect.top),
        Offset(x, volumeRect.bottom),
        Paint()
          ..color = baseGridColor.withValues(alpha: 0.24)
          ..strokeWidth = 1,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(priceRect, const Radius.circular(6)),
      Paint()
        ..color = const Color(0xFF2D83F8).withValues(alpha: 0.035)
        ..style = PaintingStyle.fill,
    );

    if (selectedIndex >= 0 && selectedIndex < dateItems.length) {
      final left = priceRect.left + step * selectedIndex;
      final highlightRect = Rect.fromLTWH(
        left,
        priceRect.top,
        step,
        volumeRect.bottom - priceRect.top,
      );
      canvas.drawRect(
        highlightRect,
        Paint()..color = theme.colorScheme.primary.withValues(alpha: 0.10),
      );
    }

    double mapPrice(double value) {
      final ratio = (value - minLow) / priceRange;
      return priceRect.bottom - ratio * priceRect.height;
    }

    double mapVolume(double value) {
      if (maxVolume <= 0) {
        return volumeRect.bottom;
      }
      final ratio = value / maxVolume;
      return volumeRect.bottom - ratio * volumeRect.height;
    }

    for (var i = 0; i < dateItems.length; i++) {
      final bar = dateItems[i].bar;
      if (bar == null) {
        continue;
      }
      final x = priceRect.left + step * i + step / 2;
      final isRising = bar.closePrice >= bar.openPrice;
      final strokeColor = isRising ? _riseColor : _fallColor;
      final fillColor = isRising
          ? const Color(0xFFFFF2F0)
          : _fallColor.withValues(alpha: 0.86);

      final openY = mapPrice(bar.openPrice);
      final closeY = mapPrice(bar.closePrice);
      final highY = mapPrice(bar.highPrice);
      final lowY = mapPrice(bar.lowPrice);
      final bodyTop = math.min(openY, closeY);
      final bodyBottom = math.max(openY, closeY);

      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        Paint()
          ..color = strokeColor
          ..strokeWidth = 1.5,
      );

      final bodyRect = Rect.fromLTRB(
        x - candleWidth / 2,
        bodyTop,
        x + candleWidth / 2,
        math.max(bodyBottom, bodyTop + 1.4),
      );
      canvas.drawRect(
        bodyRect,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        bodyRect,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25,
      );

      final volumeTop = mapVolume(bar.volume);
      canvas.drawRect(
        Rect.fromLTRB(
          x - candleWidth / 2,
          volumeTop,
          x + candleWidth / 2,
          volumeRect.bottom,
        ),
        Paint()
          ..color = strokeColor.withValues(alpha: 0.55)
          ..style = PaintingStyle.fill,
      );
    }

    final fallbackIndex = dateItems.length - 1;
    final safeSelectedIndex =
        selectedIndex >= 0 && selectedIndex < dateItems.length
            ? selectedIndex
            : fallbackIndex;
    final selectedBar = dateItems[safeSelectedIndex].bar;
    final selectedDate = dateItems[safeSelectedIndex].date;
    final headerText = selectedBar == null
        ? selectedDate
        : '$selectedDate   开 ${_fmtNumber(selectedBar.openPrice)}   '
            '收 ${_fmtNumber(selectedBar.closePrice)}   '
            '高 ${_fmtNumber(selectedBar.highPrice)}   '
            '低 ${_fmtNumber(selectedBar.lowPrice)}';
    _paintText(
      canvas,
      headerText,
      const Offset(16, 10),
      theme.textTheme.bodyMedium?.copyWith(
        color: _inkColor,
        fontWeight: FontWeight.w600,
      ),
    );
    _paintText(
      canvas,
      _fmtNumber(maxHigh),
      Offset(priceRect.right - 56, priceRect.top - 4),
      theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
      ),
    );
    _paintText(
      canvas,
      _fmtNumber(minLow),
      Offset(priceRect.right - 56, priceRect.bottom - 12),
      theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
      ),
    );
    _paintText(
      canvas,
      '成交量 ${_fmtCompactDouble(maxVolume)}',
      Offset(volumeRect.right - 92, volumeRect.top - 2),
      theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _NodeCandlePainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.dateItems != dateItems;
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle? style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }
}

class _IndexOption {
  const _IndexOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

const _indexOptions = <_IndexOption>[
  _IndexOption(code: 'sz399001', label: '深成指'),
  _IndexOption(code: 'sh000001', label: '上证指数'),
  _IndexOption(code: 'avg', label: '均值线'),
];

String _displayIndexName(String? symbol, String? rawName) {
  final normalized = rawName?.trim();
  if (normalized != null &&
      normalized.isNotEmpty &&
      normalized != 'SZIndex' &&
      normalized != 'SHIndex' &&
      normalized != 'Average') {
    return normalized;
  }
  return switch (symbol) {
    'sz399001' => '深成指',
    'sh000001' => '上证指数',
    'avg' => '均值线',
    _ => normalized?.isNotEmpty == true ? normalized! : '--',
  };
}

({Color background, Color border, Color text}) _nodePlateTone(
  int rank,
  bool selected,
) {
  final base = switch (rank) {
    1 => const (
        background: Color(0xFFFFB3B8),
        border: Color(0xFFFF9CA4),
        text: Color(0xFFC41D24),
      ),
    2 => const (
        background: Color(0xFFFFD4B8),
        border: Color(0xFFF7B88F),
        text: Color(0xFFC4501C),
      ),
    3 => const (
        background: Color(0xFFFFE8B3),
        border: Color(0xFFF1D07A),
        text: Color(0xFFC47605),
      ),
    4 => const (
        background: Color(0xFFB3E0F2),
        border: Color(0xFF8BCBE7),
        text: Color(0xFF2980B9),
      ),
    _ => const (
        background: Color(0xFFE8E8E8),
        border: Color(0xFFD4D4D4),
        text: Color(0xFF555555),
      ),
  };
  if (!selected) {
    return base;
  }
  final selectedBorder = switch (rank) {
    1 => const Color(0xFFFF2237),
    2 => const Color(0xFFFD6524),
    3 => const Color(0xFFFE9506),
    4 => const Color(0xFF5BC0DE),
    _ => const Color(0xFFBDBDBD),
  };
  return (
    background: base.background,
    border: selectedBorder,
    text: base.text,
  );
}

String _normalizeNodeHelperText(String value) {
  final trimmed = value.trim();
  if (trimmed == 'Click a candle or date to inspect index-plate linkage.') {
    return '点击 K 线或日期，查看指数与板块联动。';
  }
  return trimmed;
}

BoxDecoration _workspaceDecoration(
  BuildContext context, {
  bool toned = false,
}) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: toned
        ? theme.colorScheme.primary.withValues(alpha: 0.05)
        : theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: theme.colorScheme.outlineVariant,
    ),
  );
}

String _shortDate(String value) {
  if (value.length >= 10) {
    return value.substring(5, 10);
  }
  return value;
}

String _fmtStamp(String? value) {
  if (value == null || value.isEmpty) {
    return '--';
  }
  final normalized = value.replaceFirst('T', ' ').replaceAll('Z', '');
  return normalized.length > 19 ? normalized.substring(0, 19) : normalized;
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

String _fmtSigned(num? value, {int digits = 2}) {
  if (value == null) {
    return '--';
  }
  final number = value.toDouble();
  final prefix = number > 0 ? '+' : '';
  return '$prefix${number.toStringAsFixed(digits)}';
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

String _fmtVolume(int? value) {
  if (value == null) {
    return '--';
  }
  final digits = value.abs().toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return value < 0 ? '-$formatted' : formatted;
}

String _fmtCompactInt(int? value) {
  if (value == null) {
    return '--';
  }
  if (value >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (value >= 10000) {
    return '${(value / 10000).toStringAsFixed(1)}万';
  }
  return '$value';
}

String _fmtCompactDouble(double? value) {
  if (value == null) {
    return '--';
  }
  if (value >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (value >= 10000) {
    return '${(value / 10000).toStringAsFixed(1)}万';
  }
  return value.toStringAsFixed(0);
}

Color _changeColorForValue(BuildContext context, num? value) {
  if (value == null) {
    return Theme.of(context).colorScheme.onSurface;
  }
  if (value > 0) {
    return _riseColor;
  }
  if (value < 0) {
    return _fallColor;
  }
  return Theme.of(context).colorScheme.onSurface;
}
