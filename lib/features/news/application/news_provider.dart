import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/news_workspace.dart';
import '../../../shared/data/market_api_provider.dart';
import '../../../shared/data/market_api_repository.dart';

final newsPageProvider = FutureProvider<NewsWorkspaceData>((ref) async {
  final payload =
      await ref.watch(marketApiRepositoryProvider).fetchNewsWorkspacePayload();
  return NewsWorkspaceData.fromJson(payload);
});

final hotNewsProvider = FutureProvider<FeedSnapshot>((ref) async {
  final workspace = await ref.watch(newsPageProvider.future);
  return workspace.hotNews;
});

final todayHotProvider = FutureProvider<FeedSnapshot>((ref) async {
  final workspace = await ref.watch(newsPageProvider.future);
  return workspace.todayHot;
});

final fastNewsProvider = FutureProvider<FeedSnapshot>((ref) async {
  final workspace = await ref.watch(newsPageProvider.future);
  return workspace.fastNews;
});

final timelineProvider = FutureProvider<FeedSnapshot>((ref) async {
  final workspace = await ref.watch(newsPageProvider.future);
  return workspace.timeline;
});

final monthlyPatternsProvider = FutureProvider<List<MonthlyPatternData>>((ref) async {
  final workspace = await ref.watch(newsPageProvider.future);
  return workspace.monthlyPatterns;
});
