import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/news/application/news_provider.dart';
import 'package:niuniu_kaipan/features/news/data/news_workspace.dart';
import 'package:niuniu_kaipan/features/news/presentation/news_page.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:niuniu_kaipan/shared/data/market_api_repository.dart';

void main() {
  testWidgets('news page can open message center tab directly', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 1400);
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

    const snapshot = NewsWorkspaceData(
      hotNews: FeedSnapshot(
        tradeDate: '2026-04-18',
        fetchedAt: '2026-04-18T09:30:00',
        total: 1,
        items: [
          FeedItemData(
            title: 'Hot headline',
            subtitle: 'Hot subtitle',
            time: '09:30',
            extra: 'hot',
            url: null,
            group: 'hot',
            isImportant: false,
          ),
        ],
      ),
      todayHot: FeedSnapshot(
        tradeDate: '2026-04-18',
        fetchedAt: '2026-04-18T09:30:00',
        total: 1,
        items: [
          FeedItemData(
            title: 'Today theme',
            subtitle: 'Today subtitle',
            time: '09:32',
            extra: 'today',
            url: null,
            group: 'morning',
            isImportant: false,
          ),
        ],
      ),
      fastNews: FeedSnapshot(
        tradeDate: '2026-04-18',
        fetchedAt: '2026-04-18T09:35:00',
        total: 2,
        items: [
          FeedItemData(
            title: 'Important alert',
            subtitle: 'Fast tape',
            time: '09:35',
            extra: 'alert',
            url: 'https://example.com/fast/important',
            group: 'fast',
            isImportant: true,
          ),
          FeedItemData(
            title: 'Normal alert',
            subtitle: 'Fast tape',
            time: '09:36',
            extra: 'alert',
            url: null,
            group: 'fast',
            isImportant: false,
          ),
        ],
      ),
      timeline: FeedSnapshot(
        tradeDate: '2026-04-18',
        fetchedAt: '2026-04-18T09:40:00',
        total: 1,
        items: [
          FeedItemData(
            title: 'Calendar event',
            subtitle: 'Timeline',
            time: '10:00',
            extra: 'calendar',
            url: null,
            group: 'calendar',
            isImportant: false,
          ),
        ],
      ),
      monthlyPatterns: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => shellOverview),
          hotNewsProvider.overrideWith((ref) async => snapshot.hotNews),
          todayHotProvider.overrideWith((ref) async => snapshot.todayHot),
          fastNewsProvider.overrideWith((ref) async => snapshot.fastNews),
          timelineProvider.overrideWith((ref) async => snapshot.timeline),
          monthlyPatternsProvider.overrideWith(
            (ref) async => snapshot.monthlyPatterns,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NewsPage(initialTabIndex: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('复制图片'), findsOneWidget);
    expect(find.text('复制文本'), findsOneWidget);
    expect(find.text('导出 Excel'), findsOneWidget);
    expect(find.text('导出 CSV'), findsOneWidget);
    expect(find.text('Important alert'), findsOneWidget);
    expect(find.text('Normal alert'), findsOneWidget);
    expect(find.text('打开原文'), findsOneWidget);
  });
  testWidgets(
    'news page keeps other tabs usable when fast news is empty',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1800, 1400);
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

      const snapshot = NewsWorkspaceData(
        hotNews: FeedSnapshot(
          tradeDate: '2026-04-18',
          fetchedAt: '2026-04-18T09:30:00',
          total: 1,
          items: [
            FeedItemData(
              title: 'Hot headline',
              subtitle: 'Hot subtitle',
              time: '09:30',
              extra: 'hot',
              url: null,
              group: 'hot',
              isImportant: false,
            ),
          ],
        ),
        todayHot: FeedSnapshot(
          tradeDate: '2026-04-18',
          fetchedAt: '2026-04-18T09:30:00',
          total: 1,
          items: [
            FeedItemData(
              title: 'Today theme',
              subtitle: 'Today subtitle',
              time: '09:32',
              extra: 'today',
              url: null,
              group: 'morning',
              isImportant: false,
            ),
          ],
        ),
        fastNews: FeedSnapshot(
          tradeDate: '2026-04-18',
          fetchedAt: '2026-04-18T09:35:00',
          total: 0,
          items: [],
        ),
        timeline: FeedSnapshot(
          tradeDate: '2026-04-18',
          fetchedAt: '2026-04-18T09:40:00',
          total: 1,
          items: [
            FeedItemData(
              title: 'Calendar event',
              subtitle: 'Timeline',
              time: '10:00',
              extra: 'calendar',
              url: null,
              group: 'calendar',
              isImportant: false,
            ),
          ],
        ),
        monthlyPatterns: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellOverviewProvider.overrideWith((ref) async => shellOverview),
            hotNewsProvider.overrideWith((ref) async => snapshot.hotNews),
            todayHotProvider.overrideWith((ref) async => snapshot.todayHot),
            fastNewsProvider.overrideWith((ref) async => snapshot.fastNews),
            timelineProvider.overrideWith((ref) async => snapshot.timeline),
            monthlyPatternsProvider.overrideWith(
              (ref) async => snapshot.monthlyPatterns,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const NewsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hot headline'), findsOneWidget);
      expect(find.text('当前筛选条件下暂无 7x24 快讯。'), findsNothing);

      await tester.tap(find.text('7x24 快讯').first);
      await tester.pumpAndSettle();

      expect(find.text('当前筛选条件下暂无 7x24 快讯。'), findsOneWidget);
      expect(find.text('Hot headline'), findsNothing);

      await tester.tap(find.text('财经日历').first);
      await tester.pumpAndSettle();

      expect(find.text('Calendar event'), findsOneWidget);
      expect(find.text('当前筛选条件下暂无 7x24 快讯。'), findsNothing);
    },
  );
}
