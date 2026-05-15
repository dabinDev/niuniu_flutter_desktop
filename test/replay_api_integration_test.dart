import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/core/network/api_client.dart';
import 'package:niuniu_kaipan/features/auction/data/auction_repository.dart';
import 'package:niuniu_kaipan/features/board_height/data/board_height_repository.dart';
import 'package:niuniu_kaipan/features/limit_review/data/review_repository.dart';
import 'package:niuniu_kaipan/features/market_center/data/market_center_repository.dart';
import 'package:niuniu_kaipan/features/overview/data/overview_repository.dart';
import 'package:niuniu_kaipan/shared/data/market_api_repository.dart';

void main() {
  test(
    'flutter repositories read replayed local api server',
    () async {
      final harness = await _LocalReplayApiHarness.start();
      addTearDown(harness.close);

      final client = ApiClient(baseUrl: harness.baseUrl);
      addTearDown(client.close);

      final overviewRepository = OverviewRepository(client);
      final auctionRepository = AuctionRepository(client);
      final boardHeightRepository = BoardHeightRepository(client);
      final marketCenterRepository = MarketCenterRepository(client);
      final reviewRepository = ReviewRepository(client);
      final marketApiRepository = MarketApiRepository(client);

      final overview = await overviewRepository.fetchShell();
      expect(overview.tradeDate, '2026-04-17');
      expect(overview.shIndex, 3321.45);
      expect(overview.amountSummary.deltaVsLastYi, 1450.5);
      expect(overview.sentiment.metrics.first.today, 12);

      final auctionPage = await auctionRepository.fetchAuctionPageData(
        days: 2,
        stockLimit: 8,
        rankLimit: 20,
      );
      expect(auctionPage.tradeDate, '2026-04-17');
      expect(auctionPage.historyColumns, hasLength(2));
      expect(
        auctionPage.historyColumns.first.items
            .map((item) => item.code)
            .toList(),
        ['600000', '000967', '002051'],
      );
      expect(auctionPage.rankSections.first.items.first.code, '600000');
      expect(auctionPage.rankSections[1].items.first.code, '000967');

      final marketCenterPage = await marketCenterRepository.fetchPage(
        tradeDate: '2026-04-16',
      );
      expect(marketCenterPage.navigation.resolvedTradeDate, '2026-04-16');
      expect(marketCenterPage.navigation.previousTradeDate, isNull);
      expect(marketCenterPage.navigation.nextTradeDate, '2026-04-17');
      expect(
        marketCenterPage.navigation.availableTradeDates,
        ['2026-04-17', '2026-04-16'],
      );
      expect(
        marketCenterPage.marketCenter.tables.first.rows.first.take(6).toList(),
        ['1', '600000', 'PFBank', '+3.11%', '10.05', '8.77亿'],
      );
      expect(marketCenterPage.marketCenter.tables.first.rows.first[9], '5.43亿');
      expect(marketCenterPage.marketCenter.tables[4].rows.first[12], '1');

      final boardHeightHistory = await boardHeightRepository.fetchSnapshot(
        tradeDate: '2026-04-16',
      );
      expect(boardHeightHistory.tradeDate, '2026-04-16');
      expect(boardHeightHistory.previousTradeDate, isNull);
      expect(boardHeightHistory.nextTradeDate, '2026-04-17');
      expect(
        boardHeightHistory.availableTradeDates,
        ['2026-04-17', '2026-04-16'],
      );
      expect(boardHeightHistory.latestHeight, 2);
      expect(boardHeightHistory.chartItems.last.leaderName, 'PFBank');

      final boardTierHistory = await marketApiRepository.fetchBoardTier(
        tradeDate: '2026-04-16',
        tierLimit: 3,
        stockLimit: 5,
      );
      expect(boardTierHistory.tradeDate, '2026-04-16');
      expect(boardTierHistory.previousTradeDate, isNull);
      expect(boardTierHistory.nextTradeDate, '2026-04-17');
      expect(
        boardTierHistory.availableTradeDates,
        ['2026-04-17', '2026-04-16'],
      );
      expect(
        boardTierHistory.tiers.map((item) => item.boardCount).toList(),
        [3, 1],
      );
      expect(boardTierHistory.tiers.first.stocks.first.code, '600000');
      expect(boardTierHistory.tiers.first.stocks.first.regionName, 'Shanghai');
      expect(boardTierHistory.tiers[1].stocks.first.regionName, 'Guangdong');

      final boardTierLatest = await marketApiRepository.fetchBoardTier(
        tierLimit: 3,
        stockLimit: 5,
      );
      expect(boardTierLatest.tradeDate, '2026-04-17');
      expect(boardTierLatest.previousTradeDate, '2026-04-16');
      expect(boardTierLatest.nextTradeDate, isNull);
      expect(
        boardTierLatest.availableTradeDates,
        ['2026-04-17', '2026-04-16'],
      );
      expect(
        boardTierLatest.tiers.map((item) => item.boardCount).toList(),
        [4, 2, 1],
      );
      expect(
        boardTierLatest.tiers[1].stocks.map((item) => item.code).toList(),
        ['000967', '002051'],
      );
      expect(boardTierLatest.tiers.first.stocks.first.regionName, 'Shanghai');
      expect(boardTierLatest.tiers[1].stocks.first.regionName, 'Guangdong');
      expect(boardTierLatest.tiers[1].stocks.first.industryName, 'Robot');
      expect(boardTierLatest.tiers[1].stocks[1].regionName, 'Zhejiang');

      final reviewPage = await reviewRepository.fetchPage(
        tradeDate: '2026-04-16',
        weaknessLimit: 5,
      );
      expect(reviewPage.navigation.resolvedTradeDate, '2026-04-16');
      expect(reviewPage.limitReview.maxBoardHeight, 2);
      expect(reviewPage.limitReview.groups.first.name, '2板');
      expect(reviewPage.limitReview.groups[1].rows[1],
          ['002051', 'ZGIntl', 'Infra']);
      expect(reviewPage.boardHeight.latestHeight, 2);
      expect(reviewPage.boardHeight.chartItems.last.leaderName, 'PFBank');
      expect(reviewPage.yesterdayStats.todayStats.zt, 8);
      expect(
          reviewPage.yesterdayStats.sections[0].items.first.region, 'Shanghai');
      expect(reviewPage.yesterdayStats.sections[0].items[1].region, 'Zhejiang');
      expect(reviewPage.yesterdayStats.sections[2].items.first.code, '000967');
      expect(reviewPage.yesterdayStats.sections[2].items.first.region,
          'Guangdong');

      final yesterdayStats = await marketApiRepository.fetchYesterdayStats(
        tradeDate: '2026-04-16',
      );
      expect(yesterdayStats.sections[0].items.first.region, 'Shanghai');
      expect(yesterdayStats.sections[0].items[1].region, 'Zhejiang');
      expect(yesterdayStats.sections[2].items.first.region, 'Guangdong');

      final plateRotation =
          await marketApiRepository.fetchPlateRotation(limit: 2);
      expect(plateRotation.tradeDate, '2026-04-17');
      expect(plateRotation.previousTradeDate, isNull);
      expect(plateRotation.nextTradeDate, isNull);
      expect(plateRotation.availableTradeDates, ['2026-04-17']);
      expect(plateRotation.items.first.plateName, 'Robot');

      final newsCenter = await marketApiRepository.fetchNewsCenter(limit: 5);
      expect(newsCenter.sections.map((item) => item.key).toList(),
          ['ths', 'chaosha']);
      expect(newsCenter.sections.first.items.first.title,
          'Robot strength continues');
      expect(newsCenter.sections.first.items.first.time, '09:12');
      expect(newsCenter.sections[1].items.first.subtitle, 'Robot');

      final hotNews = await marketApiRepository.fetchHotNews(limit: 5);
      expect(hotNews.total, 2);
      expect(hotNews.items.first.title, 'Robot strength continues');
      expect(hotNews.items.last.extra, '热度 87');

      final todayHot = await marketApiRepository.fetchTodayHot(limit: 5);
      expect(todayHot.total, 2);
      expect(todayHot.items.first.title, 'Robot second wave');
      expect(todayHot.items.first.group, '2026-04-17');

      final fastNews = await marketApiRepository.fetchFastNews(limit: 5);
      expect(fastNews.total, 2);
      expect(fastNews.items.first.title, 'Robot order signs');
      expect(fastNews.items.first.isImportant, isTrue);
      expect(fastNews.items.last.subtitle, 'Infra chain turns active');

      final timeline = await marketApiRepository.fetchTimeline(limit: 5);
      expect(timeline.total, 3);
      expect(timeline.items.first.group, '2026-04-17 Morning');
      expect(timeline.items.first.title, '央企改革窗口开启');
      expect(timeline.items.last.title, '新能源链观察窗口');

      final monthlyPatterns = await marketApiRepository.fetchMonthlyPatterns();
      expect(monthlyPatterns, hasLength(12));
      expect(monthlyPatterns.first.monthIndex, 1);
      expect(monthlyPatterns.first.month, '1月');
      expect(monthlyPatterns.first.driver, '春节效应 / 资金回流');
      expect(monthlyPatterns.last.month, '12月');
    },
    skip: _hasReplayApiWorkspace()
        ? false
        : 'requires sibling db_server and api_server replay fixtures',
  );
}

bool _hasReplayApiWorkspace() {
  try {
    _findWorkspaceRoot();
    return true;
  } catch (_) {
    return false;
  }
}

class _LocalReplayApiHarness {
  _LocalReplayApiHarness._({
    required this.baseUrl,
    required Process process,
    required Directory tempDir,
    required StreamSubscription<String> stdoutSubscription,
    required StreamSubscription<String> stderrSubscription,
  })  : _process = process,
        _tempDir = tempDir,
        _stdoutSubscription = stdoutSubscription,
        _stderrSubscription = stderrSubscription;

  final String baseUrl;
  final Process _process;
  final Directory _tempDir;
  final StreamSubscription<String> _stdoutSubscription;
  final StreamSubscription<String> _stderrSubscription;

  static Future<_LocalReplayApiHarness> start() async {
    final workspaceRoot = _findWorkspaceRoot();
    final dbServerDir = _childPath(workspaceRoot.path, ['db_server']);
    final apiServerDir = _childPath(workspaceRoot.path, ['api_server']);
    final fixtureDir = _childPath(
      dbServerDir,
      ['fixtures', 'replay', 'trading_day_smoke'],
    );
    final uvExe = _uvExecutable();
    final tempDir = await Directory.systemTemp.createTemp(
      'niuniu_replay_api_test_',
    );
    final dbPath = _childPath(tempDir.path, ['replay_flutter_test.db']);
    final databaseUrl = 'sqlite:///${dbPath.replaceAll('\\', '/')}';
    final port = await _reservePort();

    final replayResult = await Process.run(
      uvExe,
      [
        'run',
        '--no-project',
        '--with',
        'alembic',
        '--with',
        'pydantic',
        '--with',
        'pydantic-settings',
        '--with',
        'pyyaml',
        '--with',
        'requests',
        '--with',
        'sqlalchemy',
        'python',
        '-m',
        'app.main',
        'replay-fixtures',
        fixtureDir,
      ],
      workingDirectory: dbServerDir,
      environment: {
        ...Platform.environment,
        'NIUNIU_DB_DATABASE_URL': databaseUrl,
      },
    );
    if (replayResult.exitCode != 0) {
      throw StateError(
        'replay-fixtures failed:\n${replayResult.stdout}\n${replayResult.stderr}',
      );
    }

    final process = await Process.start(
      uvExe,
      [
        'run',
        '--extra',
        'test',
        'python',
        '-m',
        'uvicorn',
        'app.main:app',
        '--host',
        '127.0.0.1',
        '--port',
        '$port',
        '--log-level',
        'warning',
      ],
      workingDirectory: apiServerDir,
      environment: {
        ...Platform.environment,
        'PYTHONPATH': apiServerDir,
        'NIUNIU_API_DATABASE_URL': databaseUrl,
      },
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutSubscription =
        process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
    final stderrSubscription =
        process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

    await _waitForHealth(
      port,
      process,
      stdoutBuffer,
      stderrBuffer,
      timeout: const Duration(seconds: 30),
    );

    return _LocalReplayApiHarness._(
      baseUrl: 'http://127.0.0.1:$port',
      process: process,
      tempDir: tempDir,
      stdoutSubscription: stdoutSubscription,
      stderrSubscription: stderrSubscription,
    );
  }

  Future<void> close() async {
    if (_process.kill()) {
      try {
        await _process.exitCode.timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    try {
      if (_tempDir.existsSync()) {
        await _tempDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

Future<void> _waitForHealth(
  int port,
  Process process,
  StringBuffer stdoutBuffer,
  StringBuffer stderrBuffer, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  final client = HttpClient();
  try {
    while (DateTime.now().isBefore(deadline)) {
      try {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/api/v1/health'),
        );
        final response = await request.close();
        final body = await utf8.decoder.bind(response).join();
        if (response.statusCode == 200 && body.contains('"status":"ok"')) {
          return;
        }
      } catch (_) {}

      final exitCode = await process.exitCode.timeout(
        const Duration(milliseconds: 1),
        onTimeout: () => -1,
      );
      if (exitCode != -1) {
        throw StateError(
          'api_server exited early with code $exitCode\nstdout:\n$stdoutBuffer\nstderr:\n$stderrBuffer',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  } finally {
    client.close(force: true);
  }

  throw StateError(
    'Timed out waiting for api_server health\nstdout:\n$stdoutBuffer\nstderr:\n$stderrBuffer',
  );
}

Future<int> _reservePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Directory _findWorkspaceRoot() {
  var current = Directory.current.absolute;
  for (var i = 0; i < 5; i++) {
    final dbServer = Directory(_childPath(current.path, ['db_server']));
    final apiServer = Directory(_childPath(current.path, ['api_server']));
    if (dbServer.existsSync() && apiServer.existsSync()) {
      return current;
    }
    current = current.parent;
  }
  throw StateError(
      'Could not locate workspace root from ${Directory.current.path}');
}

String _uvExecutable() {
  return Platform.isWindows ? 'uv' : 'uv';
}

String _childPath(String base, List<String> children) {
  var path = base;
  for (final child in children) {
    path = '$path${Platform.pathSeparator}$child';
  }
  return path;
}
