import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/ask_ai/application/ask_ai_provider.dart';
import 'package:niuniu_kaipan/features/ask_ai/data/ask_ai_repository.dart';
import 'package:niuniu_kaipan/features/ask_ai/presentation/ask_ai_page.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ask ai page saves generated analysis into local history', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 4200);
    addTearDown(tester.view.reset);

    final repository = _FakeAskAiRepository(
      snapshot: _snapshot(
        tradeDate: '2026-04-18',
        systemPrompt: 'System instruction for today.',
        userPrompt: 'Look for strong open auction and rotation continuity.',
      ),
      generatedResult:
          'Alpha note: robotics and storage stayed resilient into the close.',
    );

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('问AI工作台'), findsOneWidget);
    expect(find.text('复制图片'), findsOneWidget);
    expect(find.text('导出 Excel'), findsOneWidget);
    expect(find.text('导出 CSV'), findsOneWidget);
    expect(find.text('查看今日提示词'), findsOneWidget);
    expect(
      find.text('当前还没有保存记录。生成一次分析后会自动缓存在本地。'),
      findsOneWidget,
    );

    final generateButton = _buttonForText('生成分析');
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pump();
    await tester.pumpAndSettle();

    final entries = await repository.loadSavedAnalyses();

    expect(entries, hasLength(1));
    expect(entries.first.tradeDate, '2026-04-18');
    expect(
      entries.first.result,
      contains('robotics and storage stayed resilient'),
    );
    expect(entries.first.userPrompt, contains('strong open auction'));
    expect(repository.lastPromptSections, hasLength(2));
    expect(repository.lastPromptSections.first.title, 'Auction');
    expect(
      find.textContaining('Alpha note: robotics and storage'),
      findsWidgets,
    );
    expect(find.text('当前交易日'), findsOneWidget);
  });

  testWidgets('ask ai page shows loading copy while saved history is pending', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 4200);
    addTearDown(tester.view.reset);

    final repository = _FakeAskAiRepository(
      snapshot: _snapshot(
        tradeDate: '2026-04-18',
        systemPrompt: 'System instruction for today.',
        userPrompt: 'Look for strong open auction and rotation continuity.',
      ),
      generatedResult: 'Current note.',
    );
    final savedAnalysesCompleter = Completer<List<AskAiSavedAnalysisEntry>>();
    addTearDown(() {
      if (!savedAnalysesCompleter.isCompleted) {
        savedAnalysesCompleter.complete(const <AskAiSavedAnalysisEntry>[]);
      }
    });

    await tester.pumpWidget(
      _buildApp(
        repository,
        overrides: [
          askAiSavedAnalysesProvider.overrideWith(
            (ref) => savedAnalysesCompleter.future,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('最近保存的分析'), findsOneWidget);
    expect(find.text('正在加载保存记录...'), findsOneWidget);
  });

  testWidgets('ask ai page restores today saved analysis on page entry', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 4200);
    addTearDown(tester.view.reset);

    final repository = _FakeAskAiRepository(
      snapshot: _snapshot(
        tradeDate: '2026-04-18',
        systemPrompt: 'System instruction for today.',
        userPrompt: 'Look for strong open auction and rotation continuity.',
      ),
      generatedResult: 'Current note.',
    );
    repository.seedSavedEntry(
      const AskAiSavedAnalysisEntry(
        sessionId: null,
        tradeDate: '2026-04-18',
        savedAt: '2026-04-18T10:30:00',
        systemPrompt: 'Saved system prompt.',
        promptSections: [
          AskAiPromptSectionData(
            key: 'auction',
            title: 'Auction',
            content: 'Saved auction context.',
          ),
        ],
        userPrompt: 'Saved user prompt.',
        result: 'Restored today result should stay visible after tab return.',
        source: 'flutter',
      ),
    );

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Restored today result should stay visible'),
      findsWidgets,
    );
    expect(find.text('已恢复 2026-04-18 的上次 AI 分析。'), findsWidgets);
  });

  testWidgets('ask ai page exposes today and yesterday prompt dialogs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 4200);
    addTearDown(tester.view.reset);

    final repository = _FakeAskAiRepository(
      snapshot: _snapshot(
        tradeDate: '2026-04-18',
        systemPrompt: 'System instruction for today.',
        userPrompt: 'Look for strong open auction and rotation continuity.',
      ),
      generatedResult: 'Current note.',
    );

    await repository.saveAnalysis(
      tradeDate: '2026-04-17',
      systemPrompt: 'Yesterday system prompt.',
      promptSections: const [
        AskAiPromptSectionData(
          key: 'yesterday_auction',
          title: 'Yesterday Auction',
          content: 'Yesterday auction context.',
        ),
      ],
      userPrompt: 'Yesterday user prompt.',
      result: 'Yesterday note from local history.',
    );

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Yesterday note from local history'),
      findsWidgets,
    );

    await tester.tap(_buttonForText('查看昨日提示词'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('昨日提示词', skipOffstage: false),
      findsWidgets,
    );
    expect(find.text('Yesterday system prompt.'), findsOneWidget);
    expect(find.textContaining('Yesterday Auction'), findsOneWidget);
    expect(find.text('Yesterday auction context.'), findsOneWidget);
    expect(find.text('Yesterday user prompt.'), findsOneWidget);

    await tester.tap(_buttonForText('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(_buttonForText('查看今日提示词'));
    await tester.pumpAndSettle();

    expect(find.textContaining('今日提示词', skipOffstage: false), findsWidgets);
    expect(find.text('System instruction for today.'), findsWidgets);
    expect(find.textContaining('Auction'), findsWidgets);
    expect(
      find.text('Auction leaders kept a clean premium distribution.'),
      findsWidgets,
    );
    expect(
      find.text('Look for strong open auction and rotation continuity.'),
      findsWidgets,
    );
  });

  testWidgets('ask ai page replays remote session messages when session exists',
      (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 4200);
    addTearDown(tester.view.reset);

    final repository = _FakeAskAiRepository(
      snapshot: _snapshot(
        tradeDate: '2026-04-18',
        systemPrompt: 'System instruction for today.',
        userPrompt: 'Look for strong open auction and rotation continuity.',
      ),
      generatedResult: 'Current note.',
    );

    repository.seedSavedEntry(
      const AskAiSavedAnalysisEntry(
        sessionId: 42,
        tradeDate: '2026-04-17',
        savedAt: '2026-04-18T10:00:00',
        systemPrompt: 'Local fallback system prompt.',
        promptSections: [
          AskAiPromptSectionData(
            key: 'local_review',
            title: 'Local Review',
            content: 'Local summary-only review block.',
          ),
        ],
        userPrompt: 'Local fallback user prompt.',
        result: 'Local summary result.',
        source: 'server',
      ),
    );
    repository.seedConversationSession(
      const AskAiConversationSessionData(
        sessionId: 42,
        tradeDate: '2026-04-17',
        savedAt: '2026-04-18T10:00:00',
        result: 'Remote assistant full reply.',
        source: 'server',
        messages: [
          AskAiSessionMessageData(
            role: 'system',
            title: 'System',
            content: 'Remote session system prompt.',
            sortIndex: 0,
          ),
          AskAiSessionMessageData(
            role: 'context',
            title: 'Auction Segment',
            content: 'Remote-only context segment.',
            sortIndex: 1,
          ),
          AskAiSessionMessageData(
            role: 'user',
            title: 'Final User Prompt',
            content: 'Remote final user prompt.',
            sortIndex: 2,
          ),
          AskAiSessionMessageData(
            role: 'assistant',
            title: 'Assistant Reply',
            content: 'Remote assistant full reply.',
            sortIndex: 3,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('会话 #42'), findsWidgets);
    expect(find.text('Remote-only context segment.'), findsNothing);

    final loadNoteButton = find.widgetWithText(OutlinedButton, '载入记录').first;
    await tester.ensureVisible(loadNoteButton);
    await tester.tap(loadNoteButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Remote assistant full reply.'), findsWidgets);
    final requestChainTile = find.text('请求链路');
    await tester.ensureVisible(requestChainTile);
    await tester.tap(requestChainTile);
    await tester.pumpAndSettle();

    expect(find.text('Remote session system prompt.'), findsOneWidget);
    expect(find.text('Auction Segment'), findsOneWidget);
    expect(find.text('Remote-only context segment.'), findsOneWidget);
    expect(find.text('Remote final user prompt.'), findsOneWidget);
  });

  testWidgets('ask ai page shows segmented send progress during generation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 4200);
    addTearDown(tester.view.reset);

    final repository = _FakeAskAiRepository(
      snapshot: _snapshot(
        tradeDate: '2026-04-18',
        systemPrompt: 'System instruction for today.',
        userPrompt: 'Look for strong open auction and rotation continuity.',
      ),
      generatedResult: 'Segmented note.',
      generateDelay: const Duration(milliseconds: 80),
    );

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('AI 结果'), findsOneWidget);
    expect(find.text('发送顺序'), findsNothing);

    final generateButton = _buttonForText('生成分析');
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pump();

    expect(find.textContaining('正在'), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.textContaining('Segmented note.'), findsWidgets);
    final requestChainTile = find.text('请求链路');
    await tester.ensureVisible(requestChainTile);
    await tester.tap(requestChainTile);
    await tester.pumpAndSettle();

    expect(find.text('发送顺序'), findsOneWidget);
    expect(find.text('已发送'), findsWidgets);
  });

  testWidgets('ask ai page streams assistant chunks into transcript', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 4200);
    addTearDown(tester.view.reset);

    final repository = _FakeAskAiRepository(
      snapshot: _snapshot(
        tradeDate: '2026-04-18',
        systemPrompt: 'System instruction for today.',
        userPrompt: 'Look for strong open auction and rotation continuity.',
      ),
      generatedResult: 'Alpha stream done.',
      streamChunks: const ['Alpha ', 'stream ', 'done.'],
      streamChunkDelay: const Duration(milliseconds: 30),
      generateDelay: const Duration(milliseconds: 120),
    );

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    final generateButton = _buttonForText('生成分析');
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.textContaining('正在接收模型流式返回...'), findsWidgets);
    expect(find.textContaining('Alpha'), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.textContaining('Alpha stream done.'), findsWidgets);
  });

  testWidgets('ask ai page renders generation errors in result panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 4200);
    addTearDown(tester.view.reset);

    final repository = _FakeAskAiRepository(
      snapshot: _snapshot(
        tradeDate: '2026-04-18',
        systemPrompt: 'System instruction for today.',
        userPrompt: 'Look for strong open auction and rotation continuity.',
      ),
      generatedResult: '',
      generateError: StateError('Kimi 请求超时。'),
    );

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    final generateButton = _buttonForText('生成分析');
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(find.text('AI 生成失败'), findsOneWidget);
    expect(find.textContaining('Kimi 请求超时'), findsWidgets);
    expect(find.textContaining('右侧上下文数据已加载'), findsWidgets);
  });

  testWidgets('ask ai page debounces workspace settings autosave', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 4200);
    addTearDown(tester.view.reset);

    final repository = _FakeAskAiRepository(
      snapshot: _snapshot(
        tradeDate: '2026-04-18',
        systemPrompt: 'System instruction for today.',
        userPrompt: 'Look for strong open auction and rotation continuity.',
      ),
      generatedResult: 'Current note.',
    );

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('服务设置'));
    await tester.pumpAndSettle();

    expect(find.text('个人 Kimi Key'), findsOneWidget);
    expect(find.text('模型'), findsOneWidget);
    expect(find.text('接口地址'), findsNothing);

    final limitField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '本地日上限',
    );
    await tester.enterText(limitField, '3');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(limitField, '4');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(limitField, '5');
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.saveSettingsCalls, 0);

    await tester.pump(const Duration(milliseconds: 250));

    expect(repository.saveSettingsCalls, 1);
    expect(repository.storedSettings.dailyLimit, 5);
  });
}

Finder _buttonForText(String text) {
  return find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
}

Widget _buildApp(
  AskAiRepository repository, {
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: [
      shellOverviewProvider.overrideWith((ref) async => _shellOverview),
      askAiRepositoryProvider.overrideWithValue(repository),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const AskAiPage(),
    ),
  );
}

const _shellOverview = OverviewSnapshot(
  tradeDate: '2026-04-18',
  notices: [],
  indices: [],
  amountSummary: OverviewAmountSummaryData(),
  breadthSummary: OverviewBreadthSummaryData(),
  sentiment: OverviewSentimentSummaryData(
    stage: 'neutral',
    bias: 'neutral',
    score: 50,
    metrics: [],
  ),
  shellStatus: OverviewShellStatusData(
    marketPhase: 'off_hours',
    dataFreshness: 'fresh',
    jobHealth: OverviewJobHealthData(
      totalJobs: 0,
      enabledJobs: 0,
      healthyJobs: 0,
      warningJobs: 0,
      failedJobs: 0,
      queuedJobs: 0,
    ),
    watchedJobs: [],
  ),
);

AskAiContextSnapshot _snapshot({
  required String tradeDate,
  required String systemPrompt,
  required String userPrompt,
}) {
  return AskAiContextSnapshot(
    tradeDate: tradeDate,
    generatedAt: '2026-04-18T10:00:00',
    cards: const [
      AskAiContextCardData(
        key: 'market_phase',
        label: 'Phase',
        value: 'Close',
        tone: 'info',
      ),
      AskAiContextCardData(
        key: 'leaders',
        label: 'Leaders',
        value: 'Robotics / Storage',
        tone: 'neutral',
      ),
    ],
    promptSections: const [
      AskAiPromptSectionData(
        key: 'auction',
        title: 'Auction',
        content: 'Auction leaders kept a clean premium distribution.',
      ),
      AskAiPromptSectionData(
        key: 'review',
        title: 'Review',
        content: 'Review pressure stayed concentrated in late chasers.',
      ),
    ],
    systemPrompt: systemPrompt,
    userPrompt: userPrompt,
  );
}

class _FakeAskAiRepository extends AskAiRepository {
  _FakeAskAiRepository({
    required this.snapshot,
    required this.generatedResult,
    this.generateDelay = Duration.zero,
    this.streamChunks = const [],
    this.streamChunkDelay = Duration.zero,
    this.generateError,
  }) : super(ApiClient(baseUrl: 'https://api.example.invalid'));

  final AskAiContextSnapshot snapshot;
  final String generatedResult;
  final Duration generateDelay;
  final List<String> streamChunks;
  final Duration streamChunkDelay;
  final Object? generateError;
  AskAiSettings storedSettings = AskAiSettings.defaults();
  int fetchContextCalls = 0;
  int generateCalls = 0;
  int saveSettingsCalls = 0;
  List<AskAiPromptSectionData> lastPromptSections = const [];
  final List<AskAiSavedAnalysisEntry> _savedEntries = [];
  final Map<int, AskAiConversationSessionData> _sessionMap = {};

  @override
  Future<AskAiContextSnapshot> fetchContext() async {
    fetchContextCalls += 1;
    return snapshot;
  }

  @override
  Future<AskAiSettings> loadSettings() async {
    return storedSettings;
  }

  @override
  Future<void> saveSettings(AskAiSettings settings) async {
    saveSettingsCalls += 1;
    storedSettings = settings;
  }

  @override
  Future<AskAiUsageStatus> loadUsageStatus(AskAiSettings settings) async {
    return AskAiUsageStatus(
      providerLabel: settings.providerPreset.label,
      usedToday: 0,
      dailyLimit: settings.dailyLimit,
    );
  }

  @override
  Future<String> generateAnalysis({
    required AskAiSettings settings,
    required String systemPrompt,
    required String userPrompt,
    List<AskAiPromptSectionData> promptSections = const [],
    void Function(String chunk)? onChunk,
  }) async {
    generateCalls += 1;
    lastPromptSections = promptSections;
    if (onChunk != null && streamChunks.isNotEmpty) {
      for (final chunk in streamChunks) {
        if (streamChunkDelay > Duration.zero) {
          await Future<void>.delayed(streamChunkDelay);
        }
        onChunk(chunk);
      }
    }
    if (generateDelay > Duration.zero) {
      await Future<void>.delayed(generateDelay);
    }
    final error = generateError;
    if (error != null) {
      throw error;
    }
    return generatedResult;
  }

  @override
  Future<List<AskAiSavedAnalysisEntry>> loadSavedAnalyses() async {
    return List<AskAiSavedAnalysisEntry>.from(_savedEntries);
  }

  @override
  Future<AskAiConversationSessionData?> loadConversationSession(
    int sessionId,
  ) async {
    return _sessionMap[sessionId];
  }

  @override
  Future<void> saveAnalysis({
    required String? tradeDate,
    required String systemPrompt,
    required List<AskAiPromptSectionData> promptSections,
    required String userPrompt,
    required String result,
  }) async {
    final normalizedTradeDate = tradeDate == null || tradeDate.trim().isEmpty
        ? '1970-01-01'
        : tradeDate;
    final entry = AskAiSavedAnalysisEntry(
      sessionId: null,
      tradeDate: normalizedTradeDate,
      savedAt: '2026-04-18T10:00:00',
      systemPrompt: systemPrompt,
      promptSections: promptSections,
      userPrompt: userPrompt,
      result: result,
      source: 'flutter',
    );
    _savedEntries.removeWhere((item) => item.tradeDate == normalizedTradeDate);
    _savedEntries.insert(0, entry);
  }

  void seedSavedEntry(AskAiSavedAnalysisEntry entry) {
    _savedEntries.removeWhere((item) => item.tradeDate == entry.tradeDate);
    _savedEntries.insert(0, entry);
  }

  void seedConversationSession(AskAiConversationSessionData session) {
    _sessionMap[session.sessionId] = session;
  }
}
