import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:niuniu_kaipan/shared/application/app_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testApiBaseUrl = 'https://api.example.invalid';
  const persistedTestApiBaseUrl = 'https://persisted-api.example.invalid';

  test('app preferences load persisted stock linkage settings', () async {
    SharedPreferences.setMockInitialValues({
      'runtime_api_base_url': persistedTestApiBaseUrl,
      'runtime_tdx_path': r'C:\Tdx\TdxW.exe',
      'runtime_ths_path': r'C:\THS\hexin.exe',
      'runtime_stock_link_client': 'ths',
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final preferences = await container.read(appPreferencesProvider.future);

    expect(preferences.apiBaseUrl, persistedTestApiBaseUrl);
    expect(preferences.tdxPath, r'C:\Tdx\TdxW.exe');
    expect(preferences.thsPath, r'C:\THS\hexin.exe');
    expect(preferences.stockLinkClient, StockLinkClient.ths);
    expect(preferences.preferredClientReady, isTrue);
  });

  test('app preferences save updates stock linkage settings', () async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(appPreferencesProvider.notifier).savePreferences(
          const AppPreferences(
            apiBaseUrl: testApiBaseUrl,
            tdxPath: r'D:\quotes\TdxW.exe',
            thsPath: '',
            stockLinkClient: StockLinkClient.tdx,
          ),
        );

    final sharedPreferences = await SharedPreferences.getInstance();

    expect(
        sharedPreferences.getString('runtime_tdx_path'), r'D:\quotes\TdxW.exe');
    expect(sharedPreferences.getString('runtime_ths_path'), isNull);
    expect(sharedPreferences.getString('runtime_stock_link_client'), 'tdx');
  });
}
