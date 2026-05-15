import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/market_center/data/market_center_repository.dart';
import 'package:niuniu_kaipan/features/market_center/presentation/market_center_page.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/application/app_preferences_provider.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:niuniu_kaipan/shared/application/stock_link_service.dart';
import 'package:niuniu_kaipan/shared/data/market_api_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:niuniu_kaipan/features/market_center/application/market_center_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'market center page renders workspace, opens stock, and supports older trade dates',
    (tester) async {
      final repository = _FakeMarketCenterRepository(
        latestPage: _latestPage,
        olderPage: _olderPage,
      );
      final openedCodes = <String>[];

      await _pumpMarketCenterPage(
        tester,
        repository: repository,
        stockLinkService: _FakeStockLinkService(
          onOpen: openedCodes.add,
        ),
      );

      expect(find.text('行情中心'), findsWidgets);
      expect(find.text('六大股池'), findsOneWidget);
      expect(find.text('刷新'), findsOneWidget);
      expect(find.text('复制图片'), findsOneWidget);
      expect(find.text('复制文本'), findsOneWidget);
      expect(find.text('导出 Excel'), findsOneWidget);
      expect(find.text('导出 CSV'), findsOneWidget);
      expect(find.text('涨停股池 (2)'), findsOneWidget);
      expect(find.text('昨日涨停 (1)'), findsOneWidget);

      final previousButton =
          find.byKey(const ValueKey('market-center-prev-trade-date'));
      final nextButton =
          find.byKey(const ValueKey('market-center-next-trade-date'));

      expect(previousButton, findsOneWidget);
      expect(nextButton, findsOneWidget);
      expect(tester.widget<FilledButton>(previousButton).onPressed, isNotNull);
      expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

      await tester.tap(previousButton);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.requests.contains('2026-04-17'), isTrue);
      expect(find.text('LegacyCo'), findsWidgets);
      expect(find.text('昨日涨停 (1)'), findsOneWidget);

      final legacyNameCell = find.descendant(
        of: find.byType(DataTable),
        matching: find.text('LegacyCo'),
      );
      expect(legacyNameCell, findsOneWidget);

      await tester.ensureVisible(legacyNameCell);
      await tester.pumpAndSettle();
      await tester.tap(legacyNameCell);
      await tester.pump();

      expect(openedCodes, ['600001']);
    },
  );

  testWidgets('market center page syncs trade date into url', (tester) async {
    final repository = _FakeMarketCenterRepository(
      latestPage: _latestPage,
      olderPage: _olderPage,
    );

    final router = GoRouter(
      initialLocation: '/market-center?tradeDate=2026-04-17',
      routes: [
        GoRoute(
          path: '/market-center',
          builder: (_, state) => MarketCenterPage(
            key: state.pageKey,
            initialTradeDate: state.uri.queryParameters['tradeDate'],
          ),
        ),
      ],
    );

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 1400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => _shellOverview),
          marketCenterRepositoryProvider.overrideWithValue(repository),
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
      '/market-center?tradeDate=2026-04-17',
    );

    await tester
        .tap(find.byKey(const ValueKey('market-center-next-trade-date')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/market-center?tradeDate=2026-04-18',
    );

    await tester
        .tap(find.byKey(const ValueKey('market-center-trade-date-latest')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/market-center',
    );
  });

  testWidgets(
    'market center page renders structured columns and item cells',
    (tester) async {
      final repository = _FakeMarketCenterRepository(
        latestPage: _structuredPage,
        olderPage: _structuredPage,
      );
      final openedCodes = <String>[];

      await _pumpMarketCenterPage(
        tester,
        repository: repository,
        stockLinkService: _FakeStockLinkService(
          onOpen: openedCodes.add,
        ),
      );

      expect(find.text('封板资金'), findsOneWidget);
      expect(find.text('连板数'), findsOneWidget);
      expect(find.text('所属行业'), findsOneWidget);
      expect(find.text('StructuredCo'), findsWidgets);
      expect(find.text('1.80亿'), findsOneWidget);
      expect(find.text('Chip rebound'), findsOneWidget);

      final structuredNameCell = find.descendant(
        of: find.byType(DataTable),
        matching: find.text('StructuredCo'),
      );
      expect(structuredNameCell, findsOneWidget);

      await tester.ensureVisible(structuredNameCell);
      await tester.pumpAndSettle();
      await tester.tap(structuredNameCell);
      await tester.pump();

      expect(openedCodes, ['300001']);
    },
  );
}

Future<void> _pumpMarketCenterPage(
  WidgetTester tester, {
  required MarketCenterRepository repository,
  StockLinkService? stockLinkService,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1800, 1400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shellOverviewProvider.overrideWith((ref) async => _shellOverview),
        marketCenterRepositoryProvider.overrideWithValue(repository),
        if (stockLinkService != null)
          stockLinkServiceProvider.overrideWith((ref) => stockLinkService),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const MarketCenterPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

const _latestPage = MarketCenterPageData(
  navigation: MarketCenterNavigationData(
    requestedTradeDate: null,
    resolvedTradeDate: '2026-04-18',
    previousTradeDate: '2026-04-17',
    nextTradeDate: null,
    availableTradeDates: ['2026-04-18', '2026-04-17'],
  ),
  marketCenter: TableSectionsSnapshot(
    tradeDate: '2026-04-18',
    fetchedAt: '2026-04-18T15:01:00',
    tables: [
      TableSectionData(
        key: 'zt',
        title: 'limit_up',
        columns: [
          'seq',
          'code',
          'name',
          'change_pct',
          'latest_price',
          'amount'
        ],
        rows: [
          ['1', '600000', 'PFBank', '+5.23%', '10.50', '9.88 yi'],
          ['2', '000967', 'YFEnv', '+4.47%', '8.88', '1.23 yi'],
        ],
        total: 2,
      ),
      TableSectionData(
        key: 'zrzt',
        title: 'yesterday_limit_up',
        columns: [
          'seq',
          'code',
          'name',
          'change_pct',
          'latest_price',
          'amount'
        ],
        rows: [
          ['1', '002051', 'ZGIntl', '+2.20%', '9.76', '4.57 yi'],
        ],
        total: 1,
      ),
      TableSectionData(
        key: 'zb',
        title: 'broken_limit',
        columns: [
          'seq',
          'code',
          'name',
          'change_pct',
          'latest_price',
          'break_count',
        ],
        rows: [
          ['1', '600111', 'Breaker', '-1.23%', '9.34', '2'],
        ],
        total: 1,
      ),
    ],
  ),
);

const _olderPage = MarketCenterPageData(
  navigation: MarketCenterNavigationData(
    requestedTradeDate: '2026-04-17',
    resolvedTradeDate: '2026-04-17',
    previousTradeDate: null,
    nextTradeDate: '2026-04-18',
    availableTradeDates: ['2026-04-18', '2026-04-17'],
  ),
  marketCenter: TableSectionsSnapshot(
    tradeDate: '2026-04-17',
    fetchedAt: '2026-04-17T15:01:00',
    tables: [
      TableSectionData(
        key: 'zt',
        title: 'limit_up',
        columns: [
          'seq',
          'code',
          'name',
          'change_pct',
          'latest_price',
          'amount'
        ],
        rows: [
          ['1', '600001', 'LegacyCo', '+3.11%', '9.88', '8.77 yi'],
        ],
        total: 1,
      ),
      TableSectionData(
        key: 'zrzt',
        title: 'yesterday_limit_up',
        columns: [
          'seq',
          'code',
          'name',
          'change_pct',
          'latest_price',
          'amount'
        ],
        rows: [
          ['1', '000968', 'LegacyFollow', '+1.25%', '7.50', '1.13 yi'],
        ],
        total: 1,
      ),
      TableSectionData(
        key: 'zb',
        title: 'broken_limit',
        columns: [
          'seq',
          'code',
          'name',
          'change_pct',
          'latest_price',
          'break_count',
        ],
        rows: [
          ['1', '600112', 'LegacyBreaker', '-0.88%', '9.46', '1'],
        ],
        total: 1,
      ),
    ],
  ),
);

const _structuredPage = MarketCenterPageData(
  navigation: MarketCenterNavigationData(
    requestedTradeDate: null,
    resolvedTradeDate: '2026-04-18',
    previousTradeDate: null,
    nextTradeDate: null,
    availableTradeDates: ['2026-04-18'],
  ),
  marketCenter: TableSectionsSnapshot(
    tradeDate: '2026-04-18',
    fetchedAt: '2026-04-18T15:10:00',
    tables: [
      TableSectionData(
        key: 'zt',
        title: 'limit_up',
        columns: [
          'seq',
          'code',
          'name',
          'change_pct',
          'latest_price',
          'amount',
          'seal_amount',
          'first_limit_time',
          'limit_stats',
          'board_count',
          'industry_name',
          'reason',
        ],
        columnDefs: [
          TableColumnData(
            key: 'seq',
            label: '序号',
            align: 'center',
            width: 54,
          ),
          TableColumnData(
            key: 'code',
            label: '代码',
            align: 'center',
            width: 88,
          ),
          TableColumnData(
            key: 'name',
            label: '名称',
            align: 'left',
            width: 140,
          ),
          TableColumnData(
            key: 'change_pct',
            label: '涨跌幅',
            align: 'right',
            width: 92,
          ),
          TableColumnData(
            key: 'latest_price',
            label: '最新价',
            align: 'right',
            width: 92,
          ),
          TableColumnData(
            key: 'amount',
            label: '成交额',
            align: 'right',
            width: 110,
          ),
          TableColumnData(
            key: 'seal_amount',
            label: '封板资金',
            align: 'right',
            width: 116,
          ),
          TableColumnData(
            key: 'first_limit_time',
            label: '首次封板时间',
            align: 'center',
            width: 106,
          ),
          TableColumnData(
            key: 'limit_stats',
            label: '涨停统计',
            align: 'center',
            width: 96,
          ),
          TableColumnData(
            key: 'board_count',
            label: '连板数',
            align: 'center',
            width: 88,
          ),
          TableColumnData(
            key: 'industry_name',
            label: '所属行业',
            align: 'left',
            width: 132,
          ),
          TableColumnData(
            key: 'reason',
            label: '入选理由',
            align: 'left',
            width: 220,
          ),
        ],
        rows: [],
        items: [
          TableRowItemData(
            cells: [
              '1',
              '300001',
              'StructuredCo',
              '+9.99%',
              '23.45',
              '6.20 yi',
              '1.80 yi',
              '09:32:00',
              '2 days/3 hits',
              '2',
              'Chip',
              'Chip rebound',
            ],
          ),
        ],
        total: 1,
      ),
    ],
  ),
);

class _FakeMarketCenterRepository extends MarketCenterRepository {
  _FakeMarketCenterRepository({
    required this.latestPage,
    required this.olderPage,
  }) : super(ApiClient(baseUrl: 'https://api.example.invalid'));

  final MarketCenterPageData latestPage;
  final MarketCenterPageData olderPage;
  final List<String?> requests = [];

  @override
  Future<MarketCenterPageData> fetchPage({String? tradeDate}) async {
    requests.add(tradeDate);
    if (tradeDate == '2026-04-17') {
      return olderPage;
    }
    return latestPage;
  }
}

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
