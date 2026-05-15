import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/application/shell_provider.dart';
import '../data/overview_repository.dart';

final overviewProvider = FutureProvider<OverviewDashboardSnapshot>((ref) {
  final repository = ref.watch(overviewRepositoryProvider);
  return ref.watch(shellOverviewProvider.future).then(
        repository.fetchDashboardWithOverview,
      );
});
