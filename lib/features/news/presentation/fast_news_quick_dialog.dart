import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/data/market_api_provider.dart';
import '../../../shared/data/market_api_repository.dart';

class FastNewsQuickDialog extends ConsumerStatefulWidget {
  const FastNewsQuickDialog({
    super.key,
    required this.onOpenFullPage,
  });

  final VoidCallback onOpenFullPage;

  @override
  ConsumerState<FastNewsQuickDialog> createState() =>
      _FastNewsQuickDialogState();
}

class _FastNewsQuickDialogState extends ConsumerState<FastNewsQuickDialog> {
  static const _refreshInterval = Duration(seconds: 10);

  late final TextEditingController _keywordController;

  FeedSnapshot? _snapshot;
  Timer? _refreshTimer;
  String _keyword = '';
  String? _errorMessage;
  bool _importantOnly = false;
  bool _autoRefresh = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController();
    _restartTimer();
    _loadSnapshot();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = _snapshot;
    final items = snapshot == null
        ? const <FeedItemData>[]
        : _filterFastNews(
            snapshot.items,
            _keyword,
            _importantOnly,
          );
    final quickKeywords =
        snapshot == null ? const <String>[] : _extractQuickKeywords(snapshot);
    final importantCount = snapshot == null
        ? 0
        : snapshot.items.where((item) => item.isImportant).length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Align(
          alignment: Alignment.topRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 450,
              minWidth: 380,
              maxHeight: 760,
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.outlineStrong),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A17212B),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppTheme.outline),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.flash_on_rounded,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '消息中心 / 7x24',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppTheme.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  snapshot == null
                                      ? (_isRefreshing
                                          ? '正在加载最新快讯...'
                                          : '快讯速览窗口')
                                      : '快照 ${_formatStamp(snapshot.fetchedAt) ?? '--'}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '打开完整页面',
                            onPressed: widget.onOpenFullPage,
                            icon: const Icon(Icons.open_in_new_rounded),
                            color: AppTheme.mutedText,
                          ),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: AppTheme.mutedText,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _keywordController,
                                  onChanged: (value) {
                                    setState(() {
                                      _keyword = value;
                                    });
                                  },
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.text,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '关键词或股票代码',
                                    hintStyle:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.mutedText,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: AppTheme.mutedText,
                                    ),
                                    suffixIcon: _keyword.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () {
                                              _keywordController.clear();
                                              setState(() {
                                                _keyword = '';
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: AppTheme.mutedText,
                                            ),
                                          ),
                                    filled: true,
                                    fillColor: AppTheme.surfaceSoft,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppTheme.outline,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppTheme.outline,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: '立即刷新',
                                onPressed: _loadSnapshot,
                                icon: _isRefreshing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                selected: _importantOnly,
                                showCheckmark: false,
                                onSelected: (selected) {
                                  setState(() {
                                    _importantOnly = selected;
                                  });
                                },
                                label: const Text('仅看重点'),
                                avatar: const Icon(
                                  Icons.notifications_active_rounded,
                                  size: 18,
                                ),
                              ),
                              FilterChip(
                                selected: _autoRefresh,
                                showCheckmark: false,
                                onSelected: (selected) {
                                  setState(() {
                                    _autoRefresh = selected;
                                  });
                                  _restartTimer();
                                },
                                label: Text(_autoRefresh ? '自动 10 秒' : '手动'),
                              ),
                              _MetricChip(
                                label: '实时',
                                value: '${snapshot?.total ?? 0}',
                              ),
                              _MetricChip(
                                label: '重点',
                                value: '$importantCount',
                              ),
                              _MetricChip(
                                label: '显示中',
                                value: '${items.length}',
                              ),
                            ],
                          ),
                          if (quickKeywords.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: quickKeywords
                                  .map(
                                    (keyword) => ActionChip(
                                      label: Text(keyword),
                                      onPressed: () {
                                        _keywordController.value =
                                            TextEditingValue(
                                          text: keyword,
                                          selection: TextSelection.collapsed(
                                            offset: keyword.length,
                                          ),
                                        );
                                        setState(() {
                                          _keyword = keyword;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.outline),
                        ),
                        child: _buildBody(
                          context,
                          items: items,
                          errorMessage: _errorMessage,
                          hasSnapshot: snapshot != null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<FeedItemData> items,
    required String? errorMessage,
    required bool hasSnapshot,
  }) {
    final theme = Theme.of(context);
    if (errorMessage != null && !hasSnapshot) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '快讯请求失败：$errorMessage',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.text,
            ),
          ),
        ),
      );
    }

    if (_isRefreshing && !hasSnapshot) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '当前筛选条件下暂无快讯。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.text,
            ),
          ),
        ),
      );
    }

    final grouped = _groupItems(items);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      children: grouped.entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      entry.key,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  ...entry.value.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FastNewsTile(item: item),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _loadSnapshot() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final snapshot =
          await ref.read(marketApiRepositoryProvider).fetchFastNews(limit: 50);
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _restartTimer() {
    _refreshTimer?.cancel();
    if (!_autoRefresh) {
      return;
    }
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _loadSnapshot();
    });
  }
}

class _FastNewsTile extends StatelessWidget {
  const _FastNewsTile({
    required this.item,
  });

  final FeedItemData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = item.isImportant ? AppTheme.rise : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isImportant ? AppTheme.dangerSoft : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.isImportant ? AppTheme.dangerOutline : AppTheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _timeOnly(item.time) ?? '--',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.text,
                        height: 1.35,
                      ),
                    ),
                    if ((item.subtitle ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mutedText,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.isImportant)
                _MetaChip(
                  label: '重点',
                  foreground: AppTheme.rise,
                  background: AppTheme.dangerSoft,
                ),
              if ((item.extra ?? '').trim().isNotEmpty)
                _MetaChip(
                  label: item.extra!.trim(),
                  foreground: AppTheme.secondary,
                  background: AppTheme.secondarySoft,
                ),
              if ((item.group ?? '').trim().isNotEmpty)
                _MetaChip(
                  label: item.group!.trim(),
                  foreground: AppTheme.primary,
                  background: AppTheme.primarySoft,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.outline),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.text,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(color: AppTheme.mutedText),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
            ),
      ),
    );
  }
}

List<FeedItemData> _filterFastNews(
  List<FeedItemData> items,
  String keyword,
  bool importantOnly,
) {
  final normalizedKeyword = keyword.trim().toLowerCase();
  return items.where((item) {
    if (importantOnly && !item.isImportant) {
      return false;
    }
    if (normalizedKeyword.isEmpty) {
      return true;
    }
    final haystack = <String>[
      item.title,
      item.subtitle ?? '',
      item.extra ?? '',
      item.group ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(normalizedKeyword);
  }).toList(growable: false);
}

List<String> _extractQuickKeywords(FeedSnapshot snapshot) {
  final values = <String>[];
  final seen = <String>{};
  final pattern =
      RegExp(r'[\u300a\u3010]?([A-Za-z0-9\u4e00-\u9fa5]{2,12})[\u300b\u3011]?');

  void tryAdd(String candidate) {
    final value = candidate.trim();
    if (value.length < 2) {
      return;
    }
    if (seen.add(value)) {
      values.add(value);
    }
  }

  for (final item in snapshot.items) {
    for (final source in [item.title, item.subtitle ?? '']) {
      final matches = pattern.allMatches(source);
      for (final match in matches) {
        final candidate = match.group(1);
        if (candidate == null) {
          continue;
        }
        if (RegExp(r'^\d+$').hasMatch(candidate)) {
          continue;
        }
        tryAdd(candidate);
        if (values.length >= 6) {
          return values;
        }
      }
    }
  }
  return values;
}

Map<String, List<FeedItemData>> _groupItems(List<FeedItemData> items) {
  final grouped = <String, List<FeedItemData>>{};
  for (final item in items) {
    final label = _dayLabel(item);
    grouped.putIfAbsent(label, () => <FeedItemData>[]).add(item);
  }
  return grouped;
}

String _dayLabel(FeedItemData item) {
  final group = (item.group ?? '').trim();
  if (group.isNotEmpty) {
    return group;
  }
  final time = (item.time ?? '').trim();
  if (time.contains(' ')) {
    return time.split(' ').first;
  }
  return '最新';
}

String? _timeOnly(String? rawValue) {
  final value = rawValue?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value.contains(' ')) {
    return value.split(' ').last;
  }
  return value;
}

String? _formatStamp(String? rawValue) {
  final value = rawValue?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  final local = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
