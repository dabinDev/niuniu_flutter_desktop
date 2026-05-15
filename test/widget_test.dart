import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:niuniu_kaipan/app/app.dart';
import 'package:niuniu_kaipan/features/overview/application/overview_provider.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:niuniu_kaipan/shared/data/market_api_repository.dart';

void main() {
  testWidgets('app bootstraps', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.reset);

    const mockOverview = OverviewSnapshot(
      tradeDate: '2026-04-16',
      runtimeMeta: OverviewRuntimeMetaData(
        cacheHit: true,
        cacheAgeMs: 180,
        cacheTtlMs: 3000,
        refreshedAt: '2026-04-16T09:31:00',
      ),
      frontendBuild: OverviewFrontendBuildData(
        builtAt: '2026-04-16T09:29:00',
        bundleUpdatedAt: '2026-04-16T09:29:01',
        sourceUpdatedAt: '2026-04-16T09:28:30',
        apiBaseUrl: 'https://api.example.invalid',
        stale: false,
      ),
      notices: [],
      indices: [],
      amountSummary: OverviewAmountSummaryData(),
      breadthSummary: OverviewBreadthSummaryData(),
      sentiment: OverviewSentimentSummaryData(
        stage: 'neutral',
        bias: 'neutral',
        score: 50,
        metrics: [],
      ),
      shellStatus: OverviewShellStatusData(
        marketPhase: 'off_hours',
        dataFreshness: 'fresh',
        jobHealth: OverviewJobHealthData(
          totalJobs: 0,
          enabledJobs: 0,
          healthyJobs: 0,
          warningJobs: 0,
          failedJobs: 0,
          queuedJobs: 0,
        ),
        watchedJobs: [],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => mockOverview),
          overviewProvider.overrideWith(
            (ref) async => const OverviewDashboardSnapshot(
              overview: mockOverview,
              yesterdayStats: YesterdayStatsSnapshot(
                tradeDate: '2026-04-16',
                fetchedAt: null,
                tradeDates: {
                  'today': '2026-04-16',
                  'yesterday': '2026-04-15',
                },
                todayStats:
                    EmotionStatsData(zt: 0, lb: 0, zb: 0, dt: 0, fbl: 0),
                yesterdayStats:
                    EmotionStatsData(zt: 0, lb: 0, zb: 0, dt: 0, fbl: 0),
                sections: [],
              ),
              boardHeight: BoardHeightSnapshot(
                tradeDate: '2026-04-16',
                fetchedAt: null,
                latestHeight: 0,
                chartItems: [],
                columns: [],
              ),
              boardTier: BoardTierSnapshot(
                tradeDate: '2026-04-16',
                fetchedAt: null,
                totalTiers: 0,
                totalStocks: 0,
                tiers: [],
              ),
            ),
          ),
        ],
        child: const NiuNiuKaipanApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('牛牛开盘'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);

    final navOrder = [
      '/overview',
      '/auction',
      '/node',
      '/board-tier',
      '/market-center',
      '/yesterday-stats',
      '/board-height',
      '/limit-review',
      '/plate-rotation',
      '/news',
      '/ask-ai',
    ];
    for (final label in [
      '总览',
      '牛牛竞价',
      '牛牛节点',
      '连板天梯',
      '行情中心',
      '空头数据',
      '连板高度',
      '涨停复盘',
      '板块轮动',
      '牛牛资讯',
      '问AI',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    final navLefts = navOrder
        .map((path) =>
            tester.getTopLeft(find.byKey(ValueKey('shell-nav-$path'))).dx)
        .toList(growable: false);
    for (var index = 1; index < navLefts.length; index++) {
      expect(navLefts[index], greaterThan(navLefts[index - 1]));
    }
  });

  testWidgets('shell handles missing desktop client download URL', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => _mockOverview),
          overviewProvider.overrideWith(
            (ref) async => const OverviewDashboardSnapshot(
              overview: _mockOverview,
              yesterdayStats: YesterdayStatsSnapshot(
                tradeDate: '2026-04-16',
                fetchedAt: null,
                tradeDates: {
                  'today': '2026-04-16',
                  'yesterday': '2026-04-15',
                },
                todayStats:
                    EmotionStatsData(zt: 0, lb: 0, zb: 0, dt: 0, fbl: 0),
                yesterdayStats:
                    EmotionStatsData(zt: 0, lb: 0, zb: 0, dt: 0, fbl: 0),
                sections: [],
              ),
              boardHeight: BoardHeightSnapshot(
                tradeDate: '2026-04-16',
                fetchedAt: null,
                latestHeight: 0,
                chartItems: [],
                columns: [],
              ),
              boardTier: BoardTierSnapshot(
                tradeDate: '2026-04-16',
                fetchedAt: null,
                totalTiers: 0,
                totalStocks: 0,
                tiers: [],
              ),
            ),
          ),
        ],
        child: const NiuNiuKaipanApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('下载客户端'), findsOneWidget);

    await tester.tap(find.text('下载客户端'));
    await tester.pumpAndSettle();

    expect(find.text('客户端下载地址未配置。'), findsOneWidget);
  });
}

const _mockOverview = OverviewSnapshot(
  tradeDate: '2026-04-16',
  runtimeMeta: OverviewRuntimeMetaData(
    cacheHit: true,
    cacheAgeMs: 180,
    cacheTtlMs: 3000,
    refreshedAt: '2026-04-16T09:31:00',
  ),
  frontendBuild: OverviewFrontendBuildData(
    builtAt: '2026-04-16T09:29:00',
    bundleUpdatedAt: '2026-04-16T09:29:01',
    sourceUpdatedAt: '2026-04-16T09:28:30',
    apiBaseUrl: 'https://api.example.invalid',
    stale: false,
  ),
  notices: [],
  indices: [],
  amountSummary: OverviewAmountSummaryData(),
  breadthSummary: OverviewBreadthSummaryData(),
  sentiment: OverviewSentimentSummaryData(
    stage: 'neutral',
    bias: 'neutral',
    score: 50,
    metrics: [],
  ),
  shellStatus: OverviewShellStatusData(
    marketPhase: 'off_hours',
    dataFreshness: 'fresh',
    jobHealth: OverviewJobHealthData(
      totalJobs: 0,
      enabledJobs: 0,
      healthyJobs: 0,
      warningJobs: 0,
      failedJobs: 0,
      queuedJobs: 0,
    ),
    watchedJobs: [],
  ),
);
