import '../../../core/network/api_client.dart';

class PlateRotationPointData {
  const PlateRotationPointData({
    required this.date,
    required this.ztCount,
    required this.strength,
    required this.strengthText,
  });

  final String date;
  final int? ztCount;
  final double? strength;
  final String? strengthText;

  factory PlateRotationPointData.fromJson(Map<String, dynamic> json) {
    return PlateRotationPointData(
      date: json['date'] as String? ?? '--',
      ztCount: (json['zt_count'] as num?)?.toInt(),
      strength: (json['strength'] as num?)?.toDouble(),
      strengthText: json['strength_text']?.toString(),
    );
  }
}

class PlateRotationItemData {
  const PlateRotationItemData({
    required this.plateName,
    required this.plateCode,
    required this.latestZt,
    required this.latestStrengthText,
    required this.series,
  });

  final String plateName;
  final String? plateCode;
  final int? latestZt;
  final String? latestStrengthText;
  final List<PlateRotationPointData> series;

  factory PlateRotationItemData.fromJson(Map<String, dynamic> json) {
    return PlateRotationItemData(
      plateName: json['plate_name'] as String? ?? '--',
      plateCode: json['plate_code']?.toString(),
      latestZt: (json['latest_zt'] as num?)?.toInt(),
      latestStrengthText: json['latest_strength_text']?.toString(),
      series: (json['series'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateRotationPointData.fromJson)
          .toList(growable: false),
    );
  }
}

class PlateRotationMatrixCellData {
  const PlateRotationMatrixCellData({
    required this.rank,
    required this.plateName,
    required this.plateCode,
    required this.ztCount,
    required this.strength,
    required this.strengthText,
  });

  final int rank;
  final String plateName;
  final String? plateCode;
  final int? ztCount;
  final double? strength;
  final String? strengthText;

  factory PlateRotationMatrixCellData.fromJson(Map<String, dynamic> json) {
    return PlateRotationMatrixCellData(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      plateName: json['plate_name'] as String? ?? '--',
      plateCode: json['plate_code']?.toString(),
      ztCount: (json['zt_count'] as num?)?.toInt(),
      strength: (json['strength'] as num?)?.toDouble(),
      strengthText: json['strength_text']?.toString(),
    );
  }
}

class PlateRotationMatrixColumnData {
  const PlateRotationMatrixColumnData({
    required this.date,
    required this.items,
  });

  final String date;
  final List<PlateRotationMatrixCellData> items;

  factory PlateRotationMatrixColumnData.fromJson(Map<String, dynamic> json) {
    return PlateRotationMatrixColumnData(
      date: json['date'] as String? ?? '--',
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateRotationMatrixCellData.fromJson)
          .toList(growable: false),
    );
  }
}

class PlateRotationLeaderPreviewData {
  const PlateRotationLeaderPreviewData({
    required this.stockCode,
    required this.stockName,
    required this.rankNo,
  });

  final String stockCode;
  final String stockName;
  final int rankNo;

  factory PlateRotationLeaderPreviewData.fromJson(Map<String, dynamic> json) {
    return PlateRotationLeaderPreviewData(
      stockCode: json['stock_code'] as String? ?? '--',
      stockName: json['stock_name'] as String? ?? '--',
      rankNo: (json['rank_no'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlateRotationDateSummaryData {
  const PlateRotationDateSummaryData({
    required this.date,
    required this.plateName,
    required this.plateCode,
    required this.rank,
    required this.ztCount,
    required this.strength,
    required this.strengthText,
    required this.latestZt,
    required this.latestStrengthText,
    required this.isMatrixTop,
    required this.leaderTotal,
    required this.leadersPreview,
  });

  final String date;
  final String plateName;
  final String? plateCode;
  final int? rank;
  final int? ztCount;
  final double? strength;
  final String? strengthText;
  final int? latestZt;
  final String? latestStrengthText;
  final bool isMatrixTop;
  final int leaderTotal;
  final List<PlateRotationLeaderPreviewData> leadersPreview;

  factory PlateRotationDateSummaryData.fromJson(Map<String, dynamic> json) {
    return PlateRotationDateSummaryData(
      date: json['date'] as String? ?? '--',
      plateName: json['plate_name'] as String? ?? '--',
      plateCode: json['plate_code']?.toString(),
      rank: (json['rank'] as num?)?.toInt(),
      ztCount: (json['zt_count'] as num?)?.toInt(),
      strength: (json['strength'] as num?)?.toDouble(),
      strengthText: json['strength_text']?.toString(),
      latestZt: (json['latest_zt'] as num?)?.toInt(),
      latestStrengthText: json['latest_strength_text']?.toString(),
      isMatrixTop: json['is_matrix_top'] == true,
      leaderTotal: (json['leader_total'] as num?)?.toInt() ?? 0,
      leadersPreview: (json['leaders_preview'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateRotationLeaderPreviewData.fromJson)
          .toList(growable: false),
    );
  }
}

class PlateRotationSnapshot {
  const PlateRotationSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    this.previousTradeDate,
    this.nextTradeDate,
    this.availableTradeDates = const <String>[],
    required this.dates,
    required this.total,
    required this.items,
    this.matrixColumns = const <PlateRotationMatrixColumnData>[],
    this.plateDateSummaries = const <PlateRotationDateSummaryData>[],
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String? previousTradeDate;
  final String? nextTradeDate;
  final List<String> availableTradeDates;
  final List<String> dates;
  final int total;
  final List<PlateRotationItemData> items;
  final List<PlateRotationMatrixColumnData> matrixColumns;
  final List<PlateRotationDateSummaryData> plateDateSummaries;

  factory PlateRotationSnapshot.fromJson(Map<String, dynamic> json) {
    return PlateRotationSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      previousTradeDate: json['previous_trade_date']?.toString(),
      nextTradeDate: json['next_trade_date']?.toString(),
      availableTradeDates:
          (json['available_trade_dates'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
      dates: (json['dates'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateRotationItemData.fromJson)
          .toList(growable: false),
      matrixColumns: (json['matrix_columns'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateRotationMatrixColumnData.fromJson)
          .toList(growable: false),
      plateDateSummaries:
          (json['plate_date_summaries'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(PlateRotationDateSummaryData.fromJson)
              .toList(growable: false),
    );
  }
}

class PlateStockItemData {
  const PlateStockItemData({
    required this.stockCode,
    required this.stockName,
    required this.rankNo,
  });

  final String stockCode;
  final String stockName;
  final int rankNo;

  factory PlateStockItemData.fromJson(Map<String, dynamic> json) {
    return PlateStockItemData(
      stockCode: json['stock_code'] as String? ?? '--',
      stockName: json['stock_name'] as String? ?? '--',
      rankNo: (json['rank_no'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlateStockDateGroupData {
  const PlateStockDateGroupData({
    required this.date,
    required this.total,
    required this.stocks,
  });

  final String date;
  final int total;
  final List<PlateStockItemData> stocks;

  factory PlateStockDateGroupData.fromJson(Map<String, dynamic> json) {
    return PlateStockDateGroupData(
      date: json['date'] as String? ?? '--',
      total: (json['total'] as num?)?.toInt() ?? 0,
      stocks: (json['stocks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateStockItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class PlateStocksSnapshot {
  const PlateStocksSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    required this.plateCode,
    required this.plateName,
    required this.dates,
    required this.items,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String plateCode;
  final String? plateName;
  final List<String> dates;
  final List<PlateStockDateGroupData> items;

  factory PlateStocksSnapshot.fromJson(Map<String, dynamic> json) {
    return PlateStocksSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      plateCode: json['plate_code'] as String? ?? '--',
      plateName: json['plate_name']?.toString(),
      dates: (json['dates'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateStockDateGroupData.fromJson)
          .toList(growable: false),
    );
  }
}

class PlateLeaderQuoteData {
  const PlateLeaderQuoteData({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct,
    required this.open,
    required this.amplitude,
    required this.amount,
    this.dynamicPe,
    this.circulatingCap,
    this.marketCap,
  });

  final String symbol;
  final String name;
  final double? price;
  final double? changePct;
  final double? open;
  final double? amplitude;
  final double? amount;
  final double? dynamicPe;
  final double? circulatingCap;
  final double? marketCap;

  factory PlateLeaderQuoteData.fromJson(Map<String, dynamic> json) {
    return PlateLeaderQuoteData(
      symbol: json['symbol'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      price: (json['price'] as num?)?.toDouble(),
      changePct: (json['change_pct'] as num?)?.toDouble(),
      open: (json['open'] as num?)?.toDouble(),
      amplitude: (json['amplitude'] as num?)?.toDouble(),
      amount: (json['amount'] as num?)?.toDouble(),
      dynamicPe: (json['dynamic_pe'] as num?)?.toDouble(),
      circulatingCap: (json['circulating_cap'] as num?)?.toDouble(),
      marketCap: (json['market_cap'] as num?)?.toDouble(),
    );
  }
}

class PlateLeaderQuoteItemData {
  const PlateLeaderQuoteItemData({
    required this.rankNo,
    required this.stockCode,
    required this.stockName,
    required this.quote,
  });

  final int rankNo;
  final String stockCode;
  final String stockName;
  final PlateLeaderQuoteData? quote;

  factory PlateLeaderQuoteItemData.fromJson(Map<String, dynamic> json) {
    final quoteJson = json['quote'];
    return PlateLeaderQuoteItemData(
      rankNo: (json['rank_no'] as num?)?.toInt() ?? 0,
      stockCode: json['stock_code'] as String? ?? '--',
      stockName: json['stock_name'] as String? ?? '--',
      quote: quoteJson is Map<String, dynamic>
          ? PlateLeaderQuoteData.fromJson(quoteJson)
          : quoteJson is Map
              ? PlateLeaderQuoteData.fromJson(
                  Map<String, dynamic>.from(quoteJson))
              : null,
    );
  }
}

class PlateLeaderQuotesSnapshot {
  const PlateLeaderQuotesSnapshot({
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
  final List<PlateLeaderQuoteItemData> leaders;

  factory PlateLeaderQuotesSnapshot.fromJson(Map<String, dynamic> json) {
    return PlateLeaderQuotesSnapshot(
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
          .map(PlateLeaderQuoteItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class PlateRotationRepository {
  const PlateRotationRepository(this._client);

  final ApiClient _client;

  Future<PlateRotationSnapshot> fetchRotation({
    String? tradeDate,
    int limit = 100,
  }) async {
    final queryParameters = <String, String>{
      'limit': '$limit',
    };
    final normalizedTradeDate = tradeDate?.trim();
    if (normalizedTradeDate != null && normalizedTradeDate.isNotEmpty) {
      queryParameters['trade_date'] = normalizedTradeDate;
    }
    final data = await _client.getMap(
      Uri(
        path: '/api/v1/plate-rotation',
        queryParameters: queryParameters,
      ).toString(),
    );
    return PlateRotationSnapshot.fromJson(data);
  }

  Future<PlateStocksSnapshot> fetchPlateStocks(
    String plateCode, {
    int limit = 12,
  }) async {
    final data =
        await _client.getMap('/api/v1/plates/$plateCode/stocks?limit=$limit');
    return PlateStocksSnapshot.fromJson(data);
  }

  Future<PlateLeaderQuotesSnapshot> fetchDateLeaders({
    required String plateCode,
    required String date,
    int stockLimit = 10,
  }) async {
    final data = await _client.getMap(
      '/api/v1/node/plates/$plateCode/leaders?date=$date&stock_limit=$stockLimit',
    );
    return PlateLeaderQuotesSnapshot.fromJson(data);
  }
}
