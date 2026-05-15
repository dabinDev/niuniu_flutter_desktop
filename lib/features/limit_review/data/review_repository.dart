import '../../../core/network/api_client.dart';
import '../../ask_ai/data/ask_ai_repository.dart';
import '../../../shared/data/ai_analysis_data.dart';
import '../../../shared/data/market_api_repository.dart';

class TradeDateNavigationData {
  const TradeDateNavigationData({
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

  factory TradeDateNavigationData.fromJson(Map<String, dynamic> json) {
    return TradeDateNavigationData(
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

class ReviewWorkspaceData {
  const ReviewWorkspaceData({
    required this.navigation,
    required this.limitReview,
    required this.boardHeight,
    required this.yesterdayStats,
    this.aiReview = const AiAnalysisStateData(
      source: 'limit_review_ai',
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

  final TradeDateNavigationData navigation;
  final LimitReviewSnapshot limitReview;
  final BoardHeightSnapshot boardHeight;
  final YesterdayStatsSnapshot yesterdayStats;
  final AiAnalysisStateData aiReview;

  factory ReviewWorkspaceData.fromJson(Map<String, dynamic> json) {
    return ReviewWorkspaceData(
      navigation: TradeDateNavigationData.fromJson(
        json['navigation'] as Map<String, dynamic>? ?? const {},
      ),
      limitReview: LimitReviewSnapshot.fromJson(
        json['limit_review'] as Map<String, dynamic>? ?? const {},
      ),
      boardHeight: BoardHeightSnapshot.fromJson(
        json['board_height'] as Map<String, dynamic>? ?? const {},
      ),
      yesterdayStats: YesterdayStatsSnapshot.fromJson(
        json['yesterday_stats'] as Map<String, dynamic>? ?? const {},
      ),
      aiReview: AiAnalysisStateData.fromJson(
        json['ai_review'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class ReviewRepository {
  const ReviewRepository(this._client);

  final ApiClient _client;

  Future<ReviewWorkspaceData> fetchPage({
    String? tradeDate,
    int weaknessLimit = 16,
  }) async {
    final query = <String>[
      if (tradeDate != null && tradeDate.isNotEmpty) 'trade_date=$tradeDate',
      'weakness_limit=$weaknessLimit',
    ].join('&');
    final data = await _client.getMap('/api/v1/review-page?$query');
    return ReviewWorkspaceData.fromJson(data);
  }

  Future<AiAnalysisStateData> generateAiReview({
    String? tradeDate,
  }) async {
    final query =
        tradeDate == null || tradeDate.isEmpty ? '' : '?trade_date=$tradeDate';
    final askAiRepository = AskAiRepository(_client);
    final settings = await askAiRepository.loadSettings();
    final data = await _client.postMap(
      '/api/v1/limit-review/ai-review$query',
      receiveTimeout: const Duration(minutes: 4),
      data: {
        'client_config': await askAiRepository.buildClientConfigPayload(
          settings,
        ),
      },
    );
    return AiAnalysisStateData.fromJson(data);
  }
}
