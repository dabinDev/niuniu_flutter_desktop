import '../../../core/network/api_client.dart';

class NodeQuoteData {
  const NodeQuoteData({
    required this.tradeDate,
    required this.fetchedAt,
    required this.symbol,
    required this.name,
    required this.price,
    required this.preClose,
    required this.open,
    required this.high,
    required this.low,
    required this.volume,
    required this.amount,
    required this.change,
    required this.changePct,
    required this.turnoverRate,
    required this.amplitude,
    this.dynamicPe,
    this.circulatingCap,
    this.marketCap,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String symbol;
  final String name;
  final double? price;
  final double? preClose;
  final double? open;
  final double? high;
  final double? low;
  final int? volume;
  final double? amount;
  final double? change;
  final double? changePct;
  final double? turnoverRate;
  final double? amplitude;
  final double? dynamicPe;
  final double? circulatingCap;
  final double? marketCap;

  factory NodeQuoteData.fromJson(Map<String, dynamic> json) {
    return NodeQuoteData(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      symbol: json['symbol'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      price: (json['price'] as num?)?.toDouble(),
      preClose: (json['pre_close'] as num?)?.toDouble(),
      open: (json['open'] as num?)?.toDouble(),
      high: (json['high'] as num?)?.toDouble(),
      low: (json['low'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toDouble(),
      change: (json['change'] as num?)?.toDouble(),
      changePct: (json['change_pct'] as num?)?.toDouble(),
      turnoverRate: (json['turnover_rate'] as num?)?.toDouble(),
      amplitude: (json['amplitude'] as num?)?.toDouble(),
      dynamicPe: (json['dynamic_pe'] as num?)?.toDouble(),
      circulatingCap: (json['circulating_cap'] as num?)?.toDouble(),
      marketCap: (json['market_cap'] as num?)?.toDouble(),
    );
  }
}

class NodeKlineBarData {
  const NodeKlineBarData({
    required this.tradeDate,
    required this.openPrice,
    required this.closePrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
  });

  final String tradeDate;
  final double openPrice;
  final double closePrice;
  final double highPrice;
  final double lowPrice;
  final double volume;

  factory NodeKlineBarData.fromJson(Map<String, dynamic> json) {
    return NodeKlineBarData(
      tradeDate: json['trade_date'] as String? ?? '--',
      openPrice: (json['open_price'] as num?)?.toDouble() ?? 0,
      closePrice: (json['close_price'] as num?)?.toDouble() ?? 0,
      highPrice: (json['high_price'] as num?)?.toDouble() ?? 0,
      lowPrice: (json['low_price'] as num?)?.toDouble() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
    );
  }
}

class NodeKlineData {
  const NodeKlineData({
    required this.tradeDate,
    required this.fetchedAt,
    required this.symbol,
    required this.name,
    required this.total,
    required this.bars,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String symbol;
  final String name;
  final int total;
  final List<NodeKlineBarData> bars;

  factory NodeKlineData.fromJson(Map<String, dynamic> json) {
    return NodeKlineData(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      symbol: json['symbol'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      total: (json['total'] as num?)?.toInt() ?? 0,
      bars: (json['bars'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(NodeKlineBarData.fromJson)
          .toList(growable: false),
    );
  }
}

class NodePlateData {
  const NodePlateData({
    required this.rank,
    required this.plateCode,
    required this.plateName,
    required this.ztCount,
    required this.strength,
    required this.strengthText,
  });

  final int rank;
  final String? plateCode;
  final String plateName;
  final int? ztCount;
  final double? strength;
  final String? strengthText;

  factory NodePlateData.fromJson(Map<String, dynamic> json) {
    return NodePlateData(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      plateCode: json['plate_code']?.toString(),
      plateName: json['plate_name'] as String? ?? '--',
      ztCount: (json['zt_count'] as num?)?.toInt(),
      strength: (json['strength'] as num?)?.toDouble(),
      strengthText: json['strength_text']?.toString(),
    );
  }
}

class NodeDateItemData {
  const NodeDateItemData({
    required this.date,
    required this.bar,
    required this.topPlates,
  });

  final String date;
  final NodeKlineBarData? bar;
  final List<NodePlateData> topPlates;

  factory NodeDateItemData.fromJson(Map<String, dynamic> json) {
    final barJson = json['bar'];
    return NodeDateItemData(
      date: json['date'] as String? ?? '--',
      bar: barJson is Map<String, dynamic>
          ? NodeKlineBarData.fromJson(barJson)
          : barJson is Map
              ? NodeKlineBarData.fromJson(Map<String, dynamic>.from(barJson))
              : null,
      topPlates: (json['top_plates'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(NodePlateData.fromJson)
          .toList(growable: false),
    );
  }
}

class NodeSnapshotData {
  const NodeSnapshotData({
    required this.tradeDate,
    required this.fetchedAt,
    required this.symbol,
    required this.quote,
    required this.kline,
    required this.defaultDate,
    required this.helperText,
    required this.dateItems,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String symbol;
  final NodeQuoteData quote;
  final NodeKlineData kline;
  final String? defaultDate;
  final String helperText;
  final List<NodeDateItemData> dateItems;

  factory NodeSnapshotData.fromJson(Map<String, dynamic> json) {
    return NodeSnapshotData(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      symbol: json['symbol'] as String? ?? '--',
      quote: NodeQuoteData.fromJson(
        json['quote'] as Map<String, dynamic>? ?? const {},
      ),
      kline: NodeKlineData.fromJson(
        json['kline'] as Map<String, dynamic>? ?? const {},
      ),
      defaultDate: json['default_date']?.toString(),
      helperText: json['helper_text']?.toString() ?? '点击 K 线或日期，查看指数与板块联动。',
      dateItems: (json['date_items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(NodeDateItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class NodeLeaderItemData {
  const NodeLeaderItemData({
    required this.rankNo,
    required this.stockCode,
    required this.stockName,
    required this.quote,
  });

  final int rankNo;
  final String stockCode;
  final String stockName;
  final NodeQuoteData? quote;

  factory NodeLeaderItemData.fromJson(Map<String, dynamic> json) {
    final quoteJson = json['quote'];
    return NodeLeaderItemData(
      rankNo: (json['rank_no'] as num?)?.toInt() ?? 0,
      stockCode: json['stock_code'] as String? ?? '--',
      stockName: json['stock_name'] as String? ?? '--',
      quote: quoteJson is Map<String, dynamic>
          ? NodeQuoteData.fromJson(quoteJson)
          : quoteJson is Map
              ? NodeQuoteData.fromJson(Map<String, dynamic>.from(quoteJson))
              : null,
    );
  }
}

class NodePlateLeadersData {
  const NodePlateLeadersData({
    required this.tradeDate,
    required this.fetchedAt,
    required this.quoteTradeDate,
    required this.quoteFetchedAt,
    required this.plateCode,
    required this.plateName,
    required this.date,
    required this.total,
    required this.leaders,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String? quoteTradeDate;
  final String? quoteFetchedAt;
  final String plateCode;
  final String? plateName;
  final String? date;
  final int total;
  final List<NodeLeaderItemData> leaders;

  factory NodePlateLeadersData.fromJson(Map<String, dynamic> json) {
    return NodePlateLeadersData(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      quoteTradeDate: json['quote_trade_date']?.toString(),
      quoteFetchedAt: json['quote_fetched_at']?.toString(),
      plateCode: json['plate_code'] as String? ?? '--',
      plateName: json['plate_name']?.toString(),
      date: json['date']?.toString(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      leaders: (json['leaders'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(NodeLeaderItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class NodeRepository {
  const NodeRepository(this._client);

  final ApiClient _client;

  Future<NodeSnapshotData> fetchSnapshot({
    required String symbol,
    int days = 21,
    int plateLimit = 5,
  }) async {
    final data = await _client.getMap(
      '/api/v1/node/snapshot?symbol=$symbol&days=$days&plate_limit=$plateLimit',
    );
    return NodeSnapshotData.fromJson(data);
  }

  Future<NodePlateLeadersData> fetchPlateLeaders({
    required String plateCode,
    required String date,
    int stockLimit = 10,
  }) async {
    final data = await _client.getMap(
      '/api/v1/node/plates/$plateCode/leaders?date=$date&stock_limit=$stockLimit',
    );
    return NodePlateLeadersData.fromJson(data);
  }
}
