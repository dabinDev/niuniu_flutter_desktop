import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class JobPageSummary {
  const JobPageSummary({
    required this.totalJobs,
    required this.enabledJobs,
    required this.healthyJobs,
    required this.warningJobs,
    required this.failedJobs,
    required this.queuedJobs,
    required this.runningServices,
    required this.readyServices,
    required this.totalServices,
    required this.startupTaskInstalled,
    required this.startupTaskEnabled,
    required this.startupTaskState,
  });

  final int totalJobs;
  final int enabledJobs;
  final int healthyJobs;
  final int warningJobs;
  final int failedJobs;
  final int queuedJobs;
  final int runningServices;
  final int readyServices;
  final int totalServices;
  final bool startupTaskInstalled;
  final bool startupTaskEnabled;
  final String startupTaskState;

  factory JobPageSummary.fromJson(Map<String, dynamic> json) {
    return JobPageSummary(
      totalJobs: _intOf(json['total_jobs']),
      enabledJobs: _intOf(json['enabled_jobs']),
      healthyJobs: _intOf(json['healthy_jobs']),
      warningJobs: _intOf(json['warning_jobs']),
      failedJobs: _intOf(json['failed_jobs']),
      queuedJobs: _intOf(json['queued_jobs']),
      runningServices: _intOf(json['running_services']),
      readyServices: _intOf(json['ready_services']),
      totalServices: _intOf(json['total_services']),
      startupTaskInstalled: _boolOf(json['startup_task_installed']),
      startupTaskEnabled: _boolOf(json['startup_task_enabled']),
      startupTaskState: _stringOf(json['startup_task_state']),
    );
  }
}

class JobStartupTaskData {
  const JobStartupTaskData({
    required this.taskName,
    required this.exists,
    required this.enabled,
    required this.state,
    required this.author,
  });

  final String taskName;
  final bool exists;
  final bool enabled;
  final String state;
  final String? author;

  factory JobStartupTaskData.fromJson(Map<String, dynamic> json) {
    return JobStartupTaskData(
      taskName: _stringOf(json['task_name']),
      exists: _boolOf(json['exists']),
      enabled: _boolOf(json['enabled']),
      state: _stringOf(json['state']),
      author: _nullableStringOf(json['author']),
    );
  }
}

class JobServiceStatusData {
  const JobServiceStatusData({
    required this.name,
    required this.kind,
    required this.running,
    required this.ready,
    required this.pids,
    required this.port,
    required this.workDir,
    required this.stdoutPath,
    required this.stderrPath,
    required this.stdoutTail,
    required this.stderrTail,
    required this.stdoutUpdatedAt,
    required this.stderrUpdatedAt,
    required this.requiredPath,
    required this.requiredExists,
    required this.probeKind,
    required this.probeTarget,
    required this.probeStatusCode,
    required this.probeError,
    required this.probeCheckedAt,
    required this.probeLatencyMs,
  });

  final String name;
  final String kind;
  final bool running;
  final bool ready;
  final List<int> pids;
  final int? port;
  final String workDir;
  final String stdoutPath;
  final String stderrPath;
  final List<String> stdoutTail;
  final List<String> stderrTail;
  final String? stdoutUpdatedAt;
  final String? stderrUpdatedAt;
  final String requiredPath;
  final bool requiredExists;
  final String? probeKind;
  final String? probeTarget;
  final int? probeStatusCode;
  final String? probeError;
  final String? probeCheckedAt;
  final int probeLatencyMs;

  factory JobServiceStatusData.fromJson(Map<String, dynamic> json) {
    return JobServiceStatusData(
      name: _stringOf(json['name']),
      kind: _stringOf(json['kind']),
      running: _boolOf(json['running']),
      ready: json.containsKey('ready')
          ? _boolOf(json['ready'])
          : _boolOf(json['running']),
      pids: _intListOf(json['pids']),
      port: _nullableIntOf(json['port']),
      workDir: _stringOf(json['work_dir']),
      stdoutPath: _stringOf(json['stdout_path']),
      stderrPath: _stringOf(json['stderr_path']),
      stdoutTail: _stringListOf(json['stdout_tail']),
      stderrTail: _stringListOf(json['stderr_tail']),
      stdoutUpdatedAt: _nullableStringOf(json['stdout_updated_at']),
      stderrUpdatedAt: _nullableStringOf(json['stderr_updated_at']),
      requiredPath: _stringOf(json['required_path']),
      requiredExists: _boolOf(json['required_exists']),
      probeKind: _nullableStringOf(json['probe_kind']),
      probeTarget: _nullableStringOf(json['probe_target']),
      probeStatusCode: _nullableIntOf(json['probe_status_code']),
      probeError: _nullableStringOf(json['probe_error']),
      probeCheckedAt: _nullableStringOf(json['probe_checked_at']),
      probeLatencyMs: _intOf(json['probe_latency_ms']),
    );
  }
}

class JobRuntimeMetaData {
  const JobRuntimeMetaData({
    required this.cacheHit,
    required this.cacheAgeMs,
    required this.cacheTtlMs,
    required this.refreshedAt,
    required this.forceRefreshApplied,
    required this.staleFallback,
  });

  final bool cacheHit;
  final int cacheAgeMs;
  final int cacheTtlMs;
  final String? refreshedAt;
  final bool forceRefreshApplied;
  final bool staleFallback;

  factory JobRuntimeMetaData.fromJson(Map<String, dynamic> json) {
    return JobRuntimeMetaData(
      cacheHit: _boolOf(json['cache_hit']),
      cacheAgeMs: _intOf(json['cache_age_ms']),
      cacheTtlMs: _intOf(json['cache_ttl_ms']),
      refreshedAt: _nullableStringOf(json['refreshed_at']),
      forceRefreshApplied: _boolOf(json['force_refresh_applied']),
      staleFallback: _boolOf(json['stale_fallback']),
    );
  }
}

class JobFrontendBuildData {
  const JobFrontendBuildData({
    required this.builtAt,
    required this.bundleUpdatedAt,
    required this.sourceUpdatedAt,
    required this.apiBaseUrl,
    required this.stale,
    required this.reasons,
    this.probeTarget,
    this.externallyServed = false,
  });

  final String? builtAt;
  final String? bundleUpdatedAt;
  final String? sourceUpdatedAt;
  final String? apiBaseUrl;
  final bool stale;
  final List<String> reasons;
  final String? probeTarget;
  final bool externallyServed;

  bool get hasData =>
      externallyServed ||
      builtAt != null ||
      bundleUpdatedAt != null ||
      sourceUpdatedAt != null ||
      apiBaseUrl != null ||
      probeTarget != null ||
      reasons.isNotEmpty;

  String? get effectiveBuiltAt => builtAt ?? bundleUpdatedAt;

  factory JobFrontendBuildData.fromJson(Map<String, dynamic> json) {
    return JobFrontendBuildData(
      builtAt: _nullableStringOf(json['built_at']),
      bundleUpdatedAt: _nullableStringOf(json['bundle_updated_at']),
      sourceUpdatedAt: _nullableStringOf(json['source_updated_at']),
      apiBaseUrl: _nullableStringOf(json['api_base_url']),
      stale: _boolOf(json['stale']),
      reasons: _stringListOf(json['reasons']),
      probeTarget: _nullableStringOf(json['probe_target']),
      externallyServed: _boolOf(json['externally_served']),
    );
  }
}

class JobPageItem {
  const JobPageItem({
    required this.jobCode,
    required this.name,
    required this.source,
    required this.endpointKey,
    required this.enabled,
    required this.scheduleMode,
    required this.intervalSeconds,
    required this.maxRunsPerDay,
    required this.windowStart,
    required this.windowEnd,
    required this.health,
    required this.lastStatus,
    required this.lastStartedAt,
    required this.lastFinishedAt,
    required this.lastDurationMs,
    required this.lastRowsWritten,
    required this.lastErrorMessage,
    required this.triggerAllowed,
    required this.triggerBlockReason,
  });

  final String jobCode;
  final String name;
  final String source;
  final String endpointKey;
  final bool enabled;
  final String scheduleMode;
  final int intervalSeconds;
  final int maxRunsPerDay;
  final String? windowStart;
  final String? windowEnd;
  final String health;
  final String? lastStatus;
  final String? lastStartedAt;
  final String? lastFinishedAt;
  final int lastDurationMs;
  final int lastRowsWritten;
  final String? lastErrorMessage;
  final bool triggerAllowed;
  final String? triggerBlockReason;

  factory JobPageItem.fromJson(Map<String, dynamic> json) {
    return JobPageItem(
      jobCode: _stringOf(json['job_code']),
      name: _stringOf(json['name']),
      source: _stringOf(json['source']),
      endpointKey: _stringOf(json['endpoint_key']),
      enabled: _boolOf(json['enabled']),
      scheduleMode: _stringOf(json['schedule_mode']),
      intervalSeconds: _intOf(json['interval_seconds']),
      maxRunsPerDay: _intOf(json['max_runs_per_day']),
      windowStart: _nullableStringOf(json['window_start']),
      windowEnd: _nullableStringOf(json['window_end']),
      health: _stringOf(json['health']),
      lastStatus: _nullableStringOf(json['last_status']),
      lastStartedAt: _nullableStringOf(json['last_started_at']),
      lastFinishedAt: _nullableStringOf(json['last_finished_at']),
      lastDurationMs: _intOf(json['last_duration_ms']),
      lastRowsWritten: _intOf(json['last_rows_written']),
      lastErrorMessage: _nullableStringOf(json['last_error_message']),
      triggerAllowed: _boolOf(json['trigger_allowed']),
      triggerBlockReason: _nullableStringOf(json['trigger_block_reason']),
    );
  }
}

class JobPageRunItemData {
  const JobPageRunItemData({
    required this.runId,
    required this.jobCode,
    required this.name,
    required this.tradeDate,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.durationMs,
    required this.rowsWritten,
    required this.message,
    required this.error,
  });

  final int runId;
  final String jobCode;
  final String name;
  final String? tradeDate;
  final String status;
  final String? startedAt;
  final String? finishedAt;
  final int durationMs;
  final int rowsWritten;
  final String? message;
  final String? error;

  factory JobPageRunItemData.fromJson(Map<String, dynamic> json) {
    return JobPageRunItemData(
      runId: _intOf(json['run_id']),
      jobCode: _stringOf(json['job_code']),
      name: _stringOf(json['name']),
      tradeDate: _nullableStringOf(json['trade_date']),
      status: _stringOf(json['status']),
      startedAt: _nullableStringOf(json['started_at']),
      finishedAt: _nullableStringOf(json['finished_at']),
      durationMs: _intOf(json['duration_ms']),
      rowsWritten: _intOf(json['rows_written']),
      message: _nullableStringOf(json['message']),
      error: _nullableStringOf(json['error']),
    );
  }
}

class JobPageNoticeData {
  const JobPageNoticeData({
    required this.level,
    required this.title,
    required this.message,
    required this.source,
  });

  final String level;
  final String title;
  final String message;
  final String source;

  factory JobPageNoticeData.fromJson(Map<String, dynamic> json) {
    return JobPageNoticeData(
      level: _stringOf(json['level'], 'info'),
      title: _stringOf(json['title']),
      message: _stringOf(json['message']),
      source: _stringOf(json['source']),
    );
  }
}

class JobTriggerResultData {
  const JobTriggerResultData({
    required this.queuedRunId,
    required this.status,
  });

  final int queuedRunId;
  final String status;

  factory JobTriggerResultData.fromJson(Map<String, dynamic> json) {
    return JobTriggerResultData(
      queuedRunId: _intOf(json['queued_run_id']),
      status: _stringOf(json['status']),
    );
  }
}

class JobPageSnapshot {
  const JobPageSnapshot({
    required this.generatedAt,
    required this.runtimeMeta,
    required this.summary,
    required this.startupTask,
    required this.frontendBuild,
    required this.services,
    required this.jobs,
    required this.recentRuns,
    required this.failures,
    required this.notices,
    required this.runtimeError,
  });

  final String? generatedAt;
  final JobRuntimeMetaData runtimeMeta;
  final JobPageSummary summary;
  final JobStartupTaskData startupTask;
  final JobFrontendBuildData frontendBuild;
  final List<JobServiceStatusData> services;
  final List<JobPageItem> jobs;
  final List<JobPageRunItemData> recentRuns;
  final List<JobPageRunItemData> failures;
  final List<JobPageNoticeData> notices;
  final String? runtimeError;

  factory JobPageSnapshot.fromJson(Map<String, dynamic> json) {
    return JobPageSnapshot(
      generatedAt: _nullableStringOf(json['generated_at']),
      runtimeMeta: JobRuntimeMetaData.fromJson(
        json['runtime_meta'] as Map<String, dynamic>? ?? const {},
      ),
      summary: JobPageSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      startupTask: JobStartupTaskData.fromJson(
        json['startup_task'] as Map<String, dynamic>? ?? const {},
      ),
      frontendBuild: JobFrontendBuildData.fromJson(
        json['frontend_build'] as Map<String, dynamic>? ?? const {},
      ),
      services: (json['services'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(JobServiceStatusData.fromJson)
          .toList(growable: false),
      jobs: (json['jobs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(JobPageItem.fromJson)
          .toList(growable: false),
      recentRuns: (json['recent_runs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(JobPageRunItemData.fromJson)
          .toList(growable: false),
      failures: (json['failures'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(JobPageRunItemData.fromJson)
          .toList(growable: false),
      notices: (json['notices'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(JobPageNoticeData.fromJson)
          .toList(growable: false),
      runtimeError: _nullableStringOf(json['runtime_error']),
    );
  }
}

class JobsRepository {
  const JobsRepository(this._client);

  final ApiClient _client;

  Future<JobPageSnapshot> fetchPage({
    bool forceRefresh = false,
  }) async {
    final query = forceRefresh ? '?force_refresh=true' : '';
    DioException? lastError;

    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        final data = await _client.getMap('/internal/jobs/page$query');
        return JobPageSnapshot.fromJson(data);
      } on DioException catch (error) {
        lastError = error;
        final retryable = error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError;
        if (!retryable || attempt == 1) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }

    throw lastError ??
        DioException(
          requestOptions: RequestOptions(path: '/internal/jobs/page$query'),
          message: 'Jobs request failed without Dio error details.',
        );
  }

  Future<JobTriggerResultData> triggerJob(String jobCode) async {
    final encodedJobCode = Uri.encodeComponent(jobCode);
    final data =
        await _client.postMap('/internal/jobs/$encodedJobCode/trigger');
    return JobTriggerResultData.fromJson(data);
  }
}

int _intOf(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableIntOf(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

bool _boolOf(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String _stringOf(Object? value, [String fallback = '--']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableStringOf(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

List<String> _stringListOf(Object? value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<int> _intListOf(Object? value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => _nullableIntOf(item))
      .whereType<int>()
      .toList(growable: false);
}
