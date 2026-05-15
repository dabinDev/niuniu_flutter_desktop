import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/stock_link_service.dart';
import '../data/market_api_provider.dart';
import '../data/market_api_repository.dart';

class StockProfileSeed {
  const StockProfileSeed({
    required this.symbol,
    required this.name,
    this.regionName,
    this.industryName,
    this.listingDate,
    this.reason,
  });

  final String symbol;
  final String name;
  final String? regionName;
  final String? industryName;
  final String? listingDate;
  final String? reason;
}

Future<void> showStockProfileSheet(
  BuildContext context, {
  required StockProfileSeed seed,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StockProfileSheet(seed: seed),
  );
}

class _StockProfileSheet extends ConsumerStatefulWidget {
  const _StockProfileSheet({
    required this.seed,
  });

  final StockProfileSeed seed;

  @override
  ConsumerState<_StockProfileSheet> createState() => _StockProfileSheetState();
}

class _StockProfileSheetState extends ConsumerState<_StockProfileSheet> {
  late final Future<_StockProfileBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBundle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Material(
            color: theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
            child: FutureBuilder<_StockProfileBundle>(
              future: _future,
              builder: (context, snapshot) {
                final bundle = snapshot.data;
                return Column(
                  children: [
                    Container(
                      width: 56,
                      height: 6,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeroPanel(
                              seed: widget.seed,
                              profile: bundle?.profile,
                              quote: bundle?.quote,
                              isLoading: snapshot.connectionState !=
                                      ConnectionState.done &&
                                  bundle == null,
                              onOpenStock: _openStock,
                            ),
                            const SizedBox(height: 18),
                            if (bundle == null &&
                                snapshot.connectionState !=
                                    ConnectionState.done) ...[
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ] else ...[
                              _SectionCard(
                                title: '基础资料',
                                subtitle: '个股资料缓存与最新行情快照',
                                child: _ProfileSummary(
                                  seed: widget.seed,
                                  profile: bundle?.profile,
                                  quote: bundle?.quote,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _SectionCard(
                                title: '行情指标',
                                subtitle: '现价、换手、振幅与成交额',
                                child: _QuoteMetricsGrid(quote: bundle?.quote),
                              ),
                              const SizedBox(height: 16),
                              _SectionCard(
                                title: '近期走势',
                                subtitle: '最近 6 根来自 21 日 K 线接口的数据',
                                child: _RecentSessions(
                                  kline: bundle?.kline,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<_StockProfileBundle> _loadBundle() async {
    final repository = ref.read(marketApiRepositoryProvider);
    final symbol = widget.seed.symbol;

    final profileFuture = _guard(() => repository.fetchStockProfile(symbol));
    final quoteFuture = _guard(() => repository.fetchQuote(symbol));
    final klineFuture = _guard(() => repository.fetchKline(symbol, days: 21));

    return _StockProfileBundle(
      profile: await profileFuture,
      quote: await quoteFuture,
      kline: await klineFuture,
    );
  }

  Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openStock() async {
    await openStockLinkFromUi(
      context: context,
      ref: ref,
      code: widget.seed.symbol,
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.seed,
    required this.profile,
    required this.quote,
    required this.isLoading,
    required this.onOpenStock,
  });

  final StockProfileSeed seed;
  final StockProfileData? profile;
  final QuoteData? quote;
  final bool isLoading;
  final VoidCallback onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _pickValue(profile?.name, seed.name, '--');
    final code = _pickValue(profile?.stockCode, seed.symbol, '--');
    final market = _displayValue(profile?.market);
    final secid = _displayValue(profile?.secid);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7EFE1), Color(0xFFE6F0EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
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
                    Text('个股资料', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 10),
                    Text(name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      '$code${market == null ? '' : '  |  $market'}${secid == null ? '' : '  |  $secid'}',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onOpenStock,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('打开股票'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: '地区',
                value: _pickValue(profile?.regionName, seed.regionName),
              ),
              _InfoChip(
                label: '行业',
                value: _pickValue(profile?.industryName, seed.industryName),
              ),
              _InfoChip(
                label: '上市',
                value: _pickValue(profile?.listingDate, seed.listingDate),
              ),
              _InfoChip(
                label: '状态',
                value:
                    profile == null ? '待同步' : (profile!.isActive ? '正常' : '停用'),
              ),
              _InfoChip(
                label: '现价',
                value: _formatPrice(quote?.price),
              ),
              _InfoChip(
                label: '涨幅',
                value: _formatSignedPercent(quote?.changePct),
              ),
            ],
          ),
          if (_hasDisplayValue(seed.reason)) ...[
            const SizedBox(height: 14),
            Text(
              seed.reason!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF405148),
              ),
            ),
          ],
          if (isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.seed,
    required this.profile,
    required this.quote,
  });

  final StockProfileSeed seed;
  final StockProfileData? profile;
  final QuoteData? quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <_LabelValueData>[
      _LabelValueData(
        '资料刷新',
        _formatTimestamp(profile?.profileUpdatedAt),
      ),
      _LabelValueData(
        '记录更新',
        _formatTimestamp(profile?.updatedAt),
      ),
      _LabelValueData(
        '行情日期',
        _pickValue(quote?.tradeDate),
      ),
      _LabelValueData(
        '行情同步',
        _formatTimestamp(quote?.fetchedAt),
      ),
      _LabelValueData(
        '地区',
        _pickValue(profile?.regionName, seed.regionName),
      ),
      _LabelValueData(
        '行业',
        _pickValue(profile?.industryName, seed.industryName),
      ),
      _LabelValueData(
        '上市日期',
        _pickValue(profile?.listingDate, seed.listingDate),
      ),
      _LabelValueData(
        '代码',
        _pickValue(profile?.symbol, seed.symbol),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => Container(
              width: 220,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.value,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _QuoteMetricsGrid extends StatelessWidget {
  const _QuoteMetricsGrid({
    required this.quote,
  });

  final QuoteData? quote;

  @override
  Widget build(BuildContext context) {
    final metrics = <_LabelValueData>[
      _LabelValueData('现价', _formatPrice(quote?.price)),
      _LabelValueData('开盘', _formatPrice(quote?.open)),
      _LabelValueData('最高', _formatPrice(quote?.high)),
      _LabelValueData('最低', _formatPrice(quote?.low)),
      _LabelValueData('涨跌', _formatSignedNumber(quote?.change)),
      _LabelValueData('涨幅', _formatSignedPercent(quote?.changePct)),
      _LabelValueData('换手', _formatPercent(quote?.turnoverRate)),
      _LabelValueData('振幅', _formatPercent(quote?.amplitude)),
      _LabelValueData('成交额', _formatAmount(quote?.amount)),
      _LabelValueData('成交量', _formatVolume(quote?.volume)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics
          .map((item) => _MetricTile(data: item, tone: _toneForMetric(item)))
          .toList(growable: false),
    );
  }

  Color _toneForMetric(_LabelValueData data) {
    final label = data.label;
    if (label == '涨跌' || label == '涨幅') {
      return data.value.startsWith('-')
          ? const Color(0xFF157A6E)
          : const Color(0xFFC9553F);
    }
    return const Color(0xFF1C3B33);
  }
}

class _RecentSessions extends StatelessWidget {
  const _RecentSessions({
    required this.kline,
  });

  final KlineSnapshot? kline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bars = kline?.bars ?? const <KlineBarData>[];
    if (bars.isEmpty) {
      return Text(
        '暂无近期 K 线数据。',
        style: theme.textTheme.bodyLarge,
      );
    }

    final recentBars = bars.length <= 6 ? bars : bars.sublist(bars.length - 6);
    final highs = bars.map((item) => item.highPrice).toList(growable: false);
    final lows = bars.map((item) => item.lowPrice).toList(growable: false);
    final peak = highs.isEmpty ? null : highs.reduce((a, b) => a > b ? a : b);
    final floor = lows.isEmpty ? null : lows.reduce((a, b) => a < b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoChip(label: 'K线数', value: '${kline?.total ?? bars.length}'),
            _InfoChip(label: '21日高', value: _formatPrice(peak)),
            _InfoChip(label: '21日低', value: _formatPrice(floor)),
            _InfoChip(
              label: '同步',
              value: _formatTimestamp(kline?.fetchedAt),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: recentBars
              .map(
                (bar) => Container(
                  width: 148,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bar.tradeDate,
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatPrice(bar.closePrice),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: bar.closePrice >= bar.openPrice
                              ? const Color(0xFFC9553F)
                              : const Color(0xFF157A6E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '开 ${_formatPrice(bar.openPrice)}  高 ${_formatPrice(bar.highPrice)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '低 ${_formatPrice(bar.lowPrice)}  量 ${_formatCompactNumber(bar.volume)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0E4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.data,
    required this.tone,
  });

  final _LabelValueData data;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF24463B),
            ),
      ),
    );
  }
}

class _StockProfileBundle {
  const _StockProfileBundle({
    required this.profile,
    required this.quote,
    required this.kline,
  });

  final StockProfileData? profile;
  final QuoteData? quote;
  final KlineSnapshot? kline;
}

class _LabelValueData {
  const _LabelValueData(this.label, this.value);

  final String label;
  final String value;
}

String _pickValue(String? primary, [String? fallback, String empty = '--']) {
  final primaryValue = _displayValue(primary);
  if (primaryValue != null) {
    return primaryValue;
  }
  final fallbackValue = _displayValue(fallback);
  return fallbackValue ?? empty;
}

String? _displayValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == '--') {
    return null;
  }
  return trimmed;
}

bool _hasDisplayValue(String? value) => _displayValue(value) != null;

String _formatPrice(num? value) {
  if (value == null) {
    return '--';
  }
  return value.toStringAsFixed(2);
}

String _formatSignedPercent(double? value) {
  if (value == null) {
    return '--';
  }
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

String _formatSignedNumber(double? value) {
  if (value == null) {
    return '--';
  }
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}';
}

String _formatPercent(double? value) {
  if (value == null) {
    return '--';
  }
  return '${value.toStringAsFixed(2)}%';
}

String _formatAmount(double? value) {
  if (value == null) {
    return '--';
  }
  if (value.abs() >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (value.abs() >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}万';
  }
  return value.toStringAsFixed(0);
}

String _formatVolume(int? value) {
  if (value == null) {
    return '--';
  }
  return _formatCompactNumber(value.toDouble());
}

String _formatCompactNumber(double? value) {
  if (value == null) {
    return '--';
  }
  if (value.abs() >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (value.abs() >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}万';
  }
  return value.toStringAsFixed(0);
}

String _formatTimestamp(String? value) {
  final normalized = _displayValue(value);
  if (normalized == null) {
    return '--';
  }
  return normalized.replaceFirst('T', ' ').split('.').first;
}
