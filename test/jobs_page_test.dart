import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/theme/app_theme.dart';
import 'package:niuniu_kaipan/features/jobs/application/jobs_provider.dart';
import 'package:niuniu_kaipan/features/jobs/data/jobs_repository.dart';
import 'package:niuniu_kaipan/features/jobs/presentation/jobs_page.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/application/shell_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('jobs page renders live ops snapshot sections', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 1400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => _shellOverview),
          jobsProvider.overrideWith((ref) async => _jobsSnapshot),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const JobsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('NiuniuKaiPan_StartAll'), findsOneWidget);
    expect(find.text('缓存命中'), findsOneWidget);
    expect(find.text('前端包已同步'), findsOneWidget);
    expect(find.text('接口已连接'), findsOneWidget);
    expect(find.text('排队运行'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    final listView = find.byType(ListView).first;
    await tester.drag(listView, const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('数据采集服务'), findsOneWidget);
    expect(find.text('接口服务'), findsOneWidget);
    expect(find.text('前端静态服务'), findsOneWidget);
    expect(find.text('就绪 200'), findsWidgets);
    expect(
      find.textContaining('https://api.example.invalid/api/v1/health'),
      findsOneWidget,
    );

    await tester.drag(listView, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.drag(listView, const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('竞价直播'), findsOneWidget);
    expect(find.text('7x24 资讯'), findsOneWidget);
    expect(find.text('手动触发'), findsWidgets);
    expect(find.text('任务已在排队或运行中'), findsOneWidget);

    await tester.drag(listView, const Offset(0, -1400));
    await tester.pumpAndSettle();

    expect(find.text('最近运行'), findsOneWidget);
    expect(find.text('失败记录'), findsOneWidget);
    expect(find.textContaining('#302'), findsOneWidget);
    expect(find.textContaining('网络请求超时'), findsWidgets);
  });

  testWidgets(
    'jobs page shows runtime warning and keeps job list visible',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1800, 1400);
      addTearDown(tester.view.reset);

      const runtimeError = '运行时快照刷新失败，当前展示的是上一次缓存结果。';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shellOverviewProvider.overrideWith((ref) async => _shellOverview),
            jobsProvider.overrideWith(
              (ref) async => _jobsSnapshotWithRuntimeError(runtimeError),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const JobsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text(runtimeError), findsOneWidget);

      final listView = find.byType(ListView).first;
      await tester.drag(listView, const Offset(0, -1200));
      await tester.pumpAndSettle();
      await tester.drag(listView, const Offset(0, -1200));
      await tester.pumpAndSettle();

      expect(find.text('竞价直播'), findsOneWidget);
      expect(find.text('7x24 资讯'), findsOneWidget);
    },
  );

  testWidgets('jobs page labels production containerized runtime clearly', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 1400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shellOverviewProvider.overrideWith((ref) async => _shellOverview),
          jobsProvider.overrideWith(
            (ref) async => _containerizedJobsSnapshotWithExternalFrontend,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const JobsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('容器托管'), findsWidgets);
    expect(find.text('运行托管'), findsWidgets);
    expect(find.textContaining('Docker Compose'), findsWidgets);
    expect(find.text('外部前端在线'), findsOneWidget);
    expect(find.textContaining('Windows 计划任务'), findsNothing);
    expect(find.text('计划任务缺失'), findsNothing);
    expect(find.text('缺失'), findsNothing);
  });
}

const _shellOverview = OverviewSnapshot(
  tradeDate: '2026-04-22',
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

const _jobsSnapshot = JobPageSnapshot(
  generatedAt: '2026-04-22T00:36:29',
  runtimeMeta: JobRuntimeMetaData(
    cacheHit: true,
    cacheAgeMs: 240,
    cacheTtlMs: 3000,
    refreshedAt: '2026-04-22T00:36:29',
    forceRefreshApplied: false,
    staleFallback: false,
  ),
  summary: JobPageSummary(
    totalJobs: 16,
    enabledJobs: 16,
    healthyJobs: 16,
    warningJobs: 0,
    failedJobs: 0,
    queuedJobs: 1,
    runningServices: 3,
    readyServices: 3,
    totalServices: 3,
    startupTaskInstalled: true,
    startupTaskEnabled: true,
    startupTaskState: 'Ready',
  ),
  startupTask: JobStartupTaskData(
    taskName: 'NiuniuKaiPan_StartAll',
    exists: true,
    enabled: true,
    state: 'Ready',
    author: null,
  ),
  frontendBuild: JobFrontendBuildData(
    builtAt: '2026-04-22T00:35:00',
    bundleUpdatedAt: '2026-04-22T00:35:02',
    sourceUpdatedAt: '2026-04-22T00:34:55',
    apiBaseUrl: 'https://api.example.invalid',
    stale: false,
    reasons: [],
  ),
  services: [
    JobServiceStatusData(
      name: 'db_server',
      kind: 'scheduler',
      running: true,
      ready: true,
      pids: [10404, 14264],
      port: null,
      workDir: 'E:/FlutterProject/niuniufupan/niuniukaipan_new/db_server',
      stdoutPath: 'db_server/var/scheduler_loop.log',
      stderrPath: 'db_server/var/scheduler_loop.err.log',
      stdoutTail: ['[scheduler] news_724 success run_id=301'],
      stderrTail: [],
      stdoutUpdatedAt: '2026-04-22T00:36:30',
      stderrUpdatedAt: '2026-04-22T00:35:54',
      requiredPath: 'db_server/.venv/Scripts/python.exe',
      requiredExists: true,
      probeKind: 'process',
      probeTarget: null,
      probeStatusCode: null,
      probeError: null,
      probeCheckedAt: '2026-04-22T00:36:30',
      probeLatencyMs: 0,
    ),
    JobServiceStatusData(
      name: 'api_server',
      kind: 'http',
      running: true,
      ready: true,
      pids: [1396, 17164],
      port: 18081,
      workDir: 'E:/FlutterProject/niuniufupan/niuniukaipan_new/api_server',
      stdoutPath: 'api_server/var/uvicorn.log',
      stderrPath: 'api_server/var/uvicorn.err.log',
      stdoutTail: [],
      stderrTail: ['Uvicorn running on https://api.example.invalid'],
      stdoutUpdatedAt: '2026-04-22T00:36:00',
      stderrUpdatedAt: '2026-04-22T00:36:02',
      requiredPath: 'api_server/.venv/Scripts/python.exe',
      requiredExists: true,
      probeKind: 'http',
      probeTarget: 'https://api.example.invalid/api/v1/health',
      probeStatusCode: 200,
      probeError: null,
      probeCheckedAt: '2026-04-22T00:36:02',
      probeLatencyMs: 812,
    ),
    JobServiceStatusData(
      name: 'frontend_web',
      kind: 'static',
      running: true,
      ready: true,
      pids: [12372],
      port: 18103,
      workDir:
          'E:/FlutterProject/niuniufupan/niuniukaipan_new/niuniu_kaipan/build/web',
      stdoutPath: 'niuniu_kaipan/var/frontend_web.log',
      stderrPath: 'niuniu_kaipan/var/frontend_web.err.log',
      stdoutTail: [],
      stderrTail: [],
      stdoutUpdatedAt: '2026-04-22T00:36:07',
      stderrUpdatedAt: '2026-04-22T00:36:07',
      requiredPath: 'niuniu_kaipan/build/web/index.html',
      requiredExists: true,
      probeKind: 'http',
      probeTarget: 'https://frontend.example.invalid/',
      probeStatusCode: 200,
      probeError: null,
      probeCheckedAt: '2026-04-22T00:36:07',
      probeLatencyMs: 533,
    ),
  ],
  jobs: [
    JobPageItem(
      jobCode: 'auction_live',
      name: 'auction live',
      source: 'duanxianxia',
      endpointKey: 'jjlive',
      enabled: true,
      scheduleMode: 'interval',
      intervalSeconds: 5,
      maxRunsPerDay: 200,
      windowStart: '09:15:00',
      windowEnd: '09:25:30',
      health: 'healthy',
      lastStatus: 'success',
      lastStartedAt: '2026-04-21T15:32:42',
      lastFinishedAt: '2026-04-21T15:32:44',
      lastDurationMs: 2000,
      lastRowsWritten: 1,
      lastErrorMessage: null,
      triggerAllowed: true,
      triggerBlockReason: null,
    ),
    JobPageItem(
      jobCode: 'news_724',
      name: 'news 724',
      source: 'eastmoney',
      endpointKey: 'fast_news',
      enabled: true,
      scheduleMode: 'interval',
      intervalSeconds: 10,
      maxRunsPerDay: 8640,
      windowStart: '00:00:00',
      windowEnd: '23:59:59',
      health: 'healthy',
      lastStatus: 'success',
      lastStartedAt: '2026-04-21T16:36:21',
      lastFinishedAt: '2026-04-21T16:36:25',
      lastDurationMs: 4000,
      lastRowsWritten: 50,
      lastErrorMessage: null,
      triggerAllowed: false,
      triggerBlockReason: 'job already queued or running',
    ),
  ],
  recentRuns: [
    JobPageRunItemData(
      runId: 302,
      jobCode: 'news_724',
      name: 'news 724',
      tradeDate: '2026-04-21',
      status: 'success',
      startedAt: '2026-04-21T16:36:21',
      finishedAt: '2026-04-21T16:36:25',
      durationMs: 4000,
      rowsWritten: 50,
      message: 'success / 50 rows',
      error: null,
    ),
    JobPageRunItemData(
      runId: 301,
      jobCode: 'auction_live',
      name: 'auction live',
      tradeDate: '2026-04-21',
      status: 'failed',
      startedAt: '2026-04-21T15:32:42',
      finishedAt: '2026-04-21T15:32:44',
      durationMs: 2000,
      rowsWritten: 0,
      message: 'network timeout',
      error: 'network timeout',
    ),
  ],
  failures: [
    JobPageRunItemData(
      runId: 301,
      jobCode: 'auction_live',
      name: 'auction live',
      tradeDate: '2026-04-21',
      status: 'failed',
      startedAt: '2026-04-21T15:32:42',
      finishedAt: '2026-04-21T15:32:44',
      durationMs: 2000,
      rowsWritten: 0,
      message: 'network timeout',
      error: 'network timeout',
    ),
  ],
  notices: [
    JobPageNoticeData(
      level: 'warning',
      title: 'failed jobs',
      message: '1 jobs failed recently.',
      source: 'db_server',
    ),
  ],
  runtimeError: null,
);

JobPageSnapshot _jobsSnapshotWithRuntimeError(String runtimeError) {
  return JobPageSnapshot(
    generatedAt: _jobsSnapshot.generatedAt,
    runtimeMeta: _jobsSnapshot.runtimeMeta,
    summary: _jobsSnapshot.summary,
    startupTask: _jobsSnapshot.startupTask,
    frontendBuild: _jobsSnapshot.frontendBuild,
    services: _jobsSnapshot.services,
    jobs: _jobsSnapshot.jobs,
    recentRuns: _jobsSnapshot.recentRuns,
    failures: _jobsSnapshot.failures,
    notices: _jobsSnapshot.notices,
    runtimeError: runtimeError,
  );
}

final _containerizedJobsSnapshot = JobPageSnapshot(
  generatedAt: _jobsSnapshot.generatedAt,
  runtimeMeta: _jobsSnapshot.runtimeMeta,
  summary: JobPageSummary(
    totalJobs: 16,
    enabledJobs: 16,
    healthyJobs: 16,
    warningJobs: 0,
    failedJobs: 0,
    queuedJobs: 0,
    runningServices: 3,
    readyServices: 3,
    totalServices: 3,
    startupTaskInstalled: true,
    startupTaskEnabled: true,
    startupTaskState: 'containerized',
  ),
  startupTask: JobStartupTaskData(
    taskName: 'Docker Compose',
    exists: true,
    enabled: true,
    state: 'containerized',
    author: 'production',
  ),
  frontendBuild: _jobsSnapshot.frontendBuild,
  services: _jobsSnapshot.services,
  jobs: _jobsSnapshot.jobs,
  recentRuns: _jobsSnapshot.recentRuns,
  failures: [],
  notices: [],
  runtimeError: null,
);

final _externallyServedFrontendBuild = JobFrontendBuildData(
  builtAt: null,
  bundleUpdatedAt: null,
  sourceUpdatedAt: null,
  apiBaseUrl: null,
  stale: false,
  reasons: const [],
  probeTarget: 'http://frontend/',
  externallyServed: true,
);

final _containerizedJobsSnapshotWithExternalFrontend = JobPageSnapshot(
  generatedAt: _containerizedJobsSnapshot.generatedAt,
  runtimeMeta: _containerizedJobsSnapshot.runtimeMeta,
  summary: _containerizedJobsSnapshot.summary,
  startupTask: _containerizedJobsSnapshot.startupTask,
  frontendBuild: _externallyServedFrontendBuild,
  services: _containerizedJobsSnapshot.services,
  jobs: _containerizedJobsSnapshot.jobs,
  recentRuns: _containerizedJobsSnapshot.recentRuns,
  failures: _containerizedJobsSnapshot.failures,
  notices: _containerizedJobsSnapshot.notices,
  runtimeError: _containerizedJobsSnapshot.runtimeError,
);
