import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_base_url.dart';

enum StockLinkClient {
  tdx,
  ths,
}

extension StockLinkClientX on StockLinkClient {
  String get storageValue => switch (this) {
        StockLinkClient.tdx => 'tdx',
        StockLinkClient.ths => 'ths',
      };

  String get label => switch (this) {
        StockLinkClient.tdx => '通达信',
        StockLinkClient.ths => '同花顺',
      };
}

StockLinkClient parseStockLinkClient(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'ths' => StockLinkClient.ths,
    _ => StockLinkClient.tdx,
  };
}

class AppPreferences {
  const AppPreferences({
    this.apiBaseUrl = defaultApiBaseUrl,
    this.tdxPath = '',
    this.thsPath = '',
    this.stockLinkClient = StockLinkClient.tdx,
  });

  final String apiBaseUrl;
  final String tdxPath;
  final String thsPath;
  final StockLinkClient stockLinkClient;

  bool get usesDefaultApiBaseUrl => apiBaseUrl == defaultApiBaseUrl;

  bool get hasTdxPath => tdxPath.trim().isNotEmpty;

  bool get hasThsPath => thsPath.trim().isNotEmpty;

  bool get hasAnyStockClientConfigured => hasTdxPath || hasThsPath;

  bool get preferredClientReady => switch (stockLinkClient) {
        StockLinkClient.tdx => hasTdxPath,
        StockLinkClient.ths => hasThsPath,
      };

  AppPreferences copyWith({
    String? apiBaseUrl,
    String? tdxPath,
    String? thsPath,
    StockLinkClient? stockLinkClient,
  }) {
    return AppPreferences(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      tdxPath: tdxPath ?? this.tdxPath,
      thsPath: thsPath ?? this.thsPath,
      stockLinkClient: stockLinkClient ?? this.stockLinkClient,
    );
  }
}

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  static const _apiBaseUrlKey = 'runtime_api_base_url';
  static const _tdxPathKey = 'runtime_tdx_path';
  static const _thsPathKey = 'runtime_ths_path';
  static const _stockLinkClientKey = 'runtime_stock_link_client';

  @override
  Future<AppPreferences> build() async {
    return _loadPreferences();
  }

  Future<void> saveApiBaseUrl(String value) async {
    final current = state.valueOrNull ?? const AppPreferences();
    await savePreferences(
      current.copyWith(apiBaseUrl: normalizeApiBaseUrl(value)),
    );
  }

  Future<void> saveStockLinkSettings({
    required String tdxPath,
    required String thsPath,
    required StockLinkClient stockLinkClient,
  }) async {
    final current = state.valueOrNull ?? const AppPreferences();
    await savePreferences(
      current.copyWith(
        tdxPath: tdxPath.trim(),
        thsPath: thsPath.trim(),
        stockLinkClient: stockLinkClient,
      ),
    );
  }

  Future<void> savePreferences(AppPreferences nextPreferences) async {
    state = AsyncData(nextPreferences);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (nextPreferences.usesDefaultApiBaseUrl) {
        await prefs.remove(_apiBaseUrlKey);
      } else {
        await prefs.setString(_apiBaseUrlKey, nextPreferences.apiBaseUrl);
      }

      if (nextPreferences.tdxPath.trim().isEmpty) {
        await prefs.remove(_tdxPathKey);
      } else {
        await prefs.setString(_tdxPathKey, nextPreferences.tdxPath.trim());
      }

      if (nextPreferences.thsPath.trim().isEmpty) {
        await prefs.remove(_thsPathKey);
      } else {
        await prefs.setString(_thsPathKey, nextPreferences.thsPath.trim());
      }

      await prefs.setString(
        _stockLinkClientKey,
        nextPreferences.stockLinkClient.storageValue,
      );
    } catch (_) {
      // SharedPreferences is optional in tests and unsupported shells.
    }
  }

  Future<AppPreferences> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppPreferences(
        apiBaseUrl: normalizeApiBaseUrl(prefs.getString(_apiBaseUrlKey)),
        tdxPath: prefs.getString(_tdxPathKey)?.trim() ?? '',
        thsPath: prefs.getString(_thsPathKey)?.trim() ?? '',
        stockLinkClient:
            parseStockLinkClient(prefs.getString(_stockLinkClientKey)),
      );
    } catch (_) {
      return const AppPreferences();
    }
  }
}

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
  AppPreferencesController.new,
);
