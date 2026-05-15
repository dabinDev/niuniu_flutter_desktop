import '../../../core/network/api_client.dart';

class BoardHeightChartItemData {
  const BoardHeightChartItemData({
    required this.date,
    required this.value,
    required this.leaderName,
    required this.leaderCode,
  });

  final String date;
  final int value;
  final String? leaderName;
  final String? leaderCode;

  factory BoardHeightChartItemData.fromJson(Map<String, dynamic> json) {
    return BoardHeightChartItemData(
      date: json['date'] as String? ?? '--',
      value: (json['value'] as num?)?.toInt() ?? 0,
      leaderName: json['leader_name']?.toString(),
      leaderCode: json['leader_code']?.toString(),
    );
  }
}

class BoardHeightStockData {
  const BoardHeightStockData({
    required this.name,
    required this.code,
    required this.boardCount,
  });

  final String name;
  final String? code;
  final int? boardCount;

  factory BoardHeightStockData.fromJson(Map<String, dynamic> json) {
    return BoardHeightStockData(
      name: json['name'] as String? ?? '--',
      code: json['code']?.toString(),
      boardCount: (json['board_count'] as num?)?.toInt(),
    );
  }
}

class BoardHeightColumnData {
  const BoardHeightColumnData({
    required this.date,
    required this.stocks,
  });

  final String date;
  final List<BoardHeightStockData> stocks;

  factory BoardHeightColumnData.fromJson(Map<String, dynamic> json) {
    return BoardHeightColumnData(
      date: json['date'] as String? ?? '--',
      stocks: (json['stocks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BoardHeightStockData.fromJson)
          .toList(growable: false),
    );
  }
}

class BoardHeightSnapshot {
  const BoardHeightSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    this.previousTradeDate,
    this.nextTradeDate,
    this.availableTradeDates = const <String>[],
    required this.latestHeight,
    required this.chartItems,
    required this.columns,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String? previousTradeDate;
  final String? nextTradeDate;
  final List<String> availableTradeDates;
  final int? latestHeight;
  final List<BoardHeightChartItemData> chartItems;
  final List<BoardHeightColumnData> columns;

  factory BoardHeightSnapshot.fromJson(Map<String, dynamic> json) {
    return BoardHeightSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      previousTradeDate: json['previous_trade_date']?.toString(),
      nextTradeDate: json['next_trade_date']?.toString(),
      availableTradeDates:
          (json['available_trade_dates'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
      latestHeight: (json['latest_height'] as num?)?.toInt(),
      chartItems: (json['chart_items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BoardHeightChartItemData.fromJson)
          .toList(growable: false),
      columns: (json['columns'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BoardHeightColumnData.fromJson)
          .toList(growable: false),
    );
  }
}

class BoardHeightRepository {
  const BoardHeightRepository(this._client);

  final ApiClient _client;

  Future<BoardHeightSnapshot> fetchSnapshot({String? tradeDate}) async {
    final queryParameters = <String, String>{};
    final normalizedTradeDate = tradeDate?.trim();
    if (normalizedTradeDate != null && normalizedTradeDate.isNotEmpty) {
      queryParameters['trade_date'] = normalizedTradeDate;
    }
    final data = await _client.getMap(
      Uri(
        path: '/api/v1/board-height',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      ).toString(),
    );
    return BoardHeightSnapshot.fromJson(data);
  }
}
