import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/ask_ai_repository.dart';

class AskAiSettingsState {
  const AskAiSettingsState({
    required this.settings,
    required this.usageStatus,
  });

  final AskAiSettings settings;
  final AskAiUsageStatus usageStatus;
}

final askAiRepositoryProvider = Provider<AskAiRepository>((ref) {
  return AskAiRepository(ref.watch(apiClientProvider));
});

final askAiContextProvider = FutureProvider<AskAiContextSnapshot>((ref) {
  return ref.watch(askAiRepositoryProvider).fetchContext();
});

final askAiSettingsStateProvider =
    FutureProvider<AskAiSettingsState>((ref) async {
  final repository = ref.watch(askAiRepositoryProvider);
  final settings = await repository.loadSettings();
  final usageStatus = await repository.loadUsageStatus(settings);
  return AskAiSettingsState(
    settings: settings,
    usageStatus: usageStatus,
  );
});

final askAiSavedAnalysesProvider =
    FutureProvider<List<AskAiSavedAnalysisEntry>>((ref) {
  return ref.watch(askAiRepositoryProvider).loadSavedAnalyses();
});

final aiServerUsageStatusProvider =
    FutureProvider<AiServerUsageStatus>((ref) {
  return ref.watch(askAiRepositoryProvider).fetchServerUsageStatus();
});
