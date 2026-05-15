import '../../../core/network/api_client.dart';
import '../../../shared/data/market_api_repository.dart';

class OverviewNoticeData {
  const OverviewNoticeData({
    required this.level,
    required this.title,
    required this.message,
  });

  final String level;
  final String title;
  final String message;

  factory OverviewNoticeData.fromJson(Map<String, dynamic> json) {
    return OverviewNoticeData(
      level: json['level'] as String? ?? 'info',
      title: json['title'] as String? ?? '--',
      message: json['message'] as String? ?? '--',
    );
  }
}

class OverviewIndexData {
  const OverviewIndexData({
    required this.code,
    required this.name,
    required this.shortName,
    this.value,
    this.displayValue,
    this.market,
  });

  final String code;
  final String name;
  final String shortName;
  final double? value;
  final String? displayValue;
  final String? market;

  factory OverviewIndexData.fromJson(Map<String, dynamic> json) {
    final value = (json['value'] as num?)?.toDouble();
    return OverviewIndexData(
      code: json['code'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      shortName: json['short_name'] as String? ?? '--',
      value: value,
      displayValue: json['display_value']?.toString() ?? _formatDouble(value),
      market: json['market']?.toString(),
    );
  }
}

class OverviewAmountSummaryData {
  const OverviewAmountSummaryData({
    this.totalAmountYi,
    this.predictedAmountYi,
    this.lastAmountYi,
    this.deltaVsLastYi,
    this.completionRatio,
  });

  final double? totalAmountYi;
  final double? predictedAmountYi;
  final double? lastAmountYi;
  final double? deltaVsLastYi;
  final double? completionRatio;

  factory OverviewAmountSummaryData.fromJson(Map<String, dynamic> json) {
    return OverviewAmountSummaryData(
      totalAmountYi: (json['total_amount_yi'] as num?)?.toDouble(),
      predictedAmountYi: (json['predicted_amount_yi'] as num?)?.toDouble(),
      lastAmountYi: (json['last_amount_yi'] as num?)?.toDouble(),
      deltaVsLastYi: (json['delta_vs_last_yi'] as num?)?.toDouble(),
      completionRatio: (json['completion_ratio'] as num?)?.toDouble(),
    );
  }
}

class OverviewBreadthSummaryData {
  const OverviewBreadthSummaryData({
    this.upCount,
    this.flatCount,
    this.downCount,
    this.leadingSide,
    this.upRatio,
    this.downRatio,
  });

  final int? upCount;
  final int? flatCount;
  final int? downCount;
  final String? leadingSide;
  final double? upRatio;
  final double? downRatio;

  factory OverviewBreadthSummaryData.fromJson(Map<String, dynamic> json) {
    return OverviewBreadthSummaryData(
      upCount: (json['up_count'] as num?)?.toInt(),
      flatCount: (json['flat_count'] as num?)?.toInt(),
      downCount: (json['down_count'] as num?)?.toInt(),
      leadingSide: json['leading_side']?.toString(),
      upRatio: (json['up_ratio'] as num?)?.toDouble(),
      downRatio: (json['down_ratio'] as num?)?.toDouble(),
    );
  }
}

class OverviewSentimentMetricData {
  const OverviewSentimentMetricData({
    required this.key,
    required this.label,
    required this.today,
    required this.yesterday,
    required this.delta,
  });

  final String key;
  final String label;
  final int today;
  final int yesterday;
  final int delta;

  factory OverviewSentimentMetricData.fromJson(Map<String, dynamic> json) {
    return OverviewSentimentMetricData(
      key: json['key'] as String? ?? '--',
      label: json['label'] as String? ?? '--',
      today: (json['today'] as num?)?.toInt() ?? 0,
      yesterday: (json['yesterday'] as num?)?.toInt() ?? 0,
      delta: (json['delta'] as num?)?.toInt() ?? 0,
    );
  }
}

class OverviewSentimentSummaryData {
  const OverviewSentimentSummaryData({
    required this.stage,
    required this.bias,
    required this.score,
    required this.metrics,
  });

  final String stage;
  final String bias;
  final int score;
  final List<OverviewSentimentMetricData> metrics;

  factory OverviewSentimentSummaryData.fromJson(Map<String, dynamic> json) {
    return OverviewSentimentSummaryData(
      stage: json['stage'] as String? ?? '震荡',
      bias: json['bias'] as String? ?? 'neutral',
      score: (json['score'] as num?)?.toInt() ?? 50,
      metrics: (json['metrics'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OverviewSentimentMetricData.fromJson)
          .toList(growable: false),
    );
  }
}

class OverviewRuntimeMetaData {
  const OverviewRuntimeMetaData({
    this.cacheHit = false,
    this.cacheAgeMs = 0,
    this.cacheTtlMs = 0,
    this.refreshedAt,
    this.forceRefreshApplied = false,
    this.staleFallback = false,
  });

  final bool cacheHit;
  final int cacheAgeMs;
  final int cacheTtlMs;
  final String? refreshedAt;
  final bool forceRefreshApplied;
  final bool staleFallback;

  bool get hasData =>
      cacheTtlMs > 0 ||
      cacheAgeMs > 0 ||
      cacheHit ||
      forceRefreshApplied ||
      staleFallback ||
      (refreshedAt?.isNotEmpty ?? false);

  factory OverviewRuntimeMetaData.fromJson(Map<String, dynamic> json) {
    return OverviewRuntimeMetaData(
      cacheHit: _boolOf(json['cache_hit']),
      cacheAgeMs: _intOf(json['cache_age_ms']),
      cacheTtlMs: _intOf(json['cache_ttl_ms']),
      refreshedAt: _nullableStringOf(json['refreshed_at']),
      forceRefreshApplied: _boolOf(json['force_refresh_applied']),
      staleFallback: _boolOf(json['stale_fallback']),
    );
  }
}

class OverviewFrontendBuildData {
  const OverviewFrontendBuildData({
    this.builtAt,
    this.bundleUpdatedAt,
    this.sourceUpdatedAt,
    this.apiBaseUrl,
    this.stale = false,
    this.reasons = const [],
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
      stale ||
      (builtAt?.isNotEmpty ?? false) ||
      (bundleUpdatedAt?.isNotEmpty ?? false) ||
      (sourceUpdatedAt?.isNotEmpty ?? false) ||
      (apiBaseUrl?.isNotEmpty ?? false) ||
      (probeTarget?.isNotEmpty ?? false) ||
      reasons.isNotEmpty;

  String? get effectiveBuiltAt => builtAt ?? bundleUpdatedAt;

  factory OverviewFrontendBuildData.fromJson(Map<String, dynamic> json) {
    return OverviewFrontendBuildData(
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

class OverviewJobHealthData {
  const OverviewJobHealthData({
    required this.totalJobs,
    required this.enabledJobs,
    required this.healthyJobs,
    required this.warningJobs,
    required this.failedJobs,
    required this.queuedJobs,
    this.lastRunAt,
  });

  final int totalJobs;
  final int enabledJobs;
  final int healthyJobs;
  final int warningJobs;
  final int failedJobs;
  final int queuedJobs;
  final String? lastRunAt;

  factory OverviewJobHealthData.fromJson(Map<String, dynamic> json) {
    return OverviewJobHealthData(
      totalJobs: (json['total_jobs'] as num?)?.toInt() ?? 0,
      enabledJobs: (json['enabled_jobs'] as num?)?.toInt() ?? 0,
      healthyJobs: (json['healthy_jobs'] as num?)?.toInt() ?? 0,
      warningJobs: (json['warning_jobs'] as num?)?.toInt() ?? 0,
      failedJobs: (json['failed_jobs'] as num?)?.toInt() ?? 0,
      queuedJobs: (json['queued_jobs'] as num?)?.toInt() ?? 0,
      lastRunAt: json['last_run_at']?.toString(),
    );
  }
}

class OverviewWatchedJobData {
  const OverviewWatchedJobData({
    required this.jobCode,
    required this.name,
    required this.enabled,
    required this.scheduleMode,
    required this.health,
    this.lastStatus,
    this.lastStartedAt,
    required this.stale,
  });

  final String jobCode;
  final String name;
  final bool enabled;
  final String scheduleMode;
  final String health;
  final String? lastStatus;
  final String? lastStartedAt;
  final bool stale;

  factory OverviewWatchedJobData.fromJson(Map<String, dynamic> json) {
    return OverviewWatchedJobData(
      jobCode: json['job_code'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      enabled: json['enabled'] as bool? ?? false,
      scheduleMode: json['schedule_mode'] as String? ?? '--',
      health: json['health'] as String? ?? 'disabled',
      lastStatus: json['last_status']?.toString(),
      lastStartedAt: json['last_started_at']?.toString(),
      stale: json['stale'] as bool? ?? false,
    );
  }
}

class OverviewShellStatusData {
  const OverviewShellStatusData({
    required this.marketPhase,
    required this.dataFreshness,
    required this.jobHealth,
    required this.watchedJobs,
    this.snapshotAgeSeconds,
  });

  final String marketPhase;
  final String dataFreshness;
  final int? snapshotAgeSeconds;
  final OverviewJobHealthData jobHealth;
  final List<OverviewWatchedJobData> watchedJobs;

  factory OverviewShellStatusData.fromJson(Map<String, dynamic> json) {
    return OverviewShellStatusData(
      marketPhase: json['market_phase'] as String? ?? 'off_hours',
      dataFreshness: json['data_freshness'] as String? ?? 'missing',
      snapshotAgeSeconds: (json['snapshot_age_seconds'] as num?)?.toInt(),
      jobHealth: OverviewJobHealthData.fromJson(
        json['job_health'] as Map<String, dynamic>? ?? const {},
      ),
      watchedJobs: (json['watched_jobs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OverviewWatchedJobData.fromJson)
          .toList(growable: false),
    );
  }
}

class OverviewSnapshot {
  const OverviewSnapshot({
    required this.tradeDate,
    this.generatedAt,
    this.runtimeMeta = const OverviewRuntimeMetaData(),
    this.frontendBuild = const OverviewFrontendBuildData(),
    this.snapshotAt,
    this.shIndex,
    this.szIndex,
    this.cyIndex,
    this.totalAmountYi,
    this.predictedAmountYi,
    this.lastAmountYi,
    this.upCount,
    this.flatCount,
    this.downCount,
    required this.notices,
    required this.indices,
    required this.amountSummary,
    required this.breadthSummary,
    this.plateRotation = const PlateRotationSnapshot(
      tradeDate: null,
      fetchedAt: null,
      dates: <String>[],
      total: 0,
      items: <PlateRotationItemData>[],
    ),
    required this.sentiment,
    required this.shellStatus,
  });

  final String tradeDate;
  final String? generatedAt;
  final OverviewRuntimeMetaData runtimeMeta;
  final OverviewFrontendBuildData frontendBuild;
  final String? snapshotAt;
  final double? shIndex;
  final double? szIndex;
  final double? cyIndex;
  final double? totalAmountYi;
  final double? predictedAmountYi;
  final double? lastAmountYi;
  final int? upCount;
  final int? flatCount;
  final int? downCount;
  final List<OverviewNoticeData> notices;
  final List<OverviewIndexData> indices;
  final OverviewAmountSummaryData amountSummary;
  final OverviewBreadthSummaryData breadthSummary;
  final PlateRotationSnapshot plateRotation;
  final OverviewSentimentSummaryData sentiment;
  final OverviewShellStatusData shellStatus;

  factory OverviewSnapshot.fromJson(Map<String, dynamic> json) {
    final shIndex = (json['sh_index'] as num?)?.toDouble();
    final szIndex = (json['sz_index'] as num?)?.toDouble();
    final cyIndex = (json['cy_index'] as num?)?.toDouble();
    final totalAmountYi = (json['total_amount_yi'] as num?)?.toDouble();
    final predictedAmountYi = (json['predicted_amount_yi'] as num?)?.toDouble();
    final lastAmountYi = (json['last_amount_yi'] as num?)?.toDouble();
    final upCount = (json['up_count'] as num?)?.toInt();
    final flatCount = (json['flat_count'] as num?)?.toInt();
    final downCount = (json['down_count'] as num?)?.toInt();

    final fallbackIndices = <OverviewIndexData>[
      OverviewIndexData(
        code: 'sh',
        name: '上证指数',
        shortName: 'SH',
        value: shIndex,
        displayValue: _formatDouble(shIndex),
        market: 'Shanghai',
      ),
      OverviewIndexData(
        code: 'sz',
        name: '深证成指',
        shortName: 'SZ',
        value: szIndex,
        displayValue: _formatDouble(szIndex),
        market: 'Shenzhen',
      ),
      OverviewIndexData(
        code: 'cy',
        name: '创业板指',
        shortName: 'CY',
        value: cyIndex,
        displayValue: _formatDouble(cyIndex),
        market: 'ChiNext',
      ),
    ];

    final fallbackAmountSummary = OverviewAmountSummaryData(
      totalAmountYi: totalAmountYi,
      predictedAmountYi: predictedAmountYi,
      lastAmountYi: lastAmountYi,
      deltaVsLastYi: totalAmountYi == null || lastAmountYi == null
          ? null
          : totalAmountYi - lastAmountYi,
      completionRatio: totalAmountYi == null ||
              predictedAmountYi == null ||
              predictedAmountYi == 0
          ? null
          : totalAmountYi / predictedAmountYi,
    );

    final totalBreadth = (upCount ?? 0) + (flatCount ?? 0) + (downCount ?? 0);
    final fallbackBreadthSummary = OverviewBreadthSummaryData(
      upCount: upCount,
      flatCount: flatCount,
      downCount: downCount,
      leadingSide: upCount == null || downCount == null
          ? null
          : upCount > downCount
              ? 'up'
              : upCount < downCount
                  ? 'down'
                  : 'balanced',
      upRatio:
          totalBreadth == 0 || upCount == null ? null : upCount / totalBreadth,
      downRatio: totalBreadth == 0 || downCount == null
          ? null
          : downCount / totalBreadth,
    );

    final notices = (json['notices'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OverviewNoticeData.fromJson)
        .toList(growable: false);
    final indices = (json['indices'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OverviewIndexData.fromJson)
        .toList(growable: false);
    final amountSummary = OverviewAmountSummaryData.fromJson(
      json['amount_summary'] as Map<String, dynamic>? ?? const {},
    );
    final breadthSummary = OverviewBreadthSummaryData.fromJson(
      json['breadth_summary'] as Map<String, dynamic>? ?? const {},
    );

    return OverviewSnapshot(
      tradeDate: json['trade_date'] as String? ?? '--',
      generatedAt: json['generated_at']?.toString(),
      runtimeMeta: OverviewRuntimeMetaData.fromJson(
        json['runtime_meta'] as Map<String, dynamic>? ?? const {},
      ),
      frontendBuild: OverviewFrontendBuildData.fromJson(
        json['frontend_build'] as Map<String, dynamic>? ?? const {},
      ),
      snapshotAt: json['snapshot_at']?.toString(),
      shIndex: shIndex,
      szIndex: szIndex,
      cyIndex: cyIndex,
      totalAmountYi: totalAmountYi,
      predictedAmountYi: predictedAmountYi,
      lastAmountYi: lastAmountYi,
      upCount: upCount,
      flatCount: flatCount,
      downCount: downCount,
      notices: notices,
      indices: indices.isEmpty ? fallbackIndices : indices,
      amountSummary: _isOverviewAmountSummaryEmpty(amountSummary)
          ? fallbackAmountSummary
          : amountSummary,
      breadthSummary: _isOverviewBreadthSummaryEmpty(breadthSummary)
          ? fallbackBreadthSummary
          : breadthSummary,
      plateRotation: PlateRotationSnapshot.fromJson(
        json['plate_rotation'] as Map<String, dynamic>? ?? const {},
      ),
      sentiment: OverviewSentimentSummaryData.fromJson(
        json['sentiment'] as Map<String, dynamic>? ?? const {},
      ),
      shellStatus: OverviewShellStatusData.fromJson(
        json['shell_status'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

bool _isOverviewAmountSummaryEmpty(OverviewAmountSummaryData value) {
  return value.totalAmountYi == null &&
      value.predictedAmountYi == null &&
      value.lastAmountYi == null &&
      value.deltaVsLastYi == null &&
      value.completionRatio == null;
}

bool _isOverviewBreadthSummaryEmpty(OverviewBreadthSummaryData value) {
  return value.upCount == null &&
      value.flatCount == null &&
      value.downCount == null &&
      value.leadingSide == null &&
      value.upRatio == null &&
      value.downRatio == null;
}

class OverviewDashboardSnapshot {
  const OverviewDashboardSnapshot({
    required this.overview,
    required this.yesterdayStats,
    required this.boardHeight,
    required this.boardTier,
  });

  final OverviewSnapshot overview;
  final YesterdayStatsSnapshot yesterdayStats;
  final BoardHeightSnapshot boardHeight;
  final BoardTierSnapshot boardTier;
}

class OverviewRepository {
  const OverviewRepository(this._client);

  final ApiClient _client;

  Future<OverviewSnapshot> fetchShell() async {
    final data = await _client.getMap('/api/v1/overview');
    return OverviewSnapshot.fromJson(data);
  }

  Future<OverviewDashboardSnapshot> fetchDashboard() async {
    final overview = await fetchShell();
    return fetchDashboardWithOverview(overview);
  }

  Future<OverviewDashboardSnapshot> fetchDashboardWithOverview(
    OverviewSnapshot overview,
  ) async {
    final results = await Future.wait<Map<String, dynamic>>([
      _client.getMap('/api/v1/yesterday/stats?limit=8'),
      _client.getMap('/api/v1/board-height'),
      _client.getMap('/api/v1/lianban/tiers?tier_limit=6&stock_limit=4'),
    ]);

    return OverviewDashboardSnapshot(
      overview: overview,
      yesterdayStats: YesterdayStatsSnapshot.fromJson(results[0]),
      boardHeight: BoardHeightSnapshot.fromJson(results[1]),
      boardTier: BoardTierSnapshot.fromJson(results[2]),
    );
  }
}

String _formatDouble(double? value) {
  if (value == null) {
    return '--';
  }
  return value.toStringAsFixed(2);
}

int _intOf(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
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

List<String> _stringListOf(Object? value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _nullableStringOf(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
