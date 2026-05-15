import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/board_height_repository.dart';

final boardHeightRepositoryProvider = Provider<BoardHeightRepository>((ref) {
  return BoardHeightRepository(ref.watch(apiClientProvider));
});

final boardHeightProvider =
    FutureProvider.family<BoardHeightSnapshot, String?>((ref, tradeDate) {
      final normalizedTradeDate = tradeDate?.trim();
      return ref.watch(boardHeightRepositoryProvider).fetchSnapshot(
            tradeDate: normalizedTradeDate == null || normalizedTradeDate.isEmpty
                ? null
                : normalizedTradeDate,
          );
    });
