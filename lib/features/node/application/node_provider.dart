import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/node_repository.dart';

final nodeSymbolProvider = StateProvider<String>((ref) => 'sz399001');

final nodeRepositoryProvider = Provider<NodeRepository>((ref) {
  return NodeRepository(ref.watch(apiClientProvider));
});

final nodePageProvider = FutureProvider<NodeSnapshotData>((ref) {
  final symbol = ref.watch(nodeSymbolProvider);
  return ref.watch(nodeRepositoryProvider).fetchSnapshot(symbol: symbol);
});

final nodeLeadersProvider = FutureProvider.family<NodePlateLeadersData,
    ({String plateCode, String date, int stockLimit})>((ref, request) {
  return ref.watch(nodeRepositoryProvider).fetchPlateLeaders(
        plateCode: request.plateCode,
        date: request.date,
        stockLimit: request.stockLimit,
      );
});
