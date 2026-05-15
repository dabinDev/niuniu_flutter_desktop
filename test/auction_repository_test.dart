import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/features/auction/data/auction_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.response);

  final Map<String, dynamic> response;
  String? requestedPath;

  @override
  Future<Map<String, dynamic>> getMap(String path) async {
    requestedPath = path;
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fetchAuctionPageData requests auction page and parses response',
      () async {
    final client = _FakeApiClient(
      {
        'trade_date': '2026-04-17',
        'fetched_at': '2026-04-17T09:26:00',
        'history_columns': [
          {
            'trade_date': '2026-04-17',
            'fetched_at': '2026-04-17T09:26:00',
            'title': '2026-04-17 Auction Live',
            'trade_label': '2026-04-17',
            'yizi_count': 3,
            'seal_amount': '12.5 yi',
            'time_labels': ['9:15', '9:20', '9:25', 'rise'],
            'is_live': true,
            'total': 2,
            'items': [
              {
                'code': '600000',
                'name': 'PFBank',
                'concepts': ['Robot', 'AI'],
                'lianban': '',
                'amounts': ['9:15 1.2 yi', '9:20 1.6 yi', '9:25 2.0 yi'],
                'zhangfu': '+5.20%',
              },
            ],
          },
        ],
        'rank_sections': [
          {
            'key': 'weimai',
            'title': 'limit_buy',
            'tab_label': 'Limit Buy',
            'columns': ['name', 'bid_vs_now'],
            'total': 1,
            'items': [
              {
                'code': '600000',
                'name': 'PFBank',
                'cells': ['PFBank (600000)', '+5.20% / +4.80%'],
                'bid_change_pct': 5.2,
                'current_change_pct': 4.8,
                'entrust_amount_yuan': 120000000,
                'match_amount_yuan': 80000000,
                'seal_amount_wan': 4500,
                'board_count': 3,
                'float_market_cap_yi': 32,
                'price': 10.5,
                'concept': 'Robot',
              },
            ],
          },
        ],
      },
    );

    final repository = AuctionRepository(client);
    final snapshot = await repository.fetchAuctionPageData(
      days: 4,
      stockLimit: 12,
      rankLimit: 30,
    );

    expect(
      client.requestedPath,
      '/api/v1/auction/page?days=4&stock_limit=12&rank_limit=30',
    );
    expect(snapshot.tradeDate, '2026-04-17');
    expect(snapshot.historyColumns, hasLength(1));
    expect(snapshot.historyColumns.first.isLive, isTrue);
    expect(snapshot.historyColumns.first.items.first.code, '600000');
    expect(snapshot.historyColumns.first.items.first.concepts, ['Robot', 'AI']);
    expect(snapshot.rankSections, hasLength(1));
    expect(snapshot.rankSections.first.key, 'weimai');
    expect(
        snapshot.rankSections.first.items.first.cells.first, 'PFBank (600000)');
    expect(snapshot.rankSections.first.items.first.bidChangePct, 5.2);
    expect(snapshot.rankSections.first.items.first.currentChangePct, 4.8);
    expect(
        snapshot.rankSections.first.items.first.entrustAmountYuan, 120000000);
    expect(snapshot.rankSections.first.items.first.matchAmountYuan, 80000000);
    expect(snapshot.rankSections.first.items.first.sealAmountWan, 4500);
    expect(snapshot.rankSections.first.items.first.boardCount, 3);
    expect(snapshot.rankSections.first.items.first.floatMarketCapYi, 32);
    expect(snapshot.rankSections.first.items.first.price, 10.5);
    expect(snapshot.rankSections.first.items.first.concept, 'Robot');
  });

  test('generateAiAnalysis surfaces daily limit errors clearly', () async {
    final client = _FakeAuctionAiLimitClient();
    final repository = AuctionRepository(client);

    expect(
      repository.generateAiAnalysis,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('今日 AI 使用次数已用完'),
        ),
      ),
    );
  });
}

class _FakeAuctionAiLimitClient extends ApiClient {
  _FakeAuctionAiLimitClient() : super(baseUrl: 'https://api.example.invalid');

  @override
  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? data,
    Duration? receiveTimeout,
  }) async {
    if (path == '/api/v1/auction/ai-analysis') {
      throw StateError('超过当日免费使用限制（公共密钥 auction 功能今日已用 5/5 次）。');
    }
    return <String, dynamic>{};
  }
}
