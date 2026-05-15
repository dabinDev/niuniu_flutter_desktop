import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auction_repository.dart';

final auctionRepositoryProvider = Provider<AuctionRepository>((ref) {
  return AuctionRepository(ref.watch(apiClientProvider));
});

final auctionPageProvider = FutureProvider<AuctionPageData>((ref) {
  return ref.watch(auctionRepositoryProvider).fetchAuctionPageData();
});
