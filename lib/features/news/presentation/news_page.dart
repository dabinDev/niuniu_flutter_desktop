import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/application/export_bundle_service.dart';
import '../../../shared/application/workspace_capture_service.dart';
import '../../../shared/data/market_api_repository.dart';
import '../../../shared/layout/app_shell.dart';
import '../data/news_workspace.dart';
import '../application/news_provider.dart';

class NewsPage extends ConsumerStatefulWidget {
  const NewsPage({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  ConsumerState<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends ConsumerState<NewsPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey _captureKey = GlobalKey();
  int _selectedMonthIndex = DateTime.now().month - 1;
  late final TextEditingController _messageKeywordController;
  late final TabController _tabController;
  late final Set<int> _loadedTabs;
  late int _currentTabIndex;
  String _messageKeyword = '';
  bool _importantOnly = false;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex.clamp(0, 4);
    _loadedTabs = <int>{_currentTabIndex};
    _messageKeywordController = TextEditingController();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: _currentTabIndex,
    )..addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _messageKeywordController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging ||
        _currentTabIndex == _tabController.index) {
      return;
    }
    setState(() {
      _currentTabIndex = _tabController.index;
      _loadedTabs.add(_currentTabIndex);
    });
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _tabController.length) {
      return;
    }
    setState(() {
      _currentTabIndex = index;
      _loadedTabs.add(index);
    });
    if (_tabController.index != index) {
      _tabController.animateTo(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotNewsAsync = _loadedTabs.contains(0)
        ? ref.watch(hotNewsProvider)
        : const AsyncLoading<FeedSnapshot>();
    final todayHotAsync = _loadedTabs.contains(1)
        ? ref.watch(todayHotProvider)
        : const AsyncLoading<FeedSnapshot>();
    final fastNewsAsync = _loadedTabs.contains(2)
        ? ref.watch(fastNewsProvider)
        : const AsyncLoading<FeedSnapshot>();
    final timelineAsync = _loadedTabs.contains(3)
        ? ref.watch(timelineProvider)
        : const AsyncLoading<FeedSnapshot>();
    final monthlyPatternsAsync = _loadedTabs.contains(4)
        ? ref.watch(monthlyPatternsProvider)
        : const AsyncLoading<List<MonthlyPatternData>>();
    final summary = _buildSignalSummary(
      hotNewsAsync: hotNewsAsync,
      todayHotAsync: todayHotAsync,
      fastNewsAsync: fastNewsAsync,
      timelineAsync: timelineAsync,
      monthlyPatternsAsync: monthlyPatternsAsync,
    );
    final useCompactNewsHeader = MediaQuery.sizeOf(context).width > 0;

    return AppShell(
      currentPath: '/news',
      title: '牛牛资讯',
      subtitle: '热点资讯、今日热点、7x24 快讯、财经日历和月度行情集中在同一工作台。',
      child: RepaintBoundary(
        key: _captureKey,
        child: Column(
          children: [
            _SignalBand(
              summary: summary,
              currentTabIndex: _currentTabIndex,
              onSelectTab: _selectTab,
              onRefresh: () => _refreshCurrentTab(_currentTabIndex),
              onCopyImage: _copyWorkspaceImage,
              onCopyText: _copyWorkspaceText,
              onExportExcel: _exportWorkspaceExcel,
              onExportCsv: _exportWorkspaceCsv,
              compact: useCompactNewsHeader,
            ),
            SizedBox(height: useCompactNewsHeader ? 8 : 18),
            if (!useCompactNewsHeader) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: '热点资讯'),
                    Tab(text: '今日热点'),
                    Tab(text: '7x24 快讯'),
                    Tab(text: '财经日历'),
                    Tab(text: '月度行情'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHotNewsTab(hotNewsAsync),
                  _buildTodayHotTab(todayHotAsync),
                  _buildMessageCenterTab(fastNewsAsync),
                  _buildTimelineTab(timelineAsync),
                  _buildMonthlyPatternTab(monthlyPatternsAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotNewsTab(AsyncValue<FeedSnapshot> asyncValue) {
    return asyncValue.when(
      data: (snapshot) => _FeedPanel(
        title: '热点资讯',
        description: '对应旧版热点资讯栏，集中查看当天最值得先读的头条与热度主线。',
        total: snapshot.total,
        items: snapshot.items,
        onRefresh: () => _refreshCurrentTab(0),
      ),
      loading: () => const _TabLoadingState(
        message: '正在加载热点资讯...',
      ),
      error: (error, _) => _ErrorState(
        message: '热点资讯请求失败：$error',
      ),
    );
  }

  Widget _buildTodayHotTab(AsyncValue<FeedSnapshot> asyncValue) {
    return asyncValue.when(
      data: (snapshot) => _GroupedFeedPanel(
        title: '今日热点',
        description: '对应旧版今日热点栏，按分组查看盘中主题聚类和热度迁移。',
        total: snapshot.total,
        items: snapshot.items,
        onRefresh: () => _refreshCurrentTab(1),
      ),
      loading: () => const _TabLoadingState(
        message: '正在加载今日热点...',
      ),
      error: (error, _) => _ErrorState(
        message: '今日热点请求失败：$error',
      ),
    );
  }

  Widget _buildMessageCenterTab(AsyncValue<FeedSnapshot> asyncValue) {
    return asyncValue.when(
      data: (snapshot) => _MessageCenterPanel(
        snapshot: snapshot,
        keywordController: _messageKeywordController,
        keyword: _messageKeyword,
        importantOnly: _importantOnly,
        onKeywordChanged: (value) {
          setState(() {
            _messageKeyword = value;
          });
        },
        onQuickKeywordSelected: (value) {
          _messageKeywordController.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          );
          setState(() {
            _messageKeyword = value;
          });
        },
        onClearKeyword: () {
          _messageKeywordController.clear();
          setState(() {
            _messageKeyword = '';
          });
        },
        onImportantOnlyChanged: (selected) {
          setState(() {
            _importantOnly = selected;
          });
        },
        onRefresh: () => _refreshCurrentTab(2),
      ),
      loading: () => const _TabLoadingState(
        message: '正在加载 7x24 快讯...',
      ),
      error: (error, _) => _ErrorState(
        message: '7x24 快讯请求失败：$error',
      ),
    );
  }

  Widget _buildTimelineTab(AsyncValue<FeedSnapshot> asyncValue) {
    return asyncValue.when(
      data: (snapshot) => _FeedPanel(
        title: '财经日历',
        description: '对应旧版财经日历栏，按日期梳理事件流和盘前盘后提醒。',
        total: snapshot.total,
        items: snapshot.items,
        emphasizeGroup: true,
        onRefresh: () => _refreshCurrentTab(3),
      ),
      loading: () => const _TabLoadingState(
        message: '正在加载财经日历...',
      ),
      error: (error, _) => _ErrorState(
        message: '财经日历请求失败：$error',
      ),
    );
  }

  Widget _buildMonthlyPatternTab(
    AsyncValue<List<MonthlyPatternData>> asyncValue,
  ) {
    return asyncValue.when(
      data: (patterns) {
        final selectedMonthIndex = patterns.isEmpty
            ? 0
            : (_selectedMonthIndex.clamp(0, patterns.length - 1) as num)
                .toInt();
        return _MonthlyPatternPanel(
          patterns: patterns,
          selectedIndex: selectedMonthIndex,
          onSelected: (index) {
            setState(() {
              _selectedMonthIndex = index;
            });
          },
        );
      },
      loading: () => const _TabLoadingState(
        message: '正在加载月度行情...',
      ),
      error: (error, _) => _ErrorState(
        message: '月度行情资料加载失败：$error',
      ),
    );
  }

  Future<void> _refreshCurrentTab(int tabIndex) async {
    ref.invalidate(newsPageProvider);
    await ref.read(newsPageProvider.future);
  }

  Future<void> _copyWorkspaceImage() async {
    final result = await captureWorkspaceImage(
      repaintBoundaryKey: _captureKey,
      context: context,
      bundleName: 'news_workspace',
      fileName: '牛牛资讯.png',
    );
    if (result == null) {
      _showInfo('当前工作区暂时无法生成图片。');
      return;
    }
    _showInfo(
      result.copiedToClipboard
          ? '牛牛资讯图片已复制到剪贴板。'
          : '牛牛资讯图片已导出：${result.filePath}',
    );
  }

  Future<void> _copyWorkspaceText() async {
    final workspace = await _loadWorkspaceForExport();
    if (workspace == null) {
      return;
    }
    final buffer = StringBuffer()..writeln('牛牛资讯');
    _writeFeedText(buffer, '热点资讯', workspace.hotNews);
    _writeFeedText(buffer, '今日热点', workspace.todayHot);
    _writeFeedText(buffer, '7x24 快讯', workspace.fastNews);
    _writeFeedText(buffer, '财经日历', workspace.timeline);
    buffer
      ..writeln()
      ..writeln('[月度行情]');
    for (final item in workspace.monthlyPatterns) {
      buffer.writeln(
        '${item.month}\t${item.trend}\t${item.winRate}\t${item.driver}\t${item.target}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    _showInfo('牛牛资讯数据已复制到剪贴板。');
  }

  Future<void> _exportWorkspaceExcel() async {
    final workspace = await _loadWorkspaceForExport();
    if (workspace == null) {
      return;
    }
    final files = _buildWorkspaceExportFiles(workspace);
    final filePath = await writeExcelWorkbook(
      bundleName: 'news_workspace',
      fileName: '牛牛资讯.xlsx',
      sheets: files.entries
          .map((entry) => ExcelSheetData(name: entry.key, rows: entry.value))
          .toList(growable: false),
    );
    _showInfo('牛牛资讯 Excel 已导出：$filePath');
  }

  Future<void> _exportWorkspaceCsv() async {
    final workspace = await _loadWorkspaceForExport();
    if (workspace == null) {
      return;
    }
    final result = await writeCsvBundle(
      bundleName: 'news_workspace',
      files: _buildWorkspaceExportFiles(workspace),
    );
    _showInfo('牛牛资讯 CSV 已导出：${result.directoryPath}');
  }

  Future<NewsWorkspaceData?> _loadWorkspaceForExport() async {
    final cached = ref.read(newsPageProvider).valueOrNull;
    if (cached != null) {
      return cached;
    }
    try {
      return await ref.read(newsPageProvider.future);
    } catch (error) {
      _showInfo('资讯数据暂时不可导出：$error');
      return null;
    }
  }

  Map<String, List<List<String>>> _buildWorkspaceExportFiles(
    NewsWorkspaceData workspace,
  ) {
    return <String, List<List<String>>>{
      '热点资讯': _feedRows(workspace.hotNews),
      '今日热点': _feedRows(workspace.todayHot),
      '7x24 快讯': _feedRows(workspace.fastNews),
      '财经日历': _feedRows(workspace.timeline),
      '月度行情': [
        [
          'month',
          'trend',
          'win_rate',
          'driver',
          'target',
          'analysis',
          'strategy'
        ],
        ...workspace.monthlyPatterns.map(
          (item) => [
            item.month,
            item.trend,
            item.winRate,
            item.driver,
            item.target,
            item.analysis,
            item.strategy,
          ],
        ),
      ],
    };
  }

  List<List<String>> _feedRows(FeedSnapshot snapshot) {
    return [
      ['title', 'time', 'group', 'subtitle', 'extra', 'important', 'url'],
      ...snapshot.items.map(
        (item) => [
          item.title,
          item.time ?? '--',
          item.group ?? '--',
          item.subtitle ?? '--',
          item.extra ?? '--',
          item.isImportant ? 'yes' : 'no',
          item.url ?? '',
        ],
      ),
    ];
  }

  void _writeFeedText(
      StringBuffer buffer, String title, FeedSnapshot snapshot) {
    buffer
      ..writeln()
      ..writeln('[$title]');
    for (final item in snapshot.items) {
      buffer.writeln(
        '${item.time ?? '--'}\t${item.title}\t${item.group ?? '--'}\t${item.extra ?? '--'}',
      );
    }
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  _SignalBandSummary _buildSignalSummary({
    required AsyncValue<FeedSnapshot> hotNewsAsync,
    required AsyncValue<FeedSnapshot> todayHotAsync,
    required AsyncValue<FeedSnapshot> fastNewsAsync,
    required AsyncValue<FeedSnapshot> timelineAsync,
    required AsyncValue<List<MonthlyPatternData>> monthlyPatternsAsync,
  }) {
    final hotNews = hotNewsAsync.asData?.value;
    final todayHot = todayHotAsync.asData?.value;
    final fastNews = fastNewsAsync.asData?.value;
    final timeline = timelineAsync.asData?.value;
    final monthlyPatterns = monthlyPatternsAsync.asData?.value;
    final activeTabUpdatedAt = switch (_currentTabIndex) {
      0 => hotNews?.fetchedAt,
      1 => todayHot?.fetchedAt,
      2 => fastNews?.fetchedAt,
      3 => timeline?.fetchedAt,
      4 => null,
      _ => null,
    };

    final lastUpdatedAt = _firstNonEmpty(
      <String?>[
        activeTabUpdatedAt,
        hotNews?.fetchedAt,
        todayHot?.fetchedAt,
        fastNews?.fetchedAt,
        timeline?.fetchedAt,
      ],
    );

    final availableCounts = <int?>[
      hotNews?.total,
      todayHot?.total,
      fastNews?.total,
      timeline?.total,
      monthlyPatterns?.length,
    ].whereType<int>().toList(growable: false);
    final totalSignals = availableCounts.isEmpty
        ? null
        : availableCounts.fold<int>(0, (sum, value) => sum + value);

    FeedItemData? focusFastNews;
    for (final item in fastNews?.items ?? const <FeedItemData>[]) {
      if (item.isImportant) {
        focusFastNews = item;
        break;
      }
    }
    focusFastNews ??=
        (fastNews?.items.isNotEmpty ?? false) ? fastNews!.items.first : null;

    final currentFocus = switch (_currentTabIndex) {
      0 => (hotNews?.items.isNotEmpty ?? false)
          ? '头条 · ${hotNews!.items.first.title}'
          : null,
      1 => (todayHot?.items.isNotEmpty ?? false)
          ? '热点 · ${todayHot!.items.first.title}'
          : null,
      2 => focusFastNews == null ? null : '重点 · ${focusFastNews.title}',
      3 => (timeline?.items.isNotEmpty ?? false)
          ? '事件 · ${timeline!.items.first.title}'
          : null,
      4 => (monthlyPatterns?.isNotEmpty ?? false)
          ? _formatMonthlyFocus(monthlyPatterns!)
          : null,
      _ => null,
    };

    return _SignalBandSummary(
      activeTabLabel: _tabLabel(_currentTabIndex),
      loadedTabCount: _loadedTabs.length,
      lastUpdatedAt: lastUpdatedAt,
      hotStories: hotNews?.total,
      todayHots: todayHot?.total,
      fastNews: fastNews?.total,
      timeline: timeline?.total,
      monthlyPatterns: monthlyPatterns?.length,
      importantCount: fastNews?.items.where((item) => item.isImportant).length,
      totalSignals: totalSignals,
      currentFocus: currentFocus,
    );
  }

  String _tabLabel(int index) {
    return switch (index) {
      0 => '热点资讯',
      1 => '今日热点',
      2 => '7x24 快讯',
      3 => '财经日历',
      4 => '月度行情',
      _ => '资讯',
    };
  }

  String _formatMonthlyFocus(List<MonthlyPatternData> patterns) {
    if (patterns.isEmpty) {
      return '--';
    }
    final selectedMonthIndex =
        (_selectedMonthIndex.clamp(0, patterns.length - 1) as num).toInt();
    final pattern = patterns[selectedMonthIndex];
    return '${pattern.month} · ${pattern.headline}';
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if ((value ?? '').trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}

class _SignalBandSummary {
  const _SignalBandSummary({
    required this.activeTabLabel,
    required this.loadedTabCount,
    required this.lastUpdatedAt,
    required this.hotStories,
    required this.todayHots,
    required this.fastNews,
    required this.timeline,
    required this.monthlyPatterns,
    required this.importantCount,
    required this.totalSignals,
    required this.currentFocus,
  });

  final String activeTabLabel;
  final int loadedTabCount;
  final String? lastUpdatedAt;
  final int? hotStories;
  final int? todayHots;
  final int? fastNews;
  final int? timeline;
  final int? monthlyPatterns;
  final int? importantCount;
  final int? totalSignals;
  final String? currentFocus;
}

class _SignalBand extends StatelessWidget {
  const _SignalBand({
    required this.summary,
    required this.currentTabIndex,
    required this.onSelectTab,
    required this.onRefresh,
    required this.onCopyImage,
    required this.onCopyText,
    required this.onExportExcel,
    required this.onExportCsv,
    required this.compact,
  });

  final _SignalBandSummary summary;
  final int currentTabIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onRefresh;
  final VoidCallback onCopyImage;
  final VoidCallback onCopyText;
  final VoidCallback onExportExcel;
  final VoidCallback onExportCsv;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '牛牛资讯工作台',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '当前栏目为 ${summary.activeTabLabel} · ${summary.currentFocus ?? '等待加载'}',
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
                IconButton.filled(
                  onPressed: onRefresh,
                  tooltip: '刷新',
                  icon: const Icon(Icons.refresh_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CompactNewsTabPill(
                    semanticId: 'hot_news',
                    label: '热点资讯',
                    count: _metricValue(summary.hotStories),
                    selected: currentTabIndex == 0,
                    accent: AppTheme.secondary,
                    onTap: () => onSelectTab(0),
                  ),
                  _CompactNewsTabPill(
                    semanticId: 'today_hot',
                    label: '今日热点',
                    count: _metricValue(summary.todayHots),
                    selected: currentTabIndex == 1,
                    accent: AppTheme.rise,
                    onTap: () => onSelectTab(1),
                  ),
                  _CompactNewsTabPill(
                    semanticId: 'fast_news',
                    label: '7x24 快讯',
                    count: _metricValue(summary.fastNews),
                    selected: currentTabIndex == 2,
                    accent: AppTheme.primary,
                    onTap: () => onSelectTab(2),
                  ),
                  _CompactNewsTabPill(
                    semanticId: 'timeline',
                    label: '财经日历',
                    count: _metricValue(summary.timeline),
                    selected: currentTabIndex == 3,
                    accent: AppTheme.success,
                    onTap: () => onSelectTab(3),
                  ),
                  _CompactNewsTabPill(
                    semanticId: 'monthly_patterns',
                    label: '月度行情',
                    count: _metricValue(summary.monthlyPatterns),
                    selected: currentTabIndex == 4,
                    accent: const Color(0xFF7C3AED),
                    onTap: () => onSelectTab(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _NewsExportToolbar(
              onCopyImage: onCopyImage,
              onCopyText: onCopyText,
              onExportExcel: onExportExcel,
              onExportCsv: onExportCsv,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
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
                    Text(
                      '牛牛资讯工作台',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '先看热点资讯，再看今日热点、7x24 快讯、财经日历和月度行情。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '当前栏目为 ${summary.activeTabLabel}，便于按栏目连续阅读。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: onRefresh,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新'),
              ),
              _NewsExportToolbar(
                onCopyImage: onCopyImage,
                onCopyText: onCopyText,
                onExportExcel: onExportExcel,
                onExportCsv: onExportCsv,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DeskMetaChip(
                label: '最近更新',
                value: _formatStamp(summary.lastUpdatedAt) ?? '--',
                width: 180,
              ),
              _DeskMetaChip(
                label: '已加载栏目',
                value: '${summary.loadedTabCount}/5',
                width: 152,
              ),
              _DeskMetaChip(
                label: '当前焦点',
                value: summary.currentFocus ?? '等待加载',
                width: 320,
              ),
              _DeskMetaChip(
                label: '重点快讯',
                value: _metricValue(summary.importantCount),
                width: 140,
              ),
              _DeskMetaChip(
                label: '总信号数',
                value: _metricValue(summary.totalSignals),
                width: 152,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DeskTabCard(
                semanticId: 'hot_news',
                label: '热点资讯',
                detail: '先读头条与热度榜。',
                count: _metricValue(summary.hotStories),
                selected: currentTabIndex == 0,
                accent: AppTheme.secondary,
                onTap: () => onSelectTab(0),
              ),
              _DeskTabCard(
                semanticId: 'today_hot',
                label: '今日热点',
                detail: '查看主题分组与热度迁移。',
                count: _metricValue(summary.todayHots),
                selected: currentTabIndex == 1,
                accent: AppTheme.rise,
                onTap: () => onSelectTab(1),
              ),
              _DeskTabCard(
                semanticId: 'fast_news',
                label: '7x24 快讯',
                detail: '盘中盯梢与重点筛选。',
                count: _metricValue(summary.fastNews),
                selected: currentTabIndex == 2,
                accent: AppTheme.primary,
                onTap: () => onSelectTab(2),
              ),
              _DeskTabCard(
                semanticId: 'timeline',
                label: '财经日历',
                detail: '按日期梳理事件流。',
                count: _metricValue(summary.timeline),
                selected: currentTabIndex == 3,
                accent: AppTheme.success,
                onTap: () => onSelectTab(3),
              ),
              _DeskTabCard(
                semanticId: 'monthly_patterns',
                label: '月度行情',
                detail: '查看月度胜率与策略。',
                count: _metricValue(summary.monthlyPatterns),
                selected: currentTabIndex == 4,
                accent: const Color(0xFF7C3AED),
                onTap: () => onSelectTab(4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _metricValue(int? value) => value?.toString() ?? '--';

class _NewsExportToolbar extends StatelessWidget {
  const _NewsExportToolbar({
    required this.onCopyImage,
    required this.onCopyText,
    required this.onExportExcel,
    required this.onExportCsv,
  });

  final VoidCallback onCopyImage;
  final VoidCallback onCopyText;
  final VoidCallback onExportExcel;
  final VoidCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
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
      ],
    );
  }
}

class _DeskMetaChip extends StatelessWidget {
  const _DeskMetaChip({
    required this.label,
    required this.value,
    this.width,
  });

  final String label;
  final String value;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.mutedText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DeskTabCard extends StatelessWidget {
  const _DeskTabCard({
    required this.semanticId,
    required this.label,
    required this.detail,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String semanticId;
  final String label;
  final String detail;
  final String count;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor =
        selected ? Colors.white : theme.colorScheme.onSurface;

    return SizedBox(
      width: 152,
      child: Semantics(
        button: true,
        selected: selected,
        label: 'pw-news-tab-$semanticId workspace',
        hint: detail,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? accent : Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.72)
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foregroundColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? accent.withValues(alpha: 0.18)
                              : accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          count,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: selected ? Colors.white : accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactNewsTabPill extends StatelessWidget {
  const _CompactNewsTabPill({
    required this.semanticId,
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String semanticId;
  final String label;
  final String count;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor =
        selected ? Colors.white : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: 'pw-news-tab-$semanticId workspace',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? accent : Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.72)
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    count,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : accent,
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
}

class _FeedPanel extends StatelessWidget {
  const _FeedPanel({
    required this.title,
    required this.description,
    required this.total,
    required this.items,
    this.onRefresh,
    this.emphasizeGroup = false,
  });

  final String title;
  final String description;
  final int total;
  final List<FeedItemData> items;
  final VoidCallback? onRefresh;
  final bool emphasizeGroup;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        children: [
          _FeedPanelHeader(
            title: title,
            description: description,
            total: total,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 20),
          const _PanelEmptyState(
            message: '当前栏目暂无内容。',
          ),
        ],
      );
    }

    return Scrollbar(
      child: ListView.separated(
        itemCount: items.length + 1,
        separatorBuilder: (_, index) => index == 0
            ? const SizedBox(height: 20)
            : Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FeedPanelHeader(
              title: title,
              description: description,
              total: total,
              onRefresh: onRefresh,
            );
          }
          return _NewsItemRow(
            item: items[index - 1],
            emphasizeGroup: emphasizeGroup,
          );
        },
      ),
    );
  }
}

class _GroupedFeedPanel extends StatelessWidget {
  const _GroupedFeedPanel({
    required this.title,
    required this.description,
    required this.total,
    required this.items,
    this.onRefresh,
  });

  final String title;
  final String description;
  final int total;
  final List<FeedItemData> items;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<FeedItemData>>{};
    for (final item in items) {
      final group = (item.group ?? '').isEmpty ? '分组' : item.group!;
      groups.putIfAbsent(group, () => <FeedItemData>[]).add(item);
    }

    final orderedGroups = groups.entries.toList(growable: false);

    if (orderedGroups.isEmpty) {
      return ListView(
        children: [
          _FeedPanelHeader(
            title: title,
            description: description,
            total: total,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 20),
          const _PanelEmptyState(
            message: '当前还没有可分组的主题数据。',
          ),
        ],
      );
    }

    return Scrollbar(
      child: ListView(
        children: [
          _FeedPanelHeader(
            title: title,
            description: description,
            total: total,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 20),
          ...orderedGroups.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ...entry.value.asMap().entries.map(
                        (row) => Column(
                          children: [
                            _NewsItemRow(
                              item: row.value,
                              emphasizeGroup: false,
                            ),
                            if (row.key != entry.value.length - 1)
                              Divider(
                                height: 1,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
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
}

class _FeedPanelHeader extends StatelessWidget {
  const _FeedPanelHeader({
    required this.title,
    required this.description,
    required this.total,
    this.onRefresh,
  });

  final String title;
  final String description;
  final int total;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildTrailing() {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.end,
        children: [
          if (onRefresh != null)
            FilledButton.tonalIcon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('刷新'),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              '共 $total 条',
              style: theme.textTheme.labelLarge,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final detail = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(description, style: theme.textTheme.bodyLarge),
            ),
          ],
        );

        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail,
              const SizedBox(height: 14),
              buildTrailing(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: detail),
            const SizedBox(width: 16),
            buildTrailing(),
          ],
        );
      },
    );
  }
}

class _NewsItemRow extends StatelessWidget {
  const _NewsItemRow({
    required this.item,
    required this.emphasizeGroup,
  });

  final FeedItemData item;
  final bool emphasizeGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge?.copyWith(fontSize: 17);
    final targetUri = _normalizeExternalUri(item.url);
    final meta = <String>[
      if (item.isImportant) '重点',
      if (emphasizeGroup && (item.group ?? '').isNotEmpty) item.group!,
      if ((item.time ?? '').isNotEmpty) item.time!,
      if ((item.extra ?? '').isNotEmpty) item.extra!,
      if (targetUri != null) '打开原文',
    ];

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(
              color: item.isImportant ? AppTheme.rise : AppTheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: titleStyle),
                if ((item.subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.subtitle!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: meta
                        .map(
                          (value) => Text(
                            value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: value == '重点'
                                  ? AppTheme.rise
                                  : value == '打开原文'
                                      ? AppTheme.primary
                                      : AppTheme.mutedText,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (targetUri == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openNewsLink(context, item.url),
        borderRadius: BorderRadius.circular(18),
        child: content,
      ),
    );
  }
}

class _MessageCenterPanel extends StatelessWidget {
  const _MessageCenterPanel({
    required this.snapshot,
    required this.keywordController,
    required this.keyword,
    required this.importantOnly,
    required this.onKeywordChanged,
    required this.onQuickKeywordSelected,
    required this.onClearKeyword,
    required this.onImportantOnlyChanged,
    required this.onRefresh,
  });

  final FeedSnapshot snapshot;
  final TextEditingController keywordController;
  final String keyword;
  final bool importantOnly;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<String> onQuickKeywordSelected;
  final VoidCallback onClearKeyword;
  final ValueChanged<bool> onImportantOnlyChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final filteredItems =
        _filterFastNews(snapshot.items, keyword, importantOnly);
    final quickKeywords = _extractQuickKeywords(snapshot.items);
    final sources = _extractSources(snapshot.items);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1024;

        if (!isWide) {
          return ListView(
            children: [
              _FeedPanelHeader(
                title: '7x24 快讯',
                description: '补足旧版投资日历之外的实时快讯工作位，支持重点筛选与关键词过滤。',
                total: snapshot.total,
                onRefresh: onRefresh,
              ),
              const SizedBox(height: 20),
              _MessageControlRail(
                snapshot: snapshot,
                scrollable: false,
                filteredCount: filteredItems.length,
                keywordController: keywordController,
                keyword: keyword,
                importantOnly: importantOnly,
                quickKeywords: quickKeywords,
                sources: sources,
                onKeywordChanged: onKeywordChanged,
                onQuickKeywordSelected: onQuickKeywordSelected,
                onClearKeyword: onClearKeyword,
                onImportantOnlyChanged: onImportantOnlyChanged,
                onRefresh: onRefresh,
              ),
              const SizedBox(height: 18),
              _MessageFeedPanel(
                items: filteredItems,
                scrollable: false,
              ),
            ],
          );
        }

        return Column(
          children: [
            _FeedPanelHeader(
              title: '7x24 快讯',
              description: '补足旧版投资日历之外的实时快讯工作位，支持重点筛选与关键词过滤。',
              total: snapshot.total,
              onRefresh: onRefresh,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: _MessageControlRail(
                      snapshot: snapshot,
                      scrollable: true,
                      filteredCount: filteredItems.length,
                      keywordController: keywordController,
                      keyword: keyword,
                      importantOnly: importantOnly,
                      quickKeywords: quickKeywords,
                      sources: sources,
                      onKeywordChanged: onKeywordChanged,
                      onQuickKeywordSelected: onQuickKeywordSelected,
                      onClearKeyword: onClearKeyword,
                      onImportantOnlyChanged: onImportantOnlyChanged,
                      onRefresh: onRefresh,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _MessageFeedPanel(
                      items: filteredItems,
                      scrollable: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageControlRail extends StatelessWidget {
  const _MessageControlRail({
    required this.snapshot,
    required this.scrollable,
    required this.filteredCount,
    required this.keywordController,
    required this.keyword,
    required this.importantOnly,
    required this.quickKeywords,
    required this.sources,
    required this.onKeywordChanged,
    required this.onQuickKeywordSelected,
    required this.onClearKeyword,
    required this.onImportantOnlyChanged,
    required this.onRefresh,
  });

  final FeedSnapshot snapshot;
  final bool scrollable;
  final int filteredCount;
  final TextEditingController keywordController;
  final String keyword;
  final bool importantOnly;
  final List<String> quickKeywords;
  final List<String> sources;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<String> onQuickKeywordSelected;
  final VoidCallback onClearKeyword;
  final ValueChanged<bool> onImportantOnlyChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final importantCount =
        snapshot.items.where((item) => item.isImportant).length;
    final content = <Widget>[
      Text(
        '快讯筛选',
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      Text(
        '按关键词筛选快讯，只看重点消息，或重新同步最新一批数据。',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _InlineMetricPill(label: '实时', value: '${snapshot.total}'),
          _InlineMetricPill(label: '重点', value: '$importantCount'),
          _InlineMetricPill(label: '显示中', value: '$filteredCount'),
          _InlineMetricPill(label: '来源', value: '${sources.length}'),
        ],
      ),
      const SizedBox(height: 18),
      TextField(
        controller: keywordController,
        onChanged: onKeywordChanged,
        decoration: InputDecoration(
          hintText: '筛选关键词或股票代码',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: keyword.isEmpty
              ? null
              : IconButton(
                  onPressed: onClearKeyword,
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            selected: importantOnly,
            showCheckmark: false,
            onSelected: onImportantOnlyChanged,
            label: const Text('仅看重点'),
            avatar: const Icon(Icons.notifications_active_rounded, size: 18),
          ),
          FilledButton.tonalIcon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载'),
          ),
        ],
      ),
      if (quickKeywords.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          '快捷关键词',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickKeywords
              .map(
                (value) => ActionChip(
                  label: Text(value),
                  onPressed: () => onQuickKeywordSelected(value),
                ),
              )
              .toList(growable: false),
        ),
      ],
      if (sources.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          '来源',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Text(
          sources.take(8).join(' / '),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近快照',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatStamp(snapshot.fetchedAt) ?? '--',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              importantOnly ? '当前只显示重点通道。' : '当前显示全部快讯。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.80),
              ),
            ),
          ],
        ),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: scrollable
          ? ListView(
              padding: const EdgeInsets.all(18),
              children: content,
            )
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content,
              ),
            ),
    );
  }
}

class _InlineMetricPill extends StatelessWidget {
  const _InlineMetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _MessageFeedPanel extends StatelessWidget {
  const _MessageFeedPanel({
    required this.items,
    required this.scrollable,
  });

  final List<FeedItemData> items;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return const _PanelEmptyState(
        message: '当前筛选条件下暂无 7x24 快讯。',
      );
    }

    final groupedItems = _groupFastNews(items);
    final sections = groupedItems.entries.toList(growable: false);
    final content = <Widget>[
      Text(
        '7x24 快讯流水',
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      Text(
        '按日期分组展示 7x24 快讯，保证重点消息和关键词命中结果易于通读。',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 18),
      ...sections.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: _MessageDaySection(
            label: entry.key,
            items: entry.value,
          ),
        ),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: scrollable
          ? Scrollbar(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: content,
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content,
              ),
            ),
    );
  }
}

class _MessageDaySection extends StatelessWidget {
  const _MessageDaySection({
    required this.label,
    required this.items,
  });

  final String label;
  final List<FeedItemData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '共 ${items.length} 条',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.asMap().entries.map(
              (entry) => Column(
                children: [
                  _MessageItemRow(item: entry.value),
                  if (entry.key != items.length - 1)
                    Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

class _MessageItemRow extends StatelessWidget {
  const _MessageItemRow({
    required this.item,
  });

  final FeedItemData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetUri = _normalizeExternalUri(item.url);
    final borderColor = item.isImportant
        ? AppTheme.dangerOutline
        : theme.colorScheme.outlineVariant;
    final markerColor = item.isImportant ? AppTheme.rise : AppTheme.primary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: markerColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: item.isImportant
                    ? AppTheme.dangerSoft
                    : AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.isImportant)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerTint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '重点',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppTheme.rise,
                            ),
                          ),
                        ),
                      if ((item.time ?? '').isNotEmpty)
                        Text(
                          _timeOnly(item.time!) ?? item.time!,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: markerColor,
                          ),
                        ),
                      if ((item.extra ?? '').isNotEmpty)
                        Text(
                          item.extra!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (targetUri != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '打开原文',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: theme.textTheme.titleLarge,
                  ),
                  if ((item.subtitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.subtitle!,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (targetUri == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openNewsLink(context, item.url),
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }
}

class _MonthlyPatternPanel extends StatelessWidget {
  const _MonthlyPatternPanel({
    required this.patterns,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<MonthlyPatternData> patterns;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (patterns.isEmpty) {
      return const _ErrorState(message: '月度行情资料为空。');
    }

    final safeIndex = selectedIndex.clamp(0, patterns.length - 1);
    final selected = patterns[safeIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1024;
        final list = _MonthlyPatternList(
          patterns: patterns,
          selectedIndex: safeIndex,
          onSelected: onSelected,
        );
        final detail = _MonthlyPatternDetail(pattern: selected);

        if (!isWide) {
          return ListView(
            children: [
              _FeedPanelHeader(
                title: '月度行情',
                description: '沿用旧版桌面端月度行情表的数据结构，现通过服务端接口下发，客户端不再读取本地假数据。',
                total: patterns.length,
              ),
              const SizedBox(height: 20),
              SizedBox(height: 520, child: list),
              const SizedBox(height: 18),
              detail,
            ],
          );
        }

        return Column(
          children: [
            _FeedPanelHeader(
              title: '月度行情',
              description: '沿用旧版桌面端月度行情表的数据结构，现通过服务端接口下发，客户端不再读取本地假数据。',
              total: patterns.length,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 320, child: list),
                  const SizedBox(width: 24),
                  Expanded(child: detail),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthlyPatternList extends StatelessWidget {
  const _MonthlyPatternList({
    required this.patterns,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<MonthlyPatternData> patterns;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: patterns.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final pattern = patterns[index];
          final selected = index == selectedIndex;

          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryOutline
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pattern.month,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color:
                          selected ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pattern.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.76)
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PatternChip(
                        label: pattern.trend,
                        selected: selected,
                      ),
                      _PatternChip(
                        label: pattern.winRate,
                        selected: selected,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MonthlyPatternDetail extends StatelessWidget {
  const _MonthlyPatternDetail({required this.pattern});

  final MonthlyPatternData pattern;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: ListView(
          children: [
            Text(
              pattern.month.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              pattern.headline,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DetailPill(label: '趋势', value: pattern.trend),
                _DetailPill(label: '胜率', value: pattern.winRate),
                _DetailPill(label: '关注点', value: pattern.focus),
              ],
            ),
            const SizedBox(height: 22),
            _DetailBlock(
              title: '核心驱动',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pattern.drivers
                    .map(
                      (driver) => _PatternChip(label: driver, selected: false),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 18),
            _DetailBlock(
              title: '常见表现',
              child: Text(pattern.analysis, style: theme.textTheme.bodyLarge),
            ),
            const SizedBox(height: 18),
            _DetailBlock(
              title: '交易建议',
              child: Text(pattern.strategy, style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: theme.textTheme.labelMedium),
          const SizedBox(height: 5),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _PatternChip extends StatelessWidget {
  const _PatternChip({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.12)
            : AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected
              ? Colors.white.withValues(alpha: 0.18)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: selected ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _TabLoadingState extends StatelessWidget {
  const _TabLoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                message,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _PanelEmptyState extends StatelessWidget {
  const _PanelEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyLarge,
      ),
    );
  }
}

List<FeedItemData> _filterFastNews(
  List<FeedItemData> items,
  String keyword,
  bool importantOnly,
) {
  final normalizedKeyword = keyword.trim().toLowerCase();

  return items.where((item) {
    if (importantOnly && !item.isImportant) {
      return false;
    }
    if (normalizedKeyword.isEmpty) {
      return true;
    }
    final haystack = <String>[
      item.title,
      item.subtitle ?? '',
      item.extra ?? '',
      item.group ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(normalizedKeyword);
  }).toList(growable: false);
}

Map<String, List<FeedItemData>> _groupFastNews(List<FeedItemData> items) {
  final groups = <String, List<FeedItemData>>{};
  for (final item in items) {
    final label = _dayLabel(item);
    groups.putIfAbsent(label, () => <FeedItemData>[]).add(item);
  }
  return groups;
}

List<String> _extractQuickKeywords(List<FeedItemData> items) {
  final values = <String>[];
  final seen = <String>{};
  final pattern = RegExp(r'【([^】]{2,20})】');

  void tryAdd(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length < 2) {
      return;
    }
    if (seen.add(normalized)) {
      values.add(normalized);
    }
  }

  for (final item in items) {
    final titleMatch = pattern.firstMatch(item.title);
    if (titleMatch != null) {
      tryAdd(titleMatch.group(1) ?? '');
    }
    final subtitleMatch = pattern.firstMatch(item.subtitle ?? '');
    if (subtitleMatch != null) {
      tryAdd(subtitleMatch.group(1) ?? '');
    }
    if (values.length >= 8) {
      break;
    }
  }

  return values.take(8).toList(growable: false);
}

List<String> _extractSources(List<FeedItemData> items) {
  final values = <String>[];
  final seen = <String>{};

  for (final item in items) {
    final source = (item.extra ?? '').trim();
    if (source.isEmpty) {
      continue;
    }
    if (seen.add(source)) {
      values.add(source);
    }
    if (values.length >= 6) {
      break;
    }
  }

  return values;
}

String _dayLabel(FeedItemData item) {
  final group = (item.group ?? '').trim();
  if (group.isNotEmpty) {
    return group;
  }
  final time = (item.time ?? '').trim();
  if (time.contains(' ')) {
    return time.split(' ').first;
  }
  return '最新';
}

String? _timeOnly(String? rawValue) {
  final value = rawValue?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value.contains(' ')) {
    return value.split(' ').last;
  }
  return value;
}

String? _formatStamp(String? rawValue) {
  final value = rawValue?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  final local = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

Uri? _normalizeExternalUri(String? rawValue) {
  final value = rawValue?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  if (value.startsWith('//')) {
    return Uri.tryParse('https:$value');
  }

  final parsed = Uri.tryParse(value);
  if (parsed == null) {
    return null;
  }
  if (parsed.hasScheme) {
    return parsed;
  }
  if (value.startsWith('/')) {
    return Uri.tryParse('https://duanxianxia.com$value');
  }
  return Uri.tryParse('https://duanxianxia.com/$value');
}

Future<void> _openNewsLink(BuildContext context, String? rawValue) async {
  final uri = _normalizeExternalUri(rawValue);
  if (uri == null) {
    _showLinkFeedback(context, '当前条目没有可打开的原文链接。');
    return;
  }

  final launched = await launchUrl(
    uri,
    webOnlyWindowName: '_blank',
  );
  if (!launched && context.mounted) {
    _showLinkFeedback(context, '原文打开失败：$uri');
  }
}

void _showLinkFeedback(BuildContext context, String message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
