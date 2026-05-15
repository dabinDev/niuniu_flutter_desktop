const defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

String normalizeApiBaseUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return defaultApiBaseUrl;
  }
  return trimmed;
}
