import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/application/export_bundle_service.dart';
import '../../../shared/application/stock_link_service.dart';
import '../../../shared/data/ai_analysis_data.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/ai_analysis_panel.dart';
import '../../../shared/widgets/ai_primary_action_button.dart';
import '../../ask_ai/application/ask_ai_provider.dart';
import '../application/auction_provider.dart';
import '../data/auction_repository.dart';

class AuctionPage extends ConsumerStatefulWidget {
  const AuctionPage({super.key});

  @override
  ConsumerState<AuctionPage> createState() => _AuctionPageState();
}

class _AuctionPageState extends ConsumerState<AuctionPage> {
  static const _autoRefreshInterval = Duration(seconds: 5);
  static const _accent = AppTheme.primary;
  static const _accentSoft = AppTheme.surfaceSoft;
  static const _rise = AppTheme.rise;
  static const _riseStrong = AppTheme.danger;
  static const _warning = AppTheme.secondary;
  static const _muted = AppTheme.mutedText;

  final GlobalKey _captureKey = GlobalKey();
  String? _selectedCode;
  AiAnalysisStateData? _aiAnalysisOverride;
  bool _autoRefresh = false;
  bool _isRefreshing = false;
  bool _isGeneratingAi = false;
  Timer? _autoRefreshTimer;

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(auctionPageProvider);

    return AppShell(
      currentPath: '/auction',
      title: '牛牛竞价',
      subtitle: '按旧版竞价桌面的阅读顺序组织：先看当日异动，再看多日左列，最后回到右侧分组榜确认方向。',
      child: data.when(
        data: (snapshot) => RepaintBoundary(
          key: _captureKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1260;
              final panelHeight = isWide ? 980.0 : 780.0;

              return ListView(
                children: [
                  _buildSummaryCard(context, snapshot),
                  const SizedBox(height: 16),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _buildTimelinePanel(
                            context,
                            snapshot,
                            panelHeight: panelHeight,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 9,
                          child: _buildRanksPanel(
                            context,
                            snapshot,
                            panelHeight: panelHeight,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildTimelinePanel(
                      context,
                      snapshot,
                      panelHeight: panelHeight,
                    ),
                    const SizedBox(height: 16),
                    _buildRanksPanel(
                      context,
                      snapshot,
                      panelHeight: panelHeight + 80,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '竞价页面请求失败：$error',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, AuctionPageData snapshot) {
    final theme = Theme.of(context);
    final live =
        snapshot.historyColumns.isEmpty ? null : snapshot.historyColumns.first;
    final strengthSignals = _collectStrengthSignals(snapshot);
    final aiAnalysis = _effectiveAiAnalysis(snapshot);
    final selectedProfile = _selectedCode == null
        ? null
        : _buildSelectedProfile(snapshot, _selectedCode!);
    final selectedTitle = selectedProfile == null
        ? _selectedCode
        : '${selectedProfile.name} (${selectedProfile.code})';
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('竞价工作台', style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(
          _normalizeAuctionTitle(live?.title, snapshot.tradeDate),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '交易日 ${snapshot.tradeDate ?? '--'}  |  快照 ${_formatTimestamp(snapshot.fetchedAt ?? live?.fetchedAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          _selectedCode == null
              ? '左侧保留多日竞价异动，右侧用分组榜确认热点方向。'
              : '当前选中 $selectedTitle，左右区域会同步高亮，方便快速回看多日表现。',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
    final usageAsync = ref.watch(aiServerUsageStatusProvider);
    final auctionUsage = usageAsync.valueOrNull?.feature('auction');
    final aiButtonTooltip = aiAnalysis.enabled
        ? '使用当前牛牛竞价全量数据生成 AI 竞价分析'
        : (aiAnalysis.reason.isEmpty ? 'AI竞价暂不可用' : aiAnalysis.reason);
    final actionButtons = AiActionGroup(
      primary: AiPrimaryActionButton(
        tooltip: aiButtonTooltip,
        onPressed: aiAnalysis.enabled ? _generateAuctionAi : null,
        loading: _isGeneratingAi,
        loadingLabel: 'AI分析中',
        label: 'AI竞价',
        remainingUses: auctionUsage?.remaining,
        totalLimit: auctionUsage?.limit,
      ),
      children: [
        FilledButton.tonalIcon(
          onPressed: _isRefreshing ? null : _refreshData,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_isRefreshing ? '刷新中' : '刷新'),
        ),
        FilterChip(
          selected: _autoRefresh,
          showCheckmark: false,
          onSelected: (_) => _toggleAutoRefresh(),
          label: Text(_autoRefresh ? '停止' : '自动 5 秒'),
        ),
        OutlinedButton.icon(
          onPressed: () => _copyWorkspaceImage(snapshot),
          icon: const Icon(Icons.image_rounded),
          label: const Text('复制图片'),
        ),
        OutlinedButton.icon(
          onPressed: () => _copySnapshotText(snapshot),
          icon: const Icon(Icons.copy_all_rounded),
          label: const Text('复制文本'),
        ),
        OutlinedButton.icon(
          onPressed: () => _exportExcelSnapshot(snapshot),
          icon: const Icon(Icons.table_view_rounded),
          label: const Text('导出 Excel'),
        ),
        OutlinedButton.icon(
          onPressed: () => _exportCsvSnapshot(snapshot),
          icon: const Icon(Icons.download_rounded),
          label: const Text('导出 CSV'),
        ),
      ],
    );
    final selectedBlock = _selectedCode == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('当前选中', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      selectedTitle ?? _selectedCode!,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _selectedCode = null),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('清除选股'),
              ),
            ],
          );

    return Card(
      child: Container(
        decoration: AppTheme.panelDecoration(
          radius: 8,
          gradient: LinearGradient(
            colors: [
              AppTheme.surface.withValues(alpha: 0.94),
              AppTheme.surfaceSoft.withValues(alpha: 0.88),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderColor: Colors.white.withValues(alpha: 0.10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 720) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        const SizedBox(height: 10),
                        actionButtons,
                        if (selectedBlock != null) ...[
                          const SizedBox(height: 10),
                          selectedBlock,
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 12),
                      actionButtons,
                      if (selectedBlock != null) ...[
                        const SizedBox(width: 8),
                        selectedBlock,
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              AiAnalysisPanel(
                title: 'AI竞价分析',
                actionLabel: '9:26 后，后端会用当前竞价全量数据请求 Kimi。',
                state: aiAnalysis,
              ),
              if (selectedProfile != null)
                _SelectedFocusCard(
                  profile: selectedProfile,
                  onOpenStock: () => _openStock(selectedProfile.code),
                )
              else ...[
                const SizedBox(height: 8),
                _AuctionStrengthPanel(
                  signals: strengthSignals,
                  onSelectCode: (code) {
                    setState(() {
                      _selectedCode = code;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
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

  Future<void> _refreshData() async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
    });
    try {
      ref.invalidate(auctionPageProvider);
      await ref.read(auctionPageProvider.future);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _toggleAutoRefresh() {
    final nextValue = !_autoRefresh;
    setState(() {
      _autoRefresh = nextValue;
    });

    _autoRefreshTimer?.cancel();
    if (!nextValue) {
      return;
    }

    _refreshData();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _refreshData();
    });
  }

  AiAnalysisStateData _effectiveAiAnalysis(AuctionPageData snapshot) {
    final override = _aiAnalysisOverride;
    if (override == null) {
      return snapshot.aiAnalysis;
    }
    if (override.tradeDate == snapshot.tradeDate ||
        override.tradeDate == null ||
        snapshot.tradeDate == null) {
      return override;
    }
    return snapshot.aiAnalysis;
  }

  Future<void> _generateAuctionAi() async {
    if (_isGeneratingAi) {
      return;
    }
    setState(() {
      _isGeneratingAi = true;
    });
    try {
      final result =
          await ref.read(auctionRepositoryProvider).generateAiAnalysis();
      if (!mounted) {
        return;
      }
      setState(() {
        _aiAnalysisOverride = result;
      });
      ref.invalidate(auctionPageProvider);
      ref.invalidate(aiServerUsageStatusProvider);
      _showInfo('AI竞价分析已生成。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      final msg = _cleanErrorMessage(error);
      if (msg.contains('今日 AI 使用次数已用完') ||
          msg.contains('429') ||
          msg.contains('超过当日免费使用限制')) {
        ref.invalidate(aiServerUsageStatusProvider);
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('AI 使用次数已用完'),
            content: Text(msg),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } else {
        _showInfo('AI竞价分析失败：$msg');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAi = false;
        });
      }
    }
  }

  Future<void> _copyWorkspaceImage(AuctionPageData snapshot) async {
    final pngBytes = await _captureWorkspacePng();
    if (pngBytes == null) {
      _showInfo('竞价图片截取失败。');
      return;
    }

    final filePath = await writeBinaryFile(
      bundleName: 'auction_snapshot_image',
      fileName: 'auction_${snapshot.tradeDate ?? 'snapshot'}.png',
      bytes: pngBytes,
    );

    final copied = await _copyImageToClipboard(filePath);
    if (!mounted) {
      return;
    }
    if (copied) {
      _showInfo('竞价图片已复制到剪贴板：$filePath');
      return;
    }

    _showInfo('竞价 PNG 已保存：$filePath');
  }

  Future<void> _copySnapshotText(AuctionPageData snapshot) async {
    final buffer = StringBuffer()
      ..writeln('牛牛竞价')
      ..writeln('交易日：${snapshot.tradeDate ?? '--'}')
      ..writeln('快照：${_formatTimestamp(snapshot.fetchedAt)}')
      ..writeln()
      ..writeln('[History Columns]');

    for (final column in snapshot.historyColumns) {
      buffer.writeln(
        '${column.tradeLabel ?? column.tradeDate ?? '--'}'
        ' | ${_normalizeAuctionTitle(column.title, column.tradeDate)}'
        ' | rows ${column.total}',
      );
      for (final item in column.items) {
        buffer.writeln(
          '${item.code}\t${item.name}\t${item.lianban}\t'
          '${item.zhangfu}\t${item.concepts.join(" / ")}\t'
          '${item.amounts.join(" | ")}',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('[Rank Sections]');
    for (final section in snapshot.rankSections) {
      buffer.writeln('${section.tabLabel} | rows ${section.total}');
      for (final item in section.items) {
        buffer.writeln('${item.code}\t${item.name}\t${item.cells.join("\t")}');
      }
      buffer.writeln();
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    _showInfo('竞价文本已复制到剪贴板。');
  }

  Future<void> _exportExcelSnapshot(AuctionPageData snapshot) async {
    final filePath = await writeExcelWorkbook(
      bundleName: 'auction_excel',
      fileName: 'auction_${snapshot.tradeDate ?? 'snapshot'}.xlsx',
      sheets: _buildExportSheets(snapshot)
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
    _showInfo('竞价 Excel 已导出：$filePath');
  }

  Future<void> _exportCsvSnapshot(AuctionPageData snapshot) async {
    final result = await writeCsvBundle(
      bundleName: 'auction_snapshot',
      files: _buildExportSheets(snapshot),
    );
    if (!mounted) {
      return;
    }
    _showInfo('竞价 CSV 已导出：${result.directoryPath}');
  }

  Map<String, List<List<String>>> _buildExportSheets(AuctionPageData snapshot) {
    final files = <String, List<List<String>>>{
      'summary': [
        ['trade_date', snapshot.tradeDate ?? '--'],
        ['fetched_at', _formatTimestamp(snapshot.fetchedAt)],
        ['history_columns', '${snapshot.historyColumns.length}'],
        ['rank_sections', '${snapshot.rankSections.length}'],
      ],
      'history_columns': [
        [
          'trade_date',
          'trade_label',
          'title',
          'is_live',
          'code',
          'name',
          'lianban',
          'zhangfu',
          'concepts',
          'amounts',
        ],
        ...snapshot.historyColumns.expand(
          (column) => column.items.map(
            (item) => [
              column.tradeDate ?? '--',
              column.tradeLabel ?? '--',
              _normalizeAuctionTitle(column.title, column.tradeDate),
              column.isLive ? '1' : '0',
              item.code,
              item.name,
              item.lianban,
              item.zhangfu,
              item.concepts.join(' / '),
              item.amounts.join(' | '),
            ],
          ),
        ),
      ],
    };

    for (final section in snapshot.rankSections) {
      files['rank_${section.key}'] = [
        ['code', 'name', ...section.columns],
        ...section.items.map((item) => [item.code, item.name, ...item.cells]),
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

  Widget _buildTimelinePanel(
    BuildContext context,
    AuctionPageData snapshot, {
    required double panelHeight,
  }) {
    final theme = Theme.of(context);
    final columns = snapshot.historyColumns;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      Text('左侧竞价列', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        '按交易日保留最近 ${columns.length} 列，结构回到旧版“今日 + 历史多日”视图。',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (snapshot.fetchedAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      _formatTimestamp(snapshot.fetchedAt),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: panelHeight,
              child: columns.isEmpty
                  ? Center(
                      child: Text(
                        '暂无竞价历史列。',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 8.0;
                        final fillWidth = columns.isEmpty
                            ? 160.0
                            : (constraints.maxWidth -
                                    gap * math.max(0, columns.length - 1)) /
                                columns.length;
                        final columnWidth = math.max(160.0, fillWidth);
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: columns
                                .asMap()
                                .entries
                                .map(
                                  (entry) => Padding(
                                    padding: EdgeInsets.only(
                                      right: entry.key == columns.length - 1
                                          ? 0
                                          : gap,
                                    ),
                                    child: _AuctionDayColumn(
                                      width: columnWidth,
                                      column: entry.value,
                                      selectedCode: _selectedCode,
                                      accent: _accent,
                                      accentSoft: _accentSoft,
                                      rise: _rise,
                                      riseStrong: _riseStrong,
                                      warning: _warning,
                                      onSelectCode: (code) {
                                        setState(() {
                                          _selectedCode = _selectedCode == code
                                              ? null
                                              : code;
                                        });
                                      },
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRanksPanel(
    BuildContext context,
    AuctionPageData snapshot, {
    required double panelHeight,
  }) {
    final sections = snapshot.rankSections;
    if (sections.isEmpty) {
      return Card(
        child: SizedBox(
          height: panelHeight,
          child: Center(
            child: Text(
              '暂无排行数据。',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final initialRankIndex = _preferredRankSectionIndex(sections);

    return DefaultTabController(
      length: sections.length,
      initialIndex: initialRankIndex,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: panelHeight,
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
                            '右侧排行榜',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedCode == null
                                ? '点击左列或右表中的股票，所有标签内同代码会被同步高亮。'
                                : '当前选中 $_selectedCode，右侧标签会把匹配项排到前面。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_selectedCode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          '已选 $_selectedCode',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: _accent,
                  unselectedLabelColor: _muted,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.16),
                    ),
                  ),
                  dividerColor: Colors.transparent,
                  tabs: sections
                      .map(
                        (section) => Tab(
                          text: '${section.tabLabel} (${section.total})',
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: sections
                        .map(
                          (section) => _AuctionRankTable(
                            section: section,
                            selectedCode: _selectedCode,
                            onSelectCode: (code) {
                              setState(() {
                                _selectedCode =
                                    _selectedCode == code ? null : code;
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _preferredRankSectionIndex(List<AuctionRankSectionData> sections) {
    final index = sections.indexWhere(
      (section) =>
          section.key == 'qiangchou' ||
          section.title == 'grab_bid' ||
          section.tabLabel.contains('抢筹'),
    );
    return index < 0 ? 0 : index;
  }

  List<_AuctionStrengthSignal> _collectStrengthSignals(
    AuctionPageData snapshot,
  ) {
    final rankSignals = _collectRankStrengthSignals(snapshot.rankSections);
    if (rankSignals.isNotEmpty) {
      return rankSignals;
    }
    final liveItems = snapshot.historyColumns.isEmpty
        ? const <AuctionColumnItemData>[]
        : snapshot.historyColumns.first.items;
    return _collectLiveStrengthSignals(liveItems);
  }

  List<_AuctionStrengthSignal> _collectRankStrengthSignals(
    List<AuctionRankSectionData> sections,
  ) {
    AuctionRankSectionData? section;
    for (final item in sections) {
      if (item.key == 'qiangchou' ||
          item.title == 'grab_bid' ||
          item.tabLabel.contains('抢筹')) {
        section = item;
        break;
      }
    }
    if (section == null) {
      return const [];
    }

    final signals = <_AuctionStrengthSignal>[];
    for (final item in section.items) {
      final bidAmountWan = item.bidAmountWan;
      if (bidAmountWan == null || bidAmountWan <= 0) {
        continue;
      }
      final amount925 = bidAmountWan * 10000;
      double? amount920;
      final grabPct = item.grabPct;
      if (item.previousAmountWan != null && item.previousAmountWan! > 0) {
        amount920 = item.previousAmountWan! * 10000;
      } else if (grabPct != null && grabPct > -99.9) {
        amount920 = amount925 / (1 + grabPct / 100);
      }
      amount920 ??= 0;
      final delta = math.max(0.0, amount925 - amount920);
      if (delta <= 0 && (grabPct == null || grabPct <= 0)) {
        continue;
      }
      signals.add(
        _AuctionStrengthSignal(
          code: item.code,
          name: item.name,
          lianban: item.boardCount == null &&
                  _cleanNullableRankText(item.boardText) == null
              ? ''
              : _formatBoardText(item.boardText, item.boardCount, ''),
          zhangfu:
              grabPct == null ? '' : '抢筹 ${_formatPct(grabPct, null, true)}',
          concepts: [
            if (_cleanNullableRankText(item.concept) != null)
              _cleanNullableRankText(item.concept)!,
          ],
          amount920: amount920,
          amount925: amount925,
          delta: delta,
          ratio: grabPct == null ? null : grabPct / 100,
        ),
      );
    }
    signals.sort((left, right) {
      final ratioCompare = (right.ratio ?? 0).compareTo(left.ratio ?? 0);
      if (ratioCompare != 0) {
        return ratioCompare;
      }
      return right.amount925.compareTo(left.amount925);
    });
    return signals.take(12).toList(growable: false);
  }

  List<_AuctionStrengthSignal> _collectLiveStrengthSignals(
    List<AuctionColumnItemData> items,
  ) {
    final signals = <_AuctionStrengthSignal>[];
    for (final item in items) {
      if (item.amounts.length < 3) {
        continue;
      }
      final amount920 = _parseAuctionAmount(item.amounts[1]);
      final amount925 = _parseAuctionAmount(item.amounts[2]);
      if (amount920 == null || amount925 == null || amount925 <= amount920) {
        continue;
      }
      final delta = amount925 - amount920;
      signals.add(
        _AuctionStrengthSignal(
          code: item.code,
          name: item.name,
          lianban: item.lianban,
          zhangfu: item.zhangfu,
          concepts: item.concepts.take(3).toList(growable: false),
          amount920: amount920,
          amount925: amount925,
          delta: delta,
          ratio: amount920 <= 0 ? null : delta / amount920,
        ),
      );
    }
    signals.sort((left, right) {
      final deltaCompare = right.delta.compareTo(left.delta);
      if (deltaCompare != 0) {
        return deltaCompare;
      }
      return right.amount925.compareTo(left.amount925);
    });
    return signals.take(12).toList(growable: false);
  }

  _SelectedProfile _buildSelectedProfile(
    AuctionPageData snapshot,
    String code,
  ) {
    final dayMatches = <String>[];
    AuctionColumnItemData? firstItem;
    for (final column in snapshot.historyColumns) {
      for (final item in column.items) {
        if (item.code == code) {
          firstItem ??= item;
          dayMatches.add(column.tradeLabel ?? column.tradeDate ?? '--');
        }
      }
    }

    final rankMatches = snapshot.rankSections
        .where((section) => section.items.any((item) => item.code == code))
        .map((section) => section.tabLabel)
        .toList(growable: false);

    return _SelectedProfile(
      code: code,
      name: firstItem?.name ?? code,
      concepts: firstItem?.concepts ?? const [],
      lianban: firstItem?.lianban ?? '',
      dayMatches: dayMatches,
      rankMatches: rankMatches,
    );
  }
}

class _AuctionDayColumn extends StatelessWidget {
  const _AuctionDayColumn({
    required this.width,
    required this.column,
    required this.selectedCode,
    required this.accent,
    required this.accentSoft,
    required this.rise,
    required this.riseStrong,
    required this.warning,
    required this.onSelectCode,
  });

  final double width;
  final AuctionHistoryColumnData column;
  final String? selectedCode;
  final Color accent;
  final Color accentSoft;
  final Color rise;
  final Color riseStrong;
  final Color warning;
  final ValueChanged<String> onSelectCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: column.isLive
            ? accentSoft.withValues(alpha: 0.74)
            : AppTheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: column.isLive
              ? accent.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    column.tradeLabel ?? column.tradeDate ?? '--',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (column.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '实时',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '一字 ${column.yiziCount ?? '--'}  |  封单 ${column.sealAmount ?? '--'}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: column.timeLabels
                  .map(
                    (item) => Expanded(
                      child: Text(
                        item,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: column.items.isEmpty
                  ? Center(
                      child: Text(
                        '暂无数据。',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: column.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final item = column.items[index];
                        final selected = selectedCode == item.code;
                        final semanticsLabel =
                            'pw-auction-history-${column.tradeDate ?? column.tradeLabel ?? 'unknown'}-${item.code}';
                        final stockLabel = '${item.name} (${item.code})';
                        return Semantics(
                          container: true,
                          button: true,
                          selected: selected,
                          label: '$semanticsLabel $stockLabel',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => onSelectCode(item.code),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primary.withValues(alpha: 0.18)
                                    : index.isEven
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.primary.withValues(alpha: 0.46)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            color: selected ? accent : null,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        item.code,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: selected
                                              ? accent.withValues(alpha: 0.78)
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.lianban.isNotEmpty ||
                                      item.concepts.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        if (item.lianban.isNotEmpty)
                                          item.lianban,
                                        ...item.concepts.take(2),
                                      ].join(' / '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: selected
                                            ? accent.withValues(alpha: 0.82)
                                            : warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  _AuctionAmountRows(
                                    amounts: item.amounts,
                                    timeLabels: column.timeLabels,
                                    selected: selected,
                                  ),
                                  if (item.zhangfu.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      item.zhangfu,
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: selected
                                            ? _priceTone(
                                                item.zhangfu,
                                                rise,
                                                riseStrong,
                                              )
                                            : _priceTone(
                                                item.zhangfu,
                                                rise,
                                                riseStrong,
                                              ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuctionAmountRows extends StatelessWidget {
  const _AuctionAmountRows({
    required this.amounts,
    required this.timeLabels,
    required this.selected,
  });

  final List<String> amounts;
  final List<String> timeLabels;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (amounts.isEmpty) {
      return Text(
        '--',
        style: theme.textTheme.bodyMedium,
      );
    }

    final numericValues = amounts.map(_parseAuctionAmount).toList();
    return Column(
      children: List.generate(amounts.length, (index) {
        final value = numericValues[index];
        final previous = index == 0 ? null : numericValues[index - 1];
        final color = _auctionAmountTone(value, previous);
        final label = _amountTimeLabel(index, timeLabels);
        return Padding(
          padding: EdgeInsets.only(bottom: index == amounts.length - 1 ? 0 : 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.10)
                  : color.withValues(alpha: 0.08),
              border: Border(
                left: BorderSide(color: color, width: 3),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.mutedText,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    amounts[index],
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _AuctionRankTable extends StatelessWidget {
  const _AuctionRankTable({
    required this.section,
    required this.selectedCode,
    required this.onSelectCode,
  });

  final AuctionRankSectionData section;
  final String? selectedCode;
  final ValueChanged<String> onSelectCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderedItems = List<AuctionRankItemData>.of(section.items);
    if (selectedCode != null) {
      orderedItems.sort((left, right) {
        final leftSelected = left.code == selectedCode ? 1 : 0;
        final rightSelected = right.code == selectedCode ? 1 : 0;
        if (leftSelected != rightSelected) {
          return rightSelected.compareTo(leftSelected);
        }
        return 0;
      });
    }
    final matchCount = selectedCode == null
        ? 0
        : orderedItems.where((item) => item.code == selectedCode).length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.tabLabel,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(
                  selectedCode == null
                      ? '${section.total} 行'
                      : matchCount == 0
                          ? '${section.total} 行，选股未在本榜'
                          : '${section.total} 行，命中 $matchCount 条',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: orderedItems.isEmpty
                  ? Center(
                      child: Text(
                        '当前分组暂无数据。',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return Scrollbar(
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  dataRowMinHeight: 46,
                                  dataRowMaxHeight: 56,
                                  headingRowHeight: 36,
                                  columnSpacing: 8,
                                  horizontalMargin: 8,
                                  headingRowColor: WidgetStateProperty.all(
                                    AppTheme.primary.withValues(alpha: 0.06),
                                  ),
                                  columns: section.columns
                                      .map(
                                        (column) => DataColumn(
                                          label: SizedBox(
                                            width: _rankColumnWidth(column),
                                            child: Text(
                                              _columnLabel(column),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                  rows: orderedItems.map(
                                    (item) {
                                      final specs = _rankCellSpecs(
                                        section.columns,
                                        item,
                                      );
                                      return DataRow(
                                        selected: item.code == selectedCode,
                                        color: WidgetStateProperty.resolveWith(
                                          (states) {
                                            if (item.code == selectedCode) {
                                              return AppTheme.primary
                                                  .withValues(
                                                alpha: 0.10,
                                              );
                                            }
                                            return null;
                                          },
                                        ),
                                        onSelectChanged: (_) =>
                                            onSelectCode(item.code),
                                        cells: specs
                                            .map(
                                              (spec) => DataCell(
                                                Semantics(
                                                  container: true,
                                                  label:
                                                      'pw-auction-rank-${section.key}-${item.code}-${spec.column}',
                                                  child: SizedBox(
                                                    width: _rankColumnWidth(
                                                      spec.column,
                                                    ),
                                                    child:
                                                        _AuctionRankValueCell(
                                                      spec: spec,
                                                    ),
                                                  ),
                                                ),
                                                onTap: () =>
                                                    onSelectCode(item.code),
                                              ),
                                            )
                                            .toList(growable: false),
                                      );
                                    },
                                  ).toList(growable: false),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuctionRankValueCell extends StatelessWidget {
  const _AuctionRankValueCell({
    required this.spec,
  });

  final _AuctionRankCellSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = spec.secondary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          spec.primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: spec.primaryColor,
            fontWeight: spec.emphasize ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        if (secondary != null && secondary.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: spec.secondaryColor ?? AppTheme.mutedText,
            ),
          ),
        ],
      ],
    );
  }
}

class _AuctionRankCellSpec {
  const _AuctionRankCellSpec({
    required this.column,
    required this.primary,
    this.secondary,
    this.primaryColor,
    this.secondaryColor,
    this.emphasize = false,
  });

  final String column;
  final String primary;
  final String? secondary;
  final Color? primaryColor;
  final Color? secondaryColor;
  final bool emphasize;
}

class _AuctionStrengthPanel extends StatelessWidget {
  const _AuctionStrengthPanel({
    required this.signals,
    required this.onSelectCode,
  });

  final List<_AuctionStrengthSignal> signals;
  final ValueChanged<String> onSelectCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.primaryOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '竞价加强方向',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.text,
                  ),
                ),
              ),
              Text(
                signals.isEmpty ? '暂无加强票' : '${signals.length} 只',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (signals.isEmpty)
            Text(
              '当前快照没有出现 9:25 封单高于 9:20 的股票。',
              style: theme.textTheme.bodyMedium,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final useGrid = constraints.maxWidth >= 1040;
                final itemWidth = useGrid
                    ? (constraints.maxWidth - 16) / 3
                    : constraints.maxWidth >= 680
                        ? (constraints.maxWidth - 8) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: signals
                      .map(
                        (signal) => SizedBox(
                          width: itemWidth,
                          child: _AuctionStrengthRow(
                            signal: signal,
                            onTap: () => onSelectCode(signal.code),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AuctionStrengthRow extends StatelessWidget {
  const _AuctionStrengthRow({
    required this.signal,
    required this.onTap,
  });

  final _AuctionStrengthSignal signal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conceptText = [
      if (signal.lianban.trim().isNotEmpty) signal.lianban.trim(),
      if (signal.zhangfu.trim().isNotEmpty) signal.zhangfu.trim(),
      ...signal.concepts,
    ].join(' / ');
    return Semantics(
      button: true,
      label: 'pw-auction-strength-${signal.code}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.primaryOutline),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        signal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        signal.code,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_formatCompactYuan(signal.amount920)} -> ${_formatCompactYuan(signal.amount925)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        conceptText.isEmpty ? '未标注概念' : conceptText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '+${_formatCompactYuan(signal.delta)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.secondary,
                        ),
                      ),
                      Text(
                        signal.ratio == null
                            ? '新增'
                            : '+${(signal.ratio! * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _SelectedFocusCard extends StatelessWidget {
  const _SelectedFocusCard({
    required this.profile,
    required this.onOpenStock,
  });

  final _SelectedProfile profile;
  final VoidCallback onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
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
                    Text(
                      '${profile.name} (${profile.code})',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.lianban.isEmpty
                          ? '当前未标注连板标签'
                          : '连板标签 ${profile.lianban}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${profile.dayMatches.length} 日出现',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onOpenStock,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('打开股票'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...profile.dayMatches.map(
                (item) => _FocusTag(label: item),
              ),
              ...profile.rankMatches.map(
                (item) => _FocusTag(label: item, warning: true),
              ),
            ],
          ),
          if (profile.concepts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile.concepts.join(' / '),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FocusTag extends StatelessWidget {
  const _FocusTag({
    required this.label,
    this.warning = false,
  });

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: warning
            ? AppTheme.secondary.withValues(alpha: 0.12)
            : AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: warning ? AppTheme.secondary : AppTheme.primary,
            ),
      ),
    );
  }
}

class _AuctionStrengthSignal {
  const _AuctionStrengthSignal({
    required this.code,
    required this.name,
    required this.lianban,
    required this.zhangfu,
    required this.concepts,
    required this.amount920,
    required this.amount925,
    required this.delta,
    required this.ratio,
  });

  final String code;
  final String name;
  final String lianban;
  final String zhangfu;
  final List<String> concepts;
  final double amount920;
  final double amount925;
  final double delta;
  final double? ratio;
}

class _SelectedProfile {
  const _SelectedProfile({
    required this.code,
    required this.name,
    required this.concepts,
    required this.lianban,
    required this.dayMatches,
    required this.rankMatches,
  });

  final String code;
  final String name;
  final List<String> concepts;
  final String lianban;
  final List<String> dayMatches;
  final List<String> rankMatches;
}

Color _priceTone(String value, Color rise, Color riseStrong) {
  if (value.contains('-')) {
    return AppTheme.fall;
  }
  if (value.contains('+')) {
    return riseStrong;
  }
  return rise;
}

String _amountTimeLabel(int index, List<String> labels) {
  final timeLabels = labels
      .where((label) => RegExp(r'^\d{1,2}:\d{2}$').hasMatch(label.trim()))
      .toList(growable: false);
  if (index < timeLabels.length) {
    return timeLabels[index];
  }
  const fallback = ['9:15', '9:20', '9:25'];
  if (index < fallback.length) {
    return fallback[index];
  }
  return '${index + 1}';
}

double? _parseAuctionAmount(String value) {
  final normalized = value.replaceAll(',', '').trim();
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
  if (match == null) {
    return null;
  }
  final number = double.tryParse(match.group(0)!);
  if (number == null) {
    return null;
  }
  if (normalized.contains('亿')) {
    return number * 100000000;
  }
  if (normalized.contains('万')) {
    return number * 10000;
  }
  return number;
}

String _formatCompactYuan(double value) {
  final absValue = value.abs();
  if (absValue >= 100000000) {
    return '${_trimCompactNumber(value / 100000000)}亿';
  }
  if (absValue >= 10000) {
    return '${_trimCompactNumber(value / 10000)}万';
  }
  return _trimCompactNumber(value);
}

String _trimCompactNumber(double value) {
  if (value.abs() >= 100) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

Color _auctionAmountTone(double? value, double? previous) {
  if (value == null) {
    return AppTheme.mutedText;
  }
  if (previous != null) {
    if (value >= previous * 1.15) {
      return AppTheme.rise;
    }
    if (value <= previous * 0.72) {
      return AppTheme.fall;
    }
  }
  if (value >= 1000000000) {
    return AppTheme.danger;
  }
  if (value >= 300000000) {
    return AppTheme.rise;
  }
  if (value >= 100000000) {
    return AppTheme.secondary;
  }
  return AppTheme.mutedText;
}

String _normalizeAuctionTitle(String? title, String? tradeDate) {
  final normalized = _stripAuctionTitleHtml(title ?? '');
  final fallback =
      tradeDate == null || tradeDate.isEmpty ? '竞价异动' : '$tradeDate 竞价异动';
  if (normalized.isEmpty) {
    return fallback;
  }
  return normalized
      .replaceAll('Auction Live', '竞价异动')
      .replaceAll('Auction Desk', '牛牛竞价')
      .replaceAll(RegExp(r'\bYi\s*:', caseSensitive: false), '一字:')
      .replaceAll(RegExp(r'\bSeal\s*:', caseSensitive: false), '封单:')
      .replaceAll(
        RegExp(r'(-?\d+(?:\.\d+)?)\s*yi\b', caseSensitive: false),
        r'$1亿',
      )
      .replaceAll(
        RegExp(r'(-?\d+(?:\.\d+)?)\s*wan\b', caseSensitive: false),
        r'$1万',
      );
}

String _stripAuctionTitleHtml(String value) {
  var text = value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' | ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  text = text.replaceAll(RegExp(r'\s*/\s*'), ' | ');
  text = text.replaceAll(RegExp(r'\s*\|\s*'), ' | ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(
    RegExp(r'\s*\|\s*9:15\s*\|\s*9:20\s*\|\s*9:25\s*\|\s*[^|]+$'),
    '',
  );
  return text.trim().replaceAll(RegExp(r'^\|+|\|+$'), '').trim();
}

String _formatTimestamp(String? value) {
  if (value == null || value.isEmpty) {
    return '--';
  }
  return value.replaceFirst('T', ' ').split('.').first;
}

String _cleanErrorMessage(Object error) {
  return error
      .toString()
      .replaceFirst(RegExp(r'^(Bad state: |Exception: )'), '')
      .trim();
}

List<_AuctionRankCellSpec> _rankCellSpecs(
  List<String> columns,
  AuctionRankItemData item,
) {
  return List<_AuctionRankCellSpec>.generate(columns.length, (index) {
    final column = columns[index];
    final fallback = index < item.cells.length ? item.cells[index] : '--';
    return _rankCellSpec(column, item, fallback);
  }, growable: false);
}

_AuctionRankCellSpec _rankCellSpec(
  String column,
  AuctionRankItemData item,
  String fallback,
) {
  final fallbackParts = _splitRankFallback(fallback);
  final fallbackPrimary = fallbackParts.first;
  final fallbackSecondary = fallbackParts.length > 1 ? fallbackParts[1] : null;

  switch (column) {
    case 'name':
      return _AuctionRankCellSpec(
        column: column,
        primary: _cleanRankText(item.name, fallbackPrimary),
        secondary: _cleanRankText(item.code, fallbackSecondary),
        emphasize: true,
      );
    case 'board':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatBoardText(
          item.boardText,
          item.boardCount,
          fallbackPrimary,
        ),
        secondary: _cleanNullableRankText(item.boardDesc) ?? fallbackSecondary,
        primaryColor: _boardTone(item.boardCount),
        emphasize: true,
      );
    case 'entrust_match':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatYuanAmount(item.entrustAmountYuan, fallbackPrimary),
        secondary: item.matchAmountYuan == null && fallbackSecondary != null
            ? fallbackSecondary
            : _formatYuanAmount(item.matchAmountYuan),
        primaryColor: AppTheme.rise,
      );
    case 'seal_amount':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatWanAmount(item.sealAmountWan, fallbackPrimary),
        secondary: _formatBoardText(
          item.boardText,
          item.boardCount,
          fallbackSecondary,
        ),
        primaryColor: AppTheme.secondary,
        emphasize: true,
      );
    case 'bid_vs_now':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatPct(item.bidChangePct, fallbackPrimary),
        secondary: item.currentChangePct == null && fallbackSecondary != null
            ? fallbackSecondary
            : _formatPct(item.currentChangePct),
        primaryColor: _numericTone(item.bidChangePct),
        secondaryColor: _numericTone(item.currentChangePct),
        emphasize: true,
      );
    case 'bid_vs_yesterday':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatWanAmount(item.bidAmountWan, fallbackPrimary),
        secondary: item.previousAmountWan == null && fallbackSecondary != null
            ? fallbackSecondary
            : _formatWanAmount(item.previousAmountWan),
        primaryColor: AppTheme.secondary,
      );
    case 'ratio_vs_seal':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatPct(item.ratioPct, fallbackPrimary, false),
        secondary: item.sealAmountWan == null && fallbackSecondary != null
            ? fallbackSecondary
            : _formatWanAmount(item.sealAmountWan),
      );
    case 'bid_amount':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatWanAmount(item.bidAmountWan, fallbackPrimary),
        secondary: item.previousAmountWan == null
            ? fallbackSecondary
            : _formatWanAmount(item.previousAmountWan),
        primaryColor: AppTheme.secondary,
        emphasize: true,
      );
    case 'volume_ratio':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatVolumeRatio(item.volumeRatio, fallbackPrimary),
      );
    case 'grab_pct':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatPct(item.grabPct, fallbackPrimary),
        primaryColor: _numericTone(item.grabPct),
        emphasize: true,
      );
    case 'net_amount':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatWanAmount(item.netAmountWan, fallbackPrimary),
        primaryColor: _numericTone(item.netAmountWan),
        emphasize: true,
      );
    case 'float_cap':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatYiAmount(item.floatMarketCapYi, fallbackPrimary),
      );
    case 'yesterday_change':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatPct(item.yesterdayChangePct, fallbackPrimary),
        primaryColor: _numericTone(item.yesterdayChangePct),
      );
    case 'concept':
      return _AuctionRankCellSpec(
        column: column,
        primary: _cleanRankText(item.concept, fallbackPrimary),
      );
    case 'concept_vs_cap':
      return _AuctionRankCellSpec(
        column: column,
        primary: _cleanRankText(item.concept, fallbackPrimary),
        secondary: _formatYiAmount(item.floatMarketCapYi, fallbackSecondary),
      );
    case 'cap_vs_price':
      return _AuctionRankCellSpec(
        column: column,
        primary: _formatYiAmount(item.floatMarketCapYi, fallbackPrimary),
        secondary: item.price == null && fallbackSecondary != null
            ? fallbackSecondary
            : _formatPrice(item.price),
      );
    case 'action':
      return _AuctionRankCellSpec(
        column: column,
        primary: _cleanRankText(item.action, '查看'),
        primaryColor: AppTheme.secondary,
        emphasize: true,
      );
    default:
      return _AuctionRankCellSpec(
        column: column,
        primary: fallbackPrimary,
        secondary: fallbackSecondary,
      );
  }
}

List<String> _splitRankFallback(String value) {
  final parts = value
      .split(RegExp(r'\s*/\s*'))
      .map(_normalizeRankDisplayText)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return parts.isEmpty ? const ['--'] : parts;
}

String _cleanRankText(String? value, [String? fallback = '--']) {
  final normalized = _cleanNullableRankText(value);
  if (normalized != null) {
    return normalized;
  }
  final normalizedFallback = fallback?.trim();
  return normalizedFallback == null || normalizedFallback.isEmpty
      ? '--'
      : normalizedFallback;
}

String? _cleanNullableRankText(String? value) {
  final normalized = _normalizeRankDisplayText(value ?? '');
  if (normalized.isEmpty ||
      normalized == '-' ||
      normalized == '--' ||
      normalized.toLowerCase() == 'null') {
    return null;
  }
  return normalized;
}

String _normalizeRankDisplayText(String value) {
  var normalized = value.trim();
  if (normalized.isEmpty) {
    return normalized;
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
    'view': '查看',
    'open': '查看',
    'null': '--',
  };
  return labels[normalized.toLowerCase()] ?? normalized;
}

String _formatPct(double? value, [String? fallback, bool signed = false]) {
  if (value == null) {
    return _cleanRankText(null, fallback ?? '--');
  }
  final sign = signed && value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

String _formatVolumeRatio(double? value, String fallback) {
  if (value == null) {
    return _cleanRankText(null, fallback);
  }
  return value.toStringAsFixed(1);
}

String _formatYuanAmount(double? value, [String? fallback]) {
  if (value == null) {
    return _cleanRankText(null, fallback ?? '--');
  }
  final absValue = value.abs();
  if (absValue >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(1)}亿';
  }
  if (absValue >= 10000) {
    return '${(value / 10000).round()}万';
  }
  return value.round().toString();
}

String _formatWanAmount(double? value, [String? fallback]) {
  if (value == null) {
    return _cleanRankText(null, fallback ?? '--');
  }
  if (value.abs() >= 10000) {
    return '${(value / 10000).toStringAsFixed(1)}亿';
  }
  return '${value.round()}万';
}

String _formatYiAmount(double? value, [String? fallback]) {
  if (value == null) {
    return _cleanRankText(null, fallback ?? '--');
  }
  final decimals = value.abs() >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)}亿';
}

String _formatPrice(double? value) {
  if (value == null) {
    return '--';
  }
  return value.toStringAsFixed(2);
}

String _formatBoardText(String? value, int? count, [String? fallback]) {
  if (count != null && count > 0) {
    return count == 1 ? '首板' : '$count连板';
  }
  final text = _cleanNullableRankText(value);
  if (text == null) {
    return _cleanRankText(null, fallback ?? '--');
  }
  if (text == 'first board') {
    return '首板';
  }
  final match = RegExp(r'^(\d+)\s+board$').firstMatch(text);
  if (match != null) {
    final boardCount = int.tryParse(match.group(1) ?? '');
    if (boardCount != null) {
      return boardCount == 1 ? '首板' : '$boardCount连板';
    }
  }
  return text;
}

Color? _numericTone(double? value) {
  if (value == null) {
    return null;
  }
  if (value > 0) {
    return AppTheme.rise;
  }
  if (value < 0) {
    return AppTheme.fall;
  }
  return AppTheme.mutedText;
}

Color? _boardTone(int? boardCount) {
  if (boardCount == null) {
    return null;
  }
  if (boardCount >= 4) {
    return AppTheme.rise;
  }
  if (boardCount >= 2) {
    return AppTheme.secondary;
  }
  return null;
}

double _rankColumnWidth(String column) {
  return switch (column) {
    'name' => 108,
    'board' => 82,
    'entrust_match' => 96,
    'seal_amount' => 78,
    'bid_vs_now' => 84,
    'bid_vs_yesterday' => 96,
    'ratio_vs_seal' => 88,
    'concept' => 110,
    'concept_vs_cap' => 112,
    'cap_vs_price' => 96,
    'bid_amount' => 88,
    'volume_ratio' => 70,
    'grab_pct' => 78,
    'net_amount' => 86,
    'float_cap' => 82,
    'yesterday_change' => 76,
    'action' => 50,
    _ => 96,
  };
}

String _columnLabel(String value) {
  const labels = {
    'name': '名称',
    'board': '连板',
    'entrust_match': '委买/撮合',
    'seal_amount': '封单',
    'bid_vs_now': '竞涨/现涨',
    'concept': '概念',
    'cap_vs_price': '流值/现价',
    'bid_vs_yesterday': '竞额/昨额',
    'ratio_vs_seal': '竞比/封单',
    'concept_vs_cap': '概念/市值',
    'bid_amount': '竞价金额',
    'volume_ratio': '竞价量比',
    'action': '查看',
    'grab_pct': '抢筹幅度',
    'net_amount': '主力净买',
    'float_cap': '流通值',
    'yesterday_change': '昨涨幅',
  };
  return labels[value] ?? value;
}
