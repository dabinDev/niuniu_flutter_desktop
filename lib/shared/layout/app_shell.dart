import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_base_url.dart';
import '../../core/theme/app_theme.dart';
import '../../features/news/presentation/fast_news_quick_dialog.dart';
import '../../features/overview/data/overview_repository.dart';
import '../application/app_preferences_provider.dart';
import '../application/shell_provider.dart';
import '../application/stock_link_service.dart';

final jobsTabUnlockedProvider = StateProvider<bool>((ref) => false);

const _brandLogoAsset = 'assets/brand/niuniu_logo.png';
const _brandIconAsset = 'assets/brand/niuniu_icon.png';

const niuniuClientDownloadUrl = String.fromEnvironment(
  'CLIENT_DOWNLOAD_URL',
  defaultValue: '',
);

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.currentPath,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String currentPath;
  final String title;
  final String subtitle;
  final Widget child;

  static const _destinations = <_ShellDestination>[
    _ShellDestination(
      path: '/overview',
      label: '总览',
      shortLabel: '总览',
      icon: Icons.grid_view_rounded,
    ),
    _ShellDestination(
      path: '/auction',
      label: '牛牛竞价',
      shortLabel: '竞价',
      icon: Icons.flash_on_rounded,
    ),
    _ShellDestination(
      path: '/node',
      label: '牛牛节点',
      shortLabel: '节点',
      icon: Icons.polyline_rounded,
    ),
    _ShellDestination(
      path: '/board-tier',
      label: '连板天梯',
      shortLabel: '天梯',
      icon: Icons.account_tree_rounded,
    ),
    _ShellDestination(
      path: '/market-center',
      label: '行情中心',
      shortLabel: '行情',
      icon: Icons.dataset_rounded,
    ),
    _ShellDestination(
      path: '/yesterday-stats',
      label: '空头数据',
      shortLabel: '空头',
      icon: Icons.monitor_heart_rounded,
    ),
    _ShellDestination(
      path: '/board-height',
      label: '连板高度',
      shortLabel: '高度',
      icon: Icons.show_chart_rounded,
    ),
    _ShellDestination(
      path: '/limit-review',
      label: '涨停复盘',
      shortLabel: '复盘',
      icon: Icons.layers_rounded,
    ),
    _ShellDestination(
      path: '/plate-rotation',
      label: '板块轮动',
      shortLabel: '轮动',
      icon: Icons.sync_alt_rounded,
    ),
    _ShellDestination(
      path: '/news',
      label: '牛牛资讯',
      shortLabel: '资讯',
      icon: Icons.newspaper_rounded,
    ),
    _ShellDestination(
      path: '/ask-ai',
      label: '问AI',
      shortLabel: 'AI',
      icon: Icons.auto_awesome_rounded,
    ),
    _ShellDestination(
      path: '/jobs',
      label: '任务调度',
      shortLabel: '任务',
      icon: Icons.schedule_rounded,
    ),
  ];

  List<_ShellDestination> _visibleDestinations(WidgetRef ref) {
    final unlocked = ref.watch(jobsTabUnlockedProvider);
    if (unlocked) return _destinations;
    return _destinations
        .where((d) => d.path != '/jobs')
        .toList(growable: false);
  }

  int _selectedIndex(List<_ShellDestination> visible) {
    final index =
        visible.indexWhere((item) => currentPath.startsWith(item.path));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 720;
    final useDenseChrome = media.size.width > 0;
    final useCompactMarketStrips = useDenseChrome;
    final showStatusStrip = !useDenseChrome;
    final shellPadding = isCompact ? 8.0 : 10.0;
    final visible = _visibleDestinations(ref);
    final selected = visible[_selectedIndex(visible)];
    final theme = Theme.of(context);
    final shellAsync = ref.watch(shellOverviewProvider);
    final shellSnapshot = shellAsync.valueOrNull;
    final preferencesAsync = ref.watch(appPreferencesProvider);
    final preferences = preferencesAsync.valueOrNull ?? const AppPreferences();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppTheme.backdropGradient,
        ),
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      shellPadding,
                      8,
                      shellPadding,
                      0,
                    ),
                    child: _ShellHeader(
                      compact: useDenseChrome,
                      section: selected.shortLabel,
                      title: title,
                      subtitle: subtitle,
                      snapshot: shellSnapshot,
                      isLoading: shellAsync.isLoading,
                      apiBaseUrl: preferences.apiBaseUrl,
                      onOpenMessageCenter: () {
                        showDialog<void>(
                          context: context,
                          barrierColor: Colors.black.withValues(alpha: 0.18),
                          builder: (dialogContext) => FastNewsQuickDialog(
                            onOpenFullPage: () {
                              Navigator.of(dialogContext).pop();
                              context.go('/news?tab=message');
                            },
                          ),
                        );
                      },
                      onOpenSettings: () => showDialog<void>(
                        context: context,
                        builder: (_) => _SettingsDialog(
                          initialPreferences: preferences,
                        ),
                      ),
                      onDownloadClient: () => _downloadClient(context),
                      onOpenFeedback: () => showDialog<void>(
                        context: context,
                        builder: (_) => const _SupportDialog(
                          title: '反馈',
                          headline: '问题反馈与功能建议共用同一条支持通道。',
                          description:
                              '旧版桌面端提供直接反馈入口，Flutter 客户端继续保留这个入口，并显示当前接口地址，便于排查三层链路问题。',
                          accent: Color(0xFFC9553F),
                          icon: Icons.forum_outlined,
                        ),
                      ),
                      onOpenAbout: () => showDialog<void>(
                        context: context,
                        builder: (_) => _SupportDialog(
                          title: '关于',
                          headline: '牛牛开盘 Flutter 是三层架构客户端。',
                          description:
                              '当前版本正在按旧版 niuniu_mvvm 对齐壳层行为、业务页面和数据契约。AI 输出仅供参考，不应直接作为交易依据。',
                          accent: const Color(0xFF2E5B88),
                          icon: Icons.info_outline_rounded,
                          onIconTap: () {
                            ref.read(jobsTabUnlockedProvider.notifier).state =
                                true;
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        shellPadding,
                        8,
                        shellPadding,
                        shellPadding,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: _GlassPanel(
                          radius: 16,
                          blurSigma: 8,
                          color: AppTheme.glass.withValues(alpha: 0.92),
                          borderColor: AppTheme.outline,
                          padding: EdgeInsets.all(isCompact ? 8 : 10),
                          child: Column(
                            children: [
                              if (shellSnapshot != null &&
                                  useCompactMarketStrips)
                                _CompactMarketStrip(
                                  snapshot: shellSnapshot,
                                  preferences: preferences,
                                ),
                              if (shellSnapshot != null &&
                                  !useCompactMarketStrips)
                                _TopIndexStrip(snapshot: shellSnapshot),
                              if (shellSnapshot != null &&
                                  !useCompactMarketStrips)
                                const SizedBox(height: 6),
                              if (shellSnapshot != null &&
                                  !useCompactMarketStrips)
                                _TopSentimentStrip(snapshot: shellSnapshot),
                              if (shellSnapshot != null &&
                                  !useCompactMarketStrips)
                                const SizedBox(height: 6),
                              if (showStatusStrip)
                                _ShellStatusStrip(
                                  snapshot: shellSnapshot,
                                  preferences: preferences,
                                ),
                              if (shellSnapshot != null || showStatusStrip)
                                const SizedBox(height: 6),
                              _TopTabStrip(
                                destinations: visible,
                                selectedIndex: _selectedIndex(visible),
                                onSelected: (index) => _go(context, index),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: _GlassPanel(
                                  radius: 12,
                                  blurSigma: 10,
                                  color: theme.colorScheme.surface.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderColor: theme.colorScheme.outlineVariant,
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                      isCompact ? 8 : 10,
                                    ),
                                    child: child,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, int index) {
    if (index >= 0 && index < _destinations.length) {
      context.go(_destinations[index].path);
      return;
    }
    context.go('/overview');
  }
}

Future<void> _downloadClient(BuildContext context) async {
  if (niuniuClientDownloadUrl.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('客户端下载地址未配置。')),
    );
    return;
  }

  final launched = await launchUrl(
    Uri.parse(niuniuClientDownloadUrl),
    webOnlyWindowName: '_blank',
  );
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('客户端下载打开失败，请稍后重试。')),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.compact,
    required this.section,
    required this.title,
    required this.subtitle,
    required this.snapshot,
    required this.isLoading,
    required this.apiBaseUrl,
    required this.onOpenMessageCenter,
    required this.onOpenSettings,
    required this.onDownloadClient,
    required this.onOpenFeedback,
    required this.onOpenAbout,
  });

  final bool compact;
  final String section;
  final String title;
  final String subtitle;
  final OverviewSnapshot? snapshot;
  final bool isLoading;
  final String apiBaseUrl;
  final VoidCallback onOpenMessageCenter;
  final VoidCallback onOpenSettings;
  final VoidCallback onDownloadClient;
  final VoidCallback onOpenFeedback;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final notices = snapshot?.notices ?? const <OverviewNoticeData>[];

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactShellHeader(
            title: title,
            subtitle: subtitle,
            snapshot: snapshot,
            isLoading: isLoading,
            onOpenMessageCenter: onOpenMessageCenter,
            onOpenSettings: onOpenSettings,
            onDownloadClient: onDownloadClient,
            onOpenFeedback: onOpenFeedback,
            onOpenAbout: onOpenAbout,
          ),
          if (isLoading && snapshot == null) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (notices.isNotEmpty) ...[
            const SizedBox(height: 8),
            _NoticeBanner(notices: notices),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            _BrandBlock(snapshot: snapshot, apiBaseUrl: apiBaseUrl),
            _PageHeaderBlock(
              section: section,
              title: title,
              subtitle: subtitle,
              snapshot: snapshot,
            ),
            _ShellUtilityBlock(
              snapshot: snapshot,
              apiBaseUrl: apiBaseUrl,
              onOpenMessageCenter: onOpenMessageCenter,
              onOpenSettings: onOpenSettings,
              onDownloadClient: onDownloadClient,
              onOpenFeedback: onOpenFeedback,
              onOpenAbout: onOpenAbout,
            ),
          ],
        ),
        if (isLoading && snapshot == null) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 3),
        ],
        if (notices.isNotEmpty) ...[
          const SizedBox(height: 8),
          _NoticeBanner(notices: notices),
        ],
      ],
    );
  }
}

class _CompactShellHeader extends StatelessWidget {
  const _CompactShellHeader({
    required this.title,
    required this.subtitle,
    required this.snapshot,
    required this.isLoading,
    required this.onOpenMessageCenter,
    required this.onOpenSettings,
    required this.onDownloadClient,
    required this.onOpenFeedback,
    required this.onOpenAbout,
  });

  final String title;
  final String subtitle;
  final OverviewSnapshot? snapshot;
  final bool isLoading;
  final VoidCallback onOpenMessageCenter;
  final VoidCallback onOpenSettings;
  final VoidCallback onDownloadClient;
  final VoidCallback onOpenFeedback;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: _GlassPanel(
        radius: 20,
        blurSigma: 8,
        color: theme.colorScheme.surface.withValues(alpha: 0.80),
        borderColor: theme.colorScheme.outlineVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const _BrandMark(size: 24),
              const SizedBox(width: 8),
              Text('牛牛开盘', style: theme.textTheme.titleMedium),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (snapshot != null) ...[
                _HeaderPill(
                  icon: Icons.calendar_today_rounded,
                  label: snapshot!.tradeDate,
                ),
                const SizedBox(width: 8),
                _HeaderPill(
                  icon: Icons.query_stats_rounded,
                  label: _marketPhaseLabel(snapshot!.shellStatus.marketPhase),
                  tone: _marketPhaseTone(snapshot!.shellStatus.marketPhase),
                ),
                const SizedBox(width: 8),
                _HeaderPill(
                  icon: Icons.storage_rounded,
                  label: _freshnessLabel(snapshot!.shellStatus.dataFreshness),
                  tone: _freshnessTone(snapshot!.shellStatus.dataFreshness),
                ),
              ],
              if (isLoading && snapshot == null) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 80,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              ],
              const SizedBox(width: 12),
              _ShellActionButton(
                icon: Icons.markunread_outlined,
                label: '消息中心',
                onPressed: onOpenMessageCenter,
                highlighted: true,
              ),
              const SizedBox(width: 8),
              _ShellActionButton(
                icon: Icons.tune_rounded,
                label: '设置',
                onPressed: onOpenSettings,
              ),
              const SizedBox(width: 8),
              _ShellActionButton(
                icon: Icons.download_for_offline_rounded,
                label: '下载客户端',
                onPressed: onDownloadClient,
                highlighted: true,
              ),
              const SizedBox(width: 8),
              _ShellActionButton(
                icon: Icons.forum_outlined,
                label: '反馈',
                onPressed: onOpenFeedback,
              ),
              const SizedBox(width: 8),
              _ShellActionButton(
                icon: Icons.info_outline_rounded,
                label: '关于',
                onPressed: onOpenAbout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeaderBlock extends StatelessWidget {
  const _PageHeaderBlock({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.snapshot,
  });

  final String section;
  final String title;
  final String subtitle;
  final OverviewSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frontendBuild = snapshot?.frontendBuild;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: AppTheme.panelDecoration(
          radius: 20,
          color: theme.colorScheme.surface.withValues(alpha: 0.76),
          borderColor: theme.colorScheme.outlineVariant,
          elevated: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeaderPill(
                  icon: Icons.web_asset_rounded,
                  label: section,
                ),
                _HeaderPill(
                  icon: Icons.calendar_today_rounded,
                  label: snapshot?.tradeDate ?? '--',
                ),
                _HeaderPill(
                  icon: Icons.query_stats_rounded,
                  label: _marketPhaseLabel(snapshot?.shellStatus.marketPhase),
                  tone: _marketPhaseTone(snapshot?.shellStatus.marketPhase),
                ),
                _HeaderPill(
                  icon: Icons.storage_rounded,
                  label: _freshnessLabel(snapshot?.shellStatus.dataFreshness),
                  tone: _freshnessTone(snapshot?.shellStatus.dataFreshness),
                ),
                if (frontendBuild != null && frontendBuild.hasData)
                  _HeaderPill(
                    icon: _frontendBuildIcon(frontendBuild),
                    label: _frontendBuildLabel(frontendBuild),
                    tone: _frontendBuildTone(frontendBuild),
                    semanticsLabel: 'pw-shell-frontend-build-jobs',
                    onTap: () => _openJobsPage(context),
                  ),
                if (snapshot != null)
                  _HeaderPill(
                    icon: Icons.schedule_rounded,
                    label: _formatTimestamp(snapshot!.snapshotAt),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.notices,
  });

  final List<OverviewNoticeData> notices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryNotice = notices.first;

    return SizedBox(
      width: double.infinity,
      child: _GlassPanel(
        radius: 16,
        blurSigma: 8,
        color: _noticeBackground(primaryNotice.level),
        borderColor: _noticeBorder(primaryNotice.level),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              _noticeIcon(primaryNotice.level),
              size: 18,
              color: _noticeAccent(primaryNotice.level),
            ),
            Text(
              primaryNotice.title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: _noticeAccent(primaryNotice.level),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Text(
                primaryNotice.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (notices.length > 1)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: AppTheme.chipDecoration(
                  color: theme.colorScheme.surface,
                  borderColor: theme.colorScheme.outlineVariant,
                ),
                child: Text(
                  '+${notices.length - 1} 条',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        _brandIconAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: '牛牛开盘图标',
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppTheme.secondary,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        _brandLogoAsset,
        width: width,
        height: height,
        fit: BoxFit.cover,
        alignment: const Alignment(0, 0.74),
        semanticLabel: '牛牛开盘网站 logo',
        errorBuilder: (context, error, stackTrace) => Text(
          '牛牛开盘',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({
    required this.snapshot,
    required this.apiBaseUrl,
  });

  final OverviewSnapshot? snapshot;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.panelDecoration(
        radius: 20,
        color: theme.colorScheme.surface.withValues(alpha: 0.78),
        borderColor: theme.colorScheme.outlineVariant,
        elevated: false,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BrandMark(size: 30),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BrandLogo(width: 116, height: 34),
                const SizedBox(height: 4),
                Text(
                  snapshot == null
                      ? '牛牛开盘 · ${_shortApiBaseUrl(apiBaseUrl)}'
                      : '牛牛开盘 · ${snapshot!.tradeDate} · ${_shortApiBaseUrl(apiBaseUrl)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellUtilityBlock extends StatelessWidget {
  const _ShellUtilityBlock({
    required this.snapshot,
    required this.apiBaseUrl,
    required this.onOpenMessageCenter,
    required this.onOpenSettings,
    required this.onDownloadClient,
    required this.onOpenFeedback,
    required this.onOpenAbout,
  });

  final OverviewSnapshot? snapshot;
  final String apiBaseUrl;
  final VoidCallback onOpenMessageCenter;
  final VoidCallback onOpenSettings;
  final VoidCallback onDownloadClient;
  final VoidCallback onOpenFeedback;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppTheme.panelDecoration(
          radius: 20,
          color: theme.colorScheme.surface.withValues(alpha: 0.78),
          borderColor: theme.colorScheme.outlineVariant,
          elevated: false,
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              snapshot == null
                  ? '本地三层链路'
                  : '快照 ${_formatTimestamp(snapshot!.snapshotAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            _ShellActionButton(
              icon: Icons.markunread_outlined,
              label: '消息中心',
              onPressed: onOpenMessageCenter,
              highlighted: true,
            ),
            _ShellActionButton(
              icon: Icons.tune_rounded,
              label: '设置',
              onPressed: onOpenSettings,
            ),
            _ShellActionButton(
              icon: Icons.download_for_offline_rounded,
              label: '下载客户端',
              onPressed: onDownloadClient,
              highlighted: true,
            ),
            _ShellActionButton(
              icon: Icons.forum_outlined,
              label: '反馈',
              onPressed: onOpenFeedback,
            ),
            _ShellActionButton(
              icon: Icons.info_outline_rounded,
              label: '关于',
              onPressed: onOpenAbout,
            ),
            Text(
              _shortApiBaseUrl(apiBaseUrl),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellActionButton extends StatelessWidget {
  const _ShellActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    if (highlighted) {
      return FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog({
    required this.initialPreferences,
  });

  final AppPreferences initialPreferences;

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _tdxPathController;
  late final TextEditingController _thsPathController;
  late final TextEditingController _testCodeController;
  late StockLinkClient _stockLinkClient;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _apiBaseUrlController = TextEditingController(
      text: widget.initialPreferences.usesDefaultApiBaseUrl
          ? ''
          : widget.initialPreferences.apiBaseUrl,
    );
    _tdxPathController =
        TextEditingController(text: widget.initialPreferences.tdxPath);
    _thsPathController =
        TextEditingController(text: widget.initialPreferences.thsPath);
    _testCodeController = TextEditingController(text: '000001');
    _stockLinkClient = widget.initialPreferences.stockLinkClient;
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _tdxPathController.dispose();
    _thsPathController.dispose();
    _testCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('设置'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '配置 Flutter 客户端使用的接口地址。留空时回退到构建时注入的地址。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiBaseUrlController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: '接口地址',
                  hintText: defaultApiBaseUrl,
                  errorText: _errorText,
                  helperText: '留空则使用构建参数或启动配置中的接口地址。',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F1E6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('股票联动', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '按旧版桌面端习惯配置优先联动客户端和程序路径。保存后可以直接在股票卡片里打开联动。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<StockLinkClient>(
                      value: _stockLinkClient,
                      decoration: const InputDecoration(
                        labelText: '优先客户端',
                      ),
                      items: StockLinkClient.values
                          .map(
                            (client) => DropdownMenuItem(
                              value: client,
                              child: Text(client.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _stockLinkClient = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tdxPathController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: '通达信路径',
                        hintText: r'C:\...\TdxW.exe',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _thsPathController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: '同花顺路径',
                        hintText: r'C:\...\hexin.exe',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _testCodeController,
                            enabled: !_isSaving,
                            decoration: const InputDecoration(
                              labelText: '测试代码',
                              hintText: '000001',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: _isSaving ? null : _testLinkage,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('测试联动'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '旧版是双击股票联动，新版统一为股票卡片里的打开动作和联动按钮。',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.panelDecoration(
                  radius: 16,
                  color: AppTheme.surfaceSoft.withValues(alpha: 0.78),
                  borderColor: AppTheme.outline,
                  elevated: false,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('构建接口', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    SelectableText(
                      defaultApiBaseUrl.isEmpty ? '未配置' : defaultApiBaseUrl,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '支持 QQ：330202396',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  _apiBaseUrlController.clear();
                  setState(() {
                    _errorText = null;
                  });
                },
          child: const Text('恢复默认'),
        ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? '保存中...' : '保存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final errorText = _validateApiBaseUrl(_apiBaseUrlController.text);
    if (errorText != null) {
      setState(() {
        _errorText = errorText;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    await ref.read(appPreferencesProvider.notifier).savePreferences(
          AppPreferences(
            apiBaseUrl: normalizeApiBaseUrl(_apiBaseUrlController.text),
            tdxPath: _tdxPathController.text.trim(),
            thsPath: _thsPathController.text.trim(),
            stockLinkClient: _stockLinkClient,
          ),
        );

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _settingsSavedMessage(),
        ),
      ),
    );
  }

  Future<void> _testLinkage() async {
    final errorText = _validateApiBaseUrl(_apiBaseUrlController.text);
    if (errorText != null) {
      setState(() {
        _errorText = errorText;
      });
      return;
    }

    final code = _testCodeController.text.trim();
    final result = await ref.read(stockLinkServiceProvider).testPreferredClient(
          code,
          AppPreferences(
            apiBaseUrl: normalizeApiBaseUrl(_apiBaseUrlController.text),
            tdxPath: _tdxPathController.text.trim(),
            thsPath: _thsPathController.text.trim(),
            stockLinkClient: _stockLinkClient,
          ),
        );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? null : AppTheme.danger,
      ),
    );
  }

  String _settingsSavedMessage() {
    final linkState = _selectedClientPath.trim().isEmpty
        ? '${_stockLinkClient.label} 路径待配置'
        : '${_stockLinkClient.label} 已就绪';
    return _apiBaseUrlController.text.trim().isEmpty
        ? '设置已保存，接口地址已恢复默认。$linkState。'
        : '设置已保存，接口地址已更新。$linkState。';
  }

  String get _selectedClientPath {
    return switch (_stockLinkClient) {
      StockLinkClient.tdx => _tdxPathController.text,
      StockLinkClient.ths => _thsPathController.text,
    };
  }
}

class _SupportDialog extends StatefulWidget {
  const _SupportDialog({
    required this.title,
    required this.headline,
    required this.description,
    required this.accent,
    required this.icon,
    this.onIconTap,
  });

  final String title;
  final String headline;
  final String description;
  final Color accent;
  final IconData icon;
  final VoidCallback? onIconTap;

  @override
  State<_SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<_SupportDialog> {
  int _iconTapCount = 0;

  void _handleIconTap() {
    setState(() {
      _iconTapCount++;
    });
    if (_iconTapCount >= 5 && widget.onIconTap != null) {
      widget.onIconTap!();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已解锁任务调度功能。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _handleIconTap,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: widget.accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.headline, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(widget.description,
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.panelDecoration(
                radius: 16,
                color: AppTheme.surfaceSoft.withValues(alpha: 0.78),
                borderColor: AppTheme.outline,
                elevated: false,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('支持方式', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  SelectableText(
                    'QQ: 330202396',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(text: '330202396'),
            );
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('支持 QQ 已复制。')),
            );
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('复制 QQ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _TopIndexStrip extends StatelessWidget {
  const _TopIndexStrip({
    required this.snapshot,
  });

  final OverviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = snapshot.amountSummary;

    return SizedBox(
      width: double.infinity,
      child: _GlassPanel(
        radius: 16,
        blurSigma: 8,
        color: AppTheme.surface.withValues(alpha: 0.84),
        borderColor: theme.colorScheme.outlineVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text('指数带', style: theme.textTheme.titleMedium),
              const SizedBox(width: 10),
              Text(
                _formatTimestamp(snapshot.snapshotAt),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 14),
              ...snapshot.indices.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _RibbonValuePill(
                    label: _displayIndexShortName(item.shortName),
                    value: item.displayValue ?? '--',
                    caption: item.name,
                  ),
                ),
              ),
              _RibbonValuePill(
                label: '成交额',
                value: amount.totalAmountYi == null
                    ? '--'
                    : '${amount.totalAmountYi!.toStringAsFixed(0)} 亿',
                caption: amount.predictedAmountYi == null
                    ? '实时'
                    : '预测 ${amount.predictedAmountYi!.toStringAsFixed(0)} 亿',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopSentimentStrip extends StatelessWidget {
  const _TopSentimentStrip({
    required this.snapshot,
  });

  final OverviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentiment = snapshot.sentiment;
    final breadth = snapshot.breadthSummary;
    final amount = snapshot.amountSummary;
    final metrics = sentiment.metrics.take(4).toList(growable: false);

    return SizedBox(
      width: double.infinity,
      child: _GlassPanel(
        radius: 16,
        blurSigma: 8,
        color: AppTheme.surfaceSoft.withValues(alpha: 0.86),
        borderColor: theme.colorScheme.outlineVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text('情绪带', style: theme.textTheme.titleMedium),
              const SizedBox(width: 10),
              _DarkRibbonPill(
                label: '阶段',
                value: sentiment.stage,
                caption: _biasLabel(sentiment.bias),
              ),
              const SizedBox(width: 10),
              _DarkRibbonPill(
                label: '评分',
                value: '${sentiment.score}',
                caption: '0-100',
                accent: _scoreAccent(sentiment.score),
              ),
              const SizedBox(width: 10),
              _DarkRibbonPill(
                label: '广度',
                value:
                    '${breadth.upCount ?? '--'} / ${breadth.flatCount ?? '--'} / ${breadth.downCount ?? '--'}',
                caption: '涨 / 平 / 跌',
              ),
              const SizedBox(width: 10),
              _DarkRibbonPill(
                label: '较昨',
                value: amount.deltaVsLastYi == null
                    ? '--'
                    : '${amount.deltaVsLastYi! >= 0 ? '+' : ''}${amount.deltaVsLastYi!.toStringAsFixed(0)} 亿',
                caption: '两市成交额',
                accent: (amount.deltaVsLastYi ?? 0) >= 0
                    ? const Color(0xFFF3A24D)
                    : const Color(0xFF58B5A0),
              ),
              ...metrics.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _DarkRibbonPill(
                    label: item.label,
                    value: '${item.today}',
                    caption: _signedInt(item.delta),
                    accent: _deltaColor(item.delta),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMarketStrip extends StatelessWidget {
  const _CompactMarketStrip({
    required this.snapshot,
    required this.preferences,
  });

  final OverviewSnapshot snapshot;
  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = snapshot.amountSummary;
    final sentiment = snapshot.sentiment;
    final breadth = snapshot.breadthSummary;
    final shell = snapshot.shellStatus;
    final jobHealth = shell.jobHealth;

    return SizedBox(
      width: double.infinity,
      child: _GlassPanel(
        radius: 10,
        blurSigma: 8,
        color: AppTheme.surface.withValues(alpha: 0.84),
        borderColor: theme.colorScheme.outlineVariant,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text('盘面', style: theme.textTheme.labelLarge),
              const SizedBox(width: 8),
              _CompactRibbonText(
                label: '快照',
                value: _formatTimestamp(snapshot.snapshotAt),
              ),
              ...snapshot.indices.take(3).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _CompactRibbonText(
                        label: _displayIndexShortName(item.shortName),
                        value: item.displayValue ?? '--',
                      ),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _CompactRibbonText(
                  label: '成交额',
                  value: amount.totalAmountYi == null
                      ? '--'
                      : '${amount.totalAmountYi!.toStringAsFixed(0)} 亿',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _CompactRibbonText(
                  label: '情绪',
                  value: '${sentiment.stage} ${sentiment.score}',
                  accent: _scoreAccent(sentiment.score),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _CompactRibbonText(
                  label: '广度',
                  value:
                      '${breadth.upCount ?? '--'} / ${breadth.flatCount ?? '--'} / ${breadth.downCount ?? '--'}',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _CompactRibbonText(
                  label: '阶段',
                  value: _marketPhaseLabel(shell.marketPhase),
                  accent: _marketPhaseTone(shell.marketPhase) == _Tone.info
                      ? theme.colorScheme.primary
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _CompactRibbonText(
                  label: '任务',
                  value: '${jobHealth.healthyJobs}/${jobHealth.enabledJobs}',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _CompactRibbonText(
                  label: '联动',
                  value: preferences.preferredClientReady
                      ? '${preferences.stockLinkClient.label}就绪'
                      : '${preferences.stockLinkClient.label}待配置',
                  accent: preferences.preferredClientReady
                      ? theme.colorScheme.primary
                      : AppTheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactRibbonText extends StatelessWidget {
  const _CompactRibbonText({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft.withValues(alpha: 0.68),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _TopTabStrip extends StatelessWidget {
  const _TopTabStrip({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: _GlassPanel(
        radius: 10,
        blurSigma: 8,
        color: AppTheme.surfaceSoft.withValues(alpha: 0.8),
        borderColor: Theme.of(context).colorScheme.outlineVariant,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(destinations.length, (index) {
              final destination = destinations[index];
              return Padding(
                padding: EdgeInsets.only(
                    right: index == destinations.length - 1 ? 0 : 6),
                child: _TopTabItem(
                  destination: destination,
                  selected: index == selectedIndex,
                  onTap: () => onSelected(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _RibbonValuePill extends StatelessWidget {
  const _RibbonValuePill({
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
      constraints: const BoxConstraints(minWidth: 106),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: AppTheme.chipDecoration(
        radius: 14,
        color: AppTheme.surfaceSoft,
        borderColor: theme.colorScheme.outlineVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(caption, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DarkRibbonPill extends StatelessWidget {
  const _DarkRibbonPill({
    required this.label,
    required this.value,
    required this.caption,
    this.accent = Colors.white,
  });

  final String label;
  final String value;
  final String caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 106),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: accent),
          ),
          const SizedBox(height: 2),
          Text(caption, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TopTabItem extends StatelessWidget {
  const _TopTabItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: ValueKey('shell-nav-${destination.path}'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                destination.icon,
                size: 18,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 8),
              Text(
                destination.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.76),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _IndexSummaryPanel extends StatelessWidget {
  const _IndexSummaryPanel({
    required this.snapshot,
  });

  final OverviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('指数摘要', style: theme.textTheme.titleLarge),
              ),
              Text(
                _formatTimestamp(snapshot.snapshotAt),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: snapshot.indices
                .map(
                  (item) => Container(
                    width: 132,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.74),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.shortName,
                            style: theme.textTheme.labelMedium),
                        const SizedBox(height: 6),
                        Text(
                          item.displayValue ?? '--',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(item.name, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _SentimentSummaryPanel extends StatelessWidget {
  const _SentimentSummaryPanel({
    required this.snapshot,
  });

  final OverviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentiment = snapshot.sentiment;
    final breadth = snapshot.breadthSummary;
    final amount = snapshot.amountSummary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102721),
        borderRadius: BorderRadius.circular(24),
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
                    Text(
                      '情绪概览',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${sentiment.stage}  |  ${_biasLabel(sentiment.bias)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xC9F0E6DA),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _scoreBackground(sentiment.score),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Score',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sentiment.score}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: sentiment.score / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                _scoreAccent(sentiment.score),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sentiment.metrics
                .map(
                  (item) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.today}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _signedInt(item.delta),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _deltaColor(item.delta),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _InlineStat(
                label: '广度',
                value:
                    '${breadth.upCount ?? '--'} / ${breadth.flatCount ?? '--'} / ${breadth.downCount ?? '--'}',
              ),
              _InlineStat(
                label: '成交额',
                value: amount.totalAmountYi == null
                    ? '--'
                    : '${amount.totalAmountYi!.toStringAsFixed(0)} 亿',
              ),
              _InlineStat(
                label: '较昨',
                value: amount.deltaVsLastYi == null
                    ? '--'
                    : '${amount.deltaVsLastYi! >= 0 ? '+' : ''}${amount.deltaVsLastYi!.toStringAsFixed(0)} 亿',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShellStatusStrip extends StatelessWidget {
  const _ShellStatusStrip({
    required this.snapshot,
    required this.preferences,
  });

  final OverviewSnapshot? snapshot;
  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final shell = snapshot?.shellStatus;
    final runtimeMeta = snapshot?.runtimeMeta;
    final frontendBuild = snapshot?.frontendBuild;
    final jobHealth = shell?.jobHealth;
    final watchedJobs = shell?.watchedJobs ?? const <OverviewWatchedJobData>[];

    return SizedBox(
      width: double.infinity,
      child: _GlassPanel(
        radius: 18,
        blurSigma: 8,
        color: AppTheme.surface.withValues(alpha: 0.82),
        borderColor: Theme.of(context).colorScheme.outlineVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusTag(
              icon: Icons.av_timer_rounded,
              label: '阶段 ${_marketPhaseLabel(shell?.marketPhase)}',
            ),
            _StatusTag(
              icon: Icons.sync_rounded,
              label: shell == null
                  ? '等待首页快照'
                  : '${_freshnessLabel(shell.dataFreshness)}  ${_formatAge(shell.snapshotAgeSeconds)}',
            ),
            _StatusTag(
              icon: Icons.task_alt_rounded,
              label: jobHealth == null
                  ? '任务状态 --'
                  : '任务 ${jobHealth.healthyJobs}/${jobHealth.enabledJobs} 正常',
            ),
            _StatusTag(
              icon: Icons.desktop_windows_rounded,
              label: _stockClientStatusLabel(preferences),
              tone: _stockClientStatusTone(preferences),
            ),
            if (runtimeMeta != null && runtimeMeta.hasData)
              _StatusTag(
                icon: _runtimeMetaIcon(runtimeMeta),
                label: _runtimeMetaLabel(runtimeMeta),
                tone: _runtimeMetaTone(runtimeMeta),
              ),
            if (frontendBuild != null && frontendBuild.hasData)
              _StatusTag(
                icon: _frontendBuildIcon(frontendBuild),
                label: _frontendBuildLabel(frontendBuild),
                tone: _frontendBuildTone(frontendBuild),
                semanticsLabel: 'pw-shell-frontend-build-jobs',
                onTap: () => _openJobsPage(context),
              ),
            if (frontendBuild != null &&
                (frontendBuild.apiBaseUrl?.isNotEmpty ?? false))
              _StatusTag(
                icon: Icons.link_rounded,
                label: '接口 ${_shortApiBaseUrl(frontendBuild.apiBaseUrl!)}',
                tone: _Tone.info,
                semanticsLabel: 'pw-shell-frontend-build-api-jobs',
                onTap: () => _openJobsPage(context),
              ),
            if (frontendBuild != null &&
                (frontendBuild.effectiveBuiltAt?.isNotEmpty ?? false))
              _StatusTag(
                icon: Icons.layers_outlined,
                label:
                    '前端包 ${_formatTimestamp(frontendBuild.effectiveBuiltAt)}',
                semanticsLabel: 'pw-shell-frontend-build-time-jobs',
                onTap: () => _openJobsPage(context),
              ),
            if (runtimeMeta != null && runtimeMeta.hasData)
              _StatusTag(
                icon: Icons.timer_outlined,
                label:
                    '缓存 ${runtimeMeta.cacheAgeMs}ms / 有效期 ${runtimeMeta.cacheTtlMs}ms',
                tone: runtimeMeta.cacheHit ? _Tone.info : _Tone.neutral,
              ),
            if (jobHealth != null)
              _StatusTag(
                icon: Icons.error_outline_rounded,
                label:
                    '警告 ${jobHealth.warningJobs}  失败 ${jobHealth.failedJobs}',
                tone: jobHealth.failedJobs > 0
                    ? _Tone.warning
                    : jobHealth.warningJobs > 0
                        ? _Tone.info
                        : _Tone.neutral,
              ),
            if (runtimeMeta != null && runtimeMeta.hasData)
              _StatusTag(
                icon: Icons.update_rounded,
                label:
                    '刷新 ${_formatTimestamp(runtimeMeta.refreshedAt ?? snapshot?.generatedAt)}',
              ),
            if (runtimeMeta != null &&
                runtimeMeta.hasData &&
                (runtimeMeta.refreshedAt?.isEmpty ?? true))
              _StatusTag(
                icon: Icons.update_rounded,
                label: '生成 ${_formatTimestamp(snapshot!.generatedAt)}',
              ),
            if (snapshot != null &&
                (runtimeMeta == null || !runtimeMeta.hasData))
              _StatusTag(
                icon: Icons.update_rounded,
                label: '生成 ${_formatTimestamp(snapshot!.generatedAt)}',
              ),
            ...watchedJobs.take(3).map(
                  (job) => _StatusTag(
                    icon: _jobIcon(job.health),
                    label:
                        '${_displayJobName(job.name)} ${_jobHealthLabel(job.health)}',
                    tone: _jobTone(job.health),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.icon,
    required this.label,
    this.tone = _Tone.neutral,
    this.onTap,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final _Tone tone;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = switch (tone) {
      _Tone.warning => AppTheme.secondary.withValues(alpha: 0.16),
      _Tone.info => theme.colorScheme.primary.withValues(alpha: 0.16),
      _Tone.neutral => AppTheme.surfaceSoft,
    };
    final foreground = switch (tone) {
      _Tone.warning => AppTheme.secondary,
      _Tone.info => theme.colorScheme.primary,
      _Tone.neutral => theme.colorScheme.onSurface,
    };

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: AppTheme.chipDecoration(
        radius: 6,
        color: background,
        borderColor: foreground.withValues(alpha: 0.18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    this.tone = _Tone.neutral,
    this.onTap,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final _Tone tone;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = switch (tone) {
      _Tone.warning => AppTheme.secondary.withValues(alpha: 0.16),
      _Tone.info => theme.colorScheme.primary.withValues(alpha: 0.16),
      _Tone.neutral => AppTheme.surfaceSoft,
    };
    final foreground = switch (tone) {
      _Tone.warning => AppTheme.secondary,
      _Tone.info => theme.colorScheme.primary,
      _Tone.neutral => theme.colorScheme.onSurface,
    };

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: AppTheme.chipDecoration(
        radius: 6,
        color: background,
        borderColor: foreground.withValues(alpha: 0.18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ShellSidebar extends StatelessWidget {
  const _ShellSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 272,
      decoration: BoxDecoration(
        color: const Color(0xFF16231F),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x263F5A51)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _BrandMark(size: 34),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: _BrandLogo(width: 154, height: 40),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '采集、接口和桌面客户端保持在同一套交易工作台里。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xC6D9D2CC),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '功能导航',
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0x80F6F0E7),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: destinations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _SidebarNavItem(
                  destination: destinations[index],
                  selected: index == selectedIndex,
                  onTap: () => onSelected(index),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x0CB7853E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x1FB7853E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本地工作台',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0x99F6F0E7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '总览壳层统一读取公告、情绪和任务健康状态。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xD4F6F0E7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF22362F)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0x2CB7853E)
                  : Colors.white.withValues(alpha: 0.04),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFB7853E)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  destination.icon,
                  size: 20,
                  color: selected ? Colors.white : const Color(0xFFE9E1D6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.shortLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0x99F6F0E7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.radius = 24,
    this.blurSigma = 16,
    this.padding = EdgeInsets.zero,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final double radius;
  final double blurSigma;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: AppTheme.panelDecoration(
            radius: radius,
            color: color,
            borderColor: borderColor,
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.path,
    required this.label,
    required this.shortLabel,
    required this.icon,
  });

  final String path;
  final String label;
  final String shortLabel;
  final IconData icon;
}

enum _Tone {
  neutral,
  info,
  warning,
}

String _marketPhaseLabel(String? phase) {
  return switch (phase) {
    'pre_open' => '盘前',
    'auction' => '竞价',
    'trading' => '交易中',
    'midday_break' => '午间',
    'post_close' => '收盘后',
    _ => '未连接',
  };
}

_Tone _marketPhaseTone(String? phase) {
  return switch (phase) {
    'auction' || 'trading' => _Tone.info,
    'post_close' => _Tone.neutral,
    _ => _Tone.warning,
  };
}

String _freshnessLabel(String? freshness) {
  return switch (freshness) {
    'live' => '实时快照',
    'watch' => '关注延迟',
    'stale' => '快照滞后',
    _ => '待同步',
  };
}

String _displayIndexShortName(String value) {
  return switch (value.toUpperCase()) {
    'SH' => '上证',
    'SZ' => '深成',
    'CY' => '创业',
    _ => value,
  };
}

_Tone _freshnessTone(String? freshness) {
  return switch (freshness) {
    'live' => _Tone.info,
    'watch' => _Tone.neutral,
    _ => _Tone.warning,
  };
}

String _biasLabel(String bias) {
  return switch (bias) {
    'risk_on' => '偏强',
    'risk_off' => '偏弱',
    _ => '中性',
  };
}

String _formatTimestamp(String? value) {
  if (value == null || value.isEmpty) {
    return '--';
  }
  return value.replaceFirst('T', ' ').split('.').first;
}

String _formatAge(int? seconds) {
  if (seconds == null) {
    return '--';
  }
  if (seconds < 60) {
    return '${seconds}s';
  }
  if (seconds < 3600) {
    return '${(seconds / 60).floor()}m';
  }
  return '${(seconds / 3600).floor()}h';
}

String _signedInt(int value) {
  if (value > 0) {
    return '+$value';
  }
  return '$value';
}

String _shortApiBaseUrl(String value) {
  final normalized = normalizeApiBaseUrl(value);
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.isEmpty) {
    return normalized;
  }

  final buffer = StringBuffer(uri.host);
  if (uri.hasPort) {
    buffer.write(':${uri.port}');
  }
  if (uri.path.isNotEmpty && uri.path != '/') {
    buffer.write(uri.path);
  }
  return buffer.toString();
}

void _openJobsPage(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go('/jobs');
  }
}

String? _validateApiBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return '请输入完整的 http/https 地址。';
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return '仅支持 http 和 https 接口。';
  }
  return null;
}

String _stockClientStatusLabel(AppPreferences preferences) {
  final client = preferences.stockLinkClient;
  final state = preferences.preferredClientReady ? '就绪' : '待配置';
  return '联动 ${client.label} $state';
}

_Tone _stockClientStatusTone(AppPreferences preferences) {
  if (preferences.preferredClientReady) {
    return _Tone.info;
  }
  if (preferences.hasAnyStockClientConfigured) {
    return _Tone.neutral;
  }
  return _Tone.warning;
}

Color _deltaColor(int delta) {
  if (delta > 0) {
    return AppTheme.rise;
  }
  if (delta < 0) {
    return AppTheme.fall;
  }
  return Colors.white.withValues(alpha: 0.68);
}

Color _scoreBackground(int score) {
  if (score >= 68) {
    return AppTheme.rise.withValues(alpha: 0.22);
  }
  if (score <= 36) {
    return AppTheme.fall.withValues(alpha: 0.22);
  }
  return AppTheme.secondary.withValues(alpha: 0.18);
}

Color _scoreAccent(int score) {
  if (score >= 68) {
    return AppTheme.rise;
  }
  if (score <= 36) {
    return AppTheme.fall;
  }
  return AppTheme.secondary;
}

Color _noticeBackground(String level) {
  return switch (level) {
    'warning' => AppTheme.secondary.withValues(alpha: 0.12),
    'error' => AppTheme.danger.withValues(alpha: 0.14),
    _ => Colors.white.withValues(alpha: 0.08),
  };
}

Color _noticeBorder(String level) {
  return switch (level) {
    'warning' => AppTheme.secondary.withValues(alpha: 0.24),
    'error' => AppTheme.danger.withValues(alpha: 0.24),
    _ => Colors.white.withValues(alpha: 0.10),
  };
}

Color _noticeAccent(String level) {
  return switch (level) {
    'warning' => AppTheme.secondary,
    'error' => AppTheme.danger,
    _ => AppTheme.primary,
  };
}

IconData _noticeIcon(String level) {
  return switch (level) {
    'warning' => Icons.campaign_rounded,
    'error' => Icons.error_outline_rounded,
    _ => Icons.info_outline_rounded,
  };
}

IconData _jobIcon(String health) {
  return switch (health) {
    'failed' => Icons.error_outline_rounded,
    'warning' => Icons.visibility_outlined,
    'queued' => Icons.hourglass_top_rounded,
    'healthy' => Icons.check_circle_outline_rounded,
    _ => Icons.refresh_rounded,
  };
}

String _jobHealthLabel(String health) {
  return switch (health) {
    'failed' => '失败',
    'warning' => '待关注',
    'queued' => '排队',
    'healthy' => '正常',
    _ => '停用',
  };
}

String _displayJobName(String value) {
  final normalized = value.trim();
  const labels = {
    'board height': '连板高度',
    'auction ranks': '竞价榜单',
    'auction live': '竞价直播',
    'calendar timeline': '财经日历',
    'index kline': '指数 K 线',
    'index quotes': '指数报价',
    'limit review': '涨停复盘',
    'review page': '涨停复盘',
    'plate rotation': '板块轮动',
    'plate stocks': '板块成分',
    'market overview': '盘面总览',
    'market center': '行情中心',
    'news 724': '7x24 资讯',
    'news center': '资讯中心',
    'node plates': '节点板块',
    'yesterday stats': '空头数据',
    'news': '资讯',
  };
  return labels[normalized.toLowerCase()] ?? normalized;
}

_Tone _jobTone(String health) {
  return switch (health) {
    'failed' => _Tone.warning,
    'warning' => _Tone.warning,
    'queued' => _Tone.neutral,
    'healthy' => _Tone.info,
    _ => _Tone.neutral,
  };
}

_Tone _runtimeMetaTone(OverviewRuntimeMetaData meta) {
  if (meta.staleFallback) {
    return _Tone.warning;
  }
  if (meta.cacheHit || meta.forceRefreshApplied) {
    return _Tone.info;
  }
  return _Tone.neutral;
}

_Tone _frontendBuildTone(OverviewFrontendBuildData build) {
  if (build.stale) {
    return _Tone.warning;
  }
  if (build.hasData) {
    return _Tone.info;
  }
  return _Tone.neutral;
}

IconData _frontendBuildIcon(OverviewFrontendBuildData build) {
  if (build.stale) {
    return Icons.layers_clear_rounded;
  }
  if (build.hasData) {
    return Icons.layers_rounded;
  }
  return Icons.help_outline_rounded;
}

String _frontendBuildLabel(OverviewFrontendBuildData build) {
  if (build.stale) {
    return '前端包需重建';
  }
  if (build.externallyServed) {
    return '外部前端在线';
  }
  if (build.hasData) {
    return '前端包已同步';
  }
  return '缺少构建信息';
}

IconData _runtimeMetaIcon(OverviewRuntimeMetaData meta) {
  if (meta.staleFallback) {
    return Icons.history_toggle_off_rounded;
  }
  if (meta.forceRefreshApplied) {
    return Icons.sync_rounded;
  }
  if (meta.cacheHit) {
    return Icons.bolt_rounded;
  }
  return Icons.cloud_done_rounded;
}

String _runtimeMetaLabel(OverviewRuntimeMetaData meta) {
  if (meta.staleFallback) {
    return '使用滞后快照';
  }
  if (meta.forceRefreshApplied) {
    return '强制刷新';
  }
  if (meta.cacheHit) {
    return '缓存命中';
  }
  return '最新快照';
}
