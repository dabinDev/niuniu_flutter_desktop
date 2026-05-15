import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/features/yesterday_stats/application/yesterday_stats_provider.dart';
import 'package:niuniu_kaipan/features/yesterday_stats/presentation/yesterday_stats_page.dart';
import 'package:niuniu_kaipan/shared/application/app_preferences_provider.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:niuniu_kaipan/shared/application/stock_link_service.dart';
import 'package:niuniu_kaipan/shared/data/market_api_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'yesterday stats page shows full table rows and opens stock links',
    (tester) async {
      final openedCodes = <String>[];
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(2200, 3200);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellOverviewProvider.overrideWith((ref) async => _shellOverview),
            yesterdayStatsProvider(
              null,
            ).overrideWith((ref) async => _snapshot),
            stockLinkServiceProvider.overrideWith(
              (ref) => _FakeStockLinkService(onOpen: openedCodes.add),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const YesterdayStatsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('yesterday-stats-open-600009')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('yesterday-stats-open-600008')),
        findsOneWidget,
      );
      expect(find.text('昨日跌停'), findsOneWidget);
      expect(find.text('昨日断板'), findsOneWidget);
      expect(find.text('今日断板'), findsOneWidget);
      expect(find.text('复制图片'), findsOneWidget);
      expect(find.text('复制文本'), findsOneWidget);
      expect(find.text('导出 Excel'), findsOneWidget);
      expect(find.text('导出 CSV'), findsOneWidget);
      expect(find.text('Region 09'), findsOneWidget);

      final firstStock = find.byKey(
        const ValueKey('yesterday-stats-open-600000'),
      );
      await tester.ensureVisible(firstStock);
      await tester.tap(firstStock);
      await tester.pump();

      expect(openedCodes, ['600000']);
    },
  );

  testWidgets('yesterday stats summary chip jumps into limit review', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2200, 3200);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/yesterday-stats?tradeDate=2026-04-18',
      routes: [
        GoRoute(
          path: '/yesterday-stats',
          builder: (_, state) => YesterdayStatsPage(
            key: state.pageKey,
            initialTradeDate: state.uri.queryParameters['tradeDate'],
            initialSectionKey: state.uri.queryParameters['section'],
          ),
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
          yesterdayStatsProvider(
            '2026-04-18',
          ).overrideWith((ref) async => _snapshot),
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
        const ValueKey('yesterday-stats-review-today_broken_board'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/limit-review?tradeDate=2026-04-18&section=today_broken_board',
    );
  });
}

const _shellOverview = OverviewSnapshot(
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

final _snapshot = YesterdayStatsSnapshot(
  tradeDate: '2026-04-18',
  fetchedAt: '2026-04-18T16:35:00',
  tradeDates: const {
    'today': '2026-04-18',
    'yesterday': '2026-04-17',
  },
  todayStats: const EmotionStatsData(
    zt: 42,
    lb: 10,
    zb: 9,
    dt: 4,
    fbl: 62,
  ),
  yesterdayStats: const EmotionStatsData(
    zt: 39,
    lb: 8,
    zb: 11,
    dt: 5,
    fbl: 54,
  ),
  sections: [
    YesterdayStatsSectionData(
      key: 'yesterday_limit_down',
      title: 'yesterday_limit_down',
      total: 10,
      items: List.generate(
        10,
        (index) => YesterdayStatsItemData(
          code: '60000$index',
          name: 'Weak 0$index',
          price: 10 + index / 10,
          openChangePct: -1.0 - index / 10,
          changePct: -3.0 - index / 10,
          amountYi: 2.0 + index / 10,
          region: 'Region 0$index',
          industry: 'Industry 0$index',
        ),
      ),
    ),
    const YesterdayStatsSectionData(
      key: 'yesterday_duanban',
      title: 'yesterday_broken_board',
      total: 1,
      items: [
        YesterdayStatsItemData(
          code: '300001',
          name: 'Break A',
          price: 8.8,
          openChangePct: -0.5,
          changePct: -1.2,
          amountYi: 1.8,
          region: 'Shenzhen',
          industry: 'Robot',
        ),
      ],
    ),
    const YesterdayStatsSectionData(
      key: 'today_limit_down',
      title: 'today_limit_down',
      total: 1,
      items: [
        YesterdayStatsItemData(
          code: '300002',
          name: 'Drop A',
          price: 7.2,
          openChangePct: -2.1,
          changePct: -6.4,
          amountYi: 3.4,
          region: 'Guangzhou',
          industry: 'Chip',
        ),
      ],
    ),
    const YesterdayStatsSectionData(
      key: 'today_duanban',
      title: 'today_broken_board',
      total: 1,
      items: [
        YesterdayStatsItemData(
          code: '300003',
          name: 'Break B',
          price: 12.6,
          openChangePct: 0.4,
          changePct: -2.8,
          amountYi: 4.1,
          region: 'Suzhou',
          industry: 'Auto',
        ),
      ],
    ),
  ],
);

class _FakeStockLinkService extends StockLinkService {
  _FakeStockLinkService({
    required this.onOpen,
  });

  final void Function(String code) onOpen;

  @override
  Future<StockLinkResult> openStock(
    String code,
    AppPreferences preferences,
  ) async {
    onOpen(code);
    return const StockLinkResult(
      success: true,
      message: 'opened',
    );
  }
}
