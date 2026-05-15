import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/auction/application/auction_provider.dart';
import 'package:niuniu_kaipan/features/auction/data/auction_repository.dart';
import 'package:niuniu_kaipan/features/auction/presentation/auction_page.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:niuniu_kaipan/shared/data/ai_analysis_data.dart';

void main() {
  testWidgets('auction page renders and links selection across panels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 1400);
    addTearDown(tester.view.reset);

    const shellOverview = OverviewSnapshot(
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

    const snapshot = AuctionPageData(
      tradeDate: '2026-04-17',
      fetchedAt: '2026-04-17T09:26:00',
      historyColumns: [
        AuctionHistoryColumnData(
          tradeDate: '2026-04-17',
          fetchedAt: '2026-04-17T09:26:00',
          title: '2026-04-17<br><span>Yi:3 | Seal:12.5 yi</span><br>'
              '<div class="time"><i>9:15</i> | <i>9:20</i> | '
              '<i>9:25</i> | <i>rise</i></div>',
          tradeLabel: '2026-04-17',
          yiziCount: 3,
          sealAmount: '12.5 yi',
          timeLabels: ['9:15', '9:20', '9:25', 'rise'],
          isLive: true,
          total: 2,
          items: [
            AuctionColumnItemData(
              code: '600000',
              name: 'PFBank',
              concepts: ['Robot', 'AI'],
              lianban: '',
              amounts: ['9:15 1.2 yi', '9:20 1.6 yi', '9:25 2.0 yi'],
              zhangfu: '+5.20%',
            ),
            AuctionColumnItemData(
              code: '000967',
              name: 'YFEnv',
              concepts: ['EV', 'Battery'],
              lianban: '',
              amounts: ['9:15 0.8 yi', '9:20 1.1 yi', '9:25 1.5 yi'],
              zhangfu: '+3.10%',
            ),
          ],
        ),
        AuctionHistoryColumnData(
          tradeDate: '2026-04-16',
          fetchedAt: '2026-04-16T09:26:00',
          title: '2026-04-16 Auction Live',
          tradeLabel: '2026-04-16',
          yiziCount: 2,
          sealAmount: '10.2 yi',
          timeLabels: ['9:15', '9:20', '9:25', 'rise'],
          isLive: false,
          total: 1,
          items: [
            AuctionColumnItemData(
              code: '600000',
              name: 'PFBank',
              concepts: ['Robot', 'AI'],
              lianban: '',
              amounts: ['9:15 1.0 yi', '9:20 1.3 yi', '9:25 1.8 yi'],
              zhangfu: '+4.20%',
            ),
          ],
        ),
      ],
      rankSections: [
        AuctionRankSectionData(
          key: 'weimai',
          title: 'limit_buy',
          tabLabel: 'Limit Buy',
          columns: [
            'name',
            'entrust_match',
            'seal_amount',
            'bid_vs_now',
            'concept',
            'cap_vs_price',
          ],
          total: 2,
          items: [
            AuctionRankItemData(
              code: '600000',
              name: 'PFBank',
              cells: ['PFBank (600000)', '+5.20% / +4.80%'],
              bidChangePct: 5.2,
              currentChangePct: 4.8,
              entrustAmountYuan: 120000000,
              matchAmountYuan: 80000000,
              sealAmountWan: 4500,
              boardCount: 3,
              floatMarketCapYi: 32,
              price: 10.5,
              concept: 'Robot',
            ),
            AuctionRankItemData(
              code: '000967',
              name: 'YFEnv',
              cells: ['YFEnv (000967)', '+3.10% / +2.80%'],
              bidChangePct: 3.1,
              currentChangePct: 2.8,
              entrustAmountYuan: 82000000,
              matchAmountYuan: 61000000,
              sealAmountWan: 3100,
              boardCount: 1,
              floatMarketCapYi: 28,
              price: 8.7,
              concept: 'EV',
            ),
          ],
        ),
        AuctionRankSectionData(
          key: 'zrzt',
          title: 'yesterday_limit_up',
          tabLabel: 'Yesterday Limit',
          columns: ['name', 'bid_vs_now'],
          total: 1,
          items: [
            AuctionRankItemData(
              code: '600000',
              name: 'PFBank',
              cells: ['PFBank (600000)', '+4.20% / +3.90%'],
            ),
          ],
        ),
      ],
      aiAnalysis: AiAnalysisStateData(
        source: 'auction_ai',
        tradeDate: '2026-04-17',
        enabled: true,
        reason: '可生成 AI 竞价分析。',
        provider: 'kimi',
        model: 'kimi-k2-0711-preview',
        generatedAt: null,
        analysis: '',
        cached: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => shellOverview),
          auctionPageProvider.overrideWith((ref) async => snapshot),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AuctionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('牛牛竞价'), findsWidgets);
    expect(find.text('复制图片'), findsOneWidget);
    expect(find.text('复制文本'), findsOneWidget);
    expect(find.text('导出 Excel'), findsOneWidget);
    expect(find.text('导出 CSV'), findsOneWidget);
    expect(find.text('AI竞价'), findsOneWidget);
    expect(find.textContaining('当前选中 600000'), findsNothing);
    expect(find.textContaining('<br>'), findsNothing);
    expect(find.textContaining('一字:3'), findsWidgets);
    expect(find.textContaining('封单'), findsWidgets);
    expect(find.text('PFBank'), findsWidgets);
    expect(find.text('1.2亿'), findsOneWidget);
    expect(find.text('8000万'), findsOneWidget);
    expect(find.text('4500万'), findsOneWidget);
    expect(find.text('3连板'), findsOneWidget);
    expect(find.textContaining('10.50'), findsWidgets);

    final stockCard = find
        .ancestor(
          of: find.text('PFBank').first,
          matching: find.byType(InkWell),
        )
        .first;
    final stockCardWidget = tester.widget<InkWell>(stockCard);
    stockCardWidget.onTap?.call();
    await tester.pumpAndSettle();

    expect(find.textContaining('当前选中 600000'), findsWidgets);
    expect(find.text('Robot / AI'), findsWidgets);
  });
}
