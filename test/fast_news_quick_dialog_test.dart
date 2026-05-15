import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/features/news/presentation/fast_news_quick_dialog.dart';
import 'package:niuniu_kaipan/shared/data/market_api_provider.dart';
import 'package:niuniu_kaipan/shared/data/market_api_repository.dart';

void main() {
  testWidgets(
      'fast news quick dialog loads, filters, and forwards full-page action',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 1400);
    addTearDown(tester.view.reset);

    final repository = _FakeMarketApiRepository(
      const FeedSnapshot(
        tradeDate: '2026-04-18',
        fetchedAt: '2026-04-18T09:35:00',
        total: 2,
        items: [
          FeedItemData(
            title: 'Important alert',
            subtitle: 'Semiconductor strength',
            time: '2026-04-18 09:35',
            extra: 'Fast source',
            url: null,
            group: '2026-04-18',
            isImportant: true,
          ),
          FeedItemData(
            title: 'Normal update',
            subtitle: 'Banking rotation',
            time: '2026-04-18 09:36',
            extra: 'Fast source',
            url: null,
            group: '2026-04-18',
            isImportant: false,
          ),
        ],
      ),
    );

    var openedFullPage = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketApiRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: FastNewsQuickDialog(
              onOpenFullPage: () {
                openedFullPage = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('消息中心 / 7x24'), findsOneWidget);
    expect(find.text('Important alert'), findsOneWidget);
    expect(find.text('Normal update'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Semiconductor');
    await tester.pumpAndSettle();

    expect(find.text('Important alert'), findsOneWidget);
    expect(find.text('Normal update'), findsNothing);

    await tester.tap(find.byTooltip('打开完整页面'));
    await tester.pump();

    expect(openedFullPage, isTrue);
    expect(repository.fastNewsCalls, greaterThanOrEqualTo(1));
  });
}

class _FakeMarketApiRepository extends MarketApiRepository {
  _FakeMarketApiRepository(this.snapshot)
      : super(ApiClient(baseUrl: 'https://api.example.invalid'));

  final FeedSnapshot snapshot;
  int fastNewsCalls = 0;

  @override
  Future<FeedSnapshot> fetchFastNews({int limit = 20}) async {
    fastNewsCalls += 1;
    return snapshot;
  }
}
