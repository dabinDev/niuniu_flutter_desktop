import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/features/ask_ai/data/ask_ai_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testApiBaseUrl = 'https://api.example.invalid';
  const testPersonalApiKey = 'redacted';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ask ai repository keeps prompt sections in saved analyses', () async {
    final repository = AskAiRepository(
      ApiClient(baseUrl: testApiBaseUrl),
    );

    await repository.saveAnalysis(
      tradeDate: '2026-04-18',
      systemPrompt: 'System prompt',
      promptSections: const [
        AskAiPromptSectionData(
          key: 'auction',
          title: 'Auction',
          content: 'Auction context block',
        ),
        AskAiPromptSectionData(
          key: 'review',
          title: 'Review',
          content: 'Review context block',
        ),
      ],
      userPrompt: 'Final user prompt',
      result: 'Analysis result',
    );

    final entries = await repository.loadSavedAnalyses();

    expect(entries, hasLength(1));
    expect(entries.first.tradeDate, '2026-04-18');
    expect(entries.first.promptSections, hasLength(2));
    expect(entries.first.promptSections.first.title, 'Auction');
    expect(entries.first.promptSections.last.content, 'Review context block');
  });

  test('ask ai repository tracks local usage by preset and model', () async {
    final repository = AskAiRepository(
      ApiClient(baseUrl: testApiBaseUrl),
    );

    const backendSettings = AskAiSettings(
      providerPreset: AskAiProviderPreset.backend,
      model: 'kimi-k2.6',
      dailyLimit: 1,
      apiKey: '',
    );

    final initialStatus = await repository.loadUsageStatus(backendSettings);
    expect(initialStatus.canSend, isTrue);
    expect(initialStatus.remaining, 1);

    final afterFirstUse = await repository.recordUsage(backendSettings);
    expect(afterFirstUse.usedToday, 1);
    expect(afterFirstUse.canSend, isFalse);

    final otherModelStatus = await repository.loadUsageStatus(
      backendSettings.copyWith(model: 'api_server:backup'),
    );
    expect(otherModelStatus.usedToday, 0);
    expect(otherModelStatus.canSend, isTrue);
  });

  test('ask ai settings syncs personal kimi config to server', () async {
    final client = _FakeApiClient();
    final repository = AskAiRepository(client);
    const settings = AskAiSettings(
      providerPreset: AskAiProviderPreset.backend,
      model: 'kimi-k2.6',
      dailyLimit: 0,
      apiKey: testPersonalApiKey,
    );

    await repository.saveSettings(settings);
    final result = await repository.generateAnalysis(
      settings: settings,
      systemPrompt: 'System prompt',
      userPrompt: 'User prompt',
    );

    expect(result, 'AI result');
    expect(client.postedPaths.first, '/api/v1/ask-ai/client-config');
    final syncPayload = client.postedData.first as Map<String, dynamic>;
    expect(syncPayload['provider'], 'kimi');
    expect(syncPayload['model'], 'kimi-k2.6');
    expect(syncPayload['api_key'], testPersonalApiKey);
    expect(syncPayload['client_id'].toString(), startsWith('flutter-'));

    expect(client.lastPostPath, '/api/v1/ask-ai/generate');
    final payload = client.lastPostData as Map<String, dynamic>;
    expect(payload['system_prompt'], 'System prompt');
    expect(payload['user_prompt'], 'User prompt');
    final clientConfig = payload['client_config'] as Map<String, dynamic>;
    expect(clientConfig['provider'], 'kimi');
    expect(clientConfig.containsKey('model'), isFalse);
    expect(clientConfig.containsKey('api_key'), isFalse);
    expect(
      clientConfig['client_id'].toString(),
      matches(RegExp(r'^flutter-\d+-[0-9a-f]{16}$')),
    );
  });

  test('ask ai generate omits model when using backend defaults', () async {
    final client = _FakeApiClient();
    final repository = AskAiRepository(client);
    final settings = AskAiSettings.defaults();

    await repository.generateAnalysis(
      settings: settings,
      systemPrompt: 'System prompt',
      userPrompt: 'User prompt',
    );

    final payload = client.lastPostData as Map<String, dynamic>;
    final clientConfig = payload['client_config'] as Map<String, dynamic>;
    expect(clientConfig['provider'], 'kimi');
    expect(clientConfig.containsKey('model'), isFalse);
    expect(clientConfig.containsKey('api_key'), isFalse);
  });

  test('ask ai generate syncs personal kimi config before request', () async {
    final client = _FakeApiClient();
    final repository = AskAiRepository(client);
    const settings = AskAiSettings(
      providerPreset: AskAiProviderPreset.backend,
      model: 'kimi-k2.6',
      dailyLimit: 0,
      apiKey: testPersonalApiKey,
    );

    await repository.generateAnalysis(
      settings: settings,
      systemPrompt: 'System prompt',
      userPrompt: 'User prompt',
    );

    expect(client.postedPaths, <String>[
      '/api/v1/ask-ai/client-config',
      '/api/v1/ask-ai/generate',
    ]);
    final syncPayload = client.postedData.first as Map<String, dynamic>;
    expect(syncPayload['api_key'], testPersonalApiKey);
    expect(syncPayload['model'], 'kimi-k2.6');

    final payload = client.lastPostData as Map<String, dynamic>;
    final clientConfig = payload['client_config'] as Map<String, dynamic>;
    expect(clientConfig['provider'], 'kimi');
    expect(clientConfig.containsKey('model'), isFalse);
    expect(clientConfig.containsKey('api_key'), isFalse);
    expect(clientConfig['client_id'].toString(), startsWith('flutter-'));
  });

  test('ask ai generate ignores stale model without personal key', () async {
    final client = _FakeApiClient();
    final repository = AskAiRepository(client);
    const settings = AskAiSettings(
      providerPreset: AskAiProviderPreset.backend,
      model: 'gpt-4o-mini',
      dailyLimit: 0,
      apiKey: '',
    );

    await repository.generateAnalysis(
      settings: settings,
      systemPrompt: 'System prompt',
      userPrompt: 'User prompt',
    );

    final payload = client.lastPostData as Map<String, dynamic>;
    final clientConfig = payload['client_config'] as Map<String, dynamic>;
    expect(clientConfig['provider'], 'kimi');
    expect(clientConfig.containsKey('model'), isFalse);
    expect(clientConfig.containsKey('api_key'), isFalse);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'https://api.example.invalid');

  String? lastPostPath;
  Object? lastPostData;
  final postedPaths = <String>[];
  final postedData = <Object?>[];

  @override
  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? data,
    Duration? receiveTimeout,
  }) async {
    lastPostPath = path;
    lastPostData = data;
    postedPaths.add(path);
    postedData.add(data);
    if (path == '/api/v1/ask-ai/client-config') {
      return {
        'client_id': 'flutter-test',
        'provider': 'kimi',
        'model': 'kimi-k2.6',
        'api_key_configured': true,
        'uses_public_fallback': false,
      };
    }
    return {
      'result': 'AI result',
      'generated_at': '2026-04-18T10:00:00Z',
      'provider': 'kimi',
      'model': 'kimi-k2.6',
      'source': 'ask_ai',
      'trade_date': '2026-04-18',
    };
  }
}
