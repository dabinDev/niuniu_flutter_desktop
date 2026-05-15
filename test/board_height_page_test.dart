import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/board_height/application/board_height_provider.dart';
import 'package:niuniu_kaipan/features/board_height/data/board_height_repository.dart';
import 'package:niuniu_kaipan/features/board_height/presentation/board_height_page.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/application/app_preferences_provider.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:niuniu_kaipan/shared/application/stock_link_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'board height page renders copy actions and opens stock on tile tap',
      (tester) async {
    final openedCodes = <String>[];

    await _pumpBoardHeightPage(
      tester,
      stockLinkService: _FakeStockLinkService(
        onOpen: openedCodes.add,
      ),
    );

    expect(find.text('刷新'), findsOneWidget);
    expect(find.text('复制图片'), findsOneWidget);
    expect(find.text('复制文本'), findsOneWidget);
    expect(find.text('导出 Excel'), findsOneWidget);
    expect(find.text('导出 CSV'), findsOneWidget);

    final stockTile = find.byKey(const ValueKey('board-height-stock-600000'));
    await tester.ensureVisible(stockTile);
    await tester.tap(stockTile);
    await tester.pump();

    expect(openedCodes, ['600000']);
  });

  testWidgets('board height page shows trade date navigation actions',
      (tester) async {
    await _pumpBoardHeightPage(tester);

    final previousButton =
        find.byKey(const ValueKey('board-height-prev-trade-date'));
    final nextButton =
        find.byKey(const ValueKey('board-height-next-trade-date'));

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
      find.byKey(const ValueKey('board-height-trade-date-latest')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpBoardHeightPage(
  WidgetTester tester, {
  StockLinkService? stockLinkService,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1800, 1600);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shellOverviewProvider.overrideWith((ref) async => _shellOverview),
        boardHeightProvider(null).overrideWith((ref) async => _snapshot),
        if (stockLinkService != null)
          stockLinkServiceProvider.overrideWith((ref) => stockLinkService),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const BoardHeightPage(),
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

const _snapshot = BoardHeightSnapshot(
  tradeDate: '2026-04-17',
  fetchedAt: '2026-04-17T16:31:00',
  previousTradeDate: '2026-04-16',
  availableTradeDates: ['2026-04-17', '2026-04-16'],
  latestHeight: 4,
  chartItems: [
    BoardHeightChartItemData(
      date: '2026-04-16',
      value: 3,
      leaderName: 'Alpha',
      leaderCode: '000001',
    ),
    BoardHeightChartItemData(
      date: '2026-04-17',
      value: 4,
      leaderName: 'LeaderCo',
      leaderCode: '600000',
    ),
  ],
  columns: [
    BoardHeightColumnData(
      date: '2026-04-16',
      stocks: [
        BoardHeightStockData(
          name: 'Alpha',
          code: '000001',
          boardCount: 3,
        ),
      ],
    ),
    BoardHeightColumnData(
      date: '2026-04-17',
      stocks: [
        BoardHeightStockData(
          name: 'LeaderCo',
          code: '600000',
          boardCount: 4,
        ),
        BoardHeightStockData(
          name: 'Beta',
          code: '300001',
          boardCount: 2,
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
