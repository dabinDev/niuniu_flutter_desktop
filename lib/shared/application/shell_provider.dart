import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../features/overview/data/overview_repository.dart';

final overviewRepositoryProvider = Provider<OverviewRepository>((ref) {
  return OverviewRepository(ref.watch(apiClientProvider));
});

final shellOverviewProvider = FutureProvider<OverviewSnapshot>((ref) {
  return ref.watch(overviewRepositoryProvider).fetchShell();
});
