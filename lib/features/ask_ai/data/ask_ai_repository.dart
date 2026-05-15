import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';

enum AskAiProviderPreset {
  backend,
}

extension AskAiProviderPresetX on AskAiProviderPreset {
  String get storageValue => switch (this) {
        AskAiProviderPreset.backend => 'backend',
      };

  String get label => switch (this) {
        AskAiProviderPreset.backend => 'Kimi AI 服务',
      };

  String get defaultModel => switch (this) {
        AskAiProviderPreset.backend => '',
      };

  int get recommendedDailyLimit => switch (this) {
        AskAiProviderPreset.backend => 0,
      };
}

AskAiProviderPreset parseAskAiProviderPreset(String? value) {
  // Legacy values such as "openai", "kimi" and "custom" now all resolve to
  // the server-side AI service. The Flutter client must not own model secrets.
  return AskAiProviderPreset.backend;
}

class AskAiContextCardData {
  const AskAiContextCardData({
    required this.key,
    required this.label,
    required this.value,
    required this.tone,
  });

  final String key;
  final String label;
  final String value;
  final String tone;

  factory AskAiContextCardData.fromJson(Map<String, dynamic> json) {
    return AskAiContextCardData(
      key: json['key'] as String? ?? '--',
      label: json['label'] as String? ?? '--',
      value: json['value'] as String? ?? '--',
      tone: json['tone'] as String? ?? 'neutral',
    );
  }
}

class AskAiPromptSectionData {
  const AskAiPromptSectionData({
    required this.key,
    required this.title,
    required this.content,
  });

  final String key;
  final String title;
  final String content;

  factory AskAiPromptSectionData.fromJson(Map<String, dynamic> json) {
    return AskAiPromptSectionData(
      key: json['key'] as String? ?? '--',
      title: json['title'] as String? ?? '--',
      content: json['content'] as String? ?? '--',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'title': title,
      'content': content,
    };
  }
}

class AskAiContextSnapshot {
  const AskAiContextSnapshot({
    required this.tradeDate,
    required this.generatedAt,
    required this.cards,
    required this.promptSections,
    required this.systemPrompt,
    required this.userPrompt,
  });

  final String? tradeDate;
  final String? generatedAt;
  final List<AskAiContextCardData> cards;
  final List<AskAiPromptSectionData> promptSections;
  final String systemPrompt;
  final String userPrompt;

  factory AskAiContextSnapshot.fromJson(Map<String, dynamic> json) {
    return AskAiContextSnapshot(
      tradeDate: json['trade_date']?.toString(),
      generatedAt: json['generated_at']?.toString(),
      cards: (json['cards'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AskAiContextCardData.fromJson)
          .toList(growable: false),
      promptSections: (json['prompt_sections'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AskAiPromptSectionData.fromJson)
          .toList(growable: false),
      systemPrompt: json['system_prompt'] as String? ?? '',
      userPrompt: json['user_prompt'] as String? ?? '',
    );
  }
}

class AskAiSettings {
  const AskAiSettings({
    required this.providerPreset,
    required this.model,
    required this.dailyLimit,
    required this.apiKey,
  });

  final AskAiProviderPreset providerPreset;
  final String model;
  final int dailyLimit;
  final String apiKey;

  factory AskAiSettings.defaults() {
    return AskAiSettings(
      providerPreset: AskAiProviderPreset.backend,
      model: AskAiProviderPreset.backend.defaultModel,
      dailyLimit: AskAiProviderPreset.backend.recommendedDailyLimit,
      apiKey: '',
    );
  }

  AskAiSettings copyWith({
    AskAiProviderPreset? providerPreset,
    String? model,
    int? dailyLimit,
    String? apiKey,
  }) {
    return AskAiSettings(
      providerPreset: providerPreset ?? this.providerPreset,
      model: model ?? this.model,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  bool get hasPersonalApiKey => apiKey.trim().isNotEmpty;
}

class AskAiUsageStatus {
  const AskAiUsageStatus({
    required this.providerLabel,
    required this.usedToday,
    required this.dailyLimit,
  });

  final String providerLabel;
  final int usedToday;
  final int dailyLimit;

  bool get isUnlimited => dailyLimit <= 0;

  int get remaining =>
      isUnlimited ? 999 : (dailyLimit - usedToday).clamp(0, 999);

  bool get canSend => isUnlimited || usedToday < dailyLimit;

  String get summaryText => isUnlimited
      ? '$providerLabel · 今日 $usedToday 次'
      : '$providerLabel · 今日 $usedToday/$dailyLimit 次';

  String get detailText => isUnlimited
      ? '$providerLabel 未设置本地日上限，今日已用 $usedToday 次。'
      : '$providerLabel 本地日上限 $dailyLimit 次，已用 $usedToday 次，剩余 $remaining 次。';
}

class AiFeatureUsageInfo {
  const AiFeatureUsageInfo({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  final int used;
  final int limit;
  final int remaining;

  bool get canSend => remaining > 0;

  factory AiFeatureUsageInfo.fromJson(Map<String, dynamic> json) {
    return AiFeatureUsageInfo(
      used: json['used'] as int? ?? 0,
      limit: json['limit'] as int? ?? 0,
      remaining: json['remaining'] as int? ?? 0,
    );
  }
}

class AiServerUsageStatus {
  const AiServerUsageStatus({
    required this.clientId,
    required this.hasOwnKey,
    required this.tradeDate,
    required this.features,
  });

  final String clientId;
  final bool hasOwnKey;
  final String tradeDate;
  final Map<String, AiFeatureUsageInfo> features;

  AiFeatureUsageInfo? feature(String name) => features[name];

  factory AiServerUsageStatus.fromJson(Map<String, dynamic> json) {
    final featuresRaw = json['features'] as Map<String, dynamic>? ?? {};
    final features = <String, AiFeatureUsageInfo>{};
    for (final entry in featuresRaw.entries) {
      if (entry.value is Map<String, dynamic>) {
        features[entry.key] =
            AiFeatureUsageInfo.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return AiServerUsageStatus(
      clientId: json['client_id'] as String? ?? '',
      hasOwnKey: json['has_own_key'] as bool? ?? false,
      tradeDate: json['trade_date'] as String? ?? '',
      features: features,
    );
  }
}

class AskAiSavedAnalysisEntry {
  const AskAiSavedAnalysisEntry({
    required this.sessionId,
    required this.tradeDate,
    required this.savedAt,
    required this.systemPrompt,
    required this.promptSections,
    required this.userPrompt,
    required this.result,
    required this.source,
  });

  final int? sessionId;
  final String tradeDate;
  final String savedAt;
  final String systemPrompt;
  final List<AskAiPromptSectionData> promptSections;
  final String userPrompt;
  final String result;
  final String source;

  factory AskAiSavedAnalysisEntry.fromJson(Map<String, dynamic> json) {
    return AskAiSavedAnalysisEntry(
      sessionId: _tryParseInt(json['session_id']),
      tradeDate: json['trade_date'] as String? ?? '',
      savedAt: json['saved_at'] as String? ?? '',
      systemPrompt: json['system_prompt'] as String? ?? '',
      promptSections: (json['prompt_sections'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AskAiPromptSectionData.fromJson)
          .toList(growable: false),
      userPrompt: json['user_prompt'] as String? ?? '',
      result: json['result'] as String? ?? '',
      source: json['source'] as String? ?? 'flutter',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (sessionId != null) 'session_id': sessionId,
      'trade_date': tradeDate,
      'saved_at': savedAt,
      'system_prompt': systemPrompt,
      'prompt_sections': promptSections
          .map((section) => section.toJson())
          .toList(growable: false),
      'user_prompt': userPrompt,
      'result': result,
      'source': source,
    };
  }

  AskAiSavedAnalysisEntry copyWith({
    int? sessionId,
    String? tradeDate,
    String? savedAt,
    String? systemPrompt,
    List<AskAiPromptSectionData>? promptSections,
    String? userPrompt,
    String? result,
    String? source,
  }) {
    return AskAiSavedAnalysisEntry(
      sessionId: sessionId ?? this.sessionId,
      tradeDate: tradeDate ?? this.tradeDate,
      savedAt: savedAt ?? this.savedAt,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      promptSections: promptSections ?? this.promptSections,
      userPrompt: userPrompt ?? this.userPrompt,
      result: result ?? this.result,
      source: source ?? this.source,
    );
  }
}

class AskAiSessionMessageData {
  const AskAiSessionMessageData({
    required this.role,
    required this.title,
    required this.content,
    required this.sortIndex,
  });

  final String role;
  final String title;
  final String content;
  final int sortIndex;

  factory AskAiSessionMessageData.fromJson(Map<String, dynamic> json) {
    return AskAiSessionMessageData(
      role: json['role'] as String? ?? 'context',
      title: json['title'] as String? ?? '--',
      content: json['content'] as String? ?? '',
      sortIndex: _tryParseInt(json['sort_index']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'title': title,
      'content': content,
      'sort_index': sortIndex,
    };
  }
}

class AskAiConversationSessionData {
  const AskAiConversationSessionData({
    required this.sessionId,
    required this.tradeDate,
    required this.savedAt,
    required this.result,
    required this.messages,
    required this.source,
  });

  final int sessionId;
  final String tradeDate;
  final String savedAt;
  final String result;
  final List<AskAiSessionMessageData> messages;
  final String source;

  factory AskAiConversationSessionData.fromJson(Map<String, dynamic> json) {
    return AskAiConversationSessionData(
      sessionId: _tryParseInt(json['session_id']) ?? 0,
      tradeDate: json['trade_date'] as String? ?? '',
      savedAt: json['saved_at'] as String? ?? '',
      result: json['result'] as String? ?? '',
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AskAiSessionMessageData.fromJson)
          .toList(growable: false),
      source: json['source'] as String? ?? 'flutter',
    );
  }
}

class AskAiRepository {
  AskAiRepository(this._client);

  final ApiClient _client;

  static const _providerPresetKey = 'ask_ai_provider_preset';
  static const _endpointKey = 'ask_ai_endpoint';
  static const _apiKeyKey = 'ask_ai_api_key';
  static const _modelKey = 'ask_ai_model';
  static const _dailyLimitKey = 'ask_ai_daily_limit';
  static const _clientIdKey = 'ask_ai_client_id';
  static const _savedAnalysesKey = 'ask_ai_saved_analyses';
  static const _usageStoreKey = 'ask_ai_usage_store';

  Future<AskAiContextSnapshot> fetchContext() async {
    final data = await _client.getMap('/api/v1/ask-ai/context');
    return AskAiContextSnapshot.fromJson(data);
  }

  Future<AskAiSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = AskAiSettings.defaults();
    final providerPreset =
        parseAskAiProviderPreset(prefs.getString(_providerPresetKey));
    final apiKey = prefs.getString(_apiKeyKey)?.trim() ?? '';
    final model = _normalizeStoredModel(
      prefs.getString(_modelKey)?.trim(),
      hasPersonalKey: apiKey.isNotEmpty,
    );
    final storedDailyLimit = prefs.getInt(_dailyLimitKey);

    return AskAiSettings(
      providerPreset: providerPreset,
      model: model.isNotEmpty
          ? model
          : (providerPreset.defaultModel.isNotEmpty
              ? providerPreset.defaultModel
              : defaults.model),
      dailyLimit: storedDailyLimit != null && storedDailyLimit >= 0
          ? storedDailyLimit
          : providerPreset.recommendedDailyLimit,
      apiKey: apiKey,
    );
  }

  Future<void> saveSettings(AskAiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _providerPresetKey,
      settings.providerPreset.storageValue,
    );
    await prefs.remove(_endpointKey);
    if (settings.apiKey.trim().isEmpty) {
      await prefs.remove(_apiKeyKey);
    } else {
      await prefs.setString(_apiKeyKey, settings.apiKey.trim());
    }
    if (settings.model.trim().isEmpty) {
      await prefs.remove(_modelKey);
    } else {
      await prefs.setString(_modelKey, settings.model.trim());
    }
    await prefs.setInt(
        _dailyLimitKey, settings.dailyLimit < 0 ? 0 : settings.dailyLimit);
    await _syncServerClientConfig(settings);
  }

  Future<AskAiUsageStatus> loadUsageStatus(AskAiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final store = _decodeUsageStore(prefs.getString(_usageStoreKey));
    final usageKey = _usageKeyFor(settings);
    final today = _todayKey();
    final entry = store[usageKey];
    if (entry is Map && entry['date'] == today) {
      final usedToday = int.tryParse('${entry['count'] ?? 0}') ?? 0;
      return AskAiUsageStatus(
        providerLabel: _providerLabelFor(settings),
        usedToday: usedToday,
        dailyLimit: settings.dailyLimit,
      );
    }

    return AskAiUsageStatus(
      providerLabel: _providerLabelFor(settings),
      usedToday: 0,
      dailyLimit: settings.dailyLimit,
    );
  }

  Future<AskAiUsageStatus> recordUsage(AskAiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final store = _decodeUsageStore(prefs.getString(_usageStoreKey));
    final usageKey = _usageKeyFor(settings);
    final today = _todayKey();
    final existing = store[usageKey];
    final entry = existing is Map<String, dynamic>
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};

    if (entry['date'] != today) {
      entry['date'] = today;
      entry['count'] = 0;
    }

    entry['count'] = (int.tryParse('${entry['count'] ?? 0}') ?? 0) + 1;
    store[usageKey] = entry;
    await prefs.setString(_usageStoreKey, jsonEncode(store));

    return AskAiUsageStatus(
      providerLabel: _providerLabelFor(settings),
      usedToday: entry['count'] as int,
      dailyLimit: settings.dailyLimit,
    );
  }

  Future<AiServerUsageStatus> fetchServerUsageStatus() async {
    final clientId = await _loadOrCreateClientId();
    final data = await _client.getMap(
      '/api/v1/ask-ai/usage-status?client_id=$clientId',
    );
    return AiServerUsageStatus.fromJson(data);
  }

  Future<List<AskAiSavedAnalysisEntry>> loadSavedAnalyses() async {
    final localEntriesFuture = _loadLocalSavedAnalyses();
    final remoteEntriesFuture = _tryLoadRemoteSavedAnalyses();

    final localEntries = await localEntriesFuture;
    final remoteEntries = await remoteEntriesFuture;
    if (remoteEntries == null || remoteEntries.isEmpty) {
      return localEntries;
    }

    final merged = _mergeSavedAnalyses(
      primary: remoteEntries,
      secondary: localEntries,
    );
    await _persistLocalSavedAnalyses(merged);
    return merged;
  }

  Future<List<AskAiSavedAnalysisEntry>> _loadLocalSavedAnalyses() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_savedAnalysesKey)?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) {
        return const [];
      }

      final entries = <AskAiSavedAnalysisEntry>[];
      for (final item in decoded) {
        if (item is Map) {
          entries.add(
            AskAiSavedAnalysisEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
      return _sortSavedAnalyses(entries).take(7).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAnalysis({
    required String? tradeDate,
    required String systemPrompt,
    required List<AskAiPromptSectionData> promptSections,
    required String userPrompt,
    required String result,
  }) async {
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    final normalizedPromptSections = promptSections
        .where((section) => section.content.trim().isNotEmpty)
        .map(
          (section) => AskAiPromptSectionData(
            key: section.key,
            title: section.title,
            content: section.content.trim(),
          ),
        )
        .toList(growable: false);
    final sessionMessages = _buildSessionMessages(
      systemPrompt: systemPrompt.trim(),
      promptSections: normalizedPromptSections,
      userPrompt: userPrompt.trim(),
      result: result.trim(),
    );
    int? remoteSessionId;
    try {
      remoteSessionId = await _saveRemoteSession(
        tradeDate: normalizedTradeDate,
        systemPrompt: systemPrompt.trim(),
        promptSections: normalizedPromptSections,
        userPrompt: userPrompt.trim(),
        result: result.trim(),
        messages: sessionMessages,
      );
    } on DioException {
      remoteSessionId = null;
    } on StateError {
      remoteSessionId = null;
    }

    final nextEntry = AskAiSavedAnalysisEntry(
      sessionId: remoteSessionId,
      tradeDate: normalizedTradeDate,
      savedAt: DateTime.now().toIso8601String(),
      systemPrompt: systemPrompt.trim(),
      promptSections: normalizedPromptSections,
      userPrompt: userPrompt.trim(),
      result: result.trim(),
      source: remoteSessionId == null ? 'flutter' : 'server',
    );

    final existing = await _loadLocalSavedAnalyses();
    final merged = _mergeSavedAnalyses(
      primary: [nextEntry],
      secondary: existing,
    );
    await _persistLocalSavedAnalyses(merged);

    try {
      await _saveRemoteAnalysis(nextEntry);
    } on DioException {
      // Fall back to local-only history when the API server does not expose sync.
    } on StateError {
      // Keep local history usable even if the server-side sync path is unavailable.
    }
  }

  Future<AskAiConversationSessionData?> loadConversationSession(
    int sessionId,
  ) async {
    final dio = _historySyncDio();
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/ask-ai/sessions/$sessionId',
      );
      final data = response.data ?? <String, dynamic>{};
      return AskAiConversationSessionData.fromJson(data);
    } on DioException {
      return null;
    } finally {
      dio.close(force: true);
    }
  }

  Future<String> generateAnalysis({
    required AskAiSettings settings,
    required String systemPrompt,
    required String userPrompt,
    List<AskAiPromptSectionData> promptSections = const [],
    void Function(String chunk)? onChunk,
  }) async {
    final messages = _buildMessages(
      systemPrompt: systemPrompt,
      promptSections: promptSections,
      userPrompt: userPrompt,
    );
    if (messages.isEmpty) {
      throw StateError('Prompt is empty.');
    }

    try {
      final response = await _client.postMap(
        '/api/v1/ask-ai/generate',
        receiveTimeout: const Duration(minutes: 4),
        data: {
          'source': 'ask_ai',
          'system_prompt': systemPrompt,
          'prompt_sections': promptSections
              .map((section) => section.toJson())
              .toList(growable: false),
          'user_prompt': userPrompt,
          'client_config': await buildClientConfigPayload(settings),
        },
      );
      final result = response['result']?.toString().trim() ?? '';
      if (result.isEmpty) {
        throw StateError('AI response is empty.');
      }
      onChunk?.call(result);
      return result;
    } on DioException catch (error) {
      throw StateError(_extractDioError(error));
    }
  }

  List<Map<String, String>> _buildMessages({
    required String systemPrompt,
    required List<AskAiPromptSectionData> promptSections,
    required String userPrompt,
  }) {
    final messages = <Map<String, String>>[];

    if (systemPrompt.trim().isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': systemPrompt.trim(),
      });
    }

    for (final section in promptSections) {
      final content = section.content.trim();
      if (content.isEmpty) {
        continue;
      }
      messages.add({
        'role': 'user',
        'content': content,
      });
    }

    if (userPrompt.trim().isNotEmpty) {
      messages.add({
        'role': 'user',
        'content': userPrompt.trim(),
      });
    }

    return messages;
  }

  Future<Map<String, dynamic>> buildClientConfigPayload(
    AskAiSettings settings,
  ) async {
    if (settings.apiKey.trim().isNotEmpty) {
      await _syncServerClientConfig(settings);
    }
    return {
      'provider': 'kimi',
      'client_id': await _loadOrCreateClientId(),
    };
  }

  Future<void> _syncServerClientConfig(AskAiSettings settings) async {
    try {
      final apiKey = settings.apiKey.trim();
      final model = settings.model.trim();
      await _client.postMap(
        '/api/v1/ask-ai/client-config',
        data: {
          'provider': 'kimi',
          'client_id': await _loadOrCreateClientId(),
          'api_key': apiKey,
          if (apiKey.isNotEmpty && model.isNotEmpty) 'model': model,
        },
        receiveTimeout: const Duration(seconds: 12),
      );
    } on DioException {
      // Local settings remain usable; the next save or AI request can sync again.
    } on StateError {
      // Keep the desktop settings panel responsive if the API is unavailable.
    }
  }

  String _extractDioError(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = responseData['error'];
      if (message is Map<String, dynamic>) {
        final detail = message['message']?.toString();
        if (detail != null && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
      final detail = responseData['message']?.toString();
      if (detail != null && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      final fastApiDetail = responseData['detail']?.toString();
      if (fastApiDetail != null && fastApiDetail.trim().isNotEmpty) {
        return fastApiDetail.trim();
      }
    }
    return error.message ?? 'AI request failed';
  }

  Map<String, dynamic> _decodeUsageStore(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  String _usageKeyFor(AskAiSettings settings) {
    final model = settings.model.trim().toLowerCase();
    final keyScope = settings.hasPersonalApiKey ? 'personal' : 'public';
    return '${settings.providerPreset.storageValue}|$model|$keyScope';
  }

  String _providerLabelFor(AskAiSettings settings) {
    if (settings.hasPersonalApiKey) {
      return '个人 Kimi 密钥';
    }
    return '后端公共 Kimi 试用';
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _normalizeStoredModel(
    String? value, {
    required bool hasPersonalKey,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '';
    }
    if (!hasPersonalKey) {
      return '';
    }
    return normalized;
  }

  Future<String> _loadOrCreateClientId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_clientIdKey)?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final random = math.Random.secure();
    final randomHex = List.generate(
      4,
      (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
      growable: false,
    ).join();
    final clientId =
        'flutter-${DateTime.now().microsecondsSinceEpoch}-$randomHex';
    await prefs.setString(_clientIdKey, clientId);
    return clientId;
  }

  List<AskAiSavedAnalysisEntry> _sortSavedAnalyses(
    List<AskAiSavedAnalysisEntry> entries,
  ) {
    entries.sort((left, right) {
      final tradeDateCompare = right.tradeDate.compareTo(left.tradeDate);
      if (tradeDateCompare != 0) {
        return tradeDateCompare;
      }
      return right.savedAt.compareTo(left.savedAt);
    });
    return entries;
  }

  String _normalizeTradeDate(String? value) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return _todayKey();
  }

  Future<void> _persistLocalSavedAnalyses(
    List<AskAiSavedAnalysisEntry> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      _sortSavedAnalyses(entries)
          .take(7)
          .map((entry) => entry.toJson())
          .toList(growable: false),
    );
    await prefs.setString(_savedAnalysesKey, payload);
  }

  Future<List<AskAiSavedAnalysisEntry>?> _tryLoadRemoteSavedAnalyses() async {
    final sessionEntries = await _tryLoadRemoteSessionSummaries();
    if (sessionEntries != null && sessionEntries.isNotEmpty) {
      return sessionEntries;
    }

    final dio = _historySyncDio();
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/ask-ai/history?limit=7',
      );
      final data = response.data ?? <String, dynamic>{};
      final rawItems = data['items'];
      if (rawItems is! List) {
        return const [];
      }
      final entries = rawItems
          .whereType<Map<String, dynamic>>()
          .map(AskAiSavedAnalysisEntry.fromJson)
          .toList(growable: false);
      return _sortSavedAnalyses(entries).take(7).toList(growable: false);
    } on DioException {
      return null;
    } finally {
      dio.close(force: true);
    }
  }

  Future<List<AskAiSavedAnalysisEntry>?>
      _tryLoadRemoteSessionSummaries() async {
    final dio = _historySyncDio();
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/ask-ai/sessions?limit=7',
      );
      final data = response.data ?? <String, dynamic>{};
      final rawItems = data['items'];
      if (rawItems is! List) {
        return const [];
      }
      final entries = rawItems
          .whereType<Map<String, dynamic>>()
          .map(AskAiSavedAnalysisEntry.fromJson)
          .toList(growable: false);
      return _sortSavedAnalyses(entries).take(7).toList(growable: false);
    } on DioException {
      return null;
    } finally {
      dio.close(force: true);
    }
  }

  Future<void> _saveRemoteAnalysis(AskAiSavedAnalysisEntry entry) async {
    final dio = _historySyncDio();
    try {
      await dio.post<Map<String, dynamic>>(
        '/api/v1/ask-ai/history',
        data: {
          'trade_date': entry.tradeDate,
          'system_prompt': entry.systemPrompt,
          'prompt_sections': entry.promptSections
              .map((section) => section.toJson())
              .toList(growable: false),
          'user_prompt': entry.userPrompt,
          'result': entry.result,
          'source': 'flutter',
        },
      );
    } finally {
      dio.close(force: true);
    }
  }

  Future<int?> _saveRemoteSession({
    required String tradeDate,
    required String systemPrompt,
    required List<AskAiPromptSectionData> promptSections,
    required String userPrompt,
    required String result,
    required List<AskAiSessionMessageData> messages,
  }) async {
    final dio = _historySyncDio();
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/ask-ai/sessions',
        data: {
          'trade_date': tradeDate,
          'system_prompt': systemPrompt,
          'prompt_sections': promptSections
              .map((section) => section.toJson())
              .toList(growable: false),
          'user_prompt': userPrompt,
          'result': result,
          'source': 'flutter',
          'messages': messages
              .map((message) => message.toJson())
              .toList(growable: false),
        },
      );
      return _tryParseInt((response.data ?? const {})['session_id']);
    } finally {
      dio.close(force: true);
    }
  }

  List<AskAiSavedAnalysisEntry> _mergeSavedAnalyses({
    required List<AskAiSavedAnalysisEntry> primary,
    required List<AskAiSavedAnalysisEntry> secondary,
  }) {
    final merged = <AskAiSavedAnalysisEntry>[
      ...primary,
      ...secondary.where(
        (entry) => !primary.any(
          (primaryEntry) => primaryEntry.tradeDate == entry.tradeDate,
        ),
      ),
    ];
    return _sortSavedAnalyses(merged).take(7).toList(growable: false);
  }

  List<AskAiSessionMessageData> _buildSessionMessages({
    required String systemPrompt,
    required List<AskAiPromptSectionData> promptSections,
    required String userPrompt,
    required String result,
  }) {
    final messages = <AskAiSessionMessageData>[];
    var sortIndex = 0;

    if (systemPrompt.trim().isNotEmpty) {
      messages.add(
        AskAiSessionMessageData(
          role: 'system',
          title: 'System',
          content: systemPrompt.trim(),
          sortIndex: sortIndex,
        ),
      );
      sortIndex += 1;
    }

    for (final section in promptSections) {
      if (section.content.trim().isEmpty) {
        continue;
      }
      messages.add(
        AskAiSessionMessageData(
          role: 'context',
          title: section.title,
          content: section.content.trim(),
          sortIndex: sortIndex,
        ),
      );
      sortIndex += 1;
    }

    if (userPrompt.trim().isNotEmpty) {
      messages.add(
        AskAiSessionMessageData(
          role: 'user',
          title: 'Final User Prompt',
          content: userPrompt.trim(),
          sortIndex: sortIndex,
        ),
      );
      sortIndex += 1;
    }

    if (result.trim().isNotEmpty) {
      messages.add(
        AskAiSessionMessageData(
          role: 'assistant',
          title: 'Assistant Reply',
          content: result.trim(),
          sortIndex: sortIndex,
        ),
      );
    }

    return messages;
  }

  Dio _historySyncDio() {
    return Dio(
      BaseOptions(
        baseUrl: _client.baseUrl,
        connectTimeout: const Duration(milliseconds: 300),
        receiveTimeout: const Duration(milliseconds: 500),
      ),
    );
  }
}

int? _tryParseInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('${value ?? ''}');
}
