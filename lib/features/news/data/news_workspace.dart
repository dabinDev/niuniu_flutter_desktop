import '../../../shared/data/market_api_repository.dart';

class NewsWorkspaceData {
  const NewsWorkspaceData({
    required this.hotNews,
    required this.todayHot,
    required this.fastNews,
    required this.timeline,
    required this.monthlyPatterns,
  });

  final FeedSnapshot hotNews;
  final FeedSnapshot todayHot;
  final FeedSnapshot fastNews;
  final FeedSnapshot timeline;
  final List<MonthlyPatternData> monthlyPatterns;

  factory NewsWorkspaceData.fromJson(Map<String, dynamic> json) {
    final monthlyPatterns = (json['monthly_patterns'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MonthlyPatternData.fromJson)
        .toList(growable: false);

    return NewsWorkspaceData(
      hotNews: FeedSnapshot.fromJson(
        json['hot_news'] as Map<String, dynamic>? ?? const {},
      ),
      todayHot: FeedSnapshot.fromJson(
        json['today_hot'] as Map<String, dynamic>? ?? const {},
      ),
      fastNews: FeedSnapshot.fromJson(
        json['fast_news'] as Map<String, dynamic>? ?? const {},
      ),
      timeline: FeedSnapshot.fromJson(
        json['timeline'] as Map<String, dynamic>? ?? const {},
      ),
      monthlyPatterns: monthlyPatterns,
    );
  }

  String? get latestUpdatedAt {
    for (final value in <String?>[
      hotNews.fetchedAt,
      todayHot.fetchedAt,
      fastNews.fetchedAt,
      timeline.fetchedAt,
    ]) {
      if ((value ?? '').isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  int get totalSignals =>
      hotNews.total + todayHot.total + fastNews.total + timeline.total;

  int get importantFastNewsCount =>
      fastNews.items.where((item) => item.isImportant).length;
}
