import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/layout/app_shell.dart';
import '../application/jobs_provider.dart';
import '../data/jobs_repository.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  bool _isRefreshing = false;
  final Set<String> _triggeringJobCodes = <String>{};

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsProvider);

    return AppShell(
      currentPath: '/jobs',
      title: '任务调度',
      subtitle: '直接读取接口服务的运维快照，核对采集服务、前端服务、开机任务和每个抓取作业的真实状态。',
      child: jobsAsync.when(
        data: (page) => LayoutBuilder(
          builder: (context, constraints) {
            final serviceCardWidth = _responsiveWidth(constraints.maxWidth,
                compact: 1, medium: 2, wide: 3);
            final jobCardWidth = _responsiveWidth(constraints.maxWidth,
                compact: 1, medium: 2, wide: 2);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _OverviewPanel(
                    page: page,
                    isRefreshing: _isRefreshing,
                    onRefresh: _refresh,
                  ),
                  const SizedBox(height: 16),
                  _FrontendBuildPanel(buildInfo: page.frontendBuild),
                  const SizedBox(height: 16),
                  _StartupTaskPanel(task: page.startupTask),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: '服务栈状态',
                    subtitle: '三段脚本状态来自根目录 status.ps1，日志展示标准输出/错误输出的尾部内容。',
                    trailing:
                        '${page.summary.runningServices}/${page.summary.totalServices} 运行中',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: page.services
                        .map(
                          (service) => SizedBox(
                            width: serviceCardWidth,
                            child: _ServiceCard(service: service),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: '抓取任务明细',
                    subtitle: '按采集服务的抓取配置和最近一次运行结果，核对每个任务的调度方式、窗口和写入情况。',
                    trailing: '${page.jobs.length} 个任务',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: page.jobs
                        .map(
                          (job) => SizedBox(
                            width: jobCardWidth,
                            child: _JobCard(
                              job: job,
                              isTriggering:
                                  _triggeringJobCodes.contains(job.jobCode),
                              onTrigger: () => _triggerJob(job),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                  _RunListPanel(
                    title: '最近运行',
                    subtitle: '按 sys_fetch_run 最新记录展示，辅助判断手动触发是否已进入队列。',
                    emptyText: '暂无运行记录',
                    runs: page.recentRuns,
                    highlightFailures: false,
                  ),
                  const SizedBox(height: 16),
                  _RunListPanel(
                    title: '失败记录',
                    subtitle: '失败和错误消息由接口服务结构化输出，页面不再从日志文本临时拼装。',
                    emptyText: '暂无失败记录',
                    runs: page.failures,
                    highlightFailures: true,
                  ),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: _JobsErrorState(
            error: error,
            isRefreshing: _isRefreshing,
            onRetry: _refresh,
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
    });
    try {
      await ref.read(jobsRepositoryProvider).fetchPage(forceRefresh: true);
      ref.invalidate(jobsProvider);
      await ref.read(jobsProvider.future);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _triggerJob(JobPageItem job) async {
    if (_triggeringJobCodes.contains(job.jobCode) || !job.triggerAllowed) {
      return;
    }
    setState(() {
      _triggeringJobCodes.add(job.jobCode);
    });
    try {
      final result =
          await ref.read(jobsRepositoryProvider).triggerJob(job.jobCode);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已下发 ${_displayJobName(job.name)}，运行 #${result.queuedRunId} ${_displayRunStatus(result.status)}',
          ),
        ),
      );
      ref.invalidate(jobsProvider);
      await ref.read(jobsProvider.future);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('手动触发失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _triggeringJobCodes.remove(job.jobCode);
        });
      }
    }
  }

  double _responsiveWidth(
    double maxWidth, {
    required int compact,
    required int medium,
    required int wide,
  }) {
    final columns = maxWidth >= 1560
        ? wide
        : maxWidth >= 980
            ? medium
            : compact;
    final spacing = 12.0 * (columns - 1);
    final width = (maxWidth - spacing) / columns;
    return width.isFinite && width > 0 ? width : maxWidth;
  }
}

class _JobsErrorState extends StatelessWidget {
  const _JobsErrorState({
    required this.error,
    required this.isRefreshing,
    required this.onRetry,
  });

  final Object error;
  final bool isRefreshing;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.panelDecoration(
        radius: 28,
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.96),
            AppTheme.surfaceStrong.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderColor: Colors.white.withValues(alpha: 0.08),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('任务调度暂时不可用', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            '当前请求失败，先保留真实错误信息，同时允许直接重新拉取 jobs 快照。',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          SelectableText(
            '$error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 18),
          Semantics(
            button: !isRefreshing,
            label: 'pw-jobs-refresh',
            child: FilledButton.tonalIcon(
              onPressed: isRefreshing ? null : onRetry,
              icon: isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(isRefreshing ? '刷新中' : '刷新快照'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.page,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final JobPageSnapshot page;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = page.summary;

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 8,
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.96),
            AppTheme.surfaceStrong.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderColor: Colors.white.withValues(alpha: 0.10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('调度面板', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '生成 ${_formatTimestamp(page.generatedAt)}，展示真实接口快照。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Semantics(
                button: !isRefreshing,
                label: 'pw-jobs-refresh',
                child: FilledButton.tonalIcon(
                  onPressed: isRefreshing ? null : onRefresh,
                  icon: isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(isRefreshing ? '刷新中' : '刷新快照'),
                ),
              ),
              _Badge(
                icon: Icons.schedule_rounded,
                label: _startupTaskStateLabel(summary.startupTaskState),
                tone: _startupTaskTone(summary.startupTaskState),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Badge(
                icon: _runtimeMetaIcon(page.runtimeMeta),
                label: _runtimeMetaLabel(page.runtimeMeta),
                tone: _runtimeMetaTone(page.runtimeMeta),
              ),
              _Badge(
                icon: Icons.timer_outlined,
                label:
                    '缓存 ${page.runtimeMeta.cacheAgeMs}ms / 有效期 ${page.runtimeMeta.cacheTtlMs}ms',
                tone: page.runtimeMeta.cacheHit
                    ? _StatusTone.info
                    : _StatusTone.healthy,
              ),
              _Badge(
                icon: Icons.update_rounded,
                label:
                    '刷新 ${_formatTimestamp(page.runtimeMeta.refreshedAt ?? page.generatedAt)}',
                tone: _StatusTone.info,
              ),
              _Badge(
                icon: Icons.health_and_safety_outlined,
                label: '就绪 ${summary.readyServices}/${summary.totalServices}',
                tone: summary.readyServices == summary.totalServices
                    ? _StatusTone.healthy
                    : _StatusTone.warning,
              ),
            ],
          ),
          if (page.runtimeError != null &&
              page.runtimeError!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppTheme.danger.withValues(alpha: 0.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.danger,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      page.runtimeError!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (page.notices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: page.notices
                  .map((notice) => _NoticeChip(notice: notice))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: '任务总数',
                value: '${summary.totalJobs}',
                caption: '启用 ${summary.enabledJobs}',
                accent: theme.colorScheme.primary,
              ),
              _MetricCard(
                label: '健康任务',
                value: '${summary.healthyJobs}',
                caption:
                    '待关注 ${summary.warningJobs} / 失败 ${summary.failedJobs}',
                accent: AppTheme.success,
              ),
              _MetricCard(
                label: '排队运行',
                value: '${summary.queuedJobs}',
                caption: '排队 / 运行中 / 等待',
                accent: AppTheme.secondary,
              ),
              _MetricCard(
                label: '服务在线',
                value: '${summary.runningServices}/${summary.totalServices}',
                caption: '采集 / 接口 / 前端',
                accent: AppTheme.secondary,
              ),
              _MetricCard(
                label: _startupTaskMetricLabel(summary.startupTaskState),
                value: _startupTaskMetricValue(summary),
                caption: _startupTaskMetricCaption(summary),
                accent: summary.startupTaskInstalled
                    ? AppTheme.primary
                    : AppTheme.danger,
              ),
              _MetricCard(
                label: '风险关注',
                value: '${summary.warningJobs + summary.failedJobs}',
                caption: '需要人工复核的任务数',
                accent: summary.failedJobs > 0
                    ? AppTheme.danger
                    : AppTheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FrontendBuildPanel extends StatelessWidget {
  const _FrontendBuildPanel({
    required this.buildInfo,
  });

  final JobFrontendBuildData buildInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 8,
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderColor: theme.colorScheme.outlineVariant,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('客户端构建', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '区分前端包新鲜度和静态服务进程状态，避免运行中的服务仍在分发旧包。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _Badge(
                icon: _frontendBuildIcon(buildInfo),
                label: _frontendBuildLabel(buildInfo),
                tone: _frontendBuildTone(buildInfo),
              ),
              if (buildInfo.apiBaseUrl != null)
                _Badge(
                  icon: Icons.link_rounded,
                  label: '接口已连接',
                  tone: _StatusTone.info,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DetailChip(
                icon: Icons.inventory_2_outlined,
                label: '构建时间',
                value: _formatTimestamp(buildInfo.effectiveBuiltAt),
              ),
              _DetailChip(
                icon: Icons.source_outlined,
                label: '源码时间',
                value: _formatTimestamp(buildInfo.sourceUpdatedAt),
              ),
              _DetailChip(
                icon: buildInfo.externallyServed
                    ? Icons.public_rounded
                    : Icons.api_rounded,
                label: buildInfo.externallyServed ? '静态服务' : '接口',
                value: buildInfo.externallyServed
                    ? '外部前端在线'
                    : ((buildInfo.apiBaseUrl?.isNotEmpty ?? false)
                        ? '已连接'
                        : '--'),
              ),
              _DetailChip(
                icon: Icons.rule_folder_outlined,
                label: '原因数',
                value: '${buildInfo.reasons.length}',
              ),
            ],
          ),
          if (buildInfo.reasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: buildInfo.stale
                    ? AppTheme.secondary.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: buildInfo.stale
                      ? AppTheme.secondary.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FactLine(
                    label: '原因 1',
                    value: _displayBuildReason(buildInfo.reasons.first),
                  ),
                  for (var index = 1;
                      index < buildInfo.reasons.length;
                      index += 1)
                    _FactLine(
                      label: '原因 ${index + 1}',
                      value: _displayBuildReason(buildInfo.reasons[index]),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StartupTaskPanel extends StatelessWidget {
  const _StartupTaskPanel({
    required this.task,
  });

  final JobStartupTaskData task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final containerized = _isContainerizedRuntime(task.state);

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 8,
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderColor: theme.colorScheme.outlineVariant,
      ),
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
                      containerized ? '运行托管' : '开机自启任务',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      containerized
                          ? '生产环境由 Docker Compose 托管采集、接口与前端服务，状态以容器和探测结果为准。'
                          : 'Windows 计划任务负责开机后拉起三段服务，避免桌面端看起来可打开但后台未实际启动。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Badge(
                icon: containerized
                    ? Icons.hub_rounded
                    : Icons.desktop_windows_rounded,
                label: _startupTaskStateLabel(task.state),
                tone: _startupTaskTone(task.state),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DetailChip(
                icon: containerized ? Icons.hub_rounded : Icons.task_alt_rounded,
                label: containerized ? '托管方式' : '任务名',
                value: task.taskName,
              ),
              _DetailChip(
                icon: Icons.extension_rounded,
                label: containerized ? '编排状态' : '是否存在',
                value: task.exists
                    ? (containerized ? '已接管' : '已安装')
                    : '缺失',
              ),
              _DetailChip(
                icon: Icons.power_settings_new_rounded,
                label: containerized ? '运行策略' : '是否启用',
                value: task.enabled
                    ? (containerized ? '自动拉起' : '已启用')
                    : '未启用',
              ),
              _DetailChip(
                icon: Icons.person_outline_rounded,
                label: '作者',
                value: task.author ?? '--',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
  });

  final JobServiceStatusData service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 8,
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderColor: theme.colorScheme.outlineVariant,
      ),
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
                      _displayServiceName(service.name),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayServiceWorkDir(service),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Badge(
                icon: service.running
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                label: service.running ? '运行中' : '未运行',
                tone:
                    service.running ? _StatusTone.healthy : _StatusTone.failed,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(
                icon: _serviceReadinessIcon(service),
                label: _serviceReadinessLabel(service),
                tone: _serviceReadinessTone(service),
              ),
              _Badge(
                icon: Icons.monitor_heart_outlined,
                label: _serviceProbeValue(service),
                tone: service.ready ? _StatusTone.info : _StatusTone.warning,
              ),
              if (service.probeLatencyMs > 0)
                _Badge(
                  icon: Icons.speed_rounded,
                  label: '延迟 ${service.probeLatencyMs}ms',
                  tone: _StatusTone.info,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailChip(
                icon: Icons.widgets_outlined,
                label: '类型',
                value: _displayServiceKind(service.kind),
              ),
              _DetailChip(
                icon: Icons.usb_rounded,
                label: 'PID',
                value: service.pids.isEmpty ? '--' : service.pids.join(' / '),
              ),
              _DetailChip(
                icon: Icons.wifi_tethering_rounded,
                label: '端口',
                value: service.port?.toString() ?? '--',
              ),
              _DetailChip(
                icon: Icons.inventory_2_outlined,
                label: '依赖',
                value: service.requiredExists ? '就绪' : '缺失',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FactLine(
                  label: '检查时间',
                  value: _formatTimestamp(service.probeCheckedAt),
                ),
                _FactLine(
                  label: '探测目标',
                  value: service.probeTarget ?? '--',
                ),
              ],
            ),
          ),
          if (service.probeError != null &&
              service.probeError!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.wifi_tethering_error_rounded,
                    color: AppTheme.secondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _displayJobMessage(service.probeError),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _LogBlock(
            title: '标准输出',
            updatedAt: service.stdoutUpdatedAt,
            path: service.stdoutPath,
            lines: service.stdoutTail,
          ),
          const SizedBox(height: 12),
          _LogBlock(
            title: '错误输出',
            updatedAt: service.stderrUpdatedAt,
            path: service.stderrPath,
            lines: service.stderrTail,
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.isTriggering,
    required this.onTrigger,
  });

  final JobPageItem job;
  final bool isTriggering;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 8,
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderColor: theme.colorScheme.outlineVariant,
      ),
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
                      _displayJobName(job.name),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '任务代码 ${_displayEndpointKey(job.jobCode)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Badge(
                icon: _jobHealthIcon(job.health),
                label: _jobHealthLabel(job.health),
                tone: _jobHealthTone(job.health),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_displaySource(job.source)} / ${_displayEndpointKey(job.endpointKey)}',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailChip(
                icon: Icons.sync_rounded,
                label: '调度',
                value: _scheduleLabel(job),
              ),
              _DetailChip(
                icon: Icons.timelapse_rounded,
                label: '窗口',
                value: _windowLabel(job.windowStart, job.windowEnd),
              ),
              _DetailChip(
                icon: Icons.repeat_rounded,
                label: '日上限',
                value: '${job.maxRunsPerDay}',
              ),
              _DetailChip(
                icon: Icons.edit_note_rounded,
                label: '写入行数',
                value: '${job.lastRowsWritten}',
              ),
              _DetailChip(
                icon: Icons.speed_rounded,
                label: '耗时',
                value: _formatDurationMs(job.lastDurationMs),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            button: job.triggerAllowed && !isTriggering,
            label: 'pw-jobs-trigger-${job.jobCode}',
            onTap: job.triggerAllowed && !isTriggering ? onTrigger : null,
            child: ExcludeSemantics(
              child: FilledButton.tonalIcon(
                onPressed:
                    job.triggerAllowed && !isTriggering ? onTrigger : null,
                icon: isTriggering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(isTriggering ? '下发中' : '手动触发'),
              ),
            ),
          ),
          if (!job.triggerAllowed &&
              job.triggerBlockReason != null &&
              job.triggerBlockReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _displayJobMessage(job.triggerBlockReason),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.secondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FactLine(
                  label: '最近状态',
                  value: _displayRunStatus(job.lastStatus),
                ),
                _FactLine(
                    label: '开始时间', value: _formatTimestamp(job.lastStartedAt)),
                _FactLine(
                    label: '完成时间', value: _formatTimestamp(job.lastFinishedAt)),
                _FactLine(label: '启用状态', value: job.enabled ? '启用' : '停用'),
              ],
            ),
          ),
          if (job.lastErrorMessage != null &&
              job.lastErrorMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppTheme.danger.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.report_gmailerrorred_rounded,
                    color: AppTheme.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _displayJobMessage(job.lastErrorMessage),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RunListPanel extends StatelessWidget {
  const _RunListPanel({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.runs,
    required this.highlightFailures,
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final List<JobPageRunItemData> runs;
  final bool highlightFailures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: AppTheme.panelDecoration(
        radius: 8,
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderColor: theme.colorScheme.outlineVariant,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: '${runs.length} 条',
          ),
          const SizedBox(height: 12),
          if (runs.isEmpty)
            Text(emptyText, style: theme.textTheme.bodyLarge)
          else
            Column(
              children: runs
                  .take(8)
                  .map(
                    (run) => _RunRow(
                      run: run,
                      highlightFailures: highlightFailures,
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({
    required this.run,
    required this.highlightFailures,
  });

  final JobPageRunItemData run;
  final bool highlightFailures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = _isFailureStatus(run.status) ||
        (run.error != null && run.error!.trim().isNotEmpty);
    final accent = failed ? AppTheme.danger : theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: failed && highlightFailures
            ? AppTheme.danger.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: failed && highlightFailures
              ? AppTheme.danger.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              '#${run.runId}',
              style: theme.textTheme.labelLarge?.copyWith(color: accent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_displayJobName(run.name)} · ${_displayRunStatus(run.status)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    _displayEndpointKey(run.jobCode),
                    run.tradeDate ?? '--',
                    _formatTimestamp(run.startedAt),
                    _formatDurationMs(run.durationMs),
                  ].join(' / '),
                  style: theme.textTheme.bodyMedium,
                ),
                if ((run.error ?? run.message)?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    _displayJobMessage(run.error ?? run.message),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: failed ? AppTheme.danger : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${run.rowsWritten}',
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _NoticeChip extends StatelessWidget {
  const _NoticeChip({
    required this.notice,
  });

  final JobPageNoticeData notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _noticeTone(notice.level);
    final foreground = switch (tone) {
      _StatusTone.healthy => AppTheme.success,
      _StatusTone.warning => AppTheme.secondary,
      _StatusTone.failed => AppTheme.danger,
      _StatusTone.info => theme.colorScheme.primary,
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.chipDecoration(
        radius: 6,
        color: foreground.withValues(alpha: 0.10),
        borderColor: foreground.withValues(alpha: 0.20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined,
              size: 16, color: foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${_displayNoticeText(notice.title)}: ${_displayNoticeText(notice.message)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        _Badge(
          icon: Icons.insights_rounded,
          label: trailing,
          tone: _StatusTone.info,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.accent,
  });

  final String label;
  final String value;
  final String caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(color: accent),
          ),
          const SizedBox(height: 4),
          Text(caption, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.chipDecoration(
        radius: 6,
        color: Colors.white.withValues(alpha: 0.06),
        borderColor: Colors.white.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label $value',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogBlock extends StatelessWidget {
  const _LogBlock({
    required this.title,
    required this.updatedAt,
    required this.path,
    required this.lines,
  });

  final String title;
  final String? updatedAt;
  final String path;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logLineCount = lines.length;
    final latestLine = lines.reversed.firstWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => '',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title · ${_formatTimestamp(updatedAt)}',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Text(
            path.isEmpty ? '未配置日志路径' : path,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            logLineCount == 0
                ? '暂无最近日志'
                : '最近 $logLineCount 行已记录；最新状态：${_displayJobMessage(latestLine)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = switch (tone) {
      _StatusTone.healthy => AppTheme.success.withValues(alpha: 0.14),
      _StatusTone.warning => AppTheme.secondary.withValues(alpha: 0.14),
      _StatusTone.failed => AppTheme.danger.withValues(alpha: 0.14),
      _StatusTone.info => theme.colorScheme.primary.withValues(alpha: 0.14),
    };
    final foreground = switch (tone) {
      _StatusTone.healthy => AppTheme.success,
      _StatusTone.warning => AppTheme.secondary,
      _StatusTone.failed => AppTheme.danger,
      _StatusTone.info => theme.colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.chipDecoration(
        radius: 6,
        color: background,
        borderColor: foreground.withValues(alpha: 0.22),
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
  }
}

enum _StatusTone {
  healthy,
  warning,
  failed,
  info,
}

_StatusTone _startupTaskTone(String state) {
  final normalized = state.trim().toLowerCase();
  if (normalized == 'ready' ||
      normalized == 'running' ||
      normalized == 'containerized') {
    return _StatusTone.healthy;
  }
  if (normalized == 'missing' || normalized == 'disabled') {
    return _StatusTone.failed;
  }
  return _StatusTone.warning;
}

bool _isContainerizedRuntime(String state) {
  return state.trim().toLowerCase() == 'containerized';
}

String _startupTaskMetricLabel(String state) {
  return _isContainerizedRuntime(state) ? '运行托管' : '开机任务';
}

String _startupTaskMetricValue(JobPageSummary summary) {
  if (_isContainerizedRuntime(summary.startupTaskState)) {
    return '容器托管';
  }
  return summary.startupTaskInstalled ? '已安装' : '缺失';
}

String _startupTaskMetricCaption(JobPageSummary summary) {
  if (_isContainerizedRuntime(summary.startupTaskState)) {
    return summary.startupTaskEnabled ? 'Docker Compose' : '未启用';
  }
  return summary.startupTaskEnabled ? '已启用' : '未启用';
}

String _startupTaskStateLabel(String state) {
  final normalized = state.trim().toLowerCase();
  return switch (normalized) {
    'ready' => '计划任务就绪',
    'running' => '计划任务运行中',
    'containerized' => '容器托管',
    'disabled' => '计划任务已禁用',
    'missing' => '计划任务缺失',
    _ => state.isEmpty ? '--' : state,
  };
}

_StatusTone _jobHealthTone(String health) {
  final normalized = health.trim().toLowerCase();
  return switch (normalized) {
    'healthy' => _StatusTone.healthy,
    'failed' => _StatusTone.failed,
    'warning' => _StatusTone.warning,
    _ => _StatusTone.info,
  };
}

_StatusTone _noticeTone(String level) {
  final normalized = level.trim().toLowerCase();
  return switch (normalized) {
    'error' || 'failed' || 'danger' => _StatusTone.failed,
    'warning' || 'warn' => _StatusTone.warning,
    'healthy' || 'success' => _StatusTone.healthy,
    _ => _StatusTone.info,
  };
}

IconData _jobHealthIcon(String health) {
  final normalized = health.trim().toLowerCase();
  return switch (normalized) {
    'healthy' => Icons.check_circle_outline_rounded,
    'failed' => Icons.error_outline_rounded,
    'warning' => Icons.visibility_rounded,
    _ => Icons.refresh_rounded,
  };
}

String _jobHealthLabel(String health) {
  final normalized = health.trim().toLowerCase();
  return switch (normalized) {
    'healthy' => '正常',
    'failed' => '失败',
    'warning' => '待关注',
    'disabled' => '停用',
    _ => health.isEmpty ? '--' : health,
  };
}

_StatusTone _runtimeMetaTone(JobRuntimeMetaData meta) {
  if (meta.staleFallback) {
    return _StatusTone.warning;
  }
  if (meta.forceRefreshApplied) {
    return _StatusTone.healthy;
  }
  if (meta.cacheHit) {
    return _StatusTone.info;
  }
  return _StatusTone.healthy;
}

IconData _runtimeMetaIcon(JobRuntimeMetaData meta) {
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

String _runtimeMetaLabel(JobRuntimeMetaData meta) {
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

_StatusTone _frontendBuildTone(JobFrontendBuildData build) {
  if (build.stale) {
    return _StatusTone.warning;
  }
  if (build.hasData) {
    return _StatusTone.healthy;
  }
  return _StatusTone.info;
}

IconData _frontendBuildIcon(JobFrontendBuildData build) {
  if (build.stale) {
    return Icons.layers_clear_rounded;
  }
  if (build.hasData) {
    return Icons.layers_rounded;
  }
  return Icons.help_outline_rounded;
}

String _frontendBuildLabel(JobFrontendBuildData build) {
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

String _displayJobName(String value) {
  final normalized = value.trim();
  const labels = {
    'auction live': '竞价直播',
    'auction ranks': '竞价榜单',
    'board height': '连板高度',
    'calendar timeline': '财经日历',
    'index kline': '指数 K 线',
    'index quotes': '指数报价',
    'market center': '行情中心',
    'market overview': '盘面总览',
    'news 724': '7x24 资讯',
    'news center': '资讯中心',
    'node plates': '节点板块',
    'plate rotation': '板块轮动',
    'plate stocks': '板块成分',
    'review page': '涨停复盘',
    'yesterday stats': '空头数据',
  };
  return labels[normalized.toLowerCase()] ?? normalized;
}

String _displayServiceName(String value) {
  final normalized = value.trim();
  const labels = {
    'db_server': '数据采集服务',
    'api_server': '接口服务',
    'frontend_web': '前端静态服务',
    'niuniu_kaipan': '桌面客户端',
  };
  return labels[normalized.toLowerCase()] ?? normalized;
}

String _displayServiceWorkDir(JobServiceStatusData service) {
  if (service.workDir.trim().isEmpty) {
    return '服务目录未配置';
  }
  return switch (service.name.trim().toLowerCase()) {
    'db_server' => '数据采集服务目录已配置',
    'api_server' => '接口服务目录已配置',
    'frontend_web' => '前端静态目录已配置',
    _ => '服务目录已配置',
  };
}

String _displayServiceKind(String value) {
  final normalized = value.trim();
  const labels = {
    'db_server': '采集进程',
    'api_server': '接口进程',
    'frontend_web': '静态服务',
    'scheduler': '调度器',
    'worker': '采集进程',
    'http': 'HTTP 探测',
    'static': '静态页面',
    'process': '本地进程',
    'python': 'Python 进程',
    'flutter': 'Flutter 前端',
  };
  return labels[normalized.toLowerCase()] ?? normalized;
}

String _displaySource(String value) {
  final normalized = value.trim();
  const labels = {
    'eastmoney': '东方财富',
    'em': '东方财富',
    'ths': '同花顺',
    'tonghuashun': '同花顺',
    'duanxianxia': '短线侠',
    'jikefupan': '极客复盘',
    'tencent': '腾讯',
    'sina': '新浪',
    'mixed': '综合来源',
    'local': '本地库',
    'internal': '内部任务',
  };
  return labels[normalized.toLowerCase()] ?? normalized;
}

String _displayEndpointKey(String value) {
  final normalized = value.trim();
  const labels = {
    'auction_live': '竞价直播',
    'jjlive': '竞价直播',
    'auction_ranks': '竞价榜单',
    'board_height': '连板高度',
    'calendar_timeline': '财经日历',
    'index_kline': '指数 K 线',
    'index_quotes': '指数报价',
    'market_center': '行情中心',
    'eastmoney_pools': '东方财富股池',
    'market_overview': '盘面总览',
    'news_724': '7x24 资讯',
    'fast_news': '7x24 资讯',
    'news_center': '资讯中心',
    'hot_news_bundle': '资讯中心',
    'node_plates': '节点板块',
    'plate_rotation': '板块轮动',
    'plate_stocks': '板块成分',
    'review_page': '涨停复盘',
    'yesterday_stats': '空头数据',
  };
  return labels[normalized.toLowerCase()] ??
      normalized.replaceAll('_', ' ').replaceAll('-', ' ');
}

String _displayRunStatus(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  return switch (normalized) {
    '' => '--',
    'success' || 'succeeded' || 'finished' || 'ok' => '成功',
    'failed' || 'error' => '失败',
    'queued' => '排队',
    'running' => '运行中',
    'pending' => '等待',
    'skipped' => '跳过',
    'cancelled' || 'canceled' => '取消',
    'timeout' => '超时',
    _ => value!.trim(),
  };
}

String _displayJobMessage(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return '--';
  }
  final lower = normalized.toLowerCase();
  if (RegExp(r'\b(get|post|put|delete|options)\s+/').hasMatch(lower) ||
      lower.contains('http/1.1')) {
    return normalized.contains('/assets/') ? '静态资源请求正常' : '服务请求正常';
  }
  return switch (normalized.toLowerCase()) {
    'job already queued or running' => '任务已在排队或运行中',
    'job already running' => '任务正在运行中',
    'job disabled' => '任务已停用',
    'trigger not allowed' => '当前不允许手动触发',
    'service not running' => '服务未运行',
    'request timeout' => '请求超时',
    'network timeout' => '网络请求超时',
    'status.ps1 failed' => '状态脚本执行失败',
    _ => normalized,
  };
}

String _displayNoticeText(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return '--';
  }
  final lower = normalized.toLowerCase();
  if (lower == 'jobs need attention') {
    return '采集任务待关注';
  }
  final jobAttentionPattern =
      RegExp(r'^(\d+) warning jobs,\s*(\d+) queued or running jobs\.?$');
  final jobAttentionMatch = jobAttentionPattern.firstMatch(lower);
  if (jobAttentionMatch != null) {
    return '${jobAttentionMatch.group(1)} 个任务待关注，${jobAttentionMatch.group(2)} 个任务排队或运行中';
  }
  if (lower == 'frontend bundle stale') {
    return '前端包需要重建';
  }
  if (lower == 'service not ready') {
    return '服务未就绪';
  }
  return normalized;
}

String _displayBuildReason(String value) {
  final normalized = value.trim();
  final lower = normalized.toLowerCase();
  const labels = {
    'frontend bundle stale': '前端包落后于服务端记录，请重新构建。',
    'source updated after bundle': '源码时间晚于当前前端包，需要重新构建。',
    'bundle missing': '未读取到前端包构建信息。',
    'build metadata missing': '未读取到构建元数据。',
  };
  if (labels.containsKey(lower)) {
    return labels[lower]!;
  }
  if (lower.contains('frontend sources') ||
      (lower.contains('source') && lower.contains('newer'))) {
    return '前端源码晚于构建包，需要重新构建。';
  }
  return normalized
      .replaceAll('frontend', '前端')
      .replaceAll('bundle', '构建包')
      .replaceAll('source', '源码')
      .replaceAll('stale', '滞后')
      .replaceAll('missing', '缺失');
}

_StatusTone _serviceReadinessTone(JobServiceStatusData service) {
  if (!service.running) {
    return _StatusTone.failed;
  }
  if (service.ready) {
    return _StatusTone.healthy;
  }
  return _StatusTone.warning;
}

IconData _serviceReadinessIcon(JobServiceStatusData service) {
  if (!service.running) {
    return Icons.power_off_rounded;
  }
  if (service.ready) {
    return Icons.health_and_safety_outlined;
  }
  return Icons.wifi_tethering_error_rounded;
}

String _serviceReadinessLabel(JobServiceStatusData service) {
  if (!service.running) {
    return '未运行';
  }
  if (service.ready && service.probeStatusCode != null) {
    return '就绪 ${service.probeStatusCode}';
  }
  if (service.ready) {
    return '就绪';
  }
  if (service.probeStatusCode != null) {
    return '探测 ${service.probeStatusCode}';
  }
  return '探测失败';
}

String _serviceProbeValue(JobServiceStatusData service) {
  final kind = service.probeKind ?? service.kind;
  if (service.probeStatusCode != null) {
    return '${_displayServiceKind(kind)} ${service.probeStatusCode}';
  }
  return _displayServiceKind(kind);
}

bool _isFailureStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'failed' || normalized == 'error';
}

String _scheduleLabel(JobPageItem job) {
  if (job.scheduleMode == 'once') {
    return '单次';
  }
  if (job.scheduleMode == 'manual') {
    return '手动';
  }
  if (job.scheduleMode == 'disabled') {
    return '停用';
  }
  if (job.scheduleMode == 'cron') {
    return '定时';
  }
  if (job.intervalSeconds > 0) {
    return '每 ${job.intervalSeconds}s';
  }
  return job.scheduleMode.isEmpty ? '--' : job.scheduleMode;
}

String _windowLabel(String? start, String? end) {
  if ((start == null || start.isEmpty) && (end == null || end.isEmpty)) {
    return '--';
  }
  return '${start ?? '--'} - ${end ?? '--'}';
}

String _formatDurationMs(int value) {
  if (value <= 0) {
    return '--';
  }
  if (value < 1000) {
    return '${value}ms';
  }
  final seconds = value / 1000;
  if (seconds < 60) {
    return '${seconds.toStringAsFixed(seconds >= 10 ? 0 : 1)}s';
  }
  final minutes = seconds / 60;
  return '${minutes.toStringAsFixed(minutes >= 10 ? 0 : 1)}m';
}

String _formatTimestamp(String? value) {
  if (value == null || value.isEmpty) {
    return '--';
  }
  return value.replaceFirst('T', ' ').split('.').first;
}
