import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/overview/application/overview_provider.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/features/overview/presentation/overview_page.dart';
import 'package:niuniu_kaipan/features/yesterday_stats/application/yesterday_stats_provider.dart';
import 'package:niuniu_kaipan/features/yesterday_stats/presentation/yesterday_stats_page.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:niuniu_kaipan/shared/data/market_api_repository.dart';

void main() {
  testWidgets('overview page localizes weakness section titles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 2800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => _shellOverview),
          overviewProvider.overrideWith((ref) async => _dashboard),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const OverviewPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('昨日断板'), findsOneWidget);
    expect(find.text('今日断板'), findsOneWidget);
    expect(find.text('昨日炸板'), findsNothing);
    expect(find.text('today_broken_board'), findsNothing);
    expect(find.byKey(const ValueKey('overview-frontend-build-bar')),
        findsOneWidget);
    expect(find.text('需要重建'), findsWidgets);
  });

  testWidgets('overview weakness tiles jump into yesterday section focus', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 2800);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/overview',
      routes: [
        GoRoute(
          path: '/overview',
          builder: (_, __) => const OverviewPage(),
        ),
        GoRoute(
          path: '/yesterday-stats',
          builder: (_, state) => YesterdayStatsPage(
            key: state.pageKey,
            initialTradeDate: state.uri.queryParameters['tradeDate'],
            initialSectionKey: state.uri.queryParameters['section'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => _shellOverview),
          overviewProvider.overrideWith((ref) async => _dashboard),
          yesterdayStatsProvider(
            '2026-04-18',
          ).overrideWith((ref) async => _dashboard.yesterdayStats),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('overview-weakness-tile-today_broken_board')),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/yesterday-stats?tradeDate=2026-04-18&section=today_broken_board',
    );
    expect(find.text('定位 今日断板'), findsOneWidget);
    expect(find.text('总览定位'), findsOneWidget);
  });

  testWidgets('overview weakness review action jumps into limit review', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 2800);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/overview',
      routes: [
        GoRoute(
          path: '/overview',
          builder: (_, __) => const OverviewPage(),
        ),
        GoRoute(
          path: '/limit-review',
          builder: (_, state) => Scaffold(
            body: Text(state.uri.toString()),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => _shellOverview),
          overviewProvider.overrideWith((ref) async => _dashboard),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('overview-weakness-review-today_broken_board'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/limit-review?tradeDate=2026-04-18&section=today_broken_board',
    );
  });

  testWidgets('overview frontend build action jumps into jobs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 2800);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/overview',
      routes: [
        GoRoute(
          path: '/overview',
          builder: (_, __) => const OverviewPage(),
        ),
        GoRoute(
          path: '/jobs',
          builder: (_, __) => const Scaffold(body: Text('/jobs')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => _shellOverview),
          overviewProvider.overrideWith((ref) async => _dashboard),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('overview-frontend-build-jobs')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.toString(), '/jobs');
  });

  testWidgets('shell frontend build tag jumps into jobs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 2800);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/overview',
      routes: [
        GoRoute(
          path: '/overview',
          builder: (_, __) => const OverviewPage(),
        ),
        GoRoute(
          path: '/jobs',
          builder: (_, __) => const Scaffold(body: Text('/jobs')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => _shellOverview),
          overviewProvider.overrideWith((ref) async => _dashboard),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('overview-frontend-build-jobs')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.toString(), '/jobs');
  });
}

const _shellOverview = OverviewSnapshot(
  tradeDate: '2026-04-18',
  runtimeMeta: OverviewRuntimeMetaData(
    cacheHit: true,
    cacheAgeMs: 160,
    cacheTtlMs: 3000,
    refreshedAt: '2026-04-18T16:36:00',
  ),
  frontendBuild: OverviewFrontendBuildData(
    builtAt: '2026-04-18T16:20:00',
    bundleUpdatedAt: '2026-04-18T16:20:01',
    sourceUpdatedAt: '2026-04-18T16:34:00',
    apiBaseUrl: 'https://api.example.invalid',
    stale: true,
    reasons: [
      'frontend sources are newer than the built bundle',
    ],
  ),
  notices: [],
  indices: [],
  amountSummary: OverviewAmountSummaryData(
    totalAmountYi: 12340,
    predictedAmountYi: 13200,
    lastAmountYi: 11880,
    deltaVsLastYi: 460,
    completionRatio: 0.82,
  ),
  breadthSummary: OverviewBreadthSummaryData(
    upCount: 3120,
    flatCount: 233,
    downCount: 1890,
    leadingSide: 'up',
    upRatio: 59.4,
    downRatio: 36.0,
  ),
  plateRotation: PlateRotationSnapshot(
    tradeDate: '2026-04-18',
    fetchedAt: '2026-04-18T16:34:00',
    dates: ['2026-04-18', '2026-04-17'],
    total: 1,
    items: [
      PlateRotationItemData(
        plateName: '机器人',
        plateCode: 'BK001',
        latestZt: 3,
        latestStrengthText: '强',
        series: [],
      ),
    ],
  ),
  sentiment: OverviewSentimentSummaryData(
    stage: '回暖',
    bias: 'bullish',
    score: 72,
    metrics: [
      OverviewSentimentMetricData(
        key: 'zt',
        label: '涨停',
        today: 45,
        yesterday: 38,
        delta: 7,
      ),
    ],
  ),
  shellStatus: OverviewShellStatusData(
    marketPhase: 'post_close',
    dataFreshness: 'fresh',
    jobHealth: OverviewJobHealthData(
      totalJobs: 12,
      enabledJobs: 12,
      healthyJobs: 12,
      warningJobs: 0,
      failedJobs: 0,
      queuedJobs: 0,
      lastRunAt: '2026-04-18T16:35:00',
    ),
    watchedJobs: [],
  ),
);

const _dashboard = OverviewDashboardSnapshot(
  overview: _shellOverview,
  yesterdayStats: YesterdayStatsSnapshot(
    tradeDate: '2026-04-18',
    fetchedAt: '2026-04-18T16:35:00',
    tradeDates: {
      'today': '2026-04-18',
      'yesterday': '2026-04-17',
    },
    todayStats: EmotionStatsData(
      zt: 45,
      lb: 12,
      zb: 7,
      dt: 3,
      fbl: 61,
    ),
    yesterdayStats: EmotionStatsData(
      zt: 38,
      lb: 9,
      zb: 10,
      dt: 4,
      fbl: 54,
    ),
    sections: [
      YesterdayStatsSectionData(
        key: 'yesterday_duanban',
        title: '昨日炸板',
        total: 2,
        items: [
          YesterdayStatsItemData(
            code: '300001',
            name: 'Robot A',
            price: 11.2,
            openChangePct: -0.8,
            changePct: -2.1,
            amountYi: 4.5,
            region: '深圳',
            industry: '机器人',
          ),
        ],
      ),
      YesterdayStatsSectionData(
        key: 'today_duanban',
        title: '--',
        total: 1,
        items: [
          YesterdayStatsItemData(
            code: '600001',
            name: 'Chip B',
            price: 9.8,
            openChangePct: -1.4,
            changePct: -4.6,
            amountYi: 3.2,
            region: '上海',
            industry: '芯片',
          ),
        ],
      ),
    ],
  ),
  boardHeight: BoardHeightSnapshot(
    tradeDate: '2026-04-18',
    fetchedAt: '2026-04-18T16:30:00',
    latestHeight: 5,
    chartItems: [
      BoardHeightChartItemData(
        date: '2026-04-17',
        value: 4,
        leaderName: 'Legacy Core',
        leaderCode: '600001',
      ),
      BoardHeightChartItemData(
        date: '2026-04-18',
        value: 5,
        leaderName: 'Robot A',
        leaderCode: '300001',
      ),
    ],
    columns: [
      BoardHeightColumnData(
        date: '2026-04-18',
        stocks: [
          BoardHeightStockData(
            name: 'Robot A',
            code: '300001',
            boardCount: 5,
          ),
        ],
      ),
    ],
  ),
  boardTier: BoardTierSnapshot(
    tradeDate: '2026-04-18',
    fetchedAt: '2026-04-18T16:33:00',
    totalTiers: 1,
    totalStocks: 1,
    tiers: [
      BoardTierGroupData(
        boardCount: 5,
        title: '5板',
        total: 1,
        sealedCount: 1,
        brokenCount: 0,
        successRatePct: 100,
        successRateText: '100%',
        stocks: [
          BoardTierStockData(
            code: '300001',
            name: 'Robot A',
            market: '创业板',
            status: '连板',
            changePct: '+9.98%',
            latestPrice: '18.22',
            firstLimitTime: '09:31',
            amount: '12.3亿',
            breakCount: '0',
            regionName: '深圳',
            industryName: '机器人',
            listingDate: '2022-01-01',
            reason: '机器人',
          ),
        ],
      ),
    ],
  ),
);
