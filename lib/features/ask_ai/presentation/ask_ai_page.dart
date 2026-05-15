import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/application/export_bundle_service.dart';
import '../../../shared/application/workspace_capture_service.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/ai_primary_action_button.dart';
import '../application/ask_ai_provider.dart';
import '../data/ask_ai_repository.dart';

class AskAiPage extends ConsumerStatefulWidget {
  const AskAiPage({super.key});

  @override
  ConsumerState<AskAiPage> createState() => _AskAiPageState();
}

class _AskAiPageState extends ConsumerState<AskAiPage> {
  static const _accent = Color(0xFF155EEF);
  static const _accentDeep = Color(0xFF0F2F68);
  static const _accentSoft = Color(0xFFEAF2FF);
  static const _accentWash = Color(0xFFF6FAFF);
  static const _analysisSurface = Color(0xFFF9FBFF);
  static const _successSoft = Color(0xFFE8F6EF);
  static const _warningSoft = Color(0xFFFFF4DF);
  static const _infoSoft = Color(0xFFEAF7FF);
  static const _dangerSoft = Color(0xFFFFECEC);

  final GlobalKey _captureKey = GlobalKey();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _dailyLimitController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _userPromptController = TextEditingController();
  Timer? _settingsSaveDebounce;

  AskAiProviderPreset _providerPreset = AskAiProviderPreset.backend;
  List<_ConversationEntry> _conversationEntries = const [];
  List<_ConversationEntry> _promptSequenceEntries = const [];

  bool _isSubmitting = false;
  bool _promptDirty = false;
  bool _suspendPromptDirty = false;
  bool _showAdvancedSettings = false;

  String? _seededTradeDate;
  String? _seededSnapshotKey;
  String? _seededSettingsKey;
  String? _analysisTradeDate;
  String? _autoRestoredAnalysisKey;
  String? _pendingAutoRestoreKey;
  String? _analysisText;
  String? _statusText;
  int _activePromptSequenceIndex = -1;
  int _completedPromptSequenceCount = 0;

  @override
  void initState() {
    super.initState();
    _systemPromptController.addListener(_markPromptDirty);
    _userPromptController.addListener(_markPromptDirty);
  }

  @override
  void dispose() {
    _flushPendingSettingsSave();
    _apiKeyController.dispose();
    _modelController.dispose();
    _dailyLimitController.dispose();
    _systemPromptController.dispose();
    _userPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contextAsync = ref.watch(askAiContextProvider);
    final settingsStateAsync = ref.watch(askAiSettingsStateProvider);
    final savedAnalysesAsync = ref.watch(askAiSavedAnalysesProvider);
    final settingsState = settingsStateAsync.asData?.value;
    final usageStatus = settingsState?.usageStatus;
    final settingsLoaded = settingsState != null;
    final savedAnalyses =
        savedAnalysesAsync.asData?.value ?? const <AskAiSavedAnalysisEntry>[];
    final savedAnalysesCountLabel =
        savedAnalysesAsync.hasValue ? '${savedAnalyses.length}' : '--';

    if (settingsState != null) {
      _maybeSeedSettings(settingsState.settings);
    }

    return AppShell(
      currentPath: '/ask-ai',
      title: '问AI',
      subtitle: '对齐旧版 niuniu_mvvm 的问 AI 工作台，保留提示词检查、昨日记录对照和本地结果归档。',
      child: contextAsync.when(
        data: (snapshot) {
          _maybeSeedSnapshot(snapshot);
          _maybeRestoreSavedAnalysis(snapshot, savedAnalyses);
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1380;
              return RepaintBoundary(
                key: _captureKey,
                child: ListView(
                  children: [
                    _buildSummaryCard(
                      context,
                      snapshot,
                      usageStatus: usageStatus,
                      savedAnalysesCountLabel: savedAnalysesCountLabel,
                      savedAnalyses: savedAnalyses,
                    ),
                    const SizedBox(height: 16),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              children: [
                                _buildWorkspacePanel(
                                  context,
                                  snapshot,
                                  usageStatus: usageStatus,
                                  settingsLoaded: settingsLoaded,
                                  savedAnalyses: savedAnalyses,
                                ),
                                const SizedBox(height: 16),
                                _buildTranscriptPanel(context, snapshot),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                _buildContextPanel(context, snapshot),
                                const SizedBox(height: 16),
                                _buildGuidePanel(context),
                                const SizedBox(height: 16),
                                _buildHistoryPanel(
                                  context,
                                  snapshot,
                                  savedAnalyses: savedAnalyses,
                                  isLoading: savedAnalysesAsync.isLoading &&
                                      !savedAnalysesAsync.hasValue,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildGuidePanel(context),
                      const SizedBox(height: 16),
                      _buildWorkspacePanel(
                        context,
                        snapshot,
                        usageStatus: usageStatus,
                        settingsLoaded: settingsLoaded,
                        savedAnalyses: savedAnalyses,
                      ),
                      const SizedBox(height: 16),
                      _buildTranscriptPanel(context, snapshot),
                      const SizedBox(height: 16),
                      _buildHistoryPanel(
                        context,
                        snapshot,
                        savedAnalyses: savedAnalyses,
                        isLoading: savedAnalysesAsync.isLoading &&
                            !savedAnalysesAsync.hasValue,
                      ),
                      const SizedBox(height: 16),
                      _buildContextPanel(context, snapshot),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, error),
      ),
    );
  }

  Future<void> _saveSettings({bool invalidateState = true}) async {
    _settingsSaveDebounce?.cancel();
    _settingsSaveDebounce = null;
    final settings = _buildSettingsFromInputs();
    final repository = ref.read(askAiRepositoryProvider);
    await repository.saveSettings(settings);
    if (invalidateState && mounted) {
      ref.invalidate(askAiSettingsStateProvider);
    }
  }

  void _scheduleSettingsSave({
    Duration delay = const Duration(milliseconds: 320),
  }) {
    _settingsSaveDebounce?.cancel();
    _settingsSaveDebounce = Timer(delay, () {
      _settingsSaveDebounce = null;
      unawaited(_saveSettings());
    });
  }

  void _flushPendingSettingsSave() {
    if (_settingsSaveDebounce == null) {
      return;
    }
    _settingsSaveDebounce!.cancel();
    _settingsSaveDebounce = null;
    unawaited(_saveSettings(invalidateState: false));
  }

  Future<void> _copyPrompt(AskAiContextSnapshot snapshot) async {
    final prompt = _formatPromptBundle(
      title: '今日提示词',
      tradeDate: snapshot.tradeDate,
      systemPrompt: _systemPromptController.text,
      promptSections: snapshot.promptSections,
      userPrompt: _userPromptController.text,
    );
    await _copyText(prompt, message: '提示词已复制。');
  }

  Future<void> _copyWorkspaceImage() async {
    final result = await captureWorkspaceImage(
      repaintBoundaryKey: _captureKey,
      context: context,
      bundleName: 'ask_ai_workspace',
      fileName: '问AI.png',
    );
    if (result == null) {
      _showSnackBar('当前工作区暂时无法生成图片。');
      return;
    }
    _showSnackBar(
      result.copiedToClipboard
          ? '问AI工作区图片已复制到剪贴板。'
          : '问AI工作区图片已导出：${result.filePath}',
    );
  }

  Future<void> _exportWorkspaceExcel(
    AskAiContextSnapshot snapshot,
    List<AskAiSavedAnalysisEntry> savedAnalyses,
  ) async {
    final files = _buildWorkspaceExportFiles(snapshot, savedAnalyses);
    final filePath = await writeExcelWorkbook(
      bundleName: 'ask_ai_workspace',
      fileName: '问AI.xlsx',
      sheets: files.entries
          .map((entry) => ExcelSheetData(name: entry.key, rows: entry.value))
          .toList(growable: false),
    );
    _showSnackBar('问AI Excel 已导出：$filePath');
  }

  Future<void> _exportWorkspaceCsv(
    AskAiContextSnapshot snapshot,
    List<AskAiSavedAnalysisEntry> savedAnalyses,
  ) async {
    final result = await writeCsvBundle(
      bundleName: 'ask_ai_workspace',
      files: _buildWorkspaceExportFiles(snapshot, savedAnalyses),
    );
    _showSnackBar('问AI CSV 已导出：${result.directoryPath}');
  }

  Map<String, List<List<String>>> _buildWorkspaceExportFiles(
    AskAiContextSnapshot snapshot,
    List<AskAiSavedAnalysisEntry> savedAnalyses,
  ) {
    return <String, List<List<String>>>{
      'summary': [
        ['trade_date', snapshot.tradeDate ?? '--'],
        ['generated_at', snapshot.generatedAt ?? '--'],
        ['prompt_sections', '${snapshot.promptSections.length}'],
        ['saved_analyses', '${savedAnalyses.length}'],
        ['status', _statusText ?? '准备就绪'],
      ],
      'cards': [
        ['key', 'label', 'value', 'tone'],
        ...snapshot.cards.map(
          (card) => [card.key, card.label, card.value, card.tone],
        ),
      ],
      'prompt_sections': [
        ['key', 'title', 'content'],
        ...snapshot.promptSections.map(
          (section) => [section.key, section.title, section.content],
        ),
      ],
      'prompt': [
        ['type', 'content'],
        ['system', _systemPromptController.text],
        ['user', _userPromptController.text],
      ],
      'analysis': [
        ['type', 'content'],
        ['current_result', _analysisText ?? ''],
      ],
      'history': [
        ['trade_date', 'saved_at', 'source', 'result'],
        ...savedAnalyses.map(
          (entry) => [
            entry.tradeDate,
            entry.savedAt,
            entry.source,
            entry.result,
          ],
        ),
      ],
    };
  }

  Future<void> _generateAnalysis(AskAiContextSnapshot snapshot) async {
    if (_isSubmitting) {
      return;
    }

    final settings = _buildSettingsFromInputs();
    final usageStatus = await ref.read(askAiRepositoryProvider).loadUsageStatus(
          settings,
        );
    if (!usageStatus.canSend) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = '${usageStatus.providerLabel} 已达到本地日调用上限。';
      });
      _showSnackBar('本地日调用上限已触发，请调整限额或切换模型。');
      return;
    }

    await ref.read(askAiRepositoryProvider).saveSettings(settings);

    final systemPrompt = _systemPromptController.text.trim();
    final userPrompt = _userPromptController.text.trim();
    final promptSections = snapshot.promptSections
        .where((section) => section.content.trim().isNotEmpty)
        .toList(growable: false);

    if (systemPrompt.isEmpty && userPrompt.isEmpty && promptSections.isEmpty) {
      _showSnackBar('提示词内容为空。');
      return;
    }

    final promptSequence = _conversationEntriesForBundle(
      systemPrompt: systemPrompt,
      promptSections: promptSections,
      userPrompt: userPrompt,
    );

    setState(() {
      _isSubmitting = true;
      _analysisText = null;
      _analysisTradeDate = snapshot.tradeDate;
      _statusText = '正在准备提示词发送序列...';
      _promptSequenceEntries = promptSequence;
      _activePromptSequenceIndex = -1;
      _completedPromptSequenceCount = 0;
      _conversationEntries = const [];
    });

    final repository = ref.read(askAiRepositoryProvider);

    try {
      await _replayPromptSequence(promptSequence);
      if (!mounted) {
        return;
      }

      setState(() {
        _conversationEntries = [
          ...promptSequence,
          const _ConversationEntry(
            role: _ConversationRole.assistant,
            title: '助手回复',
            content: '正在等待模型返回...',
          ),
        ];
        _statusText =
            '正在提交最终提示词（${promptSequence.length}/${promptSequence.length}）...';
      });

      final result = await repository.generateAnalysis(
        settings: settings,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        promptSections: promptSections,
        onChunk: _appendAssistantChunk,
      );
      await repository.recordUsage(settings);
      await repository.saveAnalysis(
        tradeDate: snapshot.tradeDate,
        systemPrompt: systemPrompt,
        promptSections: promptSections,
        userPrompt: userPrompt,
        result: result,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _analysisText = result;
        _analysisTradeDate = snapshot.tradeDate;
        _statusText = '分析结果已生成并保存到本地。';
        _activePromptSequenceIndex = -1;
        _completedPromptSequenceCount = _promptSequenceEntries.length;
        _replaceAssistantEntry(result, triggerSetState: false);
      });
      ref.invalidate(askAiSettingsStateProvider);
      ref.invalidate(askAiSavedAnalysesProvider);
      ref.invalidate(aiServerUsageStatusProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final msg = error.toString();
      if (msg.contains('429') || msg.contains('超过当日免费使用限制')) {
        ref.invalidate(aiServerUsageStatusProvider);
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('使用限制'),
            content: const Text('超过当日免费使用限制，请明天再试或配置个人 Kimi Key。'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        setState(() {
          _statusText = '超过当日免费使用限制';
          _isSubmitting = false;
        });
        return;
      }
      final failureMessage = _analysisFailureMessage(error);
      setState(() {
        _statusText = '生成失败：$error';
        _analysisText = failureMessage;
        _analysisTradeDate = snapshot.tradeDate;
        _activePromptSequenceIndex = -1;
        _completedPromptSequenceCount = _promptSequenceEntries.length;
        _replaceAssistantEntry(
          failureMessage,
          isError: true,
          triggerSetState: false,
        );
      });
      _showSnackBar('分析请求失败。');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _analysisFailureMessage(Object error) {
    final rawMessage = error.toString().replaceFirst('Bad state: ', '').trim();
    final message = rawMessage.isEmpty ? '模型请求失败，请稍后重试。' : rawMessage;
    final isTimeout = message.contains('超时') ||
        message.toLowerCase().contains('timeout') ||
        message.contains('502');
    final suggestion = isTimeout
        ? '右侧上下文数据已加载，但 Kimi 在本次请求时间内没有返回。可以稍后重试，或在服务设置中配置个人 Kimi Key 后再生成。'
        : '右侧上下文数据已加载，但服务端没有成功返回 AI 分析。请检查服务端日志或模型配置后重试。';
    return [
      '### AI 生成失败',
      '',
      message,
      '',
      suggestion,
    ].join('\n');
  }

  void _restoreServerPrompt(
    AskAiContextSnapshot snapshot, {
    bool silent = false,
  }) {
    _suspendPromptDirty = true;
    _systemPromptController.text = snapshot.systemPrompt;
    _userPromptController.text = snapshot.userPrompt;
    _suspendPromptDirty = false;

    setState(() {
      _promptDirty = false;
      _seededTradeDate = snapshot.tradeDate;
      _seededSnapshotKey = _snapshotKeyFor(snapshot);
      _promptSequenceEntries = const [];
      _activePromptSequenceIndex = -1;
      _completedPromptSequenceCount = 0;
      if (!silent) {
        _statusText = '已从当前上下文恢复提示词。';
      }
    });
  }

  Future<void> _loadSavedAnalysis(AskAiSavedAnalysisEntry entry) async {
    final repository = ref.read(askAiRepositoryProvider);
    final remoteSession = entry.sessionId == null
        ? null
        : await repository.loadConversationSession(entry.sessionId!);

    if (!mounted) {
      return;
    }

    final sessionResult = remoteSession == null
        ? entry.result
        : _analysisTextFromSession(remoteSession, fallback: entry.result);

    setState(() {
      _analysisText = sessionResult;
      _analysisTradeDate = entry.tradeDate;
      _statusText = remoteSession == null
          ? '已载入 ${entry.tradeDate} 的保存分析。'
          : '已载入 ${entry.tradeDate} 的历史会话。';
      _conversationEntries = remoteSession == null
          ? _conversationEntriesForBundle(
              systemPrompt: entry.systemPrompt,
              promptSections: entry.promptSections,
              userPrompt: entry.userPrompt,
              assistantReply: entry.result,
            )
          : _conversationEntriesFromSessionMessages(remoteSession.messages);
    });
  }

  Future<void> _copySavedAnalysis(AskAiSavedAnalysisEntry entry) async {
    await _copyText(entry.result, message: '保存记录已复制。');
  }

  Future<void> _showTodayPromptDialog(AskAiContextSnapshot snapshot) async {
    await _showPromptDialog(
      title: '今日提示词 - ${snapshot.tradeDate ?? '--'}',
      systemPrompt: _systemPromptController.text,
      promptSections: snapshot.promptSections,
      userPrompt: _userPromptController.text,
    );
  }

  Future<void> _showSavedPromptDialog({
    required String title,
    required String? tradeDate,
    required String systemPrompt,
    required List<AskAiPromptSectionData> promptSections,
    required String userPrompt,
  }) async {
    await _showPromptDialog(
      title: '$title - ${tradeDate ?? '--'}',
      systemPrompt: systemPrompt,
      promptSections: promptSections,
      userPrompt: userPrompt,
    );
  }

  void _markPromptDirty() {
    if (_suspendPromptDirty) {
      return;
    }
    if (_promptDirty) {
      return;
    }
    setState(() {
      _promptDirty = true;
      _promptSequenceEntries = const [];
      _activePromptSequenceIndex = -1;
      _completedPromptSequenceCount = 0;
    });
  }

  AskAiSettings _buildSettingsFromInputs() {
    return AskAiSettings(
      providerPreset: _providerPreset,
      model: _modelController.text.trim(),
      dailyLimit: _parseDailyLimit(_dailyLimitController.text),
      apiKey: _apiKeyController.text.trim(),
    );
  }

  int _parseDailyLimit(String rawValue) {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed < 0) {
      return _providerPreset.recommendedDailyLimit;
    }
    return parsed;
  }

  AskAiSavedAnalysisEntry? _previousSavedEntryFor(
    List<AskAiSavedAnalysisEntry> savedAnalyses,
    String? currentTradeDate,
  ) {
    if (savedAnalyses.isEmpty) {
      return null;
    }
    for (final entry in savedAnalyses) {
      if ((currentTradeDate ?? '').isEmpty ||
          entry.tradeDate != currentTradeDate) {
        return entry;
      }
    }
    return savedAnalyses.length >= 2 ? savedAnalyses[1] : null;
  }

  Future<void> _copyText(
    String text, {
    required String message,
  }) async {
    if (text.trim().isEmpty) {
      _showSnackBar('没有可复制的内容。');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _clearConversation() {
    setState(() {
      _conversationEntries = const [];
      _promptSequenceEntries = const [];
      _activePromptSequenceIndex = -1;
      _completedPromptSequenceCount = 0;
      _analysisText = null;
      _analysisTradeDate = null;
      _statusText = '对话记录已清空。';
    });
  }

  Future<void> _replayPromptSequence(List<_ConversationEntry> sequence) async {
    if (sequence.isEmpty) {
      return;
    }

    for (var index = 0; index < sequence.length; index += 1) {
      if (!mounted) {
        return;
      }

      final segment = sequence[index];
      setState(() {
        _activePromptSequenceIndex = index;
        _completedPromptSequenceCount = index;
        _conversationEntries = sequence.take(index + 1).toList(growable: false);
        _statusText = index == sequence.length - 1
            ? '正在提交最终提示词（${index + 1}/${sequence.length}）：${segment.title}。'
            : '正在发送第 ${index + 1}/${sequence.length} 段提示词：${segment.title}。';
      });

      await Future<void>.delayed(const Duration(milliseconds: 24));
    }
  }

  void _replaceAssistantEntry(
    String content, {
    bool isError = false,
    bool triggerSetState = true,
  }) {
    final nextEntries = List<_ConversationEntry>.from(_conversationEntries);
    if (nextEntries.isNotEmpty &&
        (nextEntries.last.role == _ConversationRole.assistant ||
            nextEntries.last.role == _ConversationRole.error)) {
      nextEntries.removeLast();
    }
    nextEntries.add(
      _ConversationEntry(
        role: isError ? _ConversationRole.error : _ConversationRole.assistant,
        title: isError ? '助手错误' : '助手回复',
        content: content,
      ),
    );

    if (!triggerSetState) {
      _conversationEntries = nextEntries;
      return;
    }

    setState(() {
      _conversationEntries = nextEntries;
    });
  }

  void _appendAssistantChunk(String chunk) {
    if (!mounted || chunk.isEmpty) {
      return;
    }

    final nextEntries = List<_ConversationEntry>.from(_conversationEntries);
    var currentAssistantText = chunk;

    if (nextEntries.isNotEmpty &&
        nextEntries.last.role == _ConversationRole.assistant) {
      final previous = nextEntries.removeLast();
      final previousContent =
          previous.content == '正在等待模型返回...' ? '' : previous.content;
      currentAssistantText = '$previousContent$chunk';
    }

    nextEntries.add(
      _ConversationEntry(
        role: _ConversationRole.assistant,
        title: '助手回复',
        content: currentAssistantText,
      ),
    );

    setState(() {
      _analysisText = currentAssistantText;
      _statusText = '正在接收模型流式返回...';
      _conversationEntries = nextEntries;
    });
  }

  void _maybeSeedSettings(AskAiSettings settings) {
    final settingsKey = _settingsKeyFor(settings);
    if (_seededSettingsKey == settingsKey) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _seededSettingsKey == settingsKey) {
        return;
      }
      _setControllerText(_apiKeyController, settings.apiKey);
      _setControllerText(_modelController, settings.model);
      _setControllerText(_dailyLimitController, '${settings.dailyLimit}');
      setState(() {
        _providerPreset = settings.providerPreset;
        _seededSettingsKey = settingsKey;
      });
    });
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _maybeSeedSnapshot(AskAiContextSnapshot snapshot) {
    final snapshotKey = _snapshotKeyFor(snapshot);
    final shouldSeed = _seededTradeDate != snapshot.tradeDate ||
        (!_promptDirty && _seededSnapshotKey != snapshotKey);
    if (!shouldSeed) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _restoreServerPrompt(snapshot, silent: true);
    });
  }

  void _maybeRestoreSavedAnalysis(
    AskAiContextSnapshot snapshot,
    List<AskAiSavedAnalysisEntry> savedAnalyses,
  ) {
    if (_isSubmitting) {
      return;
    }
    final entry = _currentSavedEntryFor(savedAnalyses, snapshot.tradeDate);
    if (entry == null || entry.result.trim().isEmpty) {
      return;
    }

    final restoreKey = _savedAnalysisKeyFor(entry);
    if (_pendingAutoRestoreKey == restoreKey) {
      return;
    }
    final currentResult = (_analysisText ?? '').trim();
    if (currentResult.isNotEmpty && _analysisTradeDate == entry.tradeDate) {
      _autoRestoredAnalysisKey = restoreKey;
      return;
    }
    if (_autoRestoredAnalysisKey == restoreKey && currentResult.isNotEmpty) {
      return;
    }

    _pendingAutoRestoreKey = restoreKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_isSubmitting) {
        _pendingAutoRestoreKey = null;
        return;
      }
      final visibleResult = (_analysisText ?? '').trim();
      if (visibleResult.isNotEmpty && _analysisTradeDate == entry.tradeDate) {
        _autoRestoredAnalysisKey = restoreKey;
        _pendingAutoRestoreKey = null;
        return;
      }
      setState(() {
        _analysisText = entry.result.trim();
        _analysisTradeDate = entry.tradeDate;
        _statusText = '已恢复 ${entry.tradeDate} 的上次 AI 分析。';
        _conversationEntries = _conversationEntriesForBundle(
          systemPrompt: entry.systemPrompt,
          promptSections: entry.promptSections,
          userPrompt: entry.userPrompt,
          assistantReply: entry.result,
        );
        _promptSequenceEntries = const [];
        _activePromptSequenceIndex = -1;
        _completedPromptSequenceCount = 0;
        _autoRestoredAnalysisKey = restoreKey;
        _pendingAutoRestoreKey = null;
      });
    });
  }

  AskAiSavedAnalysisEntry? _currentSavedEntryFor(
    List<AskAiSavedAnalysisEntry> savedAnalyses,
    String? currentTradeDate,
  ) {
    final normalizedTradeDate = (currentTradeDate ?? '').trim();
    if (normalizedTradeDate.isEmpty) {
      return null;
    }
    for (final entry in savedAnalyses) {
      if (entry.tradeDate == normalizedTradeDate &&
          entry.result.trim().isNotEmpty) {
        return entry;
      }
    }
    return null;
  }

  String _savedAnalysisKeyFor(AskAiSavedAnalysisEntry entry) {
    return [
      entry.tradeDate,
      entry.savedAt,
      entry.sessionId ?? 'local',
      entry.result.hashCode,
    ].join('|');
  }

  String _snapshotKeyFor(AskAiContextSnapshot snapshot) {
    return '${snapshot.tradeDate ?? '--'}|${snapshot.generatedAt ?? '--'}';
  }

  String _settingsKeyFor(AskAiSettings settings) {
    return '${settings.providerPreset.storageValue}|'
        '${settings.model}|'
        '${settings.dailyLimit}|'
        '${settings.hasPersonalApiKey ? settings.apiKey.hashCode : 'public'}';
  }

  List<_ConversationEntry> _conversationEntriesForBundle({
    required String systemPrompt,
    required List<AskAiPromptSectionData> promptSections,
    required String userPrompt,
    String? assistantReply,
  }) {
    final entries = <_ConversationEntry>[];

    if (systemPrompt.trim().isNotEmpty) {
      entries.add(
        _ConversationEntry(
          role: _ConversationRole.system,
          title: '系统提示',
          content: systemPrompt.trim(),
        ),
      );
    }

    for (final section in promptSections) {
      if (section.content.trim().isEmpty) {
        continue;
      }
      entries.add(
        _ConversationEntry(
          role: _ConversationRole.context,
          title: section.title,
          content: section.content.trim(),
        ),
      );
    }

    if (userPrompt.trim().isNotEmpty) {
      entries.add(
        _ConversationEntry(
          role: _ConversationRole.user,
          title: '最终用户问题',
          content: userPrompt.trim(),
        ),
      );
    }

    if ((assistantReply ?? '').trim().isNotEmpty) {
      entries.add(
        _ConversationEntry(
          role: _ConversationRole.assistant,
          title: '助手回复',
          content: assistantReply!.trim(),
        ),
      );
    }

    return entries;
  }

  List<_ConversationEntry> _conversationEntriesFromSessionMessages(
    List<AskAiSessionMessageData> messages,
  ) {
    return messages
        .where((message) => message.content.trim().isNotEmpty)
        .map(
          (message) => _ConversationEntry(
            role: _conversationRoleFromApi(message.role),
            title: message.title,
            content: message.content,
          ),
        )
        .toList(growable: false);
  }

  String _analysisTextFromSession(
    AskAiConversationSessionData session, {
    required String fallback,
  }) {
    for (final message in session.messages.reversed) {
      final role = message.role.trim().toLowerCase();
      if ((role == 'assistant' || role == 'error') &&
          message.content.trim().isNotEmpty) {
        return message.content.trim();
      }
    }
    if (session.result.trim().isNotEmpty) {
      return session.result.trim();
    }
    return fallback;
  }

  List<_ConversationEntry> _promptSequencePreviewEntries(
    AskAiContextSnapshot snapshot,
  ) {
    if (_promptSequenceEntries.isNotEmpty) {
      return _promptSequenceEntries;
    }
    return _conversationEntriesForBundle(
      systemPrompt: _systemPromptController.text,
      promptSections: snapshot.promptSections,
      userPrompt: _userPromptController.text,
    );
  }

  _ConversationRole _conversationRoleFromApi(String rawRole) {
    switch (rawRole.trim().toLowerCase()) {
      case 'system':
        return _ConversationRole.system;
      case 'user':
        return _ConversationRole.user;
      case 'assistant':
        return _ConversationRole.assistant;
      case 'error':
        return _ConversationRole.error;
      default:
        return _ConversationRole.context;
    }
  }

  String _formatPromptBundle({
    required String title,
    required String? tradeDate,
    required String systemPrompt,
    required List<AskAiPromptSectionData> promptSections,
    required String userPrompt,
  }) {
    final header = tradeDate == null || tradeDate.trim().isEmpty
        ? title
        : '$title - $tradeDate';
    final buffer = StringBuffer()
      ..writeln(header)
      ..writeln()
      ..writeln('系统提示')
      ..writeln(systemPrompt.trim())
      ..writeln();

    for (final section in promptSections) {
      buffer
        ..writeln(section.title)
        ..writeln(section.content.trim())
        ..writeln();
    }

    buffer
      ..writeln('最终用户问题')
      ..writeln(userPrompt.trim());
    return buffer.toString().trim();
  }

  Future<void> _showPromptDialog({
    required String title,
    required String systemPrompt,
    required List<AskAiPromptSectionData> promptSections,
    required String userPrompt,
  }) async {
    final promptText = _formatPromptBundle(
      title: title,
      tradeDate: null,
      systemPrompt: systemPrompt,
      promptSections: promptSections,
      userPrompt: userPrompt,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 680,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPromptDialogSection(
                        dialogContext,
                        title: '系统提示',
                        body: systemPrompt,
                      ),
                      for (final section in promptSections)
                        _buildPromptDialogSection(
                          dialogContext,
                          title: section.title,
                          body: section.content,
                        ),
                      _buildPromptDialogSection(
                        dialogContext,
                        title: '最终用户问题',
                        body: userPrompt,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => _copyText(promptText, message: '提示词已复制。'),
              child: const Text('复制'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPromptDialogSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final theme = Theme.of(context);
    final normalized = body.trim().isEmpty ? '--' : body.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(normalized, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    AskAiContextSnapshot snapshot, {
    required AskAiUsageStatus? usageStatus,
    required String savedAnalysesCountLabel,
    required List<AskAiSavedAnalysisEntry> savedAnalyses,
  }) {
    final theme = Theme.of(context);
    final generatedAt = snapshot.generatedAt ?? '--';

    return Card(
      child: Container(
        decoration: BoxDecoration(
          color: _analysisSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _accent.withValues(alpha: 0.16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '问AI工作台',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: _accentDeep,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '当前页按旧版问 AI 组件重新拆成提示、对话、历史三块工作区。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Semantics(
                        button: true,
                        label: 'pw-ask-ai-refresh-context',
                        child: FilledButton.tonalIcon(
                          onPressed: () => ref.invalidate(askAiContextProvider),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('刷新上下文'),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _copyWorkspaceImage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.22),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.72),
                        ),
                        icon: const Icon(Icons.image_rounded),
                        label: const Text('复制图片'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _exportWorkspaceExcel(
                          snapshot,
                          savedAnalyses,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.22),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.72),
                        ),
                        icon: const Icon(Icons.table_chart_rounded),
                        label: const Text('导出 Excel'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _exportWorkspaceCsv(
                          snapshot,
                          savedAnalyses,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.22),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.72),
                        ),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('导出 CSV'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _analysisText == null
                            ? null
                            : () => _copyText(
                                  _analysisText!,
                                  message: '分析结果已复制。',
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.22),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.72),
                        ),
                        icon: const Icon(Icons.copy_all_rounded),
                        label: const Text('复制结果'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildMetricTile(
                    context,
                    label: '当前交易日',
                    value: snapshot.tradeDate ?? '--',
                    caption: '本次快照交易日',
                  ),
                  _buildMetricTile(
                    context,
                    label: '生成时间',
                    value: _formatTimestamp(generatedAt),
                    caption: '上下文快照时间',
                  ),
                  _buildMetricTile(
                    context,
                    label: '提示词分段',
                    value: '${snapshot.promptSections.length}',
                    caption: '今日打包段落数',
                  ),
                  _buildMetricTile(
                    context,
                    label: '已保存记录',
                    value: savedAnalysesCountLabel,
                    caption: '本地缓存条目数',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (usageStatus != null)
                    _buildUsageChip(context, usageStatus),
                  for (final card in snapshot.cards)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _toneColor(card.tone).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _toneColor(card.tone).withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            card.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.mutedText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            card.value,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppTheme.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidePanel(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('使用说明与风险', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _statusText ?? '准备就绪。先检查提示词包，再决定是否发给模型。',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            _buildNoticeBlock(
              context,
              accent: AppTheme.secondary,
              background: _warningSoft,
              title: '风险提醒',
              body: 'AI 输出只作为复盘和预案辅助，不构成交易建议。高位分歧、炸板和监管变化仍需你自己判断。',
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 12),
            _buildNoticeBlock(
              context,
              accent: AppTheme.primary,
              background: _infoSoft,
              title: '阅读顺序',
              body: '优先阅读 AI 结果。提示词和上下文只保留在按钮弹窗里，用来核对请求来源。',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildNoticeBlock(
              context,
              accent: AppTheme.mutedText,
              background: _accentSoft,
              title: '阶段偏向',
              body: '情绪启动期可以偏进攻，高潮期关注兑现，退潮期优先控制回撤。这里的提示用于约束 AI 语气，不替代盘面判断。',
              icon: Icons.insights_rounded,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearConversation,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('清空对话'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextPanel(
    BuildContext context,
    AskAiContextSnapshot snapshot,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('上下文包', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        '保留关键快照。完整提示词只在弹窗里查看，不占用结果阅读空间。',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showTodayPromptDialog(snapshot),
                  icon: const Icon(Icons.rule_folder_rounded),
                  label: const Text('查看提示词'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.cards.isNotEmpty) ...[
              Text('快照卡片', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: snapshot.cards
                    .map(
                      (card) => Container(
                        width: 160,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.label,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              card.value,
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 18),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '已装载 ${snapshot.promptSections.length} 段上下文，生成时由服务端统一发给 Kimi。',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => _copyPrompt(snapshot),
                    child: const Text('复制'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspacePanel(
    BuildContext context,
    AskAiContextSnapshot snapshot, {
    required AskAiUsageStatus? usageStatus,
    required bool settingsLoaded,
    required List<AskAiSavedAnalysisEntry> savedAnalyses,
  }) {
    final theme = Theme.of(context);
    final previousEntry =
        _previousSavedEntryFor(savedAnalyses, snapshot.tradeDate);

    return Card(
      child: Container(
        decoration: BoxDecoration(
          color: _accentWash,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI 分析', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          '提示词和上下文收进弹窗，主界面只保留生成、设置和结果阅读。',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (usageStatus != null)
                    _buildUsageChip(context, usageStatus),
                ],
              ),
              const SizedBox(height: 14),
              AiActionGroup(
                primary: AiPrimaryActionButton(
                  onPressed: !settingsLoaded || _isSubmitting
                      ? null
                      : () => _generateAnalysis(snapshot),
                  loading: _isSubmitting,
                  loadingLabel: '生成中',
                  label: '生成分析',
                  tooltip: settingsLoaded ? '使用当前系统上下文生成 AI 分析' : 'AI 服务配置加载中',
                  minWidth: 206,
                  height: 58,
                  remainingUses: ref
                      .watch(aiServerUsageStatusProvider)
                      .valueOrNull
                      ?.feature('ask_ai')
                      ?.remaining,
                  totalLimit: ref
                      .watch(aiServerUsageStatusProvider)
                      .valueOrNull
                      ?.feature('ask_ai')
                      ?.limit,
                ),
                children: [
                  AiSecondaryActionButton(
                    onPressed: () => _showTodayPromptDialog(snapshot),
                    icon: Icons.rule_folder_rounded,
                    label: '查看今日提示词',
                  ),
                  AiSecondaryActionButton(
                    onPressed: () => _copyPrompt(snapshot),
                    icon: Icons.content_copy_rounded,
                    label: '复制提示词',
                  ),
                  AiSecondaryActionButton(
                    onPressed: previousEntry == null
                        ? null
                        : () => _showSavedPromptDialog(
                              title: '昨日提示词',
                              tradeDate: previousEntry.tradeDate,
                              systemPrompt: previousEntry.systemPrompt,
                              promptSections: previousEntry.promptSections,
                              userPrompt: previousEntry.userPrompt,
                            ),
                    icon: Icons.history_edu_rounded,
                    label: '查看昨日提示词',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accent.withValues(alpha: 0.14)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSubmitting
                          ? Icons.sync_rounded
                          : Icons.check_circle_outline_rounded,
                      color: _isSubmitting ? _accent : AppTheme.success,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusText ?? '等待生成。结果会以 Markdown 阅读版式显示在下方。',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${snapshot.promptSections.length} 段上下文',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildServiceSettingsPanel(
                context,
                usageStatus: usageStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptSequencePanel(
    BuildContext context,
    AskAiContextSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    final entries = _promptSequencePreviewEntries(snapshot);
    final total = entries.length;
    final progressCount = total == 0
        ? 0
        : _activePromptSequenceIndex >= 0
            ? _activePromptSequenceIndex + 1
            : _completedPromptSequenceCount.clamp(0, total);
    final progressValue = total == 0 ? 0.0 : progressCount / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _accentSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('发送顺序', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '旧版 AskAI 会把上下文按段推入对话历史，这里固定展示本次请求的发送顺序和当前进度。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (total > 0)
                Text(
                  _isSubmitting
                      ? '$progressCount/$total 发送中'
                      : _completedPromptSequenceCount >= total &&
                              _promptSequenceEntries.isNotEmpty
                          ? '$total/$total 已完成'
                          : '$total 待发送',
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              color: _accent,
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              '提示词包准备完成后，这里会显示发送顺序预览。',
              style: theme.textTheme.bodyLarge,
            )
          else
            Column(
              children: [
                for (var index = 0; index < entries.length; index += 1) ...[
                  _buildPromptSequenceCard(
                    context,
                    entry: entries[index],
                    index: index,
                    total: entries.length,
                  ),
                  if (index != entries.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTranscriptPanel(
    BuildContext context,
    AskAiContextSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    final resultText = (_analysisText ?? '').trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI 结果', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        '模型返回内容按 Markdown 渲染，标题、列表、表格和代码块会按阅读版式展示。',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _analysisText == null
                      ? null
                      : () => _copyText(
                            _analysisText!,
                            message: '分析结果已复制。',
                          ),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('复制结果'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 460),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _analysisSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accent.withValues(alpha: 0.18)),
              ),
              child: resultText.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 34,
                            color: _accent.withValues(alpha: 0.72),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isSubmitting ? '正在等待模型返回...' : '生成后，AI 结果会显示在这里。',
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : _buildMarkdownContent(
                      context,
                      resultText,
                      minHeight: 380,
                    ),
            ),
            if (_conversationEntries.isNotEmpty) ...[
              const SizedBox(height: 14),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('请求链路', style: theme.textTheme.titleMedium),
                subtitle: Text(
                  '需要核对提示词发送顺序时再展开。',
                  style: theme.textTheme.bodyMedium,
                ),
                children: [
                  const SizedBox(height: 10),
                  _buildPromptSequencePanel(context, snapshot),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        child: Column(
                          children: _conversationEntries
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildConversationCard(context, entry),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPanel(
    BuildContext context,
    AskAiContextSnapshot snapshot, {
    required List<AskAiSavedAnalysisEntry> savedAnalyses,
    required bool isLoading,
  }) {
    final theme = Theme.of(context);
    final previousEntry =
        _previousSavedEntryFor(savedAnalyses, snapshot.tradeDate);

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '昨日参考',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            previousEntry == null
                                ? '还没有上一交易日的本地记录。'
                                : '最近一条非当前交易日记录会固定显示在这里，方便横向对照。',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (previousEntry != null)
                      OutlinedButton(
                        onPressed: () => _showSavedPromptDialog(
                          title: '昨日提示词',
                          tradeDate: previousEntry.tradeDate,
                          systemPrompt: previousEntry.systemPrompt,
                          promptSections: previousEntry.promptSections,
                          userPrompt: previousEntry.userPrompt,
                        ),
                        child: const Text('打开昨日提示词'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (previousEntry == null)
                  Text(
                    '先生成并保存今日分析，下一交易日这里会自动显示上一条记录。',
                    style: theme.textTheme.bodyLarge,
                  )
                else
                  _buildSavedEntryCard(
                    context,
                    entry: previousEntry,
                    emphasize: true,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最近保存的分析', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '本地缓存最多保留 7 条，用来替代旧版桌面端的昨日 AI 预期面板。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  Text(
                    '正在加载保存记录...',
                    style: theme.textTheme.bodyLarge,
                  )
                else if (savedAnalyses.isEmpty)
                  Text(
                    '当前还没有保存记录。生成一次分析后会自动缓存在本地。',
                    style: theme.textTheme.bodyLarge,
                  )
                else
                  SizedBox(
                    height: 560,
                    child: Scrollbar(
                      child: ListView.separated(
                        itemBuilder: (context, index) => _buildSavedEntryCard(
                          context,
                          entry: savedAnalyses[index],
                        ),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: savedAnalyses.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '问AI请求失败：$error',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(askAiContextProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required String caption,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.mutedText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageChip(BuildContext context, AskAiUsageStatus usageStatus) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: usageStatus.canSend ? _successSoft : _dangerSoft,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: usageStatus.canSend
              ? AppTheme.success.withValues(alpha: 0.20)
              : AppTheme.danger.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '用量',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.mutedText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _usageSummaryText(usageStatus),
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBlock(
    BuildContext context, {
    required Color accent,
    required Color background,
    required String title,
    required String body,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(body, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(
    BuildContext context,
    String data, {
    double? minHeight,
  }) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      child: SelectionArea(
        child: MarkdownBody(
          data: data.trim(),
          styleSheet: _markdownStyleSheet(theme),
          softLineBreak: true,
        ),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyleSheet(ThemeData theme) {
    final base = MarkdownStyleSheet.fromTheme(theme);
    return base.copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(
        height: 1.65,
        color: AppTheme.text,
      ),
      h1: theme.textTheme.headlineSmall?.copyWith(
        fontSize: 22,
        height: 1.35,
        color: AppTheme.text,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        fontSize: 18,
        height: 1.45,
        color: AppTheme.text,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.45,
        color: AppTheme.text,
      ),
      strong: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppTheme.text,
      ),
      listBullet: theme.textTheme.bodyLarge?.copyWith(
        color: _accent,
        height: 1.55,
      ),
      blockquote: theme.textTheme.bodyLarge?.copyWith(
        color: AppTheme.mutedText,
        height: 1.6,
      ),
      blockquoteDecoration: BoxDecoration(
        color: _accentSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: _accent.withValues(alpha: 0.45),
            width: 4,
          ),
        ),
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        color: AppTheme.text,
        backgroundColor: AppTheme.neutralSoft,
        fontFamily: 'Consolas',
        fontFamilyFallback: const ['Microsoft YaHei UI', 'Arial'],
      ),
      codeblockDecoration: BoxDecoration(
        color: AppTheme.neutralSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      tableHead: theme.textTheme.titleMedium?.copyWith(color: AppTheme.text),
      tableBody: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.text),
      tableBorder: TableBorder.all(
        color: theme.colorScheme.outlineVariant,
        width: 1,
      ),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildConversationCard(
    BuildContext context,
    _ConversationEntry entry,
  ) {
    final theme = Theme.of(context);
    final accent = _roleAccent(entry.role);
    final background = accent.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: theme.textTheme.titleMedium?.copyWith(color: accent),
          ),
          const SizedBox(height: 8),
          entry.role == _ConversationRole.assistant
              ? _buildMarkdownContent(context, entry.content)
              : Text(entry.content, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildPromptSequenceCard(
    BuildContext context, {
    required _ConversationEntry entry,
    required int index,
    required int total,
  }) {
    final theme = Theme.of(context);
    final roleAccent = _roleAccent(entry.role);
    final statusAccent = _promptSequenceStatusAccent(index, total);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: roleAccent.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: roleAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('${index + 1}', style: theme.textTheme.labelLarge),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            _promptSequenceRoleLabel(entry.role),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: roleAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _promptSequenceStatusLabel(index, total),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: statusAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _promptSequenceExcerpt(entry.content),
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedEntryCard(
    BuildContext context, {
    required AskAiSavedAnalysisEntry entry,
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: emphasize ? _accentSoft : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.tradeDate,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(entry.savedAt),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: entry.sessionId == null
                          ? AppTheme.secondary.withValues(alpha: 0.10)
                          : AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.sessionId == null
                          ? '本地摘要'
                          : '会话 #${entry.sessionId}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _displaySessionSource(entry.source),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Semantics(
                    button: true,
                    label: entry.sessionId == null
                        ? 'pw-ask-ai-load-local-${entry.tradeDate}'
                        : 'pw-ask-ai-load-session-${entry.sessionId}',
                    child: OutlinedButton(
                      onPressed: () => _loadSavedAnalysis(entry),
                      child: const Text('载入记录'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _showSavedPromptDialog(
                      title: '已保存提示词',
                      tradeDate: entry.tradeDate,
                      systemPrompt: entry.systemPrompt,
                      promptSections: entry.promptSections,
                      userPrompt: entry.userPrompt,
                    ),
                    child: const Text('查看提示词'),
                  ),
                  OutlinedButton(
                    onPressed: () => _copySavedAnalysis(entry),
                    child: const Text('复制'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMarkdownContent(context, entry.result),
        ],
      ),
    );
  }

  String _usageSummaryText(AskAiUsageStatus? usageStatus) {
    if (usageStatus == null) {
      return '正在加载用量状态...';
    }
    final providerLabel = _displayProviderLabel(usageStatus.providerLabel);
    if (usageStatus.isUnlimited) {
      return '$providerLabel：今日已用 ${usageStatus.usedToday} 次，不设本地上限。';
    }
    return '$providerLabel：今日已用 ${usageStatus.usedToday}/${usageStatus.dailyLimit} 次，剩余 ${usageStatus.remaining} 次。';
  }

  Widget _buildServiceSettingsPanel(
    BuildContext context, {
    required AskAiUsageStatus? usageStatus,
  }) {
    final theme = Theme.of(context);
    final statusColor =
        usageStatus?.canSend == false ? AppTheme.danger : AppTheme.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: usageStatus?.canSend == false ? _dangerSoft : _successSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 34,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('服务状态', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      _usageSummaryText(usageStatus),
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '留空使用服务端公共 Kimi 试用额度；填写个人 Key 后仅本机保存，并由后端代发请求。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAdvancedSettings = !_showAdvancedSettings;
                  });
                },
                icon: Icon(
                  _showAdvancedSettings
                      ? Icons.expand_less_rounded
                      : Icons.tune_rounded,
                ),
                label: Text(_showAdvancedSettings ? '收起设置' : '服务设置'),
              ),
            ],
          ),
          if (_showAdvancedSettings) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth >= 1080
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth >= 760
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '个人 Kimi Key',
                          helperText: '留空使用服务端公共试用额度',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _scheduleSettingsSave(),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: '模型',
                          helperText: '留空使用服务端配置',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _scheduleSettingsSave(),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _dailyLimitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '本地日上限',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _scheduleSettingsSave(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _displayProviderLabel(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '后端统一 AI 服务' : trimmed;
  }

  String _displaySessionSource(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'flutter' => '本地记录',
      'server' => '服务端记录',
      'api' => '接口记录',
      'local' => '本地记录',
      _ => value.trim().isEmpty ? '记录来源未知' : value.trim(),
    };
  }

  Color _toneColor(String tone) {
    switch (tone.trim().toLowerCase()) {
      case 'risk':
      case 'warning':
        return AppTheme.secondary;
      case 'positive':
      case 'rise':
        return AppTheme.rise;
      case 'negative':
      case 'fall':
        return AppTheme.fall;
      case 'info':
        return AppTheme.primary;
      default:
        return _accent;
    }
  }

  Color _roleAccent(_ConversationRole role) {
    switch (role) {
      case _ConversationRole.system:
        return AppTheme.secondary;
      case _ConversationRole.context:
        return AppTheme.primary;
      case _ConversationRole.user:
        return _accent;
      case _ConversationRole.assistant:
        return AppTheme.rise;
      case _ConversationRole.error:
        return AppTheme.danger;
    }
  }

  String _promptSequenceRoleLabel(_ConversationRole role) {
    switch (role) {
      case _ConversationRole.system:
        return '系统提示';
      case _ConversationRole.context:
        return '上下文片段';
      case _ConversationRole.user:
        return '最终请求';
      case _ConversationRole.assistant:
        return '助手回复';
      case _ConversationRole.error:
        return '错误回复';
    }
  }

  String _promptSequenceStatusLabel(int index, int total) {
    if (_activePromptSequenceIndex == index) {
      return index == total - 1 ? '最终请求' : '发送中';
    }
    if (_completedPromptSequenceCount > index) {
      return '已发送';
    }
    return '待发送';
  }

  Color _promptSequenceStatusAccent(int index, int total) {
    if (_activePromptSequenceIndex == index) {
      return index == total - 1 ? _accent : AppTheme.primary;
    }
    if (_completedPromptSequenceCount > index) {
      return _accent;
    }
    return AppTheme.mutedText;
  }

  String _promptSequenceExcerpt(String content) {
    final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 96) {
      return normalized;
    }
    return '${normalized.substring(0, 96)}...';
  }

  String _formatTimestamp(String rawValue) {
    final parsed = DateTime.tryParse(rawValue);
    if (parsed == null) {
      return rawValue;
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day $hour:$minute';
  }
}

enum _ConversationRole {
  system,
  context,
  user,
  assistant,
  error,
}

class _ConversationEntry {
  const _ConversationEntry({
    required this.role,
    required this.title,
    required this.content,
  });

  final _ConversationRole role;
  final String title;
  final String content;
}
