import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(apiClientProvider));
});

final reviewPageProvider = FutureProvider.family<ReviewWorkspaceData, String?>(
  (ref, tradeDate) {
    return ref.watch(reviewRepositoryProvider).fetchPage(tradeDate: tradeDate);
  },
);
