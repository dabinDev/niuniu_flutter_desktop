import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/application/export_bundle_service.dart';
import '../../../shared/application/stock_link_service.dart';
import '../../../shared/data/market_api_repository.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/trade_date_navigation.dart';
import '../../../shared/widgets/stock_profile_sheet.dart';
import '../application/board_tier_provider.dart';

class BoardTierPage extends ConsumerStatefulWidget {
  const BoardTierPage({
    super.key,
    this.initialTradeDate,
  });

  final String? initialTradeDate;

  @override
  ConsumerState<BoardTierPage> createState() => _BoardTierPageState();
}

class _BoardTierPageState extends ConsumerState<BoardTierPage> {
  static const _autoRefreshInterval = Duration(seconds: 5);

  final GlobalKey _captureKey = GlobalKey();

  bool _autoRefresh = false;
  bool _isRefreshing = false;
  String? _selectedTradeDate;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
  }

  @override
  void didUpdateWidget(covariant BoardTierPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTradeDate != widget.initialTradeDate) {
      _selectedTradeDate = _normalizeTradeDate(widget.initialTradeDate);
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = boardTierProvider(_selectedTradeDate);
    final data = ref.watch(provider);

    return AppShell(
      currentPath: '/board-tier',
      title: '连板天梯',
      subtitle: '按旧版连板天梯的方式分层展示连板梯队，先看高度，再看梯队成员与题材分布。',
      child: data.when(
        data: (snapshot) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            await ref.read(provider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: RepaintBoundary(
              key: _captureKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BoardTierSummaryStrip(
                    snapshot: snapshot,
                    autoRefresh: _autoRefresh,
                    selectedTradeDate: _selectedTradeDate,
                    onRefresh: _refreshData,
                    onSelectTradeDate: _selectTradeDate,
                    onShowLatest: () => _selectTradeDate(null),
                    onToggleAutoRefresh: _toggleAutoRefresh,
                    onCopyImage: () => _copyWorkspaceImage(snapshot),
                    onCopyText: () => _copySnapshotText(snapshot),
                    onExportExcel: () => _exportExcelSnapshot(snapshot),
                    onExportCsv: () => _exportCsvSnapshot(snapshot),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.tiers.isEmpty)
                    _EmptyState(tradeDate: snapshot.tradeDate)
                  else
                    ...snapshot.tiers.map(
                      (tier) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _BoardTierSection(
                          tier: tier,
                          onOpenStock: (code) => openStockLinkFromUi(
                            context: context,
                            ref: ref,
                            code: code,
                          ),
                          onShowStockDetails: _showStockDetails,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '连板天梯请求失败：$error',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) {
      return;
    }
    final provider = boardTierProvider(_selectedTradeDate);
    _isRefreshing = true;
    try {
      ref.invalidate(provider);
      await ref.read(provider.future);
    } finally {
      _isRefreshing = false;
    }
  }

  void _toggleAutoRefresh() {
    final nextValue = !_autoRefresh;
    if (nextValue && _selectedTradeDate != null) {
      _selectedTradeDate = null;
      _syncBoardTierRoute(null);
    }
    setState(() {
      _autoRefresh = nextValue;
    });

    _autoRefreshTimer?.cancel();
    if (!nextValue) {
      return;
    }

    _refreshData();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _refreshData();
    });
  }

  Future<void> _showStockDetails(BoardTierStockData stock) async {
    await showStockProfileSheet(
      context,
      seed: StockProfileSeed(
        symbol: stock.code,
        name: stock.name,
        regionName: stock.regionName,
        industryName: stock.industryName,
        listingDate: stock.listingDate,
        reason: stock.reason,
      ),
    );
  }

  Future<void> _copyWorkspaceImage(BoardTierSnapshot snapshot) async {
    final pngBytes = await _captureWorkspacePng();
    if (pngBytes == null) {
      _showInfo('连板天梯图片生成失败。');
      return;
    }

    final filePath = await writeBinaryFile(
      bundleName: 'board_tier_snapshot_image',
      fileName: 'board_tier_${snapshot.tradeDate ?? 'snapshot'}.png',
      bytes: pngBytes,
    );

    final copied = await _copyImageToClipboard(filePath);
    if (!mounted) {
      return;
    }
    if (copied) {
      _showInfo('连板天梯图片已复制到剪贴板：$filePath');
      return;
    }

    _showInfo('连板天梯 PNG 已保存：$filePath');
  }

  Future<void> _copySnapshotText(BoardTierSnapshot snapshot) async {
    final buffer = StringBuffer()
      ..writeln('连板天梯')
      ..writeln('交易日：${snapshot.tradeDate ?? '--'}')
      ..writeln('快照：${_formatTimestamp(snapshot.fetchedAt)}')
      ..writeln('梯队总数：${snapshot.totalTiers}')
      ..writeln('股票总数：${snapshot.totalStocks}')
      ..writeln()
      ..writeln('[梯队]');

    for (final tier in snapshot.tiers) {
      buffer.writeln(
        '${_tierTitle(tier)}\t${tier.title}\t${tier.total}\t${tier.successRateText}',
      );
      for (final stock in tier.stocks) {
        buffer.writeln(
          '${stock.market}\t${stock.code}\t${stock.name}\t${stock.status}\t${stock.changePct}\t'
          '${stock.latestPrice}\t${stock.firstLimitTime}\t${stock.breakCount}\t'
          '${stock.regionName}\t${stock.industryName}\t${stock.listingDate}\t${stock.reason}',
        );
      }
      buffer.writeln();
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
    if (!mounted) {
      return;
    }
    _showInfo('连板天梯文本已复制到剪贴板。');
  }

  Future<void> _exportExcelSnapshot(BoardTierSnapshot snapshot) async {
    final filePath = await writeExcelWorkbook(
      bundleName: 'board_tier_excel',
      fileName: 'board_tier_${snapshot.tradeDate ?? 'snapshot'}.xlsx',
      sheets: _buildBoardTierExportSheets(snapshot)
          .entries
          .map(
            (entry) => ExcelSheetData(
              name: entry.key,
              rows: entry.value,
            ),
          )
          .toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    _showInfo('连板天梯 Excel 已导出：$filePath');
  }

  Future<void> _exportCsvSnapshot(BoardTierSnapshot snapshot) async {
    final exportSheets = _buildBoardTierExportSheets(snapshot);
    final result = await writeCsvBundle(
      bundleName: 'board_tier_snapshot',
      files: exportSheets,
    );

    if (!mounted) {
      return;
    }
    _showInfo('连板天梯 CSV 已导出：${result.directoryPath}');
  }

  Future<Uint8List?> _captureWorkspacePng() async {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    if (_captureKey.currentContext == null) {
      return null;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return null;
    }

    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }

    final heightScaleCap =
        boundary.size.height <= 0 ? 1.0 : 3000 / boundary.size.height;
    final pixelRatio = [
      devicePixelRatio,
      2.0,
      heightScaleCap,
    ].reduce((value, element) => value < element ? value : element);

    final image = await boundary.toImage(
      pixelRatio: pixelRatio <= 0 ? 1.0 : pixelRatio,
    );
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  Future<bool> _copyImageToClipboard(String filePath) async {
    if (!Platform.isWindows) {
      return false;
    }

    final script = '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
\$path = ${_powerShellLiteral(filePath)}
\$bytes = [System.IO.File]::ReadAllBytes(\$path)
\$stream = New-Object System.IO.MemoryStream(,\$bytes)
\$image = [System.Drawing.Image]::FromStream(\$stream)
\$bitmap = New-Object System.Drawing.Bitmap \$image
try {
  [System.Windows.Forms.Clipboard]::SetImage(\$bitmap)
} finally {
  \$bitmap.Dispose()
  \$image.Dispose()
  \$stream.Dispose()
}
''';

    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Sta',
          '-Command',
          script,
        ],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  String _powerShellLiteral(String value) {
    final escaped = value.replaceAll("'", "''");
    return "'$escaped'";
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _normalizeTradeDate(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _selectTradeDate(String? tradeDate) {
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    if (normalizedTradeDate != null && _autoRefresh) {
      _autoRefreshTimer?.cancel();
    }
    setState(() {
      _selectedTradeDate = normalizedTradeDate;
      if (normalizedTradeDate != null) {
        _autoRefresh = false;
      }
    });
    _syncBoardTierRoute(normalizedTradeDate);
  }

  void _syncBoardTierRoute(String? tradeDate) {
    if (!mounted) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final normalizedTradeDate = _normalizeTradeDate(tradeDate);
    final uri = Uri(
      path: '/board-tier',
      queryParameters: normalizedTradeDate == null
          ? null
          : <String, String>{'tradeDate': normalizedTradeDate},
    );
    router.replace(uri.toString());
  }
}

class _BoardTierSummaryStrip extends StatelessWidget {
  const _BoardTierSummaryStrip({
    required this.snapshot,
    required this.autoRefresh,
    required this.selectedTradeDate,
    required this.onRefresh,
    required this.onSelectTradeDate,
    required this.onShowLatest,
    required this.onToggleAutoRefresh,
    required this.onCopyImage,
    required this.onCopyText,
    required this.onExportExcel,
    required this.onExportCsv,
  });

  final BoardTierSnapshot snapshot;
  final bool autoRefresh;
  final String? selectedTradeDate;
  final VoidCallback onRefresh;
  final ValueChanged<String?> onSelectTradeDate;
  final VoidCallback onShowLatest;
  final VoidCallback onToggleAutoRefresh;
  final VoidCallback onCopyImage;
  final VoidCallback onCopyText;
  final VoidCallback onExportExcel;
  final VoidCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topTier = snapshot.tiers.isEmpty ? null : snapshot.tiers.first;
    final leaderNames =
        topTier?.stocks.take(6).map((item) => item.name).toList() ??
            const <String>[];
    final resolvedTradeDate = selectedTradeDate ?? snapshot.tradeDate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 860;

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryTitleBlock(snapshot: snapshot),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeaderMetaPill(
                          icon: Icons.calendar_today_rounded,
                          label: '交易日 ${snapshot.tradeDate ?? '--'}',
                        ),
                        _HeaderMetaPill(
                          icon: Icons.schedule_rounded,
                          label: '快照 ${_formatTimestamp(snapshot.fetchedAt)}',
                        ),
                        _AutoRefreshChip(
                          selected: autoRefresh,
                          onTap: onToggleAutoRefresh,
                        ),
                        TradeDateActionBar(
                          keyPrefix: 'board-tier',
                          resolvedTradeDate: resolvedTradeDate,
                          selectedTradeDate: selectedTradeDate,
                          previousTradeDate: snapshot.previousTradeDate,
                          nextTradeDate: snapshot.nextTradeDate,
                          onSelectTradeDate: onSelectTradeDate,
                          buttonStyle: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primarySoft,
                            foregroundColor: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: onRefresh,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primarySoft,
                        foregroundColor: AppTheme.primary,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('刷新'),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _SummaryTitleBlock(snapshot: snapshot)),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _HeaderMetaPill(
                        icon: Icons.calendar_today_rounded,
                        label: '交易日 ${snapshot.tradeDate ?? '--'}',
                      ),
                      _HeaderMetaPill(
                        icon: Icons.schedule_rounded,
                        label: '快照 ${_formatTimestamp(snapshot.fetchedAt)}',
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onRefresh,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primarySoft,
                          foregroundColor: AppTheme.primary,
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('刷新'),
                      ),
                      _AutoRefreshChip(
                        selected: autoRefresh,
                        onTap: onToggleAutoRefresh,
                      ),
                      TradeDateActionBar(
                        keyPrefix: 'board-tier',
                        resolvedTradeDate: resolvedTradeDate,
                        selectedTradeDate: selectedTradeDate,
                        previousTradeDate: snapshot.previousTradeDate,
                        nextTradeDate: snapshot.nextTradeDate,
                        onSelectTradeDate: onSelectTradeDate,
                        buttonStyle: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primarySoft,
                          foregroundColor: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryStatTile(
                label: '梯队',
                value: '${snapshot.totalTiers}',
                caption: '当前收录梯队数',
              ),
              _SummaryStatTile(
                label: '股票',
                value: '${snapshot.totalStocks}',
                caption: '当前梯队股票总数',
              ),
              _SummaryStatTile(
                label: '龙头梯队',
                value: topTier == null ? '--' : '${topTier.boardCount}板',
                caption: topTier == null ? '暂无龙头梯队' : '${topTier.total} 只股票',
              ),
            ],
          ),
          if (snapshot.availableTradeDates.isNotEmpty) ...[
            const SizedBox(height: 10),
            TradeDateChoiceChips(
              keyPrefix: 'board-tier',
              availableTradeDates: snapshot.availableTradeDates,
              resolvedTradeDate: resolvedTradeDate,
              onSelectTradeDate: onSelectTradeDate,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onCopyImage,
                icon: const Icon(Icons.image_rounded),
                label: const Text('复制图片'),
              ),
              OutlinedButton.icon(
                onPressed: onCopyText,
                icon: const Icon(Icons.copy_all_rounded),
                label: const Text('复制文本'),
              ),
              OutlinedButton.icon(
                onPressed: onExportExcel,
                icon: const Icon(Icons.table_view_rounded),
                label: const Text('导出 Excel'),
              ),
              OutlinedButton.icon(
                onPressed: onExportCsv,
                icon: const Icon(Icons.download_rounded),
                label: const Text('导出 CSV'),
              ),
            ],
          ),
          if (leaderNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 10),
            Text(
              '龙头预览',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: leaderNames
                  .map(
                    (name) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryTitleBlock extends StatelessWidget {
  const _SummaryTitleBlock({
    required this.snapshot,
  });

  final BoardTierSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.secondarySoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.secondaryOutline),
          ),
          child: const Icon(
            Icons.account_tree_rounded,
            color: AppTheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '连板梯队',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '16:30 后复盘数据更完整，适合盘后核对梯队强度与断板情况。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mutedText,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                snapshot.tiers.isEmpty
                    ? '暂无梯队股票数据。'
                    : '最高梯队 ${snapshot.tiers.first.boardCount} 板，优先关注高板分歧与炸板扩散。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderMetaPill extends StatelessWidget {
  const _HeaderMetaPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.mutedText),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.text,
                ),
          ),
        ],
      ),
    );
  }
}

class _AutoRefreshChip extends StatelessWidget {
  const _AutoRefreshChip({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      label: Text(selected ? '停止' : '自动 5 秒'),
      labelStyle: const TextStyle(color: AppTheme.text),
      selectedColor: AppTheme.primarySoft,
      checkmarkColor: AppTheme.primary,
      backgroundColor: AppTheme.surfaceSoft,
      side: const BorderSide(color: AppTheme.outline),
    );
  }
}

class _SummaryStatTile extends StatelessWidget {
  const _SummaryStatTile({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 168,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.mutedText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 6),
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
}

class _BoardTierSection extends StatelessWidget {
  const _BoardTierSection({
    required this.tier,
    required this.onOpenStock,
    required this.onShowStockDetails,
  });

  final BoardTierGroupData tier;
  final ValueChanged<String> onOpenStock;
  final ValueChanged<BoardTierStockData> onShowStockDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, AppTheme.primary, 0.018),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryOutline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TierRail(tier: tier),
                    const SizedBox(width: 12),
                    Expanded(child: _TierHeading(tier: tier)),
                  ],
                ),
                const SizedBox(height: 10),
                _TierStocksWrap(
                  tier: tier,
                  onOpenStock: onOpenStock,
                  onShowStockDetails: onShowStockDetails,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TierRail(tier: tier),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TierHeading(tier: tier),
                    const SizedBox(height: 10),
                    _TierStocksWrap(
                      tier: tier,
                      onOpenStock: onOpenStock,
                      onShowStockDetails: onShowStockDetails,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TierRail extends StatelessWidget {
  const _TierRail({
    required this.tier,
  });

  final BoardTierGroupData tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryOutline),
      ),
      child: Column(
        children: [
          Text(
            '${tier.boardCount}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tier.boardCount == 1 ? '首板' : '连板',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tier.successRateText,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _successRateColor(tier.successRatePct),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '晋级率',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedText,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${tier.total} 只',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierHeading extends StatelessWidget {
  const _TierHeading({
    required this.tier,
  });

  final BoardTierGroupData tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = tier.stocks.take(4).map((item) => item.name).join(' / ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _tierTitle(tier),
              style: theme.textTheme.titleLarge,
            ),
            _NeutralPill(label: '${tier.total} 只股票'),
            _RatePill(tier: tier),
            if (tier.stocks.any((item) => item.status == 'broken'))
              const _NeutralPill(label: '含炸板'),
          ],
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            preview,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _TierStocksWrap extends StatelessWidget {
  const _TierStocksWrap({
    required this.tier,
    required this.onOpenStock,
    required this.onShowStockDetails,
  });

  final BoardTierGroupData tier;
  final ValueChanged<String> onOpenStock;
  final ValueChanged<BoardTierStockData> onShowStockDetails;

  @override
  Widget build(BuildContext context) {
    if (tier.stocks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Text(
          '当前梯队暂无股票明细。',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Text(
            '股票 / 状态 / 时间 / 地区 / 行业 / 原因',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.mutedText,
                ),
          ),
        ),
        const SizedBox(height: 8),
        ...tier.stocks.map(
          (stock) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BoardTierStockChip(
              stock: stock,
              onShowDetails: () => onShowStockDetails(stock),
              onOpenStock: () => onOpenStock(stock.code),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoardTierStockChip extends StatelessWidget {
  const _BoardTierStockChip({
    required this.stock,
    required this.onShowDetails,
    required this.onOpenStock,
  });

  final BoardTierStockData stock;
  final VoidCallback onShowDetails;
  final VoidCallback onOpenStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusTone = _statusTone(stock.status);
    final changeTone = _changeTone(stock.changePct);
    final themeText = _compactTheme(stock);
    final statusText = _statusLabel(stock.status);
    assert(statusText.isNotEmpty);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('board-tier-stock-${stock.code}'),
        onTap: onShowDetails,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: statusTone.surface.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusTone.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;

              final tokens = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StockToken(
                    label: _statusShortLabel(stock.status),
                    background: statusTone.tokenBackground,
                    foreground: statusTone.accent,
                  ),
                  _StockToken(
                    label: stock.changePct,
                    background: changeTone.surface,
                    foreground: changeTone.accent,
                  ),
                  if (themeText != null)
                    _StockToken(
                      label: themeText,
                      background: AppTheme.surfaceSoft,
                      foreground: AppTheme.text,
                    ),
                  if (_hasValue(stock.regionName))
                    _StockToken(
                      label: stock.regionName,
                      background: AppTheme.primarySoft,
                      foreground: AppTheme.primary,
                    ),
                  if (_hasValue(stock.industryName))
                    _StockToken(
                      label: stock.industryName,
                      background: AppTheme.secondarySoft,
                      foreground: AppTheme.secondary,
                    ),
                ],
              );

              final metas = Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _InlineMeta(
                    icon: Icons.schedule_rounded,
                    label: '首封 ${stock.firstLimitTime}',
                  ),
                  _InlineMeta(
                    icon: Icons.warning_amber_rounded,
                    label: '炸板 ${stock.breakCount}',
                  ),
                  if (_hasValue(stock.amount))
                    _InlineMeta(
                      icon: Icons.waterfall_chart_rounded,
                      label: stock.amount,
                    ),
                  if (_hasValue(stock.listingDate))
                    _InlineMeta(
                      icon: Icons.event_available_rounded,
                      label: '上市 ${stock.listingDate}',
                    ),
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (_hasValue(stock.market))
                                        _MarketBadge(label: stock.market),
                                      Text(
                                        stock.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          color: AppTheme.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        stock.code,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: AppTheme.mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!compact)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: Text(
                                      stock.latestPrice,
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            tokens,
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (compact)
                            Text(
                              stock.latestPrice,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          IconButton(
                            onPressed: onOpenStock,
                            icon: const Icon(Icons.open_in_new_rounded),
                            iconSize: 18,
                            tooltip: '打开股票',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 34,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  metas,
                  if (_hasValue(stock.reason)) ...[
                    const SizedBox(height: 6),
                    Text(
                      stock.reason,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MarketBadge extends StatelessWidget {
  const _MarketBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = _marketAccent(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: AppTheme.mutedText,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.mutedText,
          ),
        ),
      ],
    );
  }
}

class _StockToken extends StatelessWidget {
  const _StockToken({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _NeutralPill extends StatelessWidget {
  const _NeutralPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.mutedText,
            ),
      ),
    );
  }
}

class _RatePill extends StatelessWidget {
  const _RatePill({
    required this.tier,
  });

  final BoardTierGroupData tier;

  @override
  Widget build(BuildContext context) {
    final color = _successRateColor(tier.successRatePct);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        '晋级 ${tier.successRateText}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.tradeDate,
  });

  final String? tradeDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前快照暂无连板梯队数据',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '交易日 ${tradeDate ?? '--'} 还没有可展示的梯队结果，先检查抓取任务或等待盘后快照落库。',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _TonePalette {
  const _TonePalette({
    required this.surface,
    required this.border,
    required this.accent,
    required this.tokenBackground,
  });

  final Color surface;
  final Color border;
  final Color accent;
  final Color tokenBackground;
}

_TonePalette _statusTone(String status) {
  return switch (status) {
    'sealed' => const _TonePalette(
        surface: AppTheme.dangerSoft,
        border: AppTheme.dangerOutline,
        accent: AppTheme.rise,
        tokenBackground: AppTheme.dangerTint,
      ),
    'broken' => const _TonePalette(
        surface: AppTheme.secondarySoft,
        border: AppTheme.secondaryOutline,
        accent: AppTheme.secondary,
        tokenBackground: AppTheme.secondaryTint,
      ),
    _ => const _TonePalette(
        surface: AppTheme.neutralSoft,
        border: AppTheme.outline,
        accent: AppTheme.mutedText,
        tokenBackground: AppTheme.neutralSoft,
      ),
  };
}

_TonePalette _changeTone(String changePct) {
  final normalized = changePct.trim();
  if (normalized.startsWith('-')) {
    return const _TonePalette(
      surface: AppTheme.successSoft,
      border: AppTheme.successOutline,
      accent: AppTheme.fall,
      tokenBackground: AppTheme.successTint,
    );
  }
  return const _TonePalette(
    surface: AppTheme.dangerSoft,
    border: AppTheme.dangerOutline,
    accent: AppTheme.rise,
    tokenBackground: AppTheme.dangerTint,
  );
}

bool _hasValue(String? value) {
  if (value == null) {
    return false;
  }
  final normalized = value.trim();
  return normalized.isNotEmpty && normalized != '--';
}

String _tierTitle(BoardTierGroupData tier) {
  if (tier.boardCount <= 1) {
    return '首板';
  }
  return '${tier.boardCount} 连板';
}

String _statusLabel(String status) {
  return switch (status) {
    'sealed' => '封板',
    'broken' => '炸板',
    _ => status,
  };
}

String _statusShortLabel(String status) {
  return switch (status) {
    'sealed' => '成',
    'broken' => '炸',
    _ => '--',
  };
}

String? _compactTheme(BoardTierStockData stock) {
  final raw = _hasValue(stock.reason) ? stock.reason : stock.industryName;
  if (!_hasValue(raw)) {
    return null;
  }

  final normalized =
      raw.split(RegExp(r'[\\/|,，;；、+]')).map((item) => item.trim()).firstWhere(
            (item) => item.isNotEmpty,
            orElse: () => raw.trim(),
          );
  if (normalized.length <= 8) {
    return normalized;
  }
  return '${normalized.substring(0, 8)}…';
}

Color _marketAccent(String market) {
  return switch (market) {
    '沪' => AppTheme.primary,
    '深' => AppTheme.success,
    '创' => AppTheme.secondary,
    '科' => AppTheme.primary,
    '北' => AppTheme.mutedText,
    _ => AppTheme.mutedText,
  };
}

Color _successRateColor(int pct) {
  if (pct >= 70) {
    return AppTheme.rise;
  }
  if (pct >= 40) {
    return AppTheme.secondary;
  }
  return AppTheme.fall;
}

String _formatTimestamp(String? value) {
  if (value == null || value.isEmpty) {
    return '--';
  }
  return value.replaceFirst('T', ' ').split('.').first;
}

Map<String, List<List<String>>> _buildBoardTierExportSheets(
  BoardTierSnapshot snapshot,
) {
  return {
    'summary': [
      ['trade_date', snapshot.tradeDate ?? '--'],
      ['fetched_at', _formatTimestamp(snapshot.fetchedAt)],
      ['total_tiers', '${snapshot.totalTiers}'],
      ['total_stocks', '${snapshot.totalStocks}'],
    ],
    'tiers': [
      [
        'board_count',
        'tier_title',
        'group_title',
        'group_total',
        'sealed_count',
        'broken_count',
        'success_rate_pct',
        'success_rate_text',
        'market',
        'code',
        'name',
        'status',
        'change_pct',
        'latest_price',
        'first_limit_time',
        'amount',
        'break_count',
        'region_name',
        'industry_name',
        'listing_date',
        'reason',
      ],
      ...snapshot.tiers.expand(
        (tier) => tier.stocks.map(
          (stock) => [
            '${tier.boardCount}',
            _tierTitle(tier),
            tier.title,
            '${tier.total}',
            '${tier.sealedCount}',
            '${tier.brokenCount}',
            '${tier.successRatePct}',
            tier.successRateText,
            stock.market,
            stock.code,
            stock.name,
            stock.status,
            stock.changePct,
            stock.latestPrice,
            stock.firstLimitTime,
            stock.amount,
            stock.breakCount,
            stock.regionName,
            stock.industryName,
            stock.listingDate,
            stock.reason,
          ],
        ),
      ),
    ],
  };
}
