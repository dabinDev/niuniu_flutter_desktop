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
import '../../../shared/widgets/weakness_section_panel.dart';
import '../application/yesterday_stats_provider.dart';

class YesterdayStatsPage extends ConsumerStatefulWidget {
  const YesterdayStatsPage({
    super.key,
    this.initialTradeDate,
    this.initialSectionKey,
  });

  final String? initialTradeDate;
  final String? initialSectionKey;

  @override
  ConsumerState<YesterdayStatsPage> createState() => _YesterdayStatsPageState();
}

class _YesterdayStatsPageState extends ConsumerState<YesterdayStatsPage> {
  final GlobalKey _captureKey = GlobalKey();
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};
  String? _lastScrolledSectionKey;

  GlobalKey _keyForSection(String key) {
    return _sectionKeys.putIfAbsent(
      canonicalWeaknessSectionKey(key),
      () => GlobalKey(),
    );
  }

  void _queueScrollToSection(String? key) {
    if (key == null || key == _lastScrolledSectionKey) {
      return;
    }
    _lastScrolledSectionKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final targetContext = _sectionKeys[key]?.currentContext;
      if (targetContext == null) {
        return;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
      );
    });
  }

  String? _resolveReviewTradeDate(YesterdayStatsSnapshot snapshot) {
    final tradeDate = snapshot.tradeDate?.trim();
    if (tradeDate != null && tradeDate.isNotEmpty) {
      return tradeDate;
    }
    final todayTradeDate = snapshot.tradeDates['today']?.trim();
    if (todayTradeDate != null && todayTradeDate.isNotEmpty) {
      return todayTradeDate;
    }
    return null;
  }

  String? _normalizeTradeDate(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _openReviewSection(
    BuildContext context, {
    required String tradeDate,
    required YesterdayStatsSectionData section,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final uri = Uri(
      path: '/limit-review',
      queryParameters: <String, String>{
        'tradeDate': tradeDate,
        'section': canonicalWeaknessSectionKey(section.key),
      },
    );
    router.go(uri.toString());
  }

  Future<void> _copyWorkspaceImage() async {
    final result = await captureWorkspaceImage(
      repaintBoundaryKey: _captureKey,
      context: context,
      bundleName: 'yesterday_stats_workspace',
      fileName: '空头数据.png',
    );
    if (result == null) {
      _showInfo('当前工作区暂时无法生成图片。');
      return;
    }
    _showInfo(
      result.copiedToClipboard
          ? '空头数据图片已复制到剪贴板。'
          : '空头数据图片已导出：${result.filePath}',
    );
  }

  Future<void> _copySnapshotText(YesterdayStatsSnapshot snapshot) async {
    final buffer = StringBuffer()
      ..writeln('空头数据')
      ..writeln('交易日：${snapshot.tradeDate ?? '--'}')
      ..writeln('快照：${_formatTimestamp(snapshot.fetchedAt)}')
      ..writeln(
          '今日：涨停 ${snapshot.todayStats.zt} 连板 ${snapshot.todayStats.lb} 炸板 ${snapshot.todayStats.zb} 跌停 ${snapshot.todayStats.dt} 封板率 ${snapshot.todayStats.fbl}%')
      ..writeln(
          '昨日：涨停 ${snapshot.yesterdayStats.zt} 连板 ${snapshot.yesterdayStats.lb} 炸板 ${snapshot.yesterdayStats.zb} 跌停 ${snapshot.yesterdayStats.dt} 封板率 ${snapshot.yesterdayStats.fbl}%');
    for (final section in orderWeaknessSections(snapshot.sections)) {
      buffer
        ..writeln()
        ..writeln('[${weaknessSectionTitle(section)}]');
      buffer.writeln('代码\t名称\t地区\t行业\t价格\t开盘涨幅\t涨跌幅\t成交额(亿)');
      for (final item in section.items) {
        buffer.writeln(
          [
            item.code,
            item.name,
            item.region ?? '--',
            item.industry ?? '--',
            _fmtNumber(item.price),
            _fmtPct(item.openChangePct),
            _fmtPct(item.changePct),
            _fmtNumber(item.amountYi),
          ].join('\t'),
        );
      }
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    _showInfo('空头数据已复制到剪贴板。');
  }

  Future<void> _exportSnapshotExcel(YesterdayStatsSnapshot snapshot) async {
    final files = _buildSnapshotExportFiles(snapshot);
    final filePath = await writeExcelWorkbook(
      bundleName: 'yesterday_stats',
      fileName: '空头数据.xlsx',
      sheets: files.entries
          .map((entry) => ExcelSheetData(name: entry.key, rows: entry.value))
          .toList(growable: false),
    );
    _showInfo('空头数据 Excel 已导出：$filePath');
  }

  Future<void> _exportSnapshotCsv(YesterdayStatsSnapshot snapshot) async {
    final result = await writeCsvBundle(
      bundleName: 'yesterday_stats',
      files: _buildSnapshotExportFiles(snapshot),
    );
    _showInfo('空头数据 CSV 已导出：${result.directoryPath}');
  }

  Map<String, List<List<String>>> _buildSnapshotExportFiles(
    YesterdayStatsSnapshot snapshot,
  ) {
    final files = <String, List<List<String>>>{
      'summary': [
        ['trade_date', snapshot.tradeDate ?? '--'],
        ['snapshot_at', _formatTimestamp(snapshot.fetchedAt)],
        ['today_limit_up', '${snapshot.todayStats.zt}'],
        ['today_board', '${snapshot.todayStats.lb}'],
        ['today_broken', '${snapshot.todayStats.zb}'],
        ['today_limit_down', '${snapshot.todayStats.dt}'],
        ['today_seal_rate', '${snapshot.todayStats.fbl}%'],
        ['yesterday_limit_up', '${snapshot.yesterdayStats.zt}'],
        ['yesterday_board', '${snapshot.yesterdayStats.lb}'],
        ['yesterday_broken', '${snapshot.yesterdayStats.zb}'],
        ['yesterday_limit_down', '${snapshot.yesterdayStats.dt}'],
        ['yesterday_seal_rate', '${snapshot.yesterdayStats.fbl}%'],
      ],
    };

    for (final section in orderWeaknessSections(snapshot.sections)) {
      files[weaknessSectionTitle(section)] = [
        [
          'code',
          'name',
          'region',
          'industry',
          'price',
          'open_change_pct',
          'change_pct',
          'amount_yi'
        ],
        ...section.items.map(
          (item) => [
            item.code,
            item.name,
            item.region ?? '--',
            item.industry ?? '--',
            _fmtNumber(item.price),
            _fmtPct(item.openChangePct),
            _fmtPct(item.changePct),
            _fmtNumber(item.amountYi),
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

  @override
  Widget build(BuildContext context) {
    final selectedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
    final provider = yesterdayStatsProvider(selectedTradeDate);
    final data = ref.watch(provider);

    return AppShell(
      currentPath: '/yesterday-stats',
      title: '空头数据',
      subtitle: '按旧版四宫格结构展示昨日与今日的弱势分组，并补齐地区、行业和样本明细。',
      child: data.when(
        data: (snapshot) {
          final highlightedSectionKey = resolveWeaknessSectionSelectionKey(
            snapshot.sections,
            widget.initialSectionKey,
          );
          final reviewTradeDate = _resolveReviewTradeDate(snapshot);
          _queueScrollToSection(highlightedSectionKey);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(provider);
              await ref.read(provider.future);
            },
            child: RepaintBoundary(
              key: _captureKey,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _WorkspaceHeader(
                    snapshot: snapshot,
                    onRefresh: () => ref.invalidate(provider),
                    onCopyImage: _copyWorkspaceImage,
                    onCopyText: () => _copySnapshotText(snapshot),
                    onExportExcel: () => _exportSnapshotExcel(snapshot),
                    onExportCsv: () => _exportSnapshotCsv(snapshot),
                    highlightedSectionKey: highlightedSectionKey,
                    onOpenReviewSection: reviewTradeDate == null
                        ? null
                        : (section) => _openReviewSection(
                              context,
                              tradeDate: reviewTradeDate,
                              section: section,
                            ),
                  ),
                  const SizedBox(height: 12),
                  _MatrixWorkspace(
                    snapshot: snapshot,
                    highlightedSectionKey: highlightedSectionKey,
                    panelKeyForSection: _keyForSection,
                    onOpenStock: (code) => openStockLinkFromUi(
                      context: context,
                      ref: ref,
                      code: code,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '空头数据请求失败：$error',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.snapshot,
    required this.onRefresh,
    required this.onCopyImage,
    required this.onCopyText,
    required this.onExportExcel,
    required this.onExportCsv,
    this.highlightedSectionKey,
    this.onOpenReviewSection,
  });

  final YesterdayStatsSnapshot snapshot;
  final VoidCallback onRefresh;
  final VoidCallback onCopyImage;
  final VoidCallback onCopyText;
  final VoidCallback onExportExcel;
  final VoidCallback onExportCsv;
  final String? highlightedSectionKey;
  final ValueChanged<YesterdayStatsSectionData>? onOpenReviewSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = snapshot.todayStats.fbl - snapshot.yesterdayStats.fbl;
    final orderedSections = orderWeaknessSections(snapshot.sections);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.panelDecoration(
        radius: 8,
        color: theme.colorScheme.surface,
        borderColor: theme.colorScheme.outlineVariant,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      container: true,
                      header: true,
                      label: '\u7a7a\u5934\u770b\u677f',
                      child: const SizedBox.shrink(),
                    ),
                    Text('空头看板', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '交易日 ${snapshot.tradeDate ?? '--'}'
                      '  |  快照 ${_formatTimestamp(snapshot.fetchedAt)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '沿用旧版四宫格阅读方式，优先观察跌停与断板的弱势聚集方向。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Semantics(
                          button: true,
                          label: 'pw-yesterday-refresh',
                          child: FilledButton.tonalIcon(
                            onPressed: onRefresh,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('刷新'),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: onCopyImage,
                          icon: const Icon(Icons.image_rounded),
                          label: const Text('复制图片'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onCopyText,
                          icon: const Icon(Icons.copy_all_rounded),
                          label: const Text('复制文本'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onExportExcel,
                          icon: const Icon(Icons.table_chart_rounded),
                          label: const Text('导出 Excel'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onExportCsv,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('导出 CSV'),
                        ),
                        Semantics(
                          container: true,
                          label:
                              'pw-yesterday-trade-date-today-${snapshot.tradeDates['today'] ?? '--'}',
                          child: _InfoChip(
                            icon: Icons.calendar_today_rounded,
                            label: snapshot.tradeDates['today'] ?? '--',
                          ),
                        ),
                        Semantics(
                          container: true,
                          label:
                              'pw-yesterday-trade-date-yesterday-${snapshot.tradeDates['yesterday'] ?? '--'}',
                          child: _InfoChip(
                            icon: Icons.history_rounded,
                            label: snapshot.tradeDates['yesterday'] ?? '--',
                          ),
                        ),
                        if (highlightedSectionKey != null)
                          _InfoChip(
                            icon: Icons.my_location_rounded,
                            label:
                                '定位 ${formatWeaknessTitle(highlightedSectionKey!)}',
                            accent:
                                weaknessSectionAccent(highlightedSectionKey!),
                          ),
                        _InfoChip(
                          icon: Icons.trending_down_rounded,
                          label:
                              '封板率 ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
                          accent: delta >= 0
                              ? const Color(0xFFC9553F)
                              : AppTheme.fall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _EmotionStrip(
                title: '今日',
                dateLabel: snapshot.tradeDates['today'] ?? '--',
                stats: snapshot.todayStats,
              ),
              _EmotionStrip(
                title: '昨日',
                dateLabel: snapshot.tradeDates['yesterday'] ?? '--',
                stats: snapshot.yesterdayStats,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 920) {
                return Row(
                  children: orderedSections.asMap().entries.map((entry) {
                    final section = entry.value;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right:
                              entry.key == orderedSections.length - 1 ? 0 : 10,
                        ),
                        child: _SectionOverviewChip(
                          width: double.infinity,
                          section: section,
                          onOpenReview: onOpenReviewSection == null
                              ? null
                              : () => onOpenReviewSection!(section),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: orderedSections
                      .map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _SectionOverviewChip(
                            section: section,
                            onOpenReview: onOpenReviewSection == null
                                ? null
                                : () => onOpenReviewSection!(section),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmotionStrip extends StatelessWidget {
  const _EmotionStrip({
    required this.title,
    required this.dateLabel,
    required this.stats,
  });

  final String title;
  final String dateLabel;
  final EmotionStatsData stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 210,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              Text(dateLabel, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatChip(label: '涨停', value: '${stats.zt}'),
              _StatChip(label: '连板', value: '${stats.lb}'),
              _StatChip(label: '炸板', value: '${stats.zb}'),
              _StatChip(label: '跌停', value: '${stats.dt}'),
              _StatChip(label: '封板率', value: '${stats.fbl}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label $value', style: theme.textTheme.bodySmall),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = accent ?? theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _SectionOverviewChip extends StatelessWidget {
  const _SectionOverviewChip({
    required this.section,
    this.onOpenReview,
    this.width = 210,
  });

  final YesterdayStatsSectionData section;
  final VoidCallback? onOpenReview;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = weaknessSectionAccent(section.key);
    final preview = section.items.take(2).map((item) => item.name).join(' / ');
    final routeKey = canonicalWeaknessSectionKey(section.key);

    return Semantics(
      button: true,
      label: 'pw-yesterday-review-$routeKey review entry',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('yesterday-stats-review-$routeKey'),
          onTap: onOpenReview,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            width: width,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weaknessSectionTitle(section)}  ${section.total}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  preview.isEmpty ? '当前暂无预览样本' : preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (onOpenReview != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '进入复盘',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 16,
                        color: accent,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatrixWorkspace extends StatelessWidget {
  const _MatrixWorkspace({
    required this.snapshot,
    required this.onOpenStock,
    required this.panelKeyForSection,
    this.highlightedSectionKey,
  });

  final YesterdayStatsSnapshot snapshot;
  final ValueChanged<String> onOpenStock;
  final GlobalKey Function(String key) panelKeyForSection;
  final String? highlightedSectionKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = orderWeaknessSections(snapshot.sections);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1020;
        final panelHeight = isWide ? 390.0 : 350.0;
        final matrixSemanticTitle = Semantics(
          container: true,
          header: true,
          label: '\u56db\u8c61\u9650\u5f31\u52bf\u77e9\u9635',
          child: const SizedBox.shrink(),
        );

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.panelDecoration(
            radius: 8,
            color: theme.colorScheme.surface,
            borderColor: theme.colorScheme.outlineVariant,
            elevated: false,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              matrixSemanticTitle,
              Text('四象限弱势矩阵', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '直接对齐旧版 2 x 2 工作区，四个分组统一展开个股表格。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (isWide)
                Column(
                  children: [
                    for (var index = 0; index < sections.length; index += 2)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index + 2 < sections.length ? 12 : 0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var offset = 0; offset < 2; offset += 1) ...[
                              if (index + offset < sections.length)
                                Expanded(
                                  child: SizedBox(
                                    key: panelKeyForSection(
                                      sections[index + offset].key,
                                    ),
                                    height: panelHeight,
                                    child: WeaknessSectionPanel(
                                      section: sections[index + offset],
                                      onOpenStock: onOpenStock,
                                      keyPrefix: 'yesterday-stats',
                                      highlighted: canonicalWeaknessSectionKey(
                                            sections[index + offset].key,
                                          ) ==
                                          highlightedSectionKey,
                                      highlightLabel: '总览定位',
                                    ),
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox.shrink()),
                              if (offset == 0) const SizedBox(width: 12),
                            ],
                          ],
                        ),
                      ),
                  ],
                )
              else
                Column(
                  children: sections
                      .map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            key: panelKeyForSection(section.key),
                            height: panelHeight,
                            child: WeaknessSectionPanel(
                              section: section,
                              onOpenStock: onOpenStock,
                              keyPrefix: 'yesterday-stats',
                              highlighted:
                                  canonicalWeaknessSectionKey(section.key) ==
                                      highlightedSectionKey,
                              highlightLabel: '总览定位',
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _formatTimestamp(String? value) {
  if (value == null || value.isEmpty) {
    return '--';
  }
  return value.replaceFirst('T', ' ').split('.').first;
}

String _fmtNumber(double? value) {
  if (value == null) {
    return '--';
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

String _fmtPct(double? value) {
  if (value == null) {
    return '--';
  }
  final sign = value > 0 ? '+' : '';
  return '$sign${_fmtNumber(value)}%';
}
