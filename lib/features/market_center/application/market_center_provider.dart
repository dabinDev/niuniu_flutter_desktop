import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/market_center_repository.dart';

final marketCenterRepositoryProvider = Provider<MarketCenterRepository>((ref) {
  return MarketCenterRepository(ref.watch(apiClientProvider));
});

final marketCenterProvider =
    FutureProvider.family<MarketCenterPageData, String?>(
  (ref, tradeDate) {
    return ref.watch(marketCenterRepositoryProvider).fetchPage(
          tradeDate: tradeDate,
        );
  },
);
