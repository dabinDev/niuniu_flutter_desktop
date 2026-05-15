import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/features/plate_rotation/application/plate_rotation_provider.dart';
import 'package:niuniu_kaipan/features/plate_rotation/data/plate_rotation_repository.dart';
import 'package:niuniu_kaipan/features/plate_rotation/presentation/plate_rotation_page.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';

void main() {
  testWidgets(
      'plate rotation page renders export controls and switches selection', (
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

    const snapshot = PlateRotationSnapshot(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T10:00:00',
      previousTradeDate: '2026-04-17',
      availableTradeDates: ['2026-04-17', '2026-04-18'],
      dates: ['2026-04-17', '2026-04-18'],
      total: 2,
      plateDateSummaries: [
        PlateRotationDateSummaryData(
          date: '2026-04-18',
          plateName: 'Robotics',
          plateCode: 'BK001',
          rank: 1,
          ztCount: 5,
          strength: 9.5,
          strengthText: 'Very Strong',
          latestZt: 5,
          latestStrengthText: 'Strong',
          isMatrixTop: true,
          leaderTotal: 1,
          leadersPreview: [
            PlateRotationLeaderPreviewData(
              stockCode: '300001',
              stockName: 'Robot A',
              rankNo: 1,
            ),
          ],
        ),
        PlateRotationDateSummaryData(
          date: '2026-04-17',
          plateName: 'AI Infra',
          plateCode: 'BK002',
          rank: 1,
          ztCount: 6,
          strength: 9.7,
          strengthText: 'Explosive',
          latestZt: 4,
          latestStrengthText: 'Rising',
          isMatrixTop: true,
          leaderTotal: 1,
          leadersPreview: [
            PlateRotationLeaderPreviewData(
              stockCode: '688002',
              stockName: 'Server C',
              rankNo: 1,
            ),
          ],
        ),
      ],
      matrixColumns: [
        PlateRotationMatrixColumnData(
          date: '2026-04-18',
          items: [
            PlateRotationMatrixCellData(
              rank: 1,
              plateName: 'Robotics',
              plateCode: 'BK001',
              ztCount: 5,
              strength: 9.5,
              strengthText: 'Very Strong',
            ),
            PlateRotationMatrixCellData(
              rank: 2,
              plateName: 'AI Infra',
              plateCode: 'BK002',
              ztCount: 3,
              strength: 7.5,
              strengthText: 'Warm',
            ),
          ],
        ),
        PlateRotationMatrixColumnData(
          date: '2026-04-17',
          items: [
            PlateRotationMatrixCellData(
              rank: 1,
              plateName: 'AI Infra',
              plateCode: 'BK002',
              ztCount: 6,
              strength: 9.7,
              strengthText: 'Explosive',
            ),
            PlateRotationMatrixCellData(
              rank: 2,
              plateName: 'Robotics',
              plateCode: 'BK001',
              ztCount: 4,
              strength: 8.8,
              strengthText: 'Strong',
            ),
          ],
        ),
      ],
      items: [
        PlateRotationItemData(
          plateName: 'Robotics',
          plateCode: 'BK001',
          latestZt: 5,
          latestStrengthText: 'Strong',
          series: [
            PlateRotationPointData(
              date: '2026-04-18',
              ztCount: 5,
              strength: 9.5,
              strengthText: 'Very Strong',
            ),
            PlateRotationPointData(
              date: '2026-04-17',
              ztCount: 4,
              strength: 8.8,
              strengthText: 'Strong',
            ),
          ],
        ),
        PlateRotationItemData(
          plateName: 'AI Infra',
          plateCode: 'BK002',
          latestZt: 4,
          latestStrengthText: 'Rising',
          series: [
            PlateRotationPointData(
              date: '2026-04-18',
              ztCount: 3,
              strength: 7.5,
              strengthText: 'Warm',
            ),
            PlateRotationPointData(
              date: '2026-04-17',
              ztCount: 6,
              strength: 9.7,
              strengthText: 'Explosive',
            ),
          ],
        ),
      ],
    );

    const roboticsStocks = PlateStocksSnapshot(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T10:01:00',
      plateCode: 'BK001',
      plateName: 'Robotics',
      dates: ['2026-04-17', '2026-04-18'],
      items: [
        PlateStockDateGroupData(
          date: '2026-04-17',
          total: 1,
          stocks: [
            PlateStockItemData(
              stockCode: '300002',
              stockName: 'Servo B',
              rankNo: 1,
            ),
          ],
        ),
        PlateStockDateGroupData(
          date: '2026-04-18',
          total: 1,
          stocks: [
            PlateStockItemData(
              stockCode: '300001',
              stockName: 'Robot A',
              rankNo: 1,
            ),
          ],
        ),
      ],
    );

    const aiInfraStocks = PlateStocksSnapshot(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T10:02:00',
      plateCode: 'BK002',
      plateName: 'AI Infra',
      dates: ['2026-04-17', '2026-04-18'],
      items: [
        PlateStockDateGroupData(
          date: '2026-04-17',
          total: 1,
          stocks: [
            PlateStockItemData(
              stockCode: '688002',
              stockName: 'Server C',
              rankNo: 1,
            ),
          ],
        ),
        PlateStockDateGroupData(
          date: '2026-04-18',
          total: 1,
          stocks: [
            PlateStockItemData(
              stockCode: '688001',
              stockName: 'Compute X',
              rankNo: 1,
            ),
          ],
        ),
      ],
    );

    const roboticsLeaders = PlateLeaderQuotesSnapshot(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T10:01:00',
      quoteTradeDate: '2026-04-18',
      quoteFetchedAt: '2026-04-18T10:01:00',
      plateCode: 'BK001',
      plateName: 'Robotics',
      date: '2026-04-18',
      total: 1,
      leaders: [
        PlateLeaderQuoteItemData(
          rankNo: 1,
          stockCode: '300001',
          stockName: 'Robot A',
          quote: PlateLeaderQuoteData(
            symbol: '300001',
            name: 'Robot A',
            price: 25.12,
            changePct: 4.67,
            open: 24.30,
            amplitude: 4.58,
            amount: 6.42,
          ),
        ),
      ],
    );

    const aiInfraLeaders = PlateLeaderQuotesSnapshot(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T10:02:00',
      quoteTradeDate: '2026-04-17',
      quoteFetchedAt: '2026-04-17T15:01:00',
      plateCode: 'BK002',
      plateName: 'AI Infra',
      date: '2026-04-17',
      total: 1,
      leaders: [
        PlateLeaderQuoteItemData(
          rankNo: 1,
          stockCode: '688002',
          stockName: 'Server C',
          quote: PlateLeaderQuoteData(
            symbol: '688002',
            name: 'Server C',
            price: 88.66,
            changePct: 7.21,
            open: 82.30,
            amplitude: 8.02,
            amount: 14.80,
          ),
        ),
      ],
    );

    final repository = _FakePlateRotationRepository(
      snapshot: snapshot,
      stocksByPlateCode: const {
        'BK001': roboticsStocks,
        'BK002': aiInfraStocks,
      },
      leadersByKey: const {
        'BK001|2026-04-18': roboticsLeaders,
        'BK002|2026-04-17': aiInfraLeaders,
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => shellOverview),
          plateRotationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PlateRotationPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('板块轮动'), findsWidgets);
    expect(find.text('最新涨停 5'), findsWidgets);
    expect(find.text('最新涨停 4'), findsWidgets);
    expect(find.text('Strong'), findsNothing);
    expect(find.text('Rising'), findsNothing);
    expect(
      find.bySemanticsLabel('pw-plate-rotation-toolbar-复制图片'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('pw-plate-rotation-toolbar-复制文本'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('pw-plate-rotation-toolbar-导出 Excel'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('pw-plate-rotation-toolbar-导出 CSV'),
      findsOneWidget,
    );
    expect(find.text('Robot A'), findsWidgets);
    expect(find.textContaining('接口摘要'), findsOneWidget);
    expect(find.text('领涨日期带'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plate-rotation-leader-band-2026-04-18')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey('plate-rotation-leader-band-2026-04-18'),
            ),
          )
          .dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey('plate-rotation-leader-band-2026-04-17'),
              ),
            )
            .dx,
      ),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey('plate-rotation-trade-date-2026-04-18'),
            ),
          )
          .dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey('plate-rotation-trade-date-2026-04-17'),
              ),
            )
            .dx,
      ),
    );
    final latestMatrixCell = find.byKey(
      const ValueKey('plate-rotation-matrix-2026-04-18-BK001'),
    );
    final latestLeaderBand = find.byKey(
      const ValueKey('plate-rotation-leader-band-2026-04-18'),
    );
    expect(
      tester.getSize(latestMatrixCell).width,
      moreOrLessEquals(tester.getSize(latestLeaderBand).width),
    );
    expect(
      tester.getTopLeft(latestMatrixCell).dx,
      moreOrLessEquals(tester.getTopLeft(latestLeaderBand).dx),
    );

    final aiInfraCell = find
        .ancestor(
          of: find.text('AI Infra').first,
          matching: find.byType(InkWell),
        )
        .first;
    final aiInfraWidget = tester.widget<InkWell>(aiInfraCell);
    aiInfraWidget.onTap?.call();
    await tester.pumpAndSettle();

    expect(find.text('Server C'), findsWidgets);
    expect(
      find.byKey(const ValueKey('plate-rotation-leader-band-2026-04-17')),
      findsOneWidget,
    );
    expect(repository.stocksCalls, greaterThanOrEqualTo(2));
    expect(repository.leaderCalls, greaterThanOrEqualTo(2));
    expect(
      find.byKey(const ValueKey('plate-rotation-trade-date-2026-04-18')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plate-rotation-trade-date-2026-04-17')),
      findsOneWidget,
    );
  });
}

class _FakePlateRotationRepository extends PlateRotationRepository {
  _FakePlateRotationRepository({
    required this.snapshot,
    required this.stocksByPlateCode,
    required this.leadersByKey,
  }) : super(ApiClient(baseUrl: 'https://api.example.invalid'));

  final PlateRotationSnapshot snapshot;
  final Map<String, PlateStocksSnapshot> stocksByPlateCode;
  final Map<String, PlateLeaderQuotesSnapshot> leadersByKey;
  int snapshotCalls = 0;
  int stocksCalls = 0;
  int leaderCalls = 0;

  @override
  Future<PlateRotationSnapshot> fetchRotation({
    int limit = 100,
    String? tradeDate,
  }) async {
    snapshotCalls += 1;
    return snapshot;
  }

  @override
  Future<PlateStocksSnapshot> fetchPlateStocks(
    String plateCode, {
    int limit = 12,
  }) async {
    stocksCalls += 1;
    return stocksByPlateCode[plateCode]!;
  }

  @override
  Future<PlateLeaderQuotesSnapshot> fetchDateLeaders({
    required String plateCode,
    required String date,
    int stockLimit = 10,
  }) async {
    leaderCalls += 1;
    return leadersByKey['$plateCode|$date']!;
  }
}
