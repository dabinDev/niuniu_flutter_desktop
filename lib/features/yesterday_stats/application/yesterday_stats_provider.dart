import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/market_api_provider.dart';
import '../../../shared/data/market_api_repository.dart';

final yesterdayStatsProvider =
    FutureProvider.family<YesterdayStatsSnapshot, String?>((ref, tradeDate) {
  final normalizedTradeDate = tradeDate?.trim();
  return ref.watch(marketApiRepositoryProvider).fetchYesterdayStats(
        tradeDate: normalizedTradeDate == null || normalizedTradeDate.isEmpty
            ? null
            : normalizedTradeDate,
      );
});
