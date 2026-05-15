import '../../../core/network/api_client.dart';
import '../../../shared/data/market_api_repository.dart';

class MarketCenterNavigationData {
  const MarketCenterNavigationData({
    required this.requestedTradeDate,
    required this.resolvedTradeDate,
    required this.previousTradeDate,
    required this.nextTradeDate,
    required this.availableTradeDates,
  });

  final String? requestedTradeDate;
  final String? resolvedTradeDate;
  final String? previousTradeDate;
  final String? nextTradeDate;
  final List<String> availableTradeDates;

  factory MarketCenterNavigationData.fromJson(Map<String, dynamic> json) {
    return MarketCenterNavigationData(
      requestedTradeDate: json['requested_trade_date']?.toString(),
      resolvedTradeDate: json['resolved_trade_date']?.toString(),
      previousTradeDate: json['previous_trade_date']?.toString(),
      nextTradeDate: json['next_trade_date']?.toString(),
      availableTradeDates:
          (json['available_trade_dates'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
    );
  }
}

class MarketCenterPageData {
  const MarketCenterPageData({
    required this.navigation,
    required this.marketCenter,
  });

  final MarketCenterNavigationData navigation;
  final TableSectionsSnapshot marketCenter;

  factory MarketCenterPageData.fromJson(Map<String, dynamic> json) {
    return MarketCenterPageData(
      navigation: MarketCenterNavigationData.fromJson(
        json['navigation'] as Map<String, dynamic>? ?? const {},
      ),
      marketCenter: TableSectionsSnapshot.fromJson(
        json['market_center'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class MarketCenterRepository {
  const MarketCenterRepository(this._client);

  final ApiClient _client;

  Future<MarketCenterPageData> fetchPage({String? tradeDate}) async {
    final query =
        tradeDate == null || tradeDate.isEmpty ? '' : '?trade_date=$tradeDate';
    final data = await _client.getMap('/api/v1/market-center-page$query');
    return MarketCenterPageData.fromJson(data);
  }
}
