import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/node/application/node_provider.dart';
import 'package:niuniu_kaipan/features/node/data/node_repository.dart';
import 'package:niuniu_kaipan/features/node/presentation/node_page.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';

void main() {
  testWidgets('node page renders leader linkage and refresh controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 2600);
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

    const snapshot = NodeSnapshotData(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T10:00:00',
      symbol: 'sz399001',
      quote: NodeQuoteData(
        tradeDate: '2026-04-18',
        fetchedAt: '2026-04-18T10:00:00',
        symbol: 'sz399001',
        name: 'SZ Component',
        price: 10234.56,
        preClose: 10120.11,
        open: 10180.00,
        high: 10260.20,
        low: 10150.30,
        volume: 123456789,
        amount: 456.78,
        change: 114.45,
        changePct: 1.13,
        turnoverRate: 2.41,
        amplitude: 1.08,
      ),
      kline: NodeKlineData(
        tradeDate: '2026-04-18',
        fetchedAt: '2026-04-18T10:00:00',
        symbol: 'sz399001',
        name: 'SZ Component',
        total: 2,
        bars: [
          NodeKlineBarData(
            tradeDate: '2026-04-17',
            openPrice: 10050,
            closePrice: 10120,
            highPrice: 10140,
            lowPrice: 10020,
            volume: 100000000,
          ),
          NodeKlineBarData(
            tradeDate: '2026-04-18',
            openPrice: 10180,
            closePrice: 10234.56,
            highPrice: 10260.2,
            lowPrice: 10150.3,
            volume: 123456789,
          ),
        ],
      ),
      defaultDate: '2026-04-18',
      helperText: 'Click a candle or date to inspect index-plate linkage.',
      dateItems: [
        NodeDateItemData(
          date: '2026-04-17',
          bar: NodeKlineBarData(
            tradeDate: '2026-04-17',
            openPrice: 10050,
            closePrice: 10120,
            highPrice: 10140,
            lowPrice: 10020,
            volume: 100000000,
          ),
          topPlates: [
            NodePlateData(
              rank: 1,
              plateCode: 'BK001',
              plateName: 'Robotics',
              ztCount: 4,
              strength: 9.1,
              strengthText: 'Strong',
            ),
          ],
        ),
        NodeDateItemData(
          date: '2026-04-18',
          bar: NodeKlineBarData(
            tradeDate: '2026-04-18',
            openPrice: 10180,
            closePrice: 10234.56,
            highPrice: 10260.2,
            lowPrice: 10150.3,
            volume: 123456789,
          ),
          topPlates: [
            NodePlateData(
              rank: 1,
              plateCode: 'BK001',
              plateName: 'Robotics',
              ztCount: 5,
              strength: 9.5,
              strengthText: 'Very Strong',
            ),
            NodePlateData(
              rank: 2,
              plateCode: 'BK002',
              plateName: 'AI Infra',
              ztCount: 3,
              strength: 8.2,
              strengthText: 'Strong',
            ),
          ],
        ),
      ],
    );

    const leaders = NodePlateLeadersData(
      tradeDate: '2026-04-18',
      fetchedAt: '2026-04-18T10:01:00',
      quoteTradeDate: '2026-04-18',
      quoteFetchedAt: '2026-04-18T10:01:00',
      plateCode: 'BK001',
      plateName: 'Robotics',
      date: '2026-04-18',
      total: 2,
      leaders: [
        NodeLeaderItemData(
          rankNo: 1,
          stockCode: '300001',
          stockName: 'Robot A',
          quote: NodeQuoteData(
            tradeDate: '2026-04-18',
            fetchedAt: '2026-04-18T10:01:00',
            symbol: '300001',
            name: 'Robot A',
            price: 25.12,
            preClose: 24.00,
            open: 24.30,
            high: 25.30,
            low: 24.20,
            volume: 1230000,
            amount: 6.42,
            change: 1.12,
            changePct: 4.67,
            turnoverRate: 8.12,
            amplitude: 4.58,
            dynamicPe: 12.60,
            circulatingCap: 2340000000.0,
            marketCap: 3450000000.0,
          ),
        ),
        NodeLeaderItemData(
          rankNo: 2,
          stockCode: '300002',
          stockName: 'Servo B',
          quote: NodeQuoteData(
            tradeDate: '2026-04-18',
            fetchedAt: '2026-04-18T10:01:00',
            symbol: '300002',
            name: 'Servo B',
            price: 18.88,
            preClose: 18.10,
            open: 18.22,
            high: 19.00,
            low: 18.08,
            volume: 980000,
            amount: 4.11,
            change: 0.78,
            changePct: 4.31,
            turnoverRate: 5.66,
            amplitude: 5.08,
            dynamicPe: 21.30,
            circulatingCap: 1980000000.0,
            marketCap: 2760000000.0,
          ),
        ),
      ],
    );

    final repository = _FakeNodeRepository(
      snapshot: snapshot,
      leaders: leaders,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => shellOverview),
          nodeRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NodePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('牛牛节点'), findsWidgets);
    expect(find.bySemanticsLabel('停止自动刷新'), findsOneWidget);
    expect(repository.snapshotCalls, greaterThanOrEqualTo(1));
    expect(repository.leaderCalls, greaterThanOrEqualTo(1));

    await tester.pumpAndSettle();

    expect(find.text('Robot A'), findsOneWidget);
    expect(find.text('复制图片'), findsOneWidget);
    expect(find.text('复制文本'), findsOneWidget);
    expect(find.text('导出 Excel'), findsOneWidget);
    expect(find.text('导出 CSV'), findsOneWidget);

    final stopButton = find.bySemanticsLabel('停止自动刷新');
    await tester.ensureVisible(stopButton);
    await tester.tap(stopButton);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('自动 5 秒'), findsOneWidget);

    final refreshButtons = find.text('刷新');
    expect(refreshButtons, findsOneWidget);

    final initialSnapshotCalls = repository.snapshotCalls;
    final initialLeaderCalls = repository.leaderCalls;

    await tester.tap(refreshButtons.first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.snapshotCalls, greaterThan(initialSnapshotCalls));
    expect(repository.leaderCalls, greaterThan(initialLeaderCalls));
  });
}

class _FakeNodeRepository extends NodeRepository {
  _FakeNodeRepository({
    required this.snapshot,
    required this.leaders,
  }) : super(ApiClient(baseUrl: 'https://api.example.invalid'));

  final NodeSnapshotData snapshot;
  final NodePlateLeadersData leaders;
  int snapshotCalls = 0;
  int leaderCalls = 0;

  @override
  Future<NodeSnapshotData> fetchSnapshot({
    required String symbol,
    int days = 21,
    int plateLimit = 5,
  }) async {
    snapshotCalls += 1;
    return snapshot;
  }

  @override
  Future<NodePlateLeadersData> fetchPlateLeaders({
    required String plateCode,
    required String date,
    int stockLimit = 10,
  }) async {
    leaderCalls += 1;
    return leaders;
  }
}
