import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/application/stock_link_service.dart';
import '../../../shared/data/market_api_repository.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/weakness_section_panel.dart';
import '../application/overview_provider.dart';
import '../data/overview_repository.dart';

class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage> {
  static const _riseColor = AppTheme.rise;
  static const _riseAccentColor = Color(0xFFFF6C85);
  static const _swingColor = AppTheme.secondary;
  static const _flatColor = Color(0xFF8A9AB5);
  static const _fallColor = AppTheme.fall;
  static const _deepFallColor = Color(0xFF2E9D6A);

  bool _isRefreshing = false;

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    ref.invalidate(overviewProvider);
    try {
      await ref.read(overviewProvider.future);
    } catch (_) {
      // Errors are handled by the provider's AsyncValue
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(overviewProvider);

    return AppShell(
      currentPath: '/overview',
      title: '总览工作台',
      subtitle: '把盘面快照、情绪对比、连板高度、空头四宫格和板块轮动压缩到同一张盯盘台面。',
      child: overview.when(
        data: (data) => LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1180;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _isRefreshing ? null : _refreshData,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(_isRefreshing ? '刷新中' : '刷新'),
                    ),
                  ),
                ),
                if (data.overview.frontendBuild.hasData) ...[
                  _buildFrontendBuildBanner(
                    context,
                    data.overview.frontendBuild,
                  ),
                  const SizedBox(height: 12),
                ],
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildMarketPulseCard(context, data),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: _buildEmotionCard(
                          context,
                          data.overview,
                          data.yesterdayStats,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildMarketPulseCard(context, data),
                  const SizedBox(height: 12),
                  _buildEmotionCard(
                    context,
                    data.overview,
                    data.yesterdayStats,
                  ),
                ],
                const SizedBox(height: 12),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _buildBoardHeightCard(
                          context,
                          ref,
                          data.boardHeight,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 6,
                        child: _buildTierCard(context, data.boardTier),
                      ),
                    ],
                  )
                else ...[
                  _buildBoardHeightCard(
                    context,
                    ref,
                    data.boardHeight,
                  ),
                  const SizedBox(height: 12),
                  _buildTierCard(context, data.boardTier),
                ],
                const SizedBox(height: 12),
                _buildPlateRotationSummaryCard(
                  context,
                  data.overview.plateRotation,
                ),
                const SizedBox(height: 12),
                _buildWeaknessSummaryCard(context, data.yesterdayStats),
              ],
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '首页数据加载失败：$error',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }

  Widget _buildMarketPulseCard(
    BuildContext context,
    OverviewDashboardSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    final overview = snapshot.overview;
    final upCount = overview.upCount;
    final flatCount = overview.flatCount;
    final downCount = overview.downCount;
    final pulseTiles = <Widget Function(double?)>[
      (width) => _buildPulseMetricTile(
            context,
            label: '上证指数',
            value: _fmtDouble(overview.shIndex),
            caption: '上证',
            width: width,
          ),
      (width) => _buildPulseMetricTile(
            context,
            label: '深证成指',
            value: _fmtDouble(overview.szIndex),
            caption: '深成',
            width: width,
          ),
      (width) => _buildPulseMetricTile(
            context,
            label: '创业板指',
            value: _fmtDouble(overview.cyIndex),
            caption: '创业',
            width: width,
          ),
      (width) => _buildPulseMetricTile(
            context,
            label: '实时成交额',
            value: _fmtDouble(overview.totalAmountYi, suffix: ' 亿'),
            caption: '当前两市成交额',
            emphasized: true,
            width: width,
          ),
      (width) => _buildPulseMetricTile(
            context,
            label: '预测成交额',
            value: _fmtDouble(overview.predictedAmountYi, suffix: ' 亿'),
            caption: '盘中预测值',
            width: width,
          ),
      (width) => _buildPulseMetricTile(
            context,
            label: '昨日成交额',
            value: _fmtDouble(overview.lastAmountYi, suffix: ' 亿'),
            caption: '上一交易日',
            width: width,
          ),
    ];

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 24,
        color: theme.colorScheme.surface,
        borderColor: theme.colorScheme.outlineVariant,
        elevated: false,
      ),
      padding: const EdgeInsets.all(20),
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
                    Text('盘面总览', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text('指数、量能与市场广度', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '交易日 ${overview.tradeDate}  |  快照 ${_fmtTimestamp(overview.snapshotAt)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('涨 / 平 / 跌', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${upCount ?? '--'} / ${flatCount ?? '--'} / ${downCount ?? '--'}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 620) {
                return Row(
                  children: [
                    for (var index = 0; index < pulseTiles.length; index += 1)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == pulseTiles.length - 1 ? 0 : 8,
                          ),
                          child: pulseTiles[index](null),
                        ),
                      ),
                  ],
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: pulseTiles.map((builder) => builder(156)).toList(
                      growable: false,
                    ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('市场广度', style: theme.textTheme.titleLarge),
              ),
              Text(
                '涨 ${upCount ?? '--'} / 平 ${flatCount ?? '--'} / 跌 ${downCount ?? '--'}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildBreadthBar(context, upCount, flatCount, downCount),
        ],
      ),
    );
  }

  Widget _buildFrontendBuildBanner(
    BuildContext context,
    OverviewFrontendBuildData build,
  ) {
    final theme = Theme.of(context);
    final accent = build.stale ? AppTheme.secondary : AppTheme.primary;

    return Container(
      key: const ValueKey('overview-frontend-build-bar'),
      decoration: AppTheme.panelDecoration(
        radius: 8,
        color: theme.colorScheme.surface,
        borderColor: accent.withValues(alpha: 0.22),
        elevated: false,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('前端构建', style: theme.textTheme.labelMedium),
                    Text(
                      '客户端与服务同步状态',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '用于确认当前窗口读取的是最新运行快照。',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      build.stale
                          ? Icons.layers_clear_rounded
                          : Icons.layers_rounded,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      build.stale ? '需要重建' : '已同步',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'pw-overview-frontend-build-jobs',
                child: FilledButton.tonalIcon(
                  key: const ValueKey('overview-frontend-build-jobs'),
                  onPressed: () => _openJobs(context),
                  icon: const Icon(Icons.settings_ethernet_rounded),
                  label: const Text('任务调度'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildBuildInfoChip(
                context,
                icon: Icons.inventory_2_outlined,
                label: '构建时间',
                value: _fmtTimestamp(build.effectiveBuiltAt),
                accent: accent,
              ),
              _buildBuildInfoChip(
                context,
                icon: Icons.source_outlined,
                label: '代码时间',
                value: _fmtTimestamp(build.sourceUpdatedAt),
                accent: accent,
              ),
              _buildBuildInfoChip(
                context,
                icon:
                    build.externallyServed ? Icons.public_rounded : Icons.link_rounded,
                label: build.externallyServed ? '静态服务' : '接口状态',
                value: build.externallyServed
                    ? '外部前端在线'
                    : ((build.apiBaseUrl?.isNotEmpty ?? false) ? '已连接' : '--'),
                accent: accent,
              ),
            ],
          ),
          if (build.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accent.withValues(alpha: 0.16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _displayBuildReason(build.reasons.first),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmotionCard(
    BuildContext context,
    OverviewSnapshot overview,
    YesterdayStatsSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    final dates = snapshot.tradeDates;
    final sentiment = overview.sentiment;

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 24,
        color: AppTheme.surfaceSoft,
        borderColor: theme.colorScheme.outlineVariant,
        elevated: false,
      ),
      padding: const EdgeInsets.all(20),
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
                    Text('情绪对照', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text('今日与昨日情绪带', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${dates['today'] ?? '--'} 对比 ${dates['yesterday'] ?? '--'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(sentiment.stage, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${sentiment.score} 分  ·  ${_biasLabel(sentiment.bias)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildEmotionMetric(
                context,
                label: '涨停',
                todayValue: '${snapshot.todayStats.zt}',
                yesterdayValue: '${snapshot.yesterdayStats.zt}',
                accent: _riseColor,
              ),
              _buildEmotionMetric(
                context,
                label: '连板',
                todayValue: '${snapshot.todayStats.lb}',
                yesterdayValue: '${snapshot.yesterdayStats.lb}',
                accent: _riseAccentColor,
              ),
              _buildEmotionMetric(
                context,
                label: '封板率',
                todayValue: '${snapshot.todayStats.fbl}%',
                yesterdayValue: '${snapshot.yesterdayStats.fbl}%',
                accent: _swingColor,
              ),
              _buildEmotionMetric(
                context,
                label: '炸板',
                todayValue: '${snapshot.todayStats.zb}',
                yesterdayValue: '${snapshot.yesterdayStats.zb}',
                accent: _fallColor,
              ),
              _buildEmotionMetric(
                context,
                label: '跌停',
                todayValue: '${snapshot.todayStats.dt}',
                yesterdayValue: '${snapshot.yesterdayStats.dt}',
                accent: _deepFallColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoardHeightCard(
    BuildContext context,
    WidgetRef ref,
    BoardHeightSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    final latestPoint =
        snapshot.chartItems.isEmpty ? null : snapshot.chartItems.last;
    final recentPoints =
        snapshot.chartItems.reversed.take(6).toList(growable: false);
    final latestColumn = _findBoardColumn(snapshot, latestPoint?.date);

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 24,
        color: theme.colorScheme.surface,
        borderColor: theme.colorScheme.outlineVariant,
        elevated: false,
      ),
      padding: const EdgeInsets.all(20),
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
                    Text('连板高度', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text('高度龙头与近六日轨迹', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      latestPoint == null
                          ? '暂无连板高度数据'
                          : '最新高度出现在 ${latestPoint.date}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  '${snapshot.latestHeight ?? latestPoint?.value ?? '--'} 板',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (latestPoint != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latestPoint.leaderName ?? '--',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    latestPoint.leaderCode == null
                        ? '${latestPoint.value} 板'
                        : '${latestPoint.leaderCode}  |  ${latestPoint.value} 板',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          if (recentPoints.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('近六日轨迹', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: recentPoints
                  .map(
                    (item) => Container(
                      width: 110,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _shortDate(item.date),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${item.value} 板',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.leaderName ?? '--',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (latestColumn != null && latestColumn.stocks.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('当前梯队股票', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: latestColumn.stocks
                  .take(8)
                  .map(
                    (stock) => ActionChip(
                      avatar: const Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                      ),
                      onPressed: stock.code == null
                          ? null
                          : () => openStockLinkFromUi(
                                context: context,
                                ref: ref,
                                code: stock.code!,
                              ),
                      label: Text(
                        stock.code == null
                            ? stock.name
                            : '${stock.name} (${stock.code})',
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

  Widget _buildTierCard(
    BuildContext context,
    BoardTierSnapshot snapshot,
  ) {
    final theme = Theme.of(context);

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 24,
        color: theme.colorScheme.surface,
        borderColor: theme.colorScheme.outlineVariant,
        elevated: false,
      ),
      padding: const EdgeInsets.all(20),
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
                    Text('连板天梯', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text('梯队分层摘要', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.totalTiers} 个梯队  |  ${snapshot.totalStocks} 只股票',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  snapshot.tradeDate ?? '--',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (snapshot.tiers.isEmpty)
            Text(
              '暂无梯队数据。',
              style: theme.textTheme.bodyLarge,
            )
          else
            ...snapshot.tiers.take(4).map(
                  (tier) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTierTile(context, tier),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildWeaknessSummaryCard(
    BuildContext context,
    YesterdayStatsSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    final tradeDates = snapshot.tradeDates;
    final weaknessTradeDate = _resolveWeaknessTradeDate(snapshot);
    final sections = orderWeaknessSections(snapshot.sections)
        .take(4)
        .toList(growable: false);

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 24,
        color: theme.colorScheme.surface,
        borderColor: theme.colorScheme.outlineVariant,
        elevated: false,
      ),
      padding: const EdgeInsets.all(20),
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
                    Text('空头数据', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text(
                      '四宫格弱势预览',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${tradeDates['today'] ?? '--'} / ${tradeDates['yesterday'] ?? '--'}  按旧版 2 x 2 顺序预览，点击直接进入对应分组。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _openWeaknessSection(
                  context,
                  tradeDate: weaknessTradeDate,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('进入空头数据'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sections.isEmpty)
            Text(
              '暂无弱势分组。',
              style: theme.textTheme.bodyLarge,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 540;
                final tileWidth = isWide
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: sections
                      .map(
                        (section) => SizedBox(
                          width: tileWidth,
                          child: _buildWeaknessTile(
                            context,
                            section,
                            tradeDate: weaknessTradeDate,
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

  Widget _buildPlateRotationSummaryCard(
    BuildContext context,
    PlateRotationSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    final latestLeader = snapshot.items.isEmpty ? null : snapshot.items.first;
    final dateRange = snapshot.dates.isEmpty
        ? '--'
        : '${snapshot.dates.first} 至 ${snapshot.dates.last}';

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 24,
        color: theme.colorScheme.surface,
        borderColor: theme.colorScheme.outlineVariant,
        elevated: false,
      ),
      padding: const EdgeInsets.all(20),
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
                    Text('板块轮动', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text('强势板块摘要', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.fetchedAt == null
                          ? '暂未接入板块轮动快照'
                          : '快照 ${_fmtTimestamp(snapshot.fetchedAt)}  |  区间 $dateRange',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('跟踪板块', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.total}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (snapshot.items.isEmpty)
            Text(
              '暂无板块轮动摘要数据。',
              style: theme.textTheme.bodyLarge,
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildPulseMetricTile(
                  context,
                  label: '展示日期',
                  value: '${snapshot.dates.length}',
                  caption: dateRange,
                ),
                _buildPulseMetricTile(
                  context,
                  label: '当前第一强',
                  value: latestLeader?.plateName ?? '--',
                  caption: latestLeader?.plateCode ?? '--',
                  emphasized: true,
                ),
                _buildPulseMetricTile(
                  context,
                  label: '最新封板值',
                  value: latestLeader?.latestZt == null
                      ? '--'
                      : '${latestLeader!.latestZt}',
                  caption: latestLeader?.latestStrengthText ?? '--',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: snapshot.items
                  .take(4)
                  .toList(growable: false)
                  .asMap()
                  .entries
                  .map(
                    (entry) => _buildPlateRotationLeaderTile(
                      context,
                      entry.value,
                      accent: _plateRotationAccent(entry.key),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlateRotationLeaderTile(
    BuildContext context,
    PlateRotationItemData item, {
    required Color accent,
  }) {
    final theme = Theme.of(context);
    final latestPoint = item.series.isEmpty ? null : item.series.last;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.plateName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            item.plateCode ?? '--',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _buildCompareLine(
            context,
            '最新',
            item.latestZt == null ? '--' : '涨停 ${item.latestZt}',
            accent,
          ),
          const SizedBox(height: 6),
          _buildCompareLine(
            context,
            latestPoint?.date ?? '--',
            item.latestStrengthText ?? '--',
            accent,
          ),
        ],
      ),
    );
  }

  Color _plateRotationAccent(int index) {
    const accents = [
      AppTheme.rise,
      AppTheme.secondary,
      Color(0xFF2C7A7B),
      Color(0xFFB7791F),
    ];
    return accents[index % accents.length];
  }

  Widget _buildBreadthBar(
    BuildContext context,
    int? upCount,
    int? flatCount,
    int? downCount,
  ) {
    if (upCount == null || flatCount == null || downCount == null) {
      return Text(
        '暂无市场广度数据。',
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }

    final total = upCount + flatCount + downCount;
    if (total <= 0) {
      return Text(
        '暂无市场广度数据。',
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                if (upCount > 0)
                  Expanded(
                    flex: upCount,
                    child: Container(color: _riseColor),
                  ),
                if (flatCount > 0)
                  Expanded(
                    flex: flatCount,
                    child: Container(color: _flatColor),
                  ),
                if (downCount > 0)
                  Expanded(
                    flex: downCount,
                    child: Container(color: _fallColor),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildLegendText(
              context,
              color: _riseColor,
              label: '涨 $upCount',
            ),
            _buildLegendText(
              context,
              color: _flatColor,
              label: '平 $flatCount',
            ),
            _buildLegendText(
              context,
              color: _fallColor,
              label: '跌 $downCount',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendText(
    BuildContext context, {
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildEmotionMetric(
    BuildContext context, {
    required String label,
    required String todayValue,
    required String yesterdayValue,
    required Color accent,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          _buildCompareLine(context, '今日', todayValue, accent),
          const SizedBox(height: 6),
          _buildCompareLine(context, '昨日', yesterdayValue, accent),
        ],
      ),
    );
  }

  Widget _buildCompareLine(
    BuildContext context,
    String label,
    String value,
    Color accent,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style:
              Theme.of(context).textTheme.titleMedium?.copyWith(color: accent),
        ),
      ],
    );
  }

  Widget _buildPulseMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required String caption,
    bool emphasized = false,
    double? width = 156,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasized
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasized
              ? AppTheme.primary.withValues(alpha: 0.16)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(caption, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildBuildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            '$label $value',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildTierTile(BuildContext context, BoardTierGroupData tier) {
    final theme = Theme.of(context);
    final stockNames = tier.stocks.take(3).map((item) => item.name).join(' / ');
    final first = tier.stocks.isEmpty ? null : tier.stocks.first;
    final meta = _joinNonEmpty([first?.regionName, first?.industryName]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.28),
                  AppTheme.secondary.withValues(alpha: 0.22),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.14),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${tier.boardCount}板',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.title,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${tier.total} 只',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  stockNames.isEmpty ? '暂无代表股预览' : stockNames,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeaknessTile(
    BuildContext context,
    YesterdayStatsSectionData section, {
    String? tradeDate,
  }) {
    final theme = Theme.of(context);
    final previewItems = section.items.take(2).toList(growable: false);
    final preview = previewItems.map((item) => item.name).join(' / ');
    final meta = previewItems
        .map((item) => _joinNonEmpty([item.region, item.industry]))
        .where((item) => item.isNotEmpty)
        .join('  ·  ');
    final accent = weaknessSectionAccent(section.key);
    final routeKey = canonicalWeaknessSectionKey(section.key);

    return Semantics(
      button: true,
      label:
          'pw-overview-weakness-$routeKey ${weaknessSectionTitle(section)} 分组明细',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                key: ValueKey('overview-weakness-tile-$routeKey'),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                onTap: () => _openWeaknessSection(
                  context,
                  section: section,
                  tradeDate: tradeDate,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '旧版四宫格分组',
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
                              '${section.total} 只',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        preview.isEmpty ? '暂无样本，进入空头数据查看分组明细。' : preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        meta.isEmpty ? '地区 / 行业明细在空头数据页完整展开。' : '地区 / 行业：$meta',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '查看分组明细',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_outward_rounded,
                            size: 18,
                            color: accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    TextButton.icon(
                      key: ValueKey('overview-weakness-open-$routeKey'),
                      onPressed: () => _openWeaknessSection(
                        context,
                        section: section,
                        tradeDate: tradeDate,
                      ),
                      icon: const Icon(Icons.dashboard_customize_rounded),
                      label: const Text('查看明细'),
                      style: TextButton.styleFrom(
                        foregroundColor: accent,
                      ),
                    ),
                    const Spacer(),
                    if (tradeDate != null)
                      TextButton.icon(
                        key: ValueKey('overview-weakness-review-$routeKey'),
                        onPressed: () => _openWeaknessReview(
                          context,
                          tradeDate: tradeDate,
                          section: section,
                        ),
                        icon: const Icon(Icons.auto_stories_rounded),
                        label: const Text('进入复盘'),
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                        ),
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

  BoardHeightColumnData? _findBoardColumn(
    BoardHeightSnapshot snapshot,
    String? date,
  ) {
    if (snapshot.columns.isEmpty) {
      return null;
    }
    if (date == null) {
      return snapshot.columns.first;
    }
    for (final column in snapshot.columns) {
      if (column.date == date) {
        return column;
      }
    }
    return snapshot.columns.first;
  }

  String _shortDate(String value) {
    if (value.length >= 10) {
      return value.substring(5, 10);
    }
    return value;
  }

  String _fmtTimestamp(String? value) {
    if (value == null || value.isEmpty) {
      return '--';
    }
    return value.replaceFirst('T', ' ').split('.').first;
  }

  String _fmtDouble(double? value, {String suffix = ''}) {
    if (value == null) {
      return '--';
    }
    return '${value.toStringAsFixed(2)}$suffix';
  }

  String _displayBuildReason(String value) {
    final normalized = value.trim().toLowerCase();
    const labels = {
      'frontend bundle stale': '前端包落后于服务端记录，请重新构建前端。',
      'source updated after bundle': '源码时间晚于当前前端包，需要重新构建。',
      'bundle missing': '未读取到前端包构建信息。',
      'build metadata missing': '未读取到构建元数据。',
    };
    if (normalized.contains('frontend sources') ||
        (normalized.contains('source') && normalized.contains('newer'))) {
      return '源码时间晚于当前前端包，需要重新构建前端。';
    }
    return labels[normalized] ?? value;
  }

  String _biasLabel(String? value) {
    return switch (value) {
      'bullish' => '偏强',
      'bearish' => '偏弱',
      'mixed' => '分歧',
      'neutral' => '中性',
      _ => '待判断',
    };
  }

  void _openWeaknessSection(
    BuildContext context, {
    YesterdayStatsSectionData? section,
    String? tradeDate,
  }) {
    final queryParameters = <String, String>{};
    final normalizedTradeDate = tradeDate?.trim();
    if (normalizedTradeDate != null && normalizedTradeDate.isNotEmpty) {
      queryParameters['tradeDate'] = normalizedTradeDate;
    }
    if (section != null) {
      queryParameters['section'] = canonicalWeaknessSectionKey(section.key);
    }
    final uri = Uri(
      path: '/yesterday-stats',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    context.go(uri.toString());
  }

  void _openJobs(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/jobs');
    }
  }

  void _openWeaknessReview(
    BuildContext context, {
    required String tradeDate,
    required YesterdayStatsSectionData section,
  }) {
    final uri = Uri(
      path: '/limit-review',
      queryParameters: <String, String>{
        'tradeDate': tradeDate,
        'section': canonicalWeaknessSectionKey(section.key),
      },
    );
    context.go(uri.toString());
  }

  String? _resolveWeaknessTradeDate(YesterdayStatsSnapshot snapshot) {
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

  String _joinNonEmpty(List<String?> parts) {
    return parts
        .map((item) => item?.trim() ?? '')
        .where((item) => item.isNotEmpty && item != '--')
        .join(' · ');
  }
}
