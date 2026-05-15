import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/jobs_repository.dart';

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(ref.watch(apiClientProvider));
});

final jobsProvider = FutureProvider<JobPageSnapshot>((ref) {
  return ref.watch(jobsRepositoryProvider).fetchPage();
});
