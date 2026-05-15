import '../../core/network/api_client.dart';

class TableColumnData {
  const TableColumnData({
    required this.key,
    required this.label,
    this.align = 'left',
    this.width,
  });

  final String key;
  final String label;
  final String align;
  final double? width;

  factory TableColumnData.fromJson(Map<String, dynamic> json) {
    return TableColumnData(
      key: json['key'] as String? ?? '--',
      label: json['label'] as String? ?? '--',
      align: json['align'] as String? ?? 'left',
      width: (json['width'] as num?)?.toDouble(),
    );
  }
}

class TableRowItemData {
  const TableRowItemData({
    required this.cells,
  });

  final List<String> cells;

  factory TableRowItemData.fromJson(Map<String, dynamic> json) {
    return TableRowItemData(
      cells: (json['cells'] as List<dynamic>? ?? const [])
          .map((cell) => cell.toString())
          .toList(growable: false),
    );
  }
}

class TableSectionData {
  const TableSectionData({
    required this.key,
    required this.title,
    required this.columns,
    this.columnDefs = const [],
    required this.rows,
    this.items = const [],
    required this.total,
  });

  final String key;
  final String title;
  final List<String> columns;
  final List<TableColumnData> columnDefs;
  final List<List<String>> rows;
  final List<TableRowItemData> items;
  final int total;

  List<TableColumnData> get displayColumns {
    if (columnDefs.isNotEmpty) {
      return columnDefs;
    }
    return columns.map(_inferTableColumnData).toList(growable: false);
  }

  List<List<String>> get displayRows {
    if (items.isNotEmpty) {
      return items.map((item) => item.cells).toList(growable: false);
    }
    return rows;
  }

  factory TableSectionData.fromJson(Map<String, dynamic> json) {
    return TableSectionData(
      key: json['key'] as String? ?? '--',
      title: json['title'] as String? ?? '--',
      columns: (json['columns'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      columnDefs: (json['column_defs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TableColumnData.fromJson)
          .toList(growable: false),
      rows: (json['rows'] as List<dynamic>? ?? const [])
          .map(
            (row) => (row as List<dynamic>? ?? const [])
                .map((cell) => cell.toString())
                .toList(growable: false),
          )
          .toList(growable: false),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TableRowItemData.fromJson)
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class TableSectionsSnapshot {
  const TableSectionsSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    required this.tables,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final List<TableSectionData> tables;

  factory TableSectionsSnapshot.fromJson(Map<String, dynamic> json) {
    return TableSectionsSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      tables: (json['tables'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TableSectionData.fromJson)
          .toList(growable: false),
    );
  }
}

TableColumnData _inferTableColumnData(String rawKey) {
  final key = rawKey.trim();
  final preset = _tableColumnPresets[key];
  return TableColumnData(
    key: key,
    label: preset?.label ?? _titleizeTableColumn(key),
    align: preset?.align ?? 'left',
    width: preset?.width,
  );
}

String _titleizeTableColumn(String value) {
  return value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

class _TableColumnPreset {
  const _TableColumnPreset({
    required this.label,
    required this.align,
    this.width,
  });

  final String label;
  final String align;
  final double? width;
}

const _tableColumnPresets = <String, _TableColumnPreset>{
  'seq': _TableColumnPreset(label: '序号', align: 'center', width: 54),
  'code': _TableColumnPreset(label: '代码', align: 'center', width: 88),
  'name': _TableColumnPreset(label: '名称', align: 'left', width: 140),
  'change_pct': _TableColumnPreset(
    label: '涨跌幅',
    align: 'right',
    width: 92,
  ),
  'latest_price': _TableColumnPreset(
    label: '最新价',
    align: 'right',
    width: 92,
  ),
  'limit_price': _TableColumnPreset(
    label: '涨停价',
    align: 'right',
    width: 92,
  ),
  'amount': _TableColumnPreset(label: '成交额', align: 'right', width: 110),
  'float_market_cap': _TableColumnPreset(
    label: '流通市值',
    align: 'right',
    width: 110,
  ),
  'total_market_cap': _TableColumnPreset(
    label: '总市值',
    align: 'right',
    width: 110,
  ),
  'turnover_rate': _TableColumnPreset(
    label: '换手率',
    align: 'right',
    width: 92,
  ),
  'seal_amount': _TableColumnPreset(
    label: '封板资金',
    align: 'right',
    width: 116,
  ),
  'first_limit_time': _TableColumnPreset(
    label: '首次封板时间',
    align: 'center',
    width: 106,
  ),
  'last_limit_time': _TableColumnPreset(
    label: '最后封板时间',
    align: 'center',
    width: 106,
  ),
  'break_count': _TableColumnPreset(
    label: '炸板次数',
    align: 'center',
    width: 88,
  ),
  'limit_stats': _TableColumnPreset(
    label: '涨停统计',
    align: 'center',
    width: 96,
  ),
  'board_count': _TableColumnPreset(
    label: '连板数',
    align: 'center',
    width: 88,
  ),
  'yesterday_limit_time': _TableColumnPreset(
    label: '昨日封板时间',
    align: 'center',
    width: 126,
  ),
  'yesterday_board_count': _TableColumnPreset(
    label: '昨日连板数',
    align: 'center',
    width: 124,
  ),
  'change_speed': _TableColumnPreset(
    label: '涨速',
    align: 'right',
    width: 92,
  ),
  'amplitude': _TableColumnPreset(
    label: '振幅',
    align: 'right',
    width: 92,
  ),
  'new_high': _TableColumnPreset(
    label: '是否新高',
    align: 'center',
    width: 88,
  ),
  'volume_ratio': _TableColumnPreset(
    label: '量比',
    align: 'right',
    width: 104,
  ),
  'reason': _TableColumnPreset(label: '入选理由', align: 'left', width: 220),
  'open_days': _TableColumnPreset(
    label: '开板几日',
    align: 'center',
    width: 92,
  ),
  'open_board_date': _TableColumnPreset(
    label: '开板日期',
    align: 'center',
    width: 124,
  ),
  'listing_date': _TableColumnPreset(
    label: '上市日期',
    align: 'center',
    width: 116,
  ),
  'dynamic_pe': _TableColumnPreset(
    label: '动态市盈率',
    align: 'right',
    width: 98,
  ),
  'board_amount': _TableColumnPreset(
    label: '板上成交额',
    align: 'right',
    width: 114,
  ),
  'continuous_limit_down': _TableColumnPreset(
    label: '连续跌停',
    align: 'center',
    width: 132,
  ),
  'open_count': _TableColumnPreset(
    label: '开板次数',
    align: 'center',
    width: 92,
  ),
  'industry_name': _TableColumnPreset(
    label: '所属行业',
    align: 'left',
    width: 132,
  ),
  'symbol': _TableColumnPreset(label: '代码', align: 'center', width: 88),
  'stock_code': _TableColumnPreset(label: '代码', align: 'center', width: 88),
  'stock_name': _TableColumnPreset(label: '名称', align: 'left', width: 140),
};

class AuctionLiveItemData {
  const AuctionLiveItemData({
    required this.code,
    required this.name,
    required this.concepts,
    required this.lianban,
    required this.amounts,
    required this.zhangfu,
  });

  final String code;
  final String name;
  final List<String> concepts;
  final String lianban;
  final List<String> amounts;
  final String zhangfu;

  factory AuctionLiveItemData.fromJson(Map<String, dynamic> json) {
    return AuctionLiveItemData(
      code: json['code'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      concepts: (json['concepts'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      lianban: json['lianban'] as String? ?? '',
      amounts: (json['amounts'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      zhangfu: json['zhangfu'] as String? ?? '',
    );
  }
}

class AuctionLiveSnapshot {
  const AuctionLiveSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    required this.title,
    required this.total,
    required this.items,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String? title;
  final int total;
  final List<AuctionLiveItemData> items;

  factory AuctionLiveSnapshot.fromJson(Map<String, dynamic> json) {
    return AuctionLiveSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      title: json['title']?.toString(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AuctionLiveItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class AuctionPageData {
  const AuctionPageData({
    required this.live,
    required this.ranks,
  });

  final AuctionLiveSnapshot live;
  final TableSectionsSnapshot ranks;
}

class LimitReviewTableColumnData {
  const LimitReviewTableColumnData({
    required this.key,
    required this.label,
    this.align = 'left',
    this.width,
  });

  final String key;
  final String label;
  final String align;
  final double? width;

  factory LimitReviewTableColumnData.fromJson(Map<String, dynamic> json) {
    return LimitReviewTableColumnData(
      key: json['key'] as String? ?? '--',
      label: json['label'] as String? ?? '--',
      align: json['align'] as String? ?? 'left',
      width: (json['width'] as num?)?.toDouble(),
    );
  }
}

class LimitReviewItemData {
  const LimitReviewItemData({
    required this.sortIndex,
    required this.stockCode,
    required this.stockName,
    required this.changePct,
    required this.preClosePrice,
    required this.boardCount,
    required this.lianbanText,
    required this.boardShape,
    required this.firstLimitTime,
    required this.finalLimitTime,
    required this.amountYi,
    required this.floatMarketCapYi,
    required this.totalMarketCapYi,
    required this.turnoverRate,
    required this.reason,
    this.cells = const [],
    this.rawRow = const [],
  });

  final int sortIndex;
  final String? stockCode;
  final String? stockName;
  final double? changePct;
  final double? preClosePrice;
  final int? boardCount;
  final String? lianbanText;
  final String? boardShape;
  final String? firstLimitTime;
  final String? finalLimitTime;
  final double? amountYi;
  final double? floatMarketCapYi;
  final double? totalMarketCapYi;
  final double? turnoverRate;
  final String? reason;
  final List<String> cells;
  final List<String> rawRow;

  String? get marketTag => inferStockMarketTag(stockCode);

  factory LimitReviewItemData.fromJson(Map<String, dynamic> json) {
    return LimitReviewItemData(
      sortIndex: (json['sort_index'] as num?)?.toInt() ?? 0,
      stockCode: _normalizeLimitReviewText(json['stock_code']),
      stockName: _normalizeLimitReviewText(json['stock_name']),
      changePct: _limitReviewToDouble(json['change_pct']),
      preClosePrice: _limitReviewToDouble(json['pre_close_price']),
      boardCount: _limitReviewToInt(json['board_count']),
      lianbanText: _normalizeLimitReviewText(json['lianban_text']),
      boardShape: _normalizeLimitReviewText(json['board_shape']),
      firstLimitTime: _normalizeLimitReviewText(json['first_limit_time']),
      finalLimitTime: _normalizeLimitReviewText(json['final_limit_time']),
      amountYi: _limitReviewToDouble(json['amount_yi']),
      floatMarketCapYi: _limitReviewToDouble(json['float_market_cap_yi']),
      totalMarketCapYi: _limitReviewToDouble(json['total_market_cap_yi']),
      turnoverRate: _limitReviewToDouble(json['turnover_rate']),
      reason: _normalizeLimitReviewText(json['reason']),
      cells: (json['cells'] as List<dynamic>? ?? const [])
          .map((cell) => cell.toString())
          .toList(growable: false),
      rawRow: const [],
    );
  }

  factory LimitReviewItemData.fromRow(
    List<String> row, {
    int sortIndex = 0,
  }) {
    final normalizedRow =
        row.map((cell) => cell.toString().trim()).toList(growable: false);
    final identity = _resolveLimitReviewIdentity(normalizedRow);
    final reason = normalizedRow.length > 13
        ? normalizedRow.skip(13).where((cell) => cell.isNotEmpty).join(' / ')
        : normalizedRow.length > 2
            ? normalizedRow.skip(2).where((cell) => cell.isNotEmpty).join(' / ')
            : null;

    return LimitReviewItemData(
      sortIndex: sortIndex,
      stockCode: identity.$1,
      stockName: identity.$2,
      changePct: normalizedRow.length > 2
          ? _limitReviewParseNumber(normalizedRow[2])
          : null,
      preClosePrice: normalizedRow.length > 3
          ? _limitReviewParseNumber(normalizedRow[3])
          : null,
      boardCount:
          normalizedRow.length > 4 ? _limitReviewToInt(normalizedRow[4]) : null,
      lianbanText: normalizedRow.length > 5
          ? _normalizeLimitReviewText(normalizedRow[5])
          : null,
      boardShape: normalizedRow.length > 6
          ? _normalizeLimitReviewText(normalizedRow[6])
          : null,
      firstLimitTime: normalizedRow.length > 7
          ? _normalizeLimitReviewText(normalizedRow[7])
          : null,
      finalLimitTime: normalizedRow.length > 8
          ? _normalizeLimitReviewText(normalizedRow[8])
          : null,
      amountYi: normalizedRow.length > 9
          ? _limitReviewParseNumber(normalizedRow[9])
          : null,
      floatMarketCapYi: normalizedRow.length > 10
          ? _limitReviewParseNumber(normalizedRow[10])
          : null,
      totalMarketCapYi: normalizedRow.length > 11
          ? _limitReviewParseNumber(normalizedRow[11])
          : null,
      turnoverRate: normalizedRow.length > 12
          ? _limitReviewParseNumber(normalizedRow[12])
          : null,
      reason: _normalizeLimitReviewText(reason),
      cells: const [],
      rawRow: normalizedRow,
    );
  }

  List<String> toTableCells({
    List<LimitReviewTableColumnData> columns = const [],
  }) {
    if (cells.isNotEmpty) {
      return cells.map(_normalizeLimitReviewDisplayText).toList(
            growable: false,
          );
    }
    if (rawRow.isNotEmpty) {
      return rawRow.map(_normalizeLimitReviewDisplayText).toList(
            growable: false,
          );
    }
    if (columns.isEmpty) {
      return _defaultStructuredLimitReviewColumns
          .map((column) => _cellTextForColumnKey(column.key))
          .toList(growable: false);
    }

    return columns
        .map((column) => _cellTextForColumnKey(column.key))
        .toList(growable: false);
  }

  String _cellTextForColumnKey(String key) {
    return switch (key) {
      'stock_name' => stockName ?? '--',
      'stock_code' => stockCode ?? '--',
      'change_pct' => _formatLimitReviewSignedPercent(changePct),
      'pre_close_price' => _formatLimitReviewNumber(preClosePrice),
      'board_count' => boardCount?.toString() ?? '--',
      'lianban_text' => lianbanText ?? '--',
      'board_shape' => boardShape ?? '--',
      'first_limit_time' => firstLimitTime ?? '--',
      'final_limit_time' => finalLimitTime ?? '--',
      'amount_yi' => _formatLimitReviewYi(amountYi),
      'float_market_cap_yi' => _formatLimitReviewYi(floatMarketCapYi),
      'total_market_cap_yi' => _formatLimitReviewYi(totalMarketCapYi),
      'turnover_rate' => _formatLimitReviewPercent(turnoverRate),
      'reason' || 'theme' => reason ?? '--',
      _ => '--',
    };
  }
}

class LimitReviewGroupData {
  const LimitReviewGroupData({
    required this.name,
    required this.count,
    required this.items,
    this.columns = const [],
    required this.rows,
  });

  final String name;
  final String count;
  final List<LimitReviewItemData> items;
  final List<LimitReviewTableColumnData> columns;
  final List<List<String>> rows;

  List<LimitReviewItemData> get displayItems {
    if (items.isNotEmpty) {
      return items;
    }
    return List<LimitReviewItemData>.generate(
      rows.length,
      (index) => LimitReviewItemData.fromRow(rows[index], sortIndex: index),
      growable: false,
    );
  }

  List<LimitReviewTableColumnData> get displayColumns {
    if (columns.isNotEmpty) {
      return columns;
    }
    final sampleRow = rows.isNotEmpty
        ? rows.first
        : items.isNotEmpty
            ? (items.first.cells.isNotEmpty
                ? items.first.cells
                : items.first.rawRow)
            : const <String>[];
    return _inferLimitReviewColumns(sampleRow);
  }

  factory LimitReviewGroupData.fromJson(Map<String, dynamic> json) {
    return LimitReviewGroupData(
      name: json['name'] as String? ?? '--',
      count: json['count'] as String? ?? '--',
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LimitReviewItemData.fromJson)
          .toList(growable: false),
      columns: (json['columns'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LimitReviewTableColumnData.fromJson)
          .toList(growable: false),
      rows: (json['rows'] as List<dynamic>? ?? const [])
          .map(
            (row) => (row as List<dynamic>? ?? const [])
                .map((cell) => cell.toString())
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }
}

class LimitReviewSnapshot {
  const LimitReviewSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    required this.totalGroups,
    required this.totalStocks,
    required this.maxBoardHeight,
    required this.groups,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final int totalGroups;
  final int totalStocks;
  final int? maxBoardHeight;
  final List<LimitReviewGroupData> groups;

  factory LimitReviewSnapshot.fromJson(Map<String, dynamic> json) {
    return LimitReviewSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      totalGroups: (json['total_groups'] as num?)?.toInt() ?? 0,
      totalStocks: (json['total_stocks'] as num?)?.toInt() ?? 0,
      maxBoardHeight: (json['max_board_height'] as num?)?.toInt(),
      groups: (json['groups'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LimitReviewGroupData.fromJson)
          .toList(growable: false),
    );
  }
}

String? _normalizeLimitReviewText(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == '-' || text == '--') {
    return null;
  }
  return text;
}

double? _limitReviewToDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return _limitReviewParseNumber(value.toString());
}

int? _limitReviewToInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  final number = _limitReviewParseNumber(value.toString());
  return number?.toInt();
}

double? _limitReviewParseNumber(String? value) {
  final text = _normalizeLimitReviewText(value);
  if (text == null) {
    return null;
  }
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(
    text.replaceAll(',', '').replaceAll('，', ''),
  );
  if (match == null) {
    return null;
  }
  return double.tryParse(match.group(0)!);
}

(String?, String?) _resolveLimitReviewIdentity(List<String> row) {
  final firstCell = row.isNotEmpty ? row[0].trim() : '';
  final secondCell = row.length > 1 ? row[1].trim() : '';
  final codePattern = RegExp(r'^\d{6}$');

  if (codePattern.hasMatch(firstCell)) {
    return (firstCell, _normalizeLimitReviewText(secondCell) ?? firstCell);
  }
  if (codePattern.hasMatch(secondCell)) {
    return (secondCell, _normalizeLimitReviewText(firstCell) ?? secondCell);
  }
  return (
    null,
    _normalizeLimitReviewText(secondCell) ??
        _normalizeLimitReviewText(firstCell),
  );
}

String _formatLimitReviewSignedPercent(double? value) {
  if (value == null) {
    return '--';
  }
  final formatted = value.toStringAsFixed(2);
  return '${value >= 0 ? '+' : ''}$formatted%';
}

String _formatLimitReviewPercent(double? value) {
  if (value == null) {
    return '--';
  }
  return '${_formatLimitReviewNumber(value)}%';
}

String _formatLimitReviewYi(double? value) {
  if (value == null) {
    return '--';
  }
  return '${_formatLimitReviewNumber(value)}亿';
}

String _formatLimitReviewNumber(double? value) {
  if (value == null) {
    return '--';
  }
  final normalized =
      value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  return normalized;
}

String _normalizeLimitReviewDisplayText(String value) {
  var normalized = value.trim();
  if (normalized.isEmpty) {
    return '--';
  }
  normalized = normalized
      .replaceAllMapped(
        RegExp(r'(-?\d+(?:\.\d+)?)\s*yi\b', caseSensitive: false),
        (match) => '${match.group(1)}亿',
      )
      .replaceAllMapped(
        RegExp(r'(-?\d+(?:\.\d+)?)\s*wan\b', caseSensitive: false),
        (match) => '${match.group(1)}万',
      )
      .replaceAll(RegExp(r'\bprev\b', caseSensitive: false), '昨')
      .replaceAllMapped(
    RegExp(r'(\d+)\s*days\s*/\s*(\d+)\s*hits', caseSensitive: false),
    (match) {
      final days = int.tryParse(match.group(1) ?? '');
      final hits = int.tryParse(match.group(2) ?? '');
      if (days != null && hits != null && days == hits) {
        return '$days板';
      }
      return '${match.group(1)}天/${match.group(2)}次';
    },
  );
  const labels = {
    'inspect': '查看',
    'null': '--',
  };
  return labels[normalized.toLowerCase()] ?? normalized;
}

const List<LimitReviewTableColumnData> _defaultStructuredLimitReviewColumns = [
  LimitReviewTableColumnData(
    key: 'stock_name',
    label: '股票名称',
    align: 'left',
    width: 168,
  ),
  LimitReviewTableColumnData(
    key: 'stock_code',
    label: '股票代码',
    align: 'center',
    width: 96,
  ),
  LimitReviewTableColumnData(
    key: 'change_pct',
    label: '现涨幅',
    align: 'right',
    width: 92,
  ),
  LimitReviewTableColumnData(
    key: 'pre_close_price',
    label: '昨收价',
    align: 'right',
    width: 88,
  ),
  LimitReviewTableColumnData(
    key: 'board_count',
    label: '板数',
    align: 'center',
    width: 68,
  ),
  LimitReviewTableColumnData(
    key: 'lianban_text',
    label: '连板',
    align: 'center',
    width: 76,
  ),
  LimitReviewTableColumnData(
    key: 'board_shape',
    label: '板形',
    align: 'center',
    width: 82,
  ),
  LimitReviewTableColumnData(
    key: 'first_limit_time',
    label: '首次封板',
    align: 'center',
    width: 98,
  ),
  LimitReviewTableColumnData(
    key: 'final_limit_time',
    label: '最终封板',
    align: 'center',
    width: 98,
  ),
  LimitReviewTableColumnData(
    key: 'amount_yi',
    label: '成交额',
    align: 'right',
    width: 104,
  ),
  LimitReviewTableColumnData(
    key: 'float_market_cap_yi',
    label: '实际流通',
    align: 'right',
    width: 112,
  ),
  LimitReviewTableColumnData(
    key: 'total_market_cap_yi',
    label: '总市值',
    align: 'right',
    width: 112,
  ),
  LimitReviewTableColumnData(
    key: 'turnover_rate',
    label: '换手率',
    align: 'right',
    width: 92,
  ),
  LimitReviewTableColumnData(
    key: 'reason',
    label: '异动原因',
    align: 'left',
    width: 280,
  ),
];

const List<LimitReviewTableColumnData> _defaultSimpleCodeFirstColumns = [
  LimitReviewTableColumnData(
    key: 'stock_code',
    label: '股票代码',
    align: 'center',
    width: 96,
  ),
  LimitReviewTableColumnData(
    key: 'stock_name',
    label: '股票名称',
    align: 'left',
    width: 168,
  ),
  LimitReviewTableColumnData(
    key: 'theme',
    label: '题材',
    align: 'left',
    width: 140,
  ),
];

const List<LimitReviewTableColumnData> _defaultSimpleNameFirstColumns = [
  LimitReviewTableColumnData(
    key: 'stock_name',
    label: '股票名称',
    align: 'left',
    width: 168,
  ),
  LimitReviewTableColumnData(
    key: 'stock_code',
    label: '股票代码',
    align: 'center',
    width: 96,
  ),
  LimitReviewTableColumnData(
    key: 'theme',
    label: '题材',
    align: 'left',
    width: 140,
  ),
];

List<LimitReviewTableColumnData> _inferLimitReviewColumns(List<String> row) {
  if (row.isEmpty) {
    return const [];
  }
  if (row.length >= _defaultStructuredLimitReviewColumns.length) {
    return _defaultStructuredLimitReviewColumns;
  }
  if (row.length >= 3) {
    final secondCell = row.length > 1 ? row[1].trim() : '';
    if (RegExp(r'^\d{6}$').hasMatch(secondCell)) {
      return _defaultSimpleNameFirstColumns.take(row.length).toList(
            growable: false,
          );
    }
    return _defaultSimpleCodeFirstColumns.take(row.length).toList(
          growable: false,
        );
  }
  return List<LimitReviewTableColumnData>.generate(
    row.length,
    (index) => LimitReviewTableColumnData(
      key: 'column_${index + 1}',
      label: 'Column ${index + 1}',
    ),
    growable: false,
  );
}

class BoardHeightChartItemData {
  const BoardHeightChartItemData({
    required this.date,
    required this.value,
    required this.leaderName,
    required this.leaderCode,
  });

  final String date;
  final int value;
  final String? leaderName;
  final String? leaderCode;

  factory BoardHeightChartItemData.fromJson(Map<String, dynamic> json) {
    return BoardHeightChartItemData(
      date: json['date'] as String? ?? '--',
      value: (json['value'] as num?)?.toInt() ?? 0,
      leaderName: json['leader_name']?.toString(),
      leaderCode: json['leader_code']?.toString(),
    );
  }
}

class BoardHeightStockData {
  const BoardHeightStockData({
    required this.name,
    required this.code,
    required this.boardCount,
  });

  final String name;
  final String? code;
  final int? boardCount;

  factory BoardHeightStockData.fromJson(Map<String, dynamic> json) {
    return BoardHeightStockData(
      name: json['name'] as String? ?? '--',
      code: json['code']?.toString(),
      boardCount: (json['board_count'] as num?)?.toInt(),
    );
  }
}

class BoardHeightColumnData {
  const BoardHeightColumnData({
    required this.date,
    required this.stocks,
  });

  final String date;
  final List<BoardHeightStockData> stocks;

  factory BoardHeightColumnData.fromJson(Map<String, dynamic> json) {
    return BoardHeightColumnData(
      date: json['date'] as String? ?? '--',
      stocks: (json['stocks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BoardHeightStockData.fromJson)
          .toList(growable: false),
    );
  }
}

class BoardHeightSnapshot {
  const BoardHeightSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    this.previousTradeDate,
    this.nextTradeDate,
    this.availableTradeDates = const <String>[],
    required this.latestHeight,
    required this.chartItems,
    required this.columns,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String? previousTradeDate;
  final String? nextTradeDate;
  final List<String> availableTradeDates;
  final int? latestHeight;
  final List<BoardHeightChartItemData> chartItems;
  final List<BoardHeightColumnData> columns;

  factory BoardHeightSnapshot.fromJson(Map<String, dynamic> json) {
    return BoardHeightSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      previousTradeDate: json['previous_trade_date']?.toString(),
      nextTradeDate: json['next_trade_date']?.toString(),
      availableTradeDates:
          (json['available_trade_dates'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
      latestHeight: (json['latest_height'] as num?)?.toInt(),
      chartItems: (json['chart_items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BoardHeightChartItemData.fromJson)
          .toList(growable: false),
      columns: (json['columns'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BoardHeightColumnData.fromJson)
          .toList(growable: false),
    );
  }
}

class BoardTierStockData {
  const BoardTierStockData({
    required this.code,
    required this.name,
    required this.market,
    required this.status,
    required this.changePct,
    required this.latestPrice,
    required this.firstLimitTime,
    required this.amount,
    required this.breakCount,
    required this.regionName,
    required this.industryName,
    required this.listingDate,
    required this.reason,
  });

  final String code;
  final String name;
  final String market;
  final String status;
  final String changePct;
  final String latestPrice;
  final String firstLimitTime;
  final String amount;
  final String breakCount;
  final String regionName;
  final String industryName;
  final String listingDate;
  final String reason;

  factory BoardTierStockData.fromJson(Map<String, dynamic> json) {
    return BoardTierStockData(
      code: json['code'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      market: json['market'] as String? ?? '--',
      status: json['status'] as String? ?? '--',
      changePct: json['change_pct'] as String? ?? '--',
      latestPrice: json['latest_price'] as String? ?? '--',
      firstLimitTime: json['first_limit_time'] as String? ?? '--',
      amount: json['amount'] as String? ?? '--',
      breakCount: json['break_count'] as String? ?? '--',
      regionName: json['region_name'] as String? ?? '--',
      industryName: json['industry_name'] as String? ?? '--',
      listingDate: json['listing_date'] as String? ?? '--',
      reason: json['reason'] as String? ?? '--',
    );
  }
}

class BoardTierGroupData {
  const BoardTierGroupData({
    required this.boardCount,
    required this.title,
    required this.total,
    required this.sealedCount,
    required this.brokenCount,
    required this.successRatePct,
    required this.successRateText,
    required this.stocks,
  });

  final int boardCount;
  final String title;
  final int total;
  final int sealedCount;
  final int brokenCount;
  final int successRatePct;
  final String successRateText;
  final List<BoardTierStockData> stocks;

  factory BoardTierGroupData.fromJson(Map<String, dynamic> json) {
    return BoardTierGroupData(
      boardCount: (json['board_count'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '--',
      total: (json['total'] as num?)?.toInt() ?? 0,
      sealedCount: (json['sealed_count'] as num?)?.toInt() ?? 0,
      brokenCount: (json['broken_count'] as num?)?.toInt() ?? 0,
      successRatePct: (json['success_rate_pct'] as num?)?.toInt() ?? 0,
      successRateText: json['success_rate_text'] as String? ?? '--',
      stocks: (json['stocks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BoardTierStockData.fromJson)
          .toList(growable: false),
    );
  }
}

class BoardTierSnapshot {
  const BoardTierSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    this.previousTradeDate,
    this.nextTradeDate,
    this.availableTradeDates = const <String>[],
    required this.totalTiers,
    required this.totalStocks,
    required this.tiers,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String? previousTradeDate;
  final String? nextTradeDate;
  final List<String> availableTradeDates;
  final int totalTiers;
  final int totalStocks;
  final List<BoardTierGroupData> tiers;

  factory BoardTierSnapshot.fromJson(Map<String, dynamic> json) {
    return BoardTierSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      previousTradeDate: json['previous_trade_date']?.toString(),
      nextTradeDate: json['next_trade_date']?.toString(),
      availableTradeDates:
          (json['available_trade_dates'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
      totalTiers: (json['total_tiers'] as num?)?.toInt() ?? 0,
      totalStocks: (json['total_stocks'] as num?)?.toInt() ?? 0,
      tiers: (json['tiers'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BoardTierGroupData.fromJson)
          .toList(growable: false),
    );
  }
}

String? inferStockMarketTag(String? stockCode) {
  final digits = (stockCode ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return null;
  }

  final code = digits.length >= 6
      ? digits.substring(digits.length - 6)
      : digits.padLeft(6, '0');
  if (code.startsWith('688') || code.startsWith('689')) {
    return '科';
  }
  if (code.startsWith('300') || code.startsWith('301')) {
    return '创';
  }
  if (code.startsWith('4') || code.startsWith('8') || code.startsWith('92')) {
    return '北';
  }
  if (code.startsWith('600') ||
      code.startsWith('601') ||
      code.startsWith('603') ||
      code.startsWith('605')) {
    return '沪';
  }
  if (code.startsWith('000') ||
      code.startsWith('001') ||
      code.startsWith('002') ||
      code.startsWith('003')) {
    return '深';
  }
  return null;
}

class EmotionStatsData {
  const EmotionStatsData({
    required this.zt,
    required this.lb,
    required this.zb,
    required this.dt,
    required this.fbl,
  });

  final int zt;
  final int lb;
  final int zb;
  final int dt;
  final int fbl;

  factory EmotionStatsData.fromJson(Map<String, dynamic> json) {
    return EmotionStatsData(
      zt: (json['zt'] as num?)?.toInt() ?? 0,
      lb: (json['lb'] as num?)?.toInt() ?? 0,
      zb: (json['zb'] as num?)?.toInt() ?? 0,
      dt: (json['dt'] as num?)?.toInt() ?? 0,
      fbl: (json['fbl'] as num?)?.toInt() ?? 0,
    );
  }
}

class YesterdayStatsItemData {
  const YesterdayStatsItemData({
    required this.code,
    required this.name,
    required this.price,
    required this.openChangePct,
    required this.changePct,
    required this.amountYi,
    required this.industry,
    this.region,
  });

  final String code;
  final String name;
  final double? price;
  final double? openChangePct;
  final double? changePct;
  final double? amountYi;
  final String? region;
  final String? industry;

  String? get marketTag => inferStockMarketTag(code);

  factory YesterdayStatsItemData.fromJson(Map<String, dynamic> json) {
    return YesterdayStatsItemData(
      code: json['code'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      price: (json['price'] as num?)?.toDouble(),
      openChangePct: (json['open_change_pct'] as num?)?.toDouble(),
      changePct: (json['change_pct'] as num?)?.toDouble(),
      amountYi: (json['amount_yi'] as num?)?.toDouble(),
      region: json['region']?.toString(),
      industry: json['industry']?.toString(),
    );
  }
}

class YesterdayStatsSectionData {
  const YesterdayStatsSectionData({
    required this.key,
    required this.title,
    required this.total,
    required this.items,
  });

  final String key;
  final String title;
  final int total;
  final List<YesterdayStatsItemData> items;

  factory YesterdayStatsSectionData.fromJson(Map<String, dynamic> json) {
    return YesterdayStatsSectionData(
      key: json['key'] as String? ?? '--',
      title: json['title'] as String? ?? '--',
      total: (json['total'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(YesterdayStatsItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class YesterdayStatsSnapshot {
  const YesterdayStatsSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    required this.tradeDates,
    required this.todayStats,
    required this.yesterdayStats,
    required this.sections,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final Map<String, String> tradeDates;
  final EmotionStatsData todayStats;
  final EmotionStatsData yesterdayStats;
  final List<YesterdayStatsSectionData> sections;

  factory YesterdayStatsSnapshot.fromJson(Map<String, dynamic> json) {
    return YesterdayStatsSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      tradeDates: (json['trade_dates'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value.toString())),
      todayStats: EmotionStatsData.fromJson(
        json['today_stats'] as Map<String, dynamic>? ?? const {},
      ),
      yesterdayStats: EmotionStatsData.fromJson(
        json['yesterday_stats'] as Map<String, dynamic>? ?? const {},
      ),
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(YesterdayStatsSectionData.fromJson)
          .toList(growable: false),
    );
  }
}

class ReviewPageData {
  const ReviewPageData({
    required this.limitReview,
    required this.boardHeight,
    required this.yesterdayStats,
  });

  final LimitReviewSnapshot limitReview;
  final BoardHeightSnapshot boardHeight;
  final YesterdayStatsSnapshot yesterdayStats;
}

class FeedItemData {
  const FeedItemData({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.extra,
    required this.url,
    required this.group,
    required this.isImportant,
  });

  final String title;
  final String? subtitle;
  final String? time;
  final String? extra;
  final String? url;
  final String? group;
  final bool isImportant;

  factory FeedItemData.fromJson(Map<String, dynamic> json) {
    return FeedItemData(
      title: json['title'] as String? ?? '--',
      subtitle: json['subtitle']?.toString(),
      time: json['time']?.toString(),
      extra: _localizeNewsMeta(json['extra']?.toString()),
      url: json['url']?.toString(),
      group: json['group']?.toString(),
      isImportant: json['is_important'] as bool? ?? false,
    );
  }
}

class FeedSectionData {
  const FeedSectionData({
    required this.key,
    required this.title,
    required this.total,
    required this.items,
  });

  final String key;
  final String title;
  final int total;
  final List<FeedItemData> items;

  factory FeedSectionData.fromJson(Map<String, dynamic> json) {
    return FeedSectionData(
      key: json['key'] as String? ?? '--',
      title: json['title'] as String? ?? '--',
      total: (json['total'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FeedItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class NewsCenterSnapshot {
  const NewsCenterSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    required this.sections,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final List<FeedSectionData> sections;

  factory NewsCenterSnapshot.fromJson(Map<String, dynamic> json) {
    return NewsCenterSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FeedSectionData.fromJson)
          .toList(growable: false),
    );
  }
}

class FeedSnapshot {
  const FeedSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    required this.total,
    required this.items,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final int total;
  final List<FeedItemData> items;

  factory FeedSnapshot.fromJson(Map<String, dynamic> json) {
    return FeedSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FeedItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class MonthlyPatternData {
  const MonthlyPatternData({
    required this.monthIndex,
    required this.month,
    required this.trend,
    required this.winRate,
    required this.driver,
    required this.target,
    required this.analysis,
    required this.strategy,
  });

  final int monthIndex;
  final String month;
  final String trend;
  final String winRate;
  final String driver;
  final String target;
  final String analysis;
  final String strategy;

  String get headline => driver;

  List<String> get drivers => driver
      .split(RegExp(r'\s*/\s*'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  String get focus => target;

  factory MonthlyPatternData.fromJson(Map<String, dynamic> json) {
    return MonthlyPatternData(
      monthIndex: (json['month_index'] as num?)?.toInt() ?? 0,
      month: json['month'] as String? ?? '--',
      trend: _localizeNewsText(json['trend'] as String? ?? '--'),
      winRate: _localizeNewsText(json['win_rate'] as String? ?? '--'),
      driver: _localizeNewsText(json['driver'] as String? ?? '--'),
      target: _localizeNewsText(json['target'] as String? ?? '--'),
      analysis: _localizeNewsText(json['analysis'] as String? ?? '--'),
      strategy: _localizeNewsText(json['strategy'] as String? ?? '--'),
    );
  }
}

String _localizeNewsText(String value) {
  return value
      .replaceAll('Sell in May', '五月防御效应')
      .replaceAll('sell in May', '五月防御效应')
      .replaceAll('Sell In May', '五月防御效应')
      .replaceAll('TMT', '科技成长')
      .replaceAll('AI', '人工智能');
}

String? _localizeNewsMeta(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized
      .replaceAllMapped(
        RegExp(r'\bheat\s+(\d+)\b', caseSensitive: false),
        (match) => '热度 ${match.group(1)}',
      )
      .replaceAllMapped(
        RegExp(r'\bsource\s*[:：]?\s*', caseSensitive: false),
        (_) => '来源 ',
      );
}

class NewsPageData {
  const NewsPageData({
    required this.center,
    required this.fastNews,
    required this.timeline,
  });

  final NewsCenterSnapshot center;
  final FeedSnapshot fastNews;
  final FeedSnapshot timeline;
}

class PlateRotationPointData {
  const PlateRotationPointData({
    required this.date,
    required this.ztCount,
    required this.strength,
    required this.strengthText,
  });

  final String date;
  final int? ztCount;
  final double? strength;
  final String? strengthText;

  factory PlateRotationPointData.fromJson(Map<String, dynamic> json) {
    return PlateRotationPointData(
      date: json['date'] as String? ?? '--',
      ztCount: (json['zt_count'] as num?)?.toInt(),
      strength: (json['strength'] as num?)?.toDouble(),
      strengthText: json['strength_text']?.toString(),
    );
  }
}

class PlateRotationItemData {
  const PlateRotationItemData({
    required this.plateName,
    required this.plateCode,
    required this.latestZt,
    required this.latestStrengthText,
    required this.series,
  });

  final String plateName;
  final String? plateCode;
  final int? latestZt;
  final String? latestStrengthText;
  final List<PlateRotationPointData> series;

  factory PlateRotationItemData.fromJson(Map<String, dynamic> json) {
    return PlateRotationItemData(
      plateName: json['plate_name'] as String? ?? '--',
      plateCode: json['plate_code']?.toString(),
      latestZt: (json['latest_zt'] as num?)?.toInt(),
      latestStrengthText: json['latest_strength_text']?.toString(),
      series: (json['series'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateRotationPointData.fromJson)
          .toList(growable: false),
    );
  }
}

class PlateRotationSnapshot {
  const PlateRotationSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    this.previousTradeDate,
    this.nextTradeDate,
    this.availableTradeDates = const <String>[],
    required this.dates,
    required this.total,
    required this.items,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String? previousTradeDate;
  final String? nextTradeDate;
  final List<String> availableTradeDates;
  final List<String> dates;
  final int total;
  final List<PlateRotationItemData> items;

  factory PlateRotationSnapshot.fromJson(Map<String, dynamic> json) {
    return PlateRotationSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      previousTradeDate: json['previous_trade_date']?.toString(),
      nextTradeDate: json['next_trade_date']?.toString(),
      availableTradeDates:
          (json['available_trade_dates'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false),
      dates: (json['dates'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateRotationItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class PlateStockItemData {
  const PlateStockItemData({
    required this.stockCode,
    required this.stockName,
    required this.rankNo,
  });

  final String stockCode;
  final String stockName;
  final int rankNo;

  factory PlateStockItemData.fromJson(Map<String, dynamic> json) {
    return PlateStockItemData(
      stockCode: json['stock_code'] as String? ?? '--',
      stockName: json['stock_name'] as String? ?? '--',
      rankNo: (json['rank_no'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlateStockDateGroupData {
  const PlateStockDateGroupData({
    required this.date,
    required this.total,
    required this.stocks,
  });

  final String date;
  final int total;
  final List<PlateStockItemData> stocks;

  factory PlateStockDateGroupData.fromJson(Map<String, dynamic> json) {
    return PlateStockDateGroupData(
      date: json['date'] as String? ?? '--',
      total: (json['total'] as num?)?.toInt() ?? 0,
      stocks: (json['stocks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateStockItemData.fromJson)
          .toList(growable: false),
    );
  }
}

class PlateStocksSnapshot {
  const PlateStocksSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    required this.plateCode,
    required this.plateName,
    required this.dates,
    required this.items,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String plateCode;
  final String? plateName;
  final List<String> dates;
  final List<PlateStockDateGroupData> items;

  factory PlateStocksSnapshot.fromJson(Map<String, dynamic> json) {
    return PlateStocksSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      plateCode: json['plate_code'] as String? ?? '--',
      plateName: json['plate_name']?.toString(),
      dates: (json['dates'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlateStockDateGroupData.fromJson)
          .toList(growable: false),
    );
  }
}

class StockProfileData {
  const StockProfileData({
    required this.symbol,
    required this.stockCode,
    required this.name,
    required this.market,
    required this.secid,
    required this.regionName,
    required this.industryName,
    required this.listingDate,
    required this.isActive,
    required this.profileUpdatedAt,
    required this.updatedAt,
  });

  final String symbol;
  final String stockCode;
  final String name;
  final String? market;
  final String? secid;
  final String? regionName;
  final String? industryName;
  final String? listingDate;
  final bool isActive;
  final String? profileUpdatedAt;
  final String? updatedAt;

  factory StockProfileData.fromJson(Map<String, dynamic> json) {
    return StockProfileData(
      symbol: json['symbol'] as String? ?? '--',
      stockCode: json['stock_code'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      market: json['market']?.toString(),
      secid: json['secid']?.toString(),
      regionName: json['region_name']?.toString(),
      industryName: json['industry_name']?.toString(),
      listingDate: json['listing_date']?.toString(),
      isActive: json['is_active'] as bool? ?? false,
      profileUpdatedAt: json['profile_updated_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class QuoteData {
  const QuoteData({
    required this.tradeDate,
    required this.fetchedAt,
    required this.symbol,
    required this.name,
    required this.price,
    required this.preClose,
    required this.open,
    required this.high,
    required this.low,
    required this.volume,
    required this.amount,
    required this.change,
    required this.changePct,
    required this.turnoverRate,
    required this.amplitude,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String symbol;
  final String name;
  final double? price;
  final double? preClose;
  final double? open;
  final double? high;
  final double? low;
  final int? volume;
  final double? amount;
  final double? change;
  final double? changePct;
  final double? turnoverRate;
  final double? amplitude;

  factory QuoteData.fromJson(Map<String, dynamic> json) {
    return QuoteData(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      symbol: json['symbol'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      price: (json['price'] as num?)?.toDouble(),
      preClose: (json['pre_close'] as num?)?.toDouble(),
      open: (json['open'] as num?)?.toDouble(),
      high: (json['high'] as num?)?.toDouble(),
      low: (json['low'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toDouble(),
      change: (json['change'] as num?)?.toDouble(),
      changePct: (json['change_pct'] as num?)?.toDouble(),
      turnoverRate: (json['turnover_rate'] as num?)?.toDouble(),
      amplitude: (json['amplitude'] as num?)?.toDouble(),
    );
  }
}

class KlineBarData {
  const KlineBarData({
    required this.tradeDate,
    required this.openPrice,
    required this.closePrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
  });

  final String tradeDate;
  final double openPrice;
  final double closePrice;
  final double highPrice;
  final double lowPrice;
  final double volume;

  factory KlineBarData.fromJson(Map<String, dynamic> json) {
    return KlineBarData(
      tradeDate: json['trade_date'] as String? ?? '--',
      openPrice: (json['open_price'] as num?)?.toDouble() ?? 0,
      closePrice: (json['close_price'] as num?)?.toDouble() ?? 0,
      highPrice: (json['high_price'] as num?)?.toDouble() ?? 0,
      lowPrice: (json['low_price'] as num?)?.toDouble() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
    );
  }
}

class KlineSnapshot {
  const KlineSnapshot({
    required this.tradeDate,
    required this.fetchedAt,
    required this.symbol,
    required this.name,
    required this.total,
    required this.bars,
  });

  final String? tradeDate;
  final String? fetchedAt;
  final String symbol;
  final String name;
  final int total;
  final List<KlineBarData> bars;

  factory KlineSnapshot.fromJson(Map<String, dynamic> json) {
    return KlineSnapshot(
      tradeDate: json['trade_date']?.toString(),
      fetchedAt: json['fetched_at']?.toString(),
      symbol: json['symbol'] as String? ?? '--',
      name: json['name'] as String? ?? '--',
      total: (json['total'] as num?)?.toInt() ?? 0,
      bars: (json['bars'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(KlineBarData.fromJson)
          .toList(growable: false),
    );
  }
}

class NodePageData {
  const NodePageData({
    required this.quote,
    required this.kline,
    required this.plateRotation,
  });

  final QuoteData quote;
  final KlineSnapshot kline;
  final PlateRotationSnapshot plateRotation;
}

class MarketApiRepository {
  const MarketApiRepository(this._client);

  final ApiClient _client;

  Future<AuctionLiveSnapshot> fetchAuctionLive({int limit = 30}) async {
    final data = await _client.getMap('/api/v1/auction/live?limit=$limit');
    return AuctionLiveSnapshot.fromJson(data);
  }

  Future<TableSectionsSnapshot> fetchAuctionRanks() async {
    final data = await _client.getMap('/api/v1/auction/ranks');
    return TableSectionsSnapshot.fromJson(data);
  }

  Future<AuctionPageData> fetchAuctionPageData() async {
    final results = await Future.wait([
      fetchAuctionLive(),
      fetchAuctionRanks(),
    ]);
    return AuctionPageData(
      live: results[0] as AuctionLiveSnapshot,
      ranks: results[1] as TableSectionsSnapshot,
    );
  }

  Future<TableSectionsSnapshot> fetchMarketCenter() async {
    final data = await _client.getMap('/api/v1/market-center');
    return TableSectionsSnapshot.fromJson(data);
  }

  Future<LimitReviewSnapshot> fetchLimitReview() async {
    final data = await _client.getMap('/api/v1/limit-review');
    return LimitReviewSnapshot.fromJson(data);
  }

  Future<BoardHeightSnapshot> fetchBoardHeight() async {
    final data = await _client.getMap('/api/v1/board-height');
    return BoardHeightSnapshot.fromJson(data);
  }

  Future<BoardTierSnapshot> fetchBoardTier({
    String? tradeDate,
    int tierLimit = 8,
    int stockLimit = 20,
  }) async {
    final queryParameters = <String, String>{
      'tier_limit': '$tierLimit',
      'stock_limit': '$stockLimit',
    };
    final normalizedTradeDate = tradeDate?.trim();
    if (normalizedTradeDate != null && normalizedTradeDate.isNotEmpty) {
      queryParameters['trade_date'] = normalizedTradeDate;
    }
    final data = await _client.getMap(
      Uri(
        path: '/api/v1/lianban/tiers',
        queryParameters: queryParameters,
      ).toString(),
    );
    return BoardTierSnapshot.fromJson(data);
  }

  Future<YesterdayStatsSnapshot> fetchYesterdayStats({
    String? tradeDate,
    int limit = 16,
  }) async {
    final queryParameters = <String, String>{
      'limit': '$limit',
    };
    final normalizedTradeDate = tradeDate?.trim();
    if (normalizedTradeDate != null && normalizedTradeDate.isNotEmpty) {
      queryParameters['trade_date'] = normalizedTradeDate;
    }
    final data = await _client.getMap(
      Uri(
        path: '/api/v1/yesterday/stats',
        queryParameters: queryParameters,
      ).toString(),
    );
    return YesterdayStatsSnapshot.fromJson(data);
  }

  Future<ReviewPageData> fetchReviewPageData() async {
    final results = await Future.wait([
      fetchLimitReview(),
      fetchBoardHeight(),
      fetchYesterdayStats(),
    ]);
    return ReviewPageData(
      limitReview: results[0] as LimitReviewSnapshot,
      boardHeight: results[1] as BoardHeightSnapshot,
      yesterdayStats: results[2] as YesterdayStatsSnapshot,
    );
  }

  Future<NewsCenterSnapshot> fetchNewsCenter({int limit = 16}) async {
    final data = await _client.getMap('/api/v1/news/center?limit=$limit');
    return NewsCenterSnapshot.fromJson(data);
  }

  Future<FeedSnapshot> fetchHotNews({int limit = 16}) async {
    final data = await _client.getMap('/api/v1/news/hot?limit=$limit');
    return FeedSnapshot.fromJson(data);
  }

  Future<FeedSnapshot> fetchTodayHot({int limit = 16}) async {
    final data = await _client.getMap('/api/v1/news/today-hot?limit=$limit');
    return FeedSnapshot.fromJson(data);
  }

  Future<FeedSnapshot> fetchFastNews({int limit = 20}) async {
    final data = await _client.getMap('/api/v1/news/724?limit=$limit');
    return FeedSnapshot.fromJson(data);
  }

  Future<FeedSnapshot> fetchTimeline({int limit = 20}) async {
    final data = await _client.getMap('/api/v1/calendar/timeline?limit=$limit');
    return FeedSnapshot.fromJson(data);
  }

  Future<Map<String, dynamic>> fetchNewsWorkspacePayload({
    int hotLimit = 16,
    int todayHotLimit = 16,
    int fastLimit = 50,
    int timelineLimit = 20,
  }) async {
    return _client.getMap(
      '/api/v1/news/page'
      '?hot_limit=$hotLimit'
      '&today_hot_limit=$todayHotLimit'
      '&fast_limit=$fastLimit'
      '&timeline_limit=$timelineLimit',
    );
  }

  Future<List<MonthlyPatternData>> fetchMonthlyPatterns() async {
    final data = await _client.getList('/api/v1/news/monthly-patterns');
    return data
        .whereType<Map<String, dynamic>>()
        .map(MonthlyPatternData.fromJson)
        .toList(growable: false);
  }

  Future<NewsPageData> fetchNewsPageData() async {
    final results = await Future.wait([
      fetchNewsCenter(),
      fetchFastNews(),
      fetchTimeline(),
    ]);
    return NewsPageData(
      center: results[0] as NewsCenterSnapshot,
      fastNews: results[1] as FeedSnapshot,
      timeline: results[2] as FeedSnapshot,
    );
  }

  Future<PlateRotationSnapshot> fetchPlateRotation({int limit = 18}) async {
    final data = await _client.getMap('/api/v1/plate-rotation?limit=$limit');
    return PlateRotationSnapshot.fromJson(data);
  }

  Future<PlateStocksSnapshot> fetchPlateStocks(
    String plateCode, {
    int limit = 12,
  }) async {
    final data =
        await _client.getMap('/api/v1/plates/$plateCode/stocks?limit=$limit');
    return PlateStocksSnapshot.fromJson(data);
  }

  Future<StockProfileData> fetchStockProfile(String symbol) async {
    final data = await _client.getMap('/api/v1/stocks/$symbol/profile');
    return StockProfileData.fromJson(data);
  }

  Future<QuoteData> fetchQuote(String symbol) async {
    final data = await _client.getMap('/api/v1/stocks/$symbol/quote');
    return QuoteData.fromJson(data);
  }

  Future<KlineSnapshot> fetchKline(String symbol, {int days = 21}) async {
    final data =
        await _client.getMap('/api/v1/stocks/$symbol/kline?days=$days');
    return KlineSnapshot.fromJson(data);
  }

  Future<NodePageData> fetchNodePageData(String symbol) async {
    final results = await Future.wait([
      fetchQuote(symbol),
      fetchKline(symbol),
      fetchPlateRotation(limit: 30),
    ]);
    return NodePageData(
      quote: results[0] as QuoteData,
      kline: results[1] as KlineSnapshot,
      plateRotation: results[2] as PlateRotationSnapshot,
    );
  }
}
