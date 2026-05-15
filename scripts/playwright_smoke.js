const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const DEFAULT_BASE_URL = process.env.NIUNIU_FRONTEND_BASE_URL || '';
const DEFAULT_WAIT_MS = 30000;
const DEFAULT_VIEWPORT = { width: 1600, height: 1200 };
const DEFAULT_PAGES = [
  { name: 'overview', route: '/overview' },
  { name: 'auction', route: '/auction' },
  { name: 'node', route: '/node' },
  { name: 'market_center', route: '/market-center' },
  { name: 'yesterday', route: '/yesterday-stats' },
  { name: 'board_tier', route: '/board-tier' },
  { name: 'board_height', route: '/board-height' },
  { name: 'limit_review', route: '/limit-review' },
  { name: 'plate_rotation', route: '/plate-rotation' },
  { name: 'news', route: '/news' },
  { name: 'ask_ai', route: '/ask-ai' },
  { name: 'jobs', route: '/jobs' },
];

const SHELL_NAV_ORDER = [
  '\u603b\u89c8',
  '\u725b\u725b\u7ade\u4ef7',
  '\u725b\u725b\u8282\u70b9',
  '\u8fde\u677f\u5929\u68af',
  '\u884c\u60c5\u4e2d\u5fc3',
  '\u7a7a\u5934\u6570\u636e',
  '\u8fde\u677f\u9ad8\u5ea6',
  '\u6da8\u505c\u590d\u76d8',
  '\u677f\u5757\u8f6e\u52a8',
  '\u725b\u725b\u8d44\u8baf',
  '\u95eeAI',
  '\u4efb\u52a1\u8c03\u5ea6',
];

const SHELL_COMPACT_MARKERS = [
  '\u6d88\u606f\u4e2d\u5fc3',
  '\u8bbe\u7f6e',
  '\u53cd\u9988',
  '\u5173\u4e8e',
  '\u5feb\u7167',
  '\u524d\u7aef\u5305',
];

const PAGE_EXPECTED_API = {
  overview: [
    '/api/v1/overview',
    '/api/v1/yesterday/stats',
    '/api/v1/board-height',
    '/api/v1/lianban/tiers',
  ],
  auction: ['/api/v1/auction/page'],
  node: ['/api/v1/node/snapshot'],
  market_center: ['/api/v1/market-center-page'],
  yesterday: ['/api/v1/yesterday/stats', '/api/v1/review-page'],
  board_tier: ['/api/v1/lianban/tiers'],
  board_height: ['/api/v1/board-height'],
  limit_review: ['/api/v1/review-page'],
  plate_rotation: [
    '/api/v1/plate-rotation',
    '/api/v1/plates/',
    '/api/v1/node/plates/',
  ],
  news: ['/api/v1/news/page'],
  ask_ai: ['/api/v1/ask-ai/context', '/api/v1/ask-ai/sessions?limit=7'],
  jobs: ['/internal/jobs/page'],
};

const PAGE_EXPECTED_TEXT = {
  overview: [
    '\u603b\u89c8\u5de5\u4f5c\u53f0',
    '\u76d8\u9762\u603b\u89c8',
    '\u60c5\u7eea\u5bf9\u7167',
    '\u8fde\u677f\u9ad8\u5ea6',
    '\u8fde\u677f\u5929\u68af',
  ],
  auction: [
    '\u725b\u725b\u7ade\u4ef7',
    '\u6309\u65e7\u7248\u7ade\u4ef7\u684c\u9762\u7684\u9605\u8bfb\u987a\u5e8f\u7ec4\u7ec7',
    'AI\u7ade\u4ef7',
    '\u590d\u5236\u56fe\u7247',
    '\u5bfc\u51fa Excel',
    '\u5bfc\u51fa CSV',
  ],
  node: [
    '\u725b\u725b\u8282\u70b9',
    '\u6309\u65e7\u7248\u8282\u70b9\u9875\u7684\u5de5\u4f5c\u6d41\u7ec4\u7ec7',
    '\u5f53\u65e5\u677f\u5757\u5f3a\u5ea6',
  ],
  market_center: [
    '\u884c\u60c5\u4e2d\u5fc3',
    '\u516d\u5927\u80a1\u6c60',
    '\u6da8\u505c\u80a1\u6c60',
    '\u6628\u65e5\u6da8\u505c',
  ],
  yesterday: [
    '\u7a7a\u5934\u6570\u636e',
    '\u6628\u65e5\u8dcc\u505c',
    '\u6628\u65e5\u65ad\u677f',
    '\u4eca\u65e5\u8dcc\u505c',
    '\u4eca\u65e5\u65ad\u677f',
  ],
  board_tier: [
    '\u8fde\u677f\u5929\u68af',
    '\u8fde\u677f\u68af\u961f',
    '\u80a1\u7968 / \u72b6\u6001 / \u65f6\u95f4 / \u5730\u533a / \u884c\u4e1a / \u539f\u56e0',
  ],
  board_height: [
    '\u8fde\u677f\u9ad8\u5ea6',
    '\u9ad8\u5ea6\u65f6\u95f4\u8f74',
    '\u9ad8\u5ea6\u66f2\u7ebf',
    '\u9ad8\u5ea6\u77e9\u9635',
  ],
  limit_review: [
    '\u6da8\u505c\u590d\u76d8',
    '\u590d\u76d8\u603b\u89c8',
    '\u8fde\u677f\u9ad8\u5ea6',
    '\u5206\u7ec4\u6da8\u505c\u590d\u76d8',
    '\u5730\u533a / \u884c\u4e1a',
    'AI\u590d\u76d8',
  ],
  plate_rotation: [
    '\u677f\u5757\u8f6e\u52a8',
    '\u6309\u65e7\u7248\u677f\u5757\u8f6e\u52a8\u9875\u7684\u4e60\u60ef\u7ec4\u7ec7',
    '\u5f53\u65e5\u884c\u60c5',
  ],
  news: [
    '\u725b\u725b\u8d44\u8baf',
    '\u725b\u725b\u8d44\u8baf\u5de5\u4f5c\u53f0',
    '\u70ed\u70b9\u8d44\u8baf',
    '\u4eca\u65e5\u70ed\u70b9',
    '7x24 \u5feb\u8baf',
    '\u8d22\u7ecf\u65e5\u5386',
  ],
  ask_ai: [
    '\u95eeAI',
    'AI \u7ed3\u679c',
    '\u67e5\u770b\u4eca\u65e5\u63d0\u793a\u8bcd',
    '\u5237\u65b0\u4e0a\u4e0b\u6587',
  ],
  jobs: [
    '\u4efb\u52a1\u8c03\u5ea6',
    '\u76f4\u63a5\u8bfb\u53d6\u63a5\u53e3\u670d\u52a1\u7684\u8fd0\u7ef4\u5feb\u7167',
    '\u5237\u65b0\u5feb\u7167',
  ],
};

const PAGE_DATA_ASSERTION_FRAGMENTS = {
  overview: [
    '/api/v1/overview',
    '/api/v1/yesterday/stats',
    '/api/v1/board-height',
    '/api/v1/lianban/tiers',
  ],
  auction: ['/api/v1/auction/page'],
  node: ['/api/v1/node/snapshot', '/api/v1/node/plates/'],
  market_center: ['/api/v1/market-center-page'],
  yesterday: ['/api/v1/yesterday/stats', '/api/v1/review-page'],
  board_tier: ['/api/v1/lianban/tiers'],
  board_height: ['/api/v1/board-height'],
  limit_review: ['/api/v1/review-page'],
  plate_rotation: [
    '/api/v1/plate-rotation',
    '/api/v1/plates/',
    '/api/v1/node/plates/',
  ],
  news: ['/api/v1/news/page'],
  ask_ai: [
    '/api/v1/ask-ai/context',
    '/api/v1/ask-ai/sessions',
  ],
  jobs: ['/internal/jobs/page'],
};

const PAGE_LAYOUT_ONLY_EXPECTED_API = {
  node: ['/api/v1/node/snapshot'],
  yesterday: ['/api/v1/yesterday/stats'],
};

const PAGE_LAYOUT_ONLY_DATA_ASSERTION_FRAGMENTS = {
  node: ['/api/v1/node/snapshot'],
  yesterday: ['/api/v1/yesterday/stats'],
};

const CONSOLE_ERROR_ALLOWLIST = [
  {
    label: 'browser ResizeObserver delivery noise',
    pattern: /ResizeObserver loop (limit exceeded|completed with undelivered notifications)/i,
  },
  {
    label: 'jobs manual trigger already running conflict',
    pattern: /Failed to load resource: the server responded with a status of 409 \(Conflict\)/i,
  },
];

const FRONTEND_SKILL_APP_DESIGN_CONTRACT = Object.freeze([
  'operational desktop workspace, not a landing page or placeholder shell',
  'dense but readable market data with stable shell/navigation/status context',
  'restrained chrome: no obvious horizontal overflow, text collision, or hero-only composition',
  'UI changes must keep behavior, real data, screenshots, and style assertions in this smoke gate',
]);

function parseArgs(argv) {
  const args = {
    baseUrl: DEFAULT_BASE_URL,
    waitMs: DEFAULT_WAIT_MS,
    outputDir: path.resolve(__dirname, '..', 'build', 'playwright_smoke'),
    pages: DEFAULT_PAGES,
    viewport: { ...DEFAULT_VIEWPORT },
    skipInteractions: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const current = argv[index];
    const next = argv[index + 1];
    if (current === '--base-url' && next) {
      args.baseUrl = next;
      index += 1;
      continue;
    }
    if (current === '--output-dir' && next) {
      args.outputDir = path.resolve(next);
      index += 1;
      continue;
    }
    if (current === '--wait-ms' && next) {
      const parsed = Number.parseInt(next, 10);
      if (!Number.isNaN(parsed) && parsed >= 0) {
        args.waitMs = parsed;
      }
      index += 1;
      continue;
    }
    if (current === '--viewport' && next) {
      const [width, height] = next
        .toLowerCase()
        .split('x')
        .map((value) => Number.parseInt(value, 10));
      if (
        Number.isFinite(width) &&
        Number.isFinite(height) &&
        width >= 320 &&
        height >= 480
      ) {
        args.viewport = { width, height };
      }
      index += 1;
      continue;
    }
    if (current === '--viewport-width' && next) {
      const parsed = Number.parseInt(next, 10);
      if (!Number.isNaN(parsed) && parsed >= 320) {
        args.viewport = { ...args.viewport, width: parsed };
      }
      index += 1;
      continue;
    }
    if (current === '--viewport-height' && next) {
      const parsed = Number.parseInt(next, 10);
      if (!Number.isNaN(parsed) && parsed >= 480) {
        args.viewport = { ...args.viewport, height: parsed };
      }
      index += 1;
      continue;
    }
    if (current === '--pages' && next) {
      const requested = new Set(
        next
          .split(',')
          .map((value) => value.trim())
          .filter(Boolean),
      );
      args.pages = DEFAULT_PAGES.filter((page) => requested.has(page.name));
      index += 1;
      continue;
    }
    if (current === '--skip-interactions') {
      args.skipInteractions = true;
    }
  }

  return args;
}

function joinHashUrl(baseUrl, route) {
  const normalizedBase = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
  if (normalizedBase.endsWith('#')) {
    return `${normalizedBase}${route}`;
  }
  if (normalizedBase.endsWith('#/')) {
    return `${normalizedBase.slice(0, -1)}${route}`;
  }
  if (normalizedBase.includes('#')) {
    return `${normalizedBase}${route}`;
  }
  return `${normalizedBase}/#${route}`;
}

function isTrackedApiUrl(url) {
  return url.includes('/api/v1/') || url.includes('/internal/');
}

function summarizeApiEntries(entries) {
  if (entries.length === 0) {
    return 'none';
  }
  return entries.map((entry) => `${entry.status} ${entry.method} ${entry.url}`).join('\n');
}

function normalizeForMatch(value) {
  return value.replace(/\s+/g, ' ').trim();
}

function summarizeText(value) {
  const normalized = normalizeForMatch(value);
  if (!normalized) {
    return 'none';
  }
  return normalized.length <= 400 ? normalized : `${normalized.slice(0, 400)}...`;
}

function countMatchingResponses(fragment, apiResponses) {
  return apiResponses.filter(
    (entry) => entry.url.includes(fragment) && entry.status >= 200 && entry.status < 400,
  ).length;
}

function countMatchingResponsesAnyStatus(fragment, apiResponses) {
  return apiResponses.filter((entry) => entry.url.includes(fragment)).length;
}

function findMissingExpectedApi(expectedApi, apiResponses) {
  return expectedApi.filter((fragment) => countMatchingResponses(fragment, apiResponses) === 0);
}

function isLayoutOnly(options) {
  return options?.skipInteractions === true;
}

function expectedApiForPage(pageName, options = {}) {
  if (isLayoutOnly(options) && PAGE_LAYOUT_ONLY_EXPECTED_API[pageName]) {
    return PAGE_LAYOUT_ONLY_EXPECTED_API[pageName];
  }
  return PAGE_EXPECTED_API[pageName] || [];
}

function dataAssertionFragmentsForPage(pageName, options = {}) {
  if (isLayoutOnly(options) && PAGE_LAYOUT_ONLY_DATA_ASSERTION_FRAGMENTS[pageName]) {
    return PAGE_LAYOUT_ONLY_DATA_ASSERTION_FRAGMENTS[pageName];
  }
  return PAGE_DATA_ASSERTION_FRAGMENTS[pageName] || [];
}

function captureExpectedCounts(expectedApi, apiResponses) {
  return expectedApi.map((fragment) => countMatchingResponses(fragment, apiResponses));
}

function findMissingNewExpectedApi(expectedApi, apiResponses, startCounts) {
  return expectedApi.filter(
    (fragment, index) => countMatchingResponses(fragment, apiResponses) <= (startCounts[index] || 0),
  );
}

function captureExpectedCountsAnyStatus(expectedApi, apiResponses) {
  return expectedApi.map((fragment) => countMatchingResponsesAnyStatus(fragment, apiResponses));
}

function findMissingNewExpectedApiAnyStatus(expectedApi, apiResponses, startCounts) {
  return expectedApi.filter(
    (fragment, index) =>
      countMatchingResponsesAnyStatus(fragment, apiResponses) <= (startCounts[index] || 0),
  );
}

function findBlockingRequestFailures(expectedApi, requestFailures, apiResponses) {
  return requestFailures.filter((entry) =>
    expectedApi.some(
      (fragment) =>
        entry.url.includes(fragment) &&
        countMatchingResponses(fragment, apiResponses) === 0,
    ),
  );
}

function findMissingExpectedText(expectedText, pageText) {
  const normalizedPageText = normalizeForMatch(pageText);
  return expectedText.filter((fragment) => !normalizedPageText.includes(normalizeForMatch(fragment)));
}

function expectedTextForPage(pageName, viewport) {
  const expectedText = PAGE_EXPECTED_TEXT[pageName] || [];
  const width = viewport?.width || DEFAULT_VIEWPORT.width;
  const height = viewport?.height || DEFAULT_VIEWPORT.height;
  if (width >= 1500 && height >= 1000) {
    return expectedText;
  }

  // Narrow windows keep the workstation usable by prioritizing the shell and
  // current workspace. Detailed section labels may sit behind page-level
  // scroll regions, so API/data/design assertions carry the deeper contract.
  return expectedText.slice(0, 1);
}

function toInt(value) {
  const parsed = Number.parseInt(`${value ?? ''}`, 10);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function toText(value) {
  return `${value ?? ''}`.trim();
}

function isFilledText(value) {
  const normalized = toText(value);
  return normalized.length > 0 && normalized !== '--';
}

function normalizePlateCodeKey(value) {
  let normalized = toText(value).toUpperCase();
  if (!normalized) {
    return '';
  }
  if (normalized.startsWith('BK')) {
    normalized = normalized.slice(2);
  }
  normalized = normalized.replace(/^0+/, '');
  return normalized || toText(value).toUpperCase();
}

function isAllowlistedConsoleError(message) {
  const text = toText(message);
  return CONSOLE_ERROR_ALLOWLIST.some((entry) => entry.pattern.test(text));
}

function findConsoleErrorFailures(consoleErrors) {
  return consoleErrors.filter((message) => !isAllowlistedConsoleError(message));
}

function escapeRegExp(value) {
  return toText(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function canonicalWeaknessSectionKey(value) {
  const normalized = toText(value);
  switch (normalized) {
    case 'yesterday_limit_down':
    case '\u6628\u65e5\u8dcc\u505c':
      return 'yesterday_limit_down';
    case 'yesterday_broken_board':
    case 'yesterday_duanban':
    case '\u6628\u65e5\u70b8\u677f':
    case '\u6628\u65e5\u65ad\u677f':
      return 'yesterday_broken_board';
    case 'today_limit_down':
    case '\u4eca\u65e5\u8dcc\u505c':
      return 'today_limit_down';
    case 'today_broken_board':
    case 'today_duanban':
    case '\u4eca\u65e5\u70b8\u677f':
    case '\u4eca\u65e5\u65ad\u677f':
      return 'today_broken_board';
    default:
      return normalized;
  }
}

function formatWeaknessTitle(value) {
  switch (canonicalWeaknessSectionKey(value)) {
    case 'yesterday_limit_down':
      return '\u6628\u65e5\u8dcc\u505c';
    case 'yesterday_broken_board':
      return '\u6628\u65e5\u65ad\u677f';
    case 'today_limit_down':
      return '\u4eca\u65e5\u8dcc\u505c';
    case 'today_broken_board':
      return '\u4eca\u65e5\u65ad\u677f';
    default:
      return toText(value) || '--';
  }
}

function buildWeaknessSectionSnapshot(section) {
  const items = Array.isArray(section?.items) ? section.items : [];
  const previewItems = items.slice(0, 2);
  const previewNames = previewItems
    .map((item) => toText(item?.name || item?.stock_name))
    .filter(isFilledText);
  const previewCodes = previewItems
    .map((item) => toText(item?.code || item?.stock_code))
    .filter(isFilledText);
  const previewMeta = previewItems
    .flatMap((item) => [toText(item?.region), toText(item?.industry)])
    .filter(isFilledText);
  const routeKey = canonicalWeaknessSectionKey(section?.key || section?.title || '');
  const titleSource = isFilledText(section?.title) ? section.title : section?.key;

  return {
    section,
    routeKey,
    title: formatWeaknessTitle(titleSource),
    total: Math.max(toInt(section?.total), items.length),
    itemCount: items.length,
    firstCode: toText(items[0]?.code || items[0]?.stock_code),
    firstName: toText(items[0]?.name || items[0]?.stock_name),
    previewNames,
    previewCodes,
    previewMeta,
    regionCount: items.filter((item) => isFilledText(item?.region)).length,
    industryCount: items.filter((item) => isFilledText(item?.industry)).length,
  };
}

function findWeaknessSectionSnapshot(sections, routeKey) {
  const normalized = canonicalWeaknessSectionKey(routeKey);
  if (!normalized) {
    return null;
  }
  const items = Array.isArray(sections) ? sections : [];
  for (const section of items) {
    const snapshot = buildWeaknessSectionSnapshot(section);
    if (
      snapshot.routeKey === normalized ||
      canonicalWeaknessSectionKey(section?.title || '') === normalized
    ) {
      return snapshot;
    }
  }
  return null;
}

function pickWeaknessSectionSnapshot(sections) {
  const routePreference = [
    'today_limit_down',
    'today_broken_board',
    'yesterday_limit_down',
    'yesterday_broken_board',
  ];
  const snapshots = (Array.isArray(sections) ? sections : [])
    .map((section) => buildWeaknessSectionSnapshot(section))
    .filter((section) => section.itemCount > 0 || section.total > 0);
  if (snapshots.length === 0) {
    return null;
  }

  snapshots.sort((left, right) => {
    if (right.previewMeta.length !== left.previewMeta.length) {
      return right.previewMeta.length - left.previewMeta.length;
    }
    if (right.previewNames.length !== left.previewNames.length) {
      return right.previewNames.length - left.previewNames.length;
    }
    const leftRank = routePreference.indexOf(left.routeKey);
    const rightRank = routePreference.indexOf(right.routeKey);
    if (leftRank !== rightRank) {
      return (leftRank < 0 ? 999 : leftRank) - (rightRank < 0 ? 999 : rightRank);
    }
    if (right.total !== left.total) {
      return right.total - left.total;
    }
    return left.routeKey.localeCompare(right.routeKey);
  });

  return snapshots[0];
}

function summarizeWeaknessAssertions(prefix, section) {
  if (!section) {
    return [];
  }
  return [
    { label: `${prefix} route key`, value: section.routeKey },
    { label: `${prefix} title`, value: section.title },
    { label: `${prefix} total`, value: section.total },
    { label: `${prefix} first code`, value: section.firstCode || '--' },
    { label: `${prefix} region-filled items`, value: section.regionCount },
    { label: `${prefix} industry-filled items`, value: section.industryCount },
  ];
}

function uniqueFilledStrings(values) {
  return values
    .map((value) => toText(value))
    .filter(isFilledText)
    .filter((value, index, array) => array.indexOf(value) === index);
}

function pickAuctionSelectionSnapshot(payload) {
  const historyColumns = Array.isArray(payload?.history_columns) ? payload.history_columns : [];
  const firstColumn = historyColumns.find(
    (column) => Array.isArray(column?.items) && column.items.length > 0,
  );
  if (!firstColumn) {
    return null;
  }

  const firstItem = firstColumn.items[0] || {};
  const code = toText(firstItem?.code);
  const name = toText(firstItem?.name) || code;
  if (!isFilledText(code) || !isFilledText(name)) {
    return null;
  }

  const tradeDate =
    toText(firstColumn?.trade_date) || toText(firstColumn?.trade_label) || 'unknown';
  const dayMatches = historyColumns
    .filter(
      (column) =>
        Array.isArray(column?.items) &&
        column.items.some((item) => toText(item?.code) === code),
    )
    .map((column) => toText(column?.trade_label) || toText(column?.trade_date))
    .filter(isFilledText);
  const rankSections = Array.isArray(payload?.rank_sections) ? payload.rank_sections : [];
  const rankMatches = rankSections
    .filter(
      (section) =>
        Array.isArray(section?.items) &&
        section.items.some((item) => toText(item?.code) === code),
    )
    .map((section) => toText(section?.tab_label) || toText(section?.title) || toText(section?.key))
    .filter(isFilledText);

  return {
    code,
    name,
    tradeDate,
    titleText: `${name} (${code})`,
    semanticsLabel: `pw-auction-history-${tradeDate}-${code}`,
    concepts: Array.isArray(firstItem?.concepts)
      ? firstItem.concepts.map((item) => toText(item)).filter(isFilledText)
      : [],
    lianban: toText(firstItem?.lianban),
    dayMatches,
    rankMatches,
  };
}

function plateRotationSelectionFromCell(column, cell) {
  const date = toText(column?.date);
  const plateCode = toText(cell?.plate_code);
  const plateName = toText(cell?.plate_name);
  if (!isFilledText(date) || !isFilledText(plateCode) || !isFilledText(plateName)) {
    return null;
  }
  return {
    plateCode,
    plateName,
    date,
    strengthText: toText(cell?.strength_text),
    semanticsLabel: `pw-plate-rotation-cell-${date}-${plateCode}`,
  };
}

function findPlateRotationDateSummary(payload, selection) {
  const dateSummaries = Array.isArray(payload?.plate_date_summaries)
    ? payload.plate_date_summaries
    : [];
  const selectionCodeKey = normalizePlateCodeKey(selection?.plateCode);
  return dateSummaries.find((summary) => {
    const sameDate = toText(summary?.date) === selection?.date;
    const sameCode =
      selectionCodeKey && normalizePlateCodeKey(summary?.plate_code) === selectionCodeKey;
    const sameName =
      isFilledText(selection?.plateName) && toText(summary?.plate_name) === selection.plateName;
    return sameDate && (sameCode || sameName);
  });
}

function pickPlateRotationSelectionSnapshot(payload, options = {}) {
  const matrixColumns = Array.isArray(payload?.matrix_columns) ? payload.matrix_columns : [];
  const preferLeftColumns = (options.viewportWidth || DEFAULT_VIEWPORT.width) < 1200;
  const orderedColumns = preferLeftColumns ? matrixColumns : [...matrixColumns].reverse();
  const fallbackSelections = [];

  for (const column of orderedColumns) {
    const cells = Array.isArray(column?.items) ? column.items : [];
    for (const cell of cells) {
      const selection = plateRotationSelectionFromCell(column, cell);
      if (!selection) {
        continue;
      }
      fallbackSelections.push(selection);
      const summary = findPlateRotationDateSummary(payload, selection);
      if (toInt(summary?.leader_total) > 0) {
        return selection;
      }
    }
  }
  if (fallbackSelections.length > 0) {
    return fallbackSelections[0];
  }

  const items = Array.isArray(payload?.items) ? payload.items : [];
  for (const item of items) {
    const plateCode = toText(item?.plate_code);
    const plateName = toText(item?.plate_name);
    if (!isFilledText(plateCode) || !isFilledText(plateName)) {
      continue;
    }

    const series = Array.isArray(item?.series) ? item.series : [];
    for (let index = series.length - 1; index >= 0; index -= 1) {
      const point = series[index];
      const date = toText(point?.date);
      const hasData =
        point?.zt_count != null || point?.strength != null || isFilledText(point?.strength_text);
      if (!isFilledText(date) || !hasData) {
        continue;
      }
      return {
        plateCode,
        plateName,
        date,
        strengthText: toText(point?.strength_text),
        semanticsLabel: `pw-plate-rotation-cell-${date}-${plateCode}`,
      };
    }
  }
  return null;
}

function tableColumnsFor(section) {
  const columnDefs = Array.isArray(section?.column_defs) ? section.column_defs : [];
  if (columnDefs.length > 0) {
    return columnDefs.map((column) => ({
      key: toText(column?.key),
      label: toText(column?.label || column?.key),
    }));
  }

  return (Array.isArray(section?.columns) ? section.columns : []).map((column) => ({
    key: toText(column),
    label: toText(column),
  }));
}

function tableRowsFor(section) {
  if (Array.isArray(section?.items) && section.items.length > 0) {
    return section.items.map((item) =>
      Array.isArray(item?.cells) ? item.cells.map((cell) => toText(cell)) : [],
    );
  }
  return (Array.isArray(section?.rows) ? section.rows : []).map((row) =>
    Array.isArray(row) ? row.map((cell) => toText(cell)) : [],
  );
}

function findTableColumnIndex(columns, aliases) {
  const normalizedAliases = new Set(
    Array.from(aliases, (value) => toText(value).toLowerCase()).filter(Boolean),
  );
  return columns.findIndex(
    (column) =>
      normalizedAliases.has(toText(column?.key).toLowerCase()) ||
      normalizedAliases.has(toText(column?.label).toLowerCase()),
  );
}

function formatMarketCenterSectionTitle(value) {
  switch (toText(value).toLowerCase()) {
    case 'zt':
    case 'limit_up':
    case 'limit_up_pool':
      return '\u6da8\u505c\u80a1\u6c60';
    case 'zrzt':
    case 'yesterday_limit_up':
    case 'yesterday_limit_up_pool':
      return '\u6628\u65e5\u6da8\u505c';
    case 'qs':
    case 'trend_up':
    case 'strong_pool':
      return '\u5f3a\u52bf\u80a1\u6c60';
    case 'cx':
    case 'new_high':
    case 'new_listing_pool':
      return '\u6b21\u65b0\u80a1\u6c60';
    case 'zb':
    case 'broken_limit':
    case 'broken_limit_pool':
      return '\u70b8\u677f\u80a1\u6c60';
    case 'dt':
    case 'limit_down':
    case 'limit_down_pool':
      return '\u8dcc\u505c\u80a1\u6c60';
    default:
      return toText(value) || '--';
  }
}

function buildMarketCenterSectionSnapshot(section) {
  const columns = tableColumnsFor(section);
  const rows = tableRowsFor(section);
  const nameIndex = findTableColumnIndex(columns, new Set(['name', 'stock_name', '\u540d\u79f0']));
  const codeIndex = findTableColumnIndex(columns, new Set(['code', 'stock_code', 'symbol', '\u4ee3\u7801']));
  const industryIndex = findTableColumnIndex(
    columns,
    new Set(['industry', 'industry_name', '\u6240\u5c5e\u884c\u4e1a']),
  );
  const reasonIndex = findTableColumnIndex(
    columns,
    new Set(['reason', 'selection_reason', '\u5165\u9009\u7406\u7531', '\u5f02\u52a8\u539f\u56e0']),
  );
  const previewNames = rows
    .filter((row) => nameIndex >= 0 && row.length > nameIndex)
    .slice(0, 5)
    .map((row) => toText(row[nameIndex]))
    .filter(isFilledText);
  const firstRow = rows[0] || [];

  return {
    key: toText(section?.key),
    title: formatMarketCenterSectionTitle(section?.title || section?.key),
    total: Math.max(toInt(section?.total), rows.length),
    rowCount: rows.length,
    columnCount: columns.length,
    previewNames,
    firstName: nameIndex >= 0 ? toText(firstRow[nameIndex]) : '',
    firstCode: codeIndex >= 0 ? toText(firstRow[codeIndex]) : '',
    firstIndustry: industryIndex >= 0 ? toText(firstRow[industryIndex]) : '',
    firstReason: reasonIndex >= 0 ? toText(firstRow[reasonIndex]) : '',
    columnLabels: columns.map((column) => toText(column.label)).filter(isFilledText),
  };
}

function findMarketCenterSectionSnapshot(tables, key) {
  const normalized = toText(key).toLowerCase();
  for (const section of Array.isArray(tables) ? tables : []) {
    const snapshot = buildMarketCenterSectionSnapshot(section);
    if (toText(snapshot.key).toLowerCase() === normalized) {
      return snapshot;
    }
  }
  return null;
}

function summarizeMarketCenterAssertions(prefix, section) {
  if (!section) {
    return [];
  }
  return [
    { label: `${prefix} key`, value: section.key },
    { label: `${prefix} title`, value: section.title },
    { label: `${prefix} total`, value: section.total },
    { label: `${prefix} row count`, value: section.rowCount },
    { label: `${prefix} first name`, value: section.firstName || '--' },
    { label: `${prefix} first code`, value: section.firstCode || '--' },
  ];
}

function buildNewsTabSnapshot(payload, tabName) {
  switch (tabName) {
    case 'hot_news': {
      const items = Array.isArray(payload?.hot_news?.items) ? payload.hot_news.items : [];
      const first = items[0] || {};
      return {
        tabName,
        count: items.length,
        expectedTexts: uniqueFilledStrings([toText(first?.title)]),
        summary: {
          firstTitle: toText(first?.title),
          firstGroup: toText(first?.group),
        },
      };
    }
    case 'today_hot': {
      const items = Array.isArray(payload?.today_hot?.items) ? payload.today_hot.items : [];
      const first = items[0] || {};
      return {
        tabName,
        count: items.length,
        expectedTexts: uniqueFilledStrings([toText(first?.group), toText(first?.title)]),
        summary: {
          firstTitle: toText(first?.title),
          firstGroup: toText(first?.group),
        },
      };
    }
    case 'fast_news': {
      const items = Array.isArray(payload?.fast_news?.items) ? payload.fast_news.items : [];
      const first = items[0] || {};
      return {
        tabName,
        count: items.length,
        expectedTexts: uniqueFilledStrings([toText(first?.title)]),
        summary: {
          firstTitle: toText(first?.title),
          firstGroup: toText(first?.group),
        },
      };
    }
    case 'timeline': {
      const items = Array.isArray(payload?.timeline?.items) ? payload.timeline.items : [];
      const first = items[0] || {};
      return {
        tabName,
        count: items.length,
        expectedTexts: uniqueFilledStrings([toText(first?.group), toText(first?.title)]),
        summary: {
          firstTitle: toText(first?.title),
          firstGroup: toText(first?.group),
        },
      };
    }
    case 'monthly_patterns': {
      const items = Array.isArray(payload?.monthly_patterns) ? payload.monthly_patterns : [];
      const first = items[0] || {};
      return {
        tabName,
        count: items.length,
        expectedTexts: uniqueFilledStrings([
          toText(first?.month),
          toText(first?.driver),
          toText(first?.trend),
        ]),
        summary: {
          firstTitle: toText(first?.driver),
          firstGroup: toText(first?.month),
        },
      };
    }
    default:
      return {
        tabName,
        count: 0,
        expectedTexts: [],
        summary: {
          firstTitle: '',
          firstGroup: '',
        },
      };
  }
}

function summarizeNewsAssertions(prefix, snapshot) {
  if (!snapshot) {
    return [];
  }
  return [
    { label: `${prefix} count`, value: snapshot.count },
    { label: `${prefix} first title`, value: snapshot.summary.firstTitle || '--' },
    { label: `${prefix} first group`, value: snapshot.summary.firstGroup || '--' },
  ];
}

function countStructuredRows(section) {
  if (!section || typeof section !== 'object') {
    return 0;
  }
  if (Array.isArray(section.items) && section.items.length > 0) {
    return section.items.length;
  }
  if (Array.isArray(section.rows) && section.rows.length > 0) {
    return section.rows.length;
  }
  return toInt(section.total);
}

function parseJsonSafely(text) {
  try {
    return JSON.parse(text);
  } catch (error) {
    return null;
  }
}

function shouldCaptureJsonPayload(pageName, url, options = {}) {
  const fragments = dataAssertionFragmentsForPage(pageName, options);
  return fragments.some((fragment) => url.includes(fragment));
}

function findLatestJsonPayload(apiPayloads, fragment) {
  for (let index = apiPayloads.length - 1; index >= 0; index -= 1) {
    const entry = apiPayloads[index];
    if (
      entry.url.includes(fragment) &&
      entry.status >= 200 &&
      entry.status < 400 &&
      entry.json &&
      typeof entry.json === 'object'
    ) {
      return entry;
    }
  }
  return null;
}

function buildDataAssertions(pageName, apiPayloads, options = {}) {
  const assertions = [];
  const failures = [];
  const layoutOnly = isLayoutOnly(options);

  switch (pageName) {
    case 'overview': {
      const overviewPayload = findLatestJsonPayload(apiPayloads, '/api/v1/overview');
      const yesterdayPayload = findLatestJsonPayload(apiPayloads, '/api/v1/yesterday/stats');
      const boardHeightPayload = findLatestJsonPayload(apiPayloads, '/api/v1/board-height');
      const tierPayload = findLatestJsonPayload(apiPayloads, '/api/v1/lianban/tiers');

      if (!overviewPayload) {
        failures.push('missing JSON payload for /api/v1/overview');
      }
      if (!yesterdayPayload) {
        failures.push('missing JSON payload for /api/v1/yesterday/stats');
      }
      if (!boardHeightPayload) {
        failures.push('missing JSON payload for /api/v1/board-height');
      }
      if (!tierPayload) {
        failures.push('missing JSON payload for /api/v1/lianban/tiers');
      }
      if (failures.length > 0) {
        return { assertions, failures };
      }

      const overview = overviewPayload.json;
      const yesterday = yesterdayPayload.json;
      const boardHeight = boardHeightPayload.json;
      const tiersSnapshot = tierPayload.json;
      const indices = Array.isArray(overview?.indices) ? overview.indices : [];
      const sentimentMetrics = Array.isArray(overview?.sentiment?.metrics)
        ? overview.sentiment.metrics
        : [];
      const watchedJobs = Array.isArray(overview?.shell_status?.watched_jobs)
        ? overview.shell_status.watched_jobs
        : [];
      const plateRotationItems = Array.isArray(overview?.plate_rotation?.items)
        ? overview.plate_rotation.items
        : [];
      const breadthTotal =
        toInt(overview?.up_count) + toInt(overview?.flat_count) + toInt(overview?.down_count);
      const weaknessSections = Array.isArray(yesterday?.sections) ? yesterday.sections : [];
      const weaknessItems = weaknessSections.flatMap((section) =>
        Array.isArray(section?.items) ? section.items : [],
      );
      const weaknessRegionCount = weaknessItems.filter((item) => isFilledText(item?.region)).length;
      const weaknessIndustryCount = weaknessItems.filter((item) => isFilledText(item?.industry)).length;
      const boardHeightColumns = Array.isArray(boardHeight?.columns) ? boardHeight.columns : [];
      const tierItems = Array.isArray(tiersSnapshot?.tiers) ? tiersSnapshot.tiers : [];

      assertions.push(
        { label: 'overview indices', value: indices.length },
        { label: 'overview sentiment metrics', value: sentimentMetrics.length },
        { label: 'overview watched jobs', value: watchedJobs.length },
        { label: 'overview plate rotation items', value: plateRotationItems.length },
        { label: 'overview breadth total', value: breadthTotal },
        { label: 'overview weakness sections', value: weaknessSections.length },
        { label: 'overview weakness region-filled items', value: weaknessRegionCount },
        { label: 'overview weakness industry-filled items', value: weaknessIndustryCount },
        { label: 'overview board height columns', value: boardHeightColumns.length },
        { label: 'overview tier groups', value: tierItems.length },
      );

      if (indices.length < 3) {
        failures.push(`overview indices expected >= 3, got ${indices.length}`);
      }
      if (sentimentMetrics.length === 0) {
        failures.push('overview sentiment metrics expected > 0');
      }
      if (watchedJobs.length === 0) {
        failures.push('overview watched jobs expected > 0');
      }
      if (plateRotationItems.length === 0) {
        failures.push('overview plate rotation items expected > 0');
      }
      if (breadthTotal <= 0) {
        failures.push(`overview breadth total expected > 0, got ${breadthTotal}`);
      }
      if (weaknessSections.length === 0) {
        failures.push('overview weakness sections expected > 0');
      }
      if (weaknessRegionCount === 0) {
        failures.push('overview weakness region-filled items expected > 0');
      }
      if (weaknessIndustryCount === 0) {
        failures.push('overview weakness industry-filled items expected > 0');
      }
      if (boardHeightColumns.length === 0) {
        failures.push('overview board height columns expected > 0');
      }
      if (tierItems.length === 0) {
        failures.push('overview tier groups expected > 0');
      }
      return { assertions, failures };
    }
    case 'auction': {
      const payload = findLatestJsonPayload(apiPayloads, '/api/v1/auction/page');
      if (!payload) {
        failures.push('missing JSON payload for /api/v1/auction/page');
        return { assertions, failures };
      }

      const snapshot = payload.json;
      const historyColumns = Array.isArray(snapshot?.history_columns) ? snapshot.history_columns : [];
      const historyRows = historyColumns.reduce(
        (sum, column) => sum + (Array.isArray(column?.items) ? column.items.length : 0),
        0,
      );
      const rankSections = Array.isArray(snapshot?.rank_sections) ? snapshot.rank_sections : [];
      const rankRows = rankSections.reduce(
        (sum, section) => sum + (Array.isArray(section?.items) ? section.items.length : 0),
        0,
      );
      const structuredRankFields = [
        'bid_change_pct',
        'current_change_pct',
        'bid_amount_wan',
        'previous_amount_wan',
        'entrust_amount_yuan',
        'match_amount_yuan',
        'seal_amount_wan',
        'board_count',
        'ratio_pct',
        'volume_ratio',
        'grab_pct',
        'net_amount_wan',
        'float_market_cap_yi',
        'price',
        'concept',
        'yesterday_change_pct',
      ];
      const structuredRankRows = rankSections.reduce((sum, section) => {
        const items = Array.isArray(section?.items) ? section.items : [];
        return (
          sum +
          items.filter((item) =>
            structuredRankFields.some(
              (field) => item && item[field] !== null && item[field] !== undefined && item[field] !== '',
            ),
          ).length
        );
      }, 0);
      const sectionsWithStructuredRows = rankSections.filter((section) => {
        const items = Array.isArray(section?.items) ? section.items : [];
        return items.some((item) =>
          structuredRankFields.some(
            (field) => item && item[field] !== null && item[field] !== undefined && item[field] !== '',
          ),
        );
      }).length;

      assertions.push(
        { label: 'auction history columns', value: historyColumns.length },
        { label: 'auction history rows', value: historyRows },
        { label: 'auction rank sections', value: rankSections.length },
        { label: 'auction rank rows', value: rankRows },
        { label: 'auction structured rank sections', value: sectionsWithStructuredRows },
        { label: 'auction structured rank rows', value: structuredRankRows },
      );

      if (historyColumns.length === 0) {
        failures.push('auction history columns expected > 0');
      }
      if (historyRows === 0) {
        failures.push('auction history rows expected > 0');
      }
      if (rankSections.length === 0) {
        failures.push('auction rank sections expected > 0');
      }
      if (rankRows === 0) {
        failures.push('auction rank rows expected > 0');
      }
      if (structuredRankRows === 0) {
        failures.push('auction structured rank rows expected > 0');
      }
      return { assertions, failures };
    }
    case 'node': {
      const snapshotPayload = findLatestJsonPayload(apiPayloads, '/api/v1/node/snapshot');
      const leadersPayload = findLatestJsonPayload(apiPayloads, '/api/v1/node/plates/');
      if (!snapshotPayload) {
        failures.push('missing JSON payload for /api/v1/node/snapshot');
      }
      if (!layoutOnly && !leadersPayload) {
        failures.push('missing JSON payload for /api/v1/node/plates/');
      }
      if (failures.length > 0) {
        return { assertions, failures };
      }

      const snapshot = snapshotPayload.json;
      const leaders = leadersPayload?.json;
      const bars = Array.isArray(snapshot?.kline?.bars) ? snapshot.kline.bars : [];
      const dateItems = Array.isArray(snapshot?.date_items) ? snapshot.date_items : [];
      const leaderItems = Array.isArray(leaders?.leaders) ? leaders.leaders : [];
      const nonEmptyTopPlates = dateItems.filter(
        (item) => Array.isArray(item?.top_plates) && item.top_plates.length > 0,
      ).length;

      assertions.push(
        { label: 'node kline bars', value: bars.length },
        { label: 'node date items', value: dateItems.length },
        { label: 'node non-empty top plates', value: nonEmptyTopPlates },
        ...(layoutOnly
          ? []
          : [
              { label: 'node leaders', value: leaderItems.length },
              { label: 'node leader total', value: toInt(leaders?.total) },
            ]),
      );

      if (bars.length === 0) {
        failures.push('node kline bars expected > 0');
      }
      if (dateItems.length === 0) {
        failures.push('node date items expected > 0');
      }
      if (`${snapshot?.quote?.name ?? ''}`.trim().length === 0) {
        failures.push('node quote name expected to be non-empty');
      }
      if (`${snapshot?.helper_text ?? ''}`.trim().length === 0) {
        failures.push('node helper text expected to be non-empty');
      }
      if (!layoutOnly && `${leaders?.plate_name ?? ''}`.trim().length === 0) {
        failures.push('node leaders plate name expected to be non-empty');
      }
      if (!layoutOnly && toInt(leaders?.total) < leaderItems.length) {
        failures.push(
          `node leader total expected >= leaders length, got total ${toInt(leaders?.total)} and ${leaderItems.length} leaders`,
        );
      }
      return { assertions, failures };
    }
    case 'market_center': {
      const payload = findLatestJsonPayload(apiPayloads, '/api/v1/market-center-page');
      if (!payload) {
        failures.push('missing JSON payload for /api/v1/market-center-page');
        return { assertions, failures };
      }

      const snapshot = payload.json.market_center || payload.json;
      const tables = Array.isArray(snapshot?.tables) ? snapshot.tables : [];
      const totalRows = tables.reduce((sum, table) => sum + countStructuredRows(table), 0);
      const activeSections = tables.filter((table) => countStructuredRows(table) > 0).length;

      assertions.push(
        { label: 'market center tables', value: tables.length },
        { label: 'market center active sections', value: activeSections },
        { label: 'market center total rows', value: totalRows },
      );

      if (tables.length < 6) {
        failures.push(`market center tables expected >= 6, got ${tables.length}`);
      }
      if (activeSections < 3) {
        failures.push(`market center active sections expected >= 3, got ${activeSections}`);
      }
      if (totalRows < 30) {
        failures.push(`market center total rows expected >= 30, got ${totalRows}`);
      }
      return { assertions, failures };
    }
    case 'yesterday': {
      const payload = findLatestJsonPayload(apiPayloads, '/api/v1/yesterday/stats');
      if (!payload) {
        failures.push('missing JSON payload for /api/v1/yesterday/stats');
        return { assertions, failures };
      }

      const snapshot = payload.json;
      const sections = Array.isArray(snapshot?.sections) ? snapshot.sections : [];
      const nonEmptySections = sections.filter((section) => countStructuredRows(section) > 0).length;
      const items = sections.flatMap((section) =>
        Array.isArray(section.items) ? section.items : [],
      );
      const regionCount = items.filter((item) => `${item?.region ?? ''}`.trim()).length;
      const industryCount = items.filter((item) => `${item?.industry ?? ''}`.trim()).length;

      assertions.push(
        { label: 'yesterday sections', value: sections.length },
        { label: 'yesterday non-empty sections', value: nonEmptySections },
        { label: 'yesterday items', value: items.length },
        { label: 'yesterday region-filled items', value: regionCount },
        { label: 'yesterday industry-filled items', value: industryCount },
      );

      if (sections.length < 4) {
        failures.push(`yesterday sections expected >= 4, got ${sections.length}`);
      }
      if (nonEmptySections < 2) {
        failures.push(`yesterday non-empty sections expected >= 2, got ${nonEmptySections}`);
      }
      if (items.length < 4) {
        failures.push(`yesterday items expected >= 4, got ${items.length}`);
      }
      if (regionCount === 0) {
        failures.push('yesterday region-filled items expected > 0');
      }
      if (industryCount === 0) {
        failures.push('yesterday industry-filled items expected > 0');
      }
      return { assertions, failures };
    }
    case 'board_tier': {
      const payload = findLatestJsonPayload(apiPayloads, '/api/v1/lianban/tiers');
      if (!payload) {
        failures.push('missing JSON payload for /api/v1/lianban/tiers');
        return { assertions, failures };
      }

      const snapshot = payload.json;
      const tiers = Array.isArray(snapshot?.tiers) ? snapshot.tiers : [];
      const nonEmptyTiers = tiers.filter(
        (tier) => Array.isArray(tier?.stocks) && tier.stocks.length > 0,
      ).length;
      const stockCount = tiers.reduce(
        (sum, tier) => sum + (Array.isArray(tier?.stocks) ? tier.stocks.length : 0),
        0,
      );
      const maxBoardCount = tiers.reduce(
        (maxValue, tier) => Math.max(maxValue, toInt(tier?.board_count)),
        0,
      );

      assertions.push(
        { label: 'board tier groups', value: tiers.length },
        { label: 'board tier non-empty groups', value: nonEmptyTiers },
        { label: 'board tier stocks', value: stockCount },
        { label: 'board tier max board count', value: maxBoardCount },
      );

      if (tiers.length === 0) {
        failures.push('board tier groups expected > 0');
      }
      if (nonEmptyTiers === 0) {
        failures.push('board tier non-empty groups expected > 0');
      }
      if (stockCount === 0) {
        failures.push('board tier stocks expected > 0');
      }
      if (maxBoardCount <= 0) {
        failures.push(`board tier max board count expected > 0, got ${maxBoardCount}`);
      }
      return { assertions, failures };
    }
    case 'board_height': {
      const payload = findLatestJsonPayload(apiPayloads, '/api/v1/board-height');
      if (!payload) {
        failures.push('missing JSON payload for /api/v1/board-height');
        return { assertions, failures };
      }

      const snapshot = payload.json;
      const availableTradeDates = Array.isArray(snapshot?.available_trade_dates)
        ? snapshot.available_trade_dates
        : [];
      const chartItems = Array.isArray(snapshot?.chart_items) ? snapshot.chart_items : [];
      const columns = Array.isArray(snapshot?.columns) ? snapshot.columns : [];
      const leaderStocks = columns.reduce(
        (sum, column) => sum + (Array.isArray(column?.stocks) ? column.stocks.length : 0),
        0,
      );
      const latestHeight = toInt(snapshot?.latest_height);

      assertions.push(
        { label: 'board height trade dates', value: availableTradeDates.length },
        { label: 'board height chart items', value: chartItems.length },
        { label: 'board height columns', value: columns.length },
        { label: 'board height leader stocks', value: leaderStocks },
        { label: 'board height latest height', value: latestHeight },
      );

      if (availableTradeDates.length === 0) {
        failures.push('board height trade dates expected > 0');
      }
      if (chartItems.length === 0) {
        failures.push('board height chart items expected > 0');
      }
      if (columns.length === 0) {
        failures.push('board height columns expected > 0');
      }
      if (leaderStocks === 0) {
        failures.push('board height leader stocks expected > 0');
      }
      if (latestHeight <= 0) {
        failures.push(`board height latest height expected > 0, got ${latestHeight}`);
      }
      return { assertions, failures };
    }
    case 'limit_review': {
      const payload = findLatestJsonPayload(apiPayloads, '/api/v1/review-page');
      if (!payload) {
        failures.push('missing JSON payload for /api/v1/review-page');
        return { assertions, failures };
      }

      const snapshot = payload.json || {};
      const review = snapshot.limit_review || snapshot;
      const navigation = snapshot.navigation || {};
      const groups = Array.isArray(review?.groups) ? review.groups : [];
      const nonEmptyGroups = groups.filter((group) => countStructuredRows(group) > 0).length;
      const totalStocks = toInt(review?.total_stocks);
      const maxBoardHeight = toInt(review?.max_board_height);
      const weaknessSections = Array.isArray(snapshot?.yesterday_stats?.sections)
        ? snapshot.yesterday_stats.sections
        : [];
      const weaknessItems = weaknessSections.flatMap((section) =>
        Array.isArray(section?.items) ? section.items : [],
      );
      const weaknessRegionCount = weaknessItems.filter((item) => isFilledText(item?.region)).length;
      const weaknessIndustryCount = weaknessItems.filter((item) => isFilledText(item?.industry)).length;
      const boardHeightColumns = Array.isArray(snapshot?.board_height?.columns)
        ? snapshot.board_height.columns
        : [];

      assertions.push(
        { label: 'limit review groups', value: groups.length },
        { label: 'limit review non-empty groups', value: nonEmptyGroups },
        { label: 'limit review total stocks', value: totalStocks },
        { label: 'limit review max board height', value: maxBoardHeight },
        { label: 'limit review weakness sections', value: weaknessSections.length },
        { label: 'limit review weakness region-filled items', value: weaknessRegionCount },
        { label: 'limit review weakness industry-filled items', value: weaknessIndustryCount },
        { label: 'limit review board height columns', value: boardHeightColumns.length },
        {
          label: 'limit review resolved trade date',
          value: toText(navigation?.resolved_trade_date) || '--',
        },
      );

      if (groups.length === 0) {
        failures.push('limit review groups expected > 0');
      }
      if (nonEmptyGroups === 0) {
        failures.push('limit review non-empty groups expected > 0');
      }
      if (totalStocks <= 0) {
        failures.push(`limit review total stocks expected > 0, got ${totalStocks}`);
      }
      if (maxBoardHeight <= 0) {
        failures.push(`limit review max board height expected > 0, got ${maxBoardHeight}`);
      }
      if (weaknessSections.length < 4) {
        failures.push(`limit review weakness sections expected >= 4, got ${weaknessSections.length}`);
      }
      if (weaknessRegionCount === 0) {
        failures.push('limit review weakness region-filled items expected > 0');
      }
      if (weaknessIndustryCount === 0) {
        failures.push('limit review weakness industry-filled items expected > 0');
      }
      if (boardHeightColumns.length === 0) {
        failures.push('limit review board height columns expected > 0');
      }
      if (!isFilledText(navigation?.resolved_trade_date)) {
        failures.push('limit review resolved trade date expected to be non-empty');
      }
      return { assertions, failures };
    }
    case 'plate_rotation': {
      const rotationPayload = findLatestJsonPayload(apiPayloads, '/api/v1/plate-rotation');
      const stocksPayload = findLatestJsonPayload(apiPayloads, '/api/v1/plates/');
      const leadersPayload = findLatestJsonPayload(apiPayloads, '/api/v1/node/plates/');
      if (!rotationPayload) {
        failures.push('missing JSON payload for /api/v1/plate-rotation');
      }
      if (!stocksPayload) {
        failures.push('missing JSON payload for /api/v1/plates/');
      }
      if (!leadersPayload) {
        failures.push('missing JSON payload for /api/v1/node/plates/');
      }
      if (failures.length > 0) {
        return { assertions, failures };
      }

      const rotation = rotationPayload.json;
      const stocks = stocksPayload.json;
      const leaders = leadersPayload.json;
      const items = Array.isArray(rotation?.items) ? rotation.items : [];
      const matrixColumns = Array.isArray(rotation?.matrix_columns) ? rotation.matrix_columns : [];
      const dateSummaries = Array.isArray(rotation?.plate_date_summaries)
        ? rotation.plate_date_summaries
        : [];
      const matrixItems = matrixColumns.flatMap((column) =>
        Array.isArray(column?.items) ? column.items : [],
      );
      const summaryWithLeader = dateSummaries.find((item) => toInt(item?.leader_total) > 0);
      const sampleSeriesCount =
        items.length > 0 && Array.isArray(items[0]?.series) ? items[0].series.length : 0;
      const stockItems = Array.isArray(stocks?.items) ? stocks.items : [];
      const stockDates = Array.isArray(stocks?.dates) ? stocks.dates : [];
      const leaderItems = Array.isArray(leaders?.leaders) ? leaders.leaders : [];

      assertions.push(
        { label: 'plate rotation dates', value: Array.isArray(rotation?.dates) ? rotation.dates.length : 0 },
        {
          label: 'plate rotation available trade dates',
          value: Array.isArray(rotation?.available_trade_dates) ? rotation.available_trade_dates.length : 0,
        },
        { label: 'plate rotation items', value: items.length },
        { label: 'plate rotation matrix columns', value: matrixColumns.length },
        { label: 'plate rotation matrix items', value: matrixItems.length },
        { label: 'plate rotation date summaries', value: dateSummaries.length },
        {
          label: 'plate rotation date summaries with leaders',
          value: dateSummaries.filter((item) => toInt(item?.leader_total) > 0).length,
        },
        { label: 'plate rotation sample series', value: sampleSeriesCount },
        { label: 'plate rotation stock items', value: stockItems.length },
        { label: 'plate rotation stock dates', value: stockDates.length },
        { label: 'plate rotation leaders', value: leaderItems.length },
      );

      if (!Array.isArray(rotation?.dates) || rotation.dates.length === 0) {
        failures.push('plate rotation dates expected > 0');
      }
      if (items.length === 0) {
        failures.push('plate rotation items expected > 0');
      }
      if (matrixColumns.length === 0) {
        failures.push('plate rotation matrix columns expected > 0');
      }
      if (matrixItems.length === 0) {
        failures.push('plate rotation matrix items expected > 0');
      }
      if (dateSummaries.length === 0) {
        failures.push('plate rotation plate_date_summaries expected > 0');
      }
      if (matrixColumns.length > 0 && matrixItems.length > 0 && dateSummaries.length > 0) {
        const firstColumn = matrixColumns.find(
          (column) => Array.isArray(column?.items) && column.items.length > 0,
        );
        const firstCell = firstColumn?.items?.[0];
        const firstCellCodeKey = normalizePlateCodeKey(firstCell?.plate_code);
        const hasMatchingSummary = dateSummaries.some((summary) => {
          const sameDate = toText(summary?.date) === toText(firstColumn?.date);
          const sameCode =
            firstCellCodeKey &&
            normalizePlateCodeKey(summary?.plate_code) === firstCellCodeKey;
          const sameName =
            isFilledText(firstCell?.plate_name) &&
            toText(summary?.plate_name) === toText(firstCell?.plate_name);
          return sameDate && (sameCode || sameName);
        });
        if (!hasMatchingSummary) {
          failures.push('plate rotation matrix first cell expected matching plate_date_summaries item');
        }
      }
      if (
        summaryWithLeader &&
        (!Array.isArray(summaryWithLeader?.leaders_preview) ||
          summaryWithLeader.leaders_preview.length === 0)
      ) {
        failures.push('plate rotation leader summary expected leaders_preview when leader_total > 0');
      }
      if (sampleSeriesCount === 0) {
        failures.push('plate rotation sample series expected > 0');
      }
      if (stockItems.length === 0) {
        failures.push('plate rotation stock items expected > 0');
      }
      if (stockDates.length === 0) {
        failures.push('plate rotation stock dates expected > 0');
      }
      if (`${stocks?.plate_name ?? ''}`.trim().length === 0) {
        failures.push('plate rotation stock plate name expected to be non-empty');
      }
      if (`${leaders?.plate_name ?? ''}`.trim().length === 0) {
        failures.push('plate rotation leaders plate name expected to be non-empty');
      }
      if (toInt(rotation?.total) < items.length) {
        failures.push(
          `plate rotation total expected >= items length, got total ${toInt(rotation?.total)} and ${items.length} items`,
        );
      }
      return { assertions, failures };
    }
    case 'news': {
      const payload = findLatestJsonPayload(apiPayloads, '/api/v1/news/page');
      if (!payload) {
        failures.push('missing JSON payload for /api/v1/news/page');
        return { assertions, failures };
      }

      const snapshot = payload.json;
      const hotItems = Array.isArray(snapshot?.hot_news?.items) ? snapshot.hot_news.items : [];
      const todayHotItems = Array.isArray(snapshot?.today_hot?.items)
        ? snapshot.today_hot.items
        : [];
      const fastItems = Array.isArray(snapshot?.fast_news?.items) ? snapshot.fast_news.items : [];
      const timelineItems = Array.isArray(snapshot?.timeline?.items)
        ? snapshot.timeline.items
        : [];
      const monthlyPatterns = Array.isArray(snapshot?.monthly_patterns)
        ? snapshot.monthly_patterns
        : [];

      assertions.push(
        { label: 'news hot items', value: hotItems.length },
        { label: 'news today hot items', value: todayHotItems.length },
        { label: 'news fast items', value: fastItems.length },
        { label: 'news timeline items', value: timelineItems.length },
        { label: 'news monthly patterns', value: monthlyPatterns.length },
      );

      if (hotItems.length === 0) {
        failures.push('news hot items expected > 0');
      }
      if (todayHotItems.length === 0) {
        failures.push('news today hot items expected > 0');
      }
      if (fastItems.length === 0) {
        failures.push('news fast items expected > 0');
      }
      if (timelineItems.length === 0) {
        failures.push('news timeline items expected > 0');
      }
      if (monthlyPatterns.length === 0) {
        failures.push('news monthly patterns expected > 0');
      }
      return { assertions, failures };
    }
    case 'ask_ai': {
      const contextPayload = findLatestJsonPayload(apiPayloads, '/api/v1/ask-ai/context');
      const sessionsPayload = findLatestJsonPayload(apiPayloads, '/api/v1/ask-ai/sessions');
      const historyPayload = findLatestJsonPayload(apiPayloads, '/api/v1/ask-ai/history');
      if (!contextPayload) {
        failures.push('missing JSON payload for /api/v1/ask-ai/context');
      }
      if (!sessionsPayload) {
        failures.push('missing JSON payload for /api/v1/ask-ai/sessions');
      }
      if (failures.length > 0) {
        return { assertions, failures };
      }

      const context = contextPayload.json;
      const sessions = sessionsPayload.json;
      const history = historyPayload?.json;
      const cards = Array.isArray(context?.cards) ? context.cards : [];
      const promptSections = Array.isArray(context?.prompt_sections) ? context.prompt_sections : [];
      const sessionItems = Array.isArray(sessions?.items) ? sessions.items : [];
      const historyItems = Array.isArray(history?.items) ? history.items : [];

      assertions.push(
        { label: 'ask ai cards', value: cards.length },
        { label: 'ask ai prompt sections', value: promptSections.length },
        { label: 'ask ai system prompt length', value: `${context?.system_prompt ?? ''}`.length },
        { label: 'ask ai user prompt length', value: `${context?.user_prompt ?? ''}`.length },
        { label: 'ask ai sessions', value: sessionItems.length },
        { label: 'ask ai history', value: historyItems.length },
      );

      if (cards.length === 0) {
        failures.push('ask ai cards expected > 0');
      }
      if (promptSections.length === 0) {
        failures.push('ask ai prompt sections expected > 0');
      }
      if (`${context?.system_prompt ?? ''}`.trim().length === 0) {
        failures.push('ask ai system prompt expected to be non-empty');
      }
      if (`${context?.user_prompt ?? ''}`.trim().length === 0) {
        failures.push('ask ai user prompt expected to be non-empty');
      }
      if (!Array.isArray(sessions?.items)) {
        failures.push('ask ai sessions items expected to be an array');
      }
      if (historyPayload && !Array.isArray(history?.items)) {
        failures.push('ask ai history items expected to be an array when requested');
      }
      return { assertions, failures };
    }
    case 'jobs': {
      const payload = findLatestJsonPayload(apiPayloads, '/internal/jobs/page');
      if (!payload) {
        failures.push('missing JSON payload for /internal/jobs/page');
        return { assertions, failures };
      }

      const snapshot = payload.json;
      const services = Array.isArray(snapshot?.services) ? snapshot.services : [];
      const jobs = Array.isArray(snapshot?.jobs) ? snapshot.jobs : [];
      const recentRuns = Array.isArray(snapshot?.recent_runs) ? snapshot.recent_runs : [];
      const failuresList = Array.isArray(snapshot?.failures) ? snapshot.failures : [];
      const notices = Array.isArray(snapshot?.notices) ? snapshot.notices : [];
      const runningServices = services.filter((service) => service?.running).length;
      const readyServices = services.filter((service) => service?.ready).length;
      const requiredExistsCount = services.filter((service) => service?.required_exists).length;
      const triggerableJobs = jobs.filter((job) => job?.trigger_allowed).length;
      const blockedJobs = jobs.filter((job) => job && job.trigger_allowed === false).length;

      assertions.push(
        { label: 'jobs services', value: services.length },
        { label: 'jobs running services', value: runningServices },
        { label: 'jobs ready services', value: readyServices },
        { label: 'jobs required paths', value: requiredExistsCount },
        { label: 'jobs total jobs', value: jobs.length },
        { label: 'jobs recent runs', value: recentRuns.length },
        { label: 'jobs failures', value: failuresList.length },
        { label: 'jobs notices', value: notices.length },
        { label: 'jobs triggerable jobs', value: triggerableJobs },
        { label: 'jobs blocked trigger jobs', value: blockedJobs },
      );

      if (services.length === 0) {
        failures.push('jobs services expected > 0');
      }
      if (jobs.length === 0) {
        failures.push('jobs total jobs expected > 0');
      }
      if (toInt(snapshot?.summary?.total_services) !== services.length) {
        failures.push(
          `jobs summary total_services expected ${services.length}, got ${toInt(snapshot?.summary?.total_services)}`,
        );
      }
      if (toInt(snapshot?.summary?.total_jobs) !== jobs.length) {
        failures.push(
          `jobs summary total_jobs expected ${jobs.length}, got ${toInt(snapshot?.summary?.total_jobs)}`,
        );
      }
      if (!Object.prototype.hasOwnProperty.call(snapshot?.summary || {}, 'queued_jobs')) {
        failures.push('jobs summary queued_jobs expected to be present');
      }
      if (requiredExistsCount !== services.length) {
        failures.push(
          `jobs required paths expected ${services.length}, got ${requiredExistsCount}`,
        );
      }
      if (!snapshot?.startup_task || typeof snapshot.startup_task !== 'object') {
        failures.push('jobs startup task expected to be present');
      }
      if (!Array.isArray(snapshot?.recent_runs)) {
        failures.push('jobs recent_runs expected to be an array');
      }
      if (!Array.isArray(snapshot?.failures)) {
        failures.push('jobs failures expected to be an array');
      }
      if (!Array.isArray(snapshot?.notices)) {
        failures.push('jobs notices expected to be an array');
      }
      if (jobs.some((job) => typeof job?.trigger_allowed !== 'boolean')) {
        failures.push('jobs trigger_allowed expected on every returned job');
      }
      if (jobs.some((job) => !Number.isFinite(Number(job?.last_duration_ms ?? 0)))) {
        failures.push('jobs last_duration_ms expected numeric on every returned job');
      }
      if (recentRuns.some((run) => !run?.run_id || !run?.job_code || !run?.status)) {
        failures.push('jobs recent_runs expected run_id, job_code, and status');
      }
      return { assertions, failures };
    }
    default:
      return { assertions, failures };
  }
}

async function buildDesignAssertions(page, pageName, pageText, expectedText) {
  const assertions = [];
  const failures = [];
  const genericDesktopMarkers = [
    '\u603b\u89c8',
    '\u725b\u725b',
    '\u4efb\u52a1',
    '\u72b6\u6001',
    '\u5237\u65b0',
    '\u5feb\u7167',
    '\u4ea4\u6613\u65e5',
    '\u670d\u52a1',
    '\u8fde\u677f',
    '\u677f\u5757',
    '\u63d0\u793a\u8bcd',
    '\u9f99\u5934',
    '\u884c\u60c5',
  ];
  const desktopMarkers = Array.from(
    new Set([...expectedText, ...genericDesktopMarkers].map(normalizeForMatch).filter(Boolean)),
  );

  const addAssertion = (label, ok, details) => {
    const assertion = { label, ok, details };
    assertions.push(assertion);
    if (!ok) {
      failures.push(`${label}: ${details}`);
    }
  };

  addAssertion(
    'design: frontend-skill app workspace contract is declared',
    true,
    FRONTEND_SKILL_APP_DESIGN_CONTRACT.join(' | '),
  );

  try {
    const metrics = await page.evaluate((markers) => {
      const normalize = (value) => `${value || ''}`.replace(/\s+/g, ' ').trim();
      const root = document.documentElement;
      const body = document.body;
      const viewportWidth = window.innerWidth || root?.clientWidth || 0;
      const viewportHeight = window.innerHeight || root?.clientHeight || 0;
      const rootScrollWidth = root?.scrollWidth || 0;
      const bodyScrollWidth = body?.scrollWidth || 0;
      const documentScrollWidth = Math.max(
        viewportWidth,
        rootScrollWidth,
        bodyScrollWidth,
        root?.clientWidth || 0,
        body?.clientWidth || 0,
      );
      const visualElementRights = Array.from(document.querySelectorAll('*'))
        .filter((element) => {
          if (!(element instanceof Element)) {
            return false;
          }
          if (element.closest('flt-semantics, flt-semantics-host')) {
            return false;
          }
          const tagName = element.tagName.toLowerCase();
          if (tagName.startsWith('flt-semantics')) {
            return false;
          }
          const style = window.getComputedStyle(element);
          if (!style || style.display === 'none' || style.visibility === 'hidden') {
            return false;
          }
          const rect = element.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0;
        })
        .map((element) => element.getBoundingClientRect().right)
        .filter((value) => Number.isFinite(value));
      const visualDocumentScrollWidth = Math.max(viewportWidth, ...visualElementRights);
      const viewportArea = Math.max(1, viewportWidth * viewportHeight);
      const entries = [];
      const seen = new Set();
      const maxEntries = 220;

      const toRect = (rect) => ({
        left: Number(rect.left.toFixed(1)),
        top: Number(rect.top.toFixed(1)),
        right: Number(rect.right.toFixed(1)),
        bottom: Number(rect.bottom.toFixed(1)),
        width: Number(rect.width.toFixed(1)),
        height: Number(rect.height.toFixed(1)),
      });

      const isElementStyleVisible = (element) => {
        if (!element || !(element instanceof Element)) {
          return false;
        }
        if (element.closest('[hidden], [aria-hidden="true"]')) {
          return false;
        }
        const style = window.getComputedStyle(element);
        if (!style || style.display === 'none' || style.visibility === 'hidden') {
          return false;
        }
        const opacity = Number.parseFloat(style.opacity);
        return !Number.isFinite(opacity) || opacity > 0.01;
      };

      const isRectInViewport = (rect) =>
        rect.width > 2 &&
        rect.height > 2 &&
        rect.right > 0 &&
        rect.bottom > 0 &&
        rect.left < viewportWidth &&
        rect.top < viewportHeight;

      const addEntry = (element, rawText, rawRect, source) => {
        if (entries.length >= maxEntries || !rawRect || !isRectInViewport(rawRect)) {
          return;
        }
        const text = normalize(rawText).slice(0, 180);
        if (text.length < 2) {
          return;
        }
        const rect = toRect(rawRect);
        const key = [
          Math.round(rect.left),
          Math.round(rect.top),
          Math.round(rect.width),
          Math.round(rect.height),
          source,
          text.slice(0, 80),
        ].join('|');
        if (seen.has(key)) {
          return;
        }
        seen.add(key);
        const isSemantics =
          text.startsWith('pw-') ||
          Boolean(element?.closest?.('flt-semantics, flt-semantics-host'));
        entries.push({ element, text, rect, source, isSemantics });
      };

      const elementSelectors = [
        'flt-semantics',
        '[aria-label]',
        'button',
        'a',
        'input',
        'textarea',
        'select',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        '[role]',
      ].join(',');

      Array.from(document.querySelectorAll(elementSelectors)).forEach((element) => {
        if (!isElementStyleVisible(element)) {
          return;
        }
        const formValue = 'value' in element ? element.value : '';
        const text = normalize(
          element.getAttribute('aria-label') ||
            formValue ||
            element.getAttribute('placeholder') ||
            element.innerText ||
            element.textContent ||
            element.getAttribute('title') ||
            '',
        );
        if (text.length < 2) {
          return;
        }
        const rects = Array.from(element.getClientRects()).filter(isRectInViewport);
        const rect = rects[0] || element.getBoundingClientRect();
        addEntry(element, text, rect, 'element');
      });

      if (body) {
        const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT, {
          acceptNode(node) {
            const text = normalize(node.nodeValue || '');
            const parent = node.parentElement;
            if (
              text.length < 2 ||
              !parent ||
              parent.closest('script, style, noscript, template') ||
              !isElementStyleVisible(parent)
            ) {
              return NodeFilter.FILTER_REJECT;
            }
            return NodeFilter.FILTER_ACCEPT;
          },
        });

        let node = walker.nextNode();
        let guard = 0;
        while (node && guard < 600 && entries.length < maxEntries) {
          const parent = node.parentElement;
          const range = document.createRange();
          range.selectNodeContents(node);
          Array.from(range.getClientRects()).forEach((rect) => {
            addEntry(parent, node.nodeValue || '', rect, 'text-node');
          });
          if (typeof range.detach === 'function') {
            range.detach();
          }
          node = walker.nextNode();
          guard += 1;
        }
      }

      // Design intent: Flutter web exposes large accessibility semantics
      // overlays that are not painted text. They are useful for density and
      // interaction assertions, but visual-overlap checks must ignore them.
      const compareEntries = entries
        .filter((entry) => !entry.isSemantics)
        .slice(0, 160);
      const overlapFailures = [];
      const rectArea = (rect) => Math.max(0, rect.width) * Math.max(0, rect.height);
      const intersection = (first, second) => {
        const width = Math.max(0, Math.min(first.right, second.right) - Math.max(first.left, second.left));
        const height = Math.max(0, Math.min(first.bottom, second.bottom) - Math.max(first.top, second.top));
        return { width, height, area: width * height };
      };
      const sameBounds = (first, second) =>
        Math.abs(first.left - second.left) <= 2 &&
        Math.abs(first.top - second.top) <= 2 &&
        Math.abs(first.width - second.width) <= 2 &&
        Math.abs(first.height - second.height) <= 2;

      outer: for (let firstIndex = 0; firstIndex < compareEntries.length; firstIndex += 1) {
        for (let secondIndex = firstIndex + 1; secondIndex < compareEntries.length; secondIndex += 1) {
          const first = compareEntries[firstIndex];
          const second = compareEntries[secondIndex];
          if (
            first.element === second.element ||
            first.element.contains(second.element) ||
            second.element.contains(first.element) ||
            first.text === second.text
          ) {
            continue;
          }
          const firstArea = rectArea(first.rect);
          const secondArea = rectArea(second.rect);
          if (
            (firstArea > viewportArea * 0.5 && first.text.length > 40) ||
            (secondArea > viewportArea * 0.5 && second.text.length > 40)
          ) {
            continue;
          }
          if (
            sameBounds(first.rect, second.rect) &&
            (first.text.includes(second.text) || second.text.includes(first.text))
          ) {
            continue;
          }
          const overlap = intersection(first.rect, second.rect);
          const minArea = Math.min(firstArea, secondArea);
          if (overlap.area > minArea * 0.95 && Math.max(firstArea, secondArea) > minArea * 2.5) {
            continue;
          }
          if (overlap.area <= Math.max(120, minArea * 0.42)) {
            continue;
          }
          if (
            overlap.width < Math.min(first.rect.width, second.rect.width) * 0.45 ||
            overlap.height < Math.min(first.rect.height, second.rect.height) * 0.55
          ) {
            continue;
          }
          overlapFailures.push(
            `${first.text.slice(0, 40)} <> ${second.text.slice(0, 40)} @ ${Math.round(overlap.area)}px2`,
          );
          if (overlapFailures.length >= 5) {
            break outer;
          }
        }
      }

      const uniqueVisibleTexts = Array.from(new Set(entries.map((entry) => entry.text))).filter(Boolean);
      const visibleViewportText = normalize(uniqueVisibleTexts.join(' '));
      const markerMatches = (Array.isArray(markers) ? markers : [])
        .map(normalize)
        .filter((marker) => marker && visibleViewportText.includes(marker))
        .slice(0, 8);
      const interactiveElements = Array.from(
        document.querySelectorAll(
          'flt-semantics[role="button"], flt-semantics[role="tab"], button, a, [role="button"], [role="tab"]',
        ),
      )
        .filter(isElementStyleVisible)
        .map((element) => {
          const rect = element.getBoundingClientRect();
          const labelForElement = (target) =>
            normalize(
              target.getAttribute('aria-label') ||
                target.getAttribute('title') ||
                target.innerText ||
                target.textContent ||
                '',
            );
          const label = labelForElement(element);
          const hasLabeledControlAncestor = (() => {
            let parent = element.parentElement;
            while (parent && parent !== document.body) {
              if (
                parent.matches(
                  'flt-semantics[role="button"], flt-semantics[role="tab"], button, a, [role="button"], [role="tab"]',
                )
              ) {
                const parentRect = parent.getBoundingClientRect();
                const parentLabel = labelForElement(parent);
                if (
                  parentLabel.length >= 2 &&
                  isRectInViewport(parentRect) &&
                  parentRect.width >= 28 &&
                  parentRect.height >= 24
                ) {
                  return true;
                }
              }
              parent = parent.parentElement;
            }
            return false;
          })();
          const tagName = element.tagName.toLowerCase();
          const role = element.getAttribute('role') || '';
          const isFlutterSemantics =
            tagName.startsWith('flt-semantics') ||
            Boolean(element.closest('flt-semantics, flt-semantics-host'));
          const actionControlPattern =
            /(?:打开|刷新|导出|复制|设置|反馈|关于|停止|消息|任务|维护|限流|更新|日历|筛选|清空|搜索|测试|联动|保存|关闭|恢复|生成|重试|进入|查看|Later|Earlier|Latest|Open|Refresh|Export|Copy|Settings|Jobs|AI)/i;
          const isInternalTestHook = label.startsWith('pw-');
          const isExplicitActionHook =
            /(?:-open-|frontend-build|tab-|refresh|export|copy|jobs)/i.test(label);
          const requiresFullHitTarget =
            !isFlutterSemantics ||
            role === 'tab' ||
            actionControlPattern.test(label) ||
            isExplicitActionHook;
          return {
            label,
            tagName,
            role,
            isFlutterSemantics,
            requiresFullHitTarget,
            hasLabeledControlAncestor,
            rect: toRect(rect),
            disabled:
              element.hasAttribute('disabled') ||
              element.getAttribute('aria-disabled') === 'true',
          };
        })
        .filter((entry) => isRectInViewport(entry.rect));
      const isViewportEdgeSliver = (rect) =>
        rect.height < 8 ||
        rect.width < 8 ||
        (rect.height < 24 &&
          (rect.top <= 2 || rect.bottom >= viewportHeight - 2));
      const skippedViewportEdgeControls = interactiveElements
        .filter((entry) => !entry.disabled && isViewportEdgeSliver(entry.rect))
        .map(
          (entry) =>
            `${entry.label.slice(0, 30) || 'unlabeled'} ${Math.round(entry.rect.width)}x${Math.round(entry.rect.height)}`,
        );
      const enabledControls = interactiveElements.filter(
        (entry) => !entry.disabled && !isViewportEdgeSliver(entry.rect),
      );
      const unlabeledControls = enabledControls
        .filter(
          (entry) =>
            entry.label.length < 2 &&
            !entry.hasLabeledControlAncestor,
        )
        .slice(0, 5)
        .map(
          (entry) =>
            `${Math.round(entry.rect.left)},${Math.round(entry.rect.top)} ${Math.round(entry.rect.width)}x${Math.round(entry.rect.height)}`,
        );
      const undersizedControls = enabledControls
        .filter((entry) => {
          if (!entry.requiresFullHitTarget || entry.hasLabeledControlAncestor) {
            return false;
          }
          const minHeight = entry.isFlutterSemantics ? 12 : 24;
          if (
            entry.label.startsWith('pw-') &&
            entry.isFlutterSemantics &&
            entry.rect.height < minHeight
          ) {
            return false;
          }
          return entry.rect.width < 28 || entry.rect.height < minHeight;
        })
        .slice(0, 5)
        .map(
          (entry) =>
            `${entry.label.slice(0, 30) || 'unlabeled'} ${Math.round(entry.rect.width)}x${Math.round(entry.rect.height)}`,
        );

      return {
        viewportWidth,
        viewportHeight,
        rootScrollWidth,
        bodyScrollWidth,
        documentScrollWidth,
        horizontalOverflowPx: Math.max(0, documentScrollWidth - viewportWidth),
        visualDocumentScrollWidth,
        visualHorizontalOverflowPx: Math.max(0, visualDocumentScrollWidth - viewportWidth),
        visibleTextRectCount: entries.length,
        visualTextRectCount: compareEntries.length,
        uniqueVisibleTextCount: uniqueVisibleTexts.length,
        visibleTextCharCount: visibleViewportText.length,
        visibleTextSample: visibleViewportText.slice(0, 300),
        overlapFailures,
        desktopMarkerMatches: markerMatches,
        enabledControlCount: enabledControls.length,
        skippedViewportEdgeControls,
        unlabeledControls,
        undersizedControls,
      };
    }, desktopMarkers);

    addAssertion(
      'design: frontend-skill restrained chrome has no obvious horizontal overflow',
      metrics.visualHorizontalOverflowPx <= 16,
      `page=${pageName} viewport=${metrics.viewportWidth}x${metrics.viewportHeight} visualDocumentScrollWidth=${Math.round(metrics.visualDocumentScrollWidth)} visualOverflow=${Math.round(metrics.visualHorizontalOverflowPx)}px documentScrollWidth=${metrics.documentScrollWidth} semanticsAdjustedOverflow=${metrics.horizontalOverflowPx}px`,
    );
    addAssertion(
      'design: frontend-skill readable viewport text nodes do not obviously overlap',
      metrics.overlapFailures.length === 0,
      metrics.overlapFailures.length === 0
        ? `checkedVisualTextRects=${metrics.visualTextRectCount}; semanticsTextRects=${metrics.visibleTextRectCount - metrics.visualTextRectCount}`
        : metrics.overlapFailures.join(' | '),
    );

    const normalizedPageText = normalizeForMatch(pageText);
    const normalizedShellNav = SHELL_NAV_ORDER.map(normalizeForMatch);
    let shellCursor = 0;
    const shellNavPositions = normalizedShellNav.map((label) => {
      const position = normalizedPageText.indexOf(label, shellCursor);
      if (position >= 0) {
        shellCursor = position + label.length;
      }
      return position;
    });
    const missingShellNav = SHELL_NAV_ORDER.filter((_, index) => shellNavPositions[index] < 0);
    const shellNavOrderOk =
      missingShellNav.length === 0 &&
      shellNavPositions.every((position, index) => index === 0 || position > shellNavPositions[index - 1]);
    const mojibakePattern = /[\ufffd\u20ac\ue75d\u93ac\u9417\u947a\u9359\u93c9\u7039\u95c2]/;
    const localizationText = normalizedPageText
      .replace(/\bpw-[a-z0-9_-]+\b/gi, ' ')
      .replace(/https?:\/\/\S+/gi, ' ');
    const legacyUnitMatches = Array.from(
      new Set(localizationText.match(/\b(?:yi|wan)\b/gi) || []),
    );
    const legacyEnglishMatches = Array.from(
      new Set(
        localizationText.match(
          /\b(?:Bundle\s+Fresh|Bundle|Fresh|source|build|api|boards?|broken|Limit\s+Buy|Yesterday\s+Limit|Auction\s+(?:Live|Desk)|network\s+timeout|service\s+not\s+ready)\b/gi,
        ) || [],
      ),
    );

    if (metrics.viewportWidth >= 720) {
      addAssertion(
        'design: shell nav keeps Chinese labels in legacy desktop order',
        shellNavOrderOk,
        shellNavOrderOk
          ? SHELL_NAV_ORDER.join(' > ')
          : `missing=${missingShellNav.join(', ') || 'none'} positions=${shellNavPositions.join(',')}`,
      );
    } else {
      const compactMatches = SHELL_COMPACT_MARKERS.filter((marker) =>
        normalizedPageText.includes(normalizeForMatch(marker)),
      );
      addAssertion(
        'design: compact shell exposes status and utility controls',
        compactMatches.length >= 3,
        `matches=${compactMatches.join(', ') || 'none'}`,
      );
    }
    addAssertion(
      'design: visible shell/page copy has no mojibake markers',
      !mojibakePattern.test(pageText),
      mojibakePattern.test(pageText)
        ? `sample=${pageText.match(mojibakePattern)?.[0] || 'unknown'}`
        : 'no mojibake marker found',
    );
    addAssertion(
      'design: visible market units use Chinese 万/亿 instead of legacy yi/wan',
      legacyUnitMatches.length === 0,
      legacyUnitMatches.length === 0
        ? 'no legacy unit tokens found'
        : `legacy units=${legacyUnitMatches.join(', ')}`,
    );
    addAssertion(
      'design: visible operational copy is localized instead of legacy English status labels',
      legacyEnglishMatches.length === 0,
      legacyEnglishMatches.length === 0
        ? 'no legacy English status labels found'
        : `legacy labels=${legacyEnglishMatches.join(', ')}`,
    );

    const placeholderOnly =
      /(?:\u6682\u65e0|\u52a0\u8f7d\u4e2d|\u656c\u8bf7\u671f\u5f85|placeholder|coming soon|todo)/i.test(
        normalizedPageText,
      ) &&
      normalizedPageText.length < 220 &&
      metrics.uniqueVisibleTextCount < 8;
    const densityOk =
      !placeholderOnly &&
      (normalizedPageText.length >= 220 ||
        metrics.visibleTextCharCount >= 160 ||
        metrics.uniqueVisibleTextCount >= 10);

    addAssertion(
      'design: frontend-skill dense app workspace is not an empty placeholder shell',
      densityOk,
      `pageTextChars=${normalizedPageText.length} visibleTextChars=${metrics.visibleTextCharCount} uniqueVisibleTexts=${metrics.uniqueVisibleTextCount} placeholderOnly=${placeholderOnly}`,
    );
    addAssertion(
      'design: frontend-skill desktop viewport exposes shell nav/status or page content text',
      metrics.viewportWidth < 1200 ||
        metrics.desktopMarkerMatches.length > 0 ||
        metrics.visibleTextCharCount >= 120 ||
        metrics.visibleTextRectCount >= 8,
      `matches=${metrics.desktopMarkerMatches.join(', ') || 'none'} visibleTextRects=${metrics.visibleTextRectCount} sample=${metrics.visibleTextSample || 'none'}`,
    );
    addAssertion(
      'design: visible controls have labels and reasonable hit targets',
      metrics.enabledControlCount === 0 ||
        (metrics.unlabeledControls.length === 0 && metrics.undersizedControls.length === 0),
      `enabledControls=${metrics.enabledControlCount} unlabeled=${metrics.unlabeledControls.join(' | ') || 'none'} undersized=${metrics.undersizedControls.join(' | ') || 'none'} skippedEdgeSlivers=${metrics.skippedViewportEdgeControls.join(' | ') || 'none'}`,
    );
  } catch (error) {
    addAssertion(
      'design: assertion collector executed successfully',
      false,
      error.message || String(error),
    );
  }

  return { assertions, failures };
}

async function waitForExpectedApiResponses(page, expectedApi, apiResponses, timeoutMs) {
  if (expectedApi.length === 0) {
    await page.waitForTimeout(Math.max(1000, timeoutMs));
    return;
  }

  const deadline = Date.now() + Math.max(1000, timeoutMs);
  while (Date.now() < deadline) {
    if (findMissingExpectedApi(expectedApi, apiResponses).length === 0) {
      await page.waitForTimeout(400);
      return;
    }
    await page.waitForTimeout(250);
  }
}

async function waitForNewExpectedApiResponses(page, expectedApi, apiResponses, startCounts, timeoutMs) {
  if (expectedApi.length === 0) {
    await page.waitForTimeout(400);
    return;
  }

  const deadline = Date.now() + Math.max(1000, timeoutMs);
  while (Date.now() < deadline) {
    if (findMissingNewExpectedApi(expectedApi, apiResponses, startCounts).length === 0) {
      await page.waitForTimeout(400);
      return;
    }
    await page.waitForTimeout(250);
  }
}

async function waitForNewExpectedApiResponsesAnyStatus(
  page,
  expectedApi,
  apiResponses,
  startCounts,
  timeoutMs,
) {
  if (expectedApi.length === 0) {
    await page.waitForTimeout(400);
    return;
  }

  const deadline = Date.now() + Math.max(1000, timeoutMs);
  while (Date.now() < deadline) {
    if (findMissingNewExpectedApiAnyStatus(expectedApi, apiResponses, startCounts).length === 0) {
      await page.waitForTimeout(400);
      return;
    }
    await page.waitForTimeout(250);
  }
}

async function extractCurrentPageText(page) {
  return page.evaluate(() => {
    const selectors = ['flt-semantics-host', 'body'];
    const segments = [];

    for (const selector of selectors) {
      document.querySelectorAll(selector).forEach((node) => {
        const text = node.innerText || node.textContent || '';
        if (text.trim()) {
          segments.push(text);
        }
      });
    }

    return segments.join('\n');
  });
}

async function getFlutterWheelPoints(page) {
  const flutterHost = page.locator('flutter-view');
  if ((await flutterHost.count()) === 0) {
    return [];
  }

  const box = await flutterHost.first().boundingBox();
  if (!box || box.width <= 0 || box.height <= 0) {
    return [];
  }

  const viewport = page.viewportSize() || { width: 1600, height: 1200 };
  const ratios = [
    { x: 0.2, y: 0.35 },
    { x: 0.5, y: 0.35 },
    { x: 0.8, y: 0.35 },
    { x: 0.2, y: 0.65 },
    { x: 0.5, y: 0.65 },
    { x: 0.8, y: 0.65 },
  ];

  return ratios
    .map((ratio) => ({
      x: Math.round(
        Math.min(
          Math.max(box.x + box.width * ratio.x, 8),
          Math.max(8, viewport.width - 8),
        ),
      ),
      y: Math.round(
        Math.min(
          Math.max(box.y + box.height * ratio.y, 8),
          Math.max(8, viewport.height - 8),
        ),
      ),
    }))
    .filter(
      (point, index, points) =>
        points.findIndex((candidate) => candidate.x === point.x && candidate.y === point.y) ===
        index,
    );
}

async function collectFlutterWheelText(page) {
  const points = await getFlutterWheelPoints(page);
  if (points.length === 0) {
    return '';
  }

  const viewportHeight = page.viewportSize()?.height || 1200;
  const wheelStep = Math.max(Math.floor(viewportHeight * 0.82), 420);
  const maxPassesPerPoint = 3;
  const samples = [];

  for (const point of points) {
    await page.mouse.move(point.x, point.y);
    for (let pass = 0; pass < maxPassesPerPoint; pass += 1) {
      await page.mouse.wheel(0, wheelStep);
      await page.waitForTimeout(180);
      const currentText = await extractCurrentPageText(page);
      if (currentText.trim()) {
        samples.push(currentText);
      }
    }
  }

  for (const point of points.slice().reverse()) {
    await page.mouse.move(point.x, point.y);
    for (let pass = 0; pass < maxPassesPerPoint; pass += 1) {
      await page.mouse.wheel(0, -wheelStep);
      await page.waitForTimeout(120);
    }
  }

  return samples.join('\n');
}

async function readPageText(page, options = {}) {
  try {
    const includeFlutterWheel = options.includeFlutterWheel === true;
    const metrics = await page.evaluate(() => {
      const root = document.documentElement;
      const body = document.body;
      const scrollHeight = Math.max(root?.scrollHeight || 0, body?.scrollHeight || 0);
      const viewportHeight = window.innerHeight || root?.clientHeight || 0;
      return {
        maxScrollTop: Math.max(0, scrollHeight - viewportHeight),
      };
    });

    const checkpoints = [
      0,
      Math.floor(metrics.maxScrollTop * 0.25),
      Math.floor(metrics.maxScrollTop * 0.5),
      Math.floor(metrics.maxScrollTop * 0.75),
      metrics.maxScrollTop,
    ].filter((value, index, array) => array.indexOf(value) === index);

    const samples = [];
    for (const scrollTop of checkpoints) {
      await page.evaluate((value) => {
        window.scrollTo(0, value);
      }, scrollTop);
      await page.waitForTimeout(180);
      const currentText = await extractCurrentPageText(page);
      if (currentText.trim()) {
        samples.push(currentText);
      }
    }

    await page.evaluate(() => {
      window.scrollTo(0, 0);
    });
    await page.waitForTimeout(120);

    if (includeFlutterWheel) {
      const flutterWheelText = await collectFlutterWheelText(page);
      if (flutterWheelText.trim()) {
        samples.push(flutterWheelText);
      }
    }

    return samples
      .filter((value, index, values) => values.indexOf(value) === index)
      .join('\n');
  } catch (error) {
    return '';
  }
}

async function waitForExpectedText(page, expectedText, timeoutMs) {
  let pageText = await readPageText(page);
  if (expectedText.length === 0) {
    return {
      pageText,
      missingExpectedText: [],
    };
  }

  const deadline = Date.now() + Math.max(1000, timeoutMs);
  let attempts = 0;
  while (Date.now() < deadline) {
    const missingExpectedText = findMissingExpectedText(expectedText, pageText);
    if (missingExpectedText.length === 0) {
      return {
        pageText,
        missingExpectedText,
      };
    }

    await page.waitForTimeout(250);
    attempts += 1;
    pageText = await readPageText(page, {
      includeFlutterWheel: attempts >= 2,
    });
  }

  return {
    pageText,
    missingExpectedText: findMissingExpectedText(expectedText, pageText),
  };
}

async function revealLocatorByPageScroll(page, locator, timeoutMs) {
  if ((await locator.count()) > 0) {
    return true;
  }

  const deadline = Date.now() + Math.max(1000, timeoutMs);
  let previousScrollTop = -1;

  while (Date.now() < deadline) {
    const position = await page.evaluate(() => {
      const root = document.documentElement;
      const body = document.body;
      const viewportHeight = window.innerHeight || root?.clientHeight || 0;
      const scrollHeight = Math.max(root?.scrollHeight || 0, body?.scrollHeight || 0);
      const maxScrollTop = Math.max(0, scrollHeight - viewportHeight);
      const step = Math.max(Math.floor(viewportHeight * 0.85), 320);
      const nextScrollTop = Math.min(window.scrollY + step, maxScrollTop);
      window.scrollTo(0, nextScrollTop);
      return {
        currentScrollTop: nextScrollTop,
        maxScrollTop,
      };
    });

    await page.waitForTimeout(250);

    if ((await locator.count()) > 0) {
      return true;
    }

    if (
      position.currentScrollTop === previousScrollTop ||
      position.currentScrollTop >= position.maxScrollTop
    ) {
      break;
    }
    previousScrollTop = position.currentScrollTop;
  }

  const wheelPoints = await getFlutterWheelPoints(page);
  if (wheelPoints.length > 0) {
    const viewportHeight = page.viewportSize()?.height || 1200;
    const wheelStep = Math.max(Math.floor(viewportHeight * 0.9), 480);

    while (Date.now() < deadline) {
      for (const point of wheelPoints) {
        await page.mouse.move(point.x, point.y);
        await page.mouse.wheel(0, wheelStep);
        await page.waitForTimeout(250);

        if ((await locator.count()) > 0) {
          return true;
        }
        if (Date.now() >= deadline) {
          break;
        }
      }
    }
  } else {
    const body = page.locator('body');
    if ((await body.count()) > 0) {
      await body.hover();
      const viewportHeight = page.viewportSize()?.height || 1200;
      const wheelStep = Math.max(Math.floor(viewportHeight * 0.9), 480);

      while (Date.now() < deadline) {
        await page.mouse.wheel(0, wheelStep);
        await page.waitForTimeout(250);

        if ((await locator.count()) > 0) {
          return true;
        }
      }
    }
  }

  return (await locator.count()) > 0;
}

async function revealLocatorAcrossScrollAxes(page, locator, timeoutMs) {
  if ((await locator.count()) > 0) {
    try {
      await locator.first().scrollIntoViewIfNeeded({ timeout: 1500 });
      return true;
    } catch (_) {
      return true;
    }
  }

  const deadline = Date.now() + Math.max(1000, timeoutMs);
  await revealLocatorByPageScroll(page, locator, Math.min(timeoutMs, 8000));
  if ((await locator.count()) > 0) {
    try {
      await locator.first().scrollIntoViewIfNeeded({ timeout: 1500 });
      return true;
    } catch (_) {
      return true;
    }
  }

  while (Date.now() < deadline) {
    const moved = await page.evaluate(() => {
      const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;
      const candidates = Array.from(document.querySelectorAll('*'))
        .filter((node) => {
          if (!(node instanceof HTMLElement)) {
            return false;
          }
          if (node.scrollWidth <= node.clientWidth + 12) {
            return false;
          }
          const rect = node.getBoundingClientRect();
          return rect.bottom >= 0 && rect.top <= viewportHeight && rect.width > 120;
        })
        .sort((left, right) => {
          const leftRect = left.getBoundingClientRect();
          const rightRect = right.getBoundingClientRect();
          return Math.abs(right.scrollWidth - right.clientWidth) - Math.abs(left.scrollWidth - left.clientWidth) ||
            leftRect.top - rightRect.top;
        });

      let scrolled = false;
      for (const node of candidates.slice(0, 8)) {
        const before = node.scrollLeft;
        const step = Math.max(Math.floor(node.clientWidth * 0.8), 160);
        node.scrollLeft = Math.min(node.scrollLeft + step, node.scrollWidth - node.clientWidth);
        if (node.scrollLeft !== before) {
          scrolled = true;
        }
      }
      return scrolled;
    });

    await page.waitForTimeout(250);
    if ((await locator.count()) > 0) {
      try {
        await locator.first().scrollIntoViewIfNeeded({ timeout: 1500 });
      } catch (_) {
        // Flutter semantics may already be attached even when the platform view
        // cannot perform a native DOM scroll for the virtualized child.
      }
      return true;
    }

    if (!moved) {
      await revealLocatorByPageScroll(page, locator, 1500);
    }
  }

  return (await locator.count()) > 0;
}

async function waitForUrlIncludes(page, fragment, timeoutMs) {
  const deadline = Date.now() + Math.max(1000, timeoutMs);
  while (Date.now() < deadline) {
    if (page.url().includes(fragment)) {
      return true;
    }
    await page.waitForTimeout(200);
  }
  return page.url().includes(fragment);
}

async function waitForLocator(locator, timeoutMs) {
  await locator.first().waitFor({
    state: 'visible',
    timeout: Math.max(5000, timeoutMs),
  });
}

async function waitForLocatorAttached(locator, timeoutMs) {
  await locator.first().waitFor({
    state: 'attached',
    timeout: Math.max(5000, timeoutMs),
  });
}

function compactErrorMessage(error) {
  return String(error?.message || error || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, 4)
    .join(' | ');
}

async function activateLocatorTarget(target, timeoutMs) {
  await target
    .evaluate((node) => {
      node.scrollIntoView({ block: 'center', inline: 'center' });
    })
    .catch(() => {});
  await target.scrollIntoViewIfNeeded({ timeout: 1500 }).catch(() => {});
  try {
    await target.click({
      timeout: Math.max(5000, timeoutMs),
    });
    return { method: 'pointer' };
  } catch (clickError) {
    const fallbackError = compactErrorMessage(clickError);
    const domClicked = await target
      .evaluate((node) => {
        node.click();
        return true;
      })
      .catch(() => false);

    if (domClicked) {
      await target
        .evaluate(() => new Promise((resolve) => window.setTimeout(resolve, 250)))
        .catch(() => {});
      return { method: 'dom-click', fallbackError };
    }

    await target.focus({ timeout: 1500 }).catch(() => {});
    await target.press('Enter', { timeout: 1500 }).catch(() => {});
    await target
      .evaluate(() => new Promise((resolve) => window.setTimeout(resolve, 250)))
      .catch(() => {});
    return { method: 'keyboard-enter', fallbackError };
  }
}

async function findFirstAvailableLocator(page, candidates, timeoutMs) {
  const deadline = Date.now() + Math.max(1000, timeoutMs);

  while (Date.now() < deadline) {
    for (const candidate of candidates) {
      if ((await candidate.locator.count()) > 0) {
        return candidate;
      }
    }
    await page.waitForTimeout(250);
  }

  for (const candidate of candidates) {
    if ((await candidate.locator.count()) > 0) {
      return candidate;
    }
  }

  return null;
}

async function clickPreferred(locator, timeoutMs) {
  await waitForLocatorAttached(locator, timeoutMs);
  const count = await locator.count();
  const target = locator.nth(count > 1 ? 1 : 0);
  const activation = await activateLocatorTarget(target, timeoutMs);
  return { count, index: count > 1 ? 1 : 0, activation };
}

async function clickAtIndex(locator, index, timeoutMs) {
  await waitForLocatorAttached(locator, timeoutMs);
  const count = await locator.count();
  const safeIndex = Math.max(0, Math.min(index, count - 1));
  const target = locator.nth(safeIndex);
  const activation = await activateLocatorTarget(target, timeoutMs);
  return { count, index: safeIndex, activation };
}

async function enableAccessibilityIfNeeded(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  if ((await placeholder.count()) === 0) {
    return;
  }

  await placeholder.evaluate((node) => node.click());
  await page.waitForTimeout(800);
}

function pickNodeDateSelectionSnapshot(payload) {
  const dateItems = Array.isArray(payload?.date_items) ? payload.date_items : [];
  if (dateItems.length === 0) {
    return null;
  }

  const candidates = dateItems
    .map((item) => ({
      date: toText(item?.date),
      topPlateCount: Array.isArray(item?.top_plates) ? item.top_plates.length : 0,
    }))
    .filter((item) => isFilledText(item.date));
  if (candidates.length === 0) {
    return null;
  }

  const defaultDate =
    toText(payload?.selected_date) ||
    toText(payload?.trade_date) ||
    toText(payload?.default_date) ||
    candidates[candidates.length - 1]?.date ||
    '';
  const nonDefaultCandidates = candidates.filter((item) => item.date !== defaultDate);
  const selected =
    nonDefaultCandidates.filter((item) => item.topPlateCount > 0).slice(-1)[0] ||
    nonDefaultCandidates.slice(-1)[0] ||
    candidates.filter((item) => item.topPlateCount > 0).slice(-1)[0] ||
    candidates[0];
  if (!selected) {
    return null;
  }

  return {
    date: selected.date,
    defaultDate,
    topPlateCount: selected.topPlateCount,
    shortLabel: selected.date.length >= 10 ? selected.date.slice(5) : selected.date,
    semanticsLabel: `pw-node-date-${selected.date}`,
  };
}

async function clickButtonByContainedText(page, textFragment, timeoutMs) {
  const deadline = Date.now() + Math.max(1000, timeoutMs);
  let lastFoundText = '';
  const labelPattern = new RegExp(escapeRegExp(textFragment));

  while (Date.now() < deadline) {
    await enableAccessibilityIfNeeded(page);

    try {
      const labelLocator = page.getByLabel(labelPattern);
      await revealLocatorByPageScroll(
        page,
        labelLocator,
        Math.min(Math.max(1500, Math.floor(timeoutMs / 3)), 8000),
      ).catch(() => {});
      const labelCount = await labelLocator.count();
      if (labelCount > 0) {
        const target = labelLocator.first();
        const activation = await activateLocatorTarget(
          target,
          Math.min(Math.max(2500, Math.floor(timeoutMs / 3)), 8000),
        );
        return {
          count: labelCount,
          index: 0,
          label: textFragment,
          activation,
        };
      }
    } catch (_) {
      // Fall back to DOM text matching below. Flutter web may expose either
      // aria labels or semantics text depending on renderer and cold start.
    }

    const result = await page.evaluate((fragment) => {
      const selectors = ['[role="button"]', 'flt-semantics', 'flt-semantics-host'];
      for (const selector of selectors) {
        const nodes = Array.from(document.querySelectorAll(selector));
        const match = nodes.find((node) => {
          const text = [
            node.getAttribute?.('aria-label') || '',
            node.getAttribute?.('label') || '',
            node.innerText || '',
            node.textContent || '',
          ].join(' ').trim();
          return text.includes(fragment);
        });
        if (!match) {
          continue;
        }

        const text = [
          match.getAttribute?.('aria-label') || '',
          match.getAttribute?.('label') || '',
          match.innerText || '',
          match.textContent || '',
        ].join(' ').trim();
        match.scrollIntoView({ block: 'center', inline: 'center' });
        match.click();
        return {
          clicked: true,
          foundText: text,
        };
      }

      return {
        clicked: false,
        foundText: '',
      };
    }, textFragment);

    lastFoundText = result?.foundText || lastFoundText;
    if (result?.clicked) {
      return {
        count: 1,
        index: 0,
        label: normalizeForMatch(lastFoundText),
      };
    }

    await page.waitForTimeout(250);
  }

  throw new Error(
    `Unable to click button containing text ${textFragment}; lastFoundText=${lastFoundText || 'none'}`,
  );
}

async function runNodeInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs) {
  const expectedApi = ['/api/v1/node/plates/'];
  await Promise.all(apiPayloadReads);
  const snapshotPayload = findLatestJsonPayload(apiPayloads, '/api/v1/node/snapshot');
  const selectedDate = pickNodeDateSelectionSnapshot(snapshotPayload?.json);

  if (!selectedDate) {
    return {
      description: 'select a historical date in node workspace',
      selectors: ['role=button[name*=pw-node-date-]'],
      picked: {
        skipped: true,
        reason: 'no selectable node date found in snapshot payload',
      },
      assertions: [],
      assertionFailures: snapshotPayload
        ? ['unable to select a node date from snapshot payload']
        : ['missing JSON payload for /api/v1/node/snapshot before interaction'],
      expectedApi,
      missingExpectedApi: [],
    };
  }

  const startCounts = captureExpectedCounts(expectedApi, apiResponses);
  const hadLeadersBeforeClick =
    countMatchingResponses('/api/v1/node/plates/', apiResponses) > 0;
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(250);
  let datePick;
  try {
    const dateRole = page.getByRole('button', {
      name: new RegExp(`^${escapeRegExp(selectedDate.shortLabel)}$`),
    });
    await revealLocatorByPageScroll(page, dateRole, timeoutMs).catch(() => {});
    await waitForLocatorAttached(dateRole, timeoutMs);
    const activation = await activateLocatorTarget(dateRole.first(), timeoutMs);
    datePick = {
      count: await dateRole.count(),
      index: 0,
      label: selectedDate.shortLabel,
      activation,
    };
  } catch (_) {
    try {
      const dateText = page.getByText(selectedDate.shortLabel, { exact: true }).first();
      await dateText.click({ timeout: timeoutMs });
      datePick = {
        count: 1,
        index: 0,
        label: selectedDate.shortLabel,
        activation: { method: 'text' },
      };
    } catch (_) {
      datePick = await clickButtonByContainedText(
        page,
        selectedDate.shortLabel,
        timeoutMs,
      );
    }
  }
  if (selectedDate.date !== selectedDate.defaultDate || !hadLeadersBeforeClick) {
    await waitForNewExpectedApiResponses(page, expectedApi, apiResponses, startCounts, timeoutMs);
  } else {
    await page.waitForTimeout(500);
  }
  await Promise.all(apiPayloadReads);

  const leadersPayload = findLatestJsonPayload(apiPayloads, '/api/v1/node/plates/');
  const leaders = Array.isArray(leadersPayload?.json?.leaders) ? leadersPayload.json.leaders : [];
  const firstLeader = leaders[0] || null;
  let leaderStockVisible = false;
  let leaderOpenVisible = false;

  if (firstLeader && isFilledText(firstLeader.stock_code)) {
    const stockCode = toText(firstLeader.stock_code);
    const stockLocator = page.getByRole('button', {
      name: new RegExp(`^${escapeRegExp(`pw-node-leader-stock-${stockCode}`)}$`),
    });
    const openLocator = page.getByRole('button', {
      name: new RegExp(`^${escapeRegExp(`pw-node-leader-open-${stockCode}`)}$`),
    });

    try {
      await revealLocatorByPageScroll(page, stockLocator, timeoutMs);
      await waitForLocatorAttached(stockLocator, timeoutMs);
      leaderStockVisible = true;
    } catch (error) {
      leaderStockVisible = false;
    }

    try {
      await revealLocatorByPageScroll(page, openLocator, timeoutMs);
      await waitForLocatorAttached(openLocator, timeoutMs);
      leaderOpenVisible = true;
    } catch (error) {
      leaderOpenVisible = false;
    }
  }

  const assertions = [
    {
      label: 'node selected date',
      value: selectedDate.date,
    },
    {
      label: 'node default date',
      value: selectedDate.defaultDate || '--',
    },
    {
      label: 'node selected date top plates',
      value: selectedDate.topPlateCount,
    },
    {
      label: 'node payload url',
      value: leadersPayload?.url || '--',
    },
    {
      label: 'node leaders',
      value: leaders.length,
    },
    {
      label: 'node first leader',
      value: firstLeader
        ? `${toText(firstLeader.stock_name)} (${toText(firstLeader.stock_code)})`
        : '--',
    },
    {
      label: 'node leader stock visible',
      value: leaderStockVisible,
    },
    {
      label: 'node leader open visible',
      value: leaderOpenVisible,
    },
  ];
  const assertionFailures = [];

  if (!leadersPayload) {
    assertionFailures.push('missing JSON payload for /api/v1/node/plates/ after date switch');
  }
  if (leaders.length === 0) {
    assertionFailures.push('node leaders payload expected > 0 items after date switch');
  }
  if (firstLeader && !leaderStockVisible) {
    assertionFailures.push(
      `node expected leader stock button to be visible after scroll: ${toText(firstLeader.stock_code)}`,
    );
  }
  if (firstLeader && !leaderOpenVisible) {
    assertionFailures.push(
      `node expected leader open button to be visible after scroll: ${toText(firstLeader.stock_code)}`,
    );
  }

  return {
    description: 'select a historical date in node workspace',
    selectors: [
      `role=button[name=${selectedDate.shortLabel}]`,
      'role=button[name*=pw-node-leader-stock-]',
      'role=button[name*=pw-node-leader-open-]',
    ],
    picked: {
      ...datePick,
      date: selectedDate.date,
      defaultDate: selectedDate.defaultDate || '--',
    },
    assertions,
    assertionFailures,
    expectedApi,
    missingExpectedApi: leadersPayload
      ? []
      : findMissingNewExpectedApi(expectedApi, apiResponses, startCounts),
  };
}

async function runMarketCenterInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs) {
  await Promise.all(apiPayloadReads);
  const payload = findLatestJsonPayload(apiPayloads, '/api/v1/market-center-page');
  const tables = payload?.json?.market_center?.tables || payload?.json?.tables || [];
  const sectionKeys = ['zt', 'zrzt', 'qs', 'cx', 'zb', 'dt'].filter((key) =>
    findMarketCenterSectionSnapshot(tables, key),
  );
  const section = findMarketCenterSectionSnapshot(tables, 'dt');
  const expectedText = [];
  const steps = [];
  let tabPick = null;
  let stockButtonVisible = false;
  let codeButtonVisible = false;
  const assertionFailures = [];

  for (const key of sectionKeys) {
    const sectionSnapshot = findMarketCenterSectionSnapshot(tables, key);
    const tabLocator = page.getByRole('button', {
      name: new RegExp(`pw-market-center-tab-${key}`),
    });
    const currentPick = await clickPreferred(tabLocator, timeoutMs);
    if (key === 'dt') {
      tabPick = currentPick;
    }
    await page.waitForTimeout(350);
    const tabExpectedText = uniqueFilledStrings([sectionSnapshot?.title]);
    expectedText.push(...tabExpectedText);
    const textCheck = await waitForExpectedText(page, tabExpectedText, timeoutMs);
    steps.push({
      key,
      selector: `role=button[name*=pw-market-center-tab-${key}]`,
      picked: currentPick,
      expectedText: tabExpectedText,
      missingExpectedText: textCheck.missingExpectedText,
      snapshot: sectionSnapshot
        ? {
            title: sectionSnapshot.title,
            total: sectionSnapshot.total,
            rowCount: sectionSnapshot.rowCount,
            firstCode: sectionSnapshot.firstCode,
            firstName: sectionSnapshot.firstName,
          }
        : null,
    });
    if (!sectionSnapshot) {
      assertionFailures.push(`market center payload missing ${key} section`);
    } else if (sectionSnapshot.rowCount === 0) {
      assertionFailures.push(`market center ${key} section expected > 0 rows`);
    }
  }

  if (section?.firstCode) {
    const stockLocator = page.getByRole('button', {
      name: new RegExp(`^${escapeRegExp(`pw-market-center-stock-dt-${section.firstCode}`)}$`),
    });
    const codeLocator = page.getByRole('button', {
      name: new RegExp(`^${escapeRegExp(`pw-market-center-code-dt-${section.firstCode}`)}$`),
    });

    try {
      await revealLocatorByPageScroll(page, stockLocator, timeoutMs);
      await waitForLocatorAttached(stockLocator, timeoutMs);
      stockButtonVisible = true;
    } catch (error) {
      stockButtonVisible = false;
    }

    try {
      await revealLocatorByPageScroll(page, codeLocator, timeoutMs);
      await waitForLocatorAttached(codeLocator, timeoutMs);
      codeButtonVisible = true;
    } catch (error) {
      codeButtonVisible = false;
    }
  }

  const assertions = [
    {
      label: 'market center payload url',
      value: payload?.url || '--',
    },
    {
      label: 'market center switched tabs',
      value: sectionKeys.join(', ') || '--',
    },
    ...summarizeMarketCenterAssertions('market center selected section', section),
    {
      label: 'market center stock button visible',
      value: stockButtonVisible,
    },
    {
      label: 'market center code button visible',
      value: codeButtonVisible,
    },
  ];

  if (!payload) {
    assertionFailures.push('missing JSON payload for /api/v1/market-center-page before interaction');
  }
  if (sectionKeys.length < 6) {
    assertionFailures.push(`market center expected to cover 6 tabs, got ${sectionKeys.length}`);
  }
  if (!section) {
    assertionFailures.push('market center payload missing dt section');
  } else {
    if (section.rowCount === 0) {
      assertionFailures.push('market center dt section expected > 0 rows');
    }
    if (section.previewNames.length === 0 && !isFilledText(section.firstName)) {
      assertionFailures.push('market center dt section expected preview or first row name');
    }
    if (!isFilledText(section.firstCode)) {
      assertionFailures.push('market center dt section expected first row code');
    }
    if (isFilledText(section.firstCode) && !stockButtonVisible) {
      assertionFailures.push(
        `market center expected stock button to be visible after tab switch: ${section.firstCode}`,
      );
    }
    if (isFilledText(section.firstCode) && !codeButtonVisible) {
      assertionFailures.push(
        `market center expected code button to be visible after tab switch: ${section.firstCode}`,
      );
    }
  }

  return {
    description: 'switch all market center tabs and verify limit-down stock controls',
    selectors: [
      'role=button[name*=pw-market-center-tab-]',
      'role=button[name*=pw-market-center-stock-dt-]',
      'role=button[name*=pw-market-center-code-dt-]',
    ],
    picked: tabPick || steps[0]?.picked || null,
    steps,
    assertions,
    assertionFailures,
    expectedApi: [],
    expectedText: uniqueFilledStrings(expectedText),
    missingExpectedText: uniqueFilledStrings(steps.flatMap((step) => step.missingExpectedText)),
    missingExpectedApi: [],
  };
}

async function runLimitReviewInteraction(page, apiResponses, timeoutMs) {
  const dateLocator = page.getByRole('button', {
    name: /pw-limit-review-trade-date-/,
  });

  await waitForLocator(dateLocator, timeoutMs);
  const dateCount = await dateLocator.count();
  const targetIndex = dateCount > 1 ? 1 : 0;
  const target = dateLocator.nth(targetIndex);
  const targetRawText = ((await target.textContent()) || '').trim();
  const targetDateMatch = targetRawText.match(/\d{4}-\d{2}-\d{2}/);
  const targetDate = targetDateMatch ? targetDateMatch[0] : targetRawText;
  const expectedApi = targetDate
    ? [`/api/v1/review-page?trade_date=${targetDate}`]
    : ['/api/v1/review-page?trade_date='];
  const startCounts = captureExpectedCounts(expectedApi, apiResponses);

  await activateLocatorTarget(target, timeoutMs);
  await waitForNewExpectedApiResponses(page, expectedApi, apiResponses, startCounts, timeoutMs);

  const navigationOk = targetDate
    ? await waitForUrlIncludes(page, `tradeDate=${targetDate}`, timeoutMs)
    : true;

  return {
    description: 'switch limit review trade date',
    selectors: ['role=button[name*=pw-limit-review-trade-date-]'],
    picked: {
      dateCount,
      dateIndex: targetIndex,
      targetDate,
    },
    expectedApi,
    expectedText: [],
    missingExpectedText: [],
    navigationOk,
    navigationDetails: {
      targetDate,
      currentUrl: page.url(),
    },
    missingExpectedApi: findMissingNewExpectedApi(expectedApi, apiResponses, startCounts),
  };
}

async function runAuctionInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs) {
  await Promise.all(apiPayloadReads);
  const payload = findLatestJsonPayload(apiPayloads, '/api/v1/auction/page');
  const selection = pickAuctionSelectionSnapshot(payload?.json);
  if (!selection) {
    return {
      description: 'select an auction history stock card',
      selectors: ['role=button[name*=pw-auction-history-]'],
      picked: {
        skipped: true,
        reason: 'no selectable history item found in auction payload',
      },
      assertions: [],
      assertionFailures: payload
        ? ['unable to derive an auction selection snapshot from payload']
        : ['missing JSON payload for /api/v1/auction/page before interaction'],
      expectedApi: [],
      expectedText: [],
      missingExpectedText: [],
      missingExpectedApi: [],
    };
  }

  const cardLocator = page.getByRole('button', {
    name: new RegExp(escapeRegExp(selection.semanticsLabel)),
  });
  await revealLocatorByPageScroll(page, cardLocator, timeoutMs);
  await waitForLocatorAttached(cardLocator, timeoutMs);
  await activateLocatorTarget(cardLocator.first(), timeoutMs);
  await page.waitForTimeout(500);

  const expectedText = uniqueFilledStrings([selection.titleText]);
  const textCheck = await waitForExpectedText(page, expectedText, timeoutMs);
  const assertions = [
    {
      label: 'auction payload url',
      value: payload?.url || '--',
    },
    {
      label: 'auction selected code',
      value: selection.code,
    },
    {
      label: 'auction selected name',
      value: selection.name,
    },
    {
      label: 'auction selected day matches',
      value: selection.dayMatches.length,
    },
    {
      label: 'auction selected rank matches',
      value: selection.rankMatches.length,
    },
    {
      label: 'auction selected concept preview',
      value: selection.concepts.slice(0, 2).join(' / ') || '--',
    },
  ];
  const assertionFailures = [];

  if (!payload) {
    assertionFailures.push('missing JSON payload for /api/v1/auction/page before interaction');
  }
  if (selection.dayMatches.length === 0) {
    assertionFailures.push('auction selected stock expected to appear in at least one history column');
  }

  return {
    description: 'select an auction history stock card',
    selectors: ['role=button[name*=pw-auction-history-]'],
    picked: {
      semanticsLabel: selection.semanticsLabel,
      code: selection.code,
      name: selection.name,
      tradeDate: selection.tradeDate,
    },
    assertions,
    assertionFailures,
    expectedApi: [],
    expectedText,
    missingExpectedText: textCheck.missingExpectedText,
    missingExpectedApi: [],
  };
}

async function runPlateRotationInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs) {
  await Promise.all(apiPayloadReads);
  const rotationPayload = findLatestJsonPayload(apiPayloads, '/api/v1/plate-rotation');
  const viewportWidth = page.viewportSize()?.width || DEFAULT_VIEWPORT.width;
  if (viewportWidth < 600) {
    const rotation = rotationPayload?.json || {};
    const matrixColumns = Array.isArray(rotation?.matrix_columns) ? rotation.matrix_columns : [];
    const dateSummaries = Array.isArray(rotation?.plate_date_summaries)
      ? rotation.plate_date_summaries
      : [];
    return {
      description: 'mobile-width plate rotation layout/data check',
      selectors: ['mobile layout uses horizontally scrollable desktop matrix'],
      picked: {
        skippedDeepClick: true,
        reason: 'Flutter web does not expose offscreen matrix cells as stable mobile semantics',
      },
      assertions: [
        {
          label: 'plate rotation mobile matrix columns',
          value: matrixColumns.length,
        },
        {
          label: 'plate rotation mobile date summaries',
          value: dateSummaries.length,
        },
      ],
      assertionFailures: [],
      expectedApi: [],
      expectedText: [],
      missingExpectedText: [],
      missingExpectedApi: [],
    };
  }

  const selection = pickPlateRotationSelectionSnapshot(rotationPayload?.json, { viewportWidth });
  const dateSummaries = Array.isArray(rotationPayload?.json?.plate_date_summaries)
    ? rotationPayload.json.plate_date_summaries
    : [];
  if (!selection) {
    return {
      description: 'click plate rotation matrix cell',
      selectors: ['role=button[name*=pw-plate-rotation-cell-]'],
      picked: {
        skipped: true,
        reason: 'no selectable matrix cell found in plate rotation payload',
      },
      assertions: [],
      assertionFailures: rotationPayload
        ? ['unable to derive a plate rotation cell snapshot from payload']
        : ['missing JSON payload for /api/v1/plate-rotation before interaction'],
      expectedApi: [],
      expectedText: [],
      missingExpectedText: [],
      missingExpectedApi: [],
    };
  }
  const selectionCodeKey = normalizePlateCodeKey(selection.plateCode);
  const selectedDateSummary = dateSummaries.find((summary) => {
    const sameDate = toText(summary?.date) === selection.date;
    const sameCode =
      selectionCodeKey && normalizePlateCodeKey(summary?.plate_code) === selectionCodeKey;
    const sameName =
      isFilledText(selection.plateName) && toText(summary?.plate_name) === selection.plateName;
    return sameDate && (sameCode || sameName);
  });

  const cellLocator = page.getByRole('button', {
    name: new RegExp(escapeRegExp(selection.semanticsLabel)),
  });
  const expectedApi = [
    `/api/v1/plates/${selection.plateCode}/stocks`,
    `/api/v1/node/plates/${selection.plateCode}/leaders?date=${selection.date}`,
  ];

  await revealLocatorAcrossScrollAxes(page, cellLocator, timeoutMs);
  await waitForLocatorAttached(cellLocator, timeoutMs);
  const startCounts = captureExpectedCounts(expectedApi, apiResponses);
  await activateLocatorTarget(cellLocator.first(), timeoutMs);
  const preloadedExpectedApi = expectedApi.every(
    (fragment, index) => (startCounts[index] || 0) > 0,
  );
  if (!preloadedExpectedApi) {
    await waitForNewExpectedApiResponses(page, expectedApi, apiResponses, startCounts, timeoutMs);
  }
  await Promise.all(apiPayloadReads);

  const stocksPayload = findLatestJsonPayload(apiPayloads, expectedApi[0]);
  const leadersPayload = findLatestJsonPayload(apiPayloads, expectedApi[1]);
  const stockGroups = Array.isArray(stocksPayload?.json?.items) ? stocksPayload.json.items : [];
  const leaders = Array.isArray(leadersPayload?.json?.leaders) ? leadersPayload.json.leaders : [];
  const firstLeader = leaders[0] || null;
  let leaderStockVisible = false;
  let leaderOpenVisible = false;
  if (firstLeader && isFilledText(firstLeader.stock_code)) {
    const stockCode = toText(firstLeader.stock_code);
    const leaderStockLocator = page.getByRole('button', {
      name: new RegExp(
        `^${escapeRegExp(`pw-plate-rotation-leader-stock-${selection.date}-${stockCode}`)}$`,
      ),
    });
    const leaderOpenLocator = page.getByRole('button', {
      name: new RegExp(
        `^${escapeRegExp(`pw-plate-rotation-leader-open-${selection.date}-${stockCode}`)}$`,
      ),
    });

    try {
      await revealLocatorAcrossScrollAxes(page, leaderStockLocator, timeoutMs);
      await waitForLocatorAttached(leaderStockLocator, timeoutMs);
      leaderStockVisible = true;
    } catch (error) {
      leaderStockVisible = false;
    }

    try {
      await revealLocatorAcrossScrollAxes(page, leaderOpenLocator, timeoutMs);
      await waitForLocatorAttached(leaderOpenLocator, timeoutMs);
      leaderOpenVisible = true;
    } catch (error) {
      leaderOpenVisible = false;
    }
  }
  const expectedText =
    viewportWidth >= 1200 ? uniqueFilledStrings([selection.plateName]) : [];
  const textCheck = await waitForExpectedText(page, expectedText, timeoutMs);
  const assertions = [
    {
      label: 'plate rotation payload url',
      value: rotationPayload?.url || '--',
    },
    {
      label: 'plate rotation selected plate',
      value: selection.plateName,
    },
    {
      label: 'plate rotation selected code',
      value: selection.plateCode,
    },
    {
      label: 'plate rotation selected date',
      value: selection.date,
    },
    {
      label: 'plate rotation selected strength',
      value: selection.strengthText || '--',
    },
    {
      label: 'plate rotation selected summary rank',
      value: selectedDateSummary ? toInt(selectedDateSummary.rank) : 0,
    },
    {
      label: 'plate rotation selected summary leaders',
      value: selectedDateSummary ? toInt(selectedDateSummary.leader_total) : 0,
    },
    {
      label: 'plate rotation stock groups',
      value: stockGroups.length,
    },
    {
      label: 'plate rotation leaders',
      value: leaders.length,
    },
    {
      label: 'plate rotation first leader',
      value: firstLeader
        ? `${toText(firstLeader.stock_name)} (${toText(firstLeader.stock_code)})`
        : '--',
    },
    {
      label: 'plate rotation leader stock visible',
      value: leaderStockVisible,
    },
    {
      label: 'plate rotation leader open visible',
      value: leaderOpenVisible,
    },
  ];
  const assertionFailures = [];

  if (!rotationPayload) {
    assertionFailures.push('missing JSON payload for /api/v1/plate-rotation before interaction');
  }
  if (!selectedDateSummary) {
    assertionFailures.push('plate rotation selected cell expected matching plate_date_summaries item');
  }
  if (!stocksPayload) {
    assertionFailures.push(`missing JSON payload for ${expectedApi[0]} after interaction`);
  }
  if (!leadersPayload) {
    assertionFailures.push(`missing JSON payload for ${expectedApi[1]} after interaction`);
  }
  if (stocksPayload && toText(stocksPayload.json?.plate_name) !== selection.plateName) {
    assertionFailures.push(
      `plate rotation stocks payload plate name expected ${selection.plateName}, got ${toText(stocksPayload.json?.plate_name) || '--'}`,
    );
  }
  if (leadersPayload && toText(leadersPayload.json?.plate_name) !== selection.plateName) {
    assertionFailures.push(
      `plate rotation leaders payload plate name expected ${selection.plateName}, got ${toText(leadersPayload.json?.plate_name) || '--'}`,
    );
  }
  if (leadersPayload && toText(leadersPayload.json?.date) !== selection.date) {
    assertionFailures.push(
      `plate rotation leaders payload date expected ${selection.date}, got ${toText(leadersPayload.json?.date) || '--'}`,
    );
  }
  if (stockGroups.length === 0) {
    assertionFailures.push('plate rotation stocks payload expected grouped stock items > 0');
  }
  if (leaders.length === 0) {
    assertionFailures.push('plate rotation leaders payload expected > 0 items');
  }
  if (firstLeader && !leaderStockVisible && viewportWidth >= 1200) {
    assertionFailures.push(
      `plate rotation expected leader stock button to be visible after scroll: ${toText(firstLeader.stock_code)}`,
    );
  }
  if (firstLeader && !leaderOpenVisible && viewportWidth >= 1200) {
    assertionFailures.push(
      `plate rotation expected leader open button to be visible after scroll: ${toText(firstLeader.stock_code)}`,
    );
  }

  return {
    description: 'click plate rotation matrix cell',
    selectors: [
      'role=button[name*=pw-plate-rotation-cell-]',
      'role=button[name*=pw-plate-rotation-leader-stock-]',
      'role=button[name*=pw-plate-rotation-leader-open-]',
    ],
    picked: {
      semanticsLabel: selection.semanticsLabel,
      plateCode: selection.plateCode,
      plateName: selection.plateName,
      date: selection.date,
    },
    assertions,
    assertionFailures,
    expectedApi,
    expectedText,
    missingExpectedText: textCheck.missingExpectedText,
    missingExpectedApi: findMissingExpectedApi(expectedApi, apiResponses),
  };
}

async function runOverviewInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs) {
  const overviewUrl = page.url();
  const jobsCandidates = [
    {
      selector: 'role=button[name*=pw-shell-frontend-build-jobs]',
      locator: page.getByRole('button', {
        name: /pw-shell-frontend-build-jobs/,
      }),
    },
    {
      selector: 'role=button[name*=任务调度]',
      locator: page.getByRole('button', {
        name: /任务调度/,
      }),
    },
    {
      selector: 'role=button[name*=pw-overview-frontend-build-jobs]',
      locator: page.getByRole('button', {
        name: /pw-overview-frontend-build-jobs/,
      }),
    },
  ];
  const jobsExpectedApi = ['/internal/jobs/page'];
  const jobsStartCounts = captureExpectedCounts(jobsExpectedApi, apiResponses);
  const jobsAttemptTimeout = Math.min(Math.max(2500, Math.floor(timeoutMs / 3)), 8000);
  const jobsAttempts = [];
  let jumpedToJobs = false;
  let jobsPick = {
    skipped: true,
    reason: 'no jobs action locator available on overview',
  };

  for (const candidate of jobsCandidates) {
    const availableCandidate = await findFirstAvailableLocator(
      page,
      [candidate],
      jobsAttemptTimeout,
    );
    if (!availableCandidate) {
      jobsAttempts.push({
        selector: candidate.selector,
        available: false,
        navigated: false,
      });
      continue;
    }

    const pick = await clickPreferred(availableCandidate.locator, timeoutMs);
    const navigated = await waitForUrlIncludes(page, '/jobs', jobsAttemptTimeout);
    jobsAttempts.push({
      selector: availableCandidate.selector,
      ...pick,
      available: true,
      navigated,
    });

    if (navigated) {
      jumpedToJobs = true;
      jobsPick = {
        selector: availableCandidate.selector,
        ...pick,
      };
      break;
    }
  }

  if (jumpedToJobs) {
    await waitForNewExpectedApiResponses(
      page,
      jobsExpectedApi,
      apiResponses,
      jobsStartCounts,
      timeoutMs,
    );
    await page.goto(overviewUrl, { waitUntil: 'load' });
    await enableAccessibilityIfNeeded(page);
    await page.waitForTimeout(800);
  }
  const returnedFromJobs = jumpedToJobs
    ? await waitForUrlIncludes(page, '/overview', timeoutMs)
    : page.url().includes('/overview');
  await page.evaluate(() => {
    window.scrollTo(0, 0);
  });
  await page.waitForTimeout(250);

  const sourcePayload = findLatestJsonPayload(apiPayloads, '/api/v1/yesterday/stats');
  const selectedSection = pickWeaknessSectionSnapshot(sourcePayload?.json?.sections);
  if (!selectedSection) {
    return {
      description: 'open overview frontend build entry, then weakness tile navigation',
      selectors: [
        'role=button[name*=pw-shell-frontend-build-jobs]',
        'role=button[name*=任务调度]',
        'role=button[name*=pw-overview-frontend-build-jobs]',
        'role=button[name*=pw-overview-weakness-]',
      ],
      picked: {
        jobs: jobsPick,
        weakness: {
          skipped: true,
          reason: 'no weakness section snapshot available for current overview payload',
        },
      },
      assertions: [],
      assertionFailures: sourcePayload
        ? ['unable to select a weakness section from overview payload']
        : ['missing JSON payload for /api/v1/yesterday/stats before overview interaction'],
      expectedApi: jobsExpectedApi,
      expectedText: [],
      missingExpectedText: [],
      navigationOk: jumpedToJobs && returnedFromJobs,
      navigationDetails: {
        jumpedToJobs,
        returnedFromJobs,
        jobsAttempts,
        currentUrl: page.url(),
      },
      missingExpectedApi: findMissingNewExpectedApi(
        jobsExpectedApi,
        apiResponses,
        jobsStartCounts,
      ),
    };
  }

  const weaknessLocator = page.getByRole('button', {
    name: new RegExp(`pw-overview-weakness-${selectedSection.routeKey}`),
  });
  await revealLocatorByPageScroll(page, weaknessLocator, timeoutMs);
  await waitForLocatorAttached(weaknessLocator, timeoutMs);

  const sourceTradeDate =
    toText(sourcePayload?.json?.trade_date) ||
    toText(sourcePayload?.json?.trade_dates?.today);
  const expectedApi = sourceTradeDate
    ? [`/api/v1/yesterday/stats?limit=16&trade_date=${sourceTradeDate}`]
    : ['/api/v1/yesterday/stats?limit=16&trade_date='];
  const startCounts = captureExpectedCounts(expectedApi, apiResponses);
  const pickedLabel =
    (await weaknessLocator
      .first()
      .evaluate((node) => node.getAttribute('aria-label') || node.textContent || '')) || '';
  const weaknessPick = await clickAtIndex(weaknessLocator, 0, timeoutMs);
  const jumpedToYesterday = await waitForUrlIncludes(page, '/yesterday-stats?', timeoutMs);
  await waitForNewExpectedApiResponses(page, expectedApi, apiResponses, startCounts, timeoutMs);
  await Promise.all(apiPayloadReads);

  const jumpedUrl = page.url();
  const navigatedWithSection = jumpedUrl.includes(`section=${selectedSection.routeKey}`);
  const navigatedWithTradeDate = sourceTradeDate
    ? jumpedUrl.includes(`tradeDate=${sourceTradeDate}`)
    : true;
  const detailPayload = findLatestJsonPayload(apiPayloads, expectedApi[0]);
  const detailSection = findWeaknessSectionSnapshot(
    detailPayload?.json?.sections,
    selectedSection.routeKey,
  );
  const expectedText = ['\u7a7a\u5934\u6570\u636e'];
  const textCheck = await waitForExpectedText(page, expectedText, timeoutMs);
  const assertions = [
    ...summarizeWeaknessAssertions('overview selected weakness', selectedSection),
    {
      label: 'overview detail payload url',
      value: detailPayload?.url || '--',
    },
    {
      label: 'overview detail trade date',
      value:
        toText(detailPayload?.json?.trade_date) ||
        toText(detailPayload?.json?.trade_dates?.today) ||
        '--',
    },
    ...summarizeWeaknessAssertions('overview detail weakness', detailSection),
  ];
  const assertionFailures = [];

  if (!jumpedToYesterday) {
    assertionFailures.push('overview interaction expected to navigate to /yesterday-stats');
  }
  if (!navigatedWithSection) {
    assertionFailures.push(
      `overview interaction expected section=${selectedSection.routeKey} in URL, got ${jumpedUrl}`,
    );
  }
  if (!navigatedWithTradeDate) {
    assertionFailures.push(
      `overview interaction expected tradeDate=${sourceTradeDate} in URL, got ${jumpedUrl}`,
    );
  }
  if (!detailPayload) {
    assertionFailures.push(`missing JSON payload for ${expectedApi[0]} after overview interaction`);
  } else if (!detailSection) {
    assertionFailures.push(
      `overview detail payload missing weakness section ${selectedSection.routeKey}`,
    );
  } else {
    if (detailSection.total !== selectedSection.total) {
      assertionFailures.push(
        `overview weakness total mismatch for ${selectedSection.routeKey}: source ${selectedSection.total}, detail ${detailSection.total}`,
      );
    }
    if (
      isFilledText(selectedSection.firstCode) &&
      isFilledText(detailSection.firstCode) &&
      detailSection.firstCode !== selectedSection.firstCode
    ) {
      assertionFailures.push(
        `overview weakness first code mismatch for ${selectedSection.routeKey}: source ${selectedSection.firstCode}, detail ${detailSection.firstCode}`,
      );
    }
    if (selectedSection.regionCount > 0 && detailSection.regionCount === 0) {
      assertionFailures.push(
        `overview detail weakness ${selectedSection.routeKey} lost region data`,
      );
    }
    if (selectedSection.industryCount > 0 && detailSection.industryCount === 0) {
      assertionFailures.push(
        `overview detail weakness ${selectedSection.routeKey} lost industry data`,
      );
    }
  }

  await page.goBack();
  await page.waitForTimeout(1000);
  const returnedToOverview = await waitForUrlIncludes(page, '/overview', timeoutMs);
  await page.evaluate(() => {
    window.scrollTo(0, 0);
  });
  await page.waitForTimeout(250);

  return {
    description: 'open overview frontend build entry, then weakness tile and navigate to yesterday stats',
    selectors: [
      'role=button[name*=pw-shell-frontend-build-jobs]',
      'role=button[name*=任务调度]',
      'role=button[name*=pw-overview-frontend-build-jobs]',
      `role=button[name*=pw-overview-weakness-${selectedSection.routeKey}]`,
    ],
    picked: {
      jobs: jobsPick,
      weakness: {
        ...weaknessPick,
        label: normalizeForMatch(pickedLabel),
        routeKey: selectedSection.routeKey,
      },
    },
    assertions,
    assertionFailures: [
      ...(jumpedToJobs ? [] : ['overview frontend build action expected to navigate to /jobs']),
      ...(returnedFromJobs ? [] : ['overview frontend build action expected to return to /overview']),
      ...assertionFailures,
    ],
    expectedApi: jobsExpectedApi.concat(expectedApi),
    expectedText,
    missingExpectedText: textCheck.missingExpectedText,
    navigationOk:
      jumpedToJobs &&
      returnedFromJobs &&
      jumpedToYesterday &&
      navigatedWithSection &&
      navigatedWithTradeDate &&
      returnedToOverview,
    navigationDetails: {
      jumpedToJobs,
      returnedFromJobs,
      jobsAttempts,
      jumpedToYesterday,
      navigatedWithSection,
      navigatedWithTradeDate,
      returnedToOverview,
      routeKey: selectedSection.routeKey,
      jumpedUrl,
      currentUrl: page.url(),
    },
    missingExpectedApi: findMissingNewExpectedApi(
      jobsExpectedApi,
      apiResponses,
      jobsStartCounts,
    ).concat(findMissingNewExpectedApi(expectedApi, apiResponses, startCounts)),
  };
}

async function runAskAiInteraction(page, apiResponses, timeoutMs) {
  const refreshLocator = page.getByRole('button', {
    name: /^刷新上下文$/,
  });
  const expectedApi = ['/api/v1/ask-ai/context'];

  await waitForLocator(refreshLocator, timeoutMs);
  const startCounts = captureExpectedCounts(expectedApi, apiResponses);
  await activateLocatorTarget(refreshLocator.first(), timeoutMs);
  await waitForNewExpectedApiResponses(page, expectedApi, apiResponses, startCounts, timeoutMs);

  return {
    description: 'refresh ask ai context',
    selectors: ['role=button[name="刷新上下文"]'],
    expectedApi,
    missingExpectedApi: findMissingNewExpectedApi(expectedApi, apiResponses, startCounts),
  };
}

async function runYesterdayInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs) {
  const sourcePayload = findLatestJsonPayload(apiPayloads, '/api/v1/yesterday/stats');
  const selectedSection = pickWeaknessSectionSnapshot(sourcePayload?.json?.sections);
  if (!selectedSection) {
    return {
      description: 'open yesterday stats review link and navigate to limit review',
      selectors: ['role=button[name*=pw-yesterday-review-]'],
      picked: {
        skipped: true,
        reason: 'no weakness section snapshot available for current yesterday payload',
      },
      assertions: [],
      assertionFailures: sourcePayload
        ? ['unable to select a weakness section from yesterday payload']
        : ['missing JSON payload for /api/v1/yesterday/stats before yesterday interaction'],
      expectedApi: [],
      expectedText: [],
      missingExpectedText: [],
      navigationOk: false,
      navigationDetails: {
        currentUrl: page.url(),
      },
      missingExpectedApi: [],
    };
  }

  const reviewLocator = page.getByRole('button', {
    name: new RegExp(`pw-yesterday-review-${selectedSection.routeKey}`),
  });
  const sourceTradeDate =
    toText(sourcePayload?.json?.trade_date) ||
    toText(sourcePayload?.json?.trade_dates?.today);
  const expectedApi = sourceTradeDate
    ? [`/api/v1/review-page?trade_date=${sourceTradeDate}`]
    : ['/api/v1/review-page?'];
  const expectedText = ['\u6da8\u505c\u590d\u76d8', '\u590d\u76d8\u603b\u89c8'];
  const startCounts = captureExpectedCounts(expectedApi, apiResponses);

  const reviewPick = await clickPreferred(reviewLocator, timeoutMs);
  const jumpedToReview = await waitForUrlIncludes(page, '/limit-review?', timeoutMs);
  await waitForNewExpectedApiResponses(page, expectedApi, apiResponses, startCounts, timeoutMs);
  await Promise.all(apiPayloadReads);
  const jumpedUrl = page.url();
  const jumpedText = await waitForExpectedText(page, expectedText, timeoutMs);
  const navigatedWithSection = jumpedUrl.includes(`section=${selectedSection.routeKey}`);
  const navigatedWithTradeDate = sourceTradeDate
    ? jumpedUrl.includes(`tradeDate=${sourceTradeDate}`)
    : true;
  const reviewPayload = findLatestJsonPayload(apiPayloads, expectedApi[0]);
  const reviewSection = findWeaknessSectionSnapshot(
    reviewPayload?.json?.yesterday_stats?.sections,
    selectedSection.routeKey,
  );
  const assertions = [
    ...summarizeWeaknessAssertions('yesterday selected weakness', selectedSection),
    {
      label: 'review payload url',
      value: reviewPayload?.url || '--',
    },
    {
      label: 'review requested trade date',
      value: toText(reviewPayload?.json?.navigation?.requested_trade_date) || '--',
    },
    {
      label: 'review resolved trade date',
      value: toText(reviewPayload?.json?.navigation?.resolved_trade_date) || '--',
    },
    {
      label: 'review weakness trade date',
      value: toText(reviewPayload?.json?.yesterday_stats?.trade_date) || '--',
    },
    ...summarizeWeaknessAssertions('review nested weakness', reviewSection),
  ];
  const assertionFailures = [];

  if (!jumpedToReview) {
    assertionFailures.push('yesterday interaction expected to navigate to /limit-review');
  }
  if (!navigatedWithSection) {
    assertionFailures.push(
      `yesterday interaction expected section=${selectedSection.routeKey} in URL, got ${jumpedUrl}`,
    );
  }
  if (!navigatedWithTradeDate) {
    assertionFailures.push(
      `yesterday interaction expected tradeDate=${sourceTradeDate} in URL, got ${jumpedUrl}`,
    );
  }
  if (!reviewPayload) {
    assertionFailures.push(`missing JSON payload for ${expectedApi[0]} after yesterday interaction`);
  } else {
    if (toText(reviewPayload?.json?.navigation?.requested_trade_date) !== sourceTradeDate) {
      assertionFailures.push(
        `review requested trade date mismatch: expected ${sourceTradeDate}, got ${toText(reviewPayload?.json?.navigation?.requested_trade_date) || '--'}`,
      );
    }
    if (!isFilledText(reviewPayload?.json?.navigation?.resolved_trade_date)) {
      assertionFailures.push('review resolved trade date expected to be non-empty');
    }
    if (!reviewSection) {
      assertionFailures.push(
        `review payload missing weakness section ${selectedSection.routeKey}`,
      );
    }
    if (
      toText(reviewPayload?.json?.yesterday_stats?.trade_date) !==
      toText(reviewPayload?.json?.navigation?.resolved_trade_date)
    ) {
      assertionFailures.push(
        `review weakness trade date expected to match resolved trade date, got ${toText(reviewPayload?.json?.yesterday_stats?.trade_date) || '--'} vs ${toText(reviewPayload?.json?.navigation?.resolved_trade_date) || '--'}`,
      );
    }
    if (
      !Array.isArray(reviewPayload?.json?.navigation?.available_trade_dates) ||
      reviewPayload.json.navigation.available_trade_dates.length === 0
    ) {
      assertionFailures.push('review available trade dates expected to be non-empty');
    }
  }

  await page.goBack();
  await page.waitForTimeout(1000);
  const returnedToYesterday = await waitForUrlIncludes(page, '/yesterday-stats', timeoutMs);

  return {
    description: 'open yesterday stats review link and navigate to limit review',
    selectors: [`role=button[name*=pw-yesterday-review-${selectedSection.routeKey}]`],
    picked: {
      ...reviewPick,
      routeKey: selectedSection.routeKey,
    },
    assertions,
    assertionFailures,
    expectedApi,
    expectedText,
    missingExpectedText: jumpedText.missingExpectedText,
    navigationOk:
      jumpedToReview && navigatedWithSection && navigatedWithTradeDate && returnedToYesterday,
    navigationDetails: {
      jumpedToReview,
      navigatedWithSection,
      navigatedWithTradeDate,
      returnedToYesterday,
      currentUrl: page.url(),
      jumpedUrl,
    },
    missingExpectedApi: findMissingNewExpectedApi(expectedApi, apiResponses, startCounts),
  };
}

async function runJobsInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs) {
  const refreshLocator = page.getByRole('button', {
    name: /刷新快照/,
  });
  const expectedApi = ['/internal/jobs/page?force_refresh=true'];
  const assertions = [];
  const assertionFailures = [];

  await waitForLocator(refreshLocator, timeoutMs);
  const startCounts = captureExpectedCounts(expectedApi, apiResponses);
  await activateLocatorTarget(refreshLocator.first(), timeoutMs);
  await waitForNewExpectedApiResponses(page, expectedApi, apiResponses, startCounts, timeoutMs);
  await Promise.all(apiPayloadReads);

  const payload = findLatestJsonPayload(apiPayloads, '/internal/jobs/page');
  const jobs = Array.isArray(payload?.json?.jobs) ? payload.json.jobs : [];
  const triggerableJob = jobs.find((job) => job?.trigger_allowed && isFilledText(job?.job_code));
  const triggerExpectedApi = [];
  let triggerClick = null;
  if (triggerableJob) {
    const jobCode = toText(triggerableJob.job_code);
    const triggerLocator = page.getByRole('button', {
      name: new RegExp(`^${escapeRegExp(`pw-jobs-trigger-${jobCode}`)}$`),
    });
    triggerExpectedApi.push('/internal/jobs/');
    const triggerStartCounts = captureExpectedCountsAnyStatus(triggerExpectedApi, apiResponses);
    let activation;
    await revealLocatorByPageScroll(page, triggerLocator, Math.min(timeoutMs, 6000));
    if ((await triggerLocator.count()) > 0) {
      await waitForLocatorAttached(triggerLocator, timeoutMs);
      activation = await activateLocatorTarget(triggerLocator.first(), timeoutMs);
    } else {
      activation = await clickButtonByContainedText(page, '手动触发', timeoutMs);
    }
    await waitForNewExpectedApiResponsesAnyStatus(
      page,
      triggerExpectedApi,
      apiResponses,
      triggerStartCounts,
      timeoutMs,
    );
    triggerClick = {
      jobCode,
      name: toText(triggerableJob.name),
      activation,
      missingExpectedApi: findMissingNewExpectedApiAnyStatus(
        triggerExpectedApi,
        apiResponses,
        triggerStartCounts,
      ),
    };
    if (triggerClick.missingExpectedApi.length > 0) {
      assertionFailures.push(
        `jobs trigger expected internal POST after clicking a trigger control: ${triggerClick.missingExpectedApi.join(', ')}`,
      );
    }
  }

  assertions.push(
    { label: 'jobs refresh api', value: expectedApi[0] },
    { label: 'jobs triggerable jobs', value: jobs.filter((job) => job?.trigger_allowed).length },
    { label: 'jobs trigger clicked', value: triggerClick?.jobCode || '--' },
  );

  return {
    description: 'refresh jobs snapshot and enqueue a manual trigger when available',
    selectors: ['role=button[name*=刷新快照]', 'role=button[name*=pw-jobs-trigger-]'],
    expectedApi: expectedApi.concat(triggerExpectedApi),
    assertions,
    assertionFailures,
    triggerClick,
    missingExpectedApi: findMissingNewExpectedApi(expectedApi, apiResponses, startCounts),
  };
}

async function runNewsInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs) {
  await Promise.all(apiPayloadReads);
  const payload = findLatestJsonPayload(apiPayloads, '/api/v1/news/page');
  const viewportHeight = page.viewportSize()?.height || DEFAULT_VIEWPORT.height;
  const includeDeepContentText = viewportHeight >= 900;
  const tabTargets = [
    {
      name: 'hot_news',
      selector: 'role=button[name*=pw-news-tab-hot_news]',
      expectedText: [
        '\u5f53\u524d\u680f\u76ee\u4e3a \u70ed\u70b9\u8d44\u8baf',
      ],
    },
    {
      name: 'today_hot',
      selector: 'role=button[name*=pw-news-tab-today_hot]',
      expectedText: [
        '\u5f53\u524d\u680f\u76ee\u4e3a \u4eca\u65e5\u70ed\u70b9',
      ],
    },
    {
      name: 'fast_news',
      selector: 'role=button[name*=pw-news-tab-fast_news]',
      expectedText: [
        '\u5f53\u524d\u680f\u76ee\u4e3a 7x24 \u5feb\u8baf',
        '\u5feb\u8baf\u7b5b\u9009',
      ],
    },
    {
      name: 'timeline',
      selector: 'role=button[name*=pw-news-tab-timeline]',
      expectedText: [
        '\u5f53\u524d\u680f\u76ee\u4e3a \u8d22\u7ecf\u65e5\u5386',
      ],
    },
    {
      name: 'monthly_patterns',
      selector: 'role=button[name*=pw-news-tab-monthly_patterns]',
      expectedText: [
        '\u5f53\u524d\u680f\u76ee\u4e3a \u6708\u5ea6\u884c\u60c5',
      ],
    },
  ];
  const steps = [];
  const assertionFailures = [];
  const assertions = [
    {
      label: 'news payload url',
      value: payload?.url || '--',
    },
  ];

  if (!payload) {
    assertionFailures.push('missing JSON payload for /api/v1/news/page before interaction');
  }

  for (const target of tabTargets) {
    const tabLocator = page.getByRole('button', {
      name: new RegExp(`pw-news-tab-${target.name}`),
    });
    const snapshot = buildNewsTabSnapshot(payload?.json, target.name);
    const tabPick = await clickPreferred(tabLocator, timeoutMs);
    await page.waitForTimeout(600);
    const baseExpectedText = includeDeepContentText
      ? target.expectedText
      : target.expectedText.filter(
          (value) => value !== '\u5feb\u8baf\u7b5b\u9009' && !/^[1-5]\/5$/.test(value),
        );
    const stepExpectedText = uniqueFilledStrings(
      baseExpectedText.concat(includeDeepContentText ? snapshot.expectedTexts : []),
    );
    const textCheck = await waitForExpectedText(page, stepExpectedText, timeoutMs);
    assertions.push(...summarizeNewsAssertions(`news ${target.name}`, snapshot));
    if (payload && snapshot.count === 0) {
      assertionFailures.push(`news ${target.name} expected payload items > 0`);
    }
    steps.push({
      name: target.name,
      selector: target.selector,
      picked: tabPick,
      expectedText: stepExpectedText,
      missingExpectedText: textCheck.missingExpectedText,
      snapshotSummary: snapshot.summary,
    });
  }

  const refreshLocator = page.getByRole('button', {
    name: /^\u5237\u65b0$/,
  });
  const expectedApi = ['/api/v1/news/page'];
  const startCounts = captureExpectedCounts(expectedApi, apiResponses);
  const refreshClick = await clickPreferred(refreshLocator, timeoutMs);
  await waitForNewExpectedApiResponses(page, expectedApi, apiResponses, startCounts, timeoutMs);

  const missingExpectedText = steps
    .flatMap((step) => step.missingExpectedText)
    .filter((value, index, array) => array.indexOf(value) === index);

  return {
    description: 'switch news workspace tabs and refresh current tab',
    selectors: tabTargets.map((target) => target.selector).concat(['role=button[name="刷新"]']),
    steps,
    refreshClick,
    assertions,
    assertionFailures,
    expectedApi,
    expectedText: steps.flatMap((step) => step.expectedText),
    missingExpectedText,
    missingExpectedApi: findMissingNewExpectedApi(expectedApi, apiResponses, startCounts),
  };
}

async function runPageInteraction(page, item, apiResponses, apiPayloads, apiPayloadReads, timeoutMs) {
  switch (item.name) {
    case 'overview':
      return runOverviewInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs);
    case 'auction':
      return runAuctionInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs);
    case 'node':
      return runNodeInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs);
    case 'market_center':
      return runMarketCenterInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs);
    case 'limit_review':
      return runLimitReviewInteraction(page, apiResponses, timeoutMs);
    case 'yesterday':
      return runYesterdayInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs);
    case 'plate_rotation':
      return runPlateRotationInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs);
    case 'news':
      return runNewsInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs);
    case 'ask_ai':
      return runAskAiInteraction(page, apiResponses, timeoutMs);
    case 'jobs':
      return runJobsInteraction(page, apiResponses, apiPayloads, apiPayloadReads, timeoutMs);
    default:
      return null;
  }
}

async function capturePage(browser, item, options) {
  const context = await browser.newContext({
    viewport: options.viewport || DEFAULT_VIEWPORT,
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();
  const apiResponses = [];
  const apiPayloads = [];
  const apiPayloadReads = [];
  const requestFailures = [];
  const pageErrors = [];
  const consoleErrors = [];

  page.on('response', (response) => {
    const url = response.url();
    if (!isTrackedApiUrl(url)) {
      return;
    }
    apiResponses.push({
      url,
      method: response.request().method(),
      status: response.status(),
    });
    if (!shouldCaptureJsonPayload(item.name, url, options)) {
      return;
    }
    apiPayloadReads.push(
      (async () => {
        try {
          const text = await response.text();
          apiPayloads.push({
            url,
            status: response.status(),
            json: parseJsonSafely(text),
          });
        } catch (error) {
          apiPayloads.push({
            url,
            status: response.status(),
            json: null,
            error: error.message || String(error),
          });
        }
      })(),
    );
  });
  page.on('requestfailed', (request) => {
    const url = request.url();
    if (!isTrackedApiUrl(url)) {
      return;
    }
    requestFailures.push({
      url,
      method: request.method(),
      errorText: request.failure()?.errorText || 'request failed',
    });
  });
  page.on('pageerror', (error) => {
    pageErrors.push(error.message || String(error));
  });
  page.on('console', (message) => {
    if (message.type() === 'error') {
      consoleErrors.push(message.text());
    }
  });

  try {
    const url = `${joinHashUrl(options.baseUrl, item.route)}?ts=${options.stamp}`;
    page.setDefaultNavigationTimeout(Math.max(30000, options.waitMs + 15000));

    const expectedApi = expectedApiForPage(item.name, options);
    const expectedText = expectedTextForPage(item.name, options.viewport);
    let navigationError = null;
    let interactionResult = null;
    let missingExpectedText = expectedText;
    let pageText = '';

    try {
      await page.goto(url, { waitUntil: 'load' });
      await waitForExpectedApiResponses(page, expectedApi, apiResponses, options.waitMs);
      await enableAccessibilityIfNeeded(page);
      const textCheck = await waitForExpectedText(page, expectedText, options.waitMs);
      missingExpectedText = textCheck.missingExpectedText;
      pageText = textCheck.pageText;
      if (!options.skipInteractions) {
        interactionResult = await runPageInteraction(
          page,
          item,
          apiResponses,
          apiPayloads,
          apiPayloadReads,
          options.waitMs,
        );
      }
    } catch (error) {
      navigationError = error;
    }

    await Promise.all(apiPayloadReads);

    const screenshot = path.join(options.outputDir, `${item.name}.png`);
    await page.screenshot({ path: screenshot, fullPage: true });

    const missingExpectedApi = findMissingExpectedApi(expectedApi, apiResponses);
    const failedExpectedApi = findBlockingRequestFailures(
      expectedApi,
      requestFailures,
      apiResponses,
    );
    const interactionFailedApi = interactionResult
      ? findBlockingRequestFailures(
          interactionResult.expectedApi,
          requestFailures,
          apiResponses,
        )
      : [];
    const interactionMissingText = interactionResult?.missingExpectedText || [];
    const interactionNavigationOk = interactionResult?.navigationOk ?? true;
    const interactionAssertionFailures = interactionResult?.assertionFailures || [];
    const dataAssertions = buildDataAssertions(item.name, apiPayloads, options);
    const designAssertions = await buildDesignAssertions(page, item.name, pageText, expectedText);
    const consoleErrorFailures = findConsoleErrorFailures(consoleErrors);
    const interactionOk =
      interactionResult == null ||
      (
        interactionResult.missingExpectedApi.length === 0 &&
        interactionFailedApi.length === 0 &&
        interactionMissingText.length === 0 &&
        interactionNavigationOk &&
        interactionAssertionFailures.length === 0
      );

    const result = {
      name: item.name,
      route: item.route,
      url,
      screenshot,
      viewport: options.viewport || DEFAULT_VIEWPORT,
      expectedApi,
      expectedText,
      missingExpectedApi,
      missingExpectedText,
      pageTextSample: summarizeText(pageText),
      failedExpectedApi,
      dataAssertions: dataAssertions.assertions,
      dataAssertionFailures: dataAssertions.failures,
      frontendSkillDesignContract: FRONTEND_SKILL_APP_DESIGN_CONTRACT,
      designAssertions: designAssertions.assertions,
      designAssertionFailures: designAssertions.failures,
      skipInteractions: options.skipInteractions === true,
      interaction: interactionResult
        ? {
            ...interactionResult,
            failedExpectedApi: interactionFailedApi,
            ok: interactionOk,
          }
        : null,
      apiResponses,
      requestFailures,
      pageErrors,
      consoleErrors,
      consoleErrorFailures,
      navigationError: navigationError ? navigationError.message || String(navigationError) : null,
      ok:
        navigationError === null &&
        missingExpectedApi.length === 0 &&
        missingExpectedText.length === 0 &&
        failedExpectedApi.length === 0 &&
        dataAssertions.failures.length === 0 &&
        designAssertions.failures.length === 0 &&
        pageErrors.length === 0 &&
        consoleErrorFailures.length === 0 &&
        interactionOk,
    };

    if (result.ok) {
      const interactionLabel = result.interaction ? ` + interaction ${result.interaction.description}` : '';
      console.log(`[smoke] verified ${item.name}${interactionLabel}: ${screenshot}`);
    } else {
      console.error(
        `[smoke] verification failed for ${item.name}\n` +
          `navigation: ${result.navigationError || 'ok'}\n` +
          `missing: ${missingExpectedApi.join(', ') || 'none'}\n` +
          `missing text: ${missingExpectedText.join(', ') || 'none'}\n` +
          `data assertions: ${dataAssertions.failures.join(' | ') || 'none'}\n` +
          `design assertions: ${designAssertions.failures.join(' | ') || 'none'}\n` +
          `interaction missing: ${
            result.interaction?.missingExpectedApi.join(', ') || 'none'
          }\n` +
          `interaction missing text: ${
            interactionMissingText.join(', ') || 'none'
          }\n` +
          `interaction assertions: ${
            interactionAssertionFailures.join(' | ') || 'none'
          }\n` +
          `interaction navigation: ${
            interactionNavigationOk
              ? 'ok'
              : JSON.stringify(result.interaction?.navigationDetails || {})
          }\n` +
          `responses:\n${summarizeApiEntries(apiResponses)}\n` +
          `request failures: ${
            [...failedExpectedApi, ...interactionFailedApi]
              .map((entry) => `${entry.method} ${entry.url}`)
              .join('\n') || 'none'
          }\n` +
          `console error failures:\n${consoleErrorFailures.join('\n') || 'none'}\n` +
          `page errors:\n${pageErrors.join('\n') || 'none'}\n` +
          `page text sample:\n${summarizeText(pageText)}`,
      );
    }

    return result;
  } finally {
    await context.close();
  }
}

async function capturePageWithRetry(browser, item, options) {
  const attempts = 2;
  let lastResult = null;

  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const result = await capturePage(browser, item, options);
    if (result.ok || attempt === attempts) {
      return result;
    }
    lastResult = result;
    console.warn(`[smoke] retrying ${item.name} after cold-start failure (${attempt}/${attempts})`);
  }

  return lastResult;
}

async function main() {
  const { baseUrl, outputDir, waitMs, pages, viewport, skipInteractions } = parseArgs(
    process.argv.slice(2),
  );
  if (pages.length === 0) {
    throw new Error('No pages selected for Playwright smoke run.');
  }
  if (!baseUrl) {
    throw new Error('Pass --base-url or set NIUNIU_FRONTEND_BASE_URL.');
  }

  fs.mkdirSync(outputDir, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  const stamp = Date.now();
  const report = [];
  console.log(
    `[smoke] viewport: ${viewport.width}x${viewport.height}${
      skipInteractions ? ' (layout-only)' : ''
    }`,
  );

  try {
    for (const item of pages) {
      try {
        const result = await capturePageWithRetry(browser, item, {
          baseUrl,
          outputDir,
          waitMs,
          viewport,
          skipInteractions,
          stamp,
        });
        report.push(result);
      } catch (error) {
        report.push({
          name: item.name,
          route: item.route,
          url: `${joinHashUrl(baseUrl, item.route)}?ts=${stamp}`,
          screenshot: null,
          viewport,
          expectedApi: expectedApiForPage(item.name, { skipInteractions }),
          expectedText: expectedTextForPage(item.name, viewport),
          missingExpectedApi: expectedApiForPage(item.name, { skipInteractions }),
          missingExpectedText: expectedTextForPage(item.name, viewport),
          failedExpectedApi: [],
          dataAssertions: [],
          dataAssertionFailures: [],
          frontendSkillDesignContract: FRONTEND_SKILL_APP_DESIGN_CONTRACT,
          designAssertions: [],
          designAssertionFailures: [],
          skipInteractions,
          interaction: null,
          apiResponses: [],
          requestFailures: [],
          pageErrors: [],
          consoleErrors: [],
          consoleErrorFailures: [],
          navigationError: error.message || String(error),
          ok: false,
        });
        console.error(`[smoke] failed to capture ${item.name}: ${error.stack || error.message}`);
      }
    }
  } finally {
    await browser.close();
  }

  const reportPath = path.join(outputDir, 'report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`[smoke] report: ${reportPath}`);

  const failedPages = report.filter((item) => !item.ok);
  if (failedPages.length > 0) {
    throw new Error(
      `API verification failed for page(s): ${failedPages.map((item) => item.name).join(', ')}`,
    );
  }
}

main().catch((error) => {
  console.error(`[smoke] failed: ${error.stack || error.message}`);
  process.exit(1);
});
