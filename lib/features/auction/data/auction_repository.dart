import '../../../core/network/api_client.dart';
import '../../ask_ai/data/ask_ai_repository.dart';
import '../../../shared/data/ai_analysis_data.dart';

class AuctionColumnItemData {
  const AuctionColumnItemData({
    required this.code,
    required this.name,
    required this.concepts,
    required this.lianban,
    required this.amounts,
    required this.zhangfu,
  });

  final String code;
  final String name;
  final List<String> concepts;
  final String lianban;
  final List<String> amounts;
  final String zhangfu;

  factory AuctionColumnItemData.fromJson(Map<String, dynamic> json) {
    return AuctionColumnItemData(
      code: json['code'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      concepts: (json['concepts'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      lianban: json['lianban'] as String? ?? '',
      amounts: (json['amounts'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      zhangfu: json['zhangfu'] as String? ?? '',
    );
  }
}

class AuctionHistoryColumnData {
  const AuctionHistoryColumnData({
    required this.tradeDate,
    required this.fetchedAt,
    required this.title,
    required this.tradeLabel,
    required this.yiziCount,
    required this.sealAmount,
    required this.timeLabels,
    required this.isLive,
    required this.total,
    required this.items,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String? title;
  final String? tradeLabel;
  final int? yiziCount;
  final String? sealAmount;
  final List<String> timeLabels;
  final bool isLive;
  final int total;
  final List<AuctionColumnItemData> items;

  factory AuctionHistoryColumnData.fromJson(Map<String, dynamic> json) {
    return AuctionHistoryColumnData(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      title: json['title']?.toString(),
      tradeLabel: json['trade_label']?.toString(),
      yiziCount: (json['yizi_count'] as num?)?.toInt(),
      sealAmount: json['seal_amount']?.toString(),
      timeLabels: (json['time_labels'] as List<dynamic>? ??
              const [
                '9:15',
                '9:20',
                '9:25',
                '涨幅',
              ])
          .map((item) => item.toString())
          .toList(growable: false),
      isLive: json['is_live'] as bool? ?? false,
      total: (json['total'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AuctionColumnItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class AuctionRankItemData {
  const AuctionRankItemData({
    required this.code,
    required this.name,
    required this.cells,
    this.bidChangePct,
    this.currentChangePct,
    this.bidAmountWan,
    this.previousAmountWan,
    this.entrustAmountYuan,
    this.matchAmountYuan,
    this.sealAmountWan,
    this.boardCount,
    this.boardText,
    this.boardDesc,
    this.ratioPct,
    this.volumeRatio,
    this.grabPct,
    this.netAmountWan,
    this.floatMarketCapYi,
    this.price,
    this.concept,
    this.yesterdayChangePct,
    this.action,
  });

  final String code;
  final String name;
  final List<String> cells;
  final double? bidChangePct;
  final double? currentChangePct;
  final double? bidAmountWan;
  final double? previousAmountWan;
  final double? entrustAmountYuan;
  final double? matchAmountYuan;
  final double? sealAmountWan;
  final int? boardCount;
  final String? boardText;
  final String? boardDesc;
  final double? ratioPct;
  final double? volumeRatio;
  final double? grabPct;
  final double? netAmountWan;
  final double? floatMarketCapYi;
  final double? price;
  final String? concept;
  final double? yesterdayChangePct;
  final String? action;

  factory AuctionRankItemData.fromJson(Map<String, dynamic> json) {
    return AuctionRankItemData(
      code: json['code'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      cells: (json['cells'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      bidChangePct: _readDouble(json['bid_change_pct']),
      currentChangePct: _readDouble(json['current_change_pct']),
      bidAmountWan: _readDouble(json['bid_amount_wan']),
      previousAmountWan: _readDouble(json['previous_amount_wan']),
      entrustAmountYuan: _readDouble(json['entrust_amount_yuan']),
      matchAmountYuan: _readDouble(json['match_amount_yuan']),
      sealAmountWan: _readDouble(json['seal_amount_wan']),
      boardCount: _readInt(json['board_count']),
      boardText: _readString(json['board_text']),
      boardDesc: _readString(json['board_desc']),
      ratioPct: _readDouble(json['ratio_pct']),
      volumeRatio: _readDouble(json['volume_ratio']),
      grabPct: _readDouble(json['grab_pct']),
      netAmountWan: _readDouble(json['net_amount_wan']),
      floatMarketCapYi: _readDouble(json['float_market_cap_yi']),
      price: _readDouble(json['price']),
      concept: _readString(json['concept']),
      yesterdayChangePct: _readDouble(json['yesterday_change_pct']),
      action: _readString(json['action']),
    );
  }
}

class AuctionRankSectionData {
  const AuctionRankSectionData({
    required this.key,
    required this.title,
    required this.tabLabel,
    required this.columns,
    required this.total,
    required this.items,
  });

  final String key;
  final String title;
  final String tabLabel;
  final List<String> columns;
  final int total;
  final List<AuctionRankItemData> items;

  factory AuctionRankSectionData.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AuctionRankItemData.fromJson)
        .toList(growable: false);
    return AuctionRankSectionData(
      key: json['key'] as String? ?? '--',
      title: json['title'] as String? ?? '--',
      tabLabel: json['tab_label'] as String? ?? '--',
      columns: (json['columns'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }
}

class AuctionPageData {
  const AuctionPageData({
    required this.tradeDate,
    required this.fetchedAt,
    required this.historyColumns,
    required this.rankSections,
    this.aiAnalysis = const AiAnalysisStateData(
      source: 'auction_ai',
      tradeDate: null,
      enabled: false,
      reason: '',
      provider: 'kimi',
      model: '',
      generatedAt: null,
      analysis: '',
      cached: false,
    ),
  });

  final String? tradeDate;
  final String? fetchedAt;
  final List<AuctionHistoryColumnData> historyColumns;
  final List<AuctionRankSectionData> rankSections;
  final AiAnalysisStateData aiAnalysis;

  factory AuctionPageData.fromJson(Map<String, dynamic> json) {
    return AuctionPageData(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      historyColumns: (json['history_columns'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AuctionHistoryColumnData.fromJson)
          .toList(growable: false),
      rankSections: (json['rank_sections'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AuctionRankSectionData.fromJson)
          .toList(growable: false),
      aiAnalysis: AiAnalysisStateData.fromJson(
        json['ai_analysis'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

double? _readDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString().replaceAll('%', '').trim());
}

int? _readInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  final parsedInt = int.tryParse(value.toString().trim());
  if (parsedInt != null) {
    return parsedInt;
  }
  return double.tryParse(value.toString().trim())?.toInt();
}

String? _readString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty || text == '--' ? null : text;
}

class AuctionRepository {
  const AuctionRepository(this._client);

  final ApiClient _client;

  Future<AuctionPageData> fetchAuctionPageData({
    int days = 5,
    int stockLimit = 80,
    int rankLimit = 150,
  }) async {
    final data = await _client.getMap(
      '/api/v1/auction/page?days=$days&stock_limit=$stockLimit&rank_limit=$rankLimit',
    );
    return AuctionPageData.fromJson(data);
  }

  Future<AiAnalysisStateData> generateAiAnalysis() async {
    final askAiRepository = AskAiRepository(_client);
    final settings = await askAiRepository.loadSettings();
    try {
      final data = await _client.postMap(
        '/api/v1/auction/ai-analysis',
        receiveTimeout: const Duration(minutes: 4),
        data: {
          'client_config': await askAiRepository.buildClientConfigPayload(
            settings,
          ),
        },
      );
      return AiAnalysisStateData.fromJson(data);
    } catch (error) {
      throw StateError(_normalizeAuctionAiError(error));
    }
  }
}

String _normalizeAuctionAiError(Object error) {
  final message = error.toString();
  if (message.contains('429') || message.contains('超过当日免费使用限制')) {
    return '今日 AI 使用次数已用完，请明天再试或配置个人 Kimi Key。';
  }
  return message.replaceFirst(RegExp(r'^(Bad state: |Exception: )'), '').trim();
}
