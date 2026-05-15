import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'market_api_repository.dart';

final marketApiRepositoryProvider = Provider<MarketApiRepository>((ref) {
  return MarketApiRepository(ref.watch(apiClientProvider));
});
