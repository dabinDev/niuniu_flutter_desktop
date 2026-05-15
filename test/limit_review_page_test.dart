import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/limit_review/application/limit_review_provider.dart';
import 'package:niuniu_kaipan/features/limit_review/data/review_repository.dart';
import 'package:niuniu_kaipan/features/limit_review/presentation/limit_review_page.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:niuniu_kaipan/shared/data/market_api_repository.dart';

void main() {
  testWidgets(
      'limit review page renders export controls and supports older date navigation',
      (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 3200);
    addTearDown(tester.view.reset);

    const shellOverview = OverviewSnapshot(
      tradeDate: '2026-04-18',
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

    final latestSnapshot = ReviewWorkspaceData(
      navigation: TradeDateNavigationData(
        requestedTradeDate: null,
        resolvedTradeDate: '2026-04-18',
        previousTradeDate: '2026-04-17',
        nextTradeDate: null,
        availableTradeDates: ['2026-04-18', '2026-04-17'],
      ),
      limitReview: LimitReviewSnapshot(
        tradeDate: '2026-04-18',
        fetchedAt: '2026-04-18T16:40:00',
        totalGroups: 1,
        totalStocks: 2,
        maxBoardHeight: 5,
        groups: [
          LimitReviewGroupData(
            name: '3 Board',
            count: '2',
            items: [
              LimitReviewItemData(
                sortIndex: 0,
                stockCode: '300001',
                stockName: 'Robot A',
                changePct: 9.99,
                preClosePrice: 12.30,
                boardCount: 3,
                lianbanText: '3L',
                boardShape: 'T',
                firstLimitTime: '09:31',
                finalLimitTime: '14:55',
                amountYi: 12.3,
                floatMarketCapYi: 45,
                totalMarketCapYi: 100,
                turnoverRate: 23,
                reason: 'Robot',
                rawRow: [],
              ),
              LimitReviewItemData(
                sortIndex: 1,
                stockCode: '300002',
                stockName: 'Servo B',
                changePct: 8.10,
                preClosePrice: 18.20,
                boardCount: 2,
                lianbanText: '2L',
                boardShape: 'T',
                firstLimitTime: '10:01',
                finalLimitTime: '14:11',
                amountYi: 8.1,
                floatMarketCapYi: 30,
                totalMarketCapYi: 60,
                turnoverRate: 12,
                reason: 'Automation',
                rawRow: [],
              ),
            ],
            rows: [
              [
                'Robot A',
                '300001',
                '+9.99%',
                '12.30',
                '3',
                '连板',
                'T',
                '09:31',
                '14:55',
                '12.3亿',
                '45亿',
                '100亿',
                '23%',
                '机器人',
              ],
              [
                'Servo B',
                '300002',
                '+8.10%',
                '18.20',
                '2',
                '首板',
                'T',
                '10:01',
                '14:11',
                '8.1亿',
                '30亿',
                '60亿',
                '12%',
                '自动化',
              ],
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
            key: 'today_broken_board',
            title: 'today_broken_board',
            total: 10,
            items: [
              YesterdayStatsItemData(
                code: '600101',
                name: 'Weak 01',
                price: 13.34,
                openChangePct: -1.33,
                changePct: -4.66,
                amountYi: 3.31,
                industry: 'Industry 01',
              ),
              YesterdayStatsItemData(
                code: '600102',
                name: 'Weak 02',
                price: 14.34,
                openChangePct: -1.43,
                changePct: -4.76,
                amountYi: 3.41,
                industry: 'Industry 02',
              ),
              YesterdayStatsItemData(
                code: '600103',
                name: 'Weak 03',
                price: 15.34,
                openChangePct: -1.53,
                changePct: -4.86,
                amountYi: 3.51,
                industry: 'Industry 03',
              ),
              YesterdayStatsItemData(
                code: '600104',
                name: 'Weak 04',
                price: 16.34,
                openChangePct: -1.63,
                changePct: -4.96,
                amountYi: 3.61,
                industry: 'Industry 04',
              ),
              YesterdayStatsItemData(
                code: '600105',
                name: 'Weak 05',
                price: 17.34,
                openChangePct: -1.73,
                changePct: -5.06,
                amountYi: 3.71,
                industry: 'Industry 05',
              ),
              YesterdayStatsItemData(
                code: '600106',
                name: 'Weak 06',
                price: 18.34,
                openChangePct: -1.83,
                changePct: -5.16,
                amountYi: 3.81,
                industry: 'Industry 06',
              ),
              YesterdayStatsItemData(
                code: '600107',
                name: 'Weak 07',
                price: 19.34,
                openChangePct: -1.93,
                changePct: -5.26,
                amountYi: 3.91,
                industry: 'Industry 07',
              ),
              YesterdayStatsItemData(
                code: '600108',
                name: 'Weak 08',
                price: 20.34,
                openChangePct: -2.03,
                changePct: -5.36,
                amountYi: 4.01,
                industry: 'Industry 08',
              ),
              YesterdayStatsItemData(
                code: '600109',
                name: 'Weak 09',
                price: 21.34,
                openChangePct: -2.13,
                changePct: -5.46,
                amountYi: 4.11,
                region: 'Region 09',
                industry: 'Industry 09',
              ),
              YesterdayStatsItemData(
                code: '600100',
                name: 'Weak A',
                price: 12.34,
                openChangePct: -1.23,
                changePct: -4.56,
                amountYi: 3.21,
                industry: '消费',
              ),
            ],
          ),
        ],
      ),
    );

    const olderSnapshot = ReviewWorkspaceData(
      navigation: TradeDateNavigationData(
        requestedTradeDate: '2026-04-17',
        resolvedTradeDate: '2026-04-17',
        previousTradeDate: null,
        nextTradeDate: '2026-04-18',
        availableTradeDates: ['2026-04-18', '2026-04-17'],
      ),
      limitReview: LimitReviewSnapshot(
        tradeDate: '2026-04-17',
        fetchedAt: '2026-04-17T16:40:00',
        totalGroups: 1,
        totalStocks: 1,
        maxBoardHeight: 4,
        groups: [
          LimitReviewGroupData(
            name: '2 Board',
            count: '1',
            items: [
              LimitReviewItemData(
                sortIndex: 0,
                stockCode: '300003',
                stockName: 'Legacy C',
                changePct: 7.21,
                preClosePrice: 10.50,
                boardCount: 2,
                lianbanText: '2L',
                boardShape: 'T',
                firstLimitTime: '09:42',
                finalLimitTime: '13:40',
                amountYi: 5.5,
                floatMarketCapYi: 20,
                totalMarketCapYi: 44,
                turnoverRate: 11,
                reason: 'Legacy flowback',
                rawRow: [],
              ),
            ],
            rows: [
              [
                'Legacy C',
                '300003',
                '+7.21%',
                '10.50',
                '2',
                '连板',
                'T',
                '09:42',
                '13:40',
                '5.5亿',
                '20亿',
                '44亿',
                '11%',
                '老龙回流',
              ],
            ],
          ),
        ],
      ),
      boardHeight: BoardHeightSnapshot(
        tradeDate: '2026-04-17',
        fetchedAt: '2026-04-17T16:30:00',
        latestHeight: 4,
        chartItems: [
          BoardHeightChartItemData(
            date: '2026-04-16',
            value: 3,
            leaderName: 'Old Core',
            leaderCode: '600010',
          ),
          BoardHeightChartItemData(
            date: '2026-04-17',
            value: 4,
            leaderName: 'Legacy C',
            leaderCode: '300003',
          ),
        ],
        columns: [
          BoardHeightColumnData(
            date: '2026-04-17',
            stocks: [
              BoardHeightStockData(
                name: 'Legacy C',
                code: '300003',
                boardCount: 4,
              ),
            ],
          ),
        ],
      ),
      yesterdayStats: YesterdayStatsSnapshot(
        tradeDate: '2026-04-17',
        fetchedAt: '2026-04-17T16:35:00',
        tradeDates: {
          'today': '2026-04-17',
          'yesterday': '2026-04-16',
        },
        todayStats: EmotionStatsData(
          zt: 36,
          lb: 8,
          zb: 12,
          dt: 4,
          fbl: 49,
        ),
        yesterdayStats: EmotionStatsData(
          zt: 32,
          lb: 6,
          zb: 9,
          dt: 5,
          fbl: 46,
        ),
        sections: [
          YesterdayStatsSectionData(
            key: 'yesterday_broken_board',
            title: 'yesterday_broken_board',
            total: 1,
            items: [
              YesterdayStatsItemData(
                code: '600200',
                name: 'Weak Old',
                price: 8.76,
                openChangePct: -0.88,
                changePct: -3.21,
                amountYi: 2.40,
                industry: '化工',
              ),
            ],
          ),
        ],
      ),
    );

    final repository = _FakeReviewRepository(
      latestSnapshot: latestSnapshot,
      olderSnapshot: olderSnapshot,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => shellOverview),
          reviewRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LimitReviewPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('涨停复盘'), findsWidgets);
    expect(find.text('自动 5 秒'), findsOneWidget);
    expect(find.text('复制图片'), findsOneWidget);
    expect(find.text('复制文本'), findsOneWidget);
    expect(find.text('导出 Excel'), findsOneWidget);
    expect(find.text('导出 CSV'), findsOneWidget);
    expect(find.text('今日断板'), findsWidgets);
    expect(
      find.byKey(
        const ValueKey('limit-review-weakness-summary-today_broken_board'),
      ),
      findsOneWidget,
    );
    expect(find.text('复盘定位'), findsNothing);
    expect(find.text('显示 10 条 / 共 10 条'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('limit-review-weakness-open-600109')),
      findsOneWidget,
    );
    expect(find.text('Region 09'), findsOneWidget);
    expect(find.text('股票名称'), findsOneWidget);
    expect(find.text('Robot A'), findsWidgets);
    expect(find.text('300001'), findsWidgets);
    expect(find.text('Robot'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey('limit-review-weakness-summary-today_broken_board'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('复盘定位'), findsOneWidget);
    /*
    expect(find.text('打开个股 300001'), findsWidgets);

    await tester.tap(find.text('更早'));
    */
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.requests.contains('2026-04-17'), isTrue);
    expect(find.text('Legacy C'), findsWidgets);
    expect(find.text('300003'), findsWidgets);
    expect(find.text('Legacy flowback'), findsOneWidget);
    /*
    expect(find.text('打开个股 300003'), findsWidgets);
    */
  });

  testWidgets('limit review page accepts section deep link focus', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 3200);
    addTearDown(tester.view.reset);

    const shellOverview = OverviewSnapshot(
      tradeDate: '2026-04-18',
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

    final repository = _FakeReviewRepository(
      latestSnapshot: _latestReviewSnapshot(),
      olderSnapshot: _olderReviewSnapshot(),
    );

    final router = GoRouter(
      initialLocation:
          '/limit-review?tradeDate=2026-04-18&section=today_broken_board',
      routes: [
        GoRoute(
          path: '/limit-review',
          builder: (_, state) => LimitReviewPage(
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
          shellOverviewProvider.overrideWith((ref) async => shellOverview),
          reviewRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/limit-review?tradeDate=2026-04-18&section=today_broken_board',
    );
    expect(find.text('复盘定位'), findsOneWidget);
  });

  testWidgets('limit review page syncs trade date and section into url', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 3200);
    addTearDown(tester.view.reset);

    const shellOverview = OverviewSnapshot(
      tradeDate: '2026-04-18',
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

    final repository = _FakeReviewRepository(
      latestSnapshot: _latestReviewSnapshot(),
      olderSnapshot: _olderReviewSnapshot(),
    );

    final router = GoRouter(
      initialLocation: '/limit-review?tradeDate=2026-04-17',
      routes: [
        GoRoute(
          path: '/limit-review',
          builder: (_, state) => LimitReviewPage(
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
          shellOverviewProvider.overrideWith((ref) async => shellOverview),
          reviewRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Legacy C'), findsWidgets);

    await tester.tap(
      find.byKey(
        const ValueKey('limit-review-weakness-summary-yesterday_broken_board'),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/limit-review?tradeDate=2026-04-17&section=yesterday_broken_board',
    );
  });

  testWidgets('limit review page can jump back into yesterday stats', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 3200);
    addTearDown(tester.view.reset);

    const shellOverview = OverviewSnapshot(
      tradeDate: '2026-04-18',
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

    final repository = _FakeReviewRepository(
      latestSnapshot: _latestReviewSnapshot(),
      olderSnapshot: _olderReviewSnapshot(),
    );

    final router = GoRouter(
      initialLocation:
          '/limit-review?tradeDate=2026-04-17&section=yesterday_broken_board',
      routes: [
        GoRoute(
          path: '/limit-review',
          builder: (_, state) => LimitReviewPage(
            key: state.pageKey,
            initialTradeDate: state.uri.queryParameters['tradeDate'],
            initialSectionKey: state.uri.queryParameters['section'],
          ),
        ),
        GoRoute(
          path: '/yesterday-stats',
          builder: (_, state) => Scaffold(
            body: Text(state.uri.toString()),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => shellOverview),
          reviewRepositoryProvider.overrideWithValue(repository),
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
        const ValueKey('limit-review-open-yesterday-yesterday_broken_board'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/yesterday-stats?tradeDate=2026-04-17&section=yesterday_broken_board',
    );
  });

  testWidgets('limit review page renders dynamic theme column for raw groups', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 3200);
    addTearDown(tester.view.reset);

    const shellOverview = OverviewSnapshot(
      tradeDate: '2026-04-18',
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

    final repository = _FakeReviewRepository(
      latestSnapshot: _rawThemeReviewSnapshot(),
      olderSnapshot: _rawThemeReviewSnapshot(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => shellOverview),
          reviewRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LimitReviewPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('股票代码'), findsOneWidget);
    expect(find.text('股票名称'), findsOneWidget);
    expect(find.text('题材'), findsOneWidget);
    expect(find.text('机器人'), findsOneWidget);
    expect(find.text('算力'), findsOneWidget);
    expect(find.text('600000'), findsWidgets);
    expect(find.text('浦发银行'), findsWidgets);
  });
}

class _FakeReviewRepository extends ReviewRepository {
  _FakeReviewRepository({
    required this.latestSnapshot,
    required this.olderSnapshot,
  }) : super(ApiClient(baseUrl: 'https://api.example.invalid'));

  final ReviewWorkspaceData latestSnapshot;
  final ReviewWorkspaceData olderSnapshot;
  final List<String?> requests = [];

  @override
  Future<ReviewWorkspaceData> fetchPage({
    String? tradeDate,
    int weaknessLimit = 16,
  }) async {
    requests.add(tradeDate);
    if (tradeDate == '2026-04-17') {
      return olderSnapshot;
    }
    return latestSnapshot;
  }
}

ReviewWorkspaceData _latestReviewSnapshot() {
  return ReviewWorkspaceData(
    navigation: TradeDateNavigationData(
      requestedTradeDate: null,
      resolvedTradeDate: '2026-04-18',
      previousTradeDate: '2026-04-17',
      nextTradeDate: null,
      availableTradeDates: ['2026-04-18', '2026-04-17'],
    ),
    limitReview: LimitReviewSnapshot(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T16:40:00',
      totalGroups: 1,
      totalStocks: 2,
      maxBoardHeight: 5,
      groups: [
        LimitReviewGroupData(
          name: '3 Board',
          count: '2',
          items: [
            LimitReviewItemData(
              sortIndex: 0,
              stockCode: '300001',
              stockName: 'Robot A',
              changePct: 9.99,
              preClosePrice: 12.30,
              boardCount: 3,
              lianbanText: '3L',
              boardShape: 'T',
              firstLimitTime: '09:31',
              finalLimitTime: '14:55',
              amountYi: 12.3,
              floatMarketCapYi: 45,
              totalMarketCapYi: 100,
              turnoverRate: 23,
              reason: 'Robot',
              rawRow: [],
            ),
            LimitReviewItemData(
              sortIndex: 1,
              stockCode: '300002',
              stockName: 'Servo B',
              changePct: 8.10,
              preClosePrice: 18.20,
              boardCount: 2,
              lianbanText: '2L',
              boardShape: 'T',
              firstLimitTime: '10:01',
              finalLimitTime: '14:11',
              amountYi: 8.1,
              floatMarketCapYi: 30,
              totalMarketCapYi: 60,
              turnoverRate: 12,
              reason: 'Automation',
              rawRow: [],
            ),
          ],
          rows: [
            [
              'Robot A',
              '300001',
              '+9.99%',
              '12.30',
              '3',
              '连板',
              'T',
              '09:31',
              '14:55',
              '12.3亿',
              '45亿',
              '100亿',
              '23%',
              '机器人',
            ],
            [
              'Servo B',
              '300002',
              '+8.10%',
              '18.20',
              '2',
              '首板',
              'T',
              '10:01',
              '14:11',
              '8.1亿',
              '30亿',
              '60亿',
              '12%',
              '自动化',
            ],
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
          key: 'today_broken_board',
          title: 'today_broken_board',
          total: 10,
          items: [
            YesterdayStatsItemData(
              code: '600101',
              name: 'Weak 01',
              price: 13.34,
              openChangePct: -1.33,
              changePct: -4.66,
              amountYi: 3.31,
              industry: 'Industry 01',
            ),
            YesterdayStatsItemData(
              code: '600102',
              name: 'Weak 02',
              price: 14.34,
              openChangePct: -1.43,
              changePct: -4.76,
              amountYi: 3.41,
              industry: 'Industry 02',
            ),
            YesterdayStatsItemData(
              code: '600103',
              name: 'Weak 03',
              price: 15.34,
              openChangePct: -1.53,
              changePct: -4.86,
              amountYi: 3.51,
              industry: 'Industry 03',
            ),
            YesterdayStatsItemData(
              code: '600104',
              name: 'Weak 04',
              price: 16.34,
              openChangePct: -1.63,
              changePct: -4.96,
              amountYi: 3.61,
              industry: 'Industry 04',
            ),
            YesterdayStatsItemData(
              code: '600105',
              name: 'Weak 05',
              price: 17.34,
              openChangePct: -1.73,
              changePct: -5.06,
              amountYi: 3.71,
              industry: 'Industry 05',
            ),
            YesterdayStatsItemData(
              code: '600106',
              name: 'Weak 06',
              price: 18.34,
              openChangePct: -1.83,
              changePct: -5.16,
              amountYi: 3.81,
              industry: 'Industry 06',
            ),
            YesterdayStatsItemData(
              code: '600107',
              name: 'Weak 07',
              price: 19.34,
              openChangePct: -1.93,
              changePct: -5.26,
              amountYi: 3.91,
              industry: 'Industry 07',
            ),
            YesterdayStatsItemData(
              code: '600108',
              name: 'Weak 08',
              price: 20.34,
              openChangePct: -2.03,
              changePct: -5.36,
              amountYi: 4.01,
              industry: 'Industry 08',
            ),
            YesterdayStatsItemData(
              code: '600109',
              name: 'Weak 09',
              price: 21.34,
              openChangePct: -2.13,
              changePct: -5.46,
              amountYi: 4.11,
              region: 'Region 09',
              industry: 'Industry 09',
            ),
            YesterdayStatsItemData(
              code: '600100',
              name: 'Weak A',
              price: 12.34,
              openChangePct: -1.23,
              changePct: -4.56,
              amountYi: 3.21,
              industry: '消费',
            ),
          ],
        ),
      ],
    ),
  );
}

ReviewWorkspaceData _rawThemeReviewSnapshot() {
  return ReviewWorkspaceData(
    navigation: const TradeDateNavigationData(
      requestedTradeDate: null,
      resolvedTradeDate: '2026-04-18',
      previousTradeDate: null,
      nextTradeDate: null,
      availableTradeDates: ['2026-04-18'],
    ),
    limitReview: LimitReviewSnapshot(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T16:40:00',
      totalGroups: 1,
      totalStocks: 2,
      maxBoardHeight: 2,
      groups: const [
        LimitReviewGroupData(
          name: '首板题材',
          count: '2',
          columns: [
            LimitReviewTableColumnData(
              key: 'stock_code',
              label: 'stock_code',
              align: 'center',
              width: 96,
            ),
            LimitReviewTableColumnData(
              key: 'stock_name',
              label: 'stock_name',
              align: 'left',
              width: 168,
            ),
            LimitReviewTableColumnData(
              key: 'theme',
              label: 'theme',
              align: 'left',
              width: 140,
            ),
          ],
          items: [
            LimitReviewItemData(
              sortIndex: 0,
              stockCode: '600000',
              stockName: '浦发银行',
              changePct: null,
              preClosePrice: null,
              boardCount: 1,
              lianbanText: null,
              boardShape: null,
              firstLimitTime: null,
              finalLimitTime: null,
              amountYi: null,
              floatMarketCapYi: null,
              totalMarketCapYi: null,
              turnoverRate: null,
              reason: '机器人',
              cells: ['600000', '浦发银行', '机器人'],
            ),
            LimitReviewItemData(
              sortIndex: 1,
              stockCode: '300750',
              stockName: '宁德时代',
              changePct: null,
              preClosePrice: null,
              boardCount: 1,
              lianbanText: null,
              boardShape: null,
              firstLimitTime: null,
              finalLimitTime: null,
              amountYi: null,
              floatMarketCapYi: null,
              totalMarketCapYi: null,
              turnoverRate: null,
              reason: '算力',
              cells: ['300750', '宁德时代', '算力'],
            ),
          ],
          rows: [
            ['600000', '浦发银行', '机器人'],
            ['300750', '宁德时代', '算力'],
          ],
        ),
      ],
    ),
    boardHeight: const BoardHeightSnapshot(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T16:30:00',
      latestHeight: 2,
      chartItems: [],
      columns: [],
    ),
    yesterdayStats: const YesterdayStatsSnapshot(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T16:35:00',
      tradeDates: {
        'today': '2026-04-18',
        'yesterday': '2026-04-17',
      },
      todayStats: EmotionStatsData(
        zt: 20,
        lb: 3,
        zb: 4,
        dt: 2,
        fbl: 58,
      ),
      yesterdayStats: EmotionStatsData(
        zt: 18,
        lb: 2,
        zb: 5,
        dt: 3,
        fbl: 52,
      ),
      sections: [],
    ),
  );
}

ReviewWorkspaceData _olderReviewSnapshot() {
  return const ReviewWorkspaceData(
    navigation: TradeDateNavigationData(
      requestedTradeDate: '2026-04-17',
      resolvedTradeDate: '2026-04-17',
      previousTradeDate: null,
      nextTradeDate: '2026-04-18',
      availableTradeDates: ['2026-04-18', '2026-04-17'],
    ),
    limitReview: LimitReviewSnapshot(
      tradeDate: '2026-04-17',
      fetchedAt: '2026-04-17T16:40:00',
      totalGroups: 1,
      totalStocks: 1,
      maxBoardHeight: 4,
      groups: [
        LimitReviewGroupData(
          name: '2 Board',
          count: '1',
          items: [
            LimitReviewItemData(
              sortIndex: 0,
              stockCode: '300003',
              stockName: 'Legacy C',
              changePct: 7.21,
              preClosePrice: 10.50,
              boardCount: 2,
              lianbanText: '2L',
              boardShape: 'T',
              firstLimitTime: '09:42',
              finalLimitTime: '13:40',
              amountYi: 5.5,
              floatMarketCapYi: 20,
              totalMarketCapYi: 44,
              turnoverRate: 11,
              reason: 'Legacy flowback',
              rawRow: [],
            ),
          ],
          rows: [
            [
              'Legacy C',
              '300003',
              '+7.21%',
              '10.50',
              '2',
              '连板',
              'T',
              '09:42',
              '13:40',
              '5.5亿',
              '20亿',
              '44亿',
              '11%',
              '老龙回流',
            ],
          ],
        ),
      ],
    ),
    boardHeight: BoardHeightSnapshot(
      tradeDate: '2026-04-17',
      fetchedAt: '2026-04-17T16:30:00',
      latestHeight: 4,
      chartItems: [
        BoardHeightChartItemData(
          date: '2026-04-16',
          value: 3,
          leaderName: 'Old Core',
          leaderCode: '600010',
        ),
        BoardHeightChartItemData(
          date: '2026-04-17',
          value: 4,
          leaderName: 'Legacy C',
          leaderCode: '300003',
        ),
      ],
      columns: [
        BoardHeightColumnData(
          date: '2026-04-17',
          stocks: [
            BoardHeightStockData(
              name: 'Legacy C',
              code: '300003',
              boardCount: 4,
            ),
          ],
        ),
      ],
    ),
    yesterdayStats: YesterdayStatsSnapshot(
      tradeDate: '2026-04-17',
      fetchedAt: '2026-04-17T16:35:00',
      tradeDates: {
        'today': '2026-04-17',
        'yesterday': '2026-04-16',
      },
      todayStats: EmotionStatsData(
        zt: 36,
        lb: 8,
        zb: 12,
        dt: 4,
        fbl: 49,
      ),
      yesterdayStats: EmotionStatsData(
        zt: 32,
        lb: 6,
        zb: 9,
        dt: 5,
        fbl: 46,
      ),
      sections: [
        YesterdayStatsSectionData(
          key: 'yesterday_broken_board',
          title: 'yesterday_broken_board',
          total: 1,
          items: [
            YesterdayStatsItemData(
              code: '600200',
              name: 'Weak Old',
              price: 8.76,
              openChangePct: -0.88,
              changePct: -3.21,
              amountYi: 2.40,
              industry: '化工',
            ),
          ],
        ),
      ],
    ),
  );
}
