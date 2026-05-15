import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.response);

  final Map<String, dynamic> response;
  String? requestedPath;

  @override
  Future<Map<String, dynamic>> getMap(String path) async {
    requestedPath = path;
    return response;
  }
}

void main() {
  test(
      'fetchShell falls back to top-level overview metrics when sections are missing',
      () async {
    final client = _FakeApiClient(
      {
        'trade_date': '2026-04-22',
        'generated_at': '2026-04-22T09:31:00',
        'snapshot_at': '2026-04-22T09:30:00',
        'sh_index': 3320.12,
        'sz_index': 10011.88,
        'cy_index': 2018.66,
        'total_amount_yi': 9988.0,
        'predicted_amount_yi': 11200.0,
        'last_amount_yi': 9200.0,
        'up_count': 1822,
        'flat_count': 211,
        'down_count': 3011,
        'runtime_meta': {
          'cache_hit': false,
          'cache_age_ms': 0,
          'cache_ttl_ms': 3000,
          'refreshed_at': '2026-04-22T09:31:00',
        },
        'frontend_build': {
          'built_at': '2026-04-22T09:29:30',
          'bundle_updated_at': '2026-04-22T09:29:32',
          'source_updated_at': '2026-04-22T09:29:00',
          'api_base_url': 'https://api.example.invalid',
          'stale': false,
          'reasons': <dynamic>[],
        },
        'notices': <dynamic>[],
        'indices': <dynamic>[],
        'amount_summary': <String, dynamic>{},
        'breadth_summary': <String, dynamic>{},
        'plate_rotation': {
          'trade_date': '2026-04-22',
          'fetched_at': '2026-04-22T09:30:30',
          'dates': ['2026-04-18', '2026-04-21', '2026-04-22'],
          'total': 2,
          'items': [
            {
              'plate_name': '机器人',
              'plate_code': 'BK0420',
              'latest_zt': 18,
              'latest_strength_text': '+18.00%',
              'series': [
                {
                  'date': '2026-04-18',
                  'zt_count': 14,
                  'strength': 14.0,
                  'strength_text': '+14.00%',
                },
                {
                  'date': '2026-04-22',
                  'zt_count': 18,
                  'strength': 18.0,
                  'strength_text': '+18.00%',
                },
              ],
            },
          ],
        },
        'sentiment': {
          'stage': 'neutral',
          'bias': 'neutral',
          'score': 50,
          'metrics': <dynamic>[],
        },
        'shell_status': {
          'market_phase': 'intraday',
          'data_freshness': 'fresh',
          'job_health': {
            'total_jobs': 1,
            'enabled_jobs': 1,
            'healthy_jobs': 1,
            'warning_jobs': 0,
            'failed_jobs': 0,
            'queued_jobs': 0,
          },
          'watched_jobs': <dynamic>[],
        },
      },
    );

    final repository = OverviewRepository(client);
    final snapshot = await repository.fetchShell();

    expect(client.requestedPath, '/api/v1/overview');
    expect(snapshot.tradeDate, '2026-04-22');
    expect(snapshot.shIndex, 3320.12);
    expect(snapshot.totalAmountYi, 9988.0);
    expect(snapshot.frontendBuild.apiBaseUrl, 'https://api.example.invalid');
    expect(snapshot.frontendBuild.stale, isFalse);
    expect(snapshot.frontendBuild.effectiveBuiltAt, '2026-04-22T09:29:30');
    expect(
      snapshot.indices.map((item) => item.code).toList(growable: false),
      ['sh', 'sz', 'cy'],
    );
    expect(snapshot.amountSummary.totalAmountYi, 9988.0);
    expect(snapshot.amountSummary.predictedAmountYi, 11200.0);
    expect(snapshot.amountSummary.lastAmountYi, 9200.0);
    expect(snapshot.amountSummary.deltaVsLastYi, 788.0);
    expect(
        snapshot.amountSummary.completionRatio, closeTo(0.8917857, 0.000001));
    expect(snapshot.breadthSummary.upCount, 1822);
    expect(snapshot.breadthSummary.flatCount, 211);
    expect(snapshot.breadthSummary.downCount, 3011);
    expect(snapshot.breadthSummary.leadingSide, 'down');
    expect(snapshot.plateRotation.total, 2);
    expect(snapshot.plateRotation.items.first.plateName, '机器人');
    expect(snapshot.plateRotation.items.first.latestStrengthText, '+18.00%');
  });

  test('fetchShell treats externally served frontend as available', () async {
    final client = _FakeApiClient(
      {
        'trade_date': '2026-04-22',
        'generated_at': '2026-04-22T09:31:00',
        'snapshot_at': '2026-04-22T09:30:00',
        'frontend_build': {
          'built_at': null,
          'bundle_updated_at': null,
          'source_updated_at': null,
          'api_base_url': null,
          'stale': false,
          'reasons': <dynamic>[],
          'probe_target': 'http://frontend/',
          'externally_served': true,
        },
        'notices': <dynamic>[],
        'indices': <dynamic>[],
        'amount_summary': <String, dynamic>{},
        'breadth_summary': <String, dynamic>{},
        'sentiment': <String, dynamic>{},
        'shell_status': <String, dynamic>{},
      },
    );

    final repository = OverviewRepository(client);
    final snapshot = await repository.fetchShell();

    expect(snapshot.frontendBuild.externallyServed, isTrue);
    expect(snapshot.frontendBuild.probeTarget, 'http://frontend/');
    expect(snapshot.frontendBuild.hasData, isTrue);
    expect(snapshot.frontendBuild.stale, isFalse);
  });
}
