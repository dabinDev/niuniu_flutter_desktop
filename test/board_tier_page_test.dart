import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/board_tier/application/board_tier_provider.dart';
import 'package:niuniu_kaipan/features/board_tier/presentation/board_tier_page.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/application/app_preferences_provider.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:niuniu_kaipan/shared/application/stock_link_service.dart';
import 'package:niuniu_kaipan/shared/data/market_api_provider.dart';
import 'package:niuniu_kaipan/shared/data/market_api_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('board tier page toggles auto refresh chip', (tester) async {
    await _pumpBoardTierPage(tester);

    expect(find.text('连板天梯'), findsWidgets);
    expect(find.text('自动 5 秒'), findsOneWidget);
    expect(find.text('复制图片'), findsOneWidget);
    expect(find.text('复制文本'), findsOneWidget);
    expect(find.text('导出 Excel'), findsOneWidget);
    expect(find.text('导出 CSV'), findsOneWidget);

    final autoRefreshChip = find.widgetWithText(FilterChip, '自动 5 秒');
    await tester.ensureVisible(autoRefreshChip);
    await tester.tap(autoRefreshChip);
    await tester.pump();

    expect(find.text('停止'), findsOneWidget);

    final stopChip = find.widgetWithText(FilterChip, '停止');
    await tester.ensureVisible(stopChip);
    await tester.tap(stopChip);
    await tester.pump();

    expect(find.text('自动 5 秒'), findsOneWidget);
  });

  testWidgets('board tier stock card opens profile sheet on card tap',
      (tester) async {
    await _pumpBoardTierPage(
      tester,
      marketApiRepository: _FakeMarketApiRepository(),
    );

    await tester.tap(find.byKey(const ValueKey('board-tier-stock-600000')));
    await tester.pumpAndSettle();

    expect(find.text('个股资料'), findsOneWidget);
    expect(find.text('个股资料缓存与最新行情快照'), findsOneWidget);
    expect(find.text('行情指标'), findsOneWidget);
  });

  testWidgets('board tier stock link icon still opens stock', (tester) async {
    final openedCodes = <String>[];

    await _pumpBoardTierPage(
      tester,
      marketApiRepository: _FakeMarketApiRepository(),
      stockLinkService: _FakeStockLinkService(
        onOpen: openedCodes.add,
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('board-tier-stock-600000')),
        matching: find.byIcon(Icons.open_in_new_rounded),
      ),
    );
    await tester.pump();

    expect(openedCodes, ['600000']);
  });

  testWidgets('board tier page shows region and listing metadata',
      (tester) async {
    await _pumpBoardTierPage(tester);

    expect(find.text('Shanghai'), findsOneWidget);
    expect(find.text('上市 2001-11-28'), findsOneWidget);
  });

  testWidgets('board tier page shows trade date navigation actions',
      (tester) async {
    await _pumpBoardTierPage(tester);

    final previousButton =
        find.byKey(const ValueKey('board-tier-prev-trade-date'));
    final nextButton = find.byKey(const ValueKey('board-tier-next-trade-date'));

    expect(previousButton, findsOneWidget);
    expect(nextButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(previousButton).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<FilledButton>(nextButton).onPressed,
      isNull,
    );
    expect(
      find.byKey(const ValueKey('board-tier-trade-date-latest')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpBoardTierPage(
  WidgetTester tester, {
  MarketApiRepository? marketApiRepository,
  StockLinkService? stockLinkService,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1800, 1400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shellOverviewProvider.overrideWith((ref) async => _shellOverview),
        boardTierProvider(null).overrideWith((ref) async => _boardTierSnapshot),
        if (marketApiRepository != null)
          marketApiRepositoryProvider
              .overrideWith((ref) => marketApiRepository),
        if (stockLinkService != null)
          stockLinkServiceProvider.overrideWith((ref) => stockLinkService),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const BoardTierPage(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

const _shellOverview = OverviewSnapshot(
  tradeDate: '2026-04-17',
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

const _boardTierSnapshot = BoardTierSnapshot(
  tradeDate: '2026-04-17',
  fetchedAt: '2026-04-17T16:31:00',
  previousTradeDate: '2026-04-16',
  availableTradeDates: ['2026-04-17', '2026-04-16'],
  totalTiers: 2,
  totalStocks: 3,
  tiers: [
    BoardTierGroupData(
      boardCount: 3,
      title: '3 boards',
      total: 2,
      sealedCount: 1,
      brokenCount: 1,
      successRatePct: 50,
      successRateText: '1/2=50%',
      stocks: [
        BoardTierStockData(
          code: '600000',
          name: 'LeaderCo',
          market: '沪',
          status: 'sealed',
          changePct: '+10.01%',
          latestPrice: '12.88',
          firstLimitTime: '09:31',
          amount: '8.2 yi',
          breakCount: '0',
          regionName: 'Shanghai',
          industryName: 'AI Compute',
          listingDate: '2001-11-28',
          reason: 'Leader keeps extending',
        ),
        BoardTierStockData(
          code: '000001',
          name: 'FollowCo',
          market: '深',
          status: 'broken',
          changePct: '+6.32%',
          latestPrice: '7.45',
          firstLimitTime: '10:12',
          amount: '4.5 yi',
          breakCount: '2',
          regionName: 'Guangdong',
          industryName: 'Robotics',
          listingDate: '1991-04-03',
          reason: 'High-position profit taking',
        ),
      ],
    ),
    BoardTierGroupData(
      boardCount: 1,
      title: 'first board',
      total: 1,
      sealedCount: 1,
      brokenCount: 0,
      successRatePct: 100,
      successRateText: '1/1=100%',
      stocks: [
        BoardTierStockData(
          code: '300001',
          name: 'StarterCo',
          market: '创',
          status: 'sealed',
          changePct: '+20.00%',
          latestPrice: '25.60',
          firstLimitTime: '09:43',
          amount: '3.1 yi',
          breakCount: '0',
          regionName: 'Beijing',
          industryName: 'Chip',
          listingDate: '2020-08-12',
          reason: 'Fresh first-board catalyst',
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

class _FakeMarketApiRepository extends MarketApiRepository {
  _FakeMarketApiRepository()
      : super(ApiClient(baseUrl: 'https://api.example.invalid'));

  @override
  Future<StockProfileData> fetchStockProfile(String symbol) async {
    return const StockProfileData(
      symbol: '600000',
      stockCode: '600000',
      name: 'LeaderCo',
      market: 'SH',
      secid: '1.600000',
      regionName: 'Shanghai',
      industryName: 'AI Compute',
      listingDate: '2001-11-28',
      isActive: true,
      profileUpdatedAt: '2026-04-18T09:35:00',
      updatedAt: '2026-04-18T09:35:00',
    );
  }

  @override
  Future<QuoteData> fetchQuote(String symbol) async {
    return const QuoteData(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T10:01:00',
      symbol: '600000',
      name: 'LeaderCo',
      price: 12.88,
      preClose: 11.71,
      open: 12.30,
      high: 12.88,
      low: 12.18,
      volume: 125000000,
      amount: 820000000,
      change: 1.17,
      changePct: 10.01,
      turnoverRate: 14.20,
      amplitude: 6.02,
    );
  }

  @override
  Future<KlineSnapshot> fetchKline(String symbol, {int days = 21}) async {
    return const KlineSnapshot(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T10:01:00',
      symbol: '600000',
      name: 'LeaderCo',
      total: 6,
      bars: [
        KlineBarData(
          tradeDate: '2026-04-11',
          openPrice: 10.11,
          closePrice: 10.36,
          highPrice: 10.42,
          lowPrice: 10.02,
          volume: 80100000,
        ),
        KlineBarData(
          tradeDate: '2026-04-14',
          openPrice: 10.38,
          closePrice: 10.92,
          highPrice: 10.96,
          lowPrice: 10.28,
          volume: 93200000,
        ),
        KlineBarData(
          tradeDate: '2026-04-15',
          openPrice: 10.95,
          closePrice: 11.24,
          highPrice: 11.31,
          lowPrice: 10.88,
          volume: 99100000,
        ),
        KlineBarData(
          tradeDate: '2026-04-16',
          openPrice: 11.20,
          closePrice: 11.71,
          highPrice: 11.76,
          lowPrice: 11.12,
          volume: 104200000,
        ),
        KlineBarData(
          tradeDate: '2026-04-17',
          openPrice: 11.76,
          closePrice: 12.12,
          highPrice: 12.20,
          lowPrice: 11.60,
          volume: 117600000,
        ),
        KlineBarData(
          tradeDate: '2026-04-18',
          openPrice: 12.30,
          closePrice: 12.88,
          highPrice: 12.88,
          lowPrice: 12.18,
          volume: 125000000,
        ),
      ],
    );
  }
}
