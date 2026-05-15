import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/plate_rotation_repository.dart';

final plateRotationRepositoryProvider =
    Provider<PlateRotationRepository>((ref) {
  return PlateRotationRepository(ref.watch(apiClientProvider));
});

final plateRotationProvider =
    FutureProvider.family<PlateRotationSnapshot, ({int limit, String? tradeDate})>(
        (ref, request) {
  final normalizedTradeDate = request.tradeDate?.trim();
  return ref.watch(plateRotationRepositoryProvider).fetchRotation(
        limit: request.limit,
        tradeDate: normalizedTradeDate == null || normalizedTradeDate.isEmpty
            ? null
            : normalizedTradeDate,
      );
});

final plateRotationPlateStocksProvider =
    FutureProvider.family<PlateStocksSnapshot, ({String plateCode, int limit})>(
        (ref, request) {
  return ref.watch(plateRotationRepositoryProvider).fetchPlateStocks(
        request.plateCode,
        limit: request.limit,
      );
});

final plateRotationDateLeadersProvider = FutureProvider.family<
    PlateLeaderQuotesSnapshot,
    ({String plateCode, String date, int stockLimit})>((ref, request) {
  return ref.watch(plateRotationRepositoryProvider).fetchDateLeaders(
        plateCode: request.plateCode,
        date: request.date,
        stockLimit: request.stockLimit,
      );
});
