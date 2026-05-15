import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/market_api_provider.dart';
import '../../../shared/data/market_api_repository.dart';

final boardTierProvider =
    FutureProvider.family<BoardTierSnapshot, String?>((ref, tradeDate) {
      final normalizedTradeDate = tradeDate?.trim();
      return ref.watch(marketApiRepositoryProvider).fetchBoardTier(
            tradeDate: normalizedTradeDate == null || normalizedTradeDate.isEmpty
                ? null
                : normalizedTradeDate,
          );
    });
