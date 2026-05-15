import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/ask_ai/presentation/ask_ai_page.dart';
import '../features/auction/presentation/auction_page.dart';
import '../features/board_height/presentation/board_height_page.dart';
import '../features/board_tier/presentation/board_tier_page.dart';
import '../features/jobs/presentation/jobs_page.dart';
import '../features/limit_review/presentation/limit_review_page.dart';
import '../features/market_center/presentation/market_center_page.dart';
import '../features/news/presentation/news_page.dart';
import '../features/node/presentation/node_page.dart';
import '../features/overview/presentation/overview_page.dart';
import '../features/plate_rotation/presentation/plate_rotation_page.dart';
import '../features/yesterday_stats/presentation/yesterday_stats_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/overview',
  routes: <GoRoute>[
    GoRoute(
      path: '/',
      redirect: (_, __) => '/overview',
    ),
    GoRoute(
      path: '/overview',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        const OverviewPage(),
      ),
    ),
    GoRoute(
      path: '/auction',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        const AuctionPage(),
      ),
    ),
    GoRoute(
      path: '/node',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        const NodePage(),
      ),
    ),
    GoRoute(
      path: '/market-center',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        MarketCenterPage(
          key: state.pageKey,
          initialTradeDate: state.uri.queryParameters['tradeDate'],
        ),
      ),
    ),
    GoRoute(
      path: '/yesterday-stats',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        YesterdayStatsPage(
          key: state.pageKey,
          initialTradeDate: state.uri.queryParameters['tradeDate'],
          initialSectionKey: state.uri.queryParameters['section'],
        ),
      ),
    ),
    GoRoute(
      path: '/board-tier',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        BoardTierPage(
          key: state.pageKey,
          initialTradeDate: state.uri.queryParameters['tradeDate'],
        ),
      ),
    ),
    GoRoute(
      path: '/board-height',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        BoardHeightPage(
          key: state.pageKey,
          initialTradeDate: state.uri.queryParameters['tradeDate'],
        ),
      ),
    ),
    GoRoute(
      path: '/limit-review',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        LimitReviewPage(
          key: state.pageKey,
          initialTradeDate: state.uri.queryParameters['tradeDate'],
          initialSectionKey: state.uri.queryParameters['section'],
        ),
      ),
    ),
    GoRoute(
      path: '/plate-rotation',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        PlateRotationPage(
          key: state.pageKey,
          initialTradeDate: state.uri.queryParameters['tradeDate'],
        ),
      ),
    ),
    GoRoute(
      path: '/news',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        NewsPage(
          key: state.pageKey,
          initialTabIndex: _resolveNewsInitialTabIndex(
            state.uri.queryParameters['tab'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/ask-ai',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        const AskAiPage(),
      ),
    ),
    GoRoute(
      path: '/jobs',
      pageBuilder: (_, state) => _workbenchPage(
        state,
        const JobsPage(),
      ),
    ),
  ],
);

Page<void> _workbenchPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: child,
  );
}

int _resolveNewsInitialTabIndex(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'today' || 'today-hot' => 1,
    'message' || 'messages' || 'message-center' || 'fast-news' || '724' => 2,
    'calendar' || 'timeline' => 3,
    'monthly' || 'pattern' || 'monthly-pattern' => 4,
    _ => 0,
  };
}
