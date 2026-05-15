import 'dart:async';
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
import '../../../shared/data/ai_analysis_data.dart';
import '../../../shared/data/market_api_repository.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/ai_analysis_panel.dart';
import '../../../shared/widgets/ai_primary_action_button.dart';
import '../../../shared/widgets/weakness_section_panel.dart';
import '../../ask_ai/application/ask_ai_provider.dart';
import '../application/limit_review_provider.dart';
import '../data/review_repository.dart';

class LimitReviewPage extends ConsumerStatefulWidget {
  const LimitReviewPage({
    super.key,
    this.initialTradeDate,
    this.initialSectionKey,
  });

  final String? initialTradeDate;
  final String? initialSectionKey;

  @override
  ConsumerState<LimitReviewPage> createState() => _LimitReviewPageState();
}

class _LimitReviewPageState extends ConsumerState<LimitReviewPage> {
  static const _autoRefreshInterval = Duration(seconds: 5);
  static const _reviewColumnPresets = <String, _ReviewTableColumnSpec>{
    'stock_name': _ReviewTableColumnSpec(
      'stock_name',
      '股票名称',
      168,
      TextAlign.left,
    ),
    'stock_code': _ReviewTableColumnSpec(
      'stock_code',
      '股票代码',
      96,
      TextAlign.center,
    ),
    'change_pct': _ReviewTableColumnSpec(
      'change_pct',
      '现涨幅',
      92,
      TextAlign.right,
    ),
    'pre_close_price': _ReviewTableColumnSpec(
      'pre_close_price',
      '昨收价',
      88,
      TextAlign.right,
    ),
    'board_count': _ReviewTableColumnSpec(
      'board_count',
      '板数',
      68,
      TextAlign.center,
    ),
    'lianban_text': _ReviewTableColumnSpec(
      'lianban_text',
      '连板',
      76,
      TextAlign.center,
    ),
    'board_shape': _ReviewTableColumnSpec(
      'board_shape',
      '板形',
      82,
      TextAlign.center,
    ),
    'first_limit_time': _ReviewTableColumnSpec(
      'first_limit_time',
      '首次封板',
      98,
      TextAlign.center,
    ),
    'final_limit_time': _ReviewTableColumnSpec(
      'final_limit_time',
      '最终封板',
      98,
      TextAlign.center,
    ),
    'amount_yi': _ReviewTableColumnSpec(
      'amount_yi',
      '成交额',
      104,
      TextAlign.right,
    ),
    'float_market_cap_yi': _ReviewTableColumnSpec(
      'float_market_cap_yi',
      '实际流通',
      112,
      TextAlign.right,
    ),
    'total_market_cap_yi': _ReviewTableColumnSpec(
      'total_market_cap_yi',
      '总市值',
      112,
      TextAlign.right,
    ),
    'turnover_rate': _ReviewTableColumnSpec(
      'turnover_rate',
      '换手率',
      92,
      TextAlign.right,
    ),
    'reason': _ReviewTableColumnSpec(
      'reason',
      '异动原因',
      280,
      TextAlign.left,
    ),
    'theme': _ReviewTableColumnSpec(
      'theme',
      '题材',
      140,
      TextAlign.left,
    ),
  };
  final GlobalKey _captureKey = GlobalKey();
  final Map<String, GlobalKey> _weaknessSectionKeys = <String, GlobalKey>{};
  String? _selectedTradeDate;
  String? _highlightedWeaknessSectionKey;
  String? _pendingInitialWeaknessSectionKey;
  String? _appliedInitialWeaknessSectionKey;
  AiAnalysisStateData? _aiReviewOverride;
  bool _autoRefresh = false;
  bool _isRefreshing = false;
  bool _isGeneratingAiReview = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
    _pendingInitialWeaknessSectionKey = _normalizeInitialSectionKey(
      widget.initialSectionKey,
    );
  }

  @override
  void didUpdateWidget(covariant LimitReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTradeDate != widget.initialTradeDate) {
      _selectedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
    }
    if (oldWidget.initialSectionKey != widget.initialSectionKey) {
      _pendingInitialWeaknessSectionKey = _normalizeInitialSectionKey(
        widget.initialSectionKey,
      );
      _appliedInitialWeaknessSectionKey = null;
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(reviewPageProvider(_selectedTradeDate));

    return AppShell(
      currentPath: '/limit-review',
      title: '涨停复盘',
      subtitle: '把连板高度、昨日承接和分组涨停复盘放在同一张盘后复盘台里，沿用旧版复盘页的阅读顺序。',
      child: data.when(
        data: (snapshot) {
          _maybeApplyInitialWeaknessSection(snapshot.yesterdayStats.sections);

          return SingleChildScrollView(
            child: RepaintBoundary(
              key: _captureKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryHero(context, snapshot),
                  const SizedBox(height: 12),
                  _buildReviewWorkspace(context, snapshot.limitReview),
                  const SizedBox(height: 12),
                  _buildWeaknessWorkspace(context, snapshot.yesterdayStats),
                  const SizedBox(height: 12),
                  _buildBoardHeightWorkspace(context, snapshot.boardHeight),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '涨停复盘请求失败：$error',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }

  GlobalKey _keyForWeaknessSection(String key) {
    return _weaknessSectionKeys.putIfAbsent(
      canonicalWeaknessSectionKey(key),
      () => GlobalKey(),
    );
  }

  String? _normalizeInitialSectionKey(String? value) {
    final normalized = canonicalWeaknessSectionKey(value ?? '');
    return normalized.isEmpty ? null : normalized;
  }

  String? _normalizeTradeDate(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  void _syncReviewRoute({
    String? tradeDate,
    String? sectionKey,
  }) {
    if (!mounted) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final queryParameters = <String, String>{};
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    final normalizedSectionKey = _normalizeInitialSectionKey(sectionKey);
    if (normalizedTradeDate != null) {
      queryParameters['tradeDate'] = normalizedTradeDate;
    }
    if (normalizedSectionKey != null) {
      queryParameters['section'] = normalizedSectionKey;
    }
    final uri = Uri(
      path: '/limit-review',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    router.replace(uri.toString());
  }

  void _maybeApplyInitialWeaknessSection(
    List<YesterdayStatsSectionData> sections,
  ) {
    final requested = resolveWeaknessSectionSelectionKey(
      sections,
      _pendingInitialWeaknessSectionKey,
    );
    if (requested == null || requested == _appliedInitialWeaknessSectionKey) {
      return;
    }
    _appliedInitialWeaknessSectionKey = requested;
    _pendingInitialWeaknessSectionKey = requested;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusWeaknessSection(requested, syncRoute: false);
    });
  }

  Future<void> _focusWeaknessSection(
    String key, {
    bool syncRoute = true,
  }) async {
    final normalized = canonicalWeaknessSectionKey(key);
    _pendingInitialWeaknessSectionKey = normalized;
    _appliedInitialWeaknessSectionKey = normalized;
    if (_highlightedWeaknessSectionKey != normalized && mounted) {
      setState(() {
        _highlightedWeaknessSectionKey = normalized;
      });
    }
    if (syncRoute) {
      _syncReviewRoute(
        tradeDate: _selectedTradeDate,
        sectionKey: normalized,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final targetContext = _weaknessSectionKeys[normalized]?.currentContext;
      if (targetContext == null) {
        return;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  Widget _buildSummaryHero(BuildContext context, ReviewWorkspaceData snapshot) {
    final theme = Theme.of(context);
    final boardHeight = snapshot.boardHeight.latestHeight ??
        snapshot.limitReview.maxBoardHeight;
    final fblDelta = snapshot.yesterdayStats.todayStats.fbl -
        snapshot.yesterdayStats.yesterdayStats.fbl;
    final latestBoardDate = snapshot.boardHeight.chartItems.isEmpty
        ? '--'
        : snapshot.boardHeight.chartItems.last.date;
    final resolvedTradeDate = snapshot.navigation.resolvedTradeDate ??
        snapshot.limitReview.tradeDate ??
        snapshot.yesterdayStats.tradeDate;
    final canAutoRefresh = _selectedTradeDate == null;
    final aiReview = _effectiveAiReview(snapshot);
    final aiButtonTooltip = aiReview.enabled
        ? '结合牛牛竞价和连板天梯生成 AI 涨停复盘'
        : (aiReview.reason.isEmpty ? 'AI复盘暂不可用' : aiReview.reason);

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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('复盘总览', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      '交易日 ${resolvedTradeDate ?? '--'}'
                      '  |  快照 ${_formatTimestamp(snapshot.limitReview.fetchedAt ?? snapshot.boardHeight.fetchedAt)}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '先看分组涨停复盘，再看弱势矩阵，最后回到高度轨道确认周期位置。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    AiActionGroup(
                      primary: AiPrimaryActionButton(
                        tooltip: aiButtonTooltip,
                        onPressed: aiReview.enabled
                            ? () => _generateAiReview(snapshot)
                            : null,
                        loading: _isGeneratingAiReview,
                        loadingLabel: 'AI复盘中',
                        label: 'AI复盘',
                        remainingUses: ref
                            .watch(aiServerUsageStatusProvider)
                            .valueOrNull
                            ?.feature('limit_review')
                            ?.remaining,
                        totalLimit: ref
                            .watch(aiServerUsageStatusProvider)
                            .valueOrNull
                            ?.feature('limit_review')
                            ?.limit,
                      ),
                      children: [
                        Semantics(
                          button: true,
                          label: 'pw-limit-review-refresh',
                          child: FilledButton.tonalIcon(
                            onPressed: _isRefreshing ? null : _refreshData,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(_isRefreshing ? '刷新中' : '刷新'),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'pw-limit-review-prev-trade-date',
                          child: FilledButton.tonalIcon(
                            onPressed:
                                snapshot.navigation.previousTradeDate == null
                                    ? null
                                    : () => _selectTradeDate(
                                        snapshot.navigation.previousTradeDate),
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text('更早'),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'pw-limit-review-next-trade-date',
                          child: FilledButton.tonalIcon(
                            onPressed: snapshot.navigation.nextTradeDate == null
                                ? null
                                : () => _selectTradeDate(
                                    snapshot.navigation.nextTradeDate),
                            icon: const Icon(Icons.chevron_right_rounded),
                            label: const Text('更晚'),
                          ),
                        ),
                        if (resolvedTradeDate != null)
                          Semantics(
                            button: true,
                            label: 'pw-limit-review-trade-date-latest',
                            child: ActionChip(
                              label: const Text('最新'),
                              onPressed: _selectedTradeDate == null
                                  ? null
                                  : () => _selectTradeDate(null),
                            ),
                          ),
                        FilterChip(
                          selected: _autoRefresh,
                          onSelected: canAutoRefresh
                              ? (_) => _toggleAutoRefresh()
                              : null,
                          avatar: Icon(
                            _autoRefresh
                                ? Icons.pause_circle_outline_rounded
                                : Icons.autorenew_rounded,
                            size: 18,
                          ),
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
                    ),
                  ],
                ),
              ),
              _buildMetricPanel(
                context,
                label: '连板高度',
                value: boardHeight == null ? '--' : '$boardHeight 板',
                caption: latestBoardDate,
              ),
              _buildMetricPanel(
                context,
                label: '复盘分组',
                value: '${snapshot.limitReview.totalGroups}',
                caption: '${snapshot.limitReview.totalStocks} 行',
              ),
              _buildMetricPanel(
                context,
                label: '今日封板率',
                value: '${snapshot.yesterdayStats.todayStats.fbl}%',
                caption:
                    '涨停 ${snapshot.yesterdayStats.todayStats.zt} / 炸板 ${snapshot.yesterdayStats.todayStats.zb}',
              ),
              _buildMetricPanel(
                context,
                label: '昨日封板率',
                value: '${snapshot.yesterdayStats.yesterdayStats.fbl}%',
                caption:
                    '涨停 ${snapshot.yesterdayStats.yesterdayStats.zt} / 炸板 ${snapshot.yesterdayStats.yesterdayStats.zb}',
              ),
              _buildMetricPanel(
                context,
                label: '差值',
                value: '${fblDelta >= 0 ? '+' : ''}$fblDelta%',
                caption: '封板率差值',
              ),
            ],
          ),
          const SizedBox(height: 12),
          AiAnalysisPanel(
            title: 'AI涨停复盘',
            actionLabel: '后端会结合牛牛竞价和连板天梯数据请求 Kimi，生成盘中或盘后复盘。',
            state: aiReview,
          ),
          if (snapshot.navigation.availableTradeDates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.navigation.availableTradeDates
                  .take(6)
                  .map(
                    (tradeDate) => Semantics(
                      button: true,
                      label: 'pw-limit-review-trade-date-$tradeDate',
                      child: ChoiceChip(
                        label: Text(tradeDate),
                        selected: resolvedTradeDate == tradeDate,
                        onSelected: (_) => _selectTradeDate(tradeDate),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  void _selectTradeDate(String? value) {
    if (value != null && _autoRefresh) {
      _setAutoRefresh(false);
    }
    setState(() {
      _selectedTradeDate = _normalizeTradeDate(value);
      _aiReviewOverride = null;
    });
    _syncReviewRoute(
      tradeDate: value,
      sectionKey: _highlightedWeaknessSectionKey,
    );
  }

  void _openYesterdayStatsSection(
    BuildContext context, {
    required YesterdayStatsSectionData section,
    String? tradeDate,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final queryParameters = <String, String>{};
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    if (normalizedTradeDate != null) {
      queryParameters['tradeDate'] = normalizedTradeDate;
    }
    queryParameters['section'] = canonicalWeaknessSectionKey(section.key);
    final uri = Uri(
      path: '/yesterday-stats',
      queryParameters: queryParameters,
    );
    router.go(uri.toString());
  }

  String? _resolveYesterdayStatsTradeDate(YesterdayStatsSnapshot snapshot) {
    final tradeDate = _normalizeTradeDate(snapshot.tradeDate);
    if (tradeDate != null) {
      return tradeDate;
    }
    final todayTradeDate = _normalizeTradeDate(snapshot.tradeDates['today']);
    if (todayTradeDate != null) {
      return todayTradeDate;
    }
    return _selectedTradeDate;
  }

  YesterdayStatsSectionData? _findWeaknessSection(
    List<YesterdayStatsSectionData> sections,
    String? key,
  ) {
    if (key == null) {
      return null;
    }
    final normalized = canonicalWeaknessSectionKey(key);
    for (final section in sections) {
      if (canonicalWeaknessSectionKey(section.key) == normalized) {
        return section;
      }
    }
    return null;
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
    });
    final provider = reviewPageProvider(_selectedTradeDate);
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

  AiAnalysisStateData _effectiveAiReview(ReviewWorkspaceData snapshot) {
    final override = _aiReviewOverride;
    if (override == null) {
      return snapshot.aiReview;
    }
    final resolvedTradeDate = snapshot.navigation.resolvedTradeDate ??
        snapshot.limitReview.tradeDate ??
        snapshot.yesterdayStats.tradeDate;
    if (override.tradeDate == resolvedTradeDate ||
        override.tradeDate == null ||
        resolvedTradeDate == null) {
      return override;
    }
    return snapshot.aiReview;
  }

  Future<void> _generateAiReview(ReviewWorkspaceData snapshot) async {
    if (_isGeneratingAiReview) {
      return;
    }
    final tradeDate = snapshot.navigation.resolvedTradeDate ??
        snapshot.limitReview.tradeDate ??
        snapshot.yesterdayStats.tradeDate;
    setState(() {
      _isGeneratingAiReview = true;
    });
    try {
      final result = await ref.read(reviewRepositoryProvider).generateAiReview(
            tradeDate: tradeDate,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _aiReviewOverride = result;
      });
      ref.invalidate(reviewPageProvider(_selectedTradeDate));
      ref.invalidate(aiServerUsageStatusProvider);
      _showInfo('AI涨停复盘已生成。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      final msg = error.toString();
      if (msg.contains('429') || msg.contains('超过当日免费使用限制')) {
        ref.invalidate(aiServerUsageStatusProvider);
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('使用限制'),
            content: const Text('超过当日免费使用限制，请明天再试或配置个人 Kimi Key。'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } else {
        _showInfo('AI涨停复盘失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAiReview = false;
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
      return;
    }

    _refreshData();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _refreshData();
    });
  }

  Future<void> _openStock(String code) async {
    await openStockLinkFromUi(
      context: context,
      ref: ref,
      code: code,
    );
  }

  Future<void> _copyWorkspaceImage(ReviewWorkspaceData snapshot) async {
    final pngBytes = await _captureWorkspacePng();
    if (pngBytes == null) {
      _showInfo('复盘图片截取失败。');
      return;
    }

    final filePath = await writeBinaryFile(
      bundleName: 'limit_review_snapshot_image',
      fileName:
          'limit_review_${snapshot.navigation.resolvedTradeDate ?? snapshot.limitReview.tradeDate ?? 'snapshot'}.png',
      bytes: pngBytes,
    );

    final copied = await _copyImageToClipboard(filePath);
    if (!mounted) {
      return;
    }
    if (copied) {
      _showInfo('复盘图片已复制到剪贴板：$filePath');
      return;
    }

    _showInfo('复盘 PNG 已保存：$filePath');
  }

  Future<void> _copySnapshotText(ReviewWorkspaceData snapshot) async {
    final buffer = StringBuffer()
      ..writeln('涨停复盘')
      ..writeln(
        '交易日：${snapshot.navigation.resolvedTradeDate ?? snapshot.limitReview.tradeDate ?? snapshot.yesterdayStats.tradeDate ?? '--'}',
      )
      ..writeln(
        '快照：${_formatTimestamp(snapshot.limitReview.fetchedAt ?? snapshot.boardHeight.fetchedAt)}',
      )
      ..writeln('复盘分组：${snapshot.limitReview.totalGroups}')
      ..writeln('复盘条目：${snapshot.limitReview.totalStocks}')
      ..writeln(
          '最高连板：${snapshot.limitReview.maxBoardHeight ?? snapshot.boardHeight.latestHeight ?? '--'}')
      ..writeln()
      ..writeln('[Board Height]');

    for (final item in snapshot.boardHeight.chartItems) {
      buffer.writeln(
        '${item.date}\t${item.value}\t${_cleanLeader(item.leaderName)}\t${item.leaderCode ?? '--'}',
      );
    }

    buffer
      ..writeln()
      ..writeln('[Weakness]');
    for (final section in snapshot.yesterdayStats.sections) {
      buffer
          .writeln('${_formatWeaknessTitle(section.title)}\t${section.total}');
      for (final item in section.items) {
        buffer.writeln(
          '${item.code}\t${item.name}\t${_fmtDouble(item.price)}\t'
          '${_fmtSigned(item.openChangePct)}%\t${_fmtSigned(item.changePct)}%\t'
          '${_fmtDouble(item.amountYi, suffix: " 亿")}\t${item.region ?? '--'}\t${item.industry ?? '--'}',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('[Grouped Limit Review]');
    for (final group in snapshot.limitReview.groups) {
      final displayColumns = group.displayColumns;
      buffer.writeln('${group.name}\t${group.count}');
      buffer.writeln(
        _resolveReviewColumns(displayColumns)
            .map((column) => column.label)
            .join('\t'),
      );
      for (final item in group.displayItems) {
        buffer.writeln(
          item.toTableCells(columns: displayColumns).join('\t'),
        );
      }
      buffer.writeln();
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    _showInfo('复盘文本已复制到剪贴板。');
  }

  Future<void> _exportExcelSnapshot(ReviewWorkspaceData snapshot) async {
    final filePath = await writeExcelWorkbook(
      bundleName: 'limit_review_excel',
      fileName:
          'limit_review_${snapshot.navigation.resolvedTradeDate ?? snapshot.limitReview.tradeDate ?? 'snapshot'}.xlsx',
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
    _showInfo('复盘 Excel 已导出：$filePath');
  }

  Future<void> _exportCsvSnapshot(ReviewWorkspaceData snapshot) async {
    final result = await writeCsvBundle(
      bundleName: 'limit_review_snapshot',
      files: _buildExportSheets(snapshot),
    );

    if (!mounted) {
      return;
    }
    _showInfo('复盘 CSV 已导出：${result.directoryPath}');
  }

  Map<String, List<List<String>>> _buildExportSheets(
    ReviewWorkspaceData snapshot,
  ) {
    return {
      'summary': [
        [
          'resolved_trade_date',
          snapshot.navigation.resolvedTradeDate ??
              snapshot.limitReview.tradeDate ??
              '--',
        ],
        [
          'fetched_at',
          _formatTimestamp(
            snapshot.limitReview.fetchedAt ?? snapshot.boardHeight.fetchedAt,
          ),
        ],
        ['review_groups', '${snapshot.limitReview.totalGroups}'],
        ['review_rows', '${snapshot.limitReview.totalStocks}'],
        [
          'max_board_height',
          '${snapshot.limitReview.maxBoardHeight ?? snapshot.boardHeight.latestHeight ?? '--'}',
        ],
        ['today_fbl', '${snapshot.yesterdayStats.todayStats.fbl}'],
        ['yesterday_fbl', '${snapshot.yesterdayStats.yesterdayStats.fbl}'],
      ],
      'board_height_timeline': [
        ['date', 'height', 'leader_name', 'leader_code'],
        ...snapshot.boardHeight.chartItems.map(
          (item) => [
            item.date,
            '${item.value}',
            _cleanLeader(item.leaderName),
            item.leaderCode ?? '--',
          ],
        ),
      ],
      'weakness_sections': _buildWeaknessCsvRows(snapshot.yesterdayStats),
      'review_groups': _buildReviewGroupCsvRows(snapshot.limitReview.groups),
    };
  }

  Widget _buildMetricPanel(
    BuildContext context, {
    required String label,
    required String value,
    required String caption,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: 172,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(caption, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildBoardHeightWorkspace(
    BuildContext context,
    BoardHeightSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    final recentItems = snapshot.chartItems.length <= 14
        ? snapshot.chartItems
        : snapshot.chartItems.sublist(snapshot.chartItems.length - 14);
    final recentColumns = snapshot.columns.length <= 4
        ? snapshot.columns
        : snapshot.columns.sublist(snapshot.columns.length - 4);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
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
                        Text('连板高度', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          '展示最近高度曲线和盘后高度列，便于把复盘页里的高度变化先串起来。',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('/board-height'),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('打开页面'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildHeightTimeline(context, recentItems),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 3,
                      child: _buildHeightColumns(context, recentColumns),
                    ),
                  ],
                )
              else ...[
                _buildHeightTimeline(context, recentItems),
                const SizedBox(height: 16),
                _buildHeightColumns(context, recentColumns),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeightTimeline(
    BuildContext context,
    List<BoardHeightChartItemData> items,
  ) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return _buildSectionEmpty(
        context,
        '当前快照暂无连板高度趋势。',
      );
    }

    final maxValue = items.fold<int>(
      1,
      (current, item) => math.max(current, item.value),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('高度轨道', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.map((item) {
                final ratio = item.value / maxValue;
                final barHeight = 30 + (ratio * 110);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 54,
                          child: Text(
                            _cleanLeader(item.leaderName),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${item.value}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 26,
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFB7853E),
                                  Color(0xFF21453C),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.date.substring(5),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeightColumns(
    BuildContext context,
    List<BoardHeightColumnData> columns,
  ) {
    final theme = Theme.of(context);
    if (columns.isEmpty) {
      return _buildSectionEmpty(
        context,
        '最近交易日还没有解析出连板高度列。',
      );
    }

    return Column(
      children: columns
          .map(
            (column) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(column.date,
                            style: theme.textTheme.titleMedium),
                      ),
                      Text(
                        '${column.stocks.length} 条',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (column.stocks.isEmpty)
                    Text('暂无个股', style: theme.textTheme.bodyLarge)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: column.stocks.take(10).map((stock) {
                        return ActionChip(
                          avatar: const Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                          ),
                          onPressed: stock.code == null || stock.code!.isEmpty
                              ? null
                              : () => _openStock(stock.code!),
                          label: Text(
                            stock.code == null || stock.code!.isEmpty
                                ? stock.name
                                : '${stock.name} ${stock.code}',
                          ),
                        );
                      }).toList(growable: false),
                    ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildWeaknessWorkspace(
    BuildContext context,
    YesterdayStatsSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    final sections = orderWeaknessSections(snapshot.sections);
    final highlightedSectionKey = resolveWeaknessSectionSelectionKey(
      sections,
      _highlightedWeaknessSectionKey,
    );
    final highlightedSection = _findWeaknessSection(
      sections,
      highlightedSectionKey,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final sectionWidth =
            isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        final sectionHeight = isWide ? 430.0 : 360.0;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
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
                        Text('弱势矩阵', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          '四个分组同时跟踪昨日与今日的跌停、断板弱势表现。',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (highlightedSection != null) ...[
                        OutlinedButton.icon(
                          key: ValueKey(
                            'limit-review-open-yesterday-${canonicalWeaknessSectionKey(highlightedSection.key)}',
                          ),
                          onPressed: () => _openYesterdayStatsSection(
                            context,
                            section: highlightedSection,
                            tradeDate:
                                _resolveYesterdayStatsTradeDate(snapshot),
                          ),
                          icon: const Icon(Icons.dashboard_customize_rounded),
                          label: const Text('空头数据'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '今日 ${snapshot.tradeDates['today'] ?? '--'}',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildEmotionCard(
                    context,
                    '今日',
                    snapshot.todayStats,
                    snapshot.tradeDates['today'],
                  ),
                  _buildEmotionCard(
                    context,
                    '昨日',
                    snapshot.yesterdayStats,
                    snapshot.tradeDates['yesterday'],
                  ),
                ],
              ),
              if (sections.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('分组定位', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '点击摘要卡直接滚到对应分组，沿用空头页的四宫格阅读顺序。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: sections
                      .map(
                        (section) => SizedBox(
                          width: sectionWidth,
                          child: _buildWeaknessSummaryCard(
                            context,
                            section,
                            highlighted:
                                canonicalWeaknessSectionKey(section.key) ==
                                    highlightedSectionKey,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: sections
                    .map(
                      (section) => SizedBox(
                        key: _keyForWeaknessSection(section.key),
                        width: sectionWidth,
                        height: sectionHeight,
                        child: _buildWeaknessSection(
                          context,
                          section,
                          highlighted:
                              canonicalWeaknessSectionKey(section.key) ==
                                  highlightedSectionKey,
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

  Widget _buildEmotionCard(
    BuildContext context,
    String title,
    EmotionStatsData stats,
    String? dateLabel,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(dateLabel ?? '--', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatChip(context, '涨停', '${stats.zt}'),
              _buildStatChip(context, '连板', '${stats.lb}'),
              _buildStatChip(context, '炸板', '${stats.zb}'),
              _buildStatChip(context, '跌停', '${stats.dt}'),
              _buildStatChip(context, '封板率', '${stats.fbl}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label $value', style: theme.textTheme.bodyMedium),
    );
  }

  Widget _buildWeaknessSection(
    BuildContext context,
    YesterdayStatsSectionData section, {
    bool highlighted = false,
  }) {
    return WeaknessSectionPanel(
      section: section,
      onOpenStock: _openStock,
      keyPrefix: 'limit-review-weakness',
      emptyMessage: '当前弱势分组暂无数据。',
      highlighted: highlighted,
      highlightLabel: '复盘定位',
    );
  }

  Widget _buildWeaknessSummaryCard(
    BuildContext context,
    YesterdayStatsSectionData section, {
    required bool highlighted,
  }) {
    final theme = Theme.of(context);
    final accent = weaknessSectionAccent(section.key);
    final routeKey = canonicalWeaknessSectionKey(section.key);
    final preview = section.items.take(2).map((item) => item.name).join(' / ');
    final meta = section.items
        .take(2)
        .map((item) => [item.region, item.industry]
            .map((value) => value?.trim() ?? '')
            .where((value) => value.isNotEmpty && value != '--')
            .join(' · '))
        .where((value) => value.isNotEmpty)
        .join('  ·  ');

    return Semantics(
      button: true,
      label:
          'pw-limit-review-weakness-summary-$routeKey ${weaknessSectionTitle(section)} 分组定位',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('limit-review-weakness-summary-$routeKey'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => _focusWeaknessSection(section.key),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: highlighted ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent.withValues(alpha: highlighted ? 0.34 : 0.20),
              ),
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
                            weaknessSectionTitle(section),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            highlighted ? '当前定位分组' : '点击定位到分组',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Text(
                        '${section.total} 条',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  preview.isEmpty ? '当前暂无预览样本。' : preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meta.isEmpty ? '地区 / 行业明细在下方表格完整展开。' : '地区 / 行业：$meta',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildWeaknessSectionLegacy(
    BuildContext context,
    YesterdayStatsSectionData section,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _formatWeaknessTitle(section.title),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOutline,
                  borderRadius: BorderRadius.circular(999),
                ),
                child:
                    Text('${section.total}', style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '显示 ${section.items.length} 条 / 共 ${section.total} 条',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (section.items.isEmpty)
            Text(
              '当前弱势分组暂无数据。',
              style: theme.textTheme.bodyLarge,
            )
          else
            ...section.items.take(8).map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.name} (${item.code})',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '现价 ${_fmtDouble(item.price)}  |  开盘 ${_fmtSigned(item.openChangePct)}%  |  最新 ${_fmtSigned(item.changePct)}%',
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _openStock(item.code),
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                ),
                                label: const Text('打开股票'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _fmtDouble(item.amountYi, suffix: ' 亿'),
                                style: theme.textTheme.bodyLarge,
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.region ?? '--'} / ${item.industry ?? '--'}',
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildReviewWorkspace(
    BuildContext context,
    LimitReviewSnapshot snapshot,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
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
                    Text('分组涨停复盘', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      '按梯队分组展示复盘条带，以及每个分组里抓到的个股明细。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${snapshot.totalGroups} 组',
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (snapshot.groups.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: snapshot.groups
                    .map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSoft,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            '${group.name} ${group.count}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (snapshot.groups.isEmpty)
            _buildSectionEmpty(
              context,
              '当前还没有分组涨停复盘数据。',
            )
          else
            ...snapshot.groups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildReviewGroup(context, group),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewGroup(
    BuildContext context,
    LimitReviewGroupData group,
  ) {
    final theme = Theme.of(context);
    final items = group.displayItems;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGroupLabel(context, group),
                    const SizedBox(width: 14),
                    Expanded(
                      child: items.isEmpty
                          ? Text('暂无数据', style: theme.textTheme.bodyLarge)
                          : _buildReviewTable(context, group),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGroupLabel(context, group),
                    const SizedBox(height: 14),
                    if (items.isEmpty)
                      Text('暂无数据', style: theme.textTheme.bodyLarge)
                    else
                      _buildReviewTable(context, group),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildGroupLabel(BuildContext context, LimitReviewGroupData group) {
    final theme = Theme.of(context);

    return Container(
      width: 136,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${group.count} 条',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (group.displayItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              group.displayItems.first.stockName ?? '--',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewTable(
    BuildContext context,
    LimitReviewGroupData group,
  ) {
    final theme = Theme.of(context);
    final items = group.displayItems;
    final displayColumns = group.displayColumns;
    final columns = _resolveReviewColumns(displayColumns);
    final tableWidth = columns.fold<double>(
      4,
      (sum, column) => sum + column.width,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                _buildReviewHeaderRow(context, columns),
                ...List<Widget>.generate(
                  items.length,
                  (index) => _buildReviewDataRow(
                    context,
                    items[index],
                    columns,
                    displayColumns,
                    index,
                  ),
                  growable: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewHeaderRow(
    BuildContext context,
    List<_ReviewTableColumnSpec> columns,
  ) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: columns
            .map(
              (column) => _buildReviewCell(
                context,
                text: column.label,
                column: column,
                isHeader: true,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildReviewDataRow(
    BuildContext context,
    LimitReviewItemData item,
    List<_ReviewTableColumnSpec> columns,
    List<LimitReviewTableColumnData> rawColumns,
    int index,
  ) {
    final theme = Theme.of(context);
    final cells = item.toTableCells(columns: rawColumns);
    final accentColor = _reviewAccentColor(theme, item.boardCount);
    final baseColor =
        index.isEven ? theme.colorScheme.surface : AppTheme.surfaceSoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            item.stockCode == null ? null : () => _openStock(item.stockCode!),
        child: Container(
          decoration: BoxDecoration(
            color: baseColor,
            border: Border(
              left: BorderSide(color: accentColor, width: 4),
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: List<Widget>.generate(
              columns.length,
              (columnIndex) => _buildReviewCell(
                context,
                text: columnIndex < cells.length ? cells[columnIndex] : '--',
                column: columns[columnIndex],
                item: item,
              ),
              growable: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCell(
    BuildContext context, {
    required String text,
    required _ReviewTableColumnSpec column,
    LimitReviewItemData? item,
    bool isHeader = false,
  }) {
    final theme = Theme.of(context);
    final alignment = switch (column.textAlign) {
      TextAlign.left => Alignment.centerLeft,
      TextAlign.right => Alignment.centerRight,
      _ => Alignment.center,
    };

    Widget child;
    if (isHeader) {
      child = Text(
        text,
        textAlign: column.textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      );
    } else if (column.key == 'stock_name' && item != null) {
      final marketTag = item.marketTag;
      child = Tooltip(
        message: item.stockCode == null ? text : '打开股票 ${item.stockCode}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (marketTag != null) ...[
              _ReviewMarketBadge(label: marketTag),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _reviewCellTextStyle(theme, column, item),
              ),
            ),
          ],
        ),
      );
    } else {
      child = Text(
        text,
        textAlign: column.textAlign,
        maxLines: column.key == 'reason' || column.key == 'theme' ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: _reviewCellTextStyle(theme, column, item),
      );
    }

    return Container(
      width: column.width,
      padding: EdgeInsets.symmetric(
        horizontal: isHeader ? 10 : 12,
        vertical: isHeader ? 12 : 14,
      ),
      alignment: alignment,
      child: child,
    );
  }

  TextStyle? _reviewCellTextStyle(
    ThemeData theme,
    _ReviewTableColumnSpec column,
    LimitReviewItemData? item,
  ) {
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF364247),
      height: 1.25,
    );
    switch (column.key) {
      case 'stock_name':
        return baseStyle?.copyWith(
          color: const Color(0xFF1C3B33),
          fontWeight: FontWeight.w700,
        );
      case 'stock_code':
        return baseStyle?.copyWith(
          color: const Color(0xFF60727B),
        );
      case 'change_pct':
        final value = item?.changePct;
        return baseStyle?.copyWith(
          color: value == null
              ? const Color(0xFF60727B)
              : value >= 0
                  ? const Color(0xFFB74A57)
                  : const Color(0xFF1D7A5B),
          fontWeight: FontWeight.w700,
        );
      case 'board_count':
      case 'lianban_text':
        return baseStyle?.copyWith(
          color: _reviewAccentColor(theme, item?.boardCount),
          fontWeight: FontWeight.w700,
        );
      case 'reason':
      case 'theme':
        return baseStyle?.copyWith(
          color: const Color(0xFF52646A),
        );
      default:
        return baseStyle;
    }
  }

  Color _reviewAccentColor(ThemeData theme, int? boardCount) {
    if (boardCount == null) {
      return theme.colorScheme.outline;
    }
    if (boardCount >= 5) {
      return const Color(0xFFB74A57);
    }
    if (boardCount >= 3) {
      return const Color(0xFFE39A3A);
    }
    if (boardCount >= 2) {
      return const Color(0xFF2E6C60);
    }
    return theme.colorScheme.primary.withValues(alpha: 0.45);
  }

  Widget _buildSectionEmpty(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  String _cleanLeader(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '--';
    }
    return value.replaceAll('\n', ' / ');
  }

  String _formatWeaknessTitle(String value) {
    final localized = formatWeaknessTitle(value);
    return localized == value ? _titleize(value) : localized;
  }

  String _formatTimestamp(String? value) {
    if (value == null || value.isEmpty) {
      return '--';
    }
    return value.replaceFirst('T', ' ').split('.').first;
  }

  List<List<String>> _buildWeaknessCsvRows(YesterdayStatsSnapshot snapshot) {
    return [
      [
        'section_key',
        'section_title',
        'code',
        'name',
        'price',
        'open_change_pct',
        'change_pct',
        'amount_yi',
        'region',
        'industry',
      ],
      ...orderWeaknessSections(snapshot.sections).expand(
        (section) => section.items.map(
          (item) => [
            section.key,
            _formatWeaknessTitle(section.title),
            item.code,
            item.name,
            item.price?.toString() ?? '--',
            item.openChangePct?.toString() ?? '--',
            item.changePct?.toString() ?? '--',
            item.amountYi?.toString() ?? '--',
            item.region ?? '--',
            item.industry ?? '--',
          ],
        ),
      ),
    ];
  }

  List<List<String>> _buildReviewGroupCsvRows(
    List<LimitReviewGroupData> groups,
  ) {
    final mergedColumns = _mergeReviewExportColumns(groups);
    final columnSpecs = _resolveReviewColumns(mergedColumns);
    final rows = <List<String>>[
      [
        'group_name',
        'group_count',
        'row_index',
        ...columnSpecs.map((column) => column.label),
      ],
    ];

    for (final group in groups) {
      rows.addAll(
        List<List<String>>.generate(
          group.displayItems.length,
          (index) => [
            group.name,
            group.count,
            '${index + 1}',
            ..._mapReviewExportCells(
              item: group.displayItems[index],
              groupColumns: group.displayColumns,
              mergedColumns: mergedColumns,
            ),
          ],
        ),
      );
    }
    return rows;
  }

  List<LimitReviewTableColumnData> _mergeReviewExportColumns(
    List<LimitReviewGroupData> groups,
  ) {
    final merged = <String, LimitReviewTableColumnData>{};
    for (final group in groups) {
      for (final column in group.displayColumns) {
        merged.putIfAbsent(column.key, () => column);
      }
    }
    if (merged.isEmpty) {
      return _reviewColumnPresets.values
          .map(
            (column) => LimitReviewTableColumnData(
              key: column.key,
              label: column.label,
              align: _reviewTextAlignName(column.textAlign),
              width: column.width,
            ),
          )
          .toList(growable: false);
    }

    final ordered = <LimitReviewTableColumnData>[];
    final remaining = Map<String, LimitReviewTableColumnData>.from(merged);
    for (final key in _reviewColumnPresets.keys) {
      final column = remaining.remove(key);
      if (column != null) {
        ordered.add(column);
      }
    }
    ordered.addAll(remaining.values);
    return ordered;
  }

  List<String> _mapReviewExportCells({
    required LimitReviewItemData item,
    required List<LimitReviewTableColumnData> groupColumns,
    required List<LimitReviewTableColumnData> mergedColumns,
  }) {
    final sourceColumns = groupColumns.isEmpty
        ? _mergeReviewExportColumns(const <LimitReviewGroupData>[])
        : groupColumns;
    final sourceCells = item.toTableCells(columns: sourceColumns);
    final cellsByKey = <String, String>{};

    for (var index = 0; index < sourceColumns.length; index++) {
      final column = sourceColumns[index];
      cellsByKey[column.key] =
          index < sourceCells.length ? sourceCells[index] : '--';
    }

    return mergedColumns
        .map((column) => cellsByKey[column.key] ?? '--')
        .toList(growable: false);
  }

  String _reviewTextAlignName(TextAlign value) {
    return switch (value) {
      TextAlign.right => 'right',
      TextAlign.center => 'center',
      _ => 'left',
    };
  }

  List<_ReviewTableColumnSpec> _resolveReviewColumns(
    List<LimitReviewTableColumnData> columns,
  ) {
    if (columns.isEmpty) {
      return _reviewColumnPresets.values.toList(growable: false);
    }
    return columns.map(_resolveReviewColumnSpec).toList(growable: false);
  }

  _ReviewTableColumnSpec _resolveReviewColumnSpec(
    LimitReviewTableColumnData column,
  ) {
    final preset = _reviewColumnPresets[column.key];
    return _ReviewTableColumnSpec(
      column.key,
      preset?.label ?? column.label,
      column.width ?? preset?.width ?? 120,
      _parseReviewTextAlign(column.align, preset?.textAlign),
    );
  }

  TextAlign _parseReviewTextAlign(
    String? value,
    TextAlign? fallback,
  ) {
    return switch (value?.toLowerCase().trim()) {
      'right' => TextAlign.right,
      'center' => TextAlign.center,
      'left' => TextAlign.left,
      _ => fallback ?? TextAlign.left,
    };
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

  String _fmtDouble(double? value, {String suffix = ''}) {
    if (value == null) {
      return '--';
    }
    return '${value.toStringAsFixed(2)}$suffix';
  }

  String _fmtSigned(double? value) {
    if (value == null) {
      return '--';
    }
    return value >= 0
        ? '+${value.toStringAsFixed(2)}'
        : value.toStringAsFixed(2);
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

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ReviewTableColumnSpec {
  const _ReviewTableColumnSpec(
    this.key,
    this.label,
    this.width,
    this.textAlign,
  );

  final String key;
  final String label;
  final double width;
  final TextAlign textAlign;
}

class _ReviewMarketBadge extends StatelessWidget {
  const _ReviewMarketBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _reviewMarketColor(label),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ) ??
            const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
      ),
    );
  }
}

Color _reviewMarketColor(String label) {
  return switch (label) {
    '沪' => const Color(0xFF2E6386),
    '深' => const Color(0xFF2F7C5D),
    '创' => const Color(0xFFB56A10),
    '科' => const Color(0xFF4D6A97),
    '北' => const Color(0xFF7A5838),
    _ => const Color(0xFF60727B),
  };
}
